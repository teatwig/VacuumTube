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

        packages.vacuumtube = let
          inherit (pkgs) buildNpmPackage electron;
        in
          buildNpmPackage rec {
            pname = "vacuumtube";
            version = "unstable";

            src = ./.;

            npmDepsHash = "sha256-V6AzuvZTZx7otwvR3CbOnLTOo6+P1s+qpaOaOSrrG/c=";
            # npmFlags = ["--legacy-peer-deps"];
            # makeCacheWritable = true;

            env = {
              ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
              CHROMEDRIVER_SKIP_DOWNLOAD = "true";
              CSC_IDENTITY_AUTO_DISCOVERY = "false";
            };

            # package.json does not include `core-js` and the comment suggests
            # it is only needed on some mobile platforms
            # postPatch = ''
            #   substituteInPlace electron-builder.yaml \
            #     --replace-fail "notarize: true" "notarize: false"
            #   substituteInPlace src/polyfills.ts \
            #     --replace-fail "import 'core-js/es/object';" ""
            # '';

            buildPhase = ''
              runHook preBuild

              # npm run buildFrontend:prod:es6
              # npm run electron:build
              npm exec electron-builder -- --dir \
                -c.electronDist=${electron.dist} \
                -c.electronVersion=${electron.version}

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/${pname}
              cp -r dist/linux-unpacked/{locales,resources{,.pak}} "$out/share/${pname}"

              # icons
              for size in 16 32 48 64 128 256 512 1024; do
                local sizexsize="''${size}x''${size}"
                mkdir -p $out/share/icons/hicolor/$sizexsize/apps
                if [ "$size" == "1024" ]; then
                  srcIcon=assets/icon.png
                else
                  srcIcon=assets/icons/$sizexsize.png
                fi
                cp -v $srcIcon \
                  $out/share/icons/hicolor/$sizexsize/apps/${pname}.png
              done
              # desktop file
              mkdir -p $out/share/applications
              cp flatpak/rocks.shy.VacuumTube.desktop $out/share/applications/VacuumTube.desktop
              substituteInPlace $out/share/applications/VacuumTube.desktop \
                --replace-fail 'Exec=startvacuumtube %U' 'Exec=${pname} %U' \
                --replace-fail 'Icon=rocks.shy.VacuumTube' 'Icon=${pname}'

              makeWrapper '${lib.getExe electron}' "$out/bin/${pname}" \
                --add-flags "$out/share/${pname}/resources/app.asar" \
                --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
                --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
                --inherit-argv0

              runHook postInstall
            '';
          };

        packages.default = packages.vacuumtube;

        formatter = pkgs.alejandra;
      }
    );
}
