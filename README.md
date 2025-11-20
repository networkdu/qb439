# qb439 – qBittorrent 4.3.9 Auto Installer with 439 Preset

This repo provides an automatic installer for **qBittorrent-nox 4.3.9 (static)**,
plus a **preconfigured “439” preset** for connections and WebUI behavior.

The goal is:
- One command to install qBittorrent 4.3.9
- Automatically apply preferred 439 settings
- Automatically tune TCP (BBR + fq)
- Run qBittorrent as a systemd service

---

## What the Script Does

`install.sh` will:

1. Install dependencies
2. Download `x86_64-qbittorrent-nox` 4.3.9
3. Run qBittorrent once to generate the initial config
4. Create a systemd service (`qbittorrent.service`)
5. Apply TCP tuning via `/etc/sysctl.conf`
6. Start qBittorrent via systemd once to let it extend `qBittorrent.conf`
7. **Stop qBittorrent, patch the config, then start it again**
   - This timing is intentional and important.

---

## 439 Preset Details

After installation, the following configuration is guaranteed to be present in
`/root/.config/qBittorrent/qBittorrent.conf`:

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

That means:

- WebUI language: **Simplified Chinese (zh_CN)**
- Connection limits: effectively **unlimited** (by using `-1`)
- Allows multiple peer connections from the **same IP**

These values were manually tested and confirmed to be recognized and preserved
by qBittorrent 4.3.9.

---

## TCP Tuning

The script also configures:

- `net.core.default_qdisc=fq`
- `net.ipv4.tcp_congestion_control=bbr`
- plus additional TCP buffer and behavior tweaks

These are appended to `/etc/sysctl.conf` and applied via:

```bash
sysctl -p && sysctl --system
```

---

## Requirements

- OS: Debian/Ubuntu-based Linux (root access)
- Architecture: x86_64 (for the static qBittorrent binary)
- Network: able to reach GitHub to download the binary

---

## Usage

1. Upload `install.sh` to your server (e.g. to `/root`)
2. Make it executable:

   ```bash
   chmod +x install.sh
   ```

3. Run it as root:

   ```bash
   ./install.sh
   ```

4. When finished, check service status:

   ```bash
   systemctl status qbittorrent --no-pager
   ```

5. Open your browser:

   ```
   http://<服务器IP>:8080
   ```

   Default WebUI credentials:

   - **Username**: `admin`
   - **Password**: `adminadmin`

   You should change these from the WebUI settings after first login.

---

## Where Things Are Installed

- qBittorrent binary: `/root/x86_64-qbittorrent-nox`
- Config directory: `/root/.config/qBittorrent/`
- Main config: `/root/.config/qBittorrent/qBittorrent.conf`
- Systemd unit: `/etc/systemd/system/qbittorrent.service`

---

## Notes

- The script assumes qBittorrent runs as **root** (consistent with the original design).
- The config patch is applied **only when qB is fully stopped** to avoid race conditions.
- The patch is **idempotent**: if key 439 config is already present, it will skip appending.

---

## Disclaimer

Use at your own risk. This script modifies:

- `/etc/sysctl.conf`
- `/etc/systemd/system/qbittorrent.service`
- `/root/.config/qBittorrent/qBittorrent.conf`

Review the script before running it on production systems.
