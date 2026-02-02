#!/bin/bash

# --- CONFIGURATION ---
LOG_FILE="ssh_log.txt"
FAKE_HOST="ubuntu-server"

# ===================================================================
# PART 1: CONNECTION HANDLER (The "Actor")
# ===================================================================
# This section handles the interaction with the attacker once connected.
if [ "$1" == "--handler" ]; then
    
    # Short delay to ensure the netcat/socket connection is fully established
    sleep 0.1

    # 1. Simulate the SSH Username Prompt
    # We use printf to avoid automatic newlines, mimicking real SSH behavior
    printf "login as: "
    
    # Read the username input from the attacker
    if read -r USERNAME; then
        
        # INPUT SANITIZATION
        # Strip Carriage Returns (\r) and Newlines (\n) to prevent log corruption
        # or visual glitches in the terminal.
        USERNAME=$(echo "$USERNAME" | tr -d '\r\n')

        # If the input is empty (user just hit Enter), exit the handler
        if [ -z "$USERNAME" ]; then exit 0; fi

        # 2. Simulate the SSH Password Prompt
        # Dynamically insert the captured username and fake hostname
        printf "%s@%s's password: " "$USERNAME" "$FAKE_HOST"
        
        if read -r PASSWORD; then
            
            # Sanitize the password input as well
            PASSWORD=$(echo "$PASSWORD" | tr -d '\r\n')

            # 3. Simulate Authentication Delay
            # A 3-second pause mimics the server verifying the hash
            sleep 3
            
            # 4. Simulate Access Denial
            # Standard Linux error message for failed login
            echo ""
            echo "Permission denied, please try again."
            
            # --- LOGGING ---
            # Capture timestamp and write structured data to the log file
            TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
            
            (
                echo "[$TIMESTAMP] CAPTURED ATTEMPT:"
                echo "   ├─ IP Source: $SOCAT_PEERADDR"
                echo "   ├─ Username:  $USERNAME"
                echo "   └─ Password:  $PASSWORD"
                echo "---------------------------------------------------"
            ) >> "$LOG_FILE"
        fi
    fi
    exit 0
fi

# ===================================================================
# PART 2: THE LISTENER (Main Execution)
# ===================================================================

# Color codes for terminal output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RESET='\033[0m'

clear
echo -e "${BLUE}#################################################${RESET}"
echo -e "${BLUE}#                   SSH HONEYPOT                #${RESET}"
echo -e "${BLUE}#  Created by:  Antonio Manuel Núñez Campallo   #
#  AKA:		Antonio_101105                  #"
echo -e "${BLUE}#################################################${RESET}"

# Check for 'socat' dependency and install if missing
if ! command -v socat &> /dev/null; then
    echo "Dependency 'socat' not found. Installing..."
    sudo apt-get update && sudo apt-get install socat -y
fi

# Ensure log file exists and has generic write permissions
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Get absolute path of this script to call it recursively
SCRIPT_PATH=$(readlink -f "$0")

# --- PORT CONFIGURATION ---
# Ask user for port, defaulting to 2222 if input is empty
read -p "Enter port to listen on (default 2222): " INPUT_PORT
PORT=${INPUT_PORT:-2222}

# Kill any existing processes on the selected port to avoid conflicts
fuser -k -n tcp "$PORT" 2> /dev/null

echo -e "${GREEN}[*] Honeypot active on port $PORT${RESET}"
echo -e "${BLUE}[i] Logging activity to: $LOG_FILE${RESET}"
echo ""

# Launch SOCAT listener
# - TCP-LISTEN: Listens on the specified port
# - fork: Spawns a new process for each connection (concurrency)
# - reuseaddr: Allows immediate restart of the listener
# - SYSTEM: Executes this script in handler mode
socat -v TCP-LISTEN:$PORT,fork,reuseaddr SYSTEM:"bash $SCRIPT_PATH --handler" 2>/dev/null
