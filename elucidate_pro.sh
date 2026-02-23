#!/usr/bin/env bash
# ==============================================================================
# Elucidate Unified Recovery Pro v2.5
# Automated "Click-by-Click" Hash & Network Recovery
# ==============================================================================
set -euo pipefail

# --- Configuration ---
BASE_DIR="$HOME"
JOHN_RUN_DIR="$HOME/john/run"
PROJECTS_DIR="$HOME/projects"
REPORT="$HOME/recovery_report.txt"

# --- Visual Helpers ---
green(){ printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
red(){ printf "\033[31m%s\033[0m\n" "$*"; }
line(){ printf "%s\n" "------------------------------------------------------------"; }
pause(){ read -r -p "Press Enter to continue..." _; }

# --- Initialization ---
write_report() {
    echo "[$(date +%H:%M:%S)] $*" >> "$REPORT"
}

# --- Phase 1: Manual Recovery ---
manual_checklist() {
    clear
    green "Phase 1: Manual Recovery Checklist"
    line
    echo "Check these high-probability locations first:"
    echo " - Google Password Manager (Chrome / Android Settings)"
    echo " - iCloud Keychain (iPhone / Mac Settings)"
    echo " - Physical notes, planners, or router labels"
    echo " - Browser history for 'password reset' emails"
    line
    write_report "Viewed manual recovery checklist."
    pause
}

# --- Phase 2: Technical File Extraction ---
technical_file() {
    clear
    green "Phase 2: Technical File Extraction"
    line
    echo "Select file type for recovery:"
    echo "1) ZIP Archive (.zip)"
    echo "2) RAR Archive (.rar)"
    echo "3) PDF Document (.pdf)"
    echo "4) 7-Zip Archive (.7z)"
    echo "5) KeePass Database (.kdbx)"
    echo "0) Return to Main Menu"
    line
    read -r -p "Select [0-5]: " tech_choice
    [ "$tech_choice" -eq 0 ] && return

    read -r -p "Enter path to file (e.g. /sdcard/Download/file.zip): " target_file
    [ -f "$target_file" ] || { red "File not found!"; pause; return; }

    # Setup project folder
    local ts=$(date +%Y%m%d_%H%M%S)
    local filename=$(basename "$target_file")
    local p_dir="$PROJECTS_DIR/recovery_${filename%.*}_$ts"
    mkdir -p "$p_dir"
    cp "$target_file" "$p_dir/"
    cd "$p_dir"

    yellow "Extracting hash... please wait."
    case "$tech_choice" in
        1) "$JOHN_RUN_DIR/zip2john" "$filename" > hash.txt 2>extract.log ;;
        2) "$JOHN_RUN_DIR/rar2john" "$filename" > hash.txt 2>extract.log ;;
        3) "$JOHN_RUN_DIR/pdf2john" "$filename" > hash.txt 2>extract.log ;;
        4) perl "$JOHN_RUN_DIR/7z2john.pl" "$filename" > hash.txt 2>extract.log ;;
        5) "$JOHN_RUN_DIR/keepass2john" "$filename" > hash.txt 2>extract.log ;;
    esac

    if [ -s "hash.txt" ]; then
        green "SUCCESS: Hash extracted to $p_dir/hash.txt"
        write_report "Extracted hash from $filename into $p_dir"
        echo "Next Step: Run 'john --wordlist=\$HOME/wordlists/rockyou.txt hash.txt'"
    else
        red "FAILED: Could not extract hash. Check $p_dir/extract.log"
        write_report "Failed hash extraction for $filename"
    fi
    pause
}

# --- Phase 3: PCAP / Network Recovery ---
pcap_recovery() {
    clear
    green "Phase 3: Network Password Recovery (PCAP)"
    line
    read -r -p "Enter path to .pcap or .cap file: " pcap_file
    [ -f "$pcap_file" ] || { red "File not found!"; pause; return; }

    yellow "Scanning for WPA/WPA2 Handshakes..."
    "$JOHN_RUN_DIR/wpapcap2john" "$pcap_file" > "${pcap_file}.hash" 2>/dev/null

    if [ -s "${pcap_file}.hash" ]; then
        green "SUCCESS: Wi-Fi hash saved to ${pcap_file}.hash"
        write_report "Extracted WPA handshake from $(basename "$pcap_file")"
    else
        red "FAILED: No handshakes found in this capture."
    fi
    pause
}

# --- Phase 4: Safety Backup ---
backup_data() {
    clear
    green "Phase 4: Safety Backup Helper"
    line
    local dest="$HOME/Backup_$(date +%Y%m%d)"
    mkdir -p "$dest"
    yellow "Creating backup at $dest..."
    # Common folders (Works on WSL/Linux/Termux if storage is linked)
    for f in "Documents" "Pictures" "Downloads"; do
        [ -d "$HOME/$f" ] && cp -r "$HOME/$f" "$dest/" 2>/dev/null && echo "Backed up $f"
    done
    write_report "Created system backup at $dest"
    pause
}

# --- Main Menu ---
while true; do
    clear
    green "ELUCIDATE RECOVERY PRO v2.5"
    line
    echo "1) Manual Recovery Guide (Start here)"
    echo "2) Recover Password from File (ZIP, RAR, PDF, etc.)"
    echo "3) Recover Password from Network (PCAP)"
    echo "4) Create Safety Backup"
    echo "5) View Activity Report"
    echo "0) Exit"
    line
    read -r -p "Select an option: " choice
    case "$choice" in
        1) manual_checklist ;;
        2) technical_file ;;
        3) pcap_recovery ;;
        4) backup_data ;;
        5) [ -f "$REPORT" ] && cat "$REPORT" || echo "No report yet."; pause ;;
        0) green "Stay safe! Goodbye."; exit 0 ;;
        *) red "Invalid option."; sleep 1 ;;
    esac
done

