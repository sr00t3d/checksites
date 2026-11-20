# CheckSites (`checksites.sh`)

Readme: [EN](README.md)

![License](https://img.shields.io/github/license/sr00t3d/checksites) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" alt="CheckSites" src="checksites-cover.webp" />

Ferramenta CLI rápida e concorrente em Bash + Python3 (biblioteca padrão) para auditar disponibilidade de sites em servidores **cPanel/WHM**, **Plesk**, **DirectAdmin**, **HestiaPanel** ou listas avulsas de domínios. Verifica resolução DNS, status HTTPS/HTTP, latência TTFB (`ms`), dias restantes do certificado SSL e assinaturas críticas de erro de servidor/conteúdo em paralelo, com exportação em `table`, `json` ou `csv`.

## Funcionalidades (v2.0.0)

* **Descoberta Multi-Painel e Modo Avulso:** Descobre domínios automaticamente no cPanel/WHM (`/etc/userdomains` e `/var/cpanel/users`), Plesk (`psa.domains`), DirectAdmin, HestiaPanel ou aceita domínios via `-d <domínio>` e `-f <arquivo>`.
* **Varredura Concorrente (`-j, --jobs`):** Audita centenas de sites em segundos com pool de workers configurável (padrão `8`), reduzindo automaticamente a concorrência se o Load Average do host estiver alto.
* **Probes Completos (DNS + HTTPS/HTTP + TTFB + SSL + Conteúdo):**
  * Valida resolução DNS (com `--strict-dns` opcional para sinalizar apontamentos externos/CDN).
  * Testa HTTPS primeiro com fallback HTTP, medindo TTFB em milissegundos.
  * Verifica validade e dias restantes do certificado SSL (`--ssl-warn 15`).
  * Detecta cPanel/Plesk Default Page, Account Suspended, Database/MySQL Error, WordPress/PHP Fatal Error, Directory Listing e marcadores precisos de defacement/webshell sem falsos positivos em blogs técnicos.
* **Saída Estruturada (`-o table|json|csv`) e Exit Codes:** `0` = tudo saudável, `1` = erro de execução, `2` = um ou mais sites com falha.

## Pré-requisitos

* `bash` 4.0+
* `python3` (somente biblioteca padrão — zero pacotes `pip`)
* Opcional: cliente `mysql` (para `--all` no Plesk)

## Exemplos Práticos

**Verificar domínios específicos (DNS, HTTPS, TTFB e validade SSL):**
```bash
./checksites.sh -d perciocastelo.com.br -d example.com
```

**Auditar todos os domínios do servidor cPanel/Plesk (12 workers, apenas falhas):**
```bash
sudo ./checksites.sh -a -j 12
```

**Exportar relatório JSON para SIEM / Zabbix / chamados:**
```bash
./checksites.sh -a -v -o json > sites-audit.json
```

**Varrer lista personalizada de domínios e exportar CSV:**
```bash
./checksites.sh -f domains.txt -o csv > health.csv
```

## Exemplo de Saída Real

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

## Tutorial Detalhado

Confira o guia completo no blog: [**Verificar Rapidamente Sites e Domínios no Servidor**](https://perciocastelo.com.br/blog/fast-check-sites-domains-on-server.html)

## Licença

Este projeto é distribuído sob a licença [Apache License 2.0](LICENSE).

---
Autor: **Percio Castelo**  
Contato: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
