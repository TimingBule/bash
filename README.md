# bash
myself scropt

改进点
自动检测 CPU 架构

aarch64 -> 选择 linux-arm64 版本（适用于 64 位 ARM）
armv7l -> 选择 linux-armv7 版本（适用于 32 位 ARM）
如果架构不支持，会退出并提示错误。
自动获取 node_exporter 最新版本

wget 拉取 GitHub API，解析最新版本号并下载。
兼容 systemd 服务

运行 systemctl enable --now node_exporter，确保 node_exporter 在系统启动时自动运行。
