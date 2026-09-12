# tsiru-cloud

NixOS configuration for **tsiru-cloud**, a Linode 2 GB VPS.

This is the **`server` branch** of [`jordanaq/.dotfiles`](https://github.com/jordanaq/.dotfiles).
The desktop configuration stays on `main`; this branch deletes the entire
desktop/GUI/GPU stack and keeps only what the server needs.

## Services

| Service | Address | Notes |
|---|---|---|
| **SearXNG** | `https://search.tsiru.pet` | Behind Caddy, HTTP basic auth. Binds `127.0.0.1:8888` — loopback only, no firewall opening. |
| **Caddy** | `:80`, `:443` | Reverse proxy + automatic Let's Encrypt TLS (HTTP-01 on `:80`). |
| **OpenSSH** | `:22` | Key-only, `tsiru` only (`PasswordAuthentication=false`, `PermitRootLogin=no`). |
| **Firewall** | — | Default deny. Open: `22`, `80`, `443`. |

## Installation

Flakes must be enabled on the box:

```nix
nix.settings.experimental-features = [
  "nix-command"
  "flakes"
];
```

Then clone the **`server` branch**:

```bash
git clone -b server git@github.com:jordanaq/.dotfiles.git ~/dotfiles-server
cd ~/dotfiles-server
```

`system/hardware-configuration.nix` is machine-specific — replace it with the
target box's own output:

```bash
sudo nixos-generate-config --show-hardware-config
```

## Files to create

Both live on the server, `chmod 600`, and **must exist before the first
switch** — `EnvironmentFile` is not optional and the services refuse to start
without them.

| File | Variables | Purpose |
|---|---|---|
| `/etc/secrets/searxng.env` | `SEARXNG_SECRET`, `EXA_API_KEY` | SearXNG session secret + Exa search engine key |
| `/etc/secrets/caddy.env` | `CADDY_AUTH_HASH` | bcrypt password hash for the basic-auth user `tsiru` |

```bash
sudo install -m 600 /dev/null /etc/secrets/searxng.env
printf 'SEARXNG_SECRET=%s\n' "$(openssl rand -hex 32)" | sudo tee /etc/secrets/searxng.env
printf 'EXA_API_KEY=%s\n' '<exa-key>'                 | sudo tee -a /etc/secrets/searxng.env

sudo install -m 600 /dev/null /etc/secrets/caddy.env
printf 'CADDY_AUTH_HASH=%s\n' '<bcrypt hash>' | sudo tee /etc/secrets/caddy.env
```

Generate the hash with:

```bash
nix run nixpkgs#caddy -- hash-password --plaintext '<password>'
```

`caddy.nix` references it as `{$CADDY_AUTH_HASH}`, which Caddy substitutes from
its process environment at startup, so the plaintext never enters this repo.
Changing the password later = edit `caddy.env` + `sudo systemctl restart caddy`;
no rebuild.

## DNS

An `A` record `search.tsiru.pet → <LINODE_IP>`, set to **DNS-only / grey cloud**
so Caddy's ACME HTTP-01 challenge reaches the box directly. Check with
`dig +short search.tsiru.pet` before the first rebuild.

## Usage

```bash
sudo nixos-rebuild switch --flake .#tsiru-cloud   # system
home-manager switch --flake .#tsiru               # user (standalone; no nix-shell)
sudo nixos-rebuild switch --rollback              # revert
```

Keep a **LISH console open** during the first switch — it is the recovery path
if SSH or networking breaks.

## Note

Many sources have influenced my choices; each directory that has taken
significant influence from elsewhere will say as much in its own `README.md`.