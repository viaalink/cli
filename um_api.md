# Programmatic Access Reference

**Version:** 2.6.0 | **Last Updated:** 2026-10-22

Programmatic access to Viaalink CLI tunnels (credentials for scripts, containers and CI).

Release-over-release changes are tracked in [../CHANGELOG.md](../CHANGELOG.md).

---

## Authentication Methods

### Method 1: Enrol on a relay

Enrol this device on a relay with the link its operator gives you:

```bash
via relay add '<enrolment link>'
```

After that, all tunnel commands work automatically. (`via login` signs in to
your viaalink.com account; it does not create relay credentials. `via` and
`asd` are the same command; older scripts that call `asd` keep working.)

### Method 2: SSH Key (Docker & Containers)

Use your existing SSH key in Docker containers or new environments.

**Volume mount:**
```bash
docker run -v ~/.config/asd/tunnel:/root/.config/asd/tunnel:ro my-image
```

**Environment variables:**
```bash
# Export credentials from host
eval $(via auth export)

# Pass to Docker
docker run \
  -e ASD_TUNNEL_KEY="$ASD_TUNNEL_KEY" \
  -e ASD_TUNNEL_KEY_ID="$ASD_TUNNEL_KEY_ID" \
  -e ASD_TUNNEL_HOST="$ASD_TUNNEL_HOST" \
  -e ASD_TUNNEL_PORT="$ASD_TUNNEL_PORT" \
  my-image via expose 3000

# Or use the Docker flag format
docker run $(via auth export --docker) my-image via expose 3000
```

**Register a key already authorized on a relay:**
```bash
via relay add <name> --host <host> --key /path/to/private_key
```

---

## Environment Variables

**Credential resolution (priority order — first match wins):**

| Priority | Variables | Description |
|----------|-----------|-------------|
| 1 | `ASD_TUNNEL_KEY` + `ASD_TUNNEL_KEY_ID` | SSH key via env var (Docker, containers) |
| 2 | *Credential registry* | Relays added with `via relay add` |

**Connection (optional, auto-detected):**

| Variable | Description |
|----------|-------------|
| `ASD_TUNNEL_HOST` | Relay hostname |
| `ASD_TUNNEL_PORT` | Relay SSH port (default 2222) |

---

[Back to User Manual](./USER_MANUAL.md)
