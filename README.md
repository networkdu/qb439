# qb439 – qBittorrent 4.3.9 一键安装脚本（含 439 预设）

这个仓库提供一个用于安装 **qBittorrent-nox 4.3.9（静态版）** 的一键脚本，外加一套已经调好的
**“439 预设配置”**，主要目标：

- 一条命令完成安装
- 自动应用 439 常用设置（连接数 / 多 IP 连接 / 中文界面）
- 自动进行 TCP 网络优化（BBR + fq）
- 以 systemd 服务方式运行 qBittorrent，方便开机自启和管理

---

## 功能概览

`install.sh` 会自动完成下面这些操作：

1. 安装依赖（`mediainfo` 等）
2. 下载 `x86_64-qbittorrent-nox` 4.3.9 静态二进制
3. 预运行一次 qBittorrent，用来生成最小配置文件
4. 写入 systemd 服务文件：`/etc/systemd/system/qbittorrent.service`
5. 修改 `/etc/sysctl.conf`，进行 TCP 优化（开启 BBR + fq 等）
6. 用 systemd 启动 qBittorrent 一次，让它自己把配置补全
7. 停止 qBittorrent，**在它完全停止时对配置文件打 439 补丁**
8. 再次启动 qBittorrent，使用补丁后的配置运行

> 关键点：补丁在 **qBittorrent 完全停止** 后写入，避免配置被程序覆盖。

---

## 439 预设内容

安装完成后，脚本会确保在：

- `/root/.config/qBittorrent/qBittorrent.conf`

中追加如下配置：

```ini
[Preferences]
General\Locale=zh_CN
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxUploads=-1
Bittorrent\MaxUploadsPerTorrent=-1

[BitTorrent]
Session\MultiConnectionsPerIp=true
```

含义说明：

- `General\Locale=zh_CN`  
  WebUI 默认语言为 **简体中文**
- `Bittorrent\MaxConnecs=-1` 等四项  
  全局 / 每 Torrent 连接数与上传槽数量均设为 `-1`，相当于**不限制**
- `[BitTorrent] Session\MultiConnectionsPerIp=true`  
  允许来自同一 IP 的多个连接（配合 439 使用的常见需求）

以上配置已经在实际环境中手工验证过，确认 **qBittorrent 4.3.9 可以识别并保留**。

---

## TCP 网络优化

脚本会向 `/etc/sysctl.conf` 追加一组 TCP 相关参数，并通过 `sysctl -p && sysctl --system`
应用，核心包括：

- `net.core.default_qdisc=fq`
- `net.ipv4.tcp_congestion_control=bbr`
- 以及一组 TCP 缓冲 / 窗口相关设置

这些设置主要针对高并发长连接场景，对 BT / PT 下载较友好。

---

## 使用说明

### 环境要求

- 系统：Debian/Ubuntu 系（需要 root 权限）
- 架构：x86_64（对应 qBittorrent 静态二进制）
- 网络：能访问 GitHub 下载二进制文件

### 安装步骤

1. 把 `install.sh` 上传到服务器（例如放在 `/root`）
2. 赋予执行权限：

   ```bash
   chmod +x install.sh
   ```

3. 使用 root 执行：

   ```bash
   ./install.sh
   ```

4. 安装完成后，查看服务状态：

   ```bash
   systemctl status qbittorrent --no-pager
   ```

5. 浏览器访问 WebUI：

   ```
   http://<服务器IP>:8080
   ```

   默认登录信息：

   - 用户名：`admin`
   - 密码：`adminadmin`

   建议首次登录后立即在 WebUI 中修改密码。

---

## 文件路径约定

- qBittorrent 二进制：`/root/x86_64-qbittorrent-nox`
- 配置目录：`/root/.config/qBittorrent/`
- 主配置文件：`/root/.config/qBittorrent/qBittorrent.conf`
- systemd 单元：`/etc/systemd/system/qbittorrent.service`

默认以 **root 用户** 运行 qBittorrent（与原脚本保持一致）。

---

## 重要实现细节

为了避免 qBittorrent 启动 / 退出时覆盖配置，本脚本遵循以下顺序：

1. 预跑 `qbittorrent-nox` 一次 → 生成最小配置
2. 写入 systemd 服务配置
3. 使用 systemd 启动 qBittorrent 一次 → 让程序自己补全配置
4. 停止 qBittorrent → 确保所有配置写回磁盘
5. 此时使用 `cat >>` 的方式向 `qBittorrent.conf` **追加** 439 预设配置
6. 再次启动 qBittorrent → 使用补丁后的配置运行

这里刻意选择 **“追加配置块”** 而不是用 `sed` 替换行：

- qBittorrent 支持重复的 `[Preferences]` 段和重复的键名，后出现的值会生效
- 追加方式更稳，不会因为反斜杠转义、正则匹配失败而导致脚本“看起来执行成功但实际没改到”

---

## 风险与免责声明

本脚本会修改：

- `/etc/sysctl.conf`
- `/etc/systemd/system/qbittorrent.service`
- `/root/.config/qBittorrent/qBittorrent.conf`

请在生产环境使用前 **仔细阅读脚本内容并自行评估风险**。

---

## 后续可以扩展的方向

- 自动设置下载目录（如 `/data/downloads`）及权限
- 自动开放防火墙端口
- 定时更新 Tracker 列表
- 增加日志与调试模式
- 增加版本号 / CHANGELOG 管理

欢迎在此基础上继续改进。
