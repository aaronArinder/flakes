{
  description = "Android emulator (Google Play image) to act as WhatsApp's primary device";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-darwin" "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f s);
    in {
      devShells = forAll (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            config.android_sdk.accept_license = true;
          };
          # Apple Silicon needs arm64 images; Intel Macs / x86 Linux need x86_64.
          abi = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64-v8a" else "x86_64";
          apiLevel = "34";
          sdk = (pkgs.androidenv.composeAndroidPackages {
            platformVersions = [ apiLevel ];
            includeEmulator = true;
            includeSystemImages = true;
            systemImageTypes = [ "google_apis_playstore" ];
            abiVersions = [ abi ];
          }).androidsdk;
          sdkRoot = "${sdk}/libexec/android-sdk";
          image = "system-images;android-${apiLevel};google_apis_playstore;${abi}";

          # Creates the AVD on first run, then boots it. State lives in ./.android
          # so the WhatsApp registration persists across runs (and is easy to back up).
          wa-emulator = pkgs.writeShellScriptBin "wa-emulator" ''
            set -euo pipefail
            root="''${WA_STATE_DIR:-$PWD/.android}"
            export ANDROID_USER_HOME="$root"
            export ANDROID_AVD_HOME="$root/avd"
            mkdir -p "$ANDROID_AVD_HOME"
            if [ ! -d "$ANDROID_AVD_HOME/whatsapp.avd" ]; then
              echo "Creating AVD 'whatsapp' (${image})..."
              echo no | avdmanager create avd -n whatsapp -k "${image}" -d pixel_6
            fi
            exec emulator -avd whatsapp -netdelay none -netspeed full "$@"
          '';
        in {
          default = pkgs.mkShell {
            packages = [ sdk wa-emulator ];
            ANDROID_SDK_ROOT = sdkRoot;
            ANDROID_HOME = sdkRoot;
            shellHook = ''
              echo "Run 'wa-emulator' to create/boot the WhatsApp AVD (state in ./.android)."
            '';
          };
        });
    };
}
