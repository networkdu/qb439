#!/bin/bash

set -e

# 定义变量
DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/x86_64-qbittorrent-nox"
INSTALL_PATH="/root/x86_64-qbittorrent-nox"
SERVICE_FILE="/etc/systemd/system/qbittorrent.service"

# 下载 qBittorrent-nox
cd /root
wget -O x86_64-qbittorrent-nox "$DOWNLOAD_URL"
chmod +x x86_64-qbittorrent-nox

# 运行一次以生成默认配置
./x86_64-qbittorrent-nox <<< "y" &
sleep 2
pkill -f x86_64-qbittorrent-nox || true

# 创建 Systemd 服务文件
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=qBittorrent Daemon Service
After=network.target

[Service]
LimitNOFILE=512000
User=root
ExecStart=$INSTALL_PATH

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 Systemd 配置
systemctl daemon-reload

# 启动并启用 qBittorrent 服务
systemctl start qbittorrent
systemctl enable qbittorrent
systemctl restart qbittorrent
# 打印服务状态
systemctl status qbittorrent --no-pager

# 提示用户访问信息
echo "qBittorrent 已成功安装和配置。"
echo "请访问 http://<你的公网IP>:8080 进行登录。"
echo "默认用户名: admin"
echo "默认密码: adminadmin"
