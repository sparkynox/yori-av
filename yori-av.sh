#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
#   Yori-AV — Terminal/Termux Anti-Virus, Cleaner & Optimizer
#   Author  : SparkyNox
#   Version : 1.0.0
# ═══════════════════════════════════════════════════════════════

# ─── Colors & Styles ───────────────────────────────────────────
R='\033[0;31m'   # Red
G='\033[0;32m'   # Green
Y='\033[1;33m'   # Yellow
B='\033[1;34m'   # Blue
C='\033[0;36m'   # Cyan
M='\033[0;35m'   # Magenta
W='\033[1;37m'   # White
DIM='\033[2m'
BOLD='\033[1m'
BLINK='\033[5m'
NC='\033[0m'     # Reset

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

TEMP_DIRS=(
  "/tmp"
  "/var/tmp"
  "$HOME_DIR/.cache"
  "$HOME_DIR/tmp"
)
if $IS_TERMUX; then
  TEMP_DIRS+=(
    "$PREFIX/tmp"
    "$PREFIX/var/cache"
    "$HOME_DIR/.termux/cache"
  )
fi

LOG_FILE="$HOME_DIR/yori-av.log"
QUARANTINE="$HOME_DIR/.yori_quarantine"
mkdir -p "$QUARANTINE"

# ─── Virus Signatures (heuristic patterns) ─────────────────────
# Format: "pattern|description"
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
  "/dev/null 2>&1 &.*while true|Background loop (potential miner)"
  "base64.*|.*sh|Base64 decode pipe to shell"
  "nohup.*>/dev/null.*&|Persistent background process"
  "\.onion|Tor hidden service reference"
  "EICAR-STANDARD-ANTIVIRUS-TEST-FILE|EICAR test virus"
)

# ─── Helpers ───────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

print_line() {
  local char="${1:--}"
  local width=58
  printf "${DIM}%${width}s${NC}\n" | tr ' ' "$char"
}

spinner() {
  local pid=$1
  local msg="$2"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${frames[$i]}${NC}  ${W}%s${NC}  " "$msg"
    i=$(( (i+1) % 10 ))
    sleep 0.1
  done
  printf "\r  ${G}✔${NC}  ${W}%s${NC}               \n" "$msg"
}

progress_bar() {
  local current=$1
  local total=$2
  local width=40
  local pct=$(( current * 100 / total ))
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "\r  [${G}%s${NC}${DIM}%s${NC}] ${W}%3d%%${NC}" "$bar" "" "$pct"
}

human_size() {
  local bytes=$1
  if   [ "$bytes" -ge $((1024*1024*1024)) ]; then printf "%.2f GB" "$(echo "$bytes 1073741824" | awk '{printf "%.2f", $1/$2}')";
  elif [ "$bytes" -ge $((1024*1024)) ];      then printf "%.2f MB" "$(echo "$bytes 1048576"    | awk '{printf "%.2f", $1/$2}')";
  elif [ "$bytes" -ge 1024 ];                then printf "%.2f KB" "$(echo "$bytes 1024"       | awk '{printf "%.2f", $1/$2}')";
  else printf "%d B" "$bytes"; fi
}

confirm() {
  local prompt="$1"
  printf "  ${Y}?${NC}  ${W}%s${NC} ${DIM}[y/N]${NC} " "$prompt"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

pause() { printf "\n  ${DIM}Press ENTER to continue...${NC}"; read -r; }

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
  echo -e "  ${C}Anti-Virus${NC} ${DIM}·${NC} ${G}Cleaner${NC} ${DIM}·${NC} ${M}Optimizer${NC}   ${DIM}by ${W}SparkyNox${NC}"
  echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
  echo ""
}

# ─── Main Menu ─────────────────────────────────────────────────
main_menu() {
  banner
  echo -e "  ${BOLD}${W}MAIN MENU${NC}"
  echo ""
  echo -e "  ${C}[1]${NC}  ${W}🛡  Virus Scanner${NC}         ${DIM}Scan files for threats${NC}"
  echo -e "  ${G}[2]${NC}  ${W}🧹  Temp Cleaner${NC}          ${DIM}Remove junk & cache${NC}"
  echo -e "  ${M}[3]${NC}  ${W}⚡  System Optimizer${NC}       ${DIM}Speed up your device${NC}"
  echo -e "  ${Y}[4]${NC}  ${W}📋  View Quarantine${NC}        ${DIM}Manage quarantined files${NC}"
  echo -e "  ${B}[5]${NC}  ${W}📜  View Logs${NC}              ${DIM}See scan history${NC}"
  echo -e "  ${R}[6]${NC}  ${W}ℹ   About${NC}                  ${DIM}Info & version${NC}"
  echo -e "  ${DIM}[0]  Exit${NC}"
  echo ""
  print_line "─"
  printf "  ${W}Select option${NC} ${DIM}›${NC} "
  read -r choice
  case "$choice" in
    1) menu_scanner ;;
    2) menu_cleaner ;;
    3) menu_optimizer ;;
    4) menu_quarantine ;;
    5) view_logs ;;
    6) about ;;
    0) echo -e "\n  ${G}Stay protected. Goodbye!${NC}\n"; exit 0 ;;
    *) echo -e "  ${R}Invalid option.${NC}"; sleep 1; main_menu ;;
  esac
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 1 — VIRUS SCANNER
# ═══════════════════════════════════════════════════════════════
menu_scanner() {
  clear; banner
  echo -e "  ${BOLD}${C}🛡  VIRUS SCANNER${NC}"
  echo ""
  echo -e "  ${C}[1]${NC}  Quick Scan      ${DIM}(home dir)${NC}"
  echo -e "  ${C}[2]${NC}  Full Scan       ${DIM}(deep — all accessible paths)${NC}"
  echo -e "  ${C}[3]${NC}  Custom Path     ${DIM}(you choose)${NC}"
  echo -e "  ${C}[4]${NC}  Scan Single File"
  echo -e "  ${DIM}[0]  Back${NC}"
  echo ""
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r s
  case "$s" in
    1) run_scan "$HOME_DIR" "Quick Scan" ;;
    2) run_scan "/" "Full Scan" ;;
    3) printf "  ${W}Enter path${NC}: "; read -r p; run_scan "$p" "Custom Scan" ;;
    4) printf "  ${W}Enter file path${NC}: "; read -r p; scan_single_file "$p" ;;
    0) main_menu ;;
    *) menu_scanner ;;
  esac
}

scan_single_file() {
  local file="$1"
  clear; banner
  echo -e "  ${BOLD}${C}Scanning:${NC} ${W}$file${NC}\n"
  if [ ! -f "$file" ]; then
    echo -e "  ${R}File not found.${NC}"; pause; menu_scanner; return
  fi
  local hit=false
  for sig in "${SIGNATURES[@]}"; do
    local pattern="${sig%%|*}"
    local desc="${sig##*|}"
    if grep -qiP "$pattern" "$file" 2>/dev/null; then
      echo -e "  ${BLINK}${R}⚠  THREAT DETECTED${NC}"
      echo -e "  ${R}File   :${NC} $file"
      echo -e "  ${R}Rule   :${NC} $desc"
      echo -e "  ${R}Pattern:${NC} $pattern"
      echo ""
      log "THREAT: $file | $desc"
      hit=true
      if confirm "Quarantine this file?"; then
        mv "$file" "$QUARANTINE/"
        echo -e "  ${Y}Quarantined.${NC}"
        log "QUARANTINED: $file"
      fi
      break
    fi
  done
  if ! $hit; then
    echo -e "  ${G}✔  No threats found.${NC}"
    log "CLEAN: $file"
  fi
  pause; menu_scanner
}

run_scan() {
  local scan_path="$1"
  local scan_name="$2"
  clear; banner
  echo -e "  ${BOLD}${C}$scan_name${NC}  ${DIM}→ $scan_path${NC}\n"

  if [ ! -d "$scan_path" ] && [ ! -f "$scan_path" ]; then
    echo -e "  ${R}Path not found: $scan_path${NC}"; pause; menu_scanner; return
  fi

  local threats=0 scanned=0 skipped=0
  local threat_list=()
  local start_time=$SECONDS

  echo -e "  ${DIM}Collecting files...${NC}"
  mapfile -t files < <(find "$scan_path" -type f 2>/dev/null | grep -v "$QUARANTINE" | head -10000)
  local total=${#files[@]}

  if [ "$total" -eq 0 ]; then
    echo -e "  ${Y}No files found to scan.${NC}"; pause; menu_scanner; return
  fi

  echo -e "  ${DIM}Found ${W}$total${DIM} files. Starting scan...${NC}\n"
  sleep 0.5

  for file in "${files[@]}"; do
    ((scanned++))
    progress_bar "$scanned" "$total"
    printf "  ${DIM}%s${NC}" "$(basename "$file" | cut -c1-30)"

    # Skip binary/non-text
    if ! file "$file" 2>/dev/null | grep -qiE "text|script|ascii"; then
      ((skipped++))
      continue
    fi

    for sig in "${SIGNATURES[@]}"; do
      local pattern="${sig%%|*}"
      local desc="${sig##*|}"
      if grep -qiP "$pattern" "$file" 2>/dev/null; then
        ((threats++))
        threat_list+=("$file||$desc")
        log "THREAT: $file | $desc"
        break
      fi
    done
  done

  printf "\r%60s\r" " "
  local elapsed=$(( SECONDS - start_time ))

  # Results
  echo -e "\n"
  print_line "═"
  echo -e "  ${BOLD}${W}SCAN COMPLETE${NC}"
  print_line "─"
  echo -e "  ${W}Files Scanned  :${NC} ${C}$scanned${NC}"
  echo -e "  ${W}Files Skipped  :${NC} ${DIM}$skipped (binary)${NC}"
  echo -e "  ${W}Time Taken     :${NC} ${DIM}${elapsed}s${NC}"
  echo -e "  ${W}Threats Found  :${NC} $([ "$threats" -gt 0 ] && echo "${R}$threats${NC}" || echo "${G}0${NC}")"
  print_line "─"
  echo ""

  if [ "$threats" -gt 0 ]; then
    echo -e "  ${R}${BOLD}THREATS DETECTED:${NC}\n"
    for t in "${threat_list[@]}"; do
      local tf="${t%%||*}"
      local td="${t##*||}"
      echo -e "  ${R}▸${NC} ${W}$(basename "$tf")${NC}"
      echo -e "    ${DIM}$tf${NC}"
      echo -e "    ${Y}Rule: $td${NC}"
      echo ""
    done
    if confirm "Quarantine all threats?"; then
      for t in "${threat_list[@]}"; do
        local tf="${t%%||*}"
        [ -f "$tf" ] && mv "$tf" "$QUARANTINE/" && log "QUARANTINED: $tf"
      done
      echo -e "  ${G}All threats quarantined.${NC}"
    fi
  else
    echo -e "  ${G}✔  System is clean!${NC}"
  fi

  log "$scan_name completed. Scanned:$scanned Threats:$threats"
  pause; menu_scanner
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 2 — TEMP CLEANER
# ═══════════════════════════════════════════════════════════════
menu_cleaner() {
  clear; banner
  echo -e "  ${BOLD}${G}🧹  TEMP CLEANER${NC}\n"
  echo -e "  ${G}[1]${NC}  Clean Temp Files       ${DIM}(/tmp, cache dirs)${NC}"
  echo -e "  ${G}[2]${NC}  Clean Package Cache    ${DIM}(apt/pkg cache)${NC}"
  echo -e "  ${G}[3]${NC}  Clean Log Files        ${DIM}(old logs)${NC}"
  echo -e "  ${G}[4]${NC}  Deep Clean             ${DIM}(all of the above)${NC}"
  echo -e "  ${G}[5]${NC}  Preview (Dry Run)      ${DIM}(see what will be deleted)${NC}"
  echo -e "  ${DIM}[0]  Back${NC}"
  echo ""
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r c
  case "$c" in
    1) clean_temp ;;
    2) clean_pkg_cache ;;
    3) clean_logs ;;
    4) deep_clean ;;
    5) dry_run ;;
    0) main_menu ;;
    *) menu_cleaner ;;
  esac
}

calc_dir_size() {
  local dir="$1"
  du -sb "$dir" 2>/dev/null | awk '{print $1}' || echo 0
}

clean_temp() {
  clear; banner
  echo -e "  ${BOLD}${G}Cleaning Temp Directories...${NC}\n"
  local total_freed=0
  for dir in "${TEMP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      local before=$(calc_dir_size "$dir")
      printf "  ${DIM}Cleaning${NC} ${W}%s${NC}..." "$dir"
      find "$dir" -mindepth 1 -not -path "$QUARANTINE/*" -delete 2>/dev/null &
      spinner $! "$(basename "$dir")"
      local after=$(calc_dir_size "$dir")
      local freed=$(( before - after ))
      [ "$freed" -lt 0 ] && freed=0
      total_freed=$(( total_freed + freed ))
      echo -e "  ${G}  freed: $(human_size $freed)${NC}"
      log "CLEANED: $dir | freed $(human_size $freed)"
    fi
  done
  echo ""
  print_line "─"
  echo -e "  ${G}✔  Total Freed: ${BOLD}$(human_size $total_freed)${NC}"
  print_line "─"
  pause; menu_cleaner
}

clean_pkg_cache() {
  clear; banner
  echo -e "  ${BOLD}${G}Cleaning Package Cache...${NC}\n"
  local freed=0
  if $IS_TERMUX; then
    local before=$(calc_dir_size "$PREFIX/var/cache/apt")
    echo -e "  ${W}Running: pkg clean${NC}"
    pkg clean 2>/dev/null &
    spinner $! "pkg clean"
    local after=$(calc_dir_size "$PREFIX/var/cache/apt")
    freed=$(( before - after ))
  else
    if command -v apt-get &>/dev/null; then
      local before=$(calc_dir_size "/var/cache/apt")
      apt-get clean -y 2>/dev/null &
      spinner $! "apt-get clean"
      local after=$(calc_dir_size "/var/cache/apt")
      freed=$(( before - after ))
    fi
    if command -v pip3 &>/dev/null; then
      pip3 cache purge 2>/dev/null &
      spinner $! "pip3 cache purge"
    fi
  fi
  [ "$freed" -lt 0 ] && freed=0
  echo -e "\n  ${G}✔  Package cache freed: $(human_size $freed)${NC}"
  log "PKG CACHE cleaned | freed $(human_size $freed)"
  pause; menu_cleaner
}

clean_logs() {
  clear; banner
  echo -e "  ${BOLD}${G}Cleaning Old Log Files...${NC}\n"
  local count=0
  local log_dirs=("/var/log" "$HOME_DIR/.local/share" "$PREFIX/var/log")
  for dir in "${log_dirs[@]}"; do
    if [ -d "$dir" ]; then
      local c=$(find "$dir" -name "*.log" -mtime +7 2>/dev/null | wc -l)
      find "$dir" -name "*.log" -mtime +7 -delete 2>/dev/null
      local c2=$(find "$dir" -name "*.log.gz" -mtime +7 2>/dev/null | wc -l)
      find "$dir" -name "*.log.gz" -mtime +7 -delete 2>/dev/null
      count=$(( count + c + c2 ))
    fi
  done
  echo -e "  ${G}✔  Removed ${W}$count${G} old log files.${NC}"
  log "LOGS cleaned | $count files removed"
  pause; menu_cleaner
}

deep_clean() {
  clear; banner
  echo -e "  ${BOLD}${G}⚡ Deep Clean — All Modules${NC}\n"
  if confirm "This will clean ALL junk. Proceed?"; then
    clean_temp
    clean_pkg_cache
    clean_logs
    echo -e "\n  ${G}${BOLD}✔  Deep Clean Complete!${NC}"
    log "DEEP CLEAN completed"
    pause; menu_cleaner
  else
    menu_cleaner
  fi
}

dry_run() {
  clear; banner
  echo -e "  ${BOLD}${Y}👁  DRY RUN — Preview Only${NC}\n"
  local total=0
  for dir in "${TEMP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      local sz=$(calc_dir_size "$dir")
      local fc=$(find "$dir" -mindepth 1 -type f 2>/dev/null | wc -l)
      echo -e "  ${W}$dir${NC}"
      echo -e "  ${DIM}  Files: $fc  |  Size: $(human_size $sz)${NC}"
      total=$(( total + sz ))
    fi
  done
  echo ""
  print_line "─"
  echo -e "  ${Y}Total cleanable: ${BOLD}$(human_size $total)${NC}"
  print_line "─"
  pause; menu_cleaner
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 3 — OPTIMIZER
# ═══════════════════════════════════════════════════════════════
menu_optimizer() {
  clear; banner
  echo -e "  ${BOLD}${M}⚡  SYSTEM OPTIMIZER${NC}\n"
  echo -e "  ${M}[1]${NC}  System Info            ${DIM}CPU, RAM, Storage${NC}"
  echo -e "  ${M}[2]${NC}  Kill Background Processes ${DIM}(safe kill)${NC}"
  echo -e "  ${M}[3]${NC}  RAM Usage Analysis     ${DIM}Top memory hogs${NC}"
  echo -e "  ${M}[4]${NC}  Storage Breakdown      ${DIM}What's eating space${NC}"
  echo -e "  ${M}[5]${NC}  Network Stats          ${DIM}Connections & usage${NC}"
  echo -e "  ${M}[6]${NC}  Full Optimization      ${DIM}All-in-one boost${NC}"
  echo -e "  ${DIM}[0]  Back${NC}"
  echo ""
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r o
  case "$o" in
    1) system_info ;;
    2) kill_bg_procs ;;
    3) ram_analysis ;;
    4) storage_breakdown ;;
    5) network_stats ;;
    6) full_optimize ;;
    0) main_menu ;;
    *) menu_optimizer ;;
  esac
}

system_info() {
  clear; banner
  echo -e "  ${BOLD}${M}📊 SYSTEM INFORMATION${NC}\n"
  print_line "─"

  # OS
  local os="Unknown"
  if $IS_TERMUX; then os="Android/Termux"
  elif [ -f /etc/os-release ]; then os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  fi
  echo -e "  ${C}OS        :${NC} ${W}$os${NC}"

  # Uptime
  local uptime_str
  if command -v uptime &>/dev/null; then
    uptime_str=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | cut -d',' -f1)
  fi
  echo -e "  ${C}Uptime    :${NC} ${W}${uptime_str:-N/A}${NC}"

  # CPU
  local cpu_model
  if [ -f /proc/cpuinfo ]; then
    cpu_model=$(grep "Hardware\|model name\|Processor" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
  fi
  echo -e "  ${C}CPU       :${NC} ${W}${cpu_model:-Unknown}${NC}"

  # Load avg
  if [ -f /proc/loadavg ]; then
    local load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo -e "  ${C}Load Avg  :${NC} ${W}$load${NC}"
  fi

  # RAM
  if [ -f /proc/meminfo ]; then
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_free=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_used=$(( mem_total - mem_free ))
    local mem_pct=$(( mem_used * 100 / mem_total ))
    local mem_bar=""
    local bar_fill=$(( mem_pct * 20 / 100 ))
    for ((i=0;i<bar_fill;i++)); do mem_bar+="█"; done
    for ((i=bar_fill;i<20;i++)); do mem_bar+="░"; done
    local color=$G; [ $mem_pct -gt 70 ] && color=$Y; [ $mem_pct -gt 90 ] && color=$R
    echo -e "  ${C}RAM Used  :${NC} ${color}${mem_bar}${NC} ${W}${mem_pct}%${NC} ${DIM}($(human_size $((mem_used*1024))) / $(human_size $((mem_total*1024))))${NC}"
  fi

  # Storage
  echo -e "\n  ${C}Storage:${NC}"
  df -h 2>/dev/null | grep -E "^/|^Filesystem" | grep -v tmpfs | head -6 | while read -r line; do
    echo -e "  ${DIM}$line${NC}"
  done

  print_line "─"
  pause; menu_optimizer
}

kill_bg_procs() {
  clear; banner
  echo -e "  ${BOLD}${M}🔪 KILL BACKGROUND PROCESSES${NC}\n"
  echo -e "  ${DIM}Safe targets (non-essential):${NC}\n"

  local safe_kill=("wget" "curl" "python" "node" "ruby" "perl" "php" "nc" "ncat")
  local killed=0
  for proc in "${safe_kill[@]}"; do
    local pids
    pids=$(pgrep -x "$proc" 2>/dev/null)
    if [ -n "$pids" ]; then
      echo -e "  ${Y}Found: ${W}$proc${NC} ${DIM}(PIDs: $pids)${NC}"
      if confirm "Kill '$proc' processes?"; then
        kill $pids 2>/dev/null && echo -e "  ${G}  Killed.${NC}" && ((killed++))
        log "KILLED process: $proc PIDs:$pids"
      fi
    fi
  done
  [ "$killed" -eq 0 ] && echo -e "  ${G}✔  No suspicious background processes found.${NC}"
  pause; menu_optimizer
}

ram_analysis() {
  clear; banner
  echo -e "  ${BOLD}${M}🧠 RAM USAGE — TOP PROCESSES${NC}\n"
  print_line "─"
  printf "  ${C}%-30s %8s %8s${NC}\n" "PROCESS" "PID" "MEM%"
  print_line "─"
  ps aux --sort=-%mem 2>/dev/null | head -12 | tail -10 | while read -r line; do
    local name=$(echo "$line" | awk '{print $11}' | xargs basename 2>/dev/null | cut -c1-28)
    local pid=$(echo "$line"  | awk '{print $2}')
    local mem=$(echo "$line"  | awk '{print $4}')
    local color=$G
    local mp=$(echo "$mem" | cut -d. -f1)
    [ "${mp:-0}" -gt 5 ]  && color=$Y
    [ "${mp:-0}" -gt 15 ] && color=$R
    printf "  ${W}%-30s${NC} ${DIM}%8s${NC} ${color}%7s%%${NC}\n" "$name" "$pid" "$mem"
  done
  print_line "─"
  pause; menu_optimizer
}

storage_breakdown() {
  clear; banner
  echo -e "  ${BOLD}${M}💾 STORAGE BREAKDOWN${NC}\n"
  print_line "─"
  echo -e "  ${C}Top 10 largest directories in home:${NC}\n"
  du -sh "$HOME_DIR"/* 2>/dev/null | sort -rh | head -10 | while read -r size path; do
    printf "  ${Y}%10s${NC}  ${W}%s${NC}\n" "$size" "$(basename "$path")"
  done
  echo ""
  print_line "─"
  echo -e "  ${C}Disk Usage Summary:${NC}\n"
  df -h 2>/dev/null | grep -v tmpfs | grep -v devtmpfs | while read -r line; do
    echo -e "  ${DIM}$line${NC}"
  done
  print_line "─"
  pause; menu_optimizer
}

network_stats() {
  clear; banner
  echo -e "  ${BOLD}${M}🌐 NETWORK STATISTICS${NC}\n"
  print_line "─"

  # IP
  local ip
  ip=$(ip addr 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
  echo -e "  ${C}Local IP  :${NC} ${W}${ip:-N/A}${NC}"

  # Hostname
  echo -e "  ${C}Hostname  :${NC} ${W}$(hostname 2>/dev/null || echo N/A)${NC}"

  # Active connections
  echo -e "\n  ${C}Active Connections:${NC}"
  if command -v ss &>/dev/null; then
    ss -tnp 2>/dev/null | head -10 | while read -r line; do
      echo -e "  ${DIM}$line${NC}"
    done
  elif command -v netstat &>/dev/null; then
    netstat -tn 2>/dev/null | head -10 | while read -r line; do
      echo -e "  ${DIM}$line${NC}"
    done
  else
    echo -e "  ${DIM}(ss/netstat not available)${NC}"
  fi

  # /proc/net/dev stats
  if [ -f /proc/net/dev ]; then
    echo -e "\n  ${C}Interface Stats:${NC}"
    cat /proc/net/dev | tail -n +3 | while read -r line; do
      local iface=$(echo "$line" | awk -F: '{print $1}' | xargs)
      local rx=$(echo "$line" | awk '{print $2}')
      local tx=$(echo "$line" | awk '{print $10}')
      [ -n "$iface" ] && printf "  ${W}%-12s${NC} ${G}RX:%-12s${NC} ${M}TX:%s${NC}\n" \
        "$iface" "$(human_size $rx)" "$(human_size $tx)"
    done
  fi
  print_line "─"
  pause; menu_optimizer
}

full_optimize() {
  clear; banner
  echo -e "  ${BOLD}${M}⚡ FULL OPTIMIZATION SEQUENCE${NC}\n"
  if ! confirm "Run all optimizations? (safe, no data deleted)"; then
    menu_optimizer; return
  fi

  echo ""
  echo -e "  ${W}[1/4] Syncing filesystem...${NC}"
  sync 2>/dev/null &
  spinner $! "sync"

  echo -e "  ${W}[2/4] Flushing DNS cache (if available)...${NC}"
  (systemctl restart systemd-resolved 2>/dev/null || true) &
  spinner $! "DNS flush"

  echo -e "  ${W}[3/4] Dropping memory caches...${NC}"
  if [ -w /proc/sys/vm/drop_caches ]; then
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    echo -e "  ${G}  RAM cache dropped.${NC}"
  else
    echo -e "  ${DIM}  (no root — skipping cache drop)${NC}"
  fi

  echo -e "  ${W}[4/4] Analyzing running processes...${NC}"
  local count=$(ps aux 2>/dev/null | wc -l)
  echo -e "  ${DIM}  $count processes currently running${NC}"

  echo ""
  print_line "─"
  echo -e "  ${M}${BOLD}✔  Optimization complete!${NC}"
  print_line "─"
  log "FULL OPTIMIZE completed"
  pause; menu_optimizer
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 4 — QUARANTINE
# ═══════════════════════════════════════════════════════════════
menu_quarantine() {
  clear; banner
  echo -e "  ${BOLD}${Y}📋  QUARANTINE VAULT${NC}"
  echo -e "  ${DIM}Location: $QUARANTINE${NC}\n"
  print_line "─"

  local files=("$QUARANTINE"/*)
  if [ ! -e "${files[0]}" ]; then
    echo -e "  ${G}✔  Quarantine is empty.${NC}"
    pause; main_menu; return
  fi

  local i=1
  declare -A fmap
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    local sz=$(du -sh "$f" 2>/dev/null | cut -f1)
    printf "  ${Y}[%d]${NC} ${W}%-40s${NC} ${DIM}%s${NC}\n" "$i" "$(basename "$f")" "$sz"
    fmap[$i]="$f"
    ((i++))
  done

  print_line "─"
  echo -e "  ${R}[D]${NC}  Delete all quarantined files"
  echo -e "  ${G}[R]${NC}  Restore a file (enter number)"
  echo -e "  ${DIM}[0]  Back${NC}"
  echo ""
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r q
  case "$q" in
    0) main_menu ;;
    [Dd])
      if confirm "Permanently delete ALL quarantined files?"; then
        rm -rf "${QUARANTINE:?}"/*
        echo -e "  ${R}All quarantined files deleted.${NC}"
        log "QUARANTINE purged"
      fi
      pause; menu_quarantine ;;
    [Rr]|[0-9]*)
      local num="$q"
      [[ "$q" =~ ^[Rr]$ ]] && { printf "  Enter file number: "; read -r num; }
      if [ -n "${fmap[$num]}" ]; then
        printf "  Restore to path: "
        read -r dest
        mv "${fmap[$num]}" "${dest:-$HOME_DIR/}" && \
          echo -e "  ${G}Restored.${NC}" && log "RESTORED: ${fmap[$num]} → $dest"
      else
        echo -e "  ${R}Invalid selection.${NC}"
      fi
      pause; menu_quarantine ;;
    *) menu_quarantine ;;
  esac
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 5 — LOGS
# ═══════════════════════════════════════════════════════════════
view_logs() {
  clear; banner
  echo -e "  ${BOLD}${B}📜  YORI-AV LOG${NC}"
  echo -e "  ${DIM}$LOG_FILE${NC}\n"
  print_line "─"
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "  ${DIM}No logs yet.${NC}"
  else
    tail -40 "$LOG_FILE" | while read -r line; do
      if   echo "$line" | grep -q "THREAT\|VIRUS";     then echo -e "  ${R}$line${NC}"
      elif echo "$line" | grep -q "QUARANTINE\|DELETE"; then echo -e "  ${Y}$line${NC}"
      elif echo "$line" | grep -q "CLEAN\|OPTIMIZE";   then echo -e "  ${G}$line${NC}"
      else echo -e "  ${DIM}$line${NC}"
      fi
    done
  fi
  print_line "─"
  echo ""
  echo -e "  ${R}[C]${NC}  Clear logs   ${DIM}[0]  Back${NC}"
  printf "  ${W}Select${NC} ${DIM}›${NC} "
  read -r l
  case "$l" in
    [Cc]) > "$LOG_FILE"; echo -e "  ${G}Logs cleared.${NC}"; sleep 1 ;;
    0) main_menu; return ;;
  esac
  main_menu
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 6 — ABOUT
# ═══════════════════════════════════════════════════════════════
about() {
  clear; banner
  print_line "═"
  echo -e "  ${BOLD}${W}Yori-AV${NC}  ${DIM}v1.0.0${NC}"
  print_line "─"
  echo -e "  ${C}Author  :${NC} ${W}SparkyNox${NC}"
  echo -e "  ${C}Type    :${NC} Terminal / Termux Anti-Virus & Optimizer"
  echo -e "  ${C}License :${NC} MIT"
  echo ""
  echo -e "  ${BOLD}Features:${NC}"
  echo -e "  ${G}•${NC} Heuristic virus scanner (${#SIGNATURES[@]} signatures)"
  echo -e "  ${G}•${NC} Temp file & cache cleaner"
  echo -e "  ${G}•${NC} System optimizer & RAM analyzer"
  echo -e "  ${G}•${NC} File quarantine & restore"
  echo -e "  ${G}•${NC} Persistent logging"
  echo -e "  ${G}•${NC} Termux + Linux compatible"
  echo ""
  print_line "─"
  echo -e "  ${DIM}\"Stay clean. Stay fast. Stay protected.\"${NC}"
  print_line "═"
  pause; main_menu
}

# ─── Entry Point ───────────────────────────────────────────────
main_menu
