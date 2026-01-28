#!/bin/bash

# ==============================================================================
# N2T-parser (Nmap to TestSSL Parser)
#
# Automates the parsing of Nmap output files to identify SSL/TLS ports and
# sequentially triggers testssl.sh scans against them.
#
# Author:    gpheheise
# Copyright: (c) 2026 gpheheise
# License:   MIT
# Repository: https://github.com/gpheheise/nmap2testssl
# ==============================================================================

# --- Default Configuration ---
NMAP_DIR="nmap"
TESTSSL_CMD="testssl.sh/testssl.sh"
RESULTS_DIR="testssl_results"             # Default output folder
NON_SSL_LOG="unencrypted_hosts_and_ports" # Default log file
SSL_TARGETS_FILE="ssl_targets_to_scan.txt"

# --- Help Function ---
usage() {
    echo "Usage: $0 [-d <output_directory>] [-u <unencrypted_log_file>]"
    echo ""
    echo "Options:"
    echo "  -d <dir>   Directory to save HTML reports (Default: testssl_results)"
    echo "  -u <file>  Filename for unencrypted ports log (Default: unencrypted_hosts_and_ports)"
    echo "  -h         Show this help message"
    echo ""
    exit 1
}

# --- Parse Command Line Arguments ---
while getopts "d:u:h" opt; do
    case "$opt" in
        d) RESULTS_DIR="$OPTARG" ;;
        u) NON_SSL_LOG="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# --- Prerequisites Checks ---
if [[ ! -d "$NMAP_DIR" ]]; then echo "Error: Directory '$NMAP_DIR/' not found."; exit 1; fi
if [[ ! -f "$TESTSSL_CMD" ]]; then echo "Error: testssl script not found at '$TESTSSL_CMD'."; exit 1; fi

# Prepare files and directories
# We create the directory variable (which might be custom now)
mkdir -p "$RESULTS_DIR"
> "$NON_SSL_LOG"
> "$SSL_TARGETS_FILE"

# Track duplicates
declare -A SCANNED_TARGETS

echo "==================================================="
echo "CONF: Input Folder:     $NMAP_DIR/"
echo "CONF: SSL Reports Dir:  $RESULTS_DIR/"
echo "CONF: Unencrypted Log:  $NON_SSL_LOG"
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
                # Format: example.com (192.168.1.1)
                CURRENT_HOST="${BASH_REMATCH[1]}"
                CURRENT_IP="${BASH_REMATCH[2]}"
            else
                # Format: 192.168.1.1 (No hostname resolved)
                CURRENT_HOST="$RAW_HOST_DATA"
                CURRENT_IP="$RAW_HOST_DATA"
            fi
        fi

        # 2. Detect Open Ports
        if [[ "$line" =~ ^([0-9]+)/tcp\ +open ]]; then
            PORT="${BASH_REMATCH[1]}"
            
            if [[ -n "$CURRENT_IP" ]]; then
                
                # Determine Scan Target (Prefer Hostname over IP)
                if [[ "$CURRENT_HOST" != "$CURRENT_IP" ]]; then
                   SCAN_TARGET="${CURRENT_HOST}:${PORT}"
                else
                   SCAN_TARGET="${CURRENT_IP}:${PORT}"
                fi

                # Check for duplicates
                if [[ -n "${SCANNED_TARGETS[$SCAN_TARGET]}" ]]; then continue; fi
                SCANNED_TARGETS[$SCAN_TARGET]=1

                # 3. Verify SSL with OpenSSL
                # We connect to IP (reliable) but use Hostname for SNI
                if echo "Q" | timeout 3 openssl s_client -connect "${CURRENT_IP}:${PORT}" -servername "${CURRENT_HOST}" -quiet -no_ign_eof 2>/dev/null; then
                    
                    # SSL Found -> Add to queue
                    echo "$SCAN_TARGET" >> "$SSL_TARGETS_FILE"
                else
                    # No SSL -> Log to unencrypted file
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

if [[ ! -s "$SSL_TARGETS_FILE" ]]; then
    echo "[-] No SSL targets were found in Stage 1."
    echo "[-] Exiting."
    exit 0
fi

# --- STAGE 2: Scanning Loop ---
while IFS= read -r TARGET; do
    
    # Target is likely "hostname.com:443"
    # Replace colon with underscore for safe filename
    SAFE_FILENAME=$(echo "$TARGET" | tr ':' '_')
    OUT_FILE="${RESULTS_DIR}/${SAFE_FILENAME}.html"
    
    # Clean up old result if it exists
    if [[ -f "$OUT_FILE" ]]; then rm "$OUT_FILE"; fi
    
    echo "    [+] Scanning: $TARGET -> $OUT_FILE"
    
    # Run TestSSL
    bash "$TESTSSL_CMD" --quiet --warnings off --htmlfile "$OUT_FILE" "$TARGET"

done < "$SSL_TARGETS_FILE"

echo "==================================================="
echo "[*] Process Complete."
echo "[*] Unencrypted services: $NON_SSL_LOG"
echo "[*] HTML Reports:         $RESULTS_DIR/"
