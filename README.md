# Yori-AV 🛡️
**Terminal / Termux Anti-Virus, Cleaner & Optimizer**  
Author: **SparkyNox** | Version: 1.0.0

---

## Features

| Module | Description |
|---|---|
| 🛡 Virus Scanner | Heuristic scan with 18 signature rules |
| 🧹 Temp Cleaner | Clears /tmp, cache, pkg cache, old logs |
| ⚡ Optimizer | RAM analysis, process killer, storage breakdown, network stats |
| 📋 Quarantine | Isolate & restore suspicious files |
| 📜 Logs | Persistent color-coded scan history |

---

## Install (Termux)

```bash
# 1. Clone or copy yori-av.sh to your device
# 2. Run the installer:
bash install.sh

# Or manually:
cp yori-av.sh $PREFIX/bin/yori-av
chmod +x $PREFIX/bin/yori-av
yori-av
```

## Install (Linux)

```bash
sudo cp yori-av.sh /usr/local/bin/yori-av
sudo chmod +x /usr/local/bin/yori-av
yori-av
```

---

## Usage

```
yori-av          # Launch interactive TUI menu
```

### Menu Overview
```
[1] Virus Scanner
    ├── Quick Scan     (home directory)
    ├── Full Scan      (all accessible paths)
    ├── Custom Path
    └── Single File

[2] Temp Cleaner
    ├── Clean Temp Files
    ├── Clean Package Cache
    ├── Clean Log Files
    ├── Deep Clean (all)
    └── Dry Run (preview)

[3] System Optimizer
    ├── System Info
    ├── Kill Background Processes
    ├── RAM Usage Analysis
    ├── Storage Breakdown
    ├── Network Stats
    └── Full Optimization

[4] Quarantine Vault
[5] View Logs
[6] About
```

---

## Virus Signatures Included

- PHP webshells (base64 eval, `$_GET`/`$_POST` exec)
- Bash/Python/Netcat reverse shells
- Download & execute droppers (`wget|curl` pipe to bash)
- Crypto miner patterns (xmrig, minerd)
- Disk wipe attempts (`dd`, destructive `rm`)
- Firewall flush scripts
- EICAR test virus
- Tor hidden service references
- Persistent background loop patterns

---

## Files & Paths

| Path | Purpose |
|---|---|
| `~/yori-av.log` | Scan & action log |
| `~/.yori_quarantine/` | Quarantined files |

---

## Requirements

- `bash` 4+
- `grep` with `-P` (PCRE) support
- `find`, `du`, `df`, `ps` (standard)
- Optional: `ss` or `netstat` for network stats

> Works on Termux (Android) and standard Linux distros.

---

## Disclaimer

Yori-AV uses heuristic/pattern-based detection — not a replacement for a full AV engine. Use as a first-line defense and cleanup tool.
