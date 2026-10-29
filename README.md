# Viaalink CLI User Manual

**Version:** 2.6.0 | **Last Updated:** 2026-10-22

Share local services over HTTPS with anyone, anywhere. No port forwarding, no firewall rules, no certificates to manage.

Viaalink CLI publishes your local services through **Viaalink Relay**, the server that gives them public HTTPS URLs. The command is `via`. `via` and `asd` are the same command; older scripts that call `asd` keep working.

For the list of changes in each release, see [CHANGELOG.md](../CHANGELOG.md) (authoritative, [Keep a Changelog] format). The [GitHub release pages](https://github.com/viaalink/cli/releases) mirror the relevant section per release.

[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/

---

## Table of Contents

1. [Welcome](#1-welcome)
2. [Quick Start](#2-quick-start)
3. [Understanding HTTPS Tunnels](#3-understanding-https-tunnels)
4. [Three Ways to Create Tunnels](#4-three-ways-to-create-tunnels)
5. [Web Terminal (ttyd)](#5-web-terminal-ttyd)
6. [VS Code Server (codeserver)](#6-vs-code-server-codeserver)
7. [Security & Authentication](#7-security--authentication)
8. [Access Patterns](#8-access-patterns)
9. [Troubleshooting](#9-troubleshooting)
10. [Reference Links](#10-reference-links)
11. [Tunnel Protocols](#11-tunnel-protocols)
12. [Supabase Integration](#12-supabase-integration)
13. [Resources & Community](#13-resources--community)
14. [Docker Containers](#14-docker-containers)

[Quick Reference Card](#quick-reference-card)

---

## 1. Welcome

### What Viaalink CLI Does

Viaalink CLI creates secure HTTPS tunnels from your local machine to the internet, through a Viaalink Relay you enrol this device on. With one command, you can:

- Share a local development server with a teammate
- Receive webhook callbacks from external APIs (payment providers, CI/CD pipelines, etc.)
- Access your terminal or VS Code from any browser
- Monitor all services from a built-in dashboard (`via net`)
- Demo your work without deploying

### Who It's For

- **Developers** sharing work-in-progress with teammates
- **Teams** needing remote access to development environments
- **Anyone** who wants to access local services from anywhere

### What You'll Learn

This manual teaches you how to:

1. Expose any local port as a public HTTPS URL
2. Run a web-based terminal (ttyd) for remote shell access
3. Run VS Code in a browser (code-server) for remote development
4. Secure your services with authentication

### OS & Platform Support

Viaalink CLI is cross-platform. For detailed feature status, see [FEATURE_MATURITY.md](./FEATURE_MATURITY.md).

**Quick Status:**
- **Linux** - Primary platform, extensively tested
- **macOS/Windows** - Functional, actively improving
- **Android (Termux)** - Supported, see [um_termux.md](./um_termux.md)

> **Contributing:** Found an issue on your platform? We welcome bug reports and
> contributions at our GitHub repository.

### What is Tunneling?

The CLI creates secure tunnels from your local machine to a relay, which serves them on the internet.

**HTTP Tunneling** (default):
- Web apps, REST APIs, WebSockets
- Your service stays local, gets public HTTPS URL
- Zero port-forwarding on your firewall

**TCP Tunneling** (via direct SSH):
- Databases (PostgreSQL, MySQL, Redis)
- SSH servers, custom protocols
- Use direct SSH to your relay: `ssh -p <ssh-port> -R 5432:localhost:5432 <client-id>@relay.example.com`
- Note: `via expose` is HTTP-only; TCP requires direct SSH commands

**Key Use Cases:**
- Share localhost with teammates in 30 seconds
- Expose services in Docker/K8s containers
- Create terminal access (ttyd) to any machine
- Test webhooks from external services

---

## 2. Quick Start

Get a public URL in seconds.

### Step 1: Install

**Linux / macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/viaalink/cli/main/install.sh | bash
```

**Windows PowerShell:**

> **Note:** The `irm | iex` pattern may be blocked by Windows Defender (AMSI). If so, use the CMD method below.

```powershell
irm https://raw.githubusercontent.com/viaalink/cli/main/install.ps1 | iex
```

**Windows CMD:**

```cmd
curl -fsSL https://raw.githubusercontent.com/viaalink/cli/main/install.cmd -o %TEMP%\install.cmd && %TEMP%\install.cmd
```

**Self-update** (all platforms):

```bash
via update
```

Releases: https://github.com/viaalink/cli/releases

> **Windows notes:**
> - Binary installs to `%LOCALAPPDATA%\asd\bin\` (`via.exe` and `asd.exe`). Add to PATH if prompted.
> - For the best experience, use [Git Bash](https://git-scm.com/download/win) (recommended), Windows Terminal + PowerShell, or CMD.exe.
> - If you skip the PATH prompt, run directly: `%LOCALAPPDATA%\asd\bin\asd --version`

### Step 2: Enrol on a Relay

There is no default relay: before anything can be published, enrol this device on one. The relay's dashboard gives you an enrolment link; quote it so your shell passes it through unchanged:

```bash
via relay add '<enrolment link>'
```

This creates a device key, registers it with the relay and makes the relay your default. Running your own relay? Add it directly:

```bash
via relay add <name> --host <host> --key <path> [--port <port>] [--domain <domain>]
```

### Step 3: Start Your Local Server

Run any local server. Example with Python:

```bash
python -m http.server 3000
```

Or Node.js:

```bash
npx serve -p 3000
```

### Step 4: Expose It

```bash
via expose 3000
```

You'll see output like:

```
Local:  http://localhost:3000
Caddy:  http://app.localhost
Tunnel: https://app-x7k9m2.relay.example.com
```

**That's it!** Share the tunnel URL with anyone. It's HTTPS, secure, and works from anywhere.

### Your viaalink.com Account

`via login` signs this device in to your viaalink.com account (it opens a device-code link; `--no-browser` only prints it). `via whoami` shows the account and its licenses, `via logout` signs out. Login is separate from relay enrolment: it does not create relay credentials, and `via relay add` does not need it.

---

## 3. Understanding HTTPS Tunnels

### How It Works

When you run `via expose 3000`, here's what happens:

```mermaid
flowchart LR
    subgraph Your Computer
        A[localhost:3000]
    end
    subgraph Viaalink Relay
        B[relay.example.com<br/>HTTPS + auto-cert]
    end
    subgraph Anyone
        C[User Browser]
    end
    A -->|SSH tunnel| B
    C -->|HTTPS| B
```

1. The CLI opens an SSH tunnel from your machine to the relay you enrolled on
2. The relay provides a public HTTPS URL with automatic certificates
3. Anyone with the URL can access your local service securely

### Tunnel URL Format

Your tunnel URL depends on the relay. On a relay shared by several devices, the relay appends this device's client id:

```
https://<prefix>-<client-id>.<relay-domain>
        ^^^^^^^^  ^^^^^^^^^^^  ^^^^^^^^^^^^^^
           |          |              |
      Your name   Unique ID    The relay's domain
       (optional)
```

Example: `https://myapp-x7k9m2.relay.example.com`

On your own (dedicated) relay nothing is appended: `https://myapp.relay.example.com`.

To publish through a different relay or domain for one command, pass `--server <relay-name>` or `--domain <host>`:

```bash
via expose 3000 --server <relay-name>
via expose 3000 --domain <host>
```

### What You Get Automatically

- **HTTPS** - Encrypted connection, no certificate setup needed
- **Public URL** - Accessible from anywhere on the internet
- **Firewall bypass** - No port forwarding or router configuration
- **Instant setup** - Works in seconds, not hours

### Tunnel Lifetime

Tunnels stay up while the CLI's relay client (`asd-tunnel`) runs, and auto-reconnect if the connection drops. Any limits are set by the relay you use.

---

## 4. Three Ways to Create Tunnels

Choose the method that fits your workflow:

| Need | Method | Complexity |
|------|--------|------------|
| Share something RIGHT NOW | `via expose` | Simplest |
| Daily development workflow | `asd.yaml` config | Medium |
| CI/CD and containers | Relay key via `via auth export` | Advanced |

All three publish through a relay, so enrol one first (`via relay add '<enrolment link>'`, see [Quick Start](#step-2-enrol-on-a-relay)).

### Method 1: Quick Expose (`via expose`)

The fastest way to share a local port.

**Basic usage:**

```bash
via expose 3000
```

**With a custom name:**

```bash
via expose 3000 --name myapp
# Result: https://myapp-x7k9m2.relay.example.com
```

The `--name` sets a prefix. On a shared relay the URL is `<name>-<client-id>.<relay-domain>`; on your own relay it is `<name>.<relay-domain>`.

**Pick the relay or domain:**

```bash
via expose 3000 --server <relay-name>   # Publish through a named relay
via expose 3000 --domain <host>         # ...under one of its other domains
```

**Local only (no tunnel):**

```bash
via expose 3000 --local-only
```

**Managing exposed services:**

```bash
via expose list           # List all exposed services (shows tunnel URLs!)
via expose stop myapp     # Stop by name
via expose stop 3000      # Stop by port
```

**Example `via expose list` output:**

```
myapp
    Port:     3000
    Local:    http://myapp.localhost
    Tunnel:   https://myapp-x7k9m2.relay.example.com
    Status:   ✅ Online
    Uptime:   🕐 2h 15m
```

**Interactive prompts:**

When running in a terminal, `via expose` prompts you for the port if you leave it out, and offers to install the relay client (`asd-tunnel`) if it is missing. If this device is not enrolled on a relay yet, enrol it with `via relay add '<enrolment link>'`.

**When to use:** Quick demos, one-off sharing, testing webhooks.

### Method 2: Project Config (`asd.yaml`)

For ongoing development, define services in your project.

**Setup:**

```bash
cd your-project
via init                  # Creates asd.yaml and workspace
```

**Edit `asd.yaml`:**

```yaml
version: 1
project:
  name: "my-app"

network:
  services:
    frontend:
      dial: "127.0.0.1:3000"
      host: "app.localhost"      # Local hostname
      public: true               # Enable tunnel
      subdomain: "frontend"      # Tunnel subdomain prefix

    api:
      dial: "127.0.0.1:8080"
      paths: ["/api"]            # Path-based routing
      public: true
      subdomain: "api"
```

**Automatic environment variables:**

Services can declare env vars that are automatically written to `.env` when tunnels are created. This is useful for apps that need their own public URL (e.g., OAuth callbacks, CORS origins):

```yaml
network:
  services:
    frontend:
      dial: "127.0.0.1:5173"
      public: true
      subdomain: "frontend"
      env:
        PUBLIC_URL: "${{ macro.exposedOrigin() }}"
        AUTH_CALLBACK_URL: "${{ macro.exposedOrigin() }}/auth/callback"
```

After `via net apply`, `.env` will contain:
```bash
PUBLIC_URL=https://frontend-x7k9m2.relay.example.com
AUTH_CALLBACK_URL=https://frontend-x7k9m2.relay.example.com/auth/callback
```

The parameterless `exposedOrigin()` reads the subdomain from the same service definition. Values support all template macros: `${{ env.* }}` for env vars, `${{ macro.* }}` for dynamic values. If this device isn't enrolled on a relay yet, the env var is simply skipped (not written as empty).

See [Template Macros Reference](./um_asd_yaml.md#template-macros-reference) for the full list of available macros including port allocation, random strings, bcrypt hashing, and more.

**Apply and start:**

```bash
via net apply --caddy --tunnel
via net                   # Open TUI dashboard
```

**TUI Controls:**

| Key | Action |
|-----|--------|
| `Tab` | Cycle tabs (Services, Projects, Logs) |
| `Enter` | Actions menu for selected service |
| `Ctrl+R` | Refresh health status |
| `Ctrl+Q` | Quit |
| Arrow keys | Navigate services |

**When to use:** Daily development, team projects, multiple services.

### Method 3: CI/CD and Containers

A pipeline or container uses the key of a device you enrolled on a relay. `via auth export` prints it as environment variables, or you mount `~/.config/asd/tunnel` into the container. See [Level 3: Relay Credentials](#level-3-relay-credentials) for both options.

**When to use:** CI/CD pipelines, Docker containers, automation.

---

## 5. Web Terminal (ttyd)

Access your terminal from any browser, anywhere.

### What is ttyd?

ttyd gives you a full shell session in your web browser. Perfect for:

- Remote debugging from your phone
- Sharing terminal access with teammates
- Accessing your dev machine from anywhere

### Quick Start

**1. Set credentials** (in `.env` or environment):

```bash
ASD_TTYD_USERNAME=admin
ASD_TTYD_PASSWORD=your-secure-password
```

**2. Start the terminal:**

```bash
via terminal start
```

**3. Access it:**

| Method | URL |
|--------|-----|
| Local Direct | `http://localhost:<port>/` |
| Via Caddy | `http://asd.localhost/asde/terminal/` |
| Via Tunnel | `https://hub-x7k9m2.relay.example.com/asde/terminal/` |

**4. Stop when done:**

```bash
via terminal stop
```

### Three Ways to Access

After starting, `via terminal` shows you a menu with all access URLs:

```
Terminal (ttyd) - Web Terminal Access
=====================================
Status: Running on port 7681

Access URLs:
  Local:  http://admin:***@localhost:7681/
  Caddy:  http://asd.localhost/asde/terminal/
  Tunnel: https://hub-x7k9m2.relay.example.com/asde/terminal/

Actions:
  [1] Open in browser
  [2] Copy tunnel URL
  [3] Stop terminal
```

| Access Method | When to Use |
|---------------|-------------|
| **Local Direct** | On the same machine |
| **Caddy Route** | Local network, other devices on LAN |
| **Tunnel** | Remote access from anywhere |

### Configuration

All ttyd settings go in your `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `ASD_TTYD_PORT` | (auto) | Port number (auto-assigned if not set) |
| `ASD_TTYD_USERNAME` | (required) | Login username |
| `ASD_TTYD_PASSWORD` | (required) | Login password |
| `ASD_TTYD_SHELL_CMD` | `bash` | Shell to run (`bash`, `zsh`, `fish`) |
| `ASD_TTYD_CWD` | workspace | Starting directory |
| `ASD_TTYD_PATH` | `/` | URL path prefix |

**Example `.env`:**

```bash
ASD_TTYD_USERNAME=developer
ASD_TTYD_PASSWORD=dev-secret-123
ASD_TTYD_SHELL_CMD=zsh
```

### Remote Access Setup

To access your terminal from anywhere:

**1. Start terminal and tunnel:**

```bash
via terminal start
via net apply --tunnel
```

**2. Get the tunnel URL:**

```bash
via terminal
# Shows tunnel URL in the menu
```

**3. Share the URL** - Anyone with the URL and credentials can access your terminal.

### Security Notes

**ttyd is security-sensitive.** It provides full shell access to your machine.

- **Always use strong passwords** - At least 12 characters, mixed case/numbers
- **Don't share credentials** - Give each user their own account if possible
- **Use tunnels carefully** - Anyone with the URL + password has shell access
- **Stop when not needed** - `via terminal stop`

When project-level authentication is enabled, ttyd automatically gets protected.

### Troubleshooting

**"Missing username or password":**

```bash
# Set in .env:
ASD_TTYD_USERNAME=admin
ASD_TTYD_PASSWORD=your-password
```

**"Port already in use":**

```bash
via terminal stop
# Or manually: kill the process using the port
lsof -i :7681 | grep ttyd
kill <pid>
```

**"Can't connect via tunnel":**

```bash
# Ensure tunnel is active:
via net                   # Check hub service has tunnel URL
via net apply --tunnel    # Re-apply if needed
```

**"Binary not found":**

```bash
via init                  # Re-downloads binaries
```

---

## 6. VS Code Server (codeserver)

Run Visual Studio Code in your browser with full extension support.

### What is codeserver?

code-server runs VS Code in a browser. Get the full VS Code experience from any device:

- Edit code on a tablet or Chromebook
- Use your powerful desktop from a laptop
- Share a development environment with teammates

### Platform Availability

| Platform | Status | Notes |
|----------|--------|-------|
| **Linux** | ✅ Supported | Primary platform, recommended |
| **macOS** | ✅ Supported | Works natively |
| **Windows (WSL)** | ✅ Supported | Use WSL2 with Ubuntu/Debian |
| **Windows (native)** | ❌ Not available | No native Windows builds |

**Windows Users:** code-server does not provide native Windows builds. To use code-server on Windows:

1. **Recommended:** Install [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install) with Ubuntu
2. Run Viaalink CLI inside WSL: `via code start`
3. Access from your Windows browser at the provided URL

We are actively exploring alternatives for native Windows support. Options under consideration include:
- VS Code tunnels (official Microsoft remote development)
- OpenVSCode Server
- Other browser-based IDE solutions

### Quick Start

**1. Start code-server:**

```bash
via code start
```

**2. Access it:**

| Method | URL |
|--------|-----|
| Local Direct | `http://localhost:<port>/` |
| Via Caddy | `http://asd.localhost/asde/codeserver/` |
| Via Tunnel | `https://hub-x7k9m2.relay.example.com/asde/codeserver/` |

**3. Stop when done:**

```bash
via code stop
```

### Three Ways to Access

Same pattern as ttyd. Run `via code` for the interactive menu:

```
VS Code Server - Browser-based IDE
==================================
Status: Running on port 8080

Access URLs:
  Local:  http://localhost:8080/
  Caddy:  http://asd.localhost/asde/codeserver/
  Tunnel: https://hub-x7k9m2.relay.example.com/asde/codeserver/

Actions:
  [1] Open in browser
  [2] Copy tunnel URL
  [3] Stop code-server
```

### Configuration

Configure in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `ASD_CODESERVER_PORT` | (auto) | Port number |
| `ASD_CODESERVER_AUTH` | `none` | Auth mode: `none` or `password` |
| `ASD_CODESERVER_PASSWORD` | - | Password (when auth=password) |
| `ASD_CODESERVER_WORKSPACE` | project root | Folder to open |

**Example `.env`:**

```bash
ASD_CODESERVER_AUTH=password
ASD_CODESERVER_PASSWORD=vscode-secret-123
```

**No authentication (local only):**

```bash
ASD_CODESERVER_AUTH=none
# Safe for local-only access
```

### Remote Access Setup

**1. Enable password authentication:**

```bash
# In .env:
ASD_CODESERVER_AUTH=password
ASD_CODESERVER_PASSWORD=your-secure-password
```

**2. Start code-server and tunnel:**

```bash
via code start
via net apply --tunnel
```

**3. Get the tunnel URL:**

```bash
via code
# Shows tunnel URL in menu
```

### Features

code-server provides the full VS Code experience:

- **Extensions** - Install from Open VSX marketplace
- **Integrated Terminal** - Full shell access
- **Git Integration** - Full source control
- **Settings Sync** - Your preferences everywhere
- **Multiple Files** - Tabs, split views, everything

### Security Notes

**code-server is security-sensitive.** It provides code editing and terminal access.

- **Use password auth for remote access** - Set `ASD_CODESERVER_AUTH=password`
- **Strong passwords** - At least 12 characters
- **Project-level auth** - Enable `basic_auth` in `asd.yaml` for extra protection
- **Stop when not needed** - `via code stop`

### Authentication Layers

code-server can have two authentication layers:

1. **Caddy basic auth** - Protects the route (browser login prompt)
2. **codeserver internal auth** - Application-level password

**Known limitation:** When using Caddy basic auth (`basic_auth` in `asd.yaml`), the credentials are NOT forwarded to code-server. Caddy strips the Authorization header before proxying.

This means:
- Caddy validates the user at the gateway
- code-server doesn't know who logged in via Caddy

**Recommendation for remote access:**

Use code-server's internal authentication instead of (or in addition to) Caddy basic auth:

```bash
# In .env
ASD_CODESERVER_AUTH=password
ASD_CODESERVER_PASSWORD=your-secure-password
```

This ensures code-server manages its own session, regardless of Caddy's auth layer.

### Troubleshooting

**"Can't install extensions":**

code-server uses Open VSX, not the Microsoft marketplace. Most popular extensions are available, but some Microsoft-specific ones aren't.

**"Port conflict":**

```bash
via code stop
# Or kill manually:
lsof -i :8080 | grep code-server
kill <pid>
```

**"Authentication failing":**

```bash
# Check your auth settings:
grep ASD_CODESERVER .env

# Ensure you're using the right password
```

**"Slow performance":**

- Close unused tabs and terminals
- Disable unnecessary extensions
- Use a stable network connection

---

## 7. Security & Authentication

Protect your services from unauthorized access.

### Security Levels

Viaalink CLI provides three levels of security:

| Level | Who Can Access | When to Use |
|-------|----------------|-------------|
| **No Auth** | Anyone with URL | Local development, testing |
| **Basic Password** | Anyone with URL + password | Remote access, demos |
| **Relay Credentials** | Devices enrolled on your relay | CI/CD, automation |

```mermaid
flowchart LR
    subgraph "Level 1: No Auth"
        A1[Anyone with URL]
    end
    subgraph "Level 2: Basic Auth"
        A2[URL + Password]
    end
    subgraph "Level 3: Relay Credentials"
        A3[Enrolled Devices]
    end
    A1 --> Local[Local Dev]
    A2 --> Remote[Remote Access]
    A3 --> CI[CI/CD Automation]
```

### Level 1: Open Access (Default)

When you expose without service auth:

```bash
via expose 3000
# → https://myapp-x7k9m2.relay.example.com
```

Your **local** service on localhost:3000 becomes accessible via a **public HTTPS URL**.

Traffic flow: Internet → HTTPS → SSH tunnel (encrypted) → Caddy → your service

**Good for:** Quick demos, teammate collaboration, trusted sharing

**Add password for:** Sensitive data, long-running tunnels, public demos

**Safe for:**
- Local-only access (`localhost`)
- Trusted networks
- Quick demos where you can rotate the URL

**Not safe for:**
- Services with sensitive data
- Long-running tunnels
- Production environments

### Level 2: Basic Password Protection

Add HTTP Basic Authentication to your services.

**Project-wide authentication:**

```yaml
# asd.yaml
network:
  caddy:
    basic_auth:
      enabled: true
      realm: "My Project"
```

**Set credentials in `.env`:**

```bash
ASD_BASIC_AUTH_USERNAME=admin
ASD_BASIC_AUTH_PASSWORD=your-secure-password-here
```

**What users see:**

When accessing your service, browsers show a login dialog asking for username and password.

**Per-service override:**

```yaml
# asd.yaml
network:
  caddy:
    basic_auth:
      enabled: true

  services:
    public-api:
      dial: "127.0.0.1:3000"
      basic_auth:
        enabled: false    # No auth for this service

    admin-panel:
      dial: "127.0.0.1:8080"
      basic_auth:
        enabled: true
        realm: "Admin Only"
```

### Security-Sensitive Services

Some services are automatically treated as security-sensitive:

| Service | Default Behavior |
|---------|------------------|
| ttyd | Always requires credentials |
| codeserver | Recommends password auth |

These services provide shell or code access - they should **always** have authentication when publicly accessible.

**ttyd credentials:**

```bash
ASD_TTYD_USERNAME=admin
ASD_TTYD_PASSWORD=your-ttyd-password
```

**codeserver credentials:**

```bash
ASD_CODESERVER_AUTH=password
ASD_CODESERVER_PASSWORD=your-code-password
```

### Level 3: Relay Credentials

A device publishes through a relay with its own device key. Choose how that key gets to where the tunnel runs:

| Method | Best For | viaalink.com account required |
|--------|----------|-----------------|
| `via relay add '<enrolment link>'` | Any device you enrol on a relay | No |
| SSH key in Docker | Docker, CI | No (an enrolled key) |

#### Method 1: Enrol on a relay (`via relay add`)

The relay's dashboard gives you an enrolment link. Enrolling generates a device
key, registers it with the relay and makes the relay this device's default:

```bash
via relay add 'https://relay.example.com/_relay/enroll#t=…'
via relay list      # See the relays this device is enrolled on
```

After that, `via expose` and `via net apply --tunnel` publish through it.

Managing relays:

```bash
via relay info <name>        # Details of one relay
via relay set <name>         # Make it the default relay
via relay rotate-key [name]  # Replace this device's key on its relay
via relay remove <name>      # Sign the device out of the relay, then remove it locally
```

For a self-hosted or private relay, add it with its SSH key instead of a link:

```bash
via relay add <name> --host <host> --key <path> [--port <port>] [--domain <domain>]
```

`via login` is separate: it signs this device in to your viaalink.com account
(`via whoami` shows it, `via logout` signs out) and does not create relay
credentials.

#### Method 2: SSH Key in Docker & Containers

Two ways to use your SSH key credentials inside Docker containers:

**Option A: Volume mount (simplest)**

Mount your credential directory into the container:

```bash
docker run -v ~/.config/asd/tunnel:/root/.config/asd/tunnel:ro my-image
# Inside container: via expose 3000  ← just works
```

The CLI automatically resolves key paths even when the host path differs from the container path.

**Option B: Environment variables**

Pass SSH key content as env vars — no file mounting needed:

```bash
# Export credentials (convenience command)
eval $(via auth export)

# Or with Docker flags
docker run \
  $(via auth export --docker) \
  my-image via expose 3000
```

The `via auth export` command outputs:
```bash
export ASD_TUNNEL_KEY="<base64-encoded-private-key>"
export ASD_TUNNEL_KEY_ID="<key-id>"
export ASD_TUNNEL_HOST="relay.example.com"
export ASD_TUNNEL_PORT="2222"
```

Use `--docker` for Docker `-e` flag format instead of shell exports.

### Choosing the Right Level

| Scenario | Recommended |
|----------|-------------|
| Local development | No auth |
| Quick demo (< 1 hour) | No auth (URL is secret enough) |
| Remote access to your machine | Basic password |
| Sharing with teammates | Basic password |
| CI/CD pipelines | SSH key env vars (`via auth export`) |
| Docker containers | Volume mount or `via auth export` |
| Production | Don't use development tunnels! |

### Password Best Practices

For `ASD_BASIC_AUTH_PASSWORD`, `ASD_TTYD_PASSWORD`, and `ASD_CODESERVER_PASSWORD`:

- **Minimum 12 characters**
- **Mix of letters, numbers, symbols**
- **Never reuse passwords**
- **Don't commit to git** - Use `.env` (already gitignored)

**Generate a strong password:**

```bash
openssl rand -base64 24
# Example output: K7mX9pQr2sT8vW1yB4cF6dH3
```

---

## 8. Access Patterns

Every service can be accessed three ways.

### Caddy as Security Layer

Viaalink CLI uses Caddy as a local reverse proxy **between** the tunnel and your services:

```
Internet → Viaalink Relay → SSH Tunnel → Caddy (local) → Your Service
                                       ↑
                                  Security layer
```

**Currently Available:**
- ✅ HTTPS on all Caddy routes
- ✅ HTTP Basic Authentication (password protection)
- ✅ Health check endpoints
- ✅ Request routing (host + path based)

**Configuration:**
```yaml
network:
  caddy:
    basic_auth:
      enabled: true
```

**Caddy API client:** the CLI includes npm tooling for Caddy API configuration.

### Future Authentication (Roadmap)

These are planned but **not yet implemented**:
- ⏳ OIDC (OpenID Connect)
- ⏳ JWT validation at edge
- ⏳ LDAP / Active Directory
- ⏳ 2FA / MFA enforcement
- ⏳ Edge authentication (relay level)

For current options, see [BASIC_AUTH.md](./BASIC_AUTH.md).

### Overview

| Pattern | URL Example | Use Case |
|---------|-------------|----------|
| **Local Direct** | `http://localhost:3000` | Same machine |
| **Caddy Route** | `http://asd.localhost/myapp/` | Local network, LAN |
| **Tunnel Remote** | `https://myapp-x7k9m2.relay.example.com/` | Anywhere |

```mermaid
flowchart TB
    subgraph Access Patterns
        direction TB
        L[Local Direct<br/>localhost:3000]
        C[Caddy Route<br/>app.localhost]
        T[Tunnel Remote<br/>app-x7k9m2.relay.example.com]
    end

    L --> App[Your App]
    C --> Caddy[Caddy :80] --> App
    T --> Cloud[Viaalink Relay] --> Tunnel[SSH Tunnel] --> Caddy
```

### Pattern 1: Local Direct

Direct connection to the service port.

```
http://localhost:<port>/
```

**Example:** `http://localhost:3000/`

**When to use:**
- Developing on the same machine
- Maximum performance (no proxy)
- Debugging network issues

**How it works:**
```
Browser --> localhost:3000 --> Your App
```

### Pattern 2: Caddy Routes

Access through the local Caddy reverse proxy.

**Host-based routing:**

```
http://<service>.localhost/
```

Example: `http://myapp.localhost/`

**Path-based routing:**

```
http://asd.localhost/<path>/
```

Example: `http://asd.localhost/api/`

Built-in services use the `/asde/` path prefix:
- terminal: `http://asd.localhost/asde/terminal/`
- codeserver: `http://asd.localhost/asde/codeserver/`

**When to use:**
- Multiple services with nice URLs
- Testing with realistic hostnames
- Accessing from other devices on LAN

**How it works:**
```
Browser --> Caddy (:80) --> localhost:3000 --> Your App
```

### Pattern 3: Tunnel Remote

Access through the public HTTPS tunnel.

```
https://<prefix>-<id>.<relay-domain>/
```

Example: `https://myapp-x7k9m2.relay.example.com/` (on your own relay: `https://myapp.relay.example.com/`)

**When to use:**
- Remote access from anywhere
- Sharing with external users
- Testing webhooks from external services
- Accessing from mobile devices

**How it works:**
```
Browser --> Relay --> SSH Tunnel --> Caddy --> Your App
                     (encrypted)
```

### Built-in Service URLs

| Service | Local | Caddy | Tunnel |
|---------|-------|-------|--------|
| Your app | `http://localhost:3000` | `http://myapp.localhost` | `https://myapp-x7k9m2.relay.example.com` |
| terminal | `http://localhost:7681` | `http://asd.localhost/asde/terminal/` | `https://hub-xxx.../asde/terminal/` |
| codeserver | `http://localhost:8080` | `http://asd.localhost/asde/codeserver/` | `https://hub-xxx.../asde/codeserver/` |

### Finding Your URLs

**For quick expose:**

```bash
via expose 3000
# Output shows all URLs
```

**For project services:**

```bash
via net
# TUI shows all service URLs
```

**For built-in services:**

```bash
via terminal    # Shows ttyd URLs
via code        # Shows codeserver URLs
```

---

## 9. Troubleshooting

### Common Issues

<details>
<summary><strong>Command not found: via</strong></summary>

The CLI isn't installed or not in PATH.

```bash
# Reinstall
curl -fsSL https://raw.githubusercontent.com/viaalink/cli/main/install.sh | bash

# Or check PATH
echo $PATH
```
</details>

<details>
<summary><strong>Windows: asd not found after install</strong></summary>

The install directory may not be in PATH. Either:

**Option 1:** Run with full path:
```cmd
%LOCALAPPDATA%\asd\bin\asd --version
```

**Option 2:** Add to PATH (run in Admin PowerShell):
```powershell
$installDir = "$env:LOCALAPPDATA\asd\bin"
$path = [Environment]::GetEnvironmentVariable("PATH", "User")
[Environment]::SetEnvironmentVariable("PATH", "$path;$installDir", "User")
```

Restart your terminal after adding to PATH.
</details>

<details>
<summary><strong>Windows: Antivirus flags asd as suspicious</strong></summary>

The CLI's binary installer downloads and manages tool binaries (Caddy, ttyd, GitHub CLI, etc.) on your behalf. This involves operations that antivirus heuristics sometimes flag:

- Downloading executables from the internet
- Extracting zip archives via PowerShell
- Creating `.cmd` wrapper scripts for Unix compatibility

**Why this happens:** Windows Defender and other AV engines use behavioral heuristics that flag patterns common in both legitimate DevOps tools and malware. Compiled JavaScript runtimes (Bun/Node.js) are especially prone to false positives.

**What we do to prevent it:**

- All PowerShell calls use `execFileSync("powershell.exe", [args])` with argument arrays (not string interpolation)
- Browser opening uses `explorer.exe` (not `cmd /c start`)
- No direct `cmd.exe` or `powershell.exe` spawning for shell commands
- No detached hidden processes (`detached: true` + `stdio: "ignore"`)
- Automated AV pattern scanning in CI catches risky code patterns before release

**If your AV blocks asd:**

1. **Whitelist the install directory:** Add `%LOCALAPPDATA%\asd\` to your AV exclusion list
2. **Report the false positive:** Submit `asd.exe` to your AV vendor's false positive portal:
   - [Microsoft Defender](https://www.microsoft.com/en-us/wdsi/filesubmission) (select "Software developer")
   - [BitDefender](https://www.bitdefender.com/consumer/support/answer/29358/)
3. **Verify integrity:** Run `asd --version` to confirm the binary is authentic

</details>

<details>
<summary><strong>Windows: Post-installation details</strong></summary>

See [Quick Start > Step 1: Install](#step-1-install) for all install commands (PowerShell, Linux/macOS).

**After installation:**

Binary downloads (Caddy, ttyd, gh, busybox) are managed automatically. On Windows:
- Zip archives are extracted via PowerShell `Expand-Archive` (AV-safe)
- A `bash.cmd` wrapper is created for Unix shell compatibility via BusyBox
- All binaries are stored in `%LOCALAPPDATA%\asd\bin\`

</details>

<details>
<summary><strong>Port already in use</strong></summary>

Another process is using the port.

```bash
# Find what's using the port
lsof -i :3000

# Kill it
kill <pid>

# Or use a different port
via expose 3001
```
</details>

<details>
<summary><strong>Tunnel not connecting</strong></summary>

Authentication or network issues.

```bash
# Check which relays this device is enrolled on (and the default)
via relay list
via relay info <name>

# Diagnose the connection
via diagnose

# Not enrolled on a relay yet?
via relay add '<enrolment link>'

# Reset tunnels
via net expose reset
```
</details>

<details>
<summary><strong>Service not appearing in TUI</strong></summary>

Registry out of sync.

```bash
# Refresh services
via net refresh

# Or full reset
rm .asd/workspace/network/registry.json
via net apply
```
</details>

<details>
<summary><strong>Caddy won't start</strong></summary>

Caddy configuration issue.

```bash
# Stop and remove state
via caddy stop
rm -rf .asd/workspace/caddy/

# Restart
via caddy start
via net apply
```
</details>

<details>
<summary><strong>Full Reset (Nuclear Option)</strong></summary>

When everything is broken:

```bash
# Stop all processes
pkill -f "caddy run"
pkill -f "asd-tunnel"

# Remove all state
rm -rf .asd/workspace/

# Reinitialize
via init
via net apply --caddy --tunnel
```
</details>

<details>
<summary><strong>Debug Mode</strong></summary>

Enable verbose logging:

```bash
ASD_DEBUG=1 via net apply
```
</details>

<details>
<summary><strong>View Logs</strong></summary>

```bash
via logs caddy      # Caddy proxy logs
via logs tunnel     # Tunnel logs

# Logs are in .asd/workspace/logs/
```
</details>

### Getting Help

- **GitHub Issues:** https://github.com/viaalink/cli/issues
- **Releases:** https://github.com/viaalink/cli/releases

---

## 10. Reference Links

### Command Reference

Quick reference of most-used commands:

| Command | Description |
|---------|-------------|
| `via init` | Initialize project workspace |
| `via run <task>` | Run automation task from asd.yaml |
| `via expose <port>` | Expose a port instantly |
| `via login` | Sign in to your viaalink.com account (`via whoami`, `via logout`) |
| `via relay add '<link>'` | Enrol this device on a relay (relay credentials) |
| `via relay list` | List the relays this device is enrolled on |
| `via net` | Open network TUI |
| `via net apply` | Apply configuration |
| `via terminal` | Web terminal menu |
| `via code` | VS Code server menu |
| `via config validate` | Validate asd.yaml configuration |
| `via skill install` | Install AI assistant skills |
| `via update` | Update Viaalink CLI |

Full command reference: [um_commands.md](./um_commands.md)

### Configuration Reference

- **asd.yaml options:** [um_asd_yaml.md](./um_asd_yaml.md)
- **Basic auth details:** [BASIC_AUTH.md](./BASIC_AUTH.md)
- **Tunnel architecture:** [TUNNELING.md](./TUNNELING.md)

### Service Reference

- **All services:** [um_service.md](./um_service.md)
- **Feature maturity:** [FEATURE_MATURITY.md](./FEATURE_MATURITY.md)

### Platform Guides

- **Android/Termux:** [um_termux.md](./um_termux.md)

### Status Legend

Throughout the documentation:

| Symbol | Meaning |
|--------|---------|
| ✅ | Production - fully tested, recommended |
| 🟢 | Stable - works reliably |
| 🟡 | Beta - functional, may have rough edges |
| 🟠 | Alpha - experimental |

---

## 11. Tunnel Protocols

Viaalink CLI supports different tunnel protocols for different use cases.

### HTTP Tunneling (Default)

Most services use HTTP tunneling over ports 80 and 443:

- Web applications
- REST APIs
- WebSocket connections (like ttyd)
- GraphQL endpoints

HTTP tunnels are the default and require no special configuration:

```yaml
# asd.yaml - HTTP tunnel (default)
network:
  services:
    my-app:
      dial: "127.0.0.1:3000"
      public: true              # Creates HTTPS tunnel
```

### TCP Tunneling

TCP port forwarding works via direct SSH commands. Any port other than 80/443 is forwarded as raw TCP.

**Use cases:**
- Databases (PostgreSQL, MySQL, Redis)
- SSH servers
- Custom binary protocols
- Game servers

**Examples:**

```bash
# Expose PostgreSQL on a random public port
ssh -p <ssh-port> -R 5432:localhost:5432 $ASD_CLIENT_ID@relay.example.com

# Expose MySQL
ssh -p <ssh-port> -R 3306:localhost:3306 $ASD_CLIENT_ID@relay.example.com

# Expose Redis
ssh -p <ssh-port> -R 6379:localhost:6379 $ASD_CLIENT_ID@relay.example.com
```

`via relay info <name>` shows the relay's SSH host and port. The relay assigns a random public port and reports it back in the SSH session output.

**Note:** The `via expose` command currently supports HTTP tunnels only. For TCP:
- Use direct SSH forwarding as shown above
- Enrol on a relay with `via relay add '<enrolment link>'` first to get credentials

**Private TCP aliases** (e.g., `ssh -R mydb:5432:localhost:5432 ...`) require the `--tcp-aliases` flag on the relay. It is disabled by default for security; a relay you run yourself can enable it.

### Tunnel Protocol Comparison

| Protocol | Ports | Use Case | Encryption |
|----------|-------|----------|------------|
| HTTP/HTTPS | 80, 443 | Web apps, APIs, WebSockets | TLS via Caddy |
| TCP | Any (random assigned) | Databases, SSH, custom | SSH tunnel encryption |
| TCP Alias | Private (self-hosted only) | Team-only access | SSH tunnel + no public port |

### WebSocket Support

WebSocket connections work automatically through HTTP tunnels. This is how ttyd (web terminal) works:

1. Browser connects via HTTPS to tunnel URL
2. HTTP connection upgrades to WebSocket
3. Caddy's reverse proxy handles the upgrade correctly
4. Real-time bidirectional communication established

**No special configuration needed** - Caddy's `vulcand/oxy` forwarding library handles WebSocket upgrades transparently.

**Example: ttyd WebSocket flow:**

```
Browser --HTTPS--> Tunnel --> Caddy --WS--> ttyd:7681
                              (upgrade handled)
```

### When to Use Each

| Scenario | Protocol | Example |
|----------|----------|---------|
| Web app demo | HTTP | `via expose 3000` |
| API testing | HTTP | `public: true` in asd.yaml |
| Database access | TCP | `ssh -R 5432:localhost:5432 ...` |
| SSH access | TCP | `ssh -R 22:localhost:22 ...` |
| Team-only database | TCP Alias | Self-hosted with `--tcp-aliases` |

### Tips & Tricks: Faster Connections

#### Direct OpenSSH (Advanced)

For maximum control, you can bypass the CLI and connect directly via OpenSSH with this device's relay key:

```bash
ssh -i <path-to-device-key> \
  -p <ssh-port> \
  -R "myapp:80:localhost:3000" \
  "$ASD_CLIENT_ID@relay.example.com"
```

`via relay info <name>` shows the SSH host and port; `via auth export` prints the key (base64-encoded).

**When to use:**
- CI/CD pipelines needing minimal dependencies
- Custom scripting scenarios
- Debugging connection issues

---

## 12. Supabase Integration

Viaalink CLI includes built-in Supabase support. When enabled, it automatically detects running Supabase services, routes them through Caddy, and makes them available in the `via net` TUI.

### Enable in asd.yaml

```yaml
project:
  name: "my-app"
  plugins: [supabase]
```

### What you get

When enabled, the CLI:
1. Detects running Supabase services
2. Registers them in the network
3. Creates Caddy routes for each service
4. Makes them available in the `via net` TUI

**Services:**

| Service | Port | Description |
|---------|------|-------------|
| `supabase:studio` | 54323 | Database GUI |
| `supabase:kong` | 54321 | API Gateway |
| `supabase:mailpit` | 54324 | Email testing UI |

### Commands

```bash
# Bootstrap Supabase + extract env vars to .env
via supabase bootstrap

# Start/stop Supabase services
via supabase start
via supabase stop

# Extract environment variables to .env
via supabase extract
```

The `bootstrap` command extracts credentials from Supabase and adds them to `.env`:

```bash
PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_API_URL_LOCAL=http://127.0.0.1:54321
SUPABASE_DB_URL_LOCAL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
# ... and more
```

### Future Integrations

We plan to add more integrations over time (Redis, Meilisearch, MinIO, etc.). If you need a specific integration sooner, let us know.

---

## 13. Resources & Community

### Get in Touch

- **GitHub Issues**: Report bugs, request features at https://github.com/viaalink/cli/issues

---

## 14. Docker Containers

Pre-built Docker containers give you a portable development environment. For the full reference, see [um_docker.md](./um_docker.md).

### Sandbox

A complete development environment in a container (~750 MB). Includes Viaalink CLI, Caddy, the relay client (`asd-tunnel`), ttyd, VS Code Server, Claude Code, and tmux.

```bash
# Interactive sandbox (recommended)
via sandbox shell
```

`via sandbox shell` mounts this device's relay credentials (`~/.config/asd/tunnel`) read-only, so tunnels work inside the container without a new enrolment.

**Features:**
- Interactive menu with system info, running services, and active tunnel URLs
- Tmux session management (detach with `Ctrl+B D`, reattach with `docker start -ai`)
- Project workspace mounted at `/workspace`

To use relay credentials in your own containers, see [Level 3: Relay Credentials](#level-3-relay-credentials).

See [um_docker.md](./um_docker.md) for environment variables, volume mounts, GitHub Actions examples, and more.

---

## Quick Reference Card

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/viaalink/cli/main/install.sh | bash
```

**Enrol on a relay (once per device):**
```bash
via relay add '<enrolment link>'
```

**Sign in to your viaalink.com account (optional):**
```bash
via login
```

**Initialize workspace:**
```bash
via init --yes
```

**Start development:**
```bash
via run dev               # Run 'dev' task from asd.yaml
```

**Expose a service:**
```bash
via expose 3000
```

**Diagnose connection:**
```bash
via diagnose
```

**Switch relay:**
```bash
via relay                 # Interactive picker
via relay list            # Show all relays
via relay set <name>      # Set the default relay
```

**Web terminal:**
```bash
via terminal start
```

**VS Code in browser:**
```bash
via code start
```

**Stop everything:**
```bash
via down                  # Stop workspace services
```

---

*For detailed technical reference, see the documents in `.asd/docs/`.*
