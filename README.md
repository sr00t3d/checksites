# CheckSites

Readme: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/checksites) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="checksites-cover.webp" />

> **Bash rewrite of the original Perl checksites utility by Matthew Harris (HostGator)**

A fast and efficient Bash script to check the status of websites hosted on cPanel/WHM and Plesk servers. Designed to detect DNS issues, HTTP errors, and common website problems.

## About

This project is a **Bash rewrite** of the original Perl script `checksites` created by **Matthew Harris** at HostGator in 2013. The original script was designed to check the status of multiple websites on shared hosting servers.

### Why a Bash Rewrite?

- **No Perl dependencies** - Uses standard Unix tools
- **Faster execution** - Native shell operations vs Perl interpreter
- **Easier maintenance** - Simpler code structure
- **Better portability** - Works on any modern Linux system
- **Same functionality** - 100% compatible with original options

## Original Reference

```perl
#!/usr/bin/perl
# $Date: 2013-08-24 $
# $Revision: 3.5 $
# $Source: /root/bin/checksites $
# $Author: Matthew Harris $
# Tool for checking status of multiple sites
# https://gatorwiki.hostgator.com/Admin/RootBin#checksites 
# http://git.toolbox.hostgator.com/checksites 
# Please submit all bug reports at bugs.hostgator.com
```

**Original Author**: Matthew Harris (HostGator)  
**Original Date**: 2013-08-24  
**Original Version**: 3.5  
**Original Purpose**: Check status of multiple sites on shared hosting servers

## Features

| Feature | Description | Original | This Version |
|---------|-------------|----------|--------------|
| Check all domains | Scan all websites on server | ✅ | ✅ |
| Check by user | Scan all domains of a cPanel user | ✅ | ✅ |
| Check by reseller | Scan all domains under a reseller | ✅ | ✅ |
| Single domain check | Check specific domain | ✅ | ✅ |
| DNS verification | Verify if domain resolves to server | ✅ | ✅ |
| HTTP status check | Verify HTTP response codes | ✅ | ✅ |
| Content detection | Detect default pages, hacks, errors | ✅ | ✅ |
| Load average protection | Pause if server load is high | ✅ | ✅ |
| Verbose mode | Show working sites too | ✅ | ✅ |
| cPanel support | Read cPanel user data | ✅ | ✅ |
| Plesk support | Query Plesk database | ✅ | ✅ |
| Timeout control | Adjustable HTTP timeout | ✅ | ✅ |

## Requirements

- **Bash** 4.0+
- **cPanel/WHM** OR **Plesk** server
- Root or sudo access (to read system files)
- Standard Unix tools: `curl`, `dig`, `mysql`, `grep`, `sed`, `awk`

## Installation

```bash
# Clone or download
curl -O https://raw.githubusercontent.com/sr00t3d/checksites/refs/heads/main/checksites.sh

# Make executable
chmod +x checksites.sh

# Optional: move to PATH
sudo mv checksites.sh /usr/local/bin/checksites
```

## Dependencies

### CentOS/RHEL/AlmaLinux/Rocky Linux
```bash
sudo yum install curl bind-utils mysql bc
# or
sudo dnf install curl bind-utils mysql bc
```

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install curl dnsutils mysql-client bc
```

## Usage

```bash
./checksites.sh [OPTIONS]
```

### Options

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-a` | `--all` | Check all domains on server | - |
| `-d` | `--domain` | Check specific domain | - |
| `-u` | `--user` | Check all domains of cPanel user | - |
| `-r` | `--reseller` | Check all domains under reseller | - |
| `-v` | `--verbose` | Show working websites (HTTP 200) | Disabled |
| `-t` | `--timeout` | HTTP request timeout in seconds | 5 |
| `-s` | `--sleep` | Sleep time for load check | 10 |
| `-h` | `--help` | Show help message | - |

## Examples

### 1. Check All Domains (Issues Only)

Show only problematic websites:

```bash
./checksites.sh -a
```

**Output:**
```bash
DOMAIN                                             ISSUE/STATUS                                      
[!] http://expired-domain.com                      Non-existent or DNS Error
[!] http://old-site.com                            Points to 192.168.1.100
[!] http://suspended-account.com                   Suspended Account
[!] http://hacked-site.com                       Possibly Hacked -> Manually Confirm
[!] http://db-error-site.com                       Database Error
[!] http://default-page.com                        Cpanel Default Page
```

### 2. Check All Domains (Verbose)

Show all websites including working ones:

```bash
./checksites.sh -a -v
```

**Output:**
```bash
DOMAIN                                             ISSUE/STATUS                                      
[+] http://working-site1.com                       200 OK
[+] http://working-site2.com                       200 OK
[!] http://problem-site.com                        500 Internal Server Error
[+] http://another-ok-site.com                     200 OK
```

### 3. Check Single Domain

```bash
./checksites.sh -d example.com
```

**Output:**
```bash
DOMAIN                                             ISSUE/STATUS                                      
[+] http://example.com                             200 OK
```

Or with problems:
```bash
DOMAIN                                             ISSUE/STATUS                                      
[!] http://example.com                             Cpanel Default Page
```

### 4. Check by cPanel User

Check all domains owned by a specific cPanel user:

```bash
./checksites.sh -u username
```

### 5. Check by Reseller

Check all domains under a specific reseller account:

```bash
./checksites.sh -r resellername
```

### 6. Custom Timeout

Useful for slow servers or network issues:

```bash
./checksites.sh -a -t 15
```

### 7. Cron Monitoring

Add to crontab for automated monitoring:

```bash
# Check all sites every hour, email if issues found
0 * * * * /usr/local/bin/checksites -a > /tmp/sites_check.txt 2>&1 || \
  cat /tmp/sites_check.txt | mail -s "Site Issues on $(hostname)" admin@example.com
```

## Detection Capabilities

### DNS Issues
- **Non-existent domain**: Domain doesn't resolve
- **External DNS**: Domain points to different server

### HTTP Status Codes
- `200 OK` - Working (only shown with `-v`)
- `301/302` - Redirects (shown as issues)
- `403 Forbidden` - Access denied
- `404 Not Found` - Missing content
- `500/502/503` - Server errors
- `Connection Failed` - Timeout or refused

### Content Detection (Original Patterns by Matthew Harris)

| Pattern | Issue Detected |
|---------|----------------|
| `defaultwebpage.cgi` | cPanel Default Page |
| `Database Error` | Database connection problem |
| `Account Suspended` | Suspended cPanel account |
| `Index of /` | Directory listing enabled |
| `/var/lib/mysql/mysql.sock` | MySQL socket error |
| `Domain Default Page` | Plesk Default Page |
| `hacked`, `haxor`, `shell`, `exploit`, `WebShell` | Possible security breach |

## Performance

### Load Average Protection

The script automatically checks server load before running:

```bash
Load Average: 15.5, cores: 8
Load Average: 15.5, sleeping for 10 seconds
Load Average: 12.3, sleeping for 10 seconds
Load Average: 8.1, sleeping for 10 seconds
Perhaps, you should fix the load before checking the sites?
```

If load remains high after 3 attempts, it prompts for confirmation.

### Parallel Processing (Optional Enhancement)

For faster checking on servers with 1000+ domains, you can modify the script to use `xargs` or `parallel`:

```bash
# Example with xargs (modification needed)
./checksites.sh -a | xargs -P 10 -I {} check_site {}
```

## Comparison with Original

| Aspect | Perl Original | Bash Version |
|--------|---------------|--------------|
| HTTP requests | `LWP::UserAgent` | `curl` |
| DNS resolution | `Socket` module | `dig`/`host`/`getent` |
| Plesk database | `DBI` (Perl DB) | `mysql` CLI |
| cPanel parsing | Perl regex | `grep`/`sed`/`awk` |
| Load check | File operations | `cut` on `/proc` |
| Core count | Parse `/proc/cpuinfo` | `nproc` |
| Dependencies | Perl modules | Standard Unix tools |
| Startup time | Slower (Perl interpreter) | Instant |
| Memory usage | Similar | Similar |

## Troubleshooting

### "Command not found: dig"
```bash
# Install DNS utilities
yum install bind-utils      # CentOS/RHEL
apt-get install dnsutils    # Ubuntu/Debian
```

### "mysql: command not found" (Plesk)
```bash
# Install MySQL client
yum install mysql           # CentOS/RHEL
apt-get install mysql-client # Ubuntu/Debian
```

### "Permission denied"
```bash
# Run as root
sudo ./checksites.sh -a
```

### All domains show "Points to X.X.X.X"
Your server IPs are not being detected correctly. Check:
```bash
ip addr show
# or
/sbin/ifconfig
```

### Script hangs on load check
Server load is very high. Use `-s` to reduce sleep time or fix the load issue first.

## Supported Control Panels

| Panel | Version | Features |
|-------|---------|----------|
| **cPanel/WHM** | All versions | Full support (users, resellers, all domains) |
| **Plesk** | All versions | All domains support (no user/reseller filtering) |

## Credits

- **Original Author**: Matthew Harris (HostGator)
- **Original Date**: 2013-08-24
- **Original Version**: 3.5
- **Bash Rewrite**: 2026
- **Purpose**: System administration tool for shared hosting servers

## Links

- Original HostGator Wiki: `https://gatorwiki.hostgator.com/Admin/RootBin#checksites`
- Original Repository: `http://git.toolbox.hostgator.com/checksites`

## Legal Notice

> [!WARNING]
> This software is provided "as is." Always ensure you have explicit permission before executing it. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## Detailed Tutorial

For a complete, step-by-step guide, check out my full article:

👉 [**Fast Check sites domains o server**](https://perciocastelo.com.br/blog/fast-check-sites-domains-on-server.html)

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.

---

**Note**: This is an unofficial rewrite and not supported/sponsored by HostGator.