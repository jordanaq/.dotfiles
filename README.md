# NixOS Configuration

## Installation

Make sure flakes are enabled on your system. If not, add the following to your system's `configuration.nix`.

```nix
nix.settings.experimental-features = [
  "nix-command"
  "flakes"
];
```

Clone the repository and its submodules into your home directory.

```bash
git clone --recurse-submodules git@github.com:jordanaq/.dotfiles.git ~/.dotfiles
```

For an existing checkout, initialize the submodules after pulling:

```bash
git submodule update --init --recursive
```

## Usage

### To update system-wide

With elevated permissions,

```bash
nixos-rebuild switch --upgrade --flake ~/.dotfiles#tsiru-nixos
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
