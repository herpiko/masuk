#!/bin/bash

# Masuk - SSH host and port manager (Bash version)
# A simple SSH host and port manager that allows you to save SSH connection details with memorable names

set -e

CONFIG_DIR="$HOME/.config/masuk"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Initialize config file if it doesn't exist
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$CONFIG_DIR"
        local timestamp=$(date +%s)
        echo "{\"profiles\":{},\"updated_at\":$timestamp}" > "$CONFIG_FILE"
    fi
}

# Update timestamp in config
update_timestamp() {
    local timestamp=$(date +%s)
    local tmp_file=$(mktemp)
    jq ".updated_at = $timestamp" "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
}

# Add a profile
add_profile() {
    local profile=""
    local host=""
    local user=""
    local port=""
    local key=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                host="$2"
                shift 2
                ;;
            -u|--user)
                user="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -k|--key)
                key="$2"
                shift 2
                ;;
            *)
                if [[ -z "$profile" ]]; then
                    profile="$1"
                    shift
                else
                    echo "Error: Unknown argument: $1"
                    exit 1
                fi
                ;;
        esac
    done

    # Validate required fields
    if [[ -z "$profile" ]]; then
        echo "Error: Profile name is required"
        echo "Usage: masuk add <profile> -h <host> [-u <user>] [-p <port>] [-k <key>]"
        exit 1
    fi

    if [[ -z "$host" ]]; then
        echo "Error: Host is required"
        echo "Usage: masuk add <profile> -h <host> [-u <user>] [-p <port>] [-k <key>]"
        exit 1
    fi

    # Build JSON object
    local config_obj="{\"host\":\"$host\""
    if [[ -n "$user" ]]; then
        config_obj+=",\"user\":\"$user\""
    fi
    if [[ -n "$port" ]]; then
        config_obj+=",\"port\":$port"
    fi
    if [[ -n "$key" ]]; then
        config_obj+=",\"key\":\"$key\""
    fi
    config_obj+="}"

    # Add to config
    local tmp_file=$(mktemp)
    jq ".profiles[\"$profile\"] = $config_obj" "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
    update_timestamp

    # Build display string
    local display=""
    if [[ -n "$user" ]]; then
        display="${user}@"
    fi
    display+="$host"
    if [[ -n "$port" ]]; then
        display+=":$port"
    fi
    if [[ -n "$key" ]]; then
        display+=" (key: $key)"
    fi

    echo -e "${GREEN}✓${NC} Added profile '$profile' → $display"
}

# Connect to a profile
connect_profile() {
    local profile="$1"

    if [[ -z "$profile" ]]; then
        echo "Error: Profile name is required"
        exit 1
    fi

    # Check if profile exists
    if ! jq -e ".profiles[\"$profile\"]" "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "Error: Profile '$profile' not found. Use 'masuk ls' to see available profiles."
        exit 1
    fi

    # Read profile config
    local host=$(jq -r ".profiles[\"$profile\"].host" "$CONFIG_FILE")
    local user=$(jq -r ".profiles[\"$profile\"].user // empty" "$CONFIG_FILE")
    local port=$(jq -r ".profiles[\"$profile\"].port // empty" "$CONFIG_FILE")
    local key=$(jq -r ".profiles[\"$profile\"].key // empty" "$CONFIG_FILE")

    # Build display string
    local display=""
    if [[ -n "$user" ]]; then
        display="${user}@"
    fi
    display+="$host"
    if [[ -n "$port" ]]; then
        display+=":$port"
    fi

    echo "Connecting to $profile ($display)..."

    # Build SSH command
    local ssh_cmd="ssh"
    local ssh_args=()

    if [[ -n "$port" ]]; then
        ssh_args+=("-p" "$port")
    fi

    if [[ -n "$key" ]]; then
        ssh_args+=("-i" "$key")
    fi

    # Build target
    local target="$host"
    if [[ -n "$user" ]]; then
        target="${user}@${host}"
    fi

    # Execute SSH
    exec ssh "${ssh_args[@]}" "$target"
}

# List all profiles
list_profiles() {
    local profile_count=$(jq '.profiles | length' "$CONFIG_FILE")

    if [[ "$profile_count" -eq 0 ]]; then
        echo "No profiles configured yet. Use 'masuk add <profile> -h <host>' to add one."
        return
    fi

    echo ""
    echo "Configured profiles:"
    echo ""

    # Get sorted profile names and iterate
    jq -r '.profiles | keys | sort | .[]' "$CONFIG_FILE" | while read -r profile; do
        local host=$(jq -r ".profiles[\"$profile\"].host" "$CONFIG_FILE")
        local user=$(jq -r ".profiles[\"$profile\"].user // empty" "$CONFIG_FILE")
        local port=$(jq -r ".profiles[\"$profile\"].port // empty" "$CONFIG_FILE")
        local key=$(jq -r ".profiles[\"$profile\"].key // empty" "$CONFIG_FILE")

        local display=""
        if [[ -n "$user" ]]; then
            display="${user}@"
        fi
        display+="$host"
        if [[ -n "$port" ]]; then
            display+=":$port"
        fi
        if [[ -n "$key" ]]; then
            display+=" (key: $key)"
        fi

        echo "  $profile → $display"
    done
    echo ""
}

# Remove a profile
remove_profile() {
    local profile="$1"

    if [[ -z "$profile" ]]; then
        echo "Error: Profile name is required"
        exit 1
    fi

    # Check if profile exists
    if ! jq -e ".profiles[\"$profile\"]" "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "Error: Profile '$profile' not found"
        exit 1
    fi

    # Remove profile
    local tmp_file=$(mktemp)
    jq "del(.profiles[\"$profile\"])" "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
    update_timestamp

    echo -e "${GREEN}✓${NC} Removed profile '$profile'"
}

# Show help
show_help() {
    cat << EOF
Masuk - SSH host and port manager

USAGE:
    masuk <COMMAND>

COMMANDS:
    add <profile> -h <host> [-u <user>] [-p <port>] [-k <key>]
        Add a profile with host and optional user/port/key
        Example: masuk add foobar -h 192.168.1.81 -u root -p 2222 -k ~/.ssh/id_rsa

    list, ls
        List all configured profiles

    remove <profile>, rm <profile>
        Remove a profile
        Example: masuk remove foobar

    <profile>
        Connect to a saved profile
        Example: masuk myserver

    help, --help, -h
        Show this help message

EXAMPLES:
    # Add a profile with just host
    masuk add myserver -h example.com

    # Add a profile with user and port
    masuk add dev -h dev.example.com -u root -p 2222

    # Connect to a profile
    masuk myserver

    # List all profiles
    masuk ls

    # Remove a profile
    masuk rm myserver
EOF
}

# Main function
main() {
    # Check for jq dependency
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed."
        echo "Please install jq: https://stedolan.github.io/jq/"
        exit 1
    fi

    # Initialize config
    init_config

    # Parse command
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        add)
            add_profile "$@"
            ;;
        list|ls)
            list_profiles
            ;;
        remove|rm)
            remove_profile "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            # Treat as profile name for direct connection
            connect_profile "$command"
            ;;
    esac
}

main "$@"
