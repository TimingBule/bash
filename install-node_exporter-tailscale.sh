#!/bin/bash

# 获取最新版本 tag
github_project="prometheus/node_exporter"
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
echo "Latest version tag: ${tag}"

# 提取版本号用于下载路径
version=${tag#*v}
echo "Version: $version"

# 下载并安装 node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${version}.linux-amd64.tar.gz && \
tar xvfz node_exporter-${version}.linux-amd64.tar.gz && \
rm node_exporter-${version}.linux-amd64.tar.gz
sudo mv node_exporter-${version}.linux-amd64/node_exporter /usr/local/bin
rm -r node_exporter-${version}.linux-amd64*

# 创建 node_exporter 用户（如不存在）
sudo useradd -rs /bin/false node_exporter 2>/dev/null

# 获取 tailscale IPv4 地址
tailscale_ip=$(tailscale ip -4 | head -n 1)
echo "Tailscale IP: $tailscale_ip"

# 写入 systemd 配置文件
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
ExecStart=/usr/local/bin/node_exporter --web.listen-address=${tailscale_ip}:9100

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启动服务
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter
