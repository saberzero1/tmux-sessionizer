{
  description = "Tmux sessionizer - A script that helps you manage tmux sessions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = self.packages.${system}.tmux-sessionizer;

          tmux-sessionizer = pkgs.stdenv.mkDerivation {
            pname = "tmux-sessionizer";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            dontBuild = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              cp tmux-sessionizer $out/bin/tmux-sessionizer
              chmod +x $out/bin/tmux-sessionizer

              wrapProgram $out/bin/tmux-sessionizer \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.fzf pkgs.tmux pkgs.findutils pkgs.gnugrep pkgs.coreutils pkgs.gnused pkgs.bash ]}

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "A tmux session manager with FZF integration";
              homepage = "https://github.com/saberzero1/tmux-sessionizer";
              license = licenses.mit;
              platforms = platforms.unix;
              maintainers = [ ];
            };
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/tmux-sessionizer";
        };
      }
    ) // {
      # Home Manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.tmux-sessionizer;
        in
        {
          options.programs.tmux-sessionizer = {
            enable = mkEnableOption "tmux-sessionizer";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.tmux-sessionizer;
              defaultText = literalExpression "pkgs.tmux-sessionizer";
              description = "The tmux-sessionizer package to use.";
            };

            searchPaths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "~/" "~/projects" ];
              description = ''
                List of paths to search for directories.
                If set, this will override the default search paths.
                Leave empty to use the default paths.
              '';
            };

            extraSearchPaths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "~/ghq:3" "~/Git:3" "~/.config:2" ];
              description = ''
                Additional search paths to append to the default search paths.
                Can be suffixed with :number to specify search depth.
              '';
            };

            maxDepth = mkOption {
              type = types.nullOr types.int;
              default = null;
              example = 2;
              description = ''
                Maximum depth for directory search.
                If not set, defaults to 1.
              '';
            };

            sessionCommands = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "nvim ." "npm run dev" ];
              description = ''
                List of commands to run in session windows.
                These can be executed with tmux-sessionizer -s <index>.
              '';
            };

            enableLogging = mkOption {
              type = types.bool;
              default = false;
              description = "Enable logging for debugging purposes.";
            };

            logOutput = mkOption {
              type = types.enum [ "file" "echo" ];
              default = "file";
              description = ''
                Where to send log output.
                - file: Write to logFile
                - echo: Echo to stdout
              '';
            };

            logFile = mkOption {
              type = types.str;
              default = "$HOME/.local/share/tmux-sessionizer/tmux-sessionizer.logs";
              description = "Path to log file when enableLogging is true and logOutput is 'file'.";
            };

            extraConfig = mkOption {
              type = types.lines;
              default = "";
              example = ''
                # Custom configuration
                export CUSTOM_VAR="value"
              '';
              description = "Extra configuration to append to the config file.";
            };
          };

          config = mkIf cfg.enable {
            home.packages = [ cfg.package ];

            xdg.configFile."tmux-sessionizer/tmux-sessionizer.conf" = mkIf
              (cfg.searchPaths != [ ] ||
               cfg.extraSearchPaths != [ ] ||
               cfg.maxDepth != null ||
               cfg.sessionCommands != [ ] ||
               cfg.enableLogging ||
               cfg.extraConfig != "")
              {
                text = ''
                  ${optionalString (cfg.searchPaths != [ ]) ''
                    TS_SEARCH_PATHS=(${concatMapStringsSep " " (p: ''"${p}"'') cfg.searchPaths})
                  ''}
                  ${optionalString (cfg.extraSearchPaths != [ ]) ''
                    TS_EXTRA_SEARCH_PATHS=(${concatMapStringsSep " " (p: ''"${p}"'') cfg.extraSearchPaths})
                  ''}
                  ${optionalString (cfg.maxDepth != null) ''
                    TS_MAX_DEPTH=${toString cfg.maxDepth}
                  ''}
                  ${optionalString (cfg.sessionCommands != [ ]) ''
                    TS_SESSION_COMMANDS=(${concatMapStringsSep " " (c: ''"${c}"'') cfg.sessionCommands})
                  ''}
                  ${optionalString cfg.enableLogging ''
                    TS_LOG="${cfg.logOutput}"
                  ''}
                  ${optionalString (cfg.enableLogging && cfg.logOutput == "file") ''
                    TS_LOG_FILE="${cfg.logFile}"
                  ''}
                  ${cfg.extraConfig}
                '';
              };
          };
        };

      # Alias for convenience
      homeManagerModules.tmux-sessionizer = self.homeManagerModules.default;
    };
}
