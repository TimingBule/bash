#!/bin/bash

# 检查是否以 root 权限运行脚本
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行脚本（使用 sudo）"
  exit 1
fi

# 安装必要的软件包（wget 用于下载）
echo "正在安装 wget..."
apt-get update
apt-get install -y wget
# 注意：如果不是 Debian/Ubuntu 系统，请手动安装 wget 或使用对应包管理器（如 yum install wget）

# 下载 cloudflared 二进制文件
echo "正在下载 cloudflared 二进制文件..."
wget -q https://ghfast.top/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

# 安装 cloudflared：添加执行权限并移动到系统路径
echo "正在安装 cloudflared..."
chmod +x cloudflared-linux-amd64
mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# 创建 cloudflared 配置文件目录和配置文件
echo "正在创建 cloudflared 配置文件..."
mkdir -p /etc/cloudflared
cat > /etc/cloudflared/config.yml << EOL
proxy-dns: true
#proxy-dns-port: 5053
proxy-dns-upstream:
  - https://223.5.5.5/dns-query
  - https://223.6.6.6/dns-query
EOL

# 创建 systemd 服务文件
echo "正在创建 cloudflared 的 systemd 服务..."
cat > /etc/systemd/system/cloudflared.service << EOL
[Unit]
Description=Cloudflared DNS over HTTPS 代理
After=network.target

[Service]
ExecStart=/usr/local/bin/cloudflared --config /etc/cloudflared/config.yml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# 启用并启动 cloudflared 服务
echo "正在启用并启动 cloudflared 服务..."
systemctl daemon-reload  # 重新加载 systemd 配置
systemctl enable cloudflared
systemctl start cloudflared

# 检查 cloudflared 服务是否正常运行
if systemctl is-active --quiet cloudflared; then
  echo "cloudflared 服务正在运行。"
else
  echo "cloudflared 服务启动失败，请使用 'journalctl -u cloudflared' 查看日志。"
  exit 1
fi

# 更新 DNS 设置以使用本地 DoH 解析器
echo "正在更新 DNS 设置..."
cat > /etc/resolv.conf << EOL
nameserver 127.0.0.1
EOL

# 锁定 resolv.conf 文件以防止被覆盖（可选，如果系统使用 NetworkManager 等，可能需额外配置）
chattr +i /etc/resolv.conf

# 测试 DNS 解析
echo "正在测试 DNS 解析..."
if command -v dig >/dev/null 2>&1; then
    dig example.com @127.0.0.1
else
    echo "dig 未安装，使用 nslookup 测试..."
    nslookup example.com 127.0.0.1
fi

echo "DoH 配置完成！您的系统现已使用 Cloudflare 的 DNS over HTTPS。"
echo "提示：如果 /etc/resolv.conf 被 NetworkManager 或其他服务覆盖，请检查系统 DNS 配置。"
