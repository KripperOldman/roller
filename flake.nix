{
  description = "A basic flake with a shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls-overlay.url = "github:zigtools/zls/0.13.0";
  };

  outputs = { nixpkgs, flake-utils, zig-overlay, zls-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.13.0";
        zls = zls-overlay.packages.${system}.zls.overrideAttrs (old: {
          nativeBuildInputs = [ zig ];
        });
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [ zig zls ];
        };
      });
}
