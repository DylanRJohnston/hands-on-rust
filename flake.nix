# Nix Flake builder for Rust crates.
{
  inputs = {
    # Nix package repository.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Flake utility functions.
    flake-utils.url = "github:numtide/flake-utils";
    # Rust toolchain packages.
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rust crate builder for Nix.
    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, naersk, fenix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Desired Rust channel to use, either: "stable", "beta", or "latest" (nightly).
        rustChannelName = "latest";

        # Use the host's package repository.
        pkgs = nixpkgs.legacyPackages.${system};
        # Read the `Cargo.toml` file and get the crate name and version.
        crateToml = (builtins.fromTOML (builtins.readFile ./Cargo.toml));
        crateName = "Foobar";
        crateVersion = "0.1";
        # Fetch the toolchain.
        rustChannel = fenix.packages.${system}.${rustChannelName};
        rustToolchain = rustChannel.toolchain;
        # Configure `naersk` to use the toolchain.
        naerskBuilder = naersk.lib.${system}.override {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };
      in
      rec {
        # Set the default package and app.
        defaultPackage = packages.${crateName};
        defaultApp = apps.${crateName};

        # `nix build`
        packages.${crateName} = naerskBuilder.buildPackage {
          src = ./.;
          pname = "${crateName}";
          version = "${crateVersion}";
          # Run all tests.
          doCheck = true;
          CARGO_BUILD_RUSTFLAGS = "-D warnings";
        };

        packages.docker = pkgs.dockerTools.buildLayeredImage {
          name = crateName;
          tag = self.rev;
          config.Cmd = [ "${defaultPackage}/bin/${crateName}" ];
          created = "now";
        };

        # `nix run`
        apps.${crateName} = flake-utils.lib.mkApp {
          drv = packages.${crateName};
        };

        # `nix develop`
        devShell = pkgs.mkShell (rec {
          buildInputs = with pkgs; [
            xorg.libX11
            xorg.libX11.dev
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            libGL
            (with fenix.packages.${system}; combine [
              rustToolchain
              (rustChannel.withComponents [ "rust-src" ])
            ])
          ];

          # Let `rust-analyzer` know where to find the Rust source code.
          RUST_SRC_PATH = "${rustChannel.rust-src}/lib/rustlib/src";
          LD_LIBRARY_PATH = "${nixpkgs.lib.makeLibraryPath buildInputs}";
        });
      });
}
