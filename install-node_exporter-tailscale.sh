#!/bin/bash
set -e

# 获取最新版本 tag
github_project="prometheus/node_exporter"
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" \
  | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

if [[ -z "$tag" ]]; then
  echo "ERROR: 获取版本号失败，请检查网络或 GitHub API 限速"
  exit 1
fi
echo "Latest version tag: ${tag}"

version=${tag#*v}
echo "Version: $version"

# 检测系统架构
arch=$(uname -m)
case "$arch" in
  x86_64)
    arch_str="amd64"
    ;;
  aarch64 | arm64)
    arch_str="arm64"
    ;;
  armv7l)
    arch_str="armv7"
    ;;
  armv6l)
    arch_str="armv6"
    ;;
  *)
    echo "ERROR: 不支持的架构: $arch"
    exit 1
    ;;
esac
echo "System arch: ${arch} → ${arch_str}"

# 下载并安装
pkg_name="node_exporter-${version}.linux-${arch_str}"
wget "https://github.com/prometheus/node_exporter/releases/download/${tag}/${pkg_name}.tar.gz"
tar xvfz "${pkg_name}.tar.gz"
rm "${pkg_name}.tar.gz"

# 停止旧服务再替换二进制
sudo systemctl stop node_exporter 2>/dev/null || true
sudo mv "${pkg_name}/node_exporter" /usr/local/bin
rm -rf "${pkg_name}"

# 创建用户（已存在则跳过）
sudo useradd -rs /bin/false node_exporter 2>/dev/null || true

# 获取 Tailscale IP
tailscale_ip=$(tailscale ip -4 2>/dev/null | head -n 1)
if [[ -z "$tailscale_ip" ]]; then
  echo "ERROR: 无法获取 Tailscale IP，请确认 tailscale 已运行"
  exit 1
fi
echo "Tailscale IP: $tailscale_ip"

# 写入 systemd 配置
sudo bash -c "cat > /etc/systemd/system/node_exporter.service" <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter \\
  --web.listen-address=${tailscale_ip}:9100 \\
  --collector.netdev.device-exclude="^(docker[0-9]+|br-[a-f0-9]+|veth[a-f0-9]+|lo)\$" \\
  --collector.filesystem.mount-points-exclude="^/(sys|proc|dev|host|etc|run/docker.+)(\$|/)" \\
  --collector.filesystem.fs-types-exclude="^(tmpfs|overlay|aufs|nsfs|squashfs|fuse.lxcfs)\$"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter
