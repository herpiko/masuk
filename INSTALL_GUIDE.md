# Masuk Installation & Setup Guide

This guide will walk you through installing masuk and setting up shell autocomplete.

## Quick Start (One Command)

The fastest way to get started:

```bash
make install-all
```

This will:
1. Build and install the `masuk` binary to `~/.cargo/bin`
2. Auto-detect your shell (bash/zsh/fish)
3. Install the appropriate completion script
4. Update your shell configuration

Then reload your shell:
```bash
source ~/.bashrc    # for bash
source ~/.zshrc     # for zsh
# or just restart your terminal
```

## Step-by-Step Installation

### 1. Build the Project

```bash
cargo build --release
```

The binary will be at `target/release/masuk`.

### 2. Install the Binary

Choose one method:

**Option A: Install via cargo (Recommended)**
```bash
cargo install --path .
```
This installs to `~/.cargo/bin/masuk` (ensure `~/.cargo/bin` is in your PATH)

**Option B: Copy to system PATH**
```bash
sudo cp target/release/masuk /usr/local/bin/
```

**Option C: Use from project directory**
```bash
# Add an alias to your shell config
alias masuk='/path/to/masuk/target/release/masuk'
```

### 3. Verify Installation

```bash
masuk --help
```

You should see the help message.

### 4. Install Shell Completion (Automatic)

Run the installer script:

```bash
./install-completion.sh
```

Or use make:
```bash
make install-completion
```

**What the script does:**
- Detects your current shell (bash, zsh, fish, or powershell)
- Finds your shell config file (`~/.bashrc`, `~/.zshrc`, etc.)
- Adds the completion source command
- Checks if completion is already installed to avoid duplicates

**Manual shell selection:**
```bash
./install-completion.sh bash
./install-completion.sh zsh
./install-completion.sh fish
```

### 5. Activate Completion

**For bash:**
```bash
source ~/.bashrc
```

**For zsh:**
```bash
source ~/.zshrc
```

**For fish:**
```bash
# Just restart fish or open a new terminal
```

Or simply restart your terminal.

## Testing Completion

1. Add a test profile:
```bash
masuk add chola -h 192.168.1.100 -p 2222
masuk add chocolate -h 192.168.1.101 -u admin
```

2. Test autocomplete:
```bash
masuk ch<TAB>
```

You should see:
```
chola  chocolate
```

3. Test with more specific prefix:
```bash
masuk chol<TAB>
```

Should autocomplete to:
```
masuk chola
```

## Troubleshooting

### "masuk: command not found"

**Solution:** Ensure the binary is in your PATH

For cargo install:
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.cargo/bin:$PATH"
```

Then reload your shell.

### Autocomplete not working

**Check 1:** Verify completion is installed
```bash
grep -i "masuk-completion" ~/.bashrc  # for bash
grep -i "masuk-completion" ~/.zshrc   # for zsh
```

**Check 2:** Verify completion script exists
```bash
ls -la /path/to/masuk/completions/
```

**Check 3:** Test completion manually
```bash
# For bash
source /path/to/masuk/completions/masuk-completion.bash
masuk ch<TAB>
```

**Check 4:** Reload shell config
```bash
source ~/.bashrc   # or ~/.zshrc
```

### Python error in completion

The bash completion script uses Python to parse JSON. If you don't have Python 3:

```bash
# Install Python 3 (Ubuntu/Debian)
sudo apt install python3

# Or use the fallback grep method (already in script)
```

The script has a fallback that uses `grep` if Python is not available.

## Uninstalling Completion

To remove the completion:

1. Open your shell config file:
```bash
nano ~/.bashrc    # for bash
nano ~/.zshrc     # for zsh
```

2. Remove the masuk completion section:
```bash
# Remove these lines:
# Masuk shell completion
if [ -f "/path/to/masuk-completion.bash" ]; then
    source "/path/to/masuk-completion.bash"
fi
```

3. Reload your shell:
```bash
source ~/.bashrc
```

## Advanced: System-wide Installation

To install completion system-wide for all users:

**Bash:**
```bash
sudo cp completions/masuk-completion.bash /etc/bash_completion.d/masuk
```

**Zsh:**
```bash
sudo cp completions/masuk-completion.zsh /usr/local/share/zsh/site-functions/_masuk
```

Then all users will have completion without individual setup.

## What Gets Installed

### Binary Location
- Via `cargo install`: `~/.cargo/bin/masuk`
- Via manual copy: `/usr/local/bin/masuk`

### Completion Scripts
- Bash: Added to `~/.bashrc`
- Zsh: Added to `~/.zshrc`
- Fish: `~/.config/fish/completions/masuk.fish`

### Configuration
- Config file: `~/.config/masuk/config.json`
- Automatically created on first use

## Next Steps

After installation:

1. Add your first profile:
```bash
masuk add myserver -h example.com
```

2. Connect to it:
```bash
masuk myserver
```

3. Try the autocomplete:
```bash
masuk my<TAB>
```

Enjoy fast SSH connections! 🚀
