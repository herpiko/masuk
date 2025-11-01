# Masuk

Masuk is a simple SSH host and port manager that allows you to save SSH connection details with memorable names and connect quickly.

## Features

- Store SSH host configurations with optional user and port
- Connect to saved hosts with a single command
- Simple JSON-based configuration storage
- No modification to your `~/.ssh/config` file
- Only stores values you explicitly provide (no defaults saved)

## Building

```bash
cargo build --release
```

The binary will be available at `target/release/masuk`.

## Installation

```bash
cargo install --path .
```

Or copy the binary to your PATH:

```bash
cp target/release/masuk /usr/local/bin/
```

## Usage

### Quick Reference

```bash
# Add a profile (minimal)
masuk add <profile> -h <host>

# Add a profile with user
masuk add <profile> -h <host> -u <user>

# Add a profile with port
masuk add <profile> -h <host> -p <port>

# Add a profile with both user and port
masuk add <profile> -h <host> -u <user> -p <port>

# Connect to a profile
masuk <profile>

# List all profiles
masuk ls

# Remove a profile
masuk rm <profile>
```

### Examples

#### Add profiles with different configurations

**Just host (uses SSH defaults for user and port)**:
```bash
masuk add myserver -h example.com
```
This stores only: `{"host": "example.com"}`

**Host with custom port**:
```bash
masuk add foobar -h 192.168.1.81 -p 2222
```
This stores: `{"host": "192.168.1.81", "port": 2222}`

**Host with user**:
```bash
masuk add prod -h prod.example.com -u deploy
```
This stores: `{"host": "prod.example.com", "user": "deploy"}`

**Host with user and custom port**:
```bash
masuk add dev -h dev.example.com -u root -p 2222
```
This stores: `{"host": "dev.example.com", "user": "root", "port": 2222}`

#### Connect to a saved profile

Simply use the profile name to connect:

```bash
masuk myserver
```

This will execute the appropriate SSH command based on what you saved:
- `ssh example.com` (if only host was saved)
- `ssh 192.168.1.81 -p 2222` (if host and port were saved)
- `ssh deploy@prod.example.com` (if host and user were saved)
- `ssh root@dev.example.com -p 2222` (if all were saved)

#### List all profiles

View all configured profiles:

```bash
masuk ls
```

or

```bash
masuk list
```

Example output:
```
Configured profiles:

  dev → root@dev.example.com:2222
  foobar → 192.168.1.81:2222
  myserver → example.com
  prod → deploy@prod.example.com
```

#### Remove a profile

Remove a profile you no longer need:

```bash
masuk rm foobar
```

or

```bash
masuk remove foobar
```

## How it works

Masuk stores profile configurations in `~/.config/masuk/config.json`. Each profile contains:
- A memorable name (the profile name)
- The hostname or IP address (required)
- The SSH username (optional - only stored if you specify it)
- The SSH port number (optional - only stored if you specify it)

When you connect using a profile name, Masuk looks up the saved configuration and runs the appropriate SSH command. If user or port were not specified when adding the profile, SSH will use its default behavior (current user and port 22).

## Configuration File

The configuration file is stored at `~/.config/masuk/config.json`.

**Example with all optional fields**:
```json
{
  "profiles": {
    "dev": {
      "host": "dev.example.com",
      "user": "root",
      "port": 2222
    }
  },
  "updated_at": 1234567890
}
```

**Example with minimal config (only host)**:
```json
{
  "profiles": {
    "myserver": {
      "host": "example.com"
    }
  },
  "updated_at": 1234567890
}
```

Notice how `user` and `port` are not present when not specified - this keeps your config clean and allows SSH to use its defaults.

You can manually edit this file if needed, though it's recommended to use the CLI commands.

## License

MIT
