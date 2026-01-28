# N2T-parser (Nmap to TestSSL Parser)

**N2T-parser** is a lightweight automation tool designed to bridge the gap between network discovery and detailed SSL/TLS analysis. It parses existing Nmap scan files, validates SSL availability on open ports, and automatically dispatches `testssl.sh` to generate HTML reports for every encrypted service found.

## Features

* **Smart Parsing:** Reads standard Nmap output files (greps `Nmap scan report` and `open` ports).
* **Active Verification:** Uses `openssl` to verify if a port is actually speaking SSL/TLS before scanning, preventing false positives on HTTP/SSH ports.
* **Two-Stage Process:**
    1.  **Discovery:** Identifies all SSL targets and filters out unencrypted services.
    2.  **Scanning:** Runs `testssl.sh` sequentially on the confirmed SSL list.
* **De-duplication:** Automatically ignores duplicate IP:Port pairs across multiple Nmap files.
* **Clean Reporting:** Saves individual HTML reports for every service and logs unencrypted ports to a separate file.

## Prerequisites

Ensure the following tools are installed and accessible on your system:

* **Nmap:** Required to generate the initial scan files.
* **Bash & OpenSSL:** Standard on most Linux distributions.
* **TestSSL.sh:** This script must be cloned from GitHub (instructions below).

## Installation & Directory Structure

1.  **Clone this repository:**
    ```bash
    git clone [https://github.com/gpheheise/nmap2testssl.git](https://github.com/gpheheise/nmap2testssl.git)
    cd nmap2testssl
    ```

2.  **Install TestSSL.sh:**
    The script expects `testssl.sh` to be located in the current directory. Clone it from the official source:
    ```bash
    git clone [https://github.com/drwetter/testssl.sh.git](https://github.com/drwetter/testssl.sh.git)
    ```

3.  **Organize your folders:**
    Ensure your directory structure looks like this:
    ```text
    .
    ├── n2t.sh                  # The main script (rename if needed)
    ├── nmap/                   # Place your Nmap output files here
    │   ├── scan1.txt
    │   └── scan2.txt
    └── testssl.sh/             # The cloned testssl repository
        └── testssl.sh
    ```

4.  **Make executable:**
    ```bash
    chmod +x n2t.sh
    chmod +x testssl.sh/testssl.sh
    ```

## Usage

1.  Place your Nmap scan results (standard output format) into the `nmap/` folder.
2.  Run the script:

    ```bash
    ./n2t.sh
    ```

3.  **View Results:**
    * **Encrypted Reports:** Check the `testssl_results/` folder for HTML reports (e.g., `192.168.1.5_443.html`).
    * **Unencrypted Log:** Check `unencrypted_hosts_and_ports` for a list of open ports that do not support SSL.

## Workflow

1.  The script iterates through all files in `nmap/`.
2.  It attempts an SSL handshake on every open TCP port found.
3.  **If SSL fails:** The port is logged to `unencrypted_hosts_and_ports`.
4.  **If SSL succeeds:** The target is added to a queue (`ssl_targets_to_scan.txt`).
5.  Once discovery is complete, `testssl.sh` is executed against the queue, saving HTML reports.

## Copyright

Copyright (c) 2026 gpheheise.
