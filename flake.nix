{
  description = "Minimal PoC isolating torchcodec shared-library/linker health against nixpkgs";

  inputs = {
    # Verified via: nix eval --impure --raw --expr '(import "$NIXPKGS" { system = "x86_64-linux"; config.allowUnfree = true; }).lib.version' -> 26.05pre-git; nix path-info --json "$NIXPKGS" | jq -r '.[0].path' -> /nix/store/1hb1glkkpl6vjjpfrwzmvjyvhcyqfxfk-source
    nixpkgs.url = "github:NixOS/nixpkgs/f83fc3c307e74bc5fd5adb7eb6b8b13ffd2a36e1";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    pythonRuntimeEnv = pkgs.python3.withPackages (ps: [
        # Verified via: nix eval --impure --raw --expr '(import "$NIXPKGS" { system = "x86_64-linux"; config.allowUnfree = true; }).python313Packages.torchcodec.version' -> 0.11.1
        ps.torchcodec
        # Verified via: nix path-info -rS on /nix/store/lxf9hcwwkgf2h0ib5a2yyma1jyjqkp8f-python3.13-torchcodec-0.11.1 -> python3.13-torch-2.11.0
        ps.torch
      ]);
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          pythonRuntimeEnv
          # Verified via: nix eval --impure --raw --expr '(import "$NIXPKGS" { system = "x86_64-linux"; config.allowUnfree = true; }).ffmpeg.version' -> 8.1
          # pkgs.ffmpeg # torchcodec 0.11.1 already pulls ffmpeg-8.1-lib
        ];
      };

      packages.${system}.dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "torchcodec-poc";
        tag = "latest";
        # Verified via: nix eval --impure --raw --expr '(import "$NIXPKGS" { system = "x86_64-linux"; config.allowUnfree = true; }).python313Packages.torchcodec.version' -> 0.11.1; nix path-info -rS on /nix/store/lxf9hcwwkgf2h0ib5a2yyma1jyjqkp8f-python3.13-torchcodec-0.11.1 -> python3.13-torch-2.11.0; nix eval --impure --raw --expr '(import "$NIXPKGS" { system = "x86_64-linux"; config.allowUnfree = true; }).ffmpeg.version' -> 8.1
        contents = [
          pythonRuntimeEnv
        ];
        config = {
          # Set PATH so `python3` resolves by name inside a minimal image that has no default /bin or /usr/bin.
          Env = [
            "PATH=${pkgs.lib.makeBinPath [ pythonRuntimeEnv ]}:/bin"
            "USER=root"
          ];
          Cmd = [ "python3" "-c" "import torchcodec.decoders" ];
        };
      };

      checks.${system} = {
        # Verified via: nix eval --impure --raw --expr '(import "$NIXPKGS" { system = "x86_64-linux"; config.allowUnfree = true; }).python313Packages.torchcodec.version' -> 0.11.1; nix eval --impure --raw --expr '(import "$NIXPKGS" { system = "x86_64-linux"; config.allowUnfree = true; }).ffmpeg.version' -> 8.1
        smoke = pkgs.runCommand "torchcodec-flake-smoke" { } ''
          test -x ${pkgs.ffmpeg}/bin/ffmpeg
          test -d ${pkgs.python313Packages.torchcodec}
          touch $out
        '';
      };
    };
}
