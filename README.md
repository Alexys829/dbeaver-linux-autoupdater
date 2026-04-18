# 🦫 DBeaver Linux Auto-Updater

> Tired of manually checking and installing DBeaver updates on Linux? This tool hooks into your app launcher and automatically checks for new releases every time you open DBeaver.

A lightweight Bash solution for **Debian/Ubuntu-based distros** (Ubuntu, Kubuntu, Linux Mint, Pop!_OS, Debian, etc.) that:
- Checks the installed version against the **latest GitHub release**
- **Asks the user** before downloading anything
- Downloads and installs the official `.deb` only if confirmed
- Falls back to launching DBeaver as-is on any error (network, download, install)
- Sends a **desktop notification** with the result

---

## 📋 Requirements

- Debian/Ubuntu-based Linux distro
- `curl` (usually pre-installed)
- `dpkg` / `apt`
- DBeaver Community installed via `.deb` package
- `notify-send` for desktop notifications (optional — gracefully skipped if missing)

---

## 🚀 Installation

### One-liner

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Alexys829/dbeaver-linux-autoupdater/main/setup.sh)
```

### Manual (clone the repo)

```bash
git clone https://github.com/Alexys829/dbeaver-linux-autoupdater.git
cd dbeaver-linux-autoupdater
chmod +x setup.sh
./setup.sh
```

The setup script will:
1. Create `/usr/local/bin/dbeaver-update` — the updater script
2. Make it executable
3. Find and copy the system `.desktop` file to `~/.local/share/applications/` (if not already there)
4. Patch the `Exec=` line to run the updater before launching DBeaver
5. Refresh the application launcher database

> You will be prompted for your `sudo` password once, to write to `/usr/local/bin/`.

---

## ⚙️ How it works

```
Click DBeaver in app menu
        │
        ▼
 dbeaver-update runs
        │
        ├─ Already up to date?   → notify ✅ → launch DBeaver
        │
        ├─ New version found?    → ask user [Y/n]
        │       ├─ Y → download .deb → install → notify 🎉 → launch DBeaver
        │       └─ N → launch DBeaver immediately
        │
        └─ Network/install error → notify ⚠️  → launch DBeaver anyway
```

The updater fetches version info from the official GitHub Releases API:
```
https://api.github.com/repos/dbeaver/dbeaver/releases/latest
```
No scraping, no third-party sources — always official.

---

## 🖥️ Usage after setup

You can also run the updater manually at any time from the terminal:

```bash
dbeaver-update
```

---

## 🔔 Desktop Notifications

| Event | Notification |
|---|---|
| Already up to date | `✅ Già aggiornato (X.X.X)` |
| Updated successfully | `🎉 Aggiornato a X.X.X!` |
| Network error | `⚠️ Impossibile verificare aggiornamenti` |
| Download/install failed | `❌ Download/installazione fallita` |

Notifications require `libnotify-bin`:
```bash
sudo apt install libnotify-bin
```

---

## 🧪 Tested on

| Distro | Status |
|--------|--------|
| Ubuntu 22.04 / 24.04 | ✅ |
| Kubuntu 22.04 / 24.04 | ✅ |
| Linux Mint 21.x | ✅ |
| Debian 12 (Bookworm) | ✅ |
| Pop!_OS 22.04 | ✅ |

---

## 🗑️ Uninstall

```bash
# Rimuovi lo script updater
sudo rm /usr/local/bin/dbeaver-update

# Ripristina il launcher originale
rm ~/.local/share/applications/dbeaver-ce.desktop
update-desktop-database ~/.local/share/applications/
```

---

## 📄 License

MIT — do whatever you want with it.
