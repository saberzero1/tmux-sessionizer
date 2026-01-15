# Example Home Manager configuration for tmux-sessionizer
# This file shows various configuration examples

{
  description = "Example Home Manager configuration with tmux-sessionizer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux-sessionizer = {
      url = "github:saberzero1/tmux-sessionizer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, darwin, tmux-sessionizer, ... }: {
    # Example for standalone home-manager on Linux/macOS
    homeConfigurations."user@hostname" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux; # or x86_64-darwin for macOS
      modules = [
        tmux-sessionizer.homeManagerModules.default
        {
          home.username = "user";
          home.homeDirectory = "/home/user";
          home.stateVersion = "24.05";

          # Minimal configuration
          programs.tmux-sessionizer.enable = true;

          # Or with custom configuration
          # programs.tmux-sessionizer = {
          #   enable = true;
          #   searchPaths = [ "~/projects" "~/work" ];
          #   extraSearchPaths = [ "~/github:3" "~/gitlab:2" ];
          #   maxDepth = 2;
          #   sessionCommands = [
          #     "nvim ."
          #     "npm run dev"
          #     "docker-compose up"
          #   ];
          #   enableLogging = true;
          # };
        }
      ];
    };

    # Example for NixOS system configuration
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.user = {
            imports = [ tmux-sessionizer.homeManagerModules.default ];
            
            programs.tmux-sessionizer = {
              enable = true;
              searchPaths = [ "~/projects" ];
              sessionCommands = [ "nvim ." ];
            };
          };
        }
      ];
    };

    # Example for nix-darwin (macOS)
    darwinConfigurations.hostname = darwin.lib.darwinSystem {
      system = "aarch64-darwin"; # or x86_64-darwin
      modules = [
        home-manager.darwinModules.home-manager
        {
          home-manager.users.user = {
            imports = [ tmux-sessionizer.homeManagerModules.default ];
            
            programs.tmux-sessionizer = {
              enable = true;
              searchPaths = [ "~/Code" "~/Documents" ];
              extraSearchPaths = [ "~/github:3" ];
              sessionCommands = [ "nvim ." "npm run dev" ];
            };
          };
        }
      ];
    };
  };
}
