# Home Manager Examples

This directory contains example configurations for using tmux-sessionizer with Home Manager.

## Files

- **home-manager-example.nix**: Complete example flake showing configurations for:
  - Standalone Home Manager
  - NixOS with Home Manager
  - nix-darwin (macOS) with Home Manager

## Usage

### Standalone Home Manager

If you're using Home Manager standalone (not as a NixOS or nix-darwin module):

```nix
# In your flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    tmux-sessionizer.url = "github:saberzero1/tmux-sessionizer";
  };

  outputs = { nixpkgs, home-manager, tmux-sessionizer, ... }: {
    homeConfigurations."youruser@yourhostname" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        tmux-sessionizer.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

Then in your `home.nix`:

```nix
{ config, pkgs, ... }: {
  programs.tmux-sessionizer = {
    enable = true;
    searchPaths = [ "~/projects" ];
  };
}
```

### NixOS with Home Manager

If you're using NixOS with Home Manager as a module:

```nix
# In your configuration.nix or flake.nix
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager.users.youruser = {
    imports = [ inputs.tmux-sessionizer.homeManagerModules.default ];
    
    programs.tmux-sessionizer = {
      enable = true;
      searchPaths = [ "~/dev" "~/projects" ];
      sessionCommands = [ "nvim ." ];
    };
  };
}
```

### nix-darwin (macOS)

If you're using nix-darwin:

```nix
# In your darwin-configuration.nix or flake.nix
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager.users.youruser = {
    imports = [ inputs.tmux-sessionizer.homeManagerModules.default ];
    
    programs.tmux-sessionizer = {
      enable = true;
      searchPaths = [ "~/Code" "~/Documents" ];
      extraSearchPaths = [ "~/github:3" ];
    };
  };
}
```

## Testing Your Configuration

After setting up your configuration:

1. Build your configuration:
   ```bash
   # For standalone Home Manager
   home-manager switch --flake .#youruser@yourhostname
   
   # For NixOS
   sudo nixos-rebuild switch --flake .
   
   # For nix-darwin
   darwin-rebuild switch --flake .
   ```

2. Verify tmux-sessionizer is available:
   ```bash
   which tmux-sessionizer
   tmux-sessionizer --version
   ```

3. Check your configuration was applied:
   ```bash
   cat ~/.config/tmux-sessionizer/tmux-sessionizer.conf
   ```

## Tips

- Use `searchPaths` to completely override the default search locations
- Use `extraSearchPaths` to add additional locations while keeping defaults
- Add `:N` suffix to paths in `extraSearchPaths` to control search depth (e.g., `"~/github:3"`)
- Session commands are indexed from 0, use with `tmux-sessionizer -s 0`, `-s 1`, etc.
