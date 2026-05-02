#!/data/data/com.termux/files/usr/bin/bash
# ══════════════════════════════════════════
#   Yori-AV Installer — by SparkyNox
# ══════════════════════════════════════════

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${C}  ┌─────────────────────────────────┐${NC}"
echo -e "${C}  │   Yori-AV Installer v1.0.0      │${NC}"
echo -e "${C}  │   by SparkyNox                  │${NC}"
echo -e "${C}  └─────────────────────────────────┘${NC}"
echo ""

# Detect environment
if [ -d "/data/data/com.termux/files" ]; then
  ENV="termux"
  BIN="/data/data/com.termux/files/usr/bin"
  echo -e "  ${G}✔${NC} Detected: ${W}Termux (Android)${NC}"
else
  ENV="linux"
  BIN="/usr/local/bin"
  echo -e "  ${G}✔${NC} Detected: ${W}Linux${NC}"
fi

# Check bash version
BASH_VER="${BASH_VERSINFO[0]}"
if [ "$BASH_VER" -lt 4 ]; then
  echo -e "  ${R}✘ Bash 4+ required. Found: $BASH_VERSION${NC}"
  exit 1
fi
echo -e "  ${G}✔${NC} Bash version: ${W}$BASH_VERSION${NC}"

# Check grep PCRE
if echo "test" | grep -qP "test" 2>/dev/null; then
  echo -e "  ${G}✔${NC} grep PCRE: ${W}supported${NC}"
else
  echo -e "  ${Y}⚠${NC}  grep -P not supported — virus scanner may have limited detection"
fi

# Copy script
SCRIPT_SRC="$(dirname "$0")/yori-av.sh"
if [ ! -f "$SCRIPT_SRC" ]; then
  # Try same directory as installer
  SCRIPT_SRC="./yori-av.sh"
fi

if [ ! -f "$SCRIPT_SRC" ]; then
  echo -e "  ${R}✘ yori-av.sh not found. Place it in the same folder as this installer.${NC}"
  exit 1
fi

echo -e "  ${DIM}Installing to $BIN/yori-av ...${NC}"

if [ "$ENV" = "linux" ] && [ "$EUID" -ne 0 ]; then
  echo -e "  ${Y}⚠${NC}  Linux install to /usr/local/bin requires sudo."
  echo -e "  ${DIM}  Trying with sudo...${NC}"
  sudo cp "$SCRIPT_SRC" "$BIN/yori-av"
  sudo chmod +x "$BIN/yori-av"
else
  cp "$SCRIPT_SRC" "$BIN/yori-av"
  chmod +x "$BIN/yori-av"
fi

if [ $? -eq 0 ]; then
  echo -e "\n  ${G}✔  Yori-AV installed successfully!${NC}"
  echo -e "\n  ${W}Run it anytime with:${NC}  ${C}yori-av${NC}\n"
else
  echo -e "\n  ${R}✘ Installation failed. Try manually:${NC}"
  echo -e "  ${DIM}cp yori-av.sh $BIN/yori-av && chmod +x $BIN/yori-av${NC}\n"
  exit 1
fi
