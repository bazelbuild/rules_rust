{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.cargo-bazel = pkgs.rustPlatform.buildRustPackage {
          pname = "cargo-bazel";
          version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;

          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          # Tests cannot be run via Cargo due to the dependency on the
          # Bazel `runfiles` crate.
          doCheck = false;
        };
      });
}
