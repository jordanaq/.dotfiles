# tsiru-cloud

NixOS configuration for **tsiru-cloud**, a Linode 2 GB VPS.

This is the **`server` branch** of [`jordanaq/.dotfiles`](https://github.com/jordanaq/.dotfiles).
The desktop configuration stays on `main`; this branch deletes the entire
desktop/GUI/GPU stack and keeps only what the server needs.

## Services

| Service | Address | Notes |
|---|---|---|
| **SearXNG** | `https://search.tsiru.pet` | Behind Caddy, HTTP basic auth. Binds `127.0.0.1:8888` — loopback only, no firewall opening. |
| **calibre-web** | `https://library.tsiru.pet` | Browser UI for the Calibre library. Behind Caddy; calibre-web's own login is the gate. |
| **calibre-server** | `https://calibre.tsiru.pet` | Calibre content server — remote `calibredb` + OPDS. Behind Caddy; its own auth is the gate. |
| **LinkStack** | `https://links.tsiru.pet` | Link-in-bio page (Linktree alternative). php-fpm pool + SQLite; app lives in `/var/lib/linkstack`. See `system/linkstack.nix`. |
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

An `A` record for each subdomain — `search.tsiru.pet`, `library.tsiru.pet`,
`calibre.tsiru.pet`, `links.tsiru.pet` → `<LINODE_IP>` — set to **DNS-only /
grey cloud** so Caddy's ACME HTTP-01 challenge reaches the box directly. Check
with `dig +short links.tsiru.pet` before the first rebuild.

## LinkStack (links.tsiru.pet)

LinkStack is **not packaged in nixpkgs** — `system/linkstack.nix` fetches the
official release zip, runs it under php-fpm (SQLite), and Caddy fronts it.

Because the app ships in the shared-hosting layout, its docroot is the **app
root**, not a `public/` subdir. That means `.env` / the SQLite DB / the source
would be web-reachable — Apache hides them via `.htaccess`, but **Caddy ignores
`.htaccess`**, so the equivalent denials are re-stated in `system/caddy.nix`.
Keep the two in sync.

- **Data dir:** `/var/lib/linkstack` (owned `linkstack:linkstack`) — the mutable
  install. `linkstack-setup` rsyncs the store copy in on each activation and
  **excludes** `.env`, `storage/`, `bootstrap/cache/`, so upgrades keep state.
- **Upgrading:** bump `version` (and the `hash`) in `system/linkstack.nix`; the
  setup unit re-runs automatically. Compute a new hash with
  `nix store prefetch-file <release-url>`.
- **First run:** visit `https://links.tsiru.pet` — the browser installer runs
  (creates the admin account + SQLite DB). No secret file is needed up front.

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