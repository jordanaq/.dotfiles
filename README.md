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
| **Personal site** | `https://tsiru.pet` | Public bio + projects page (Zola). Built from the [`jordanaq/tsiru-pet`](https://github.com/jordanaq/tsiru-pet) flake input and served from the store path. No auth. |
| **Notes site** | `https://notes.tsiru.pet` | Public Quartz export of the vault's `Concepts/` folder, built **and** published on this box by `notes-publish.service`. Static files only. See `system/notes-site.nix`. |
| **Stalwart** | `mail.tsiru.pet` (SMTP `25`/`465`/`587`, IMAPS `993`, JMAP/CalDAV/CardDAV over Caddy on `443`) | All-in-one mail + collaboration server, 0.16.21 (prebuilt release overlay — nixpkgs still pins 0.15.5). Outbound relayed via SMTP2GO; TLS via `security.acme` DNS-01. See `system/stalwart.nix`. |
| **Bulwark** | `https://webmail.tsiru.pet` | Self-hosted JMAP webmail client for Stalwart (prebuilt Node bundle — no PHP/DB; accounts live in Stalwart). See `system/bulwark.nix`. |
| **Vaultwarden** | `https://vault.tsiru.pet` | Bitwarden-compatible password manager (SQLite). Registration closed; `/admin` is tailnet-only. See `system/vaultwarden.nix`. |
| **Uptime Kuma** | tailnet only (`:8443`) | Status/heartbeat monitor. Loopback-only, reached via `tailscale serve` — deliberately **not** in Caddy. See `system/uptime-kuma.nix`. |
| **Tailscale** | — | Private mesh access to the box (no extra public ports). Purely additive. See `system/tailscale.nix`. |
| **fail2ban** | — | Bans IPs tripping repeated `401`/`403`, or a 4xx on an auth endpoint, across **all** Caddy vhosts (`/var/log/caddy/*.log`; file backend). See `system/fail2ban.nix`. |
| **Caddy** | `:80`, `:443` | Reverse proxy + automatic Let's Encrypt TLS (HTTP-01 on `:80`; the `mail.` cert comes from `security.acme` DNS-01, see below). |
| **OpenSSH** | `:22` | Key-only, `tsiru` only (`PasswordAuthentication=false`, `PermitRootLogin=no`). |
| **Firewall** | — | Default deny. Open TCP: `22`, `80`, `443`, `25`, `465`, `587`, `993`; UDP: `41641` (WireGuard/Tailscale). ManageSieve `4190` is deliberately **not** opened — Linode filters it upstream, so it can never be reached from the internet (pentest F-11). |

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

All live on the server and **must exist before the first switch** —
`EnvironmentFile` is not optional and the services refuse to start without
them. Their owner/mode is **not** a hand-step: `systemd.tmpfiles.rules` in
`system/configuration.nix` re-apply it on every boot (`z`), so a drifted
permission self-heals. Most are `0600 root:root`; the ones Stalwart reads
itself at runtime are `0640 root:stalwart` (called out per row below).

| File | Variables | Purpose |
|---|---|---|
| `/etc/secrets/searxng.env` | `SEARXNG_SECRET`, `EXA_API_KEY` | SearXNG session secret + Exa search engine key |
| `/etc/secrets/caddy.env` | `CADDY_AUTH_HASH` | bcrypt password hash for the basic-auth user `tsiru` |
| `/etc/secrets/spaceship.env` | `SPACESHIP_API_KEY`, `SPACESHIP_API_SECRET` | Spaceship API credentials — let `security.acme` (lego) solve the `mail.` DNS-01 challenge |
| `/etc/secrets/smtp2go.smtp-password` | SMTP2GO API key | **Active** outbound relay — read by the `stalwart` user at runtime (`0640 root:stalwart`) |
| `/etc/secrets/scaleway.smtp-password` | Scaleway API secret key | Dormant fallback route (Scaleway TEM) — not used while SMTP2GO is active |
| `/etc/secrets/stalwart-admin-password` | plaintext admin password | Stalwart's fallback administrator (`admin`), read by the `stalwart` user (`0640 root:stalwart`) |
| `/etc/secrets/bulwark.env` | `SESSION_SECRET` | Bulwark session encryption (64+ random chars) |
| `/etc/secrets/vaultwarden.env` | `ADMIN_TOKEN`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Vaultwarden admin token + outbound mail via Stalwart |

```bash
sudo install -m 600 /dev/null /etc/secrets/searxng.env
printf 'SEARXNG_SECRET=%s\n' "$(openssl rand -hex 32)" | sudo tee /etc/secrets/searxng.env
printf 'EXA_API_KEY=%s\n' '<exa-key>'                 | sudo tee -a /etc/secrets/searxng.env

sudo install -m 600 /dev/null /etc/secrets/caddy.env
printf 'CADDY_AUTH_HASH=%s\n' '<bcrypt hash>' | sudo tee /etc/secrets/caddy.env

sudo install -m 600 /dev/null /etc/secrets/bulwark.env
printf 'SESSION_SECRET=%s\n' "$(openssl rand -hex 48)" | sudo tee /etc/secrets/bulwark.env

sudo install -m 600 /dev/null /etc/secrets/vaultwarden.env
printf 'ADMIN_TOKEN=%s\n' "$(openssl rand -base64 48)" | sudo tee /etc/secrets/vaultwarden.env
printf 'SMTP_USERNAME=vault@tsiru.pet\nSMTP_PASSWORD=<that mailbox password>\n' | sudo tee -a /etc/secrets/vaultwarden.env
```

`/etc/secrets/scaleway.smtp-user` is **read by nothing** — 0.16 removed the
`%{file:…}%` macros, so the Scaleway username is a plain string set **once** in
the Stalwart WebUI (Settings › MTA › Outbound › Routes › `scaleway` → Username);
provisioning's upsert preserves it. Both that route and `mx` are **dormant** now
(SMTP2GO is the active relay, see the Stalwart notes below).

Generate the Caddy hash with:

```bash
nix run nixpkgs#caddy -- hash-password --plaintext '<password>'
```

`caddy.nix` references it as `{$CADDY_AUTH_HASH}`, which Caddy substitutes from
its process environment at startup, so the plaintext never enters this repo.
Changing the password later = edit `caddy.env` + `sudo systemctl restart caddy`;
no rebuild.

> **systemd reads `EnvironmentFile` only at service start.** After editing any
> file above, `sudo systemctl restart <service>` — otherwise the change is
> silently ignored. This trips people up most often on `vaultwarden.env`.

## DNS

An `A` record for each public name — the apex `tsiru.pet` plus `search.`,
`library.`, `calibre.`, `links.`, `notes.`, `mail.`, `webmail.`, `vault.`
→ `<LINODE_IP>`.

Spaceship is the DNS authority. Two certificate paths are in play:

- **Caddy's own ACME (HTTP-01 on `:80`)** covers every name *except* `mail.` —
  those records must be **DNS-only / grey cloud** so the challenge reaches the
  box directly. Check with `dig +short tsiru.pet` before the first rebuild.
- **`mail.<domain>` uses `security.acme` with the Spaceship DNS-01 provider**
  (lego), producing one certificate shared by Stalwart and the Caddy JMAP vhost.
  No `:80`/`:443` challenge traffic, so the record's proxy state doesn't matter.

**Mail DNS records:** `MX` → `mail.tsiru.pet`, plus `SPF`/`DMARC`, are published
**by hand** — `dnsManagement` is kept for DKIM + TLSA only. DKIM is
Stalwart's own (`dkimManagement = Automatic`, RSA-only — Ed25519 is deliberately
off, since Proton and Gmail log a permerror for it): copy the record Stalwart
reports under *Settings › Domains › DKIM Signatures* into Spaceship.

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
  **excludes** every path the app rewrites at runtime — `.env`, `INSTALLING`,
  `storage/`, `bootstrap/cache/`, `config/advanced-config.php` — so a redeploy
  never clobbers live state.
- **Seeding.** Two excluded paths still need a first-run seed from the release,
  and the unit does that without ever overwriting anything the app has since
  written:
  - `storage/` — excluded as runtime state, but the release ships a few
    non-mutable files inside it. `storage/app/ISINSTALLED` gates the
    post-install self-heal at the top of `routes/web.php`, and **nothing in
    LinkStack ever writes it**; `storage/templates/advanced-config.php` is the
    source that self-heal copies. Drop them and the self-heal never fires, so
    `config/advanced-config.php` is never created and the admin config editor
    500s on `file_get_contents('config/advanced-config.php')` — *before* you can
    reach the "Restore defaults" button that would have created the file. The
    unit re-seeds this skeleton with `--ignore-existing` (create if absent,
    never overwrite).
  - `INSTALLING` — seeded inside the same first-run guard as `.env`, because the
    app *deletes* it once setup completes. Re-shipping it on every rebuild would
    put a live install back into installer mode, where the installer's
    catch-all exposes `GET /skip` (re-seeds `AdminSeeder`, logs you in as
    `admin`). To deliberately re-run the installer, delete `.env`.
- **Advanced config.** `config/advanced-config.php` is **app-owned** — LinkStack
  creates it and the admin panel edits it. It is *not* managed by Nix; edit it at
  `https://links.tsiru.pet/admin/config`, not in this repo.
- **Upgrading:** bump `version` (and the `hash`) in `system/linkstack.nix`; the
  setup unit re-runs automatically. Compute a new hash with
  `nix store prefetch-file <release-url>`.
- **First run:** `linkstack-setup` seeds `.env` and generates the Laravel
  `APP_KEY` (required — the app 500s without it). Then visit
  `https://links.tsiru.pet` — the browser installer creates the admin account
  and SQLite DB. No secret file is needed up front.

## Personal site (tsiru.pet)

The public bio + projects page. Source and build live in a separate repo,
[`jordanaq/tsiru-pet`](https://github.com/jordanaq/tsiru-pet); this config
consumes it as the `tsiru-pet` flake input and Caddy serves the built store
path at the apex domain. Nothing runs on the box for it.

- **Editing the page:** change content in the site repo and push — the box
  picks it up on the next `nix flake update tsiru-pet` + rebuild.
- **GitHub-derived files:** the "From GitHub" project list and the profile
  picture are generated ahead of time by `scripts/fetch-github-projects.sh` in
  that repo (Nix builds have no network, so both are committed, not fetched at
  build time).

## Notes site (notes.tsiru.pet)

A Quartz v5 export of the vault's `Concepts/` folder, built and published
**on the box** (`system/notes-site.nix`). The vault lives on the desktop, but
its bare git remote lives here (`~/Documents/Obsidian-Vault.git`), so the
publisher clones from a local path and needs no credentials.

- **Trigger:** `notes-publish.service` is a long-running daemon (`Restart=always`,
  active from power-on) that republishes every `INTERVAL` seconds (default
  `300`). It exits early unless the vault's `HEAD` moved, so an idle box costs
  one `git fetch` per tick. Publishing follows the vault's **push**, not the
  desktop's edits.
- **Scratch + docroot:** `/var/lib/notes-build` and `/var/lib/notes-site`, both
  owned by `tsiru` (not root) so the publisher shares the vault repo's user and
  avoids git's "dubious ownership" refusal.
- **Quartz** is pinned by `flake.lock` (not `?ref=main`), so a rebuild is
  reproducible and an upstream release can never silently change the site. The
  site's config is `system/notes-site-quartz.config.yaml`; a synthetic root
  index (`system/notes-site-index.md`) is injected into the build clone because
  `Concepts/` has no `index.md` and `/` would otherwise 404.

## Mail (mail.tsiru.pet)

**Stalwart** is the mail server; **Bulwark** at `webmail.tsiru.pet` is the web
client. Accounts, lists, and filters to existing addresses are administered in
the WebUI at `https://mail.tsiru.pet/admin` (Stalwart's own login — there is
deliberately **no** `admin.` vhost; a separate one became bypassable and broke
the panel).

- **Version 0.16.21**, prebuilt from the upstream GitHub release via
  `system/stalwart-overlay.nix` (nixpkgs still pins 0.15.5). The 0.16 module +
  provisioning are vendored from open nixpkgs PR #552103. Drop both once nixpkgs
  ships Stalwart ≥ 0.16.
- **Config model.** 0.16 keeps only a tiny datastore descriptor on disk
  (`@type = RocksDb`, `/var/lib/stalwart/db`); listeners, routing, domains, and
  accounts live *in the datastore as JMAP objects*, provisioned idempotently at
  boot by `stalwart-cli apply` (`system/stalwart-module/provision.nix`). That
  provisioning covers SMTP `25`/`465`/`587`, IMAPS `993`, the loopback HTTP
  listener (`127.0.0.1:8080`, fronted by Caddy), and the outbound routes.
  There is deliberately **no** ManageSieve listener — see below.
  - **No ManageSieve (`4190`).** Pentest F-11 removed both the listener and its
    firewall opening. Linode filters the port upstream, so no internet client
    could ever reach it, and nothing here speaks ManageSieve: Bulwark and the
    WebUI both manage Sieve over JMAP. Re-adding the listener would be
    tailnet-only until Linode stops filtering the port.
  - **Outbound = SMTP2GO relay.** Mail goes to `mail.smtp2go.com:465` (implicit
    TLS, authenticated) rather than direct-to-MX. SMTP2GO is MIME-agnostic — so
    end-to-end encrypted (PGP/MIME) mail passes, which is what forced the move
    off Scaleway TEM — and delivery is reliable from a young domain. Direct-to-MX
    (`mx`, IPv4-only) and Scaleway TEM remain as **dormant** fallback routes.
    Outbound port `25` is open from this box (verified 2026-09-13), so direct
    delivery stays viable if the relay is ever dropped.
- **Bulwark** is a prebuilt standalone Node bundle (no build step, no DB)
  unpacked to `/var/lib/bulwark/app`; mutable state lives outside the app tree in
  `admin/` + `state/`, so a version bump replaces the code cleanly. It talks JMAP
  to `https://mail.tsiru.pet`. First login uses the mail account
  (`tsiru@tsiru.pet`) — Bulwark has no separate user database.

## Vaultwarden (vault.tsiru.pet)

A Bitwarden-compatible password manager, built on NixOS's first-class
`services.vaultwarden` module — no Docker, no bespoke packaging. SQLite backend.

- **Registration is closed.** `SIGNUPS_ALLOWED` **and** `INVITATIONS_ALLOWED`
  are off, as are password hints, Sends, and emergency access. Re-open
  invitations temporarily if a second user is ever needed.
- **`/admin` is tailnet-only** — the public vhost returns `403` for it (see
  `caddy.nix`). Reach it over the tailnet instead.
- **Re-skinned to Catppuccin Macchiato** (pink accent) — see
  `system/vaultwarden-catppuccin-macchiato.scss` and the tmpfiles rules that
  symlink it into place.
- **Email** goes out through Stalwart on `:587` (STARTTLS) as an authenticated
  `vault@` account — an unauthenticated loopback submission has no aligned
  SPF/DKIM and was filed into Junk.
- **⚠️ No backups yet.** The module's nightly dump is deliberately commented out
  in `system/vaultwarden.nix` (`backupDir`); a Discord reminder job tracks it.
  Uncomment `backupDir` to enable the built-in `23:00` backup timer.

## Tailnet & private admin

**Tailscale** provides private mesh access with no extra public ports (direct
WireGuard on UDP `41641`, relayed via DERP otherwise). Nothing here depends on
it — it is purely additive.

Two admin surfaces are exposed **only** over the tailnet, via `tailscale serve`:

```bash
sudo tailscale serve --bg --https=8443  http://127.0.0.1:3001   # Uptime Kuma
sudo tailscale serve --bg --https=10000 http://127.0.0.1:8222   # Vaultwarden /admin
```

> ⚠️ **Never use `--https=443`.** Tailscale then binds the tailnet address on
> `:443`, which collides with Caddy's wildcard `:443` bind — Caddy dies with
> `address already in use` and *every* public site goes down. Use `8443`
> (Uptime Kuma) or `10000` (Vaultwarden).

Uptime Kuma (`https://<box>.<tailnet>.ts.net:8443`) is first-run-setup, then
loopback-only; the old public `status.` vhost was removed in favour of
tailnet-only access (the stale `status.tsiru.pet` DNS record is still pending
deletion in Spaceship — pentest F-12). An SSH tunnel
(`ssh -L 3001:127.0.0.1:3001 tsiru.pet`) also works.

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
