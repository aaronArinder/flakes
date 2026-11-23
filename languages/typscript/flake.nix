{
  description = "typescriptlings — a rustlings-style TypeScript course, offline and zero-install";

  # Pinned to the nixos-26.05 release rather than unstable or master: unstable
  # (26.11+) has dropped x86_64-darwin, which is this machine. 26.05 is the last
  # release that carries it. The pin also makes the toolchain reproducible, which
  # matters here: the runner executes `.ts` files directly via Node's type
  # stripping, and that needs Node >= 22.6.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-darwin" "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      # `@types/node` is not packaged in nixpkgs, and without it `tsc` doesn't
      # know what `console`, `process`, `fetch`, or `node:http` are — every
      # exercise would fail typecheck for reasons that aren't the learner's
      # fault. Pull the tarball straight from the npm registry instead, pinned
      # by its published sha512 (npm's own `integrity` field is already SRI, so
      # it drops into `hash` unchanged) and unpacked into the layout `tsc`
      # looks for.
      packages = forAllSystems ({ pkgs, ... }: rec {
        typesNode =
          let
            # @types/node re-exports undici-types for the fetch globals
            # (Response, Headers, RequestInit). Without it `Response` resolves
            # to an empty interface and every `res.json()` is a type error, so
            # the two have to be unpacked side by side.
            fetchNpm = { name, version, hash }: pkgs.fetchurl {
              url = "https://registry.npmjs.org/${name}/-/${baseNameOf name}-${version}.tgz";
              inherit hash;
            };
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "types-node";
            version = "22.18.12";
            dontUnpack = true;
            dontBuild = true;

            nodeTypes = fetchNpm {
              name = "@types/node";
              version = "22.18.12";
              hash = "sha512-BICHQ67iqxQGFSzfCFTT7MRQ5XcBjG5aeKh5Ok38UBbPe5fxTyE+aHFxwVrGyr8GNlqFMLKD1D3P2K/1ks8tog==";
            };
            undiciTypes = fetchNpm {
              name = "undici-types";
              version = "6.21.0";
              hash = "sha512-iwDZqg0QAGrg9Rav5H4n0M64c3mkR59cJ6wQp+7C4nI0gsmExaedaYLNO44eT4AtBBwjbTiGPMlt2Md0T9H9JQ==";
            };

            # Each npm tarball has a single top-level `package/` directory.
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/node_modules/@types/node" "$out/node_modules/undici-types"
              tar -xzf "$nodeTypes"   -C "$out/node_modules/@types/node"  --strip-components=1
              tar -xzf "$undiciTypes" -C "$out/node_modules/undici-types" --strip-components=1
              runHook postInstall
            '';
          };

        # `nix run` entry point: nix run . -- watch
        default = tsl;
        tsl = pkgs.writeShellApplication {
          name = "tsl";
          runtimeInputs = [ pkgs.nodejs_22 pkgs.typescript ];
          text = ''
            export TSL_TYPES_NODE=${typesNode}/node_modules
            exec node "''${TSL_ROOT:-.}/runner/cli.mjs" "$@"
          '';
        };
      });

      apps = forAllSystems ({ pkgs, system, ... }: {
        default = {
          type = "app";
          program = "${self.packages.${system}.tsl}/bin/tsl";
        };
      });

      devShells = forAllSystems ({ pkgs, system, ... }: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nodejs_22           # >= 22.6 for `node file.ts` type stripping
            pkgs.typescript          # tsc, for the typecheck half of each exercise
            pkgs.typescript-language-server  # editor LSP (nvim/VS Code)
            pkgs.prettier                    # optional formatter
            pkgs.tsx                         # `tsx` REPL / runner for ad-hoc TS experiments
          ];

          # Editors and `tsc` both resolve types through ./node_modules, so link
          # the store copy into place instead of asking for an npm install. The
          # link is rebuilt every time the shell starts, so a nixpkgs bump can't
          # leave a stale dangling symlink behind. node_modules/ is gitignored.
          shellHook = ''
            export TSL_TYPES_NODE=${self.packages.${system}.typesNode}/node_modules
            mkdir -p node_modules/@types
            rm -f node_modules/@types/node node_modules/undici-types
            ln -s "$TSL_TYPES_NODE/@types/node" node_modules/@types/node
            ln -s "$TSL_TYPES_NODE/undici-types" node_modules/undici-types
            export PATH="$PWD:$PATH"
            echo "typescriptlings — node $(node --version), tsc $(tsc --version | cut -d' ' -f2)"
            echo "  ./tsl watch     start where you left off"
            echo "  ./tsl list      see every exercise and its status"
            echo "  ./tsl hint <n>  a hint for one exercise"
          '';
        };
      });
    };
}
