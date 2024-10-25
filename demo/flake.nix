{
  # Nix: https://nixos.org/download.html
  # How to activate flakes: https://nixos.wiki/wiki/Flakes
  # For seamless integration, consider using:
  # - direnv: https://github.com/direnv/direnv
  # - nix-direnv: https://github.com/nix-community/nix-direnv
  #
  # # .envrc
  # use flake
  # dotenv .env
  #
  description = "Grafbase CLI development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    flake-utils,
    ...
  }: let
    inherit (nixpkgs.lib) optional concatStringsSep;
    systems = flake-utils.lib.system;
    flake = flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      defaultShellConf = {
        nativeBuildInputs = with pkgs;
          [
            # Testing
            cargo-insta
            cargo-nextest
            cargo-component
            # Benchmark tool to send multiple requests
            hey

            # binary bloat inspector
            cargo-bloat

            # Versioning, automation and releasing
            cargo-make
            cargo-release
            nodePackages.npm
            nodePackages.semver
            sd
            go
            nix-ld

            # workspace-hack
            cargo-hakari

            # Node.js
            nodejs_22
            nodePackages.prettier

            # Native SSL
            openssl
            pkg-config
            cmake # for libz-ng-sys

            # Rust
            rustup

            # SQLx macros
            libiconv

            # Resolver tests
            pnpm # and cli-app
          ]
          ++ optional (system == systems.aarch64-darwin) [
            cargo-binstall
            darwin.apple_sdk.frameworks.CoreFoundation
            darwin.apple_sdk.frameworks.CoreServices
            darwin.apple_sdk.frameworks.Security
            darwin.apple_sdk.frameworks.SystemConfiguration
          ]
          ++ optional (system != systems.aarch64-darwin) [
            gdb
            cargo-about # broken build at the moment on darwin
          ];

        shellHook = ''
          project_root="$(git rev-parse --show-toplevel 2>/dev/null || jj workspace root 2>/dev/null)"
          export CARGO_INSTALL_ROOT="$project_root/cli/.cargo";
          export PATH="$CARGO_INSTALL_ROOT/bin:$project_root/node_modules/.bin:$PATH";
        '';
      };
    in {
      devShells.default = pkgs.mkShell defaultShellConf;
    });
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      inherit flake;

      systems = flake-utils.lib.defaultSystems;

      perSystem = {
        config,
        system,
        ...
      }: {
        _module.args = {
          pkgs = import nixpkgs {
            inherit system;
          };
        };
      };
    };
}