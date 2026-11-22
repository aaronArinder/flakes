# flakes

A collection of Nix flakes. Each flake lives in its own directory and can be run straight from GitHub, or from a local clone.

## Flakes

| Directory | What it does |
|-----------|--------------|
| [`whatsapp/`](whatsapp/) | Android emulator (Google Play image) that acts as WhatsApp's primary device, so you can use web.whatsapp.com without a smartphone |

## Running a flake

Requires [Nix](https://nixos.org/download) with flakes enabled.

### whatsapp

From GitHub, no clone needed (the `github:aaronArinder/flakes?dir=whatsapp` shorthand also works):

```sh
nix develop "git+https://github.com/aaronArinder/flakes?dir=whatsapp" -c wa-emulator
```

Or from a local clone:

```sh
cd whatsapp
nix develop        # enter the dev shell
wa-emulator        # create/boot the emulator
```

Emulator state, including your WhatsApp registration, is written to `.android/` in the directory you run it from, so run it from the same place every time or set `WA_STATE_DIR` to your existing state directory. See [`whatsapp/README.md`](whatsapp/README.md) for the full setup.
