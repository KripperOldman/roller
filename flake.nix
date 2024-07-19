{
  description = "A basic flake with a shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls-overlay.url = "github:zigtools/zls/0.13.0";
    gitignore.url = "github:hercules-ci/gitignore.nix";
    gitignore.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, flake-utils, zig-overlay, zls-overlay, gitignore, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.13.0";
        zls = zls-overlay.packages.${system}.zls.overrideAttrs (old: {
          nativeBuildInputs = [ zig ];
        });
        gitignoreSource = gitignore.lib.gitignoreSource;
      in
      rec {
        devShells.default = pkgs.mkShell {
          packages = [ zig zls ];
        };
        packages.default = packages.roller;
        packages.roller = pkgs.stdenvNoCC.mkDerivation {
          name = "roller";
          version = "master";
          src = gitignoreSource ./.;
          nativeBuildInputs = [ zig ];
          dontConfigure = true;
          dontInstall = true;
          doCheck = true;
          buildPhase = ''
            mkdir -p .cache
            zig build install \
            --cache-dir $(pwd)/.zig-cache \
            --global-cache-dir $(pwd)/.cache \
            -Dcpu=baseline \
            -Doptimize=ReleaseSafe \
            --prefix $out
          '';
          checkPhase = ''
            zig build test \
            --cache-dir $(pwd)/.zig-cache \
            --global-cache-dir $(pwd)/.cache \
            -Dcpu=baseline
          '';
        };
      });
}
