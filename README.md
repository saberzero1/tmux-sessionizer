## tmux sessionizer
its a script that does everything awesome at all times

## Requirements
fzf and tmux

## Installation

### Using Nix Flakes

This project provides a Nix Flake for declarative configuration with Home Manager, supporting both NixOS and Darwin (macOS).

#### Quick Start with Nix

To try tmux-sessionizer without installing:
```bash
nix run github:saberzero1/tmux-sessionizer
```

To install directly:
```bash
nix profile install github:saberzero1/tmux-sessionizer
```

#### Home Manager Configuration

Add the flake to your Home Manager configuration:

1. Add the input to your `flake.nix`:
```nix
{
  inputs = {
    tmux-sessionizer = {
      url = "github:saberzero1/tmux-sessionizer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

2. Import the Home Manager module:
```nix
{ inputs, ... }: {
  imports = [ inputs.tmux-sessionizer.homeManagerModules.default ];
  
  programs.tmux-sessionizer = {
    enable = true;
    
    # Optional configuration
    searchPaths = [ "~/" "~/projects" ];
    extraSearchPaths = [ "~/ghq:3" "~/Git:3" ];
    maxDepth = 2;
    sessionCommands = [ "nvim ." "npm run dev" ];
    
    # Enable logging for debugging
    enableLogging = false;
    logOutput = "file";
  };
}
```

#### Configuration Options

All configuration options available in the Home Manager module:

- **`enable`**: Enable tmux-sessionizer (default: `false`)
- **`package`**: The package to use (default: `pkgs.tmux-sessionizer`)
- **`searchPaths`**: Override default search paths (default: `[]`)
- **`extraSearchPaths`**: Additional search paths with optional depth (default: `[]`)
  - Example: `["~/ghq:3" "~/Git:3" "~/.config:2"]` - the number after `:` specifies search depth
- **`maxDepth`**: Maximum search depth (default: `null`, uses 1)
- **`sessionCommands`**: List of commands for session windows (default: `[]`)
  - Access with `tmux-sessionizer -s 0`, `tmux-sessionizer -s 1`, etc.
- **`enableLogging`**: Enable logging (default: `false`)
- **`logOutput`**: Log output type - `"file"` or `"echo"` (default: `"file"`)
- **`logFile`**: Path to log file (default: `"$HOME/.local/share/tmux-sessionizer/tmux-sessionizer.logs"`)
- **`extraConfig`**: Extra bash configuration to append

#### Example Configurations

**Minimal setup:**
```nix
programs.tmux-sessionizer.enable = true;
```

**Full-featured setup:**
```nix
programs.tmux-sessionizer = {
  enable = true;
  searchPaths = [ "~/projects" "~/work" ];
  extraSearchPaths = [ "~/github:3" ];
  maxDepth = 2;
  sessionCommands = [
    "nvim ."
    "npm run dev"
    "docker-compose up"
  ];
  enableLogging = true;
  extraConfig = ''
    # Custom bash configuration
    export MY_CUSTOM_VAR="value"
  '';
};
```

For complete examples including NixOS and nix-darwin configurations, see [examples/home-manager-example.nix](examples/home-manager-example.nix).

### Manual Installation

Download the script and place it in your PATH:
```bash
curl -o ~/.local/bin/tmux-sessionizer https://raw.githubusercontent.com/saberzero1/tmux-sessionizer/main/tmux-sessionizer
chmod +x ~/.local/bin/tmux-sessionizer
```

## Usage
```bash
tmux-sessionizer [<partial name of session>]
```

if you execute tmux-sessionizer without any parameters it will FZF set of default directories or ones specified in config file.

## Session Commands
Session commands are for you to write / navigate without using tmux navigation commands.
They are meant to be used with zsh/vim/tmux remaps.

The basic idea is that you want long running commands on a per session basis.
You can start them by calling tmux-sessionizer with the -s option.  This will
start the long running session starting at window 69.  This means if you open 6
windows, it wont interfere with your way of using tmux.

### Example
tmux-sessionizer config file
```bash
# file: ~/.config/tmux-sessionizer/tmux-sessionizer.conf
TS_SESSION_COMMANDS=(opencode .)
```

There is one command which means you can call `tmux-sessionizer -s 0` only (`-s 1` is out of bounds)
This will effectively call the following command:
```bash
tmux neww -t $SESSION_NAME:69 opencode .
```

### How i use it
Here are my vim remaps for tmux-sessionizer.  C-f will do the standard
sessionizer experience but Alt+h will mimic my harpoon navigation.  C-h is
first file harpoon.  M-h is first sessionizer command.

**vim**
```lua
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<M-h>", "<cmd>silent !tmux neww tmux-sessionizer -s 0<CR>")
vim.keymap.set("n", "<M-t>", "<cmd>silent !tmux neww tmux-sessionizer -s 1<CR>")
vim.keymap.set("n", "<M-n>", "<cmd>silent !tmux neww tmux-sessionizer -s 2<CR>")
vim.keymap.set("n", "<M-s>", "<cmd>silent !tmux neww tmux-sessionizer -s 3<CR>")
```

**zsh**
```bash
bindkey -s ^f "tmux-sessionizer\n"
bindkey -s '\eh' "tmux-sessionizer -s 0\n"
bindkey -s '\et' "tmux-sessionizer -s 1\n"
bindkey -s '\en' "tmux-sessionizer -s 2\n"
bindkey -s '\es' "tmux-sessionizer -s 3\n"
```

**tmux**
```bash
bind-key -r f run-shell "tmux neww ~/.local/bin/tmux-sessionizer"
bind-key -r M-h run-shell "tmux neww tmux-sessionizer -s 0"
bind-key -r M-t run-shell "tmux neww tmux-sessionizer -s 1"
bind-key -r M-n run-shell "tmux neww tmux-sessionizer -s 2"
bind-key -r M-s run-shell "tmux neww tmux-sessionizer -s 3"
```

## Enable Logs
This is for debugging purposes.

```bash
# file: ~/.config/tmux-sessionizer/tmux-sessionizer.conf
TS_LOG=file | echo # echo will echo to stdout, file will write to TS_LOG_FILE
TS_LOG_FILE=<file> # will write logs to <file> Defaults to ~/.local/share/tmux-sessionizer/tmux-sessionizer.logs
```
