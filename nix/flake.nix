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
        devShells.default = pkgs.mkShell
          {
            packages = [
              pkgs.bazel-buildtools
              pkgs.bazel_6
              pkgs.cargo
              pkgs.rustc
              pkgs.rustfmt
            ];
          };
      });
}
