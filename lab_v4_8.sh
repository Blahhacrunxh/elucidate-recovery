#!/usr/bin/env bash
set -u 
set -o pipefail

# --- Configuration ---
PROJECTS_DIR="$HOME/projects"
WORDLIST_DIR="$HOME/wordlists"
JOHN_RUN="$HOME/john/run"
DEFAULT_WL="$WORDLIST_DIR/rockyou.txt"
TTY_DEV="/dev/tty"

# --- Architecture & Environment Detection ---
ARCH=$(uname -m)
if [[ -d "/data/data/com.termux" ]]; then
    OS_TYPE="Termux (Android)"
else
    OS_TYPE="Linux (Kali/Generic)"
fi

# --- TTY Helpers ---
tty_ok() { [ -r "$TTY_DEV" ] && [ -w "$TTY_DEV" ]; }
tty_print() { if tty_ok; then printf "%s" "$*" >"$TTY_DEV"; else printf "%s" "$*"; fi; }
tty_println() { tty_print "$*"; tty_print $'\n'; }
tty_read() {
  local __var="$1"; shift; local prompt="${1:-}"
  tty_print "$prompt"
  local val=""
  if tty_ok; then IFS= read -r val <"$TTY_DEV" || true; else IFS= read -r val || true; fi
  printf -v "$__var" "%s" "$val"
}

# Colors
green(){ tty_println $'\033[32m'"$*"$'\033[0m'; }
yellow(){ tty_println $'\033[33m'"$*"$'\033[0m'; }
red(){ tty_println $'\033[31m'"$*"$'\033[0m'; }
line(){ tty_println "------------------------------------------------------------"; }
cls(){ clear >/dev/null 2>&1 || true; }
pause_tty() { local _x=""; tty_println ""; tty_read _x "Press Enter to return to menu >> "; }

# --- 0. Environment Setup ---
setup_environment() {
    cls; yellow "Verifying Lab Environment..."; line
    tty_println "OS: $OS_TYPE | Arch: $ARCH"
    line
    for dir in "$PROJECTS_DIR" "$WORDLIST_DIR"; do
        [ ! -d "$dir" ] && mkdir -p "$dir"
    done
    if [ ! -f "$JOHN_RUN/john" ]; then
        yellow "Installing Bleeding-Jumbo..."
        if [[ "$OS_TYPE" == *"Termux"* ]]; then
            pkg install -y git clang make perl python libopenssl libzip
        else
            sudo apt update && sudo apt install -y git build-essential libssl-dev zlib1g-dev yasm libgmp-dev libpcap-dev pkg-config libbz2-dev
        fi
        git clone --depth 1 https://github.com/openwall/john -b bleeding-jumbo "$HOME/john"
        cd "$HOME/john/src" && ./configure --enable-openmp && make -s -j$(nproc) && make clean
        cd "$HOME"
    fi
    if [ ! -f "$DEFAULT_WL" ]; then
        yellow "Downloading RockYou..."
        curl -L https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt -o "$DEFAULT_WL"
    fi
}

# --- 1. Gallery ---
show_cracked() {
    cls; yellow "--- PASSWORD RECOVERY GALLERY ---"; line
    local found_pot=""
    for loc in "$HOME/.john/john.pot" "$JOHN_RUN/john.pot" "$HOME/john.pot"; do
        [ -f "$loc" ] && [ -s "$loc" ] && found_pot="$loc" && break
    done
    if [ -n "$found_pot" ]; then
        green "Source: $found_pot"
        line
        grep ":" "$found_pot" | cut -d: -f2- | sort | uniq | while read -r pwd; do
            tty_println "⭐ RECOVERED: $pwd"
        done
    else
        red "No recovered passwords found yet."
    fi
    line; pause_tty
}

# --- 2. Custom Generator ---
generate_custom_list() {
    cls; yellow "--- CUSTOM WORDLIST GENERATOR ---"; line
    local base; tty_read base "Base keyword: "
    local year; tty_read year "Year: "
    local out="$WORDLIST_DIR/custom_$(date +%s).txt"
    echo "$base" > "$WORDLIST_DIR/tmp.txt"
    echo "$year" >> "$WORDLIST_DIR/tmp.txt"
    "$JOHN_RUN/john" --wordlist="$WORDLIST_DIR/tmp.txt" --rules --stdout > "$out"
    rm "$WORDLIST_DIR/tmp.txt"
    green "Created: $(basename "$out")"; pause_tty
}

# --- 3. Wordlist & Search Pickers ---
_pick_wordlist() {
    local lists=( $(find "$WORDLIST_DIR" -maxdepth 2 -name "*.txt" 2>/dev/null) )
    if [ "${#lists[@]}" -le 1 ]; then echo "$DEFAULT_WL"; return; fi
    cls; yellow "--- SELECT YOUR WORDLIST ---"; line
    tty_println "0) DEFAULT: rockyou.txt"
    local i=1; for wl in "${lists[@]}"; do
        [[ "$(basename "$wl")" == "rockyou.txt" ]] && continue
        tty_println "$i) $(basename "$wl")"
        i=$((i+1))
    done
    line; local choice; tty_read choice "Select # (Enter for Default): "
    if [[ -z "$choice" ]] || [[ "$choice" == "0" ]]; then echo "$DEFAULT_WL"; 
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -lt "$i" ]; then echo "${lists[$((choice-1))]}"; 
    else echo "$DEFAULT_WL"; fi
}

_pick_search() {
  local root="$1" pattern="$2"
  cls; yellow "Search Mode: $pattern"; line
  local q; tty_read q "Keyword: "
  local alt_p="${pattern}"
  [[ "$pattern" == "*.pcap" ]] && alt_p="*.cap"
  mapfile -t files < <(find "$root" -type f \( -name "$pattern" -o -name "$alt_p" \) 2>/dev/null | grep -i -- "$q" | head -n 25)
  if [ "${#files[@]}" -eq 0 ]; then red "Nothing found."; sleep 1; return 1; fi
  local i=1; for f in "${files[@]}"; do tty_println "$(printf "%2d) [%s] %s" "$i" "$(basename "$(dirname "$f")")" "$(basename "$f")")"; i=$((i+1)); done
  line; local n; tty_read n "Select # (0 to cancel): "
  [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#files[@]}" ] && echo "${files[$((n-1))]}" || return 1
}

# --- 4. Execution ---
execute_recovery() {
    local target="$1"; local tool="$2"
    local out_dir="$PROJECTS_DIR/recovery_$(date +%m%d_%H%M)"
    mkdir -p "$out_dir"
    local ACTIVE_WL=$(_pick_wordlist)
    cls; yellow "Extraction Phase"; line
    if [[ "$tool" == *.pl ]]; then perl "$tool" "$target" > "$out_dir/hash.txt" 2>/dev/null
    elif [[ "$tool" == *.py ]]; then python3 "$tool" "$target" > "$out_dir/hash.txt" 2>/dev/null
    else "$tool" "$target" > "$out_dir/hash.txt" 2>/dev/null; fi
    if [ -s "$out_dir/hash.txt" ]; then
        green "Hash Ready!"; line
        tty_println "Wordlist: $(basename "$ACTIVE_WL")"
        local run_j; tty_read run_j "Run John? (y/n): "
        if [[ "$run_j" == "y" ]]; then
            [[ "$tool" == *wpapcap* ]] && yellow "Cracking WPA is slow. Please be patient..."
            "$JOHN_RUN/john" --wordlist="$ACTIVE_WL" "$out_dir/hash.txt"
        fi
    else red "Extraction failed."; fi
    pause_tty
}

# --- Main ---
setup_environment
while true; do
  cls; yellow "ELUCIDATE RECOVERY v4.8 (Omni Edition)"; line
  tty_println "System: $OS_TYPE | $ARCH"
  line
  yellow "1) ZIP (.zip)        5) Office (.docx/.xlsx)"
  yellow "2) PDF (.pdf)        6) SSH Keys (id_rsa)"
  yellow "3) RAR (.rar)        7) 7-Zip (.7z)"
  yellow "4) WiFi (.cap/.pcap) 8) BitLocker"
  line
  green "G) View Gallery      W) Custom Wordlist"
  red "0) Exit"
  line
  choice=""; tty_read choice "Select: "
  case "${choice,,}" in
    1) p="*.zip"; t="$JOHN_RUN/zip2john" ;;
    2) p="*.pdf"; t="$JOHN_RUN/pdf2john.pl" ;;
    3) p="*.rar"; t="$JOHN_RUN/rar2john" ;;
    4) p="*.pcap"; t="$JOHN_RUN/wpapcap2john" ;;
    5) p="*.docx"; t="$JOHN_RUN/office2john.py" ;;
    6) p="*"; t="$JOHN_RUN/ssh2john" ;;
    7) p="*.7z"; t="$JOHN_RUN/7z2john.pl" ;;
    8) p="*"; t="$JOHN_RUN/bitlocker2john" ;;
    g) show_cracked; continue ;;
    w) generate_custom_list; continue ;;
    0) exit 0 ;;
    *) continue ;;
  esac
  selected=$(_pick_search "$PROJECTS_DIR" "$p")
  [ -n "$selected" ] && [ -f "$selected" ] && execute_recovery "$selected" "$t"
done
