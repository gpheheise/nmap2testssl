# N2T-parser (Nmap to TestSSL Parser)

**N2T-parser** is a lightweight automation tool designed to bridge the gap between network discovery and detailed SSL/TLS analysis. It parses existing Nmap scan files, validates SSL availability on open ports, and automatically dispatches `testssl.sh` to generate HTML reports for every encrypted service found.

## Features

* **Smart Parsing:** Reads standard Nmap output files (greps `Nmap scan report` and `open` ports).
* **SNI Aware:** Prioritizes Hostnames/FQDNs over IP addresses when available. This ensures `testssl.sh` checks the correct certificate (SNI) and validates the domain name.
* **Active Verification:** Uses `openssl` to verify if a port is actually speaking SSL/TLS before scanning, preventing false positives on HTTP/SSH ports.
* **Customizable Output:** Allows you to define custom directories for HTML reports and custom filenames for unencrypted logs via command-line flags.
* **De-duplication:** Automatically ignores duplicate Host:Port pairs across multiple Nmap files.
* **Clean Reporting:** Saves individual HTML reports for every service (named `hostname_port.html`).

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
    ├── nmap2testssl.sh         # The main script
    ├── nmap/                   # Place your Nmap output files here
    │   ├── scan1.txt
    │   └── scan2.txt
    └── testssl.sh/             # The cloned testssl repository
        └── testssl.sh
    ```

4.  **Make executable:**
    ```bash
    chmod +x nmap2testssl.sh
    chmod +x testssl.sh/testssl.sh
    ```

## Usage

Place your Nmap scan results (standard output format) into the `nmap/` folder and run the script.

### Basic Run (Defaults)
```bash
./nmap2testssl.sh
