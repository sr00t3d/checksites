#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   CheckSites v2.0.0                                                       ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: percio@evolya.com.br | contato@perciocastelo.com.br            ║
# ║   Web:     https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  Fast concurrent website & hosting diagnostics CLI for          ║
# ║            cPanel/WHM, Plesk, DirectAdmin, HestiaPanel and standalone     ║
# ║            lists: DNS, HTTP/HTTPS, TTFB, SSL expiry, content & errors.    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -uo pipefail
export LC_ALL=C

readonly VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

# =============================================================================
# Defaults
# =============================================================================
ACTION=""                # all | domain | user | reseller | file
TARGET=""
DOMAINS=()
VERBOSE=false
ONLY_ISSUES=false
STRICT_DNS=false
IGNORE_LOAD=false
TIMEOUT=8
JOBS=8
SSL_WARN_DAYS=15
OUTPUT_FORMAT="table"    # table | json | csv
NO_COLOR=false
QUIET=false

TMP_DIR=""
cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

# =============================================================================
# Colors
# =============================================================================
C_RESET=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_CYAN=""
C_DIM=""

init_colors() {
    if [[ "$NO_COLOR" == false && "$OUTPUT_FORMAT" == "table" && -t 1 ]]; then
        C_RESET=$'\033[0m'
        C_DIM=$'\033[2m'
        C_RED=$'\033[0;31m'
        C_GREEN=$'\033[0;32m'
        C_YELLOW=$'\033[0;33m'
        C_CYAN=$'\033[0;36m'
    fi
}

log_info() { [[ "$QUIET" == false && "$OUTPUT_FORMAT" == "table" ]] && echo -e "${C_CYAN}[→]${C_RESET} $*" >&2; }
log_warn() { [[ "$QUIET" == false ]] && echo -e "${C_YELLOW}[!]${C_RESET} $*" >&2; }
log_err()  { echo -e "${C_RED}[✗] Error:${C_RESET} $*" >&2; }

# =============================================================================
# Help
# =============================================================================
show_help() {
    cat <<EOF
CheckSites v${VERSION}
Fast concurrent website & hosting health monitor (cPanel/WHM, Plesk, DirectAdmin, HestiaPanel, or custom lists).

Usage:
  ${SCRIPT_NAME} [SCOPE] [OPTIONS]

Scope (pick one):
  -a, --all                 Scan all domains hosted on the detected panel
  -d, --domain <domain>     Check one or more specific domains (can be repeated)
  -f, --file <path>         Read domains from file (one per line, # comments ignored)
  -u, --user <user>         Scan all domains of a cPanel/Hestia/DirectAdmin user
  -r, --reseller <reseller> Scan all domains under a cPanel reseller

Options:
  -v, --verbose             Show all checked sites including healthy HTTP 200 (default for -d/-f)
  -e, --only-issues         Show only sites with DNS, HTTP, SSL, or content issues
      --strict-dns          Flag & skip HTTP check when DNS points outside this server
  -j, --jobs <num>          Concurrent worker threads (default: 8)
  -t, --timeout <sec>       HTTP/SSL request timeout in seconds (default: 8)
      --ssl-warn <days>     Warn when SSL certificate expires in <= N days (default: 15)
      --ignore-load         Skip host Load Average guard
  -o, --output <fmt>        Output format: table (default), json, csv
  -q, --quiet               Suppress progress messages
      --no-color            Disable ANSI colors
  -V, --version             Show version and exit
  -h, --help                Show this help message and exit

Exit Codes:
  0  All checked websites are healthy
  1  Usage or runtime error
  2  One or more websites have issues (DNS, HTTP, SSL, or content)

Examples:
  ${SCRIPT_NAME} -d perciocastelo.com.br -d example.com
  ${SCRIPT_NAME} -a -v -j 12
  ${SCRIPT_NAME} -a --only-issues -o json > site-issues.json
  ${SCRIPT_NAME} -f domains.txt -o csv > health.csv
EOF
}

# =============================================================================
# Panel & Domain Discovery
# =============================================================================
detect_panel() {
    if [[ -f /usr/local/cpanel/version ]]; then
        echo "cpanel"
    elif [[ -d /usr/local/psa ]]; then
        echo "plesk"
    elif [[ -d /usr/local/directadmin ]]; then
        echo "directadmin"
    elif [[ -d /usr/local/hestia ]]; then
        echo "hestia"
    else
        echo "standalone"
    fi
}

get_server_ips() {
    local ips=()
    if command -v ip >/dev/null 2>&1; then
        while IFS= read -r ip; do
            [[ -n "$ip" && "$ip" != "127.0.0.1" ]] && ips+=("$ip")
        done < <(ip -4 -o addr show scope global 2>/dev/null | awk '{sub(/\/.*/,"",$4); print $4}')
    fi
    printf '%s\n' "${ips[@]:-}" | sort -u
}

check_host_load() {
    [[ "$IGNORE_LOAD" == true ]] && return 0
    [[ -r /proc/loadavg ]] || return 0
    local cores load
    cores=$(nproc 2>/dev/null || echo 1)
    load=$(awk '{print $1}' /proc/loadavg)
    if awk -v l="$load" -v c="$cores" 'BEGIN { exit !(l > c * 1.5) }'; then
        log_warn "High host Load Average detected (${load} on ${cores} cores). Reducing concurrency to 2."
        JOBS=2
    fi
}

cpanel_domains_for_user() {
    local user="$1"
    local uf="/var/cpanel/users/${user}"
    [[ -f "$uf" ]] || return 0
    awk -F= '/^X?DNS[0-9]*=/{gsub(/\r/,"",$2); if ($2 != "") print $2}' "$uf"
}

discover_domains() {
    local panel="$1"
    case "$ACTION" in
        domain)
            printf '%s\n' "${DOMAINS[@]}" | sort -u ;;
        file)
            [[ -r "$TARGET" ]] || { log_err "Cannot read file: ${TARGET}"; exit 1; }
            sed 's/#.*//' "$TARGET" | awk 'NF {print $1}' | sort -u ;;
        all)
            case "$panel" in
                cpanel)
                    if [[ -r /etc/userdomains ]]; then
                        awk -F: '$1 != "*" && $1 != "" {gsub(/[[:space:]]/,"",$1); print $1}' /etc/userdomains | sort -u
                    else
                        local u
                        for u in /var/cpanel/users/*; do
                            [[ -f "$u" ]] || continue
                            cpanel_domains_for_user "$(basename "$u")"
                        done | sort -u
                    fi ;;
                plesk)
                    if [[ -r /etc/psa/.psa.shadow ]] && command -v mysql >/dev/null 2>&1; then
                        MYSQL_PWD="$(cat /etc/psa/.psa.shadow)" mysql -u admin psa -N -e "SELECT name FROM domains WHERE status=0;" 2>/dev/null | sort -u
                    else
                        log_err "Plesk database credentials not accessible."
                        exit 1
                    fi ;;
                directadmin)
                    awk -F: '{print $1}' /etc/virtual/domainowners 2>/dev/null | sort -u ;;
                hestia)
                    ls -1 /home/*/web/ 2>/dev/null | grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' | sort -u ;;
                *)
                    log_err "No supported hosting panel detected for --all. Use -d <domain> or -f <file>."
                    exit 1 ;;
            esac ;;
        user)
            if [[ "$panel" == "cpanel" ]]; then
                cpanel_domains_for_user "$TARGET" | sort -u
            elif [[ "$panel" == "hestia" && -d "/home/${TARGET}/web" ]]; then
                ls -1 "/home/${TARGET}/web/" | sort -u
            else
                log_err "--user requires cPanel or HestiaPanel (detected: ${panel})."
                exit 1
            fi ;;
        reseller)
            if [[ "$panel" != "cpanel" || ! -r /etc/trueuserowners ]]; then
                log_err "--reseller requires cPanel (/etc/trueuserowners)."
                exit 1
            fi
            local u
            while IFS=: read -r u owner; do
                owner=$(echo "$owner" | tr -d '[:space:]')
                [[ "$owner" == "$TARGET" ]] && cpanel_domains_for_user "$u"
            done < /etc/trueuserowners | sort -u ;;
    esac
}

# =============================================================================
# Argument Parser
# =============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)          ACTION="all"; ONLY_ISSUES=true; shift ;;
            -d|--domain)       [[ $# -lt 2 ]] && { log_err "$1 requires a domain"; exit 1; }; ACTION="domain"; DOMAINS+=("$2"); VERBOSE=true; shift 2 ;;
            -f|--file)         [[ $# -lt 2 ]] && { log_err "$1 requires a file"; exit 1; }; ACTION="file"; TARGET="$2"; VERBOSE=true; shift 2 ;;
            -u|--user)         [[ $# -lt 2 ]] && { log_err "$1 requires a user"; exit 1; }; ACTION="user"; TARGET="$2"; shift 2 ;;
            -r|--reseller)     [[ $# -lt 2 ]] && { log_err "$1 requires a reseller"; exit 1; }; ACTION="reseller"; TARGET="$2"; shift 2 ;;
            -v|--verbose)      VERBOSE=true; ONLY_ISSUES=false; shift ;;
            -e|--only-issues)  ONLY_ISSUES=true; VERBOSE=false; shift ;;
            --strict-dns)      STRICT_DNS=true; shift ;;
            -j|--jobs)         [[ $# -lt 2 ]] && { log_err "$1 requires a number"; exit 1; }; JOBS="$2"; shift 2 ;;
            -t|--timeout)      [[ $# -lt 2 ]] && { log_err "$1 requires seconds"; exit 1; }; TIMEOUT="$2"; shift 2 ;;
            --ssl-warn)        [[ $# -lt 2 ]] && { log_err "$1 requires days"; exit 1; }; SSL_WARN_DAYS="$2"; shift 2 ;;
            --ignore-load)     IGNORE_LOAD=true; shift ;;
            -o|--output)       [[ $# -lt 2 ]] && { log_err "$1 requires a format"; exit 1; }; OUTPUT_FORMAT="$2"; shift 2 ;;
            -q|--quiet)        QUIET=true; shift ;;
            --no-color)        NO_COLOR=true; shift ;;
            -V|--version)      echo "CheckSites v${VERSION}"; exit 0 ;;
            -h|--help)         show_help; exit 0 ;;
            -*)                log_err "Unknown option: $1 (use --help)"; exit 1 ;;
            *)                 ACTION="domain"; DOMAINS+=("$1"); VERBOSE=true; shift ;;
        esac
    done

    if [[ -z "$ACTION" ]]; then
        show_help
        exit 1
    fi
    case "$OUTPUT_FORMAT" in
        table|json|csv) ;;
        *) log_err "--output must be table, json, or csv"; exit 1 ;;
    esac
}

# =============================================================================
# Concurrent Checker Engine (Python3 stdlib: DNS, HTTPS/HTTP, SSL expiry, content)
# =============================================================================
run_checks() {
    local panel="$1"
    local dom_file="$2"
    local srv_ips="$3"

    if ! command -v python3 >/dev/null 2>&1; then
        log_err "python3 is required for concurrent checks and structured output."
        exit 1
    fi

    python3 - "$VERSION" "$panel" "$dom_file" "$srv_ips" "$JOBS" "$TIMEOUT" \
        "$SSL_WARN_DAYS" "$STRICT_DNS" "$ONLY_ISSUES" "$OUTPUT_FORMAT" \
        "$C_RESET" "$C_GREEN" "$C_YELLOW" "$C_RED" "$C_DIM" <<'PYEOF'
import concurrent.futures
import csv
import datetime
import io
import json
import re
import socket
import ssl
import sys
import time
import urllib.error
import urllib.request

(version, panel, dom_file, srv_ips_raw, jobs_s, timeout_s,
 ssl_warn_s, strict_dns_s, only_issues_s, fmt,
 c_rst, c_grn, c_yel, c_red, c_dim) = sys.argv[1:16]

jobs = max(1, int(jobs_s))
timeout = max(1, int(timeout_s))
ssl_warn = int(ssl_warn_s)
strict_dns = strict_dns_s == "true"
only_issues = only_issues_s == "true"
server_ips = {ip.strip() for ip in srv_ips_raw.splitlines() if ip.strip()}

with open(dom_file, encoding="utf-8") as fh:
    domains = [line.strip() for line in fh if line.strip()]

CONTENT_RULES = [
    (re.compile(r"defaultwebpage\.cgi|searchdiscovered\.com", re.I), "cPanel Default Page"),
    (re.compile(r"<title>\s*(Domain Default Page|Default Parallels Plesk)", re.I), "Plesk Default Page"),
    (re.compile(r"Account\s+Suspended", re.I), "Account Suspended"),
    (re.compile(r"Error establishing a database connection|Database\s+Error|/var/lib/mysql/mysql\.sock", re.I), "Database Error"),
    (re.compile(r"There has been a critical error on this website|Fatal error:", re.I), "PHP/WP Fatal Error"),
    (re.compile(r"<title>\s*Index of /", re.I), "Directory Listing"),
    (re.compile(r"\b(FilesMan|c99shell|r57shell|WSO\s*Shell|Hacked\s+by)\b", re.I), "Suspected Compromise"),
]

def check_ssl_days(domain: str):
    try:
        ctx = ssl.create_default_context()
        with socket.create_connection((domain, 443), timeout=timeout) as sock:
            with ctx.wrap_socket(sock, server_hostname=domain) as ssock:
                cert = ssock.getpeercert()
                not_after = cert.get("notAfter")
                if not_after:
                    exp = datetime.datetime.strptime(not_after, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=datetime.timezone.utc)
                    delta = exp - datetime.datetime.now(datetime.timezone.utc)
                    return delta.days, None
    except ssl.SSLCertVerificationError:
        return -1, "SSL Invalid"
    except Exception:
        return None, None
    return None, None

def probe_http(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": f"CheckSites/{version} (+https://perciocastelo.com.br)"})
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            code = resp.getcode()
            body = resp.read(65536).decode("utf-8", errors="replace")
            ms = int((time.monotonic() - t0) * 1000)
            return code, ms, body, None
    except urllib.error.HTTPError as e:
        ms = int((time.monotonic() - t0) * 1000)
        try:
            body = e.read(16384).decode("utf-8", errors="replace")
        except Exception:
            body = ""
        return e.code, ms, body, None
    except Exception as e:
        ms = int((time.monotonic() - t0) * 1000)
        return 0, ms, "", str(e)

def check_domain(domain: str):
    # 1. DNS lookup
    try:
        resolved_ip = socket.gethostbyname(domain)
    except Exception:
        return {
            "domain": domain, "ip": "-", "dns_local": False,
            "http_code": 0, "ttfb_ms": 0, "ssl_days": None,
            "status": "DNS_ERROR", "detail": "Domain does not resolve", "has_issue": True
        }

    dns_local = (resolved_ip in server_ips) if server_ips else True
    if strict_dns and not dns_local:
        return {
            "domain": domain, "ip": resolved_ip, "dns_local": False,
            "http_code": 0, "ttfb_ms": 0, "ssl_days": None,
            "status": "EXTERNAL_DNS", "detail": f"Points to {resolved_ip}", "has_issue": True
        }

    # 2. SSL check + HTTPS probe (fallback to HTTP if HTTPS fails to connect)
    ssl_days, ssl_err = check_ssl_days(domain)
    code, ms, body, err = probe_http(f"https://{domain}/")
    if code == 0:
        code, ms, body, err = probe_http(f"http://{domain}/")

    if code == 0:
        return {
            "domain": domain, "ip": resolved_ip, "dns_local": dns_local,
            "http_code": 0, "ttfb_ms": ms, "ssl_days": ssl_days,
            "status": "CONN_ERROR", "detail": (err or "Timeout/Connection failed")[:40], "has_issue": True
        }

    # 3. Content signature inspection
    content_issue = ""
    for pat, label in CONTENT_RULES:
        if pat.search(body):
            content_issue = label
            break

    status = "OK"
    detail = "Healthy"
    has_issue = False

    if code >= 400:
        status = f"HTTP_{code}"
        detail = content_issue or f"HTTP Error {code}"
        has_issue = True
    elif content_issue:
        status = "CONTENT_ERR"
        detail = content_issue
        has_issue = True
    elif ssl_err:
        status = "SSL_ERROR"
        detail = ssl_err
        has_issue = True
    elif ssl_days is not None and ssl_days <= ssl_warn:
        status = "SSL_EXPIRING"
        detail = f"SSL expires in {ssl_days}d"
        has_issue = True

    return {
        "domain": domain, "ip": resolved_ip, "dns_local": dns_local,
        "http_code": code, "ttfb_ms": ms, "ssl_days": ssl_days,
        "status": status, "detail": detail, "has_issue": has_issue
    }

with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
    results = list(ex.map(check_domain, domains))

total = len(results)
issues_count = sum(1 for r in results if r["has_issue"])
shown = [r for r in results if r["has_issue"]] if only_issues else results

if fmt == "json":
    print(json.dumps({
        "version": version,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "panel": panel,
        "summary": {"total": total, "healthy": total - issues_count, "issues": issues_count},
        "results": shown,
    }, indent=2))
elif fmt == "csv":
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["domain", "ip", "http_code", "ttfb_ms", "ssl_days", "status", "detail", "has_issue"])
    for r in shown:
        w.writerow([r["domain"], r["ip"], r["http_code"], r["ttfb_ms"],
                    "" if r["ssl_days"] is None else r["ssl_days"],
                    r["status"], r["detail"], r["has_issue"]])
    sys.stdout.write(buf.getvalue())
else:
    print("=" * 114)
    print(f" CHECKSITES v{version} | Panel: {panel} | Checked: {total} domain(s) | Workers: {jobs}")
    print("=" * 114)
    print(f"{'DOMAIN':<32} | {'IP':<15} | {'HTTP':<5} | {'TTFB':<7} | {'SSL':<6} | {'STATUS':<13} | {'DETAIL'}")
    print("-" * 114)
    for r in shown:
        col = c_red if r["has_issue"] else c_grn
        ssl_s = f"{r['ssl_days']}d" if r["ssl_days"] is not None and r["ssl_days"] >= 0 else ("INV" if r["ssl_days"] == -1 else "-")
        http_s = str(r["http_code"]) if r["http_code"] > 0 else "ERR"
        ttfb_s = f"{r['ttfb_ms']}ms"
        print(f"{r['domain'][:32]:<32} | {r['ip'][:15]:<15} | {http_s:<5} | {ttfb_s:<7} | {ssl_s:<6} | {col}{r['status']:<13}{c_rst} | {r['detail']}")
    print("=" * 114)
    print(f" Summary: {total} checked | Healthy: {total - issues_count} | Issues: {issues_count}")
    print("=" * 114)

sys.exit(2 if issues_count > 0 else 0)
PYEOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    parse_args "$@"
    init_colors
    check_host_load

    local panel
    panel=$(detect_panel)

    TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/checksites.XXXXXX")
    local dom_file="${TMP_DIR}/domains.txt"

    discover_domains "$panel" > "$dom_file"
    local dcount
    dcount=$(wc -l < "$dom_file")
    if (( dcount == 0 )); then
        log_err "No domains found for scope '${ACTION}'."
        exit 1
    fi

    log_info "Checking ${dcount} domain(s) with ${JOBS} parallel workers (timeout: ${TIMEOUT}s)..."
    local srv_ips
    srv_ips=$(get_server_ips)

    run_checks "$panel" "$dom_file" "$srv_ips"
    exit $?
}

main "$@"
