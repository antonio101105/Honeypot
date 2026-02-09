#!/bin/bash

# ===================================================================
# SECURE SSH HONEYPOT V2.0
# Refactored for: Integrity, Privacy, and Safety
# ===================================================================

# --- CONFIGURATION ---
LOG_FILE="honeypot_events.log"
FAKE_HOSTNAME="srv-prod-01"
# Pretend to be an OpenSSH server on Ubuntu to simple scrapers
SSH_BANNER="SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.1"

# ===================================================================
# PART 1: CONNECTION HANDLER
# This logic runs per connection.
# ===================================================================
if [ "${1:-}" == "--handler" ]; then
    
    # Getting IP from SOCAT environment variable
    # Socat sets SOCAT_PEERADDR. If missing, use "UNKNOWN"
    ATTACKER_IP="${SOCAT_PEERADDR:-UNKNOWN}"
    
    # 1. Fake the Protocol Banner (RFC 4253)
    # Real SSH sends version string first.
    echo -ne "${SSH_BANNER}\r\n"

    # 2. Simulate User Prompt
    # We use a timeout to prevent hung processes from idle attackers
    echo -ne "login as: "
    if ! read -t 10 -r USERNAME_RAW; then exit 0; fi

    # SANITIZATION: Remove non-printable chars to protect log integrity
    USERNAME=$(echo "$USERNAME_RAW" | tr -cd '[:alnum:]._-')

    if [ -z "$USERNAME" ]; then exit 0; fi

    # 3. Simulate Password Prompt
    echo -ne "${USERNAME}@${FAKE_HOSTNAME}'s password: "
    if ! read -t 10 -r PASSWORD_RAW; then exit 0; fi

    # 4. PRIVACY & SECURITY: HASHING
    # Never store plain text passwords. We hash it to track recurrence
    # without holding the liability of storing stolen credentials.
    PASS_HASH=$(echo -n "$PASSWORD_RAW" | sha256sum | awk '{print $1}')

    # 5. Simulate Delay & Access Denied
    sleep 2
    echo -e "\r\nAccess denied"

    # 6. LOGGING (Secure Append)
    # ISO 8601 Timestamp format
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Structured Log (CSV style for easy parsing)
    # Format: TIMESTAMP | IP | USER | PASS_HASH
    LOG_ENTRY="${TIMESTAMP} | IP:${ATTACKER_IP} | USER:${USERNAME} | PASS_HASH:${PASS_HASH}"
    
    echo "$LOG_ENTRY" >> "$LOG_FILE"
    
    exit 0
fi

# ===================================================================
# PART 2: THE CONTROLLER (Main)
# ===================================================================

# Strict Mode
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Trap Ctrl+C for clean exit
trap 'echo -e "\n${YELLOW}[!] Stopping Honeypot...${RESET}"; exit 0' SIGINT

clear
echo -e "${GREEN}#################################################${RESET}"
echo -e "${GREEN}#          SECURE SSH HONEYPOT V2.0             #${RESET}"
echo -e "${GREEN}#################################################${RESET}"

# 1. Dependency Check (Passive)
if ! command -v socat &> /dev/null; then
    echo -e "${RED}[ERROR] 'socat' is not installed.${RESET}"
    echo "Please install it manually: sudo apt install socat"
    exit 1
fi

if ! command -v sha256sum &> /dev/null; then
    echo -e "${RED}[ERROR] 'sha256sum' (coreutils) not found.${RESET}"
    exit 1
fi

# 2. Secure Log Creation
# Set umask to 077 ensures new files are -rw------- (Owner only)
old_umask=$(umask)
umask 077
touch "$LOG_FILE"
# Restore umask just in case
umask "$old_umask"

# Verify permissions
PERMS=$(stat -c "%a" "$LOG_FILE")
if [ "$PERMS" != "600" ]; then
    chmod 600 "$LOG_FILE"
    echo -e "${YELLOW}[i] Fixed log permissions to 600 (Current User Only).${RESET}"
fi

# 3. Path & Port Resolution
SCRIPT_PATH=$(readlink -f "$0")
read -p "Enter port to listen on (default 2222): " INPUT_PORT
PORT=${INPUT_PORT:-2222}

# Port sanity check
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo -e "${RED}[ERROR] Invalid port number.${RESET}"
    exit 1
fi

echo -e "${GREEN}[*] Honeypot Active on Port $PORT${RESET}"
echo -e "${YELLOW}[i] Log file: $LOG_FILE (Secure Mode: Hashed Passwords)${RESET}"
echo -e "${YELLOW}[i] Press Ctrl+C to stop.${RESET}"
echo ""

# 4. Execution
# TCP-LISTEN options:
# - reuseaddr: prevents "Address already in use" errors
# - fork: handle multiple connections
# - STDERR is silenced to keep terminal clean
socat -v TCP-LISTEN:"$PORT",fork,reuseaddr SYSTEM:"bash '$SCRIPT_PATH' --handler" 2>/dev/null
