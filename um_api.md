# Programmatic Access Reference

**Version:** 2.6.0 | **Last Updated:** 2026-10-22

Programmatic access to Viaalink CLI tunnels (credentials for scripts, containers and CI).

Release-over-release changes are tracked in [../CHANGELOG.md](../CHANGELOG.md).

---

## Authentication Methods

### Method 1: Enrol on a relay

Enrol this device on a relay with the link its operator gives you:

```bash
via relay add '<invite link>'
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
eval $(via auth export --with-key)

# Pass to Docker by name: docker copies each value from this shell, so the
# key is not in the docker command line
docker run \
  -e VIA_TUNNEL_KEY -e VIA_TUNNEL_KEY_ID -e VIA_TUNNEL_HOST -e VIA_TUNNEL_PORT \
  -e VIA_TUNNEL_HOST_KEY_FINGERPRINTS \
  my-image via expose 3000

# Or use the Docker flag format
docker run $(via auth export --docker --with-key) my-image via expose 3000
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
| 1 | `VIA_TUNNEL_KEY` + `VIA_TUNNEL_KEY_ID` (+ `VIA_TUNNEL_HOST_KEY_FINGERPRINTS`) | SSH key via env var (Docker, containers; `via auth export --with-key`, read as `ASD_TUNNEL_*`); the relay's host key pins come with it, and without them the connection is refused |
| 2 | *Credential registry* | Relays added with `via relay add` |

**Connection (optional, auto-detected):**

| Variable | Description |
|----------|-------------|
| `ASD_TUNNEL_HOST` | Relay hostname |
| `ASD_TUNNEL_PORT` | Relay SSH port (default 2222) |

---

[Back to User Manual](./USER_MANUAL.md)
