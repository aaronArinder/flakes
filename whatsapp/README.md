# whatsapp

Use WhatsApp in a desktop browser (web.whatsapp.com) **without owning a smartphone**.

WhatsApp needs a "primary device" with the app installed before a browser can be linked to it. This repo uses a Nix flake to run an Android emulator on your computer as that primary device. You register your number on the emulator, link web.whatsapp.com to it, and from then on use WhatsApp in the browser.

A feature phone (dumbphone) is enough for registration: WhatsApp can verify by SMS or by a voice call ("call me").

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
- A Mac or Linux machine. Intel/x86_64 gives hardware-accelerated emulation. Apple Silicon uses the arm64 image.
- About 10 GB of free disk space for the SDK, system image and AVD

nixpkgs is pinned to `nixpkgs-26.05-darwin`, the last release that supports Intel Macs.

## Setup

```sh
nix develop          # enter the shell (first run downloads a few GB)
wa-emulator          # creates the "whatsapp" AVD on first run, then boots it
```

Or, without cloning, from the root of the flakes repo:

```sh
nix develop "git+https://github.com/aaronArinder/flakes?dir=whatsapp" -c wa-emulator
```

`wa-emulator` passes extra arguments through to `emulator`, for example `wa-emulator -no-snapshot` for a cold boot. A cold boot takes about 100 seconds.

### Install WhatsApp in the emulator

Either:

- Sign in to the Play Store in the emulator and install WhatsApp, or
- Sideload the official APK, which needs no Google account:
  ```sh
  curl -L -o WhatsApp.apk https://www.whatsapp.com/android/current/WhatsApp.apk
  adb install WhatsApp.apk
  ```
  Download it somewhere outside this repo. APKs are not committed.

### Register and link the browser

1. In the emulator, open WhatsApp, accept the terms, and enter your number. Use "call me" if the SMS code is slow.
2. At https://web.whatsapp.com choose **Log in with phone number**. It shows an 8-character code.
3. In the emulator open ⋮ → **Linked devices** → **Link a device** → **Link with phone number instead**, and enter that code.

After this the browser works on its own. The emulator doesn't need to be running while you chat.

## Keeping the link alive

WhatsApp unlinks companion devices if the primary device hasn't been online for about 14 days. Boot the emulator (`wa-emulator`) at least every two weeks and leave it up for a minute or two.

## Where state lives

All emulator state, including your WhatsApp registration, is in `./.android/` of the directory you run `wa-emulator` from (override with `WA_STATE_DIR`). It is gitignored and **must never be committed**: it contains your registration and an adb private key. Back it up privately and don't delete it, or you will have to register again.

## adb notes

- The emulator's adb daemon only trusts a key the emulator knows about, so `adb devices` may show `unauthorized` at first. Accept the "Allow USB debugging?" dialog in the emulator window if it appears.
- Run adb with `ANDROID_USER_HOME` set to the same `.android` directory as the emulator, so both use the same key.

## Risks and caveats

- **State follows your working directory.** `wa-emulator` keeps its state in `./.android/` of the directory you run it from. Running it from somewhere new (including via the GitHub URL) creates a fresh AVD with no registration, so you would have to register again. Always run it from the same directory, or set `WA_STATE_DIR` to the absolute path of your existing state directory:
  ```sh
  WA_STATE_DIR=$HOME/path/to/.android nix develop "git+https://github.com/aaronArinder/flakes?dir=whatsapp" -c wa-emulator
  ```
- WhatsApp may flag or refuse registrations from emulators. If that happens, the fallback is a cheap used Android phone used only for registration and the 14-day check-in.
- Registering a number moves any existing WhatsApp account on that number to the emulator and logs it out elsewhere. Chat history does not transfer unless you restore a backup.
- Running WhatsApp on an emulator is not an officially supported setup. Check WhatsApp's Terms of Service and use it at your own risk.
