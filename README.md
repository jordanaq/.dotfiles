# NixOS WSL Configuration

## Installation

Install the NixOS WSL container. See the [wiki](https://wiki.nixos.org/wiki/WSL) for directions.

Make sure flakes are enabled on your system. If not, add the following to your system's `configuration.nix`.

```nix
nix.settings.experimental-features = [
  "nix-command"
  "flakes"
];
```

Then, simply clone this repo into your home directory.

```bash
git clone --recurse-submodules -b wsl git@github.com:jordanaq/.dotfiles.git ~/.dotfiles
```

For an existing checkout, run `git submodule update --init --recursive`
after pulling.

## Usage

### To update system-wide

With elevated permissions,

```bash
nixos-rebuild switch --upgrade --flake "$HOME/.dotfiles?submodules=1#tsiru-nixos"
```

### To update via home-manager

Ensure that [`home-manager`](https://github.com/nix-community/home-manager) is available in your shell.

```bash
nix-shell -p home-manager
```

Then,

```bash
home-manager switch --flake ~/.dotfiles?submodules=1 -b backup
```

## Note

Many sources have influenced my choices, each directory that has taken significant influence from elsewhere will say as much in their `README.md`.
