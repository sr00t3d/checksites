# CheckSites (`checksites.sh`)

Readme: [PT-BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/checksites) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" alt="CheckSites" src="checksites-cover.webp" />

A fast, concurrent Bash + Python3 (stdlib) CLI diagnostics tool for auditing website availability across **cPanel/WHM**, **Plesk**, **DirectAdmin**, **HestiaPanel**, or standalone domain lists. Checks DNS resolution, HTTPS/HTTP status codes, TTFB latency (`ms`), SSL certificate expiration days, and critical content/server error signatures in parallel, exporting results in `table`, `json`, or `csv`.

## Features (v2.0.0)

* **Multi-Panel & Standalone Discovery:** Auto-discovers hosted domains from cPanel/WHM (`/etc/userdomains` & `/var/cpanel/users`), Plesk (`psa.domains`), DirectAdmin, HestiaPanel, or runs standalone with `-d <domain>` / `-f <file>`.
* **Concurrent Multi-Thread Scanning (`-j, --jobs`):** Audits hundreds of websites in seconds using a configurable worker pool (default `8`), automatically throttling down if host Load Average spikes (`--ignore-load` to bypass).
* **Full-Stack Probes (DNS + HTTPS/HTTP + TTFB + SSL + Content):**
  * Checks DNS resolution (with optional `--strict-dns` to flag external/CDN pointers).
  * Probes HTTPS first with automatic HTTP fallback, measuring TTFB in milliseconds.
  * Inspects SSL certificate validity and remaining days (`--ssl-warn 15`).
  * Detects cPanel/Plesk Default Pages, Suspended Accounts, Database/MySQL Errors, WordPress/PHP Fatal Errors, Directory Listings, and precise webshell/defacement markers without false positives on tech blogs.
* **Structured Output (`-o table|json|csv`) & Semantic Exit Codes:** `0` = all healthy, `1` = runtime error, `2` = one or more sites have issues.

## Prerequisites

* `bash` 4.0+
* `python3` (standard library only — zero `pip` packages)
* Optional: `mysql` CLI (for Plesk `--all` discovery)

## Usage & Options

```text
CheckSites v2.0.0
Fast concurrent website & hosting health monitor (cPanel/WHM, Plesk, DirectAdmin, HestiaPanel, or custom lists).

Usage:
  checksites.sh [SCOPE] [OPTIONS]

Scope (pick one):
  -a, --all                 Scan all domains hosted on the detected panel
  -d, --domain <domain>     Check one or more specific domains (can be repeated)
  -f, --file <path>         Read domains from file (one per line, # comments ignored)
  -u, --user <user>         Scan all domains of a cPanel/Hestia/DirectAdmin user
  -r, --reseller <reseller> Scan all domains under a cPanel reseller

Options:
  -v, --verbose             Show all checked sites including healthy HTTP 200
  -e, --only-issues         Show only sites with DNS, HTTP, SSL, or content issues
      --strict-dns          Flag & skip HTTP check when DNS points outside this server
  -j, --jobs <num>          Concurrent worker threads (default: 8)
  -t, --timeout <sec>       HTTP/SSL request timeout in seconds (default: 8)
      --ssl-warn <days>     Warn when SSL certificate expires in <= N days (default: 15)
      --ignore-load         Skip host Load Average guard
  -o, --output <fmt>        Output format: table (default), json, csv
```

## Practical Examples

**Check specific domains with DNS, HTTPS, TTFB, and SSL expiry:**
```bash
./checksites.sh -d perciocastelo.com.br -d example.com
```

**Audit all hosted domains on cPanel/Plesk (12 workers, issues only):**
```bash
sudo ./checksites.sh -a -j 12
```

**Export structured JSON for SIEM / Zabbix / incident tickets:**
```bash
./checksites.sh -a -v -o json > sites-audit.json
```

**Scan a custom list of domains and export CSV:**
```bash
./checksites.sh -f domains.txt -o csv > health.csv
```

## Real Output Example

```text
==================================================================================================================
 CHECKSITES v2.0.0 | Panel: cpanel | Checked: 3 domain(s) | Workers: 8
==================================================================================================================
DOMAIN                           | IP              | HTTP  | TTFB    | SSL    | STATUS        | DETAIL
------------------------------------------------------------------------------------------------------------------
example.com                      | 104.20.23.154   | 200   | 66ms    | 35d    | OK            | Healthy
nonexistent-lab-99999.invalid    | -               | ERR   | 0ms     | -      | DNS_ERROR     | Domain does not resolve
perciocastelo.com.br             | 172.64.80.1     | 200   | 95ms    | 89d    | OK            | Healthy
==================================================================================================================
 Summary: 3 checked | Healthy: 2 | Issues: 1
==================================================================================================================
```

## Detailed Tutorial

Read the full walkthrough: [**Fast Check Sites & Domains on Server**](https://perciocastelo.com.br/blog/fast-check-sites-domains-on-server.html)

## License

This project is licensed under the [Apache License 2.0](LICENSE).

---
Author: **Percio Castelo**  
Contact: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
