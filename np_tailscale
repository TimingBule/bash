#!/bin/bash

# 获取 Prometheus 最新版本
github_project="prometheus/node_exporter"
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
version=${tag#*v}

# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_TYPE="amd64"
        ;;
    aarch64)
        ARCH_TYPE="arm64"
        ;;
    arm*)
        ARCH_TYPE="arm"
        ;;
    i386|i686)
        ARCH_TYPE="386"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# 下载对应架构的 Node Exporter
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${version}.linux-${ARCH_TYPE}.tar.gz"
wget "${DOWNLOAD_URL}" && \
tar xvfz node_exporter-*.tar.gz && \
rm node_exporter-*.tar.gz

# 移动二进制文件
sudo mv node_exporter-*.linux-${ARCH_TYPE}/node_exporter /usr/local/bin
rm -r node_exporter-*.linux-${ARCH_TYPE}

# 创建用户
sudo useradd -rs /bin/false node_exporter

# 获取 Tailscale IP 地址
TAILSCALE_IP=$(ip a | grep tailscale | grep inet | awk '{print $2}' | cut -d'/' -f1)
if [ -z "$TAILSCALE_IP" ]; then
    echo "No Tailscale IP detected, defaulting to 127.0.0.1:9100"
    LISTEN_ADDRESS="127.0.0.1:9100"
else
    LISTEN_ADDRESS="${TAILSCALE_IP}:9100"
fi

# 创建 systemd 服务文件
sudo cat > /etc/systemd/system/node_exporter.service <<EOF
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
ExecStart=/usr/local/bin/node_exporter --web.listen-address=${LISTEN_ADDRESS}

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter
