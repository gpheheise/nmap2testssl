#!/bin/bash
# ==============================================================================
# N2T-parser - Nmap to TestSSL Scanner
#
# Automates the parsing of Nmap output files to identify SSL/TLS ports and
# sequentially triggers testssl.sh scans against them. Separates unencrypted
# traffic into a distinct log for review.
#
# Author:    gpheheise
# Copyright: (c) 2026 gpheheise
# License:   MIT (or your preferred license)
# ==============================================================================

# Configuration
NMAP_DIR="nmap"
NON_SSL_LOG="unencrypted_hosts_and_ports"
SSL_TARGETS_FILE="ssl_targets_to_scan.txt"
RESULTS_DIR="testssl_results"
TESTSSL_CMD="testssl.sh/testssl.sh"

# Check prerequisites
if [[ ! -d "$NMAP_DIR" ]]; then echo "Error: Directory '$NMAP_DIR/' not found."; exit 1; fi
if [[ ! -f "$TESTSSL_CMD" ]]; then echo "Error: testssl script not found at '$TESTSSL_CMD'."; exit 1; fi

# Prepare files and directories
mkdir -p "$RESULTS_DIR"
> "$NON_SSL_LOG"
> "$SSL_TARGETS_FILE"

# Track duplicates to prevent re-checking the same IP:Port
declare -A SCANNED_TARGETS

echo "==================================================="
echo "STAGE 1: Analyzing Ports & Identifying SSL"
echo "==================================================="

# --- STAGE 1: Discovery Loop ---
for NMAP_FILE in "$NMAP_DIR"/*; do
    
    [ -f "$NMAP_FILE" ] || continue
    echo "--> Parsing: $NMAP_FILE"
    
    CURRENT_IP=""
    CURRENT_HOST=""

    while IFS= read -r line; do
        
        # 1. Detect Host/IP
        if [[ "$line" =~ Nmap\ scan\ report\ for\ (.*) ]]; then
            RAW_HOST_DATA="${BASH_REMATCH[1]}"
            if [[ "$RAW_HOST_DATA" =~ (.*)\ \((.*)\) ]]; then
                CURRENT_HOST="${BASH_REMATCH[1]}"
                CURRENT_IP="${BASH_REMATCH[2]}"
            else
                CURRENT_HOST="$RAW_HOST_DATA"
                CURRENT_IP="$RAW_HOST_DATA"
            fi
        fi

        # 2. Detect Open Ports
        if [[ "$line" =~ ^([0-9]+)/tcp\ +open ]]; then
            PORT="${BASH_REMATCH[1]}"
            
            if [[ -n "$CURRENT_IP" ]]; then
                
                TARGET_ID="${CURRENT_IP}:${PORT}"
                
                # Check for duplicates
                if [[ -n "${SCANNED_TARGETS[$TARGET_ID]}" ]]; then continue; fi
                SCANNED_TARGETS[$TARGET_ID]=1

                # 3. Verify SSL with OpenSSL
                if echo "Q" | timeout 3 openssl s_client -connect "${CURRENT_IP}:${PORT}" -quiet -no_ign_eof 2>/dev/null; then
                    # SSL Found -> Save to the intermediate file for Stage 2
                    echo "$TARGET_ID" >> "$SSL_TARGETS_FILE"
                else
                    # No SSL -> Save to the final unencrypted log
                    echo "$CURRENT_HOST [$CURRENT_IP] $PORT" >> "$NON_SSL_LOG"
                fi
            fi
        fi

    done < "$NMAP_FILE"
done

echo ""
echo "==================================================="
echo "STAGE 2: Running TestSSL on identified targets"
echo "==================================================="

# Check if we actually found any SSL ports
if [[ ! -s "$SSL_TARGETS_FILE" ]]; then
    echo "[-] No SSL targets were found in Stage 1."
    echo "[-] Exiting."
    exit 0
fi

# --- STAGE 2: Scanning Loop ---
# Read the file we just created line by line
while IFS= read -r TARGET; do
    
    # Extract IP and Port for filename generation
    # Target format is IP:PORT
    SCAN_IP=$(echo "$TARGET" | awk -F: '{print $1}')
    SCAN_PORT=$(echo "$TARGET" | awk -F: '{print $2}')
    
    OUT_FILE="${RESULTS_DIR}/${SCAN_IP}_${SCAN_PORT}.html"
    
    # Clean up old result if it exists
    if [[ -f "$OUT_FILE" ]]; then rm "$OUT_FILE"; fi
    
    echo "    [+] Scanning: $TARGET -> $OUT_FILE"
    
    # Run TestSSL
    bash "$TESTSSL_CMD" --quiet --warnings off --htmlfile "$OUT_FILE" "$TARGET"

done < "$SSL_TARGETS_FILE"

echo "==================================================="
echo "[*] Process Complete."
echo "[*] Unencrypted services: $NON_SSL_LOG"
echo "[*] SSL Targets list:     $SSL_TARGETS_FILE"
echo "[*] HTML Reports:         $RESULTS_DIR/"Analyzing
