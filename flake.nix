{
  description = "Pixel 9 Pro XL KernelSU Next Docker kernel build";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/0";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nickcomua.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nickcomua.cachix.org-1:stcsazuAJ0uhVu6i4yXinhDenHEwKngOtystEXf++so="
    ];
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachSystem ["aarch64-darwin" "x86_64-linux"] (
      system: let
        pkgs = import nixpkgs {inherit system;};

        kernelHostTools = with pkgs; [
          bash
          bc
          bison
          cacert
          coreutils
          cpio
          curl
          file
          findutils
          flex
          gawk
          git
          git-repo
          gnugrep
          gnumake
          gnused
          gnutar
          gzip
          lz4
          openssl
          perl
          python3
          rsync
          unzip
          which
          xz
          zstd
        ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          pkgs.elfutils
        ];

        kernelBuild = pkgs.writeShellApplication {
          name = "pixel-kernel-build";
          runtimeInputs = kernelHostTools;
          text = ''
            exec ${./scripts/nix-build.sh} "$@"
          '';
        };
      in {
        packages.default = kernelBuild;
        packages.kernel-build = kernelBuild;

        apps.default = {
          type = "app";
          program = "${kernelBuild}/bin/pixel-kernel-build";
        };
        apps.kernel-build = self.apps.${system}.default;

        devShells.default = pkgs.mkShell {
          packages = kernelHostTools;
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          shellHook = ''
            echo "Pixel kernel Nix shell"
            echo "Build: nix run .#kernel-build -- work/caimito"
            echo "Existing tree: SKIP_SYNC=1 SKIP_PATCHES=1 nix run .#kernel-build -- /Volumes/dev/caimito"
          '';
        };

        checks.script-syntax = pkgs.runCommand "pixel-kernel-script-syntax" {
          nativeBuildInputs = [pkgs.bash];
        } ''
          bash -n ${./scripts/sync-source.sh}
          bash -n ${./scripts/apply-patches.sh}
          bash -n ${./scripts/build.sh}
          bash -n ${./scripts/nix-build.sh}
          touch "$out"
        '';
      }
    );
}
