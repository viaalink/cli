# Viaalink CLI Advanced Manual (asd.yaml and Operations)

**Version:** 2.7.0 | **Last Updated:** 2026-10-22

This is the deep-dive reference. If you want the quick, simple flow, start here:
- `docs/USER_MANUAL.md`

`via` and `asd` are the same command; older scripts that call `asd` keep working.

Template macros are fully documented in [`TEMPLATE_MACROS.md`](./TEMPLATE_MACROS.md) (auto-generated from the engine source, stays current). Release-over-release changes are in [../CHANGELOG.md](../CHANGELOG.md).

---

## Configuration (`asd.yaml`)

The `asd.yaml` file at your project root defines services, features, and network configuration.

### Minimal Example

```yaml
version: 1
project:
  name: "my-app"

features:
  auto_detect_services: true
  auto_install_binaries: true

network:
  services:
    my-app:
      dial: "127.0.0.1:3000"
      host: "app.localhost"
      paths: ["/"]
```

### Project Settings

```yaml
project:
  name: "my-project"          # Project identifier
  domain: "localhost"         # Base domain for services
  description: "My app"       # Optional description
  plugins: [supabase]         # Enable plugins (e.g., supabase)
```

### Service Definitions

Services map local ports to routable URLs:

```yaml
network:
  services:
    # Full service definition
    frontend:
      dial: "127.0.0.1:5173"      # Local address:port
      host: "app.localhost"        # Host-based routing
      paths: ["/"]                 # Path-based routing

    # API service with path routing
    api:
      dial: "127.0.0.1:8080"
      paths: ["/api"]
      stripPrefix: true            # Remove /api prefix before forwarding

    # Service with public tunnel
    webhook-receiver:
      dial: "127.0.0.1:9000"
      public: true                 # Enable public tunnel for this service
      subdomain: "webhook"         # Subdomain: webhook-x7k9m2.relay.example.com
```

**Service Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `dial` | `string` | Local address:port (e.g., `127.0.0.1:3000`) |
| `host` | `string` | Host-based routing domain |
| `paths` | `string[]` | Path prefixes for routing |
| `stripPrefix` | `boolean` | Remove path prefix before forwarding |
| `public` | `boolean` | Enable public tunnel for this service |
| `subdomain` | `string` | Subdomain prefix for tunnel URL |
| `priority` | `number` | Route ordering (higher = first) |
| `description` | `string` | Human-readable description |
| `securityHeaders` | `object` | Security header configuration (see below) |
| `iframeOrigin` | `string\|null` | Origin for iframe embedding (`null` to disable) |
| `deleteResponseHeaders` | `string[]` | Response headers to strip from upstream |
| `ingressTag` | `string\|null` | Per-service ingress tag (overrides `ASD_INGRESS_TAG` env) |
| `env` | `Record<string, string>` | Env vars written to `.env` during `net apply` (supports template macros) |

> **Note:** `tunnelPreferred` and `tunnelPrefix` are deprecated aliases for `public` and `subdomain`. They still work for backward compatibility.

### Understanding Service IDs

Every service has a unique identifier (`service-id`) used in CLI commands. The service-id is the key name from your `asd.yaml`:

```yaml
network:
  services:
    my-frontend:        # service-id = "my-frontend"
      dial: "127.0.0.1:3000"

    api-server:         # service-id = "api-server"
      dial: "127.0.0.1:8080"
```

**Finding service-ids:**
- **From config:** Look at `network.services` keys in `asd.yaml`
- **From TUI:** Run `via net` - IDs shown in the Services table
- **Plugin services:** Use namespaced IDs like `supabase:studio`, `supabase:kong`

**Using service-ids in commands:**
```bash
via net expose start my-frontend    # Start tunnel for "my-frontend"
via net stop api-server             # Stop "api-server"
via net open supabase:studio        # Open Supabase Studio in browser
```

### Feature Flags

```yaml
features:
  auto_detect_services: true      # Auto-discover running services
  auto_onboard_detected: true     # Auto-add discovered services to registry
  auto_install_binaries: true     # Download Caddy, ttyd on init
  auto_start_caddy: false         # Start Caddy automatically
  auto_start_tunnel: false        # Start the relay client (asd-tunnel) automatically
  auto_start_ttyd: false          # Start web terminal automatically
  enable_restricted_ports: false  # Allow ports 80/443 (requires sudo)
  disable_authentication: false   # Disable basic auth globally
```

### Automation Tasks

Define reusable tasks that can be run with `via run <task>`:

```yaml
automation:
  dev:
    - run: "pnpm dev"
      background: true
    - waitFor: "http://localhost:3000"

  prod:
    - run: "pnpm build && pnpm preview"
      background: true

  start:
    - run: "docker compose up -d"
    - waitFor: "http://localhost:8080"
```

**Run tasks with:**
```bash
via run dev               # Simple, recommended way
via run prod
via up --task=dev         # Alternative with more options
```

**Task Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `run` | `string` | Command to execute (alias for `command`) |
| `background` | `boolean` | Run in background (daemon mode) |
| `waitFor` | `string` | Wait for URL to become available |
| `timeout` | `number` | Timeout in milliseconds |
| `environment` | `object` | Environment variables |

**Convention-based defaults:**

When running `via up` without `--task`, it tries these names in order:
1. `up`
2. `dev`
3. `start`

### Caddy/TLS Settings

```yaml
network:
  caddy:
    enable: true
    tls:
      enabled: true               # Enable HTTPS
      auto: true                  # Auto-generate certificates

    # Optional: Basic authentication
    basic_auth:
      enabled: true
      realm: "My Project"
      routes: ["host", "path"]    # Which routes to protect
```

### Basic Authentication

Protect services with HTTP Basic Auth:

```yaml
# Project-level (applies to all services)
network:
  caddy:
    basic_auth:
      enabled: true
      realm: "Restricted Area"

  services:
    # Override per-service
    public-api:
      dial: "127.0.0.1:3000"
      basic_auth:
        enabled: false            # No auth for this service

    admin-panel:
      dial: "127.0.0.1:8080"
      basic_auth:
        enabled: true
        realm: "Admin Only"
        routes: ["host"]          # Only protect host routes
```

Set credentials in `.env`:
```bash
ASD_BASIC_AUTH_USERNAME=admin
ASD_BASIC_AUTH_PASSWORD=your-secure-password
```

### Route Options (Caddy)

Fine-tune how Caddy handles requests for individual services using route options. These are passed directly to the Caddy route builder.

#### Security Headers

Add security-related response headers to a service:

```yaml
network:
  services:
    admin-panel:
      dial: "127.0.0.1:3000"
      securityHeaders:
        enableHsts: true              # Strict-Transport-Security header
        hstsMaxAge: 31536000          # Max-age in seconds (default: 1 year)
        frameOptions: "DENY"          # X-Frame-Options: DENY or SAMEORIGIN
        enableCompression: true       # Enable response compression
```

**`securityHeaders` properties:**

| Property | Type | Description |
|----------|------|-------------|
| `enableHsts` | `boolean` | Add `Strict-Transport-Security` header |
| `hstsMaxAge` | `number` | HSTS max-age in seconds |
| `frameOptions` | `"DENY"\|"SAMEORIGIN"` | `X-Frame-Options` header value |
| `enableCompression` | `boolean` | Enable gzip/zstd response compression |

#### Iframe Embedding

Allow a service to be embedded in an iframe from a specific origin. Useful for dashboard integrations:

```yaml
network:
  services:
    supabase:studio:
      iframeOrigin: "https://dashboard.example.com"
      deleteResponseHeaders: ["Content-Security-Policy"]
```

- **`iframeOrigin`** — Sets the `X-Frame-Options: ALLOW-FROM <origin>` header. Set to `null` to explicitly disable.
- **`deleteResponseHeaders`** — Strips listed headers from upstream responses. Often needed to remove `Content-Security-Policy` or `X-Frame-Options` headers that the upstream service sets, so Caddy's headers take effect instead.

#### Ingress Tagging

Tag routes with an identifier for monitoring or routing purposes:

```yaml
network:
  services:
    api:
      dial: "127.0.0.1:8080"
      ingressTag: "production-api"    # Overrides ASD_INGRESS_TAG env var
```

The ingress tag is added as a response header. By default, all services use the value from the `ASD_INGRESS_TAG` environment variable (or `"local-caddy"`). Set `ingressTag` per-service to override, or set to `null` to disable.

### Declarative Environment Variables

Services can declare environment variables that are automatically written to `.env` during `via net apply`. This is useful for configuring services with tunnel URLs that are only known after tunnels are created.

```yaml
network:
  services:
    frontend:
      dial: "127.0.0.1:5173"
      public: true
      subdomain: app
      env:
        PUBLIC_WEBSITE_BASE_URL: "${{ macro.exposedOrigin() }}"
        SUPABASE_AUTH_SITE_URL: "${{ macro.exposedOrigin() }}"
```

After `via net apply`, your `.env` will contain:

```bash
PUBLIC_WEBSITE_BASE_URL=https://app-x7k9m2.relay.example.com
SUPABASE_AUTH_SITE_URL=https://app-x7k9m2.relay.example.com
```

**Key behaviors:**

- Values support all template macros (`${{ macro.* }}`, `${{ env.* }}`)
- The parameterless `exposedOrigin()` reads the `subdomain` from the same service block
- If no relay is enrolled (no tunnel credentials), the env var is skipped (not written as empty)
- Writing is idempotent — re-running `net apply` only writes if values changed
- Use `exposedOriginWithAuth()` to include basic auth credentials in the URL

**Example with auth URL:**

```yaml
env:
  APP_URL: "${{ macro.exposedOriginWithAuth() }}"
  # Result: https://admin:password@app-x7k9m2.relay.example.com
  # Reads ASD_BASIC_AUTH_USERNAME and ASD_BASIC_AUTH_PASSWORD from .env
```

---

## Plugins Configuration

Plugins extend the CLI with network services from external tools like Supabase.

### Enabling Plugins

```yaml
project:
  name: "my-app"
  plugins: [supabase]           # List of enabled plugins
```

### Available Plugins

| Plugin | Description | Services |
|--------|-------------|----------|
| `supabase` | Local Supabase integration | `supabase:studio`, `supabase:kong`, `supabase:mailpit` |

### Plugin Services in Network

Plugin services automatically appear in the network registry. You can customize them with overlays:

```yaml
network:
  services:
    # Overlay: customize a plugin service (no 'dial' - uses plugin default)
    supabase:studio:
      paths: ["/studio"]          # Custom path routing
      public: true                # Enable public tunnel
      priority: 40                # Route priority

    # Full service: your own service (has 'dial')
    my-app:
      dial: "127.0.0.1:3000"
      host: "app.localhost"
```

**Overlay vs Full Service:**

| Aspect | Overlay | Full Service |
|--------|---------|--------------|
| Has `dial` | No (uses plugin default) | Yes (required) |
| Purpose | Customize plugin service | Define your own service |
| Example | `supabase:studio:` | `my-app:` |

### Plugin Commands

Plugins may register CLI commands using the `plugin:<name>:<command>` pattern:

```bash
# Supabase plugin commands
via plugin:supabase:bootstrap   # Start + extract env vars
via plugin:supabase:start       # Start services
via plugin:supabase:stop        # Stop services
via plugin:supabase:extract     # Extract env vars only
```

### Tunnel Protocol for Plugins

Plugin services use HTTP tunneling by default. To use TCP tunneling:

```yaml
network:
  services:
    supabase:kong:
      tunnelProtocol: "tcp"       # Override to TCP
      public: true
```

### Plugin Service IDs

Plugin services use namespaced IDs: `<plugin>:<service>`

Examples:
- `supabase:studio` - Supabase Studio dashboard
- `supabase:kong` - Supabase API Gateway
- `supabase:mailpit` - Email testing UI

Use these IDs in commands:

```bash
via net open supabase:studio    # Open in browser
via net expose start supabase:kong  # Start tunnel
```

### Template Macros Reference

Template macros (`${{ macro.X }}`, `${{ env.X }}`, `${{ core.X }}`) have
moved to a dedicated reference that's generated from the engine itself
— that way the doc can't drift from the code:

- 📖 **[Template Macros reference](./TEMPLATE_MACROS.md)** — all 30
  macros, grouped, with runnable examples. Regenerated from
  `via macro --json` by `just docs-generate`.
- 🔴 **Live**: `via macro` for the grouped list, `via macro <name>`
  for detail. Forgiving lookup — `via macro exposedOrigin` works.
- 💡 **Where each one resolves**: `tpl.env` accepts only the four
  allocator macros (`getRandomPort`, `getRandomPorts`,
  `getRandomString`, `getPortRange`). All 30 work inside
  `asd.yaml` service `env:` blocks and `packages/*/net.manifest.yaml`
  `env:` blocks.
- 🔁 **Chaining**: service/manifest env blocks feed-forward per key
  so later keys can reference earlier ones via `env:VAR`.
  Syntactically nested `${{ ... ${{ ... }} ... }}` is **not**
  supported — the engine's regex stops at the first inner `}}`.

Legacy `${VAR}` syntax is still accepted in `net.manifest.yaml` for
backward compatibility; new code should use `${{ macro.X }}`.

---


## Initialization & Workspace

### `via init`

Full workspace initialization:

```bash
via init
```

**What it does:**
1. Creates `asd.yaml` if missing (from template)
2. Creates `.asd/workspace/` directory
3. Downloads helper binaries (Caddy, ttyd)
4. Optionally discovers running services
5. Sets up `.env` from template

**Options:**
```bash
via init --yes              # Accept all defaults (non-interactive)
via init --skip-binaries    # Skip binary downloads
```

### `via env-init`

Manage environment variables only:

```bash
via env-init                # Merge with existing .env
via env-init --override     # Replace entire .env
```

### Workspace Structure

```
your-project/
├── asd.yaml                 # Project configuration
├── .env                     # Environment variables
└── .asd/                    # (if using submodule)
    └── workspace/           # Runtime state (git-ignored)
        ├── bin/             # Downloaded binaries (optional)
        ├── network/
        │   └── registry.json  # Service registry
        ├── caddy/           # Caddy config and data
        ├── tunnels/         # Tunnel state
        └── logs/            # Service logs
```

### Binary Storage

By default, binaries are installed globally:

| OS | Location |
|----|----------|
| Linux | `~/.local/share/asd/bin/` |
| macOS | `~/Library/Application Support/asd/bin/` |
| Windows | `%LOCALAPPDATA%/asd/bin/` |

To use per-project binaries, set `ASD_BIN_LOCATION=workspace` in `.env`.

---

## Global Configuration

User preferences are stored globally and apply to all projects.

**Config Location:**

| OS | Path |
|----|------|
| Linux | `~/.config/asd/config.yaml` |
| macOS | `~/Library/Application Support/asd/config.yaml` |
| Windows | `%APPDATA%/asd/config.yaml` |

### Available Preferences

```yaml
# ~/.config/asd/config.yaml
version: 1
preferences:
  auto_install_binaries: true     # Download binaries on init
  bin_location: "global"          # "global" or "workspace"
  skip_binaries: []               # Modules to skip (e.g., ["codeserver"])

tui:
  borderStyle: "honeywell"        # "honeywell" or "minimal"

vault:                            # where `via vault` keeps secrets
  provider: s3                    # "local" (default) or "s3"
  scope: default                  # scope for names without one
  s3:
    bucket: my-secrets
    endpoint: https://<account>.r2.cloudflarestorage.com   # omit for AWS S3
    # credentials: S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY env, or `profile: <name>`
```

A project's `asd.yaml` may set only `vault.scope` and `vault.s3.prefix`
(where secrets go is never taken from a repository); see
[Secrets in the command reference](./um_commands.md#secrets-via-vault).

### Setting Preferences

Use environment variables to override:

```bash
# In .env or shell
ASD_BIN_LOCATION=workspace        # Per-project binaries
ASD_SKIP_BINARIES=codeserver,mitmproxy  # Skip specific binaries
```

---

## Service Management

### Network TUI

The interactive TUI provides real-time service monitoring:

```bash
via net
```

**Keyboard shortcuts:**
| Key | Action |
|-----|--------|
| `Tab` | Cycle tabs (Services, Projects, Logs) |
| `Enter` | Open actions menu for selected service |
| `Ctrl+R` | Refresh services |
| `Ctrl+Q` | Quit |
| `↑/↓` | Navigate services |

**Status Icons:**
| Icon | Meaning |
|------|---------|
| ✅ | Healthy |
| ⚪ | Not checked |
| ⛔ | Failed |
| 🐳 | Docker container |
| 💻 | Local process |

### CLI Commands

**Apply configuration:**
```bash
via net apply              # Apply asd.yaml, start Caddy
via net apply --caddy      # Start Caddy reverse proxy
via net apply --tunnel     # Start tunnels for tunnel-preferred services
```

**Service operations:**
```bash
via net refresh            # Re-detect services and update health
via net start <id>         # Start a service
via net stop <id>          # Stop a service
via net remove <id>        # Remove from registry
via net open <id>          # Open service URL in browser
```

**Discovery:**
```bash
via net discover           # Scan for running services
via net pending            # List services pending onboarding
via net onboard <id>       # Add discovered service to registry
```

**Maintenance:**
```bash
via net clean              # Remove stale entries
via net reset              # Clear registry and restart
```

### Health Checks

Services are validated through a multi-level cascade:

1. **Tunnel Check** - Public URL accessibility
2. **HTTP Check** - Endpoint response validation
3. **TCP Check** - Port connectivity
4. **Process Check** - PID verification

Refresh health status:
```bash
via net refresh            # Update all health checks
via net healthcheck <id>   # Check specific service
```

---

## Tunnels (Public Access)

Create secure public URLs for local services.

### Starting Tunnels

**From TUI:**
1. `via net` to open TUI
2. Select a service
3. Press `Enter` -> "Start Tunnel"

**From CLI:**
```bash
via net expose start <service-id>
via net expose start --all        # Start all tunnel-preferred services
```

### Stopping Tunnels

```bash
via net expose stop <service-id>
via net expose stop --all
via net expose reset              # Kill all tunnels, clear state
```

### Tunnel Configuration

Configure tunnels in `asd.yaml`:

```yaml
network:
  services:
    my-app:
      dial: "127.0.0.1:3000"
      public: true                 # Enable tunnel for this service
      subdomain: "myapp"           # URL: myapp-x7k9m2.relay.example.com
      tunnelProtocol: "http"       # "http" or "tcp"
```

**Tunnel URL Format:**
```
https://{prefix}-{client-id}.{relay-domain}   # relay shared by several devices
https://{prefix}.{relay-domain}               # your own (dedicated) relay
```

## Exposing Services

The CLI provides multiple ways to expose local services. Choose based on your needs.

### Quick Exposure (`via expose`)

One-command service exposure through Caddy with optional public tunnel:

```bash
via expose 3000                    # Expose port 3000 via Caddy
via expose 3000 --name myapp       # With name prefix in tunnel URL
```

The `--name` sets a prefix for the tunnel URL: `<name>-<client-id>.<relay-domain>` (on your own dedicated relay: `<name>.<relay-domain>`). `--server <relay-name>` publishes through another enrolled relay, `--domain <host>` under another domain of the relay.

**What it does:**
1. Starts Caddy if not running
2. Creates local route (e.g., `myapp.localhost`)
3. Optionally creates public tunnel

**Managing exposed services:**
```bash
via expose list                    # List all exposed services
via expose stop myapp              # Stop by name
via expose stop 3000               # Stop by port
```

### Tunnel Authentication

There is no default relay. Before using tunnels, enrol this device on a relay
with the link from the relay's dashboard (quote it):

```bash
via relay add '<enrolment link>'
```

A private, self-hosted relay is added by host and key:
`via relay add <name> --host <host> --key <path> [--port <port>] [--domain <domain>]`.

**Check status:**
```bash
via relay list                     # Relays this device knows, the default marked
via relay info <name>              # Details of one relay
```

> **Note:** `via login` signs you in to your viaalink.com account; relay credentials come from `via relay add '<enrolment link>'`.

### Network Tunnel Control (`via net expose`)

Enable/disable tunnels for services defined in `asd.yaml`:

```bash
via net expose start <service-id>  # Enable tunnel for service
via net expose start --all         # Enable all tunnel-preferred services
via net expose stop <service-id>   # Disable tunnel
via net expose reset               # Kill all tunnels, clear state
```

### When to Use Each

| Need | Use |
|------|-----|
| Quick share a port | `via expose <port>` |
| Share a configured service | `via net expose start <service-id>` |
| Enrol on a relay | `via relay add '<enrolment link>'` |
| Sign in to viaalink.com | `via login` |
| Switch credentials | `via auth switch` |

---

## GitHub Integration (`via gh`)

Remote development and CI/CD integration.

### Setup

Install GitHub workflows for remote terminal access:

```bash
via gh setup
```

This adds `.github/workflows/terminal.yml`. The workflow publishes through
your relay with a device key kept in four repository secrets. On a device
enrolled on the relay (`via relay add '<enrolment link>'`), run
`via auth export` and store each value it prints as a secret of the same name:

| Secret | Value |
|--------|-------|
| `ASD_TUNNEL_KEY` | The device key (base64) |
| `ASD_TUNNEL_KEY_ID` | The device key's id |
| `ASD_TUNNEL_HOST` | The relay host |
| `ASD_TUNNEL_PORT` | The relay SSH port (optional; 2222 when unset) |

```bash
gh secret set ASD_TUNNEL_KEY --repo <owner>/<repo>   # paste the value; repeat per secret
```

Whoever opens the terminal can read that key on the runner, so enrol a
device for CI alone. `via gh terminal` checks the secrets are there before it
starts a run.

### Remote Terminal

Start a web terminal in GitHub Actions:

```bash
via gh terminal
```

This triggers a workflow that:
1. Installs the CLI on the runner
2. Starts a ttyd web terminal (or code-server)
3. Publishes it through your relay with the key from the repository secrets
4. Provides a URL to access the terminal

### Available Commands

```bash
via gh                     # Show GitHub integration menu
via gh setup               # Install workflow files
via gh terminal            # Start remote terminal session
via gh list                # List recent workflow runs
via gh runs                # Show active runs
via gh active              # Check active sessions
via gh stop                # Stop running session
via gh login               # Configure GitHub authentication
```

---

## Updates

### Self-Update

```bash
via update                 # Update to latest version
via update --check         # Check for updates only
via update --force         # Force reinstall
```

### Version Information

```bash
via --version              # Current version
via update version         # Current and latest versions
```

---

## Troubleshooting

### Common Issues

**"Caddy won't start":**
```bash
via caddy stop
rm -rf .asd/workspace/caddy/
via caddy start
via net apply
```

**"Tunnels not connecting":**
```bash
pkill -f "asd-tunnel"
rm -rf .asd/workspace/tunnels/
via net apply --tunnel
```

**"Services not appearing":**
```bash
via net refresh            # Re-scan for services
via net discover           # Manual discovery
```

**"Registry corruption":**
```bash
rm .asd/workspace/network/registry.json
via net apply
```

### Full Reset

When everything is broken:

```bash
# Stop all processes
pkill -f "caddy run"
pkill -f "asd-tunnel"

# Remove runtime state
rm -rf .asd/workspace/

# Re-initialize
via init
via net apply --caddy --tunnel
```

### Debug Mode

Enable verbose output:

```bash
ASD_DEBUG=1 via net apply
ASD_VERBOSE=1 via init
```

### Logs

View service logs:

```bash
via logs caddy             # Caddy proxy logs
via logs tunnel            # Tunnel logs
```

Logs are stored in `.asd/workspace/logs/`.

---

## Command Reference

### Core Commands

| Command | Description |
|---------|-------------|
| `via init` | Initialize workspace |
| `via login` | Sign in to your viaalink.com account |
| `via help` | Show help |
| `via --version` | Show version |
| `via update` | Self-update |

### Network Commands

| Command | Description |
|---------|-------------|
| `via net` | Open network TUI |
| `via net apply` | Apply configuration |
| `via net refresh` | Refresh health checks |
| `via net discover` | Discover services |
| `via net start <id>` | Start a service |
| `via net stop <id>` | Stop a service |
| `via net open <id>` | Open service URL in browser |
| `via net expose start <id>` | Start tunnel for service |
| `via net expose stop <id>` | Stop tunnel for service |
| `via net expose reset` | Kill all tunnels, clear state |

### Service Commands

**Interactive Menus:**

| Command | Description |
|---------|-------------|
| `via code` | VS Code server menu (status, URLs, start/stop) |
| `via terminal` | Web terminal menu |
| `via database` | Database manager menu (DbGate) |
| `via inspect` | Network inspector menu (mitmproxy) |

**Direct Commands:**

| Command | Description |
|---------|-------------|
| `via code start` | Start VS Code server |
| `via code stop` | Stop VS Code server |
| `via terminal start` | Start web terminal (ttyd) |
| `via terminal stop` | Stop web terminal |
| `via database start` | Start database manager |
| `via database stop` | Stop database manager |
| `via inspect start` | Start network inspector |
| `via inspect stop` | Stop network inspector |
| `via caddy start` | Start Caddy reverse proxy |
| `via caddy stop` | Stop Caddy reverse proxy |
| `via caddy restart` | Restart Caddy |

### Expose Commands

| Command | Description |
|---------|-------------|
| `via expose <port>` | Expose port via Caddy + tunnel |
| `via expose <port> --name <name>` | Expose with custom name |
| `via expose list` | List exposed services |
| `via expose stop <name>` | Stop exposed service |

### Auth Commands

| Command | Description |
|---------|-------------|
| `via login` | Sign in to your viaalink.com account |
| `via logout` | Sign out of viaalink.com |
| `via whoami` | Show the signed-in account and its licenses |
| `via auth switch` | Interactive credential and relay switcher |
| `via auth export` | Export the active relay key as env vars (Docker/CI) |

### Relay Commands

| Command | Description |
|---------|-------------|
| `via relay add '<enrolment link>'` | Enrol this device on a relay |
| `via relay add <name> --host <host> --key <path>` | Add a private, self-hosted relay |
| `via relay list` | List relays |
| `via relay info <name>` | Show relay details |
| `via relay set <name>` | Set the default relay |
| `via relay rotate-key [name]` | Replace this device's key on its relay |
| `via relay remove <name>` | Sign out of the relay and remove it locally |

### GitHub Commands

| Command | Description |
|---------|-------------|
| `via gh` | Show GitHub integration menu |
| `via gh setup` | Install workflows |
| `via gh terminal` | Start remote terminal |
| `via gh list` | List workflow runs |
| `via gh runs` | Show active workflow runs |
| `via gh active` | Check active sessions |
| `via gh stop` | Stop running session |
| `via gh login` | Configure GitHub authentication |

---

## Getting Help

- **GitHub Issues:** https://github.com/viaalink/cli/issues
- **Releases:** https://github.com/viaalink/cli/releases
- **Documentation:** `via docs` (built-in documentation browser)

---

## Platform Guides

Platform-specific documentation for non-standard environments:

| Platform | Guide |
|----------|-------|
| Android (Termux) | [um_termux.md](./um_termux.md) |

---

[Back to User Manual](./USER_MANUAL.md)
