#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   CheckSites v1.0.0                                                       ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Author:   Percio Castelo                                                ║
# ║   Contact:  percio@evolya.com.br | contato@perciocastelo.com.br           ║
# ║   Web:      https://perciocastelo.com.br                                  ║
# ║                                                                           ║
# ║   Function: check the status of websites                                  ║
# ║             hosted on cPanel/WHM and Plesk servers                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Settings
TIMEOUT=5
SLEEP=10
VERBOSE=0
PANEL=""
FORMAT="%-50s %-50s\n"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect panel
detect_panel() {
    if [[ -f /usr/local/cpanel/version ]]; then
        PANEL="cpanel"
    elif [[ -d /usr/local/psa ]]; then
        PANEL="plesk"
    else
        echo -e "${RED}Error: cPanel or Plesk not detected${NC}" >&2
        exit 1
    fi
}

# Get server IPs
get_ips() {
    local ips=()
    while read -r ip; do
        [[ -n "$ip" && "$ip" != "127.0.0.1" ]] && ips+=("$ip")
    done < <(ip addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' || \
             /sbin/ifconfig 2>/dev/null | grep -oP 'inet (addr:)?\K[\d.]+')
    echo "${ips[@]}"
}

# Check system load
check_load() {
    local cores=$(nproc)
    local load=$(cut -d' ' -f1 /proc/loadavg)
    local sleep_count=0
    
    while (( $(echo "$load > $cores" | bc -l) )); do
        if [[ $sleep_count -gt 2 ]]; then
            echo "Load Average: $load, cores: $cores"
            read -p "Continue even with high load? (y/N): " ans
            [[ "$ans" != "y" && "$ans" != "Y" ]] && exit 1
            break
        fi
        echo "Load Average: $load, sleeping for $SLEEP seconds"
        sleep $SLEEP
        ((sleep_count++))
        load=$(cut -d' ' -f1 /proc/loadavg)
    done
}

# DNS resolution
dns_res() {
    local domain="$1"
    local ip=$(dig +short "$domain" 2>/dev/null | head -1)
    [[ -z "$ip" ]] && ip=$(host "$domain" 2>/dev/null | grep -oP 'has address \K[\d.]+' | head -1)
    [[ -z "$ip" ]] && ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -1)
    echo "$ip"
}

# Check page content (common issue detection)
content_check() {
    local domain="$1"
    local content="$2"
    local issue=""
    
    # Check issue patterns
    if [[ "$content" =~ defaultwebpage\.cgi|searchdiscovered\.com ]]; then
        issue="Cpanel Default Page"
    elif [[ "$content" =~ [Dd]atabase[[:space:]]+[Ee]rror ]]; then
        issue="Database Error"
    elif [[ "$content" =~ [Aa]ccount[[:space:]]+[Ss]uspended ]]; then
        issue="Suspended Account"
    elif [[ "$content" =~ \<[Tt][Ii][Tt][Ll][Ee]\>[Ii]ndex[[:space:]]+[Oo][Ff] ]]; then
        issue="Directory Index"
    elif [[ "$content" =~ /var/lib/mysql/mysql\.sock ]]; then
        issue="MySQL Error"
    elif [[ "$content" =~ \<[Tt][Ii][Tt][Ll][Ee]\>([Dd]omain[[:space:]]+[Dd]efault[[:space:]]+[Pp]age|[Dd]efault[[:space:]]+[Pp]arallels[[:space:]]+[Pp]lesk) ]]; then
        issue="Plesk default page"
    elif [[ "$content" =~ [Hh]acked|[Hh]axor|shell|exploit|Web[[:space:]]Shell|FilesMan|CGI-Telnet|[Cc]99[[:space:]]?[Ss]hell|[Rr]57[[:space:]]?[Ss]hell ]]; then
        issue="Possibly Hacked -> Manually Confirm"
    fi
    
    echo "$issue"
}

# Check a specific site
check_site() {
    local domain="$1"
    local show="$2"
    local server_ips=($(get_ips))
    local ip=$(dns_res "$domain")
    
    # Check DNS
    if [[ -z "$ip" ]]; then
        printf "$FORMAT" "[!] http://$domain" "Non-existent or DNS Error"
        return
    fi
    
    # Check if it points to this server
    local found=0
    for sip in "${server_ips[@]}"; do
        [[ "$ip" == "$sip" ]] && found=1 && break
    done
    
    if [[ $found -eq 0 ]]; then
        printf "$FORMAT" "[!] http://$domain" "Points to $ip"
        return
    fi
    
    # Make HTTP request
    local response
    response=$(curl -s -L --max-time "$TIMEOUT" \
        -A "HG Site Checker (Bash)" \
        -w "\n%{http_code}|%{content_type}|%{size_download}|%{time_total}" \
        "http://$domain/" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -1 | cut -d'|' -f1)
    local body=$(echo "$response" | sed '$d')
    
    # Check if there was a connection error
    if [[ -z "$http_code" || "$http_code" == "000" ]]; then
        printf "$FORMAT" "[!] http://$domain" "Connection Failed/Timeout"
        return
    fi
    
    # Check content
    local content_issue=$(content_check "$domain" "$body")
    
    # Process response
    if [[ "$http_code" =~ ^2 ]]; then
        if [[ -n "$content_issue" ]]; then
            printf "$FORMAT" "[!] http://$domain" "$content_issue"
        elif [[ $show -eq 1 ]]; then
            printf "$FORMAT" "[+] http://$domain" "$http_code OK"
        fi
    else
        printf "$FORMAT" "[!] http://$domain" "$http_code $(echo "$response" | tail -1 | cut -d'|' -f2)"
    fi
}

# cPanel: Get domains of a user
cpanel_get_domains() {
    local user="$1"
    local file="/var/cpanel/userdata/$user/main"
    
    [[ ! -f "$file" ]] && return
    
    local domains=()
    
    # Main domain
    local main=$(grep -oP '^main_domain:\s*\K\S+' "$file" 2>/dev/null)
    [[ -n "$main" ]] && domains+=("$main")
    
    # Addon domains (lines with domain: without underscore)
    while IFS= read -r line; do
        [[ "$line" =~ ^[a-zA-Z0-9.-]+:[[:space:]] && ! "$line" =~ _ ]] || continue
        local dom=$(echo "$line" | cut -d: -f1 | tr -d ' ')
        [[ -n "$dom" && "$dom" != "main_domain" ]] && domains+=("$dom")
    done < "$file"
    
    # Parked domains (lines starting with -)
    local in_parked=0
    while IFS= read -r line; do
        [[ "$line" =~ parked_domains: ]] && in_parked=1 && continue
        [[ "$line" =~ sub_domains: ]] && break
        [[ $in_parked -eq 1 && "$line" =~ ^[[:space:]]*-[[:space:]]+([a-zA-Z0-9.-]+) ]] && domains+=("${BASH_REMATCH[1]}")
    done < "$file"
    
    echo "${domains[@]}"
}

# cPanel: All domains
cpanel_all() {
    local show="$1"
    local domains=()
    
    for user_dir in /var/cpanel/userdata/*/; do
        local user=$(basename "$user_dir")
        [[ "$user" == "nobody" ]] && continue
        local user_domains=$(cpanel_get_domains "$user")
        domains+=($user_domains)
    done
    
    printf "$FORMAT" "DOMAIN" "ISSUE/STATUS"
    for domain in "${domains[@]}"; do
        check_site "$domain" "$show"
    done
}

# cPanel: Domains of a specific user
cpanel_user() {
    local show="$1"
    local user="$2"
    local domains=$(cpanel_get_domains "$user")
    
    if [[ -z "$domains" ]]; then
        echo -e "${RED}User not found or without domains: $user${NC}"
        exit 1
    fi
    
    printf "$FORMAT" "DOMAIN" "ISSUE/STATUS"
    for domain in $domains; do
        check_site "$domain" "$show"
    done
}

# cPanel: Domains of a reseller
cpanel_reseller() {
    local show="$1"
    local reseller="$2"
    local users=()
    local domains=()
    
    # Read /etc/trueuserowners
    while IFS=: read -r user owner; do
        [[ "$owner" == "$reseller" ]] && users+=("$user")
    done < /etc/trueuserowners 2>/dev/null
    
    if [[ ${#users[@]} -eq 0 ]]; then
        echo -e "${RED}Reseller not found or without users: $reseller${NC}"
        exit 1
    fi
    
    for user in "${users[@]}"; do
        local user_domains=$(cpanel_get_domains "$user")
        domains+=($user_domains)
    done
    
    printf "$FORMAT" "DOMAIN" "ISSUE/STATUS"
    for domain in "${domains[@]}"; do
        check_site "$domain" "$show"
    done
}

# Plesk: Get domains from the database
plesk_all() {
    local show="$1"
    local pass_file="/etc/psa/.psa.shadow"
    
    if [[ ! -f "$pass_file" ]]; then
        echo -e "${RED}Plesk password file not found${NC}"
        exit 1
    fi
    
    local password=$(cat "$pass_file")
    local domains=()
    
    # MySQL query
    while IFS=$'\t' read -r domain; do
        [[ -n "$domain" ]] && domains+=("$domain")
    done < <(mysql -u admin -p"$password" psa -N -e "SELECT name FROM domains;" 2>/dev/null)
    
    if [[ ${#domains[@]} -eq 0 ]]; then
        echo -e "${RED}No domain found in Plesk or connection error${NC}"
        exit 1
    fi
    
    printf "$FORMAT" "DOMAIN" "ISSUE/STATUS"
    for domain in "${domains[@]}"; do
        check_site "$domain" "$show"
    done
}

# Help
show_help() {
    cat << 'EOF'
     
  checksites.sh [OPTIONS] [INPUT]
     
     Options:
        --all, -a          Check status of all domains on the server
        --domain, -d       Check status of one domain
        --user, -u         Check status of all domains owned by a user
        --reseller, -r     Check status of all domains under a reseller
        --verbose, -v      Show websites that are working (HTTP 200)
        --timeout, -t      Specifies a timeout for requests (default: 5)
        --sleep, -s        Set sleep time for load average check (default: 10)
        --help, -h         Show this page

   Examples:
        ./checksites.sh -a                    # Check all domains (issues only)
        ./checksites.sh -a -v                 # Check all domains (verbose)
        ./checksites.sh -d example.com        # Check single domain
        ./checksites.sh -u username           # Check all domains of user
        ./checksites.sh -r resellername      # Check all domains of reseller
        ./checksites.sh -a -t 10              # All domains with 10s timeout

EOF
}

# Parse arguments
parse_args() {
    local OPTS
    OPTS=$(getopt -o ad:u:r:vht:s: --long all,domain:,user:,reseller:,verbose,help,timeout:,sleep: -n 'checksites.sh' -- "$@")
    [[ $? != 0 ]] && exit 1
    eval set -- "$OPTS"
    
    local action=""
    local target=""
    
    while true; do
        case "$1" in
            -a|--all) action="all"; shift ;;
            -d|--domain) action="domain"; target="$2"; shift 2 ;;
            -u|--user) action="user"; target="$2"; shift 2 ;;
            -r|--reseller) action="reseller"; target="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -t|--timeout) TIMEOUT="$2"; shift 2 ;;
            -s|--sleep) SLEEP="$2"; shift 2 ;;
            -h|--help) show_help; exit 0 ;;
            --) shift; break ;;
            *) echo "Invalid option: $1"; exit 1 ;;
        esac
    done
    
    # Check load before executing
    check_load
    
    # Execute action
    case "$action" in
        all)
            if [[ "$PANEL" == "cpanel" ]]; then
                cpanel_all "$VERBOSE"
            else
                plesk_all "$VERBOSE"
            fi
            ;;
        domain)
            [[ -z "$target" ]] && { echo -e "${RED}Domain not specified${NC}"; exit 1; }
            printf "$FORMAT" "DOMAIN" "ISSUE/STATUS"
            check_site "$target" "$VERBOSE"
            ;;
        user)
            [[ "$PANEL" != "cpanel" ]] && { echo -e "${RED}Option -u only available for cPanel${NC}"; exit 1; }
            [[ -z "$target" ]] && { echo -e "${RED}User not specified${NC}"; exit 1; }
            cpanel_user "$VERBOSE" "$target"
            ;;
        reseller)
            [[ "$PANEL" != "cpanel" ]] && { echo -e "${RED}Option -r only available for cPanel${NC}"; exit 1; }
            [[ -z "$target" ]] && { echo -e "${RED}Reseller not specified${NC}"; exit 1; }
            cpanel_reseller "$VERBOSE" "$target"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Main
detect_panel
parse_args "$@"