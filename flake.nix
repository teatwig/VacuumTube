{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self,
    nixpkgs,
    utils,
  }:
    utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
      in rec {
        devShell = pkgs.mkShell rec {
          buildInputs = with pkgs; [
            alsa-lib
            at-spi2-atk
            cairo
            cups
            dbus.lib
            glib
            gtk3
            libGL # runtime only
            libX11
            libXcomposite
            libXdamage
            libXfixes
            libXrandr
            libgbm
            libxcb
            libxkbcommon
            nspr
            nss
            pango
            xorg_sys_opengl
          ];

          shellHook = ''
            export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${builtins.toString (lib.makeLibraryPath buildInputs)}";
          '';
        };

        formatter = pkgs.alejandra;
      }
    );
}
