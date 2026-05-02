#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
#   Yori-AV — Terminal/Termux Anti-Virus, Cleaner & Optimizer
#   Author  : SparkyNox
#   Version : 1.1.0
# ═══════════════════════════════════════════════════════════════

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[1;34m'
C='\033[0;36m'; M='\033[0;35m'; W='\033[1;37m'; DIM='\033[2m'
BOLD='\033[1m'; BLINK='\033[5m'; NC='\033[0m'

# ─── Paths ─────────────────────────────────────────────────────
if [ -d "/data/data/com.termux/files" ]; then
  PREFIX="/data/data/com.termux/files/usr"
  HOME_DIR="/data/data/com.termux/files/home"
  IS_TERMUX=true
else
  PREFIX="/usr"
  HOME_DIR="$HOME"
  IS_TERMUX=false
fi

MAIN_STORAGE="$HOME/storage/shared"
SDCARD_ID=""
for d in /storage/*/; do
  id=$(basename "$d")
  if [[ "$id" != "emulated" && "$id" != "self" && -d "$d" ]]; then
    SDCARD_ID="$id"; break
  fi
done

LOG_FILE="$HOME_DIR/yori-av.log"
QUARANTINE="$HOME_DIR/.yori_quarantine"
mkdir -p "$QUARANTINE"

SIGNATURES=(
  "eval\(base64_decode|PHP webshell (base64 eval)"
  "system\(\$_GET|PHP remote command injection"
  "exec\(\$_POST|PHP POST command exec"
  "wget.*chmod.*\+x|Download & execute dropper"
  "curl.*\|.*bash|Curl pipe to bash (dropper)"
  "python.*socket.*exec|Python reverse shell"
  "bash -i.*>&.*/dev/tcp|Bash reverse shell"
  "nc -e.*/bin/bash|Netcat reverse shell"
  "rm -rf /.*--no-preserve-root|Destructive rm command"
  "dd if=/dev/zero of=/dev|Disk wipe attempt"
  "chmod 777 /etc/passwd|Passwd permission tampering"
  "iptables -F|Firewall flush script"
  "cryptominer\|minerd\|xmrig|Crypto miner binary"
  "/dev/null 2>&1 &.*while true|Background loop (miner)"
  "base64.*|.*sh|Base64 decode pipe to shell"
  "nohup.*>/dev/null.*&|Persistent background process"
  "\.onion|Tor hidden service reference"
  "EICAR-STANDARD-ANTIVIRUS-TEST-FILE|EICAR test virus"
)

# ─── Helpers ───────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

print_line() {
  local char="${1:--}"; local width=58
  printf "${DIM}%${width}s${NC}\n" | tr ' ' "$char"
}

spinner() {
  local pid=$1 msg="$2"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${frames[$i]}${NC}  ${W}%s${NC}  " "$msg"
    i=$(( (i+1) % 10 )); sleep 0.1
  done
  printf "\r  ${G}✔${NC}  ${W}%s${NC}               \n" "$msg"
}

progress_bar() {
  local current=$1 total=$2 width=40
  [ "$total" -eq 0 ] && return
  local pct=$(( current * 100 / total ))
  local filled=$(( current * width / total ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=filled; i<width; i++)); do bar+="░"; done
  printf "\r  [${G}%s${NC}] ${W}%3d%%${NC}" "$bar" "$pct"
}

human_size() {
  local b=$1
  if   [ "$b" -ge $((1024*1024*1024)) ]; then printf "%.2f GB" "$(echo "$b 1073741824" | awk '{printf "%.2f",$1/$2}')";
  elif [ "$b" -ge $((1024*1024)) ];      then printf "%.2f MB" "$(echo "$b 1048576"    | awk '{printf "%.2f",$1/$2}')";
  elif [ "$b" -ge 1024 ];                then printf "%.2f KB" "$(echo "$b 1024"       | awk '{printf "%.2f",$1/$2}')";
  else printf "%d B" "$b"; fi
}

confirm() {
  printf "  ${Y}?${NC}  ${W}%s${NC} ${DIM}[y/N]${NC} " "$1"
  read -r ans; [[ "$ans" =~ ^[Yy]$ ]]
}

pause() { printf "\n  ${DIM}Press ENTER to continue...${NC}"; read -r; }

calc_dir_size() { du -sb "$1" 2>/dev/null | awk '{print $1}' || echo 0; }

check_storage() {
  if $IS_TERMUX && [ ! -d "$MAIN_STORAGE" ]; then
    echo -e "  ${Y}⚠  Storage not accessible!${NC}"
    echo -e "  ${DIM}Run: termux-setup-storage${NC}\n"
    if confirm "Run termux-setup-storage now?"; then
      termux-setup-storage; sleep 2
    fi
  fi
}

# ─── Banner ────────────────────────────────────────────────────
banner() {
  clear
  echo ""
  echo -e "${R}  ██╗   ██╗ ██████╗ ██████╗ ██╗      █████╗ ██╗   ██╗${NC}"
  echo -e "${R}  ╚██╗ ██╔╝██╔═══██╗██╔══██╗██║     ██╔══██╗██║   ██║${NC}"
  echo -e "${Y}   ╚████╔╝ ██║   ██║██████╔╝██║     ███████║██║   ██║${NC}"
  echo -e "${Y}    ╚██╔╝  ██║   ██║██╔══██╗██║     ██╔══██║╚██╗ ██╔╝${NC}"
  echo -e "${W}     ██║   ╚██████╔╝██║  ██║███████╗██║  ██║ ╚████╔╝ ${NC}"
  echo -e "${W}     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ${NC}"
  echo ""
  echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
  echo -e "  ${C}Anti-Virus${NC} ${DIM}·${NC} ${G}Cleaner${NC} ${DIM}·${NC} ${M}Optimizer${NC}   ${DIM}by ${W}SparkyNox${NC}  ${DIM}v1.1.0${NC}"
  if $IS_TERMUX; then
    if [ -d "$MAIN_STORAGE" ]; then
      local sdinfo="${DIM}● SDCard: None${NC}"
      [ -n "$SDCARD_ID" ] && sdinfo="${G}● SDCard: $SDCARD_ID${NC}"
      echo -e "  ${G}● Storage: OK${NC}  $sdinfo"
    else
      echo -e "  ${R}● Storage: No Permission${NC} ${DIM}→ run termux-setup-storage${NC}"
    fi
  fi
  echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
  echo ""
}

# ─── Main Menu ─────────────────────────────────────────────────
main_menu() {
  banner
  echo -e "  ${BOLD}${W}MAIN MENU${NC}\n"
  echo -e "  ${C}[1]${NC}  ${W}🛡  Virus Scanner${NC}         ${DIM}Scan files for threats${NC}"
  echo -e "  ${G}[2]${NC}  ${W}🧹  Temp Cleaner${NC}          ${DIM}Remove junk & cache${NC}"
  echo -e "  ${M}[3]${NC}  ${W}⚡  System Optimizer${NC}       ${DIM}Speed up your device${NC}"
  echo -e "  ${Y}[4]${NC}  ${W}📋  View Quarantine${NC}        ${DIM}Manage quarantined files${NC}"
  echo -e "  ${B}[5]${NC}  ${W}📜  View Logs${NC}              ${DIM}See scan history${NC}"
  echo -e "  ${R}[6]${NC}  ${W}ℹ   About${NC}"
  echo -e "  ${DIM}[0]  Exit${NC}"
  echo ""
  print_line "─"
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r choice
  case "$choice" in
    1) menu_scanner ;;
    2) menu_cleaner ;;
    3) menu_optimizer ;;
    4) menu_quarantine ;;
    5) view_logs ;;
    6) about ;;
    0) echo -e "\n  ${G}Stay protected. Goodbye!${NC}\n"; exit 0 ;;
    *) echo -e "  ${R}Invalid.${NC}"; sleep 1; main_menu ;;
  esac
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 1 — VIRUS SCANNER
# ═══════════════════════════════════════════════════════════════
menu_scanner() {
  clear; banner
  echo -e "  ${BOLD}${C}🛡  VIRUS SCANNER${NC}\n"
  echo -e "  ${C}[1]${NC}  Quick Scan          ${DIM}(Termux home)${NC}"
  echo -e "  ${C}[2]${NC}  Main Storage Scan   ${DIM}(/sdcard internal)${NC}"
  echo -e "  ${C}[3]${NC}  SDCard Scan         ${DIM}(external card)${NC}"
  echo -e "  ${C}[4]${NC}  Full Scan           ${DIM}(all accessible)${NC}"
  echo -e "  ${C}[5]${NC}  Custom Path"
  echo -e "  ${C}[6]${NC}  Scan Single File"
  echo -e "  ${DIM}[0]  Back${NC}"
  echo ""
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r s
  case "$s" in
    1) run_scan "$HOME_DIR" "Quick Scan" ;;
    2) check_storage; run_scan "/storage/emulated/0" "Main Storage Scan" ;;
    3)
      if [ -n "$SDCARD_ID" ]; then run_scan "/storage/$SDCARD_ID" "SDCard Scan"
      else echo -e "  ${R}SDCard not found.${NC}"; sleep 2; menu_scanner; fi ;;
    4) check_storage; run_scan "/" "Full Scan" ;;
    5) printf "  ${W}Path${NC}: "; read -r p; run_scan "$p" "Custom Scan" ;;
    6) printf "  ${W}File path${NC}: "; read -r p; scan_single "$p" ;;
    0) main_menu ;;
    *) menu_scanner ;;
  esac
}

scan_single() {
  local file="$1"; clear; banner
  echo -e "  ${BOLD}${C}Scanning:${NC} ${W}$file${NC}\n"
  [ ! -f "$file" ] && echo -e "  ${R}File not found.${NC}" && pause && menu_scanner && return
  local hit=false
  for sig in "${SIGNATURES[@]}"; do
    local pattern="${sig%%|*}" desc="${sig##*|}"
    if grep -qiP "$pattern" "$file" 2>/dev/null; then
      echo -e "  ${BLINK}${R}⚠  THREAT DETECTED${NC}"
      echo -e "  ${R}File:${NC} $file\n  ${R}Rule:${NC} $desc"
      log "THREAT: $file | $desc"; hit=true
      if confirm "Quarantine?"; then mv "$file" "$QUARANTINE/"; echo -e "  ${Y}Quarantined.${NC}"; log "QUARANTINED: $file"; fi
      break
    fi
  done
  ! $hit && echo -e "  ${G}✔  Clean.${NC}" && log "CLEAN: $file"
  pause; menu_scanner
}

run_scan() {
  local scan_path="$1" scan_name="$2"; clear; banner
  echo -e "  ${BOLD}${C}$scan_name${NC}  ${DIM}→ $scan_path${NC}\n"
  if [ ! -d "$scan_path" ] && [ ! -f "$scan_path" ]; then
    echo -e "  ${R}Path not found: $scan_path${NC}\n  ${DIM}Tip: run termux-setup-storage first${NC}"
    pause; menu_scanner; return
  fi
  local threats=0 scanned=0 skipped=0
  local threat_list=()
  local start_time=$SECONDS
  echo -e "  ${DIM}Collecting files...${NC}"
  mapfile -t files < <(find "$scan_path" -type f 2>/dev/null | grep -v "$QUARANTINE" | head -20000)
  local total=${#files[@]}
  [ "$total" -eq 0 ] && echo -e "  ${Y}No files found.${NC}" && pause && menu_scanner && return
  echo -e "  ${DIM}Found ${W}$total${DIM} files...${NC}\n"; sleep 0.3
  for file in "${files[@]}"; do
    ((scanned++))
    progress_bar "$scanned" "$total"
    if ! file "$file" 2>/dev/null | grep -qiE "text|script|ascii"; then ((skipped++)); continue; fi
    for sig in "${SIGNATURES[@]}"; do
      local pattern="${sig%%|*}" desc="${sig##*|}"
      if grep -qiP "$pattern" "$file" 2>/dev/null; then
        ((threats++)); threat_list+=("$file||$desc"); log "THREAT: $file | $desc"; break
      fi
    done
  done
  printf "\r%70s\r" " "
  local elapsed=$(( SECONDS - start_time ))
  echo -e "\n"; print_line "═"
  echo -e "  ${BOLD}${W}SCAN COMPLETE${NC}"; print_line "─"
  echo -e "  ${W}Scanned :${NC} ${C}$scanned${NC}  ${W}Skipped:${NC} ${DIM}$skipped${NC}  ${W}Time:${NC} ${DIM}${elapsed}s${NC}"
  echo -e "  ${W}Threats :${NC} $([ "$threats" -gt 0 ] && echo "${R}${BOLD}$threats FOUND${NC}" || echo "${G}0 — Clean!${NC}")"
  print_line "─"; echo ""
  if [ "$threats" -gt 0 ]; then
    echo -e "  ${R}${BOLD}THREATS:${NC}\n"
    for t in "${threat_list[@]}"; do
      local tf="${t%%||*}" td="${t##*||}"
      echo -e "  ${R}▸${NC} ${W}$(basename "$tf")${NC}\n    ${DIM}$tf${NC}\n    ${Y}$td${NC}\n"
    done
    if confirm "Quarantine all?"; then
      for t in "${threat_list[@]}"; do
        local tf="${t%%||*}"; [ -f "$tf" ] && mv "$tf" "$QUARANTINE/" && log "QUARANTINED: $tf"
      done; echo -e "  ${G}Done.${NC}"
    fi
  fi
  log "$scan_name | Scanned:$scanned Threats:$threats"
  pause; menu_scanner
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 2 — TEMP CLEANER
# ═══════════════════════════════════════════════════════════════
menu_cleaner() {
  clear; banner
  echo -e "  ${BOLD}${G}🧹  TEMP CLEANER${NC}\n"
  echo -e "  ${G}[1]${NC}  Clean Termux Cache     ${DIM}(home/.cache, /tmp)${NC}"
  echo -e "  ${G}[2]${NC}  Clean Android Cache    ${DIM}(all app caches)${NC}"
  echo -e "  ${G}[3]${NC}  Clean Thumbnails       ${DIM}(DCIM/.thumbnails)${NC}"
  echo -e "  ${G}[4]${NC}  Clean Package Cache    ${DIM}(pkg clean)${NC}"
  echo -e "  ${G}[5]${NC}  Clean Old Logs         ${DIM}(logs >7 days)${NC}"
  echo -e "  ${G}[6]${NC}  Deep Clean ALL         ${DIM}(everything)${NC}"
  echo -e "  ${G}[7]${NC}  Preview / Dry Run"
  echo -e "  ${DIM}[0]  Back${NC}"
  echo ""
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r c
  case "$c" in
    1) clean_termux_cache ;;
    2) clean_android_cache ;;
    3) clean_thumbnails ;;
    4) clean_pkg_cache ;;
    5) clean_logs ;;
    6) deep_clean ;;
    7) dry_run ;;
    0) main_menu ;;
    *) menu_cleaner ;;
  esac
}

clean_termux_cache() {
  clear; banner
  echo -e "  ${BOLD}${G}Cleaning Termux Cache...${NC}\n"
  local total=0
  for dir in "/tmp" "$HOME_DIR/.cache" "$HOME_DIR/tmp" "$PREFIX/tmp" "$PREFIX/var/cache"; do
    [ ! -d "$dir" ] && continue
    local before=$(calc_dir_size "$dir")
    find "$dir" -mindepth 1 -not -path "$QUARANTINE/*" -delete 2>/dev/null &
    spinner $! "$dir"
    local after=$(calc_dir_size "$dir"); local freed=$(( before - after ))
    [ "$freed" -lt 0 ] && freed=0; total=$(( total + freed ))
    echo -e "   ${G}freed: $(human_size $freed)${NC}"
    log "CLEANED: $dir | $(human_size $freed)"
  done
  echo ""; print_line "─"
  echo -e "  ${G}✔  Total: ${BOLD}$(human_size $total)${NC}"; print_line "─"
  pause; menu_cleaner
}

clean_android_cache() {
  clear; banner; check_storage
  echo -e "  ${BOLD}${G}Cleaning Android App Caches...${NC}\n"
  local total=0
  local android_cache="$MAIN_STORAGE/Android/data"
  if [ ! -d "$android_cache" ]; then
    echo -e "  ${R}Cannot access $android_cache${NC}\n  ${DIM}Run termux-setup-storage first.${NC}"
    pause; menu_cleaner; return
  fi
  for appdir in "$android_cache"/*/; do
    local cachedir="$appdir/cache"
    [ ! -d "$cachedir" ] && continue
    local before=$(calc_dir_size "$cachedir")
    find "$cachedir" -mindepth 1 -delete 2>/dev/null &
    spinner $! "$(basename "$appdir")"
    local after=$(calc_dir_size "$cachedir"); local freed=$(( before - after ))
    [ "$freed" -lt 0 ] && freed=0; total=$(( total + freed ))
    [ "$freed" -gt 0 ] && echo -e "   ${G}freed: $(human_size $freed)${NC}"
    log "CLEANED: $appdir/cache | $(human_size $freed)"
  done
  if [ -n "$SDCARD_ID" ] && [ -d "/storage/$SDCARD_ID/Android/data" ]; then
    echo -e "\n  ${DIM}SDCard app caches...${NC}"
    for appdir in "/storage/$SDCARD_ID/Android/data"/*/; do
      local cachedir="$appdir/cache"
      [ ! -d "$cachedir" ] && continue
      local before=$(calc_dir_size "$cachedir")
      find "$cachedir" -mindepth 1 -delete 2>/dev/null
      local after=$(calc_dir_size "$cachedir"); local freed=$(( before - after ))
      [ "$freed" -lt 0 ] && freed=0; total=$(( total + freed ))
    done
    echo -e "  ${G}SDCard done.${NC}"
  fi
  echo ""; print_line "─"
  echo -e "  ${G}✔  Android Cache Freed: ${BOLD}$(human_size $total)${NC}"; print_line "─"
  pause; menu_cleaner
}

clean_thumbnails() {
  clear; banner; check_storage
  echo -e "  ${BOLD}${G}Cleaning Thumbnails...${NC}\n"
  local total=0
  local dirs=(
    "$MAIN_STORAGE/DCIM/.thumbnails"
    "$MAIN_STORAGE/Pictures/.thumbnails"
    "$MAIN_STORAGE/.thumbnails"
  )
  [ -n "$SDCARD_ID" ] && dirs+=("/storage/$SDCARD_ID/DCIM/.thumbnails")
  for dir in "${dirs[@]}"; do
    [ ! -d "$dir" ] && continue
    local before=$(calc_dir_size "$dir")
    find "$dir" -mindepth 1 -delete 2>/dev/null &
    spinner $! "$(basename "$(dirname "$dir")")/.thumbnails"
    local after=$(calc_dir_size "$dir"); local freed=$(( before - after ))
    [ "$freed" -lt 0 ] && freed=0; total=$(( total + freed ))
    echo -e "   ${G}freed: $(human_size $freed)${NC}"
    log "CLEANED thumbnails: $dir"
  done
  echo ""; print_line "─"
  echo -e "  ${G}✔  Thumbnails Freed: ${BOLD}$(human_size $total)${NC}"; print_line "─"
  pause; menu_cleaner
}

clean_pkg_cache() {
  clear; banner
  echo -e "  ${BOLD}${G}Cleaning Package Cache...${NC}\n"
  local before=$(calc_dir_size "$PREFIX/var/cache/apt")
  pkg clean 2>/dev/null &
  spinner $! "pkg clean"
  local after=$(calc_dir_size "$PREFIX/var/cache/apt")
  local freed=$(( before - after )); [ "$freed" -lt 0 ] && freed=0
  echo -e "\n  ${G}✔  Freed: $(human_size $freed)${NC}"
  log "PKG CACHE cleaned | $(human_size $freed)"
  pause; menu_cleaner
}

clean_logs() {
  clear; banner
  echo -e "  ${BOLD}${G}Cleaning Old Logs...${NC}\n"
  local count=0
  for dir in "/var/log" "$HOME_DIR/.local/share" "$PREFIX/var/log"; do
    [ ! -d "$dir" ] && continue
    local c=$(find "$dir" -name "*.log" -mtime +7 2>/dev/null | wc -l)
    find "$dir" -name "*.log" -mtime +7 -delete 2>/dev/null
    local c2=$(find "$dir" -name "*.log.gz" -mtime +7 2>/dev/null | wc -l)
    find "$dir" -name "*.log.gz" -mtime +7 -delete 2>/dev/null
    count=$(( count + c + c2 ))
  done
  echo -e "  ${G}✔  Removed ${W}$count${G} old log files.${NC}"
  log "LOGS: $count removed"
  pause; menu_cleaner
}

deep_clean() {
  clear; banner
  echo -e "  ${BOLD}${G}⚡ Deep Clean${NC}\n"
  confirm "Clean everything?" || { menu_cleaner; return; }
  clean_termux_cache; clean_android_cache; clean_thumbnails; clean_pkg_cache; clean_logs
  echo -e "\n  ${G}${BOLD}✔  Deep Clean Done!${NC}"; log "DEEP CLEAN done"
  pause; menu_cleaner
}

dry_run() {
  clear; banner; check_storage
  echo -e "  ${BOLD}${Y}👁  DRY RUN — Preview${NC}\n"
  local total=0
  echo -e "  ${C}Termux:${NC}"
  for dir in "/tmp" "$HOME_DIR/.cache" "$PREFIX/tmp" "$PREFIX/var/cache"; do
    [ ! -d "$dir" ] && continue
    local sz=$(calc_dir_size "$dir"); local fc=$(find "$dir" -type f 2>/dev/null | wc -l)
    printf "  ${DIM}%-38s${NC} ${Y}%-10s${NC} ${DIM}%d files${NC}\n" "$dir" "$(human_size $sz)" "$fc"
    total=$(( total + sz ))
  done
  echo -e "\n  ${C}Android Cache:${NC}"
  if [ -d "$MAIN_STORAGE/Android/data" ]; then
    local sz=$(calc_dir_size "$MAIN_STORAGE/Android/data")
    printf "  ${DIM}%-38s${NC} ${Y}%s${NC}\n" "Android/data" "$(human_size $sz)"; total=$(( total + sz ))
  fi
  echo -e "\n  ${C}Thumbnails:${NC}"
  for dir in "$MAIN_STORAGE/DCIM/.thumbnails" "$MAIN_STORAGE/.thumbnails"; do
    [ ! -d "$dir" ] && continue
    local sz=$(calc_dir_size "$dir")
    printf "  ${DIM}%-38s${NC} ${Y}%s${NC}\n" "$dir" "$(human_size $sz)"; total=$(( total + sz ))
  done
  echo ""; print_line "─"
  echo -e "  ${Y}${BOLD}Total Cleanable: $(human_size $total)${NC}"; print_line "─"
  pause; menu_cleaner
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 3 — OPTIMIZER
# ═══════════════════════════════════════════════════════════════
menu_optimizer() {
  clear; banner
  echo -e "  ${BOLD}${M}⚡  SYSTEM OPTIMIZER${NC}\n"
  echo -e "  ${M}[1]${NC}  System Info"
  echo -e "  ${M}[2]${NC}  Kill Background Processes"
  echo -e "  ${M}[3]${NC}  RAM Usage — Top Hogs"
  echo -e "  ${M}[4]${NC}  Storage Breakdown      ${DIM}(Main + SDCard)${NC}"
  echo -e "  ${M}[5]${NC}  Network Stats"
  echo -e "  ${M}[6]${NC}  Full Optimization"
  echo -e "  ${DIM}[0]  Back${NC}"
  echo ""
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r o
  case "$o" in
    1) system_info ;; 2) kill_bg_procs ;; 3) ram_analysis ;;
    4) storage_breakdown ;; 5) network_stats ;; 6) full_optimize ;;
    0) main_menu ;; *) menu_optimizer ;;
  esac
}

system_info() {
  clear; banner
  echo -e "  ${BOLD}${M}📊 SYSTEM INFO${NC}\n"; print_line "─"
  local os="Android/Termux"
  [ -f /etc/os-release ] && os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  echo -e "  ${C}OS       :${NC} ${W}$os${NC}"
  local uptime_str; uptime_str=$(uptime -p 2>/dev/null || uptime | awk -F"up " '{print $2}' | cut -d',' -f1)
  echo -e "  ${C}Uptime   :${NC} ${W}${uptime_str}${NC}"
  echo -e "  ${C}CPU      :${NC} ${W}$(grep "Hardware\|model name\|Processor" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)${NC}"
  echo -e "  ${C}Load     :${NC} ${W}$(awk '{print $1,$2,$3}' /proc/loadavg 2>/dev/null)${NC}"
  if [ -f /proc/meminfo ]; then
    local mt=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mf=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mu=$(( mt - mf )); local mp=$(( mu * 100 / mt ))
    local bar="" bf=$(( mp * 20 / 100 ))
    for ((i=0;i<bf;i++)); do bar+="█"; done
    for ((i=bf;i<20;i++)); do bar+="░"; done
    local col=$G; [ $mp -gt 70 ] && col=$Y; [ $mp -gt 90 ] && col=$R
    echo -e "  ${C}RAM      :${NC} ${col}${bar}${NC} ${W}${mp}%${NC} ${DIM}($(human_size $((mu*1024))) / $(human_size $((mt*1024))))${NC}"
  fi
  echo -e "\n  ${C}Storage:${NC}"
  df -h 2>/dev/null | grep -v tmpfs | grep -v "Filesystem" | while read -r l; do echo -e "  ${DIM}$l${NC}"; done
  [ -n "$SDCARD_ID" ] && echo -e "\n  ${C}SDCard ($SDCARD_ID):${NC}" && df -h "/storage/$SDCARD_ID" 2>/dev/null | tail -1 | while read -r l; do echo -e "  ${DIM}$l${NC}"; done
  print_line "─"; pause; menu_optimizer
}

kill_bg_procs() {
  clear; banner
  echo -e "  ${BOLD}${M}🔪 KILL BACKGROUND PROCESSES${NC}\n"
  local killed=0
  for proc in wget curl python node ruby perl php nc ncat; do
    local pids=$(pgrep -x "$proc" 2>/dev/null)
    [ -z "$pids" ] && continue
    echo -e "  ${Y}Found: ${W}$proc${NC} ${DIM}(PIDs: $pids)${NC}"
    if confirm "Kill '$proc'?"; then
      kill $pids 2>/dev/null && echo -e "  ${G}  Killed.${NC}" && ((killed++))
      log "KILLED: $proc"
    fi
  done
  [ "$killed" -eq 0 ] && echo -e "  ${G}✔  Nothing suspicious found.${NC}"
  pause; menu_optimizer
}

ram_analysis() {
  clear; banner
  echo -e "  ${BOLD}${M}🧠 RAM — TOP PROCESSES${NC}\n"; print_line "─"
  printf "  ${C}%-30s %8s %8s${NC}\n" "PROCESS" "PID" "MEM%"; print_line "─"
  ps aux --sort=-%mem 2>/dev/null | head -12 | tail -10 | while read -r line; do
    local name=$(echo "$line" | awk '{print $11}' | xargs basename 2>/dev/null | cut -c1-28)
    local pid=$(echo "$line" | awk '{print $2}')
    local mem=$(echo "$line" | awk '{print $4}')
    local col=$G; local mp=$(echo "$mem" | cut -d. -f1)
    [ "${mp:-0}" -gt 5 ] && col=$Y; [ "${mp:-0}" -gt 15 ] && col=$R
    printf "  ${W}%-30s${NC} ${DIM}%8s${NC} ${col}%7s%%${NC}\n" "$name" "$pid" "$mem"
  done
  print_line "─"; pause; menu_optimizer
}

storage_breakdown() {
  clear; banner; check_storage
  echo -e "  ${BOLD}${M}💾 STORAGE BREAKDOWN${NC}\n"; print_line "─"
  echo -e "  ${C}Main Storage — Top 10:${NC}\n"
  if [ -d "$MAIN_STORAGE" ]; then
    du -sh "$MAIN_STORAGE"/*/ 2>/dev/null | sort -rh | head -10 | while read -r sz path; do
      printf "  ${Y}%10s${NC}  ${W}%s${NC}\n" "$sz" "$(basename "$path")"
    done
  else
    echo -e "  ${DIM}Not accessible.${NC}"
  fi
  if [ -n "$SDCARD_ID" ]; then
    echo -e "\n  ${C}SDCard ($SDCARD_ID) — Top 5:${NC}\n"
    du -sh "/storage/$SDCARD_ID"/*/ 2>/dev/null | sort -rh | head -5 | while read -r sz path; do
      printf "  ${Y}%10s${NC}  ${W}%s${NC}\n" "$sz" "$(basename "$path")"
    done
  fi
  echo ""; print_line "─"
  df -h 2>/dev/null | grep -v tmpfs | grep -v devtmpfs | while read -r l; do echo -e "  ${DIM}$l${NC}"; done
  print_line "─"; pause; menu_optimizer
}

network_stats() {
  clear; banner
  echo -e "  ${BOLD}${M}🌐 NETWORK STATS${NC}\n"; print_line "─"
  local ip=$(ip addr 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
  echo -e "  ${C}Local IP :${NC} ${W}${ip:-N/A}${NC}"
  echo -e "  ${C}Hostname :${NC} ${W}$(hostname 2>/dev/null)${NC}"
  echo -e "\n  ${C}Connections:${NC}"
  if command -v ss &>/dev/null; then
    ss -tnp 2>/dev/null | head -8 | while read -r l; do echo -e "  ${DIM}$l${NC}"; done
  else echo -e "  ${DIM}(ss not available)${NC}"; fi
  if [ -f /proc/net/dev ]; then
    echo -e "\n  ${C}Interface Stats:${NC}"
    tail -n +3 /proc/net/dev | while read -r line; do
      local iface=$(echo "$line" | awk -F: '{print $1}' | xargs)
      local rx=$(echo "$line" | awk '{print $2}')
      local tx=$(echo "$line" | awk '{print $10}')
      [ -n "$iface" ] && printf "  ${W}%-12s${NC} ${G}RX:%-12s${NC} ${M}TX:%s${NC}\n" "$iface" "$(human_size $rx)" "$(human_size $tx)"
    done
  fi
  print_line "─"; pause; menu_optimizer
}

full_optimize() {
  clear; banner
  echo -e "  ${BOLD}${M}⚡ FULL OPTIMIZATION${NC}\n"
  confirm "Run all optimizations?" || { menu_optimizer; return; }
  echo -e "\n  ${W}[1/3] Syncing...${NC}"
  sync 2>/dev/null &
  spinner $! "sync"
  echo -e "  ${W}[2/3] Cache drop...${NC}"
  if [ -w /proc/sys/vm/drop_caches ]; then echo 3>/proc/sys/vm/drop_caches 2>/dev/null && echo -e "  ${G}  Done.${NC}"
  else echo -e "  ${DIM}  Skipped (no root)${NC}"; fi
  echo -e "  ${W}[3/3] Processes: $(ps aux 2>/dev/null | wc -l) running${NC}"
  echo ""; print_line "─"; echo -e "  ${M}${BOLD}✔  Done!${NC}"; print_line "─"
  log "FULL OPTIMIZE done"; pause; menu_optimizer
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 4 — QUARANTINE
# ═══════════════════════════════════════════════════════════════
menu_quarantine() {
  clear; banner
  echo -e "  ${BOLD}${Y}📋  QUARANTINE VAULT${NC}"
  echo -e "  ${DIM}$QUARANTINE${NC}\n"; print_line "─"
  local files=("$QUARANTINE"/*)
  if [ ! -e "${files[0]}" ]; then
    echo -e "  ${G}✔  Quarantine is empty.${NC}"; pause; main_menu; return
  fi
  local i=1; declare -A fmap
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    printf "  ${Y}[%d]${NC} ${W}%-40s${NC} ${DIM}%s${NC}\n" "$i" "$(basename "$f")" "$(du -sh "$f" 2>/dev/null | cut -f1)"
    fmap[$i]="$f"; ((i++))
  done
  print_line "─"
  echo -e "  ${R}[D]${NC} Delete all  ${G}[R]${NC} Restore  ${DIM}[0]  Back${NC}"
  echo ""; printf "  ${W}Select${NC} ${DIM}›${NC} "; read -r q
  case "$q" in
    0) main_menu ;;
    [Dd])
      confirm "Delete ALL quarantined files?" && rm -rf "${QUARANTINE:?}"/* && echo -e "  ${R}Deleted.${NC}" && log "QUARANTINE purged"
      pause; menu_quarantine ;;
    *)
      local num="$q"
      [[ "$q" =~ ^[Rr]$ ]] && { printf "  File number: "; read -r num; }
      if [ -n "${fmap[$num]}" ]; then
        printf "  Restore to: "; read -r dest
        mv "${fmap[$num]}" "${dest:-$HOME_DIR/}" && echo -e "  ${G}Restored.${NC}" && log "RESTORED: ${fmap[$num]}"
      else echo -e "  ${R}Invalid.${NC}"; fi
      pause; menu_quarantine ;;
  esac
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 5 — LOGS
# ═══════════════════════════════════════════════════════════════
view_logs() {
  clear; banner
  echo -e "  ${BOLD}${B}📜  LOGS${NC}  ${DIM}$LOG_FILE${NC}\n"; print_line "─"
  if [ ! -f "$LOG_FILE" ]; then echo -e "  ${DIM}No logs yet.${NC}"
  else
    tail -40 "$LOG_FILE" | while read -r line; do
      if   echo "$line" | grep -q "THREAT\|VIRUS";      then echo -e "  ${R}$line${NC}"
      elif echo "$line" | grep -q "QUARANTINE\|DELETE";  then echo -e "  ${Y}$line${NC}"
      elif echo "$line" | grep -q "CLEAN\|OPTIMIZE";     then echo -e "  ${G}$line${NC}"
      else echo -e "  ${DIM}$line${NC}"; fi
    done
  fi
  print_line "─"
  echo -e "  ${R}[C]${NC} Clear  ${DIM}[0]  Back${NC}"
  printf "  ${W}›${NC} "; read -r l
  case "$l" in
    [Cc]) > "$LOG_FILE"; echo -e "  ${G}Cleared.${NC}"; sleep 1 ;;
  esac
  main_menu
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 6 — ABOUT
# ═══════════════════════════════════════════════════════════════
about() {
  clear; banner; print_line "═"
  echo -e "  ${BOLD}${W}Yori-AV  v1.1.0${NC}"; print_line "─"
  echo -e "  ${C}Author  :${NC} ${W}SparkyNox${NC}"
  echo -e "  ${C}Type    :${NC} Termux / Terminal AV + Cleaner + Optimizer"
  echo -e "  ${C}Storage :${NC} Termux + Main Storage + SDCard\n"
  echo -e "  ${G}•${NC} ${#SIGNATURES[@]} virus signatures"
  echo -e "  ${G}•${NC} Android app cache + thumbnail cleaner"
  echo -e "  ${G}•${NC} Main Storage & SDCard support"
  echo -e "  ${G}•${NC} Quarantine & restore system"
  echo -e "  ${G}•${NC} Persistent color-coded logs"
  echo ""; print_line "─"
  echo -e "  ${DIM}\"Stay clean. Stay fast. Stay protected.\"${NC}"
  print_line "═"; pause; main_menu
}

# ─── Start ─────────────────────────────────────────────────────
main_menu
