## tmux sessionizer
its a script that does everything awesome at all times

## Requirements
fzf and tmux

## Shell Support

tmux-sessionizer is available in multiple shell flavors:
- **Bash**: `tmux-sessionizer` (default)
- **Nushell**: `tmux-sessionizer.nu`

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

**nushell**
```nu
# Add to your config.nu
$env.config.keybindings = ($env.config.keybindings | append [
    {
        name: tmux_sessionizer
        modifier: control
        keycode: char_f
        mode: [emacs vi_normal vi_insert]
        event: { send: executehostcommand cmd: "tmux neww tmux-sessionizer.nu" }
    }
    {
        name: tmux_session_0
        modifier: alt
        keycode: char_h
        mode: [emacs vi_normal vi_insert]
        event: { send: executehostcommand cmd: "tmux neww tmux-sessionizer.nu -s 0" }
    }
    {
        name: tmux_session_1
        modifier: alt
        keycode: char_t
        mode: [emacs vi_normal vi_insert]
        event: { send: executehostcommand cmd: "tmux neww tmux-sessionizer.nu -s 1" }
    }
    {
        name: tmux_session_2
        modifier: alt
        keycode: char_n
        mode: [emacs vi_normal vi_insert]
        event: { send: executehostcommand cmd: "tmux neww tmux-sessionizer.nu -s 2" }
    }
    {
        name: tmux_session_3
        modifier: alt
        keycode: char_s
        mode: [emacs vi_normal vi_insert]
        event: { send: executehostcommand cmd: "tmux neww tmux-sessionizer.nu -s 3" }
    }
])
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

**Bash config** (`~/.config/tmux-sessionizer/tmux-sessionizer.conf`):
```bash
TS_LOG=file | echo # echo will echo to stdout, file will write to TS_LOG_FILE
TS_LOG_FILE=<file> # will write logs to <file> Defaults to ~/.local/share/tmux-sessionizer/tmux-sessionizer.logs
```

**Nushell config** (`~/.config/tmux-sessionizer/tmux-sessionizer.nuon`):
```nu
{
    log: "file"  # or "echo"
    log_file: "~/.local/share/tmux-sessionizer/tmux-sessionizer.logs"
}
```

## Nushell Configuration

The Nushell version uses a `.nuon` configuration file instead of the bash `.conf` file.

Create `~/.config/tmux-sessionizer/tmux-sessionizer.nuon`:
```nu
{
    # Override default search paths (optional)
    search_paths: ["~/" "~/projects" "~/work"]
    
    # Add extra search paths with optional depth suffix (optional)
    # Format: "path:depth" or just "path"
    extra_search_paths: ["~/ghq:3" "~/Git:3" "~/.config:2"]
    
    # Default max search depth when not specified per-path (default: 1)
    max_depth: 2
    
    # Session commands accessible via tmux-sessionizer.nu -s <index>
    session_commands: ["opencode ." "lazygit" "htop"]
    
    # Force session template to always run instead of .tmux-sessionizer files
    force_session_template: false
    
    # Enable logging: "file" or "echo" (optional, null to disable)
    log: null
    
    # Custom log file path (optional)
    log_file: "~/.local/share/tmux-sessionizer/debug.log"
}
```

## Nix Flake Installation

This repository provides a Nix flake with a Home Manager module that works on both NixOS and nix-darwin.

### Quick Install

Run directly without installing:
```bash
nix run github:saberzero1/tmux-sessionizer
```

### Flake Input

Add to your `flake.nix` inputs:
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    tmux-sessionizer.url = "github:saberzero1/tmux-sessionizer";
  };
}
```

### Home Manager Module

Import the module and configure:

```nix
{ inputs, ... }:
{
  imports = [ inputs.tmux-sessionizer.homeManagerModules.default ];

  programs.tmux-sessionizer = {
    enable = true;

    # Enable Nushell version (installs tmux-sessionizer.nu and generates NUON config)
    # enableNushell = true;

    # Override default search paths (optional)
    # searchPaths = [ "~/" "~/projects" ];

    # Add extra search paths with optional depth suffix (optional)
    extraSearchPaths = [ "~/projects:3" "~/work:2" "~/.config:1" ];

    # Maximum search depth when not specified per-path (optional, default: 1)
    maxDepth = 2;

    # Session commands accessible via tmux-sessionizer -s <index>
    sessionCommands = [ "opencode ." "lazygit" "htop" ];

    # Session template: runs when no .tmux-sessionizer file exists (optional)
    sessionTemplate = ''
      # Example: auto-allow direnv
      if command -v direnv &> /dev/null; then
        eval "$(direnv export bash)"
      fi
    '';

    # Force session template to always run instead of .tmux-sessionizer files
    # forceSessionTemplate = true;

    # Enable logging: "file" or "echo" (optional)
    # enableLogging = "file";

    # Custom log file path (optional)
    # logFile = "~/.local/share/tmux-sessionizer/debug.log";
  };
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | boolean | `false` | Enable tmux-sessionizer |
| `enableNushell` | boolean | `false` | Enable Nushell version (installs `tmux-sessionizer.nu` and generates NUON config) |
| `package` | package | `<flake>.packages.${system}.default` | The tmux-sessionizer package to use |
| `nushellPackage` | package | `<flake>.packages.${system}.tmux-sessionizer-nu` | The tmux-sessionizer Nushell package to use |
| `searchPaths` | list of strings | `[]` | Override default search paths (`TS_SEARCH_PATHS`) |
| `extraSearchPaths` | list of strings | `[]` | Additional search paths, optionally with `:depth` suffix (`TS_EXTRA_SEARCH_PATHS`) |
| `maxDepth` | int or null | `null` | Default max search depth (`TS_MAX_DEPTH`) |
| `sessionCommands` | list of strings | `[]` | Commands for session windows (`TS_SESSION_COMMANDS`) |
| `sessionTemplate` | multiline string or null | `null` | Bash script to run on new sessions (fallback when no `.tmux-sessionizer` file exists) |
| `forceSessionTemplate` | boolean | `false` | Always use `sessionTemplate` instead of `.tmux-sessionizer` files |
| `enableLogging` | `"file"`, `"echo"`, or null | `null` | Enable logging (`TS_LOG`) |
| `logFile` | string or null | `null` | Custom log file path (`TS_LOG_FILE`) |

### Using the Overlay

You can also use the provided overlay to add `tmux-sessionizer` to your pkgs:

```nix
{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.tmux-sessionizer.overlays.default ];

  # Then use it anywhere
  environment.systemPackages = [
    pkgs.tmux-sessionizer      # Bash version
    pkgs.tmux-sessionizer-nu   # Nushell version
  ];
}
```

### Standalone Package

Install without Home Manager:
```bash
# Add to profile (Bash version)
nix profile install github:saberzero1/tmux-sessionizer

# Add Nushell version to profile
nix profile install github:saberzero1/tmux-sessionizer#tmux-sessionizer-nu

# Or in a flake-based config
environment.systemPackages = [
  inputs.tmux-sessionizer.packages.${system}.default           # Bash version
  inputs.tmux-sessionizer.packages.${system}.tmux-sessionizer-nu  # Nushell version
];
```

## Credits

This is a fork/derivative of the original [tmux-sessionizer by ThePrimeagen](https://github.com/ThePrimeagen/tmux-sessionizer).
