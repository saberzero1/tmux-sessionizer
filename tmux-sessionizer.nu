#!/usr/bin/env nu

# tmux-sessionizer - Nushell version
# A script to manage tmux sessions with fzf integration

const VERSION = "0.1.0"

# Configuration paths
def config-dir [] {
    $env.XDG_CONFIG_HOME? | default ($env.HOME | path join ".config") | path join "tmux-sessionizer"
}

def config-file [] {
    config-dir | path join "tmux-sessionizer.nuon"
}

def session-template-file [] {
    config-dir | path join "session-template"
}

def pane-cache-dir [] {
    $env.XDG_CACHE_HOME? | default ($env.HOME | path join ".cache") | path join "tmux-sessionizer"
}

def pane-cache-file [] {
    pane-cache-dir | path join "panes.cache"
}

def log-file-default [] {
    $env.HOME | path join ".local" "share" "tmux-sessionizer" "tmux-sessionizer.logs"
}

# Load configuration from file
def load-config [] {
    let config_path = (config-file)
    if ($config_path | path exists) {
        open $config_path
    } else {
        {}
    }
}

# Configuration record with defaults
def get-config [] {
    let user_config = (load-config)
    {
        search_paths: ($user_config.search_paths? | default ["~/" "~/personal" "~/personal/dev/env/.config"])
        extra_search_paths: ($user_config.extra_search_paths? | default [])
        max_depth: ($user_config.max_depth? | default 1)
        session_commands: ($user_config.session_commands? | default [])
        force_session_template: ($user_config.force_session_template? | default false)
        log: ($user_config.log? | default null)
        log_file: ($user_config.log_file? | default (log-file-default))
    }
}

# Logging function
def log [message: string] {
    let config = (get-config)
    match $config.log {
        "echo" => { print $message }
        "file" => {
            let log_path = $config.log_file
            let log_dir = ($log_path | path dirname)
            if not ($log_dir | path exists) {
                mkdir $log_dir
            }
            $message | save --append $log_path
        }
        _ => { }
    }
}

# Version control directories to check for (highest to lowest priority)
const VC_DIRS = [".git" ".jj" ".hg" ".svn" ".fossil" ".bzr" "_darcs"]

# Check if directory has version control
def has-vcs [dir: string] {
    $VC_DIRS | any {|vc| ($dir | path join $vc | path exists) }
}

# Check if tmux is running
def is-tmux-running [] {
    let tmux_env = ($env.TMUX? | default "")
    let tmux_pgrep = (do { pgrep tmux } | complete)
    not ($tmux_env == "" and $tmux_pgrep.exit_code != 0)
}

# Check if tmux session exists
def has-session [name: string] {
    let result = (do { tmux list-sessions } | complete)
    if $result.exit_code != 0 {
        return false
    }
    $result.stdout | lines | any {|line| $line | str starts-with $"($name):" }
}

# Switch to or attach to a tmux session
def switch-to [session_name: string] {
    let in_tmux = ($env.TMUX? | default "") != ""
    if $in_tmux {
        log $"switching to session ($session_name)"
        tmux switch-client -t $session_name
    } else {
        log $"attaching to session ($session_name)"
        tmux attach-session -t $session_name
    }
}

# Hydrate a session with template/config
def hydrate [session_name: string, selected_dir: string, session_cmd: string] {
    if $session_cmd != "" {
        log $"skipping hydrate for ($session_name) -- using \"($session_cmd)\" instead"
        return
    }

    let config = (get-config)
    let template_file = (session-template-file)
    let local_config = ($selected_dir | path join ".tmux-sessionizer")
    let global_config = ($env.HOME | path join ".tmux-sessionizer")

    # If force template is set, always use session template
    if $config.force_session_template {
        if ($template_file | path exists) {
            log $"sourcing\(forced template) ($template_file)"
            tmux send-keys -t $session_name $"source ($template_file)" C-m
        }
        return
    }

    # Normal precedence: local -> global -> template
    if ($local_config | path exists) {
        log $"sourcing\(local) ($local_config)"
        tmux send-keys -t $session_name $"source ($local_config)" C-m
    } else if ($global_config | path exists) {
        log $"sourcing\(global) ($global_config)"
        tmux send-keys -t $session_name $"source ($global_config)" C-m
    } else if ($template_file | path exists) {
        log $"sourcing\(session template) ($template_file)"
        tmux send-keys -t $session_name $"source ($template_file)" C-m
    }
}

# Find directories based on search paths
def find-dirs [] {
    let config = (get-config)
    mut all_dirs: list<string> = []
    mut vcs_dirs: list<string> = []
    mut other_dirs: list<string> = []

    # List TMUX sessions first (priority 1: active sessions)
    let in_tmux = ($env.TMUX? | default "") != ""
    let sessions_result = (do { tmux list-sessions -F "[TMUX] #{session_name}" } | complete)
    
    let sessions = if $sessions_result.exit_code == 0 {
        let all_sessions = ($sessions_result.stdout | lines)
        if $in_tmux {
            let current = (tmux display-message -p '#S' | str trim)
            $all_sessions | where {|s| $s != $"[TMUX] ($current)" }
        } else {
            $all_sessions
        }
    } else {
        []
    }

    # Combine search paths
    let search_paths = ($config.search_paths ++ $config.extra_search_paths)

    # Search each path
    for entry in $search_paths {
        let parts = ($entry | split row ":")
        let path = ($parts | first | path expand)
        let depth = if ($parts | length) > 1 {
            $parts | get 1 | into int
        } else {
            $config.max_depth
        }

        if ($path | path exists) and ($path | path type) == "dir" {
            let found = (
                do {
                    find $path -maxdepth $depth -mindepth 1 -type d -not -path "*/.git"
                } | complete
            )
            if $found.exit_code == 0 {
                let dirs = ($found.stdout | lines | where {|d| $d != "" })
                $all_dirs = ($all_dirs ++ $dirs)
            }
        }
    }

    # Sort directories: VCS repos first (priority 2), then others (priority 3)
    for dir in $all_dirs {
        if (has-vcs $dir) {
            $vcs_dirs = ($vcs_dirs | append $dir)
        } else {
            $other_dirs = ($other_dirs | append $dir)
        }
    }

    # Return sessions first, then VCS dirs, then others
    $sessions ++ $vcs_dirs ++ $other_dirs
}

# Initialize pane cache
def init-pane-cache [] {
    let cache_dir = (pane-cache-dir)
    let cache_file = (pane-cache-file)
    if not ($cache_dir | path exists) {
        mkdir $cache_dir
    }
    if not ($cache_file | path exists) {
        touch $cache_file
    }
}

# Get cached pane ID
def get-pane-id [session_idx: int, split_type: string] {
    init-pane-cache
    let cache_file = (pane-cache-file)
    let content = (open $cache_file --raw | lines)
    let prefix = $"($session_idx):($split_type):"
    let match = ($content | where {|line| $line | str starts-with $prefix } | first?)
    if $match != null {
        $match | split row ":" | get 2
    } else {
        null
    }
}

# Set cached pane ID
def set-pane-id [session_idx: int, split_type: string, pane_id: string] {
    init-pane-cache
    let cache_file = (pane-cache-file)
    let prefix = $"($session_idx):($split_type):"
    
    # Remove existing entry and add new one
    let content = (open $cache_file --raw | lines | where {|line| not ($line | str starts-with $prefix) })
    let new_entry = $"($session_idx):($split_type):($pane_id)"
    let new_content = ($content | append $new_entry | str join "\n")
    $new_content | save -f $cache_file
}

# Cleanup dead panes from cache
def cleanup-dead-panes [] {
    init-pane-cache
    let cache_file = (pane-cache-file)
    let all_panes_result = (do { tmux list-panes -a -F "#{pane_id}" } | complete)
    
    if $all_panes_result.exit_code != 0 {
        return
    }
    
    let all_panes = ($all_panes_result.stdout | lines)
    let content = (open $cache_file --raw | lines | where {|line| $line != "" })
    
    let valid_entries = ($content | where {|line|
        let parts = ($line | split row ":")
        if ($parts | length) >= 3 {
            let pane_id = ($parts | get 2)
            $all_panes | any {|p| $p == $pane_id }
        } else {
            false
        }
    })
    
    $valid_entries | str join "\n" | save -f $cache_file
}

# Handle window-based session command
def handle-window-session-cmd [current_session: string, session_idx: int, session_cmd: string, selected: string] {
    let start_index = 69 + $session_idx
    let target = $"($current_session):($start_index)"
    
    log $"target: ($target) command ($session_cmd)"
    
    let has_target = (do { tmux has-session -t $"=($target)" } | complete)
    
    if $has_target.exit_code == 0 {
        switch-to $target
    } else {
        log $"executing session command: tmux neww -dt ($target) ($session_cmd)"
        tmux neww -dt $target $session_cmd
        hydrate $target $selected $session_cmd
        tmux select-window -t $target
    }
}

# Handle split-based session command
def handle-split-session-cmd [current_session: string, session_idx: int, session_cmd: string, split_type: string] {
    cleanup-dead-panes
    
    # Check if pane already exists
    let existing_pane_id = (get-pane-id $session_idx $split_type)
    
    if $existing_pane_id != null {
        let all_panes_result = (do { tmux list-panes -a -F "#{pane_id}" } | complete)
        let pane_exists = if $all_panes_result.exit_code == 0 {
            $all_panes_result.stdout | lines | any {|p| $p == $existing_pane_id }
        } else {
            false
        }
        
        if $pane_exists {
            log $"switching to existing pane ($existing_pane_id)"
            tmux select-pane -t $existing_pane_id
            let in_tmux = ($env.TMUX? | default "") != ""
            if $in_tmux {
                tmux switch-client -t $current_session
            } else {
                tmux attach-session -t $current_session
            }
            return
        }
    }
    
    # Create new split
    let split_flag = if $split_type == "vsplit" { "-h" } else { "-v" }
    let pwd = (pwd)
    
    log $"creating new split: tmux split-window ($split_flag) -c ($pwd) ($session_cmd)"
    let new_pane_result = (do { tmux split-window $split_flag -c $pwd -P -F "#{pane_id}" $session_cmd } | complete)
    
    if $new_pane_result.exit_code == 0 {
        let new_pane_id = ($new_pane_result.stdout | str trim)
        set-pane-id $session_idx $split_type $new_pane_id
        log $"created pane ($new_pane_id) for session_idx=($session_idx) split_type=($split_type)"
    }
}

# Handle session command
def handle-session-cmd [session_idx: int, session_cmd: string, split_type: string, selected: string] {
    log $"executing session command ($session_cmd) with index ($session_idx) split_type=($split_type)"
    
    if not (is-tmux-running) {
        print "Error: tmux is not running. Please start tmux first before using session commands."
        exit 1
    }
    
    let current_session = (tmux display-message -p '#S' | str trim)
    
    if $split_type != "" {
        handle-split-session-cmd $current_session $session_idx $session_cmd $split_type
    } else {
        handle-window-session-cmd $current_session $session_idx $session_cmd $selected
    }
}

# Sanity check for required tools
def sanity-check [] {
    if (which tmux | is-empty) {
        print "tmux is not installed. Please install it first."
        exit 1
    }
    
    if (which fzf | is-empty) {
        print "fzf is not installed. Please install it first."
        exit 1
    }
}

# Main entrypoint
def main [
    search_path?: string           # Optional path to use directly
    --session (-s): int            # Session command index
    --vsplit                       # Create vertical split (horizontal layout) for session command
    --hsplit                       # Create horizontal split (vertical layout) for session command
    --help (-h)                    # Display help message
    --version (-v)                 # Display version
] {
    if $help {
        print "Usage: tmux-sessionizer [OPTIONS] [SEARCH_PATH]"
        print "Options:"
        print "  -h, --help             Display this help message"
        print "  -s, --session <index>  Session command index"
        print "  --vsplit               Create vertical split (horizontal layout) for session command"
        print "  --hsplit               Create horizontal split (vertical layout) for session command"
        print "  -v, --version          Display version"
        return
    }
    
    if $version {
        print $"tmux-sessionizer version ($VERSION)"
        return
    }
    
    sanity-check
    
    let config = (get-config)
    
    # Determine split type
    let split_type = if $vsplit {
        "vsplit"
    } else if $hsplit {
        "hsplit"
    } else {
        ""
    }
    
    # Validate split options are only used with session commands
    if $split_type != "" and $session == null {
        print "Error: --vsplit and --hsplit can only be used with -s/--session option"
        exit 1
    }
    
    # Handle session command
    let session_cmd = if $session != null {
        if ($config.session_commands | is-empty) {
            print "TS_SESSION_COMMANDS is not set. Must have a command set to run when switching to a session"
            exit 1
        }
        
        let max_idx = ($config.session_commands | length) - 1
        if $session < 0 or $session > $max_idx {
            print $"Error: Invalid index. Please provide an index between 0 and ($max_idx)."
            exit 1
        }
        
        $config.session_commands | get $session
    } else {
        ""
    }
    
    log $"tmux-sessionizer\(($VERSION)): idx=($session | default '') cmd=($session_cmd) user_selected=($search_path | default '') split_type=($split_type)"
    
    if $session_cmd != "" {
        handle-session-cmd $session $session_cmd $split_type ($search_path | default "")
        return
    }
    
    # Select directory
    let selected = if $search_path != null {
        $search_path
    } else {
        let dirs = (find-dirs)
        let selection = ($dirs | str join "\n" | fzf | str trim)
        if $selection == "" {
            return
        }
        $selection
    }
    
    if $selected == "" {
        return
    }
    
    # Handle TMUX session selection
    let final_selected = if ($selected | str starts-with "[TMUX] ") {
        $selected | str substring 7..
    } else {
        $selected
    }
    
    let selected_name = ($final_selected | path basename | str replace -a "." "_")
    
    if not (is-tmux-running) {
        tmux new-session -ds $selected_name -c $final_selected
        hydrate $selected_name $final_selected ""
    }
    
    if not (has-session $selected_name) {
        tmux new-session -ds $selected_name -c $final_selected
        hydrate $selected_name $final_selected ""
    }
    
    switch-to $selected_name
}
