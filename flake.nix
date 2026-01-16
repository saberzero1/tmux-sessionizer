{
  description = "tmux-sessionizer - fuzzy-finder for tmux sessions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # Systems supported (both NixOS and Darwin)
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Home Manager module
      homeManagerModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.tmux-sessionizer;
          settingsFormat = pkgs.formats.keyValue { };
        in
        {
          options.programs.tmux-sessionizer = {
            enable = lib.mkEnableOption "tmux-sessionizer";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = lib.literalExpression "inputs.tmux-sessionizer.packages.\${pkgs.system}.default";
              description = "The tmux-sessionizer package to use.";
            };

            searchPaths = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [
                "~/"
                "~/projects"
              ];
              description = ''
                List of paths to search for directories.
                If set, this overrides the default search paths.
              '';
            };

            extraSearchPaths = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [
                "~/ghq:3"
                "~/Git:3"
                "~/.config:2"
              ];
              description = ''
                Additional search paths to add to the default paths.
                Optionally suffix with :N to specify search depth.
              '';
            };

            maxDepth = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              example = 2;
              description = ''
                Maximum depth for directory search.
                Defaults to 1 if not set.
              '';
            };

            sessionCommands = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [
                "opencode ."
                "lazygit"
              ];
              description = ''
                List of commands for session windows.
                These can be invoked with tmux-sessionizer -s <index>.
              '';
            };

            enableLogging = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.enum [
                  "file"
                  "echo"
                ]
              );
              default = null;
              example = "file";
              description = ''
                Enable logging. "file" writes to log file, "echo" prints to stdout.
              '';
            };

            logFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "~/.local/share/tmux-sessionizer/debug.log";
              description = ''
                Path to log file. Defaults to ~/.local/share/tmux-sessionizer/tmux-sessionizer.logs
              '';
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];

            xdg.configFile."tmux-sessionizer/tmux-sessionizer.conf" =
              lib.mkIf
                (
                  cfg.searchPaths != [ ]
                  || cfg.extraSearchPaths != [ ]
                  || cfg.maxDepth != null
                  || cfg.sessionCommands != [ ]
                  || cfg.enableLogging != null
                  || cfg.logFile != null
                )
                {
                  text = lib.concatStringsSep "\n" (
                    lib.optional (
                      cfg.searchPaths != [ ]
                    ) "TS_SEARCH_PATHS=(${lib.concatStringsSep " " cfg.searchPaths})"
                    ++ lib.optional (
                      cfg.extraSearchPaths != [ ]
                    ) "TS_EXTRA_SEARCH_PATHS=(${lib.concatStringsSep " " cfg.extraSearchPaths})"
                    ++ lib.optional (cfg.maxDepth != null) "TS_MAX_DEPTH=${toString cfg.maxDepth}"
                    ++
                      lib.optional (cfg.sessionCommands != [ ])
                        "TS_SESSION_COMMANDS=(${lib.concatMapStringsSep " " (cmd: ''"${cmd}"'') cfg.sessionCommands})"
                    ++ lib.optional (cfg.enableLogging != null) "TS_LOG=${cfg.enableLogging}"
                    ++ lib.optional (cfg.logFile != null) "TS_LOG_FILE=${cfg.logFile}"
                  );
                };
          };
        };
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          tmux-sessionizer = pkgs.stdenv.mkDerivation {
            pname = "tmux-sessionizer";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            # Runtime dependencies
            buildInputs = [ pkgs.bash ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              cp tmux-sessionizer $out/bin/tmux-sessionizer
              chmod +x $out/bin/tmux-sessionizer

              wrapProgram $out/bin/tmux-sessionizer \
                --prefix PATH : ${
                  pkgs.lib.makeBinPath [
                    pkgs.tmux
                    pkgs.fzf
                    pkgs.gnugrep
                    pkgs.findutils
                    pkgs.procps
                    pkgs.coreutils
                  ]
                }

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Fuzzy-finder for tmux sessions";
              homepage = "https://github.com/ThePrimeagen/tmux-sessionizer";
              license = licenses.mit;
              maintainers = [ ];
              platforms = platforms.unix;
              mainProgram = "tmux-sessionizer";
            };
          };

          default = self.packages.${system}.tmux-sessionizer;
        };

        apps = {
          tmux-sessionizer = flake-utils.lib.mkApp {
            drv = self.packages.${system}.tmux-sessionizer;
          };
          default = self.apps.${system}.tmux-sessionizer;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            tmux
            fzf
            bash
          ];
        };
      }
    )
    // {
      # Export the Home Manager module
      homeManagerModules = {
        tmux-sessionizer = homeManagerModule;
        default = homeManagerModule;
      };

      # Backwards compatibility alias
      homeManagerModule = homeManagerModule;

      # Overlay for easy integration
      overlays.default = final: prev: {
        tmux-sessionizer = self.packages.${prev.system}.tmux-sessionizer;
      };
    };
}
