{
  description = "Minimal Node + TypeScript dev shell";

  # nixos-26.05 is the last release that still carries x86_64-darwin.
  # Node >= 22.6 is needed to run `.ts` files directly (type stripping).
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
      # `@types/node` isn't packaged in nixpkgs, and without it `tsc` doesn't
      # know about `console`, `process`, `fetch`, etc. It re-exports
      # undici-types for the fetch globals, so both are unpacked side by side.
      packages = forAllSystems ({ pkgs, ... }: {
        typesNode =
          let
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

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/node_modules/@types/node" "$out/node_modules/undici-types"
              tar -xzf "$nodeTypes"   -C "$out/node_modules/@types/node"  --strip-components=1
              tar -xzf "$undiciTypes" -C "$out/node_modules/undici-types" --strip-components=1
              runHook postInstall
            '';
          };
      });

      devShells = forAllSystems ({ pkgs, system, ... }: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nodejs_22    # `node file.ts` works directly (>= 22.6)
            pkgs.typescript   # tsc
            pkgs.typescript-language-server  # editor LSP (nvim/VS Code)
            pkgs.prettier                    # formatter
            pkgs.tsx                         # `tsx` REPL / runner for ad-hoc TS
          ];

          # Link the store copy of the types into ./node_modules so `tsc` and
          # editors find them without an npm install. Rebuilt on every shell
          # start so a nixpkgs bump can't leave a dangling symlink.
          shellHook = ''
            types=${self.packages.${system}.typesNode}/node_modules
            mkdir -p node_modules/@types
            rm -f node_modules/@types/node node_modules/undici-types
            ln -s "$types/@types/node" node_modules/@types/node
            ln -s "$types/undici-types" node_modules/undici-types
          '';
        };
      });
    };
}
