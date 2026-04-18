#!/bin/bash
set -e

COLOR="echo -e \\E[1;32m"
COLOR1="echo -e \\E[1;31m"
END="\\E[0m"

# 必须 root
if [[ $EUID -ne 0 ]]; then
  echo "请切换到 root 用户后再运行脚本"
  exit 1
fi

# 架构判断
case "$(uname -m)" in
  x86_64)         type=amd64  ;;
  aarch64|arm64)  type=arm64  ;;
  armv7l)         type=armv7  ;;
  armv6l)         type=armv6  ;;
  *)
    echo "$(uname -m) 架构不支持"
    exit 1
    ;;
esac
echo "系统架构: $(uname -m) → $type"

# 获取最新版本
latest_version=$(curl -m 10 -sL "https://api.github.com/repos/prometheus/blackbox_exporter/releases/latest" \
  | awk -F'"' '/tag_name/{gsub(/v/, "", $4); print $4}')
if [[ -z "$latest_version" ]]; then
  echo "ERROR: 获取版本号失败，请检查网络或 GitHub API 限速"
  exit 1
fi
echo "Latest version: $latest_version"

# 获取 Tailscale IP
get_tailscale_ip() {
  local ip
  ip=$(tailscale ip -4 2>/dev/null | head -n 1)
  if [[ -z "$ip" ]]; then
    echo "ERROR: 无法获取 Tailscale IP，请确认 tailscale 已运行"
    exit 1
  fi
  echo "$ip"
}

pkg_name="blackbox_exporter-${latest_version}.linux-${type}"

install() {
  if ss -tuln | grep -q ":9115"; then
    echo "端口 9115 已被占用"
    exit 1
  fi

  tailscale_ip=$(get_tailscale_ip)
  echo "Tailscale IP: $tailscale_ip"

  wget "https://github.com/prometheus/blackbox_exporter/releases/download/v${latest_version}/${pkg_name}.tar.gz"
  tar zxvf "${pkg_name}.tar.gz"
  mkdir -p /etc/blackbox_exporter
  mv "${pkg_name}/blackbox_exporter" /usr/local/bin/blackbox_exporter
  chmod +x /usr/local/bin/blackbox_exporter
  wget -O /etc/blackbox_exporter/blackbox.yml \
    https://raw.githubusercontent.com/midori01/common-scripts/main/blackbox-exporter/blackbox.yml
  rm -rf "${pkg_name}" "${pkg_name}.tar.gz"

  # $MAINPID 必须转义，否则 heredoc 会把它展开为空
  cat > /etc/systemd/system/blackbox-exporter.service <<EOF
[Unit]
Description=Prometheus Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/blackbox_exporter \\
  --config.file="/etc/blackbox_exporter/blackbox.yml" \\
  --web.listen-address="${tailscale_ip}:9115"
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now blackbox-exporter.service
}

uninstall() {
  systemctl stop blackbox-exporter.service 2>/dev/null || true
  systemctl disable blackbox-exporter.service 2>/dev/null || true
  rm -f /etc/systemd/system/blackbox-exporter.service
  rm -rf /etc/blackbox_exporter
  rm -f /usr/local/bin/blackbox_exporter
  systemctl daemon-reload
  echo "blackbox-exporter 卸载成功"
}

update() {
  # 先下载，成功再替换，避免下载失败导致服务损坏
  wget "https://github.com/prometheus/blackbox_exporter/releases/download/v${latest_version}/${pkg_name}.tar.gz"
  tar zxvf "${pkg_name}.tar.gz"

  systemctl stop blackbox-exporter.service 2>/dev/null || true
  mv "${pkg_name}/blackbox_exporter" /usr/local/bin/blackbox_exporter
  chmod +x /usr/local/bin/blackbox_exporter
  wget -O /etc/blackbox_exporter/blackbox.yml \
    https://raw.githubusercontent.com/midori01/common-scripts/main/blackbox-exporter/blackbox.yml
  rm -rf "${pkg_name}" "${pkg_name}.tar.gz"

  systemctl daemon-reload
  systemctl restart blackbox-exporter.service
  echo "blackbox-exporter 更新成功"
}

# 入口
case "$1" in
  uninstall) uninstall; exit 0 ;;
  update)    update;    exit 0 ;;
  *)         install ;;
esac

# 验证安装结果
sleep 1
if systemctl is-active --quiet blackbox-exporter.service; then
  ${COLOR}blackbox-exporter 安装成功${END}
  systemctl status blackbox-exporter.service --no-pager
else
  ${COLOR1}blackbox-exporter 安装失败${END}
  journalctl -u blackbox-exporter.service --no-pager -n 20
  exit 1
fi
