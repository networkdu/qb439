#!/bin/bash
apt update -y
apt install mediainfo -y
set -e

# 定义变量
DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/x86_64-qbittorrent-nox"
INSTALL_PATH="/root/x86_64-qbittorrent-nox"
SERVICE_FILE="/etc/systemd/system/qbittorrent.service"
QB_CONFIG_FILE="/root/.config/qBittorrent/qBittorrent.conf"

########################################
# 439 配置补丁函数（只在 qB 完全停止时调用）
########################################
patch_qb439_conf() {
  local CONF="$QB_CONFIG_FILE"

  echo "==> 应用 439 配置补丁..."

  # 配置文件不存在就跳过
  if [ ! -f "$CONF" ]; then
    echo "  - 找不到 $CONF：$CONF"
    echo "    可能 qBittorrent 尚未成功生成配置，跳过补丁。"
    return 0
  fi

  # 如果已经有关键配置，就不再追加，避免重复
  if grep -q 'Bittorrent\\MaxConnecs' "$CONF" && grep -q 'Session\\MultiConnectionsPerIp' "$CONF"; then
    echo "  - 检测到已存在 439 相关配置，跳过追加。"
    return 0
  fi

  # 备份一份当前配置
  local bak="${CONF}.bak_$(date +%Y%m%d%H%M%S)"
  cp "$CONF" "$bak"
  echo "  - 当前配置已备份到：$bak"

  # 直接在文件末尾追加我们验证过的配置
  cat >> "$CONF" <<'EOF'

[Preferences]
General\Locale=zh_CN
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxUploads=-1
Bittorrent\MaxUploadsPerTorrent=-1

[BitTorrent]
Session\MultiConnectionsPerIp=true
EOF

  echo "  - 439 配置补丁追加完成。"
}

########################################
# TCP 调优保持你原来的逻辑
########################################
tcp_tune() {
  echo "==> 优化 TCP 设置中..."

  # 删除现有的 TCP 相关设置
  sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
  sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
  sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
  sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
  sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

  # 添加新的 TCP 优化设置
  cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=2
net.ipv4.tcp_adv_win_scale=2
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_rmem=4096 65536 37331520
net.ipv4.tcp_wmem=4096 65536 37331520
net.core.rmem_max=37331520
net.core.wmem_max=37331520
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

  # 应用系统配置
  sysctl -p && sysctl --system
  echo "TCP 设置已优化。"
}

########################################
# 主流程：严格顺序
########################################

# 1. 下载 qBittorrent-nox
cd /root
wget -O x86_64-qbittorrent-nox "$DOWNLOAD_URL"
chmod +x x86_64-qbittorrent-nox

# 2. 预跑一次，以生成基础配置并自动接受 y
./x86_64-qbittorrent-nox &        # 后台运行
sleep 2                           # 等待一点时间
echo "y" | pkill -P $$ -f x86_64-qbittorrent-nox || true  # 输入 "y" 并杀死子进程

# 3. 创建 Systemd 服务文件（保持你原来的逻辑）
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

# 4. TCP 调优（原逻辑）
tcp_tune

# 5. 重新加载 Systemd 配置
echo "重新加载 Systemd 配置"
sleep 1
systemctl daemon-reload

# 6. 第一次用 systemd 启动 qB，让它按正常方式初始化 / 扩展配置
echo "第一次启动 qBittorrent（用于初始化完整配置）"
systemctl start qbittorrent
sleep 3   # 给它一点时间写配置

# 7. 停掉 qB，保证它完成写回，再改配置（严谨点）
echo "停止 qBittorrent 以应用 439 补丁"
systemctl stop qbittorrent

# 8. 在 qB 完全停止的情况下，打 439 补丁
patch_qb439_conf

# 9. 再次启动 qB，使用补丁后的配置
echo "重新启动 qBittorrent（已应用 439 配置）"
sleep 1
systemctl start qbittorrent

# 打印服务状态
sleep 1
systemctl status qbittorrent --no-pager || true

# 提示用户访问信息
echo "qBittorrent 已成功安装和配置。"
echo "已应用 439 预设："
echo "  - General\\Locale=zh_CN"
echo "  - Bittorrent\\MaxConnecs/-PerTorrent/-Uploads/-PerTorrent=-1"
echo "  - [BitTorrent] Session\\MultiConnectionsPerIp=true"
echo "请访问 http://<你的公网IP>:8080 进行登录。"
echo "默认用户名: admin"
echo "默认密码: adminadmin"
