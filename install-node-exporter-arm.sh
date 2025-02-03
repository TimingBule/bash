#!/bin/bash

# 获取最新版本号
github_project="prometheus/node_exporter"
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

# 识别架构
arch=$(uname -m)
if [[ "$arch" == "aarch64" ]]; then
    node_exporter_arch="linux-arm64"
elif [[ "$arch" == "armv7l" ]]; then
    node_exporter_arch="linux-armv7"
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

echo "Detected architecture: $arch"
echo "Downloading Node Exporter $tag for $node_exporter_arch..."

# 下载并解压 Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${tag#*v}.${node_exporter_arch}.tar.gz && \
tar xvfz node_exporter-*.tar.gz && \
rm node_exporter-*.tar.gz

# 移动二进制文件到 /usr/local/bin
sudo mv node_exporter-*.${node_exporter_arch}/node_exporter /usr/local/bin/
rm -r node_exporter-*.${node_exporter_arch}

# 创建 node_exporter 用户
sudo useradd -rs /bin/false node_exporter

# 创建 Systemd 服务文件
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
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
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 Systemd 并启动服务
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# 检查运行状态
sudo systemctl status node_exporter --no-pager
