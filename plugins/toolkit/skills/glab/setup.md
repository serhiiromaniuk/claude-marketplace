# Setup Guide

Complete setup instructions for `glab` CLI and helper functions.

## Prerequisites

### Install glab

`glab` is maintained by GitLab at [gitlab-org/cli](https://gitlab.com/gitlab-org/cli).
The skill and its helpers need **glab 1.54 or newer** (`glab ci cancel pipeline|job` arrived in
1.53, and `glab ci get --pipeline-id` stopped requiring a branch in 1.54). Check with `glab --version`.

**macOS / Linux (Homebrew):**
```bash
brew install glab
```

**Linux (Debian/Ubuntu, Fedora/RHEL):**
Download the `.deb` or `.rpm` for your architecture from the
[official releases page](https://gitlab.com/gitlab-org/cli/-/releases), then:
```bash
sudo apt install ./glab_*_linux_amd64.deb     # Debian/Ubuntu
sudo dnf install ./glab_*_linux_amd64.rpm     # Fedora/RHEL
```

**Linux (distribution packages):**
```bash
sudo pacman -S glab      # Arch
sudo apk add glab        # Alpine
sudo snap install glab   # Snap
```
Distribution packages can lag behind upstream — confirm `glab --version` is 1.54 or newer.

**From source:**
```bash
go install gitlab.com/gitlab-org/cli/cmd/glab@latest
```

### Install jq (required for helpers)

**macOS:**
```bash
brew install jq
```

**Linux:**
```bash
sudo apt install jq      # Debian/Ubuntu
sudo dnf install jq      # Fedora/RHEL
```

### Verify Installation

```bash
glab --version
jq --version
```

## Authentication

### GitLab.com

```bash
glab auth login
```

Follow the prompts to authenticate via browser or token.

### Self-Hosted GitLab

```bash
# Set hostname
export GITLAB_HOST=gitlab.example.com

# Authenticate
glab auth login --hostname gitlab.example.com
```

### Using Personal Access Token

1. Go to GitLab → Settings → Access Tokens
2. Create token with scopes: `api`, `read_repository`, `write_repository`
3. Authenticate:

```bash
# Interactive
glab auth login

# Or via environment variable
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx
```

### Verify Authentication

```bash
glab auth status
glab api user | jq '{username, name}'
```

## Shell Helper Functions

The helper functions provide convenient aliases and watch functions for common operations.
They live in `scripts/glab-helpers.sh` inside this skill. Inside Claude Code the skill sources
them itself; this section is for using them in your own terminal.

### Where the Script Lives

When the `toolkit` plugin is installed, Claude Code keeps a copy per plugin version:

```
${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/cache/serhii/toolkit/<version>/skills/glab/scripts/glab-helpers.sh
```

The `<version>` directory changes on every plugin update and old versions may be removed, so
don't paste that full path into your shell config. Either look the newest copy up at shell
start-up (option A) or source a clone of the repository (option B).

### One-Time Setup

**Option A — the installed plugin (Bash or Zsh).** Add to `~/.bashrc` or `~/.zshrc`:
```bash
# Load glab helpers from the newest installed toolkit plugin, if present
glab_helpers=$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/serhii/toolkit" \
    -path '*/skills/glab/scripts/glab-helpers.sh' 2>/dev/null | sort -V | tail -n 1)
[ -n "$glab_helpers" ] && source "$glab_helpers"
unset glab_helpers
```

**Option B — a clone of the repository.** Clone once, then add one line to `~/.bashrc` or `~/.zshrc`:
```bash
git clone https://github.com/serhiiromaniuk/claude-marketplace.git ~/src/claude-marketplace

# in ~/.bashrc or ~/.zshrc
source ~/src/claude-marketplace/plugins/toolkit/skills/glab/scripts/glab-helpers.sh
```
Run `git -C ~/src/claude-marketplace pull` to update.

Then reload your shell (`exec "$SHELL"`) or source the file directly.

**For Fish:**
```fish
# Fish doesn't directly source bash scripts
# Create a wrapper or use bass plugin
# https://github.com/edc/bass
bass source ~/src/claude-marketplace/plugins/toolkit/skills/glab/scripts/glab-helpers.sh
```

### Verify Helpers are Loaded

```bash
# Should list all available commands
gl-help

# Test a function
glcis  # Should show pipeline status (or error if not in git repo)
```

### Manual Sourcing (Per Session)

If you don't want persistent loading, source the newest installed copy (or your clone) once:

```bash
source "$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/serhii/toolkit" \
    -path '*/skills/glab/scripts/glab-helpers.sh' 2>/dev/null | sort -V | tail -n 1)"
```

### In Scripts

```bash
#!/bin/bash
# At the top of your script: source your clone (or set GLAB_HELPERS to the path)
source "${GLAB_HELPERS:-$HOME/src/claude-marketplace/plugins/toolkit/skills/glab/scripts/glab-helpers.sh}"

# Now you can use helpers
gl-wait 30 && echo "Pipeline passed!"
```

## Environment Variables

Add these to your shell config for persistence:

```bash
# ~/.bashrc or ~/.zshrc

# Required for self-hosted GitLab
export GITLAB_HOST=gitlab.example.com

# Optional: Set token directly (less secure)
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx

# Optional: Default editor for MR descriptions
export EDITOR=vim

# Load glab helpers: see "Shell Helper Functions" above
```

## Shell Completions

### Bash

```bash
# Generate completions
glab completion bash > /etc/bash_completion.d/glab

# Or for user-only
glab completion bash > ~/.local/share/bash-completion/completions/glab
```

### Zsh

```bash
# Add to ~/.zshrc
echo 'eval "$(glab completion zsh)"' >> ~/.zshrc

# Or generate file
glab completion zsh > "${fpath[1]}/_glab"
```

### Fish

```fish
glab completion fish > ~/.config/fish/completions/glab.fish
```

## Quick Test

After setup, verify everything works:

```bash
# 1. Check glab
glab --version

# 2. Check auth
glab auth status

# 3. Check helpers
gl-help

# 4. Test in a GitLab repo
cd /path/to/your/gitlab/project
glcis  # Should show pipeline status
```

## Troubleshooting Setup

### Helpers not found after restart

Ensure the source line is in the correct file:
```bash
# Check which shell you're using
echo $SHELL

# Bash: ~/.bashrc
# Zsh: ~/.zshrc
# Check the file contains the source line
grep glab-helpers ~/.bashrc ~/.zshrc 2>/dev/null
```

### Helpers file not found

The script is sourced, so it needs no execute permission. Check that the path resolves:
```bash
# Installed plugin copies (newest last)
find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/serhii/toolkit" \
    -path '*/skills/glab/scripts/glab-helpers.sh' 2>/dev/null | sort -V

# No output: the toolkit plugin is not installed for this config dir — use a clone (option B)
```

### jq not found

```bash
# Verify jq is installed
which jq

# Install if missing
sudo apt install jq  # Linux
brew install jq      # macOS
```

## Uninstall

To remove the helpers:

```bash
# Remove from shell config:
# edit ~/.bashrc or ~/.zshrc and delete the lines added in "One-Time Setup"
grep -n glab-helpers ~/.bashrc ~/.zshrc 2>/dev/null   # find them
```
