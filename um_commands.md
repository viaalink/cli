# Viaalink CLI Command Reference

**Version:** 2.7.1 | **Last Updated:** 2026-11-09

Complete reference for all Viaalink CLI commands.

`via` and `asd` are the same command; older scripts that call `asd` keep working.

---

## Quick Reference

**Complete list of every `via <cmd>`** — all 209 commands across 41
groups — lives in **[`docs/generated/COMMANDS.md`](./generated/COMMANDS.md)**,
generated from `registerCommand(...)` call sites and kept in sync by
a CI drift test. For per-command help and flags, run
`via <command> --help`. For the live grouped list,
`via core list-commands` (or just `via help`).

This document covers the **day-to-day workflow commands** below with
additional context — how to use them together, common patterns, and
flags that aren't obvious from `--help` alone. Knowledge commands
(`via macro`, `via schema`, `via rules`, `via flow`) are documented
in their own files:

- [docs/TEMPLATE_MACROS.md](./TEMPLATE_MACROS.md) — every macro
- [docs/generated/ASD_YAML_SPEC.md](./generated/ASD_YAML_SPEC.md) — every `asd.yaml` field
- [docs/generated/NET_MANIFEST_SPEC.md](./generated/NET_MANIFEST_SPEC.md) — every `net.manifest.yaml` field
- [docs/generated/AUTOMATION_SPEC.md](./generated/AUTOMATION_SPEC.md) — every automation step type

---

## Core Commands

### `via init`

Initialize a project workspace with configuration and binaries.

```bash
via init              # Interactive setup
via init --yes        # Accept all defaults
ASD_SKIP_BINARIES=all via init  # Skip binary downloads
```

**What it does:**
1. Creates `asd.yaml` configuration file
2. Creates the `.via/` state directory (`.via/workspace/`) and adds `.via/` to `.gitignore` in a git repository
3. Downloads helper binaries (Caddy, ttyd, code-server)
4. Sets up `.env` from template
5. Optionally discovers running services

### `via env-init`

Manage environment variables in `.env` file.

```bash
via env-init              # Merge with existing .env
via env-init --override   # Replace entire .env
```

### `via config validate`

Validate `asd.yaml` configuration against the schema.

```bash
via config validate          # Human-readable output
via config validate --json   # JSON output (for CI/scripts)
```

**What it checks:**
- Schema validation (required fields, types, structure)
- Service configuration (valid dial addresses, paths)
- Feature flags and plugin references

### `via run <task>`

Run an automation task defined in `asd.yaml`. This is the simplest way to start your development environment.

```bash
via run dev               # Run the 'dev' task
via run prod              # Run the 'prod' task
via run start             # Run the 'start' task
via run                   # Show available tasks
```

**What it does:**
1. Reads `automation:` section from `asd.yaml`
2. Starts the specified task in the background
3. Shows rich output with service status and tunnel URLs

**Example asd.yaml:**
```yaml
automation:
  dev:
    - run: "pnpm dev"
      background: true
  prod:
    - run: "pnpm build && pnpm preview"
      background: true
```

**Options:**
- `--follow` or `-f`: Follow logs after starting
- `--json`: Output JSON format

**See also:** `via up` for more advanced options like `--env` flag.

### `via login`

Sign this device in to your viaalink.com account with a device code: the CLI
prints a code and a link, you approve it in the browser, and the session is
stored for this user.

```bash
via login                # Opens the link in a browser
via login --no-browser   # Only prints the link and the code
```

Signing in does not give this device relay credentials; those come from
`via relay add '<invite link>'`.

### `via logout`

Sign this device out of viaalink.com and revoke its session.

```bash
via logout
```

### `via whoami`

Show the signed-in viaalink.com account and its licenses.

```bash
via whoami
```

### `via update`

Update the CLI to the latest version.

```bash
via update           # Update to latest
via update --check   # Check for updates only
via update --force   # Force reinstall
```

---

## Expose Commands

Quick port exposure with tunnels.

### `via expose <port>`

Expose a local port instantly.

```bash
via expose 3000                    # Basic exposure
via expose 3000 --name myapp       # Named tunnel (prefix in URL)
via expose 3000 --local-only       # No tunnel, local Caddy only
via expose 3000 --server home      # Publish through a named relay
```

**Options:**

| Option | Description |
|--------|-------------|
| `--name <name>` | Name prefix for tunnel URL |
| `--local-only` | No tunnel, local Caddy routing only |
| `--server <relay>` | Publish through this relay instead of the default one |
| `--domain <host>` | Publish under another domain the relay serves |
| `--auth=basic\|none` | Login in front (basic is the default). `--auth=basic` with no project login set (`ASD_BASIC_AUTH_USERNAME` / `ASD_BASIC_AUTH_PASSWORD`) is refused: nothing is published |
| `--json` | Print the result as one JSON object on stdout; every other line goes to stderr |

**Output:**
```
📍 Published:   https://myapp-abc123.relay.example.com  (answers HTTP 401)
   Your app:    localhost:3000
   Local route: http://myapp.localhost  (this machine only, answers HTTP 401)
```

**Exit codes:**

| Code | Meaning |
|------|---------|
| `0` | Published, and the app answers through the published address (with `--local-only`: the app answers) |
| `3` | Published (the relay routes the address to this machine), but the app does not answer yet, e.g. HTTP 502 because it has not started |
| `1` | Not published: the tunnel failed, or the command refused before anything started |

A CI job can expose first and start its app afterwards: exit 3 means "start the app", exit 1 means "fix the setup".

**JSON (`--json`):**

```bash
via expose 8080 webhooks --auth=none --json
```

```json
{"id":"webhooks","url":"https://webhooks.relay.example.com/","state":"online","tunnelUp":true,"appUp":true}
```

| Field | Meaning |
|-------|---------|
| `id` | The service id (the name), as `via expose list --json` and `via expose stop` use it |
| `url` | The published address once the relay routes it; otherwise the local route (`null` with `--direct`, which has none) |
| `state` | As in `via expose list`: `online`, `stale` (published, app not answering) or `local` (not published) |
| `tunnelUp` | The relay routes the published address to this machine |
| `appUp` | The app answers on its port, like `via expose list --json`'s `appUp` |

When the command refuses before anything starts (a bad port, a login that is due and not set), stdout stays empty and the exit code is 1.

The `--name` option sets a prefix. On a relay shared by several devices the URL is `<name>-<client-id>.<relay-domain>`; on your own (dedicated) relay nothing is appended (`<name>.<relay-domain>`).

**Interactive prompts:** When running in a terminal, prompts for binary installation if needed. Without an enrolled relay it tells you to run `via relay add`.

### `via expose list`

List all exposed services with tunnel URLs.

```bash
via expose list
```

**Output:**
```
myapp
    Published:   https://myapp-abc123.relay.example.com
    Port:        3000
    Status:   ✅ Online
    Uptime:   🕐 2h 15m
```

### `via expose stop`

Stop an exposed service.

```bash
via expose stop myapp    # Stop by name
via expose stop 3000     # Stop by port
```

---

## Network Commands

Network management and TUI.

### `via net`

Open the interactive network TUI.

```bash
via net
```

**TUI Controls:**
| Key | Action |
|-----|--------|
| `Tab` | Cycle tabs (Services, Projects, Logs) |
| `Enter` | Actions menu for selected service |
| `Ctrl+R` | Refresh health checks |
| `Ctrl+Q` | Quit |
| `↑/↓` | Navigate services |

### `via net apply`

Apply network configuration.

```bash
via net apply              # Apply all (Caddy routes)
via net apply --caddy      # Start Caddy reverse proxy
via net apply --tunnel     # Start tunnels for services
via net apply --ids svc1,svc2  # Apply specific services only
```

### `via net refresh`

Refresh service detection and health checks.

```bash
via net refresh
```

### `via net discover`

Discover running services.

```bash
via net discover
```

### `via net expose`

Manage tunnels for services.

```bash
via net expose start <service-id>    # Start tunnel
via net expose start --all           # Start all public services
via net expose stop <service-id>     # Stop tunnel
via net expose stop --all            # Stop all tunnels
via net expose reset                 # Kill all, clear state
```

### `via net start/stop`

Start or stop a service.

```bash
via net start <service-id>
via net stop <service-id>
```

### `via net open`

Open service URL in browser.

```bash
via net open <service-id>
```

### `via net remove`

Remove a service: stop its tunnel (its public address closes), remove its Caddy routes and its registry entry. To stop sharing a service for good, delete it from `via.yaml` instead: the next `via net apply` does the same, and a service still in `via.yaml` comes back on the next apply.

```bash
via net remove <service-id>
```

### `via net clean`

Remove stale registry entries.

```bash
via net clean
```

### `via net reset`

Full registry reset.

```bash
via net reset
```

---

## Service Commands

Built-in service management.

### `via terminal`

Web terminal (ttyd) management.

```bash
via terminal          # Interactive menu
via terminal start    # Start ttyd
via terminal stop     # Stop ttyd
```

**Required environment:**
- `ASD_TTYD_USERNAME` - Login username
- `ASD_TTYD_PASSWORD` - Login password

### `via code`

VS Code server (code-server) management.

```bash
via code          # Interactive menu
via code start    # Start code-server
via code stop     # Stop code-server
```

### `via database`

Database UI (DbGate) management.

```bash
via database          # Interactive menu
via database start    # Start DbGate
via database stop     # Stop DbGate
```

### `via inspect`

Network inspector (mitmproxy) - Alpha.

```bash
via inspect          # Interactive menu
via inspect start    # Start mitmproxy
via inspect stop     # Stop mitmproxy
```

---

## Caddy Commands

Local reverse proxy management.

### `via caddy start`

Start Caddy reverse proxy.

```bash
via caddy start
```

### `via caddy stop`

Stop Caddy reverse proxy.

```bash
via caddy stop
```

### `via caddy restart`

Restart Caddy.

```bash
via caddy restart
```

### `via caddy config`

Show current Caddy configuration.

```bash
via caddy config
```

---

## Relays and Tunnel Authentication

There is no default relay. Before `via expose` or any other tunnel command can
publish a service, enrol this device on a relay. Signing in with `via login`
is separate and does not give the device relay credentials.

### `via relay add`

Enrol this device on a relay with the link from the relay's dashboard (quote it),
or register a private, self-hosted relay by host and key.

```bash
via relay add '<invite link>'           # Enrol from the relay's link
via relay add '<invite link>' --name home
via relay add <name> --host <host> --key <path> [--port <port>] [--domain <domain>]
```

### `via relay list` / `via relay info`

```bash
via relay list            # All relays this device knows, the default marked
via relay info <name>     # Details, capabilities and local credentials
```

### `via relay set`

Set the default relay used when a command does not name one.

```bash
via relay set <name>
```

Per command, `--server <relay-name>` picks another relay and `--domain <host>`
one of its other domains:

```bash
via expose 3000 --server <relay-name>
via expose 3000 --domain apps.example.com
```

### `via relay rotate-key`

Replace this device's key on its relay (default: the default relay).

```bash
via relay rotate-key [name]
```

### `via relay remove`

Sign this device out of the relay, then remove it locally.

```bash
via relay remove <name>
```

### `via auth export`

Export the active relay key as `VIA_TUNNEL_*` environment variables for use
in Docker or CI. The private key (`VIA_TUNNEL_KEY`) is printed only with
`--with-key`, so a plain run never leaves it in your scrollback or a log; a
note on stderr says it was left out. For a GitHub repository use
`via gh setup`, which stores the key as secrets without printing it.

```bash
via auth export                       # Shell export lines, without the private key
via auth export --docker              # Docker -e flags, without the private key
via auth export --with-key            # Also VIA_TUNNEL_KEY (the private key)
via auth export --docker --with-key
```

**Shell format output (`--with-key`):**
```bash
export VIA_TUNNEL_KEY="<base64-private-key>"
export VIA_TUNNEL_KEY_ID="<key-uuid>"
export VIA_TUNNEL_HOST="relay.example.com"
export VIA_TUNNEL_PORT="2222"
export VIA_TUNNEL_HOST_KEY_FINGERPRINTS="SHA256:...,SHA256:..."
```

**Docker format output (`--docker --with-key`):**
```bash
-e VIA_TUNNEL_KEY="<base64-private-key>" \
-e VIA_TUNNEL_KEY_ID="<key-uuid>" \
-e VIA_TUNNEL_HOST="relay.example.com" \
-e VIA_TUNNEL_PORT="2222" \
-e VIA_TUNNEL_HOST_KEY_FINGERPRINTS="SHA256:...,SHA256:..."
```

The CLI reads each `VIA_X` as `ASD_X`, so a runner or container with these set
publishes with the key.

**Usage examples:**
```bash
# Set env vars in current shell
eval $(via auth export --with-key)

# Pass to Docker
docker run $(via auth export --docker --with-key) my-image via expose 3000
```

> **Tip:** Relay credentials come from `via relay add '<invite link>'`; `via relay list` shows them.

---

## Secrets (`via vault`)

`via vault` keeps secrets encrypted on this machine before they go anywhere.
Two stores ("providers"):

- `local` (default): one file, `<data dir>/vault-store/local.json` (mode 0600;
  `~/.local/share/via/vault-store/` on Linux, or `$VIA_HOME/vault-store/`).
- `s3`: your own S3-compatible bucket (AWS S3, Cloudflare R2, Backblaze B2,
  MinIO, ...). Only ciphertext reaches the bucket. Secret **names** are
  visible to whoever runs the bucket; values, descriptions and categories
  are not.

Secrets live in **scopes** (default: `default`). A secret is referenced as
`via://<scope>/<name>`, e.g. `via://default/db/password`.

The key that opens your secrets is the **identity**, in your per-user config
directory (`~/.config/via/vault/identity` on Linux, or
`$XDG_CONFIG_HOME/via/vault/identity`; `~/Library/Application
Support/via/vault/identity` on macOS, `%APPDATA%\via\vault\identity` on
Windows; mode 0600, created on the first `vault set`). Before 3.2 these
directories were named `asd`; the CLI moves them to `via` on its first start
and leaves a link at the old name. It is kept apart from
the store on purpose and never leaves this machine. To use the same secrets
on another machine, copy that file there over a secure channel (same path,
mode 0600). Lose it and the secrets cannot be decrypted, so back it up, but
separately from the store and somewhere only you can read: anyone with both
can read every secret.

### Choosing the store

```bash
via config set vault.provider s3
via config set vault.s3.bucket my-secrets
via config set vault.s3.prefix via/          # optional, the default
via config set vault.scope default           # optional: scope for names without one
```

Then, per provider:

| Provider | `vault.s3.endpoint` | `vault.s3.region` |
|---|---|---|
| AWS S3 | leave unset | the bucket's region (e.g. `eu-central-1`); or `AWS_REGION` / `AWS_DEFAULT_REGION`, or `region` in your AWS profile. Required: there is no "auto" on AWS |
| Cloudflare R2 | `https://<account-id>.r2.cloudflarestorage.com` | leave unset (`auto`; `AWS_REGION` is ignored when an endpoint is set) |
| Backblaze B2 | `https://s3.<region>.backblazeb2.com` (e.g. `s3.eu-central-003.backblazeb2.com`) | the same region, e.g. `eu-central-003` |
| MinIO / Garage | `https://minio.example.com` (`http://` only for `localhost` / `127.0.0.1`) | your server's region, often `us-east-1` |

Credentials are never read from a config file: set `S3_ACCESS_KEY_ID` and
`S3_SECRET_ACCESS_KEY` (or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`), or
name a profile from `~/.aws/credentials` with `via config set vault.s3.profile <name>`.
The bucket must honour conditional writes (`If-Match` / `If-None-Match`); AWS
S3, R2 and current MinIO do. Before a scope is created, the vault checks this
with a short-lived probe object and refuses a bucket that ignores them.
`vault.s3.prefix` must be relative, without `..` segments or backslashes.

A project's `asd.yaml` may set only the scope and the key prefix; where
secrets go (provider, bucket, endpoint, region, profile) comes from your
global config alone, so a cloned repository cannot point your vault at
someone else's bucket:

```yaml
vault:
  scope: myapp
  s3:
    prefix: myapp/
```

`via config set` refuses a key the vault config does not have (such as an
access key under `vault.s3`) before writing anything.

### `via vault set` / `get` / `list` / `delete`

```bash
via vault set db/password                    # prompts for the value (hidden)
printf '%s' "$VALUE" | via vault set db/password --stdin
via vault set tls/key --file ./server.key    # binary files are kept as-is
via vault set api/token --scope work --category api --description "CI token"
via vault get db/password                    # prints the value
via vault get via://work/api/token
via vault list [--scope work]                # names and descriptions, never values
via vault delete db/password
```

A value is never accepted on the command line (`via vault set name value`
fails): it would end up in your shell history.

### `via vault inject`

Replace `${via://scope/name}` references in a template. The output file is
created readable by you only; a reference that does not resolve is an error.

```bash
via vault inject config.tpl config.yaml      # or omit the output for stdout
```

### `via vault run`

Run a command with secrets in its environment. The env template holds
`KEY=via://scope/name` or `KEY=...${via://scope/name}...` lines. Any secret
value the command prints is replaced by `***` (byte for byte, so binary
output passes through unchanged).

Limits of the masking: values shorter than 4 characters are not masked
(`vault set` warns below 6), and encoded forms of a secret (base64, URL- or
hex-encoded, split across words) are not recognised. Masking guards against
accidents, not against a command that wants to leak a secret.

With the `s3` provider, the command does not inherit the environment
variables the vault itself took its bucket credentials from (for example
`S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY`); every other variable, other
`AWS_*` ones included, passes through, so `vault run -- aws ...` or
`terraform` keep working. With the `local` provider nothing is removed.
This keeps the vault's key out of the command by accident; it is not a
security boundary against the command. Ctrl+C and SIGTERM are passed on to the command, and its exit
code is the exit code of `vault run`.

```bash
via vault run --env-file .env.vault -- bun dev
```

### `via vault import` / `export`

```bash
via vault import ./secrets --yes             # .env files become one secret per variable
via vault export ./restored                  # rebuilds the files (mode 0600)
```

---

## GitHub Integration

Remote development via GitHub Actions.

### `via ci install`

Viaalink CI/CD: a terminal, VS Code and your services in CI/CD jobs. Detects the repository's
provider from the `origin` remote and installs its terminal workflow; on
GitHub it does what `via gh setup` does, `--relay` included. GitLab support is
coming. `via ci` on its own only lists the commands.

The job runs on a GitHub-hosted runner, with the operating system picked per
session, unless you name a self-hosted runner pool: `--runs-on` takes the
pool's labels, comma-separated, and writes them as the job's
`runs-on: [self-hosted, linux, x64]` (the workflow then has no OS input). At a
terminal without the flag, `via ci install` asks, offering "custom labels".
Labels may only contain letters, digits, `.`, `_` and `-`.

```bash
via ci install
via ci install --relay github-ci   # store the key of the relay device kept for CI
via ci install --runs-on self-hosted,linux,x64   # run on your own runner pool
```

### `via gh`

Show GitHub integration menu.

```bash
via gh
```

### `via gh setup`

Install the terminal workflow (`.github/workflows/terminal.yml`) and, after
asking, store its secrets on the repository with `gh secret set`, each value
on gh's stdin (never an argument, never printed). The workflow is short: a
`workflow_dispatch` that calls the
[Viaalink CI/CD Action](https://github.com/viaalink/cicd)
(`uses: viaalink/cicd@v2`), which holds the session itself (installing
the CLI, the login, publishing through the relay, cleanup). It passes the
secrets below to the Action and maps the inputs `via gh terminal` sends (`os`
picks the runner; `shell`, `username`, `interface`, `tunnel-name` and
`cli-version` go to the Action). An existing `terminal.yml` that differs is
replaced only after you confirm; one that is already current is left as it is,
also one that still names the Action by its earlier name
`viaalink/ci-terminal@v2` (GitHub redirects it, so it keeps working).
The secrets:

- `VIA_TUNNEL_KEY`, `VIA_TUNNEL_KEY_ID`, `VIA_TUNNEL_HOST`, `VIA_TUNNEL_PORT`,
  `VIA_TUNNEL_HOST_KEY_FINGERPRINTS`: this device's relay key and the relay's
  host key pins (run it on a device enrolled on the relay; a key without pins
  is refused before anything is written, since a runner could not connect with it);
- `VIA_TERMINAL_PASSWORD`: the password of the login in front of the
  terminal, generated once and saved on this machine for `via gh terminal`.

Without `--relay` and with more than one relay enrolled, it asks which relay's
key goes to the runner, offering one that is not this laptop's own first; it
warns when the key it stores is this laptop's own (whoever opens the terminal
can read it on the runner). `via ci install` does the same and takes `--relay`
too.

It stores nothing without a terminal to confirm at. Before 3.2 the relay key
secrets were named `ASD_TUNNEL_*`; nothing reads those now. Run `via gh setup`
again in such a repository and then delete the old secrets
(`gh secret delete ASD_TUNNEL_KEY --repo <owner>/<repo>`, and so on).

```bash
via gh setup
```

### `via gh terminal`

Start remote terminal session in GitHub Actions. Stops before triggering when
the repository lacks the secrets above, or still has them under the pre-3.2
`ASD_TUNNEL_*` names, and says which to store with `via gh setup`. The login
password is never a workflow input (inputs show on the run's page).

```bash
via gh terminal                          # a terminal
via gh terminal --interface codeserver   # VS Code in the browser
via gh terminal --show-login             # also print the address with the login in it
via gh terminal --watch                  # keep watching the run after it is published
```

It starts in the current folder's project and shows the published address
first (`Published: https://…/`), without the login: the login is the username
(default `via`) and the password `via gh setup` saved on this machine;
`--show-login` prints the address with both in it, but only for an address
under the domain of a relay this device is enrolled on. Before it starts, one
line names the workflow, repository, branch, runner and interface
(`Start terminal.yml in o/r on main (runner ubuntu-latest, terminal)? [Y/n]`);
Enter starts it, and without a terminal only an explicit `y` does. `Run:` is
the run's page on GitHub. Once the session is published it prints how to stop
it (`via gh stop <run>`) and returns; `--watch` keeps following the run until
it ends. The address comes from the run's `tunnel-url-<session name>`
artifact, which the Viaalink CI/CD Action uploads; once it is there the
session is ready.

The installed `terminal.yml` runs one session per person at a time in a repository
(its `concurrency` group is keyed on the person): a second one would wait,
queued, until the first ends. So when one of yours is running there,
`via gh terminal` offers to reopen it, or to stop it and start a new one, not a
second session. A workflow without such a group (dev-terminal.yml, or one that
only calls the Viaalink CI/CD Action) can start a new session alongside. When the
GitHub account cannot be read (an app token, no network), nothing is assumed to
be yours: only a session you pick (`s1`, `s2`, …) is stopped, and stopping a
session someone else started asks first. After starting a session it follows
the new run of your account; when the account cannot be read it does not
follow any run (it might be a colleague's) and points to `via gh active`.

The inputs sent are the ones the workflow on that branch declares: the CLI
version goes as `cli-version`. An input the workflow does not take is named before the run
starts, the CLI version included. When the workflow on that branch cannot be
read, a picked CLI version is not sent (the run would be refused): it says so
and starts nothing; the workflow's default version starts as usual.

The version step offers the workflow's default, the latest release, the latest
nightly build from
[`viaalink/cli-nightly`](https://github.com/viaalink/cli-nightly/releases), or
a version to type. The workflow's default is the default choice: no version is
sent, and the Action installs the CLI build it is made for (the workflow's
`cli-version` input is empty unless you pick one). A nightly is used only when
you pick it (the latest nightly is then the default next time). For a
nightly tag (`v3.2.6-nightly.20261105T0212`) the Action installs the archive
from that nightly's release and checks it against the release's
`SHA256SUMS.txt`. In a repository whose `terminal.yml` an older CLI installed,
run `via gh setup` again (let it replace `terminal.yml`, then commit and push)
to move it onto the Action.

### `via gh list`

List recent workflow runs.

```bash
via gh list
```

### `via gh runs`

Recent terminal sessions of this repository, as a table (run, branch, state,
when it started); runs of other workflows are not listed.

```bash
via gh runs
```

### `via gh active`

Running and queued terminal sessions, each with its published address
(`--show-login` adds the address with the login) and its run's page.

```bash
via gh active
```

### `via gh stop`

Stop a running session: the only one, or the one you pick. A run id must be
digits only, belong to this project's repository and be a terminal session: a
run started by hand (`workflow_dispatch`) of `terminal.yml`, `dev-terminal.yml`
or a workflow that runs the Viaalink CI/CD Action unconditionally. Any other run,
such as CI (also one that adds the Action as an `if: failure()` debug step) or
a release, is refused. Stopping a session someone else started asks first,
with or without a run id; when the GitHub account cannot be read, every session
counts as someone else's. Without a terminal it stops only your own sessions and
exits 1 with "Not stopped: …" for any other.

```bash
via gh stop
via gh stop 42618438585
```

### `via gh login`

Configure GitHub authentication.

```bash
via gh login
```

---

## Skill Commands

AI assistant skill management.

### `via skill install`

Install skills for Claude Code and OpenAI Codex.

```bash
via skill install            # Install for current project
via skill install --global   # Install globally
via skill install --yes      # Non-interactive
```

### `via skill list`

List available skills.

```bash
via skill list
```

### `via skill status`

Check installation status of skills.

```bash
via skill status
```

---

## Dependency Management

Manage the CLI's binary dependencies (Caddy, ttyd, code-server, gh, etc.).

### `via deps install`

Install all managed binaries, or a specific one.

```bash
via deps install                  # Install all
via deps install caddy            # Install specific binary
via deps install --force          # Force reinstall even if present
```

**What it does:**
1. Downloads binaries from upstream (GitHub releases, official sites)
2. Verifies integrity via SHA-256/SHA-512 checksums
3. Installs to global location (`~/.local/share/asd/bin/`)

### `via deps update`

Update all binaries to their latest upstream versions, or a specific one.

```bash
via deps update                   # Update all outdated binaries
via deps update caddy             # Update specific binary
```

**What it does:**
1. Checks each binary's latest version on GitHub
2. Downloads and verifies new versions
3. Shows summary of what was updated

**Note:** Results are cached for 10 minutes to avoid excessive API calls. Uses `gh` CLI for authenticated requests when available.

---

## Logs

View service logs.

### `via logs <service>`

View logs for a service.

```bash
via logs caddy      # Caddy proxy logs
via logs tunnel     # Tunnel logs
via logs ttyd       # Terminal logs
```

Logs are stored in `.via/workspace/logs/`.

---

## Autocomplete

Shell tab-completion for all CLI commands.

### `via ac install`

Install shell completions. Auto-detects your shell, or specify one.

```bash
via ac install          # Auto-detect (bash/zsh/fish)
via ac install bash     # Install for bash
via ac install zsh      # Install for zsh
via ac install fish     # Install for fish
```

After installing, open a new terminal (or `source ~/.bashrc`) and use Tab to complete:

```
via ca<TAB>        → caddy
via caddy <TAB>    → start  stop  restart  config
```

### `via ac remove`

Remove shell completions.

```bash
via ac remove           # Remove for detected shell
via ac remove bash      # Remove for bash
```

### `via ac status`

Show autocomplete installation status across all shells.

```bash
via ac status
```

### `via ac refresh`

Refresh the completions cache (run after installing new commands or plugins).

```bash
via ac refresh
```

---

## Command Suggestions

If you mistype a command, the CLI will suggest similar commands:

```
$ via deos
Unknown command: deos

  Did you mean?

    deps install    Install managed binaries (--binary <name>, --force)
    deps update     Update a binary to latest upstream version

  Run 'via --help' to see available commands.
```

If you mistype a subcommand within a valid group, the CLI shows available subcommands:

```
$ via caddy strat
  Usage: via caddy <command>

  Available commands:

    start    Start Caddy reverse proxy
    stop     Stop Caddy reverse proxy
    restart  Restart Caddy
    config   Show Caddy configuration
```

---

## Global Options

Available for all commands:

| Option | Description |
|--------|-------------|
| `--help` | Show help for command |
| `--version` | Show version |

---

## Environment Variables

Key environment variables:

| Variable | Description |
|----------|-------------|
| `ASD_DEBUG=1` | Enable debug logging |
| `ASD_VERBOSE=1` | Enable verbose output |
| `ASD_BIN_LOCATION` | Binary storage: `global` or `workspace` |

**Tunnel authentication** (what `via auth export --with-key` prints; the CLI
reads each `VIA_X` as `ASD_X`):

| Variable | Description |
|----------|-------------|
| `VIA_TUNNEL_KEY` | Base64-encoded SSH private key (for Docker/CI) |
| `VIA_TUNNEL_KEY_ID` | SSH key UUID (required with `VIA_TUNNEL_KEY`) |
| `VIA_TUNNEL_HOST` | Relay hostname (required with `VIA_TUNNEL_KEY`) |
| `VIA_TUNNEL_PORT` | Relay SSH port (optional, default 2222) |
| `VIA_TUNNEL_HOST_KEY_FINGERPRINTS` | The relay's SSH host key fingerprints, comma or space separated (required with `VIA_TUNNEL_KEY` or `VIA_CLIENT_ID`/`VIA_CLIENT_SECRET`: the CLI never connects unpinned) |

**Service credentials:**

| Service | Variables |
|---------|-----------|
| Basic Auth | `ASD_BASIC_AUTH_USERNAME`, `ASD_BASIC_AUTH_PASSWORD` |
| ttyd | `ASD_TTYD_USERNAME`, `ASD_TTYD_PASSWORD`, `ASD_TTYD_PORT` |
| code-server | `ASD_CODESERVER_AUTH`, `ASD_CODESERVER_PASSWORD`, `ASD_CODESERVER_PORT` |

---

## Command Status

| Status | Meaning |
|--------|---------|
| ✅ | Production - fully tested |
| 🟢 | Stable - works reliably |
| 🟡 | Beta - functional, may have rough edges |
| 🟠 | Alpha - experimental |

| Command | Status |
|---------|--------|
| `via init` | ✅ |
| `via run` | 🟢 |
| `via net` | ✅ |
| `via net apply` | ✅ |
| `via expose` | 🟢 |
| `via login` / `via logout` / `via whoami` | 🟢 |
| `via auth export` | 🟢 |
| `via terminal` | 🟢 |
| `via code` | 🟢 |
| `via database` | 🟢 |
| `via caddy` | ✅ |
| `via config validate` | 🟢 |
| `via relay add/list/info/set/rotate-key/remove` | 🟢 |
| `via skill install/list/status` | 🟢 |
| `via gh` | 🟡 |
| `via inspect` | 🟠 |
| `via deps install/update` | 🟢 |
| `via ac install/remove/status/refresh` | 🟢 |
| `via macro / via macro <name>` | ✅ (new in 2.6) |
| `via schema / via schema automation` | ✅ (new in 2.6) |
| `via rules` | 🟢 (new in 2.6) |
| `via flow` | 🟢 (new in 2.6) |
| `via update` | ✅ (fixed on Windows + Termux in 2.6) |

---

## Knowledge Commands (new in v2.6)

Four introspection commands that surface the embedded source of truth —
use these instead of digging through markdown files when you want
accurate, live-from-code answers.

### `via macro`

List every template macro available inside `${{ ... }}` expressions.

```bash
via macro                     # Grouped list of all 30 macros
via macro <name>              # Detail view with examples and notes
via macro exposedOrigin       # Forgiving lookup — works without prefix
via macro macro.exposedOrigin # Also works (exact id)
via macro --json              # Machine-readable dump for tooling
```

Backed by `modules/core/config/api.schema.ts::TEMPLATE_MACROS`. A CI
drift test (`modules/automation/tests/templating-docs.test.ts`) fails
if a macro is added to the engine without a matching doc entry.

See also: [`docs/TEMPLATE_MACROS.md`](./TEMPLATE_MACROS.md).

### `via schema`

Print the full Zod-derived configuration schema — `asd.yaml`, service
entries, `net.manifest.yaml`, plugin service entries — plus the
template-macro reference.

```bash
via schema                    # Full config schema + macro index
via schema --json             # Machine-readable dump
via schema --ai               # Adds external-tool doc URLs
via schema automation         # Automation YAML schema (all step types)
via schema automation pty     # Filter to a single section
```

Sources: `modules/core/config/asd-config.ts`, `modules/network/scripts/net.schema.ts`, `modules/automation/src/schema.ts`.

### `via rules`

Behavioral rules for AI agents and contributors — routing patterns,
auth flows, naming conventions.

```bash
via rules                     # All rules
via rules <category>          # Filter by category (e.g. routing, auth)
```

### `via flow`

Visualize the template-to-.env data pipeline: which templates are
read, in what order, with which macros expanded at each stage.

```bash
via flow
```

Pairs with `via macro` for understanding how a service's `env:` block
resolves from `tpl.env` → manifest env → asd.yaml service env.

---

## Related Documentation

- [User Manual](./USER_MANUAL.md) - Complete beginner guide
- [Services](./um_service.md) - Service details
- [asd.yaml](./um_asd_yaml.md) - Configuration reference
- [Template Macros](./TEMPLATE_MACROS.md) - All 30 template macros
- [Feature Maturity](./FEATURE_MATURITY.md) - What's production-ready

---

[Back to User Manual](./USER_MANUAL.md)
