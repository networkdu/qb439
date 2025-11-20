
# qBittorrent 4.3.9 Auto-Install + 439 Configuration Patch

This README documents the design, reasoning, and implementation details of the
**automatic qBittorrent 4.3.9 installer with 439‑style WebUI/network configuration patching**.

It also includes *critical notes for future maintainers or AIs (including ChatGPT)*,
based on lessons learned during debugging in this session.

---

# ⭐ Overview

This project provides an installation script (`install.sh`) for:

- qBittorrent-nox **4.3.9 static build**
- Automatic first-run initialization
- Automatic application of **439 preset configurations**
- Automatic TCP optimization (BBR + fq)
- Fully systemd‑managed service

A key feature is the **safe, deterministic, robust configuration patching** that works
even when qBittorrent internally rewrites its own config file.

---

# ✔ What exactly is the “439 Configuration Patch”?

After installation, the script ensures that the following preferences are ALWAYS applied:

### `[Preferences]`
```
General\Locale=zh_CN
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxUploads=-1
Bittorrent\MaxUploadsPerTorrent=-1
```

### `[BitTorrent]`
```
Session\MultiConnectionsPerIp=true
```

These reflect your final validated values, tested manually for correctness.

---

# 🔥 Why was this scripting task so tricky?

**Because qBittorrent rewrites configuration internally**, and sed‑based editing cannot
be assumed safe unless the editor understands the *exact semantics* of qB's config parser.

Key difficulties you encountered:

## 1. qB writes its config *during startup AND shutdown*
If the script edits config while qB is running, qB overwrites the values.

### ❗Critical rule:
> **Always stop qBittorrent before writing to `qBittorrent.conf`.**

We now follow this strictly.

---

## 2. Using sed regex with backslashes (`\`) is error‑prone  
The config keys contain literal backslashes:

```
Bittorrent\MaxConnecs
```

But sed requires escaping:

```
Bittorrent\MaxConnecs
```

Different shells, encodings, and quoting can break this silently.

**Solution**: avoid sed entirely for patch insertion.

---

## 3. qBittorrent accepts duplicate sections and duplicate keys  
qB merges later keys and sections, e.g.:

```
[Preferences]
General\Locale=zh_CN
```

even if another `[Preferences]` exists above.

This allows a **simplest & safest** patch method:

> **Append a fully-formed configuration block to the end of the file.**
>  
> qB will use the newer values automatically.

This is the key breakthrough that made stabilization possible.

---

# 🧠 Key Lessons Learned (for future maintainers / AIs)

1. **Never modify `qBittorrent.conf` while qB is running**
2. **Do not rely on sed for key matching unless absolutely required**
3. **Appending config blocks is safer than replacing lines**
4. **qbittorrent-nox generates minimal config in "first run" but adds more keys in “first systemd run”**
5. **The correct sequence is essential**:
   1. Pre-run qbittorrent-nox (generate file)
   2. Start via systemd (qB writes more defaults)
   3. Stop qB (flush config)
   4. Patch config (safe to modify)
   5. Start qB again (patches applied)

---

# 🚀 Recommended Installation Sequence (as used in script)

```
1. Download x86_64-qbittorrent-nox
2. First-run qbittorrent-nox to generate minimal config
3. Create systemd service
4. Start service once to let qB update config
5. Stop service to flush final config to disk
6. Apply 439 patch (append block)
7. Restart qB to load patched values
```

This ensures 100% deterministic behavior.

---

# 📦 Files Included

- `install.sh` – main installer script
- This `README.md`

---

# 🛠 Future Improvement Ideas

1. Add optional:
   - Auto tracker updater
   - Auto directory layout (`/data/downloads`)
   - Auto firewall opening
2. Add logging & debug mode
3. Add checksum verification for qBittorrent binary
4. Add "idempotent patcher" that cleans old values before writing new ones

---

# 🧩 Notes to Future AI Assistants

If you (AI) must update or extend this script:

- **Preserve the startup → stop → patch sequence**
- **Do not modify config while qB is running**
- **Prefer append-over-replace unless specifically required**
- **Always evaluate the actual config file after running qB**
- **Remember: this script must run correctly on minimal environments**

---

# 🙏 Acknowledgements

This entire design was hardened through iterative manual testing,
strict control‑variable methodology, and detailed behavioral validation of qBittorrent.

Use this script confidently, knowing the failure modes have been understood.

