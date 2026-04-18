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

# 下载并安装
wget https://github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${version}.linux-amd64.tar.gz
tar xvfz node_exporter-${version}.linux-amd64.tar.gz
rm node_exporter-${version}.linux-amd64.tar.gz

# 停止旧服务再替换二进制
sudo systemctl stop node_exporter 2>/dev/null || true
sudo mv node_exporter-${version}.linux-amd64/node_exporter /usr/local/bin
rm -rf node_exporter-${version}.linux-amd64

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
