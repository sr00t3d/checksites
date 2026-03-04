# CheckSites

Leia-me: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/checksites) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="checksites-cover.webp" />

> **Reescrita em Bash do utilitário checksites original em Perl por Matthew Harris (HostGator)**

Um script Bash rápido e eficiente para verificar o status de sites hospedados em servidores cPanel/WHM e Plesk. Projetado para detectar problemas de DNS, erros HTTP e problemas comuns em sites.

## Sobre

Este projeto é uma **reescrita em Bash** do script original em Perl `checksites`, criado por **Matthew Harris** na HostGator em 2013. O script original foi projetado para verificar o status de múltiplos sites em servidores de hospedagem compartilhada.

### Por que uma Reescrita em Bash?

- **Sem dependências de Perl** - Utiliza ferramentas Unix padrão
- **Execução mais rápida** - Operações nativas do shell vs interpretador Perl
- **Manutenção mais fácil** - Estrutura de código mais simples
- **Melhor portabilidade** - Funciona em qualquer sistema Linux moderno
- **Mesma funcionalidade** - 100% compatível com as opções originais

## Referência Original

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

**Autor Original**: Matthew Harris (HostGator)  
**Data Original**: 2013-08-24  
**Versão Original**: 3.5  
**Propósito Original**: Verificar o status de múltiplos sites em servidores de hospedagem compartilhada

## Recursos

| Recurso | Descrição | Original | Esta Versão |
|----------|------------|----------|-------------|
| Verificar todos os domínios | Escaneia todos os sites no servidor | ✅ | ✅ |
| Verificar por usuário | Escaneia todos os domínios de um usuário cPanel | ✅ | ✅ |
| Verificar por revendedor | Escaneia todos os domínios sob um revendedor | ✅ | ✅ |
| Verificação de domínio único | Verifica domínio específico | ✅ | ✅ |
| Verificação de DNS | Verifica se o domínio resolve para o servidor | ✅ | ✅ |
| Verificação de status HTTP | Verifica códigos de resposta HTTP | ✅ | ✅ |
| Detecção de conteúdo | Detecta páginas padrão, invasões, erros | ✅ | ✅ |
| Proteção por carga média | Pausa se a carga do servidor estiver alta | ✅ | ✅ |
| Modo verboso | Mostra sites funcionando também | ✅ | ✅ |
| Suporte a cPanel | Lê dados de usuários do cPanel | ✅ | ✅ |
| Suporte a Plesk | Consulta banco de dados do Plesk | ✅ | ✅ |
| Controle de timeout | Timeout HTTP ajustável | ✅ | ✅ |

## Requisitos

- **Bash** 4.0+
- Servidor **cPanel/WHM** OU **Plesk**
- Acesso root ou sudo (para ler arquivos do sistema)
- Ferramentas Unix padrão: `curl`, `dig`, `mysql`, `grep`, `sed`, `awk`

## Instalação

```bash
# Clonar ou baixar
curl -O https://raw.githubusercontent.com/sr00t3d/checksites/refs/heads/main/checksites.sh

# Tornar executável
chmod +x checksites.sh

# Opcional: mover para o PATH
sudo mv checksites.sh /usr/local/bin/checksites
```

## Dependências

### CentOS/RHEL/AlmaLinux/Rocky Linux
```bash
sudo yum install curl bind-utils mysql bc
# ou
sudo dnf install curl bind-utils mysql bc
```

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install curl dnsutils mysql-client bc
```

## Uso

```bash
./checksites.sh [OPÇÕES]
```

### Opções

| Opção | Forma Longa | Descrição | Padrão |
|--------|------------|------------|---------|
| `-a` | `--all` | Verificar todos os domínios no servidor | - |
| `-d` | `--domain` | Verificar domínio específico | - |
| `-u` | `--user` | Verificar todos os domínios de um usuário cPanel | - |
| `-r` | `--reseller` | Verificar todos os domínios sob um revendedor | - |
| `-v` | `--verbose` | Mostrar sites funcionando (HTTP 200) | Desativado |
| `-t` | `--timeout` | Timeout da requisição HTTP em segundos | 5 |
| `-s` | `--sleep` | Tempo de espera para verificação de carga | 10 |
| `-h` | `--help` | Mostrar mensagem de ajuda | - |

## Exemplos

### 1. Verificar Todos os Domínios (Apenas Problemas)

Mostrar apenas sites problemáticos:

```bash
./checksites.sh -a
```

**Saída:**
```bash
DOMAIN                                             ISSUE/STATUS                                      
[!] http://expired-domain.com                      Domínio inexistente ou erro de DNS
[!] http://old-site.com                            Aponta para 192.168.1.100
[!] http://suspended-account.com                   Conta suspensa
[!] http://hacked-site.com                         Possivelmente invadido -> Confirmar manualmente
[!] http://db-error-site.com                       Erro de banco de dados
[!] http://default-page.com                        Página padrão do Cpanel
```

### 2. Verificar Todos os Domínios (Verboso)

Mostrar todos os sites, incluindo os que funcionam:

```bash
./checksites.sh -a -v
```

**Saída:**
```bash
DOMAIN                                             ISSUE/STATUS                                      
[+] http://working-site1.com                       200 OK
[+] http://working-site2.com                       200 OK
[!] http://problem-site.com                        500 Internal Server Error
[+] http://another-ok-site.com                     200 OK
```

### 3. Verificar Domínio Único

```bash
./checksites.sh -d example.com
```

**Saída:**
```bash
DOMAIN                                             ISSUE/STATUS                                      
[+] http://example.com                             200 OK
```

Ou com problemas:
```bash
DOMAIN                                             ISSUE/STATUS                                      
[!] http://example.com                             Página padrão do Cpanel
```

### 4. Verificar por Usuário cPanel

Verificar todos os domínios pertencentes a um usuário cPanel específico:

```bash
./checksites.sh -u username
```

### 5. Verificar por Revendedor

Verificar todos os domínios sob uma conta de revendedor específica:

```bash
./checksites.sh -r resellername
```

### 6. Timeout Personalizado

Útil para servidores lentos ou problemas de rede:

```bash
./checksites.sh -a -t 15
```

### 7. Monitoramento com Cron

Adicionar ao crontab para monitoramento automatizado:

```bash
# Verificar todos os sites a cada hora, enviar e-mail se houver problemas
0 * * * * /usr/local/bin/checksites -a > /tmp/sites_check.txt 2>&1 || \
  cat /tmp/sites_check.txt | mail -s "Problemas nos Sites em $(hostname)" admin@example.com
```

## Capacidades de Detecção

### Problemas de DNS
- **Domínio inexistente**: Domínio não resolve
- **DNS externo**: Domínio aponta para servidor diferente

### Códigos de Status HTTP
- `200 OK` - Funcionando (mostrado apenas com `-v`)
- `301/302` - Redirecionamentos (mostrados como problemas)
- `403 Forbidden` - Acesso negado
- `404 Not Found` - Conteúdo não encontrado
- `500/502/503` - Erros de servidor
- `Connection Failed` - Timeout ou conexão recusada

### Detecção de Conteúdo (Padrões Originais por Matthew Harris)

| Padrão | Problema Detectado |
|---------|-------------------|
| `defaultwebpage.cgi` | Página padrão do cPanel |
| `Database Error` | Problema de conexão com banco de dados |
| `Account Suspended` | Conta cPanel suspensa |
| `Index of /` | Listagem de diretório habilitada |
| `/var/lib/mysql/mysql.sock` | Erro de socket do MySQL |
| `Domain Default Page` | Página padrão do Plesk |
| `hacked`, `haxor`, `shell`, `exploit`, `WebShell` | Possível violação de segurança |

## Desempenho

### Proteção por Carga Média

O script verifica automaticamente a carga do servidor antes de executar:

```bash
Carga Média: 15.5, núcleos: 8
Carga Média: 15.5, aguardando por 10 segundos
Carga Média: 12.3, aguardando por 10 segundos
Carga Média: 8.1, aguardando por 10 segundos
Talvez você deva corrigir a carga antes de verificar os sites?
```

Se a carga permanecer alta após 3 tentativas, ele solicita confirmação.

### Processamento Paralelo (Melhoria Opcional)

Para verificação mais rápida em servidores com mais de 1000 domínios, você pode modificar o script para usar `xargs` ou `parallel`:

```bash
# Exemplo com xargs (modificação necessária)
./checksites.sh -a | xargs -P 10 -I {} check_site {}
```

## Comparação com o Original

| Aspecto | Original em Perl | Versão em Bash |
|----------|------------------|----------------|
| Requisições HTTP | `LWP::UserAgent` | `curl` |
| Resolução DNS | Módulo `Socket` | `dig`/`host`/`getent` |
| Banco de dados Plesk | `DBI` (Perl DB) | `mysql` CLI |
| Parsing cPanel | Regex Perl | `grep`/`sed`/`awk` |
| Verificação de carga | Operações com arquivos | `cut` em `/proc` |
| Contagem de núcleos | Analisar `/proc/cpuinfo` | `nproc` |
| Dependências | Módulos Perl | Ferramentas Unix padrão |
| Tempo de inicialização | Mais lento (interpretador Perl) | Instantâneo |
| Uso de memória | Similar | Similar |

## Solução de Problemas

### "Command not found: dig"
```bash
# Instalar utilitários DNS
yum install bind-utils      # CentOS/RHEL
apt-get install dnsutils    # Ubuntu/Debian
```

### "mysql: command not found" (Plesk)
```bash
# Instalar cliente MySQL
yum install mysql           # CentOS/RHEL
apt-get install mysql-client # Ubuntu/Debian
```

### "Permission denied"
```bash
# Executar como root
sudo ./checksites.sh -a
```

### Todos os domínios mostram "Aponta para X.X.X.X"
Os IPs do seu servidor não estão sendo detectados corretamente. Verifique:
```bash
ip addr show
# ou
/sbin/ifconfig
```

### Script trava na verificação de carga
A carga do servidor está muito alta. Use `-s` para reduzir o tempo de espera ou corrija o problema de carga primeiro.

## Painéis de Controle Suportados

| Painel | Versão | Recursos |
|--------|---------|----------|
| **cPanel/WHM** | Todas as versões | Suporte completo (usuários, revendedores, todos os domínios) |
| **Plesk** | Todas as versões | Suporte a todos os domínios (sem filtragem por usuário/revendedor) |

## Créditos

- **Autor Original**: Matthew Harris (HostGator)
- **Data Original**: 2013-08-24
- **Versão Original**: 3.5
- **Reescrita em Bash**: 2026
- **Propósito**: Ferramenta de administração de sistemas para servidores de hospedagem compartilhada

## Links

- Wiki original da HostGator: `https://gatorwiki.hostgator.com/Admin/RootBin#checksites`
- Repositório original: `http://git.toolbox.hostgator.com/checksites`

## Aviso Legal

> [!WARNING]
> Este software é fornecido "como está". Sempre garanta que você tenha permissão explícita antes de executá-lo. O autor não é responsável por qualquer uso indevido, consequências legais ou impacto em dados causados por esta ferramenta.

## Tutorial Detalhado

Para um guia completo passo a passo, confira meu artigo completo:

👉 [**Verificação rápida de domínios de sites servidor**](https://perciocastelo.com.br/blog/fast-check-sites-domains-on-server.html)

## Licença

Este projeto está licenciado sob a **GNU General Public License v3.0**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Nota**: Esta é uma reescrita não oficial e não suportada/patrocinada pela HostGator.