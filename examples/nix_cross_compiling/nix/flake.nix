{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, fenix, android-nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };

      llvm = pkgs.llvmPackages_16;

      rust = with fenix.packages."x86_64-linux"; combine [
        complete.cargo
        complete.clippy
        complete.rustc
        complete.rustfmt
        complete.rust-src
        complete.rust-analyzer
        targets."aarch64-apple-darwin".latest.rust-std
        targets."aarch64-apple-ios".latest.rust-std
        targets."aarch64-linux-android".latest.rust-std
        targets."aarch64-unknown-linux-gnu".latest.rust-std
        targets."wasm32-unknown-unknown".latest.rust-std
        targets."wasm32-wasi".latest.rust-std
        targets."x86_64-apple-darwin".latest.rust-std
        targets."x86_64-pc-windows-msvc".latest.rust-std
        targets."x86_64-unknown-linux-gnu".latest.rust-std
      ];

      fetchVendor = { name, url, sha256, stripComponents ? 0 }:
        let
          authorization =
            if (pkgs.lib.hasPrefix "https://raw.githubusercontent.com/<repo>/" url) then
              ''-H "Authorization: Bearer <token>"''
            else
              "";
        in
        pkgs.runCommandLocal "vendor-${name}"
          {
            buildInputs = [ pkgs.cacert ];
            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = sha256;
          } ''
          # Empty URL special cased for example
          mkdir --parents $out
          if [ -n "${url}" ]; then
            ${pkgs.curl}/bin/curl -s -S -L ${authorization} "${url}" | ${pkgs.libarchive}/bin/bsdtar -C $out -xf - --strip-components ${toString stripComponents}
          fi
        '';

      libclang_rt_wasm32 = fetchVendor {
        name = "libclang_rt_wasm32";
        url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz";
        sha256 = "AdRe1XrGeBuai1p5IMUTR7T7nhNlD1RZ8grZjVoHAKs=";
      };

      sdk_aarch64-unknown-linux-gnu = fetchVendor {
        name = "sdk_aarch64-unknown-linux-gnu";
        url = "https://commondatastorage.googleapis.com/chrome-linux-sysroot/toolchain/80fc74e431f37f590d0c85f16a9d8709088929e8/debian_bullseye_arm64_sysroot.tar.xz";
        sha256 = "VwHx6SjTmnGWvEoevjThR2oxNEe9NIdnSIJ9RBgKPE8=";
      };

      sdk_universal-apple-darwin = fetchVendor {
        name = "sdk_universal-apple-darwin";
        url = ""; # User needs to supply.
        sha256 = "pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo="; # User needs to supply.
      };

      sdk_universal-apple-ios = fetchVendor {
        name = "sdk_universal-apple-ios";
        url = ""; # User needs to supply.
        sha256 = "pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo="; # User needs to supply.
      };

      sdk_universal-linux-android = android-nixpkgs.sdk."x86_64-linux" (sdkPkgs: with sdkPkgs; [
        cmdline-tools-latest
        build-tools-33-0-2
        platform-tools
        platforms-android-33
        ndk-25-2-9519653
      ]);

      sdk_wasm32-wasi = fetchVendor {
        name = "sdk_wasm32-wasi";
        url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sysroot-20.0.tar.gz";
        sha256 = "aePDwDYWopPPDSO802BO3YWM4d/J4a4CmGP/hDPF8FY=";
      };

      sdk_x86_64-pc-windows-msvc = fetchVendor {
        name = "sdk_x86_64-pc-windows-msvc";
        url = ""; # User needs to supply.
        sha256 = "pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo="; # User needs to supply.
      };

      sdk_x86_64-unknown-linux-gnu = fetchVendor {
        name = "sdk_x86_64-unknown-linux-gnu";
        url = "https://commondatastorage.googleapis.com/chrome-linux-sysroot/toolchain/f5f68713249b52b35db9e08f67184cac392369ab/debian_bullseye_amd64_sysroot.tar.xz";
        sha256 = "+pqXDAsKY1BCBGFD3PDqMv1YiU+0/B2LXXryTFIUaWk=";
      };

      sdk_x86_64-unknown-nixos-gnu = pkgs.symlinkJoin {
        name = "sdk_x86_64-unknown-nixos-gnu";
        paths = [
          llvm.libcxx.out
          llvm.libcxx.dev
          llvm.libcxxabi.out
          llvm.libunwind.out
          pkgs.gcc13.cc.libgcc.out
          pkgs.gcc13.cc.libgcc.libgcc
          pkgs.glibc.dev
          pkgs.glibc.libgcc.out
          pkgs.glibc.out
        ];
      };
    in
    {
      packages."x86_64-linux".bazel = {
        config = pkgs.writeTextFile {
          name = "bazel-config";
          destination = "/config.bzl";
          text = ''
            LLVM = "${llvm.bintools-unwrapped}"
            CLANG = "${llvm.clang-unwrapped}"
            CLANG_LIB = "${llvm.clang-unwrapped.lib}"
            CLANG_LIB_VERSION = "16"

            NIXOS_DYNAMIC_LINKER = "${pkgs.glibc.out}/lib64/ld-linux-x86-64.so.2"
            LIBCLANG_RT_WASM32 = "${libclang_rt_wasm32}"
            ANDROID_NDK_VERSION = "25.2.9519653"

            SDK_AARCH64_UNKNOWN_LINUX_GNU = "${sdk_aarch64-unknown-linux-gnu}"
            SDK_UNIVERSAL_APPLE_DARWIN = "${sdk_universal-apple-darwin}"
            SDK_UNIVERSAL_APPLE_IOS = "${sdk_universal-apple-ios}"
            SDK_UNIVERSAL_LINUX_ANDROID = "${sdk_universal-linux-android}"
            SDK_WASM32_WASI = "${sdk_wasm32-wasi}"
            SDK_X86_64_PC_WINDOWS_MSVC = "${sdk_x86_64-pc-windows-msvc}"
            SDK_X86_64_UNKNOWN_LINUX_GNU = "${sdk_x86_64-unknown-linux-gnu}"
            SDK_X86_64_UNKNOWN_NIXOS_GNU = "${sdk_x86_64-unknown-nixos-gnu}"
          '';
        };

        rust = rust;
      };
    };
}
