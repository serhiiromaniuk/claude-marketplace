# Setup Guide

Complete setup instructions for `glab` CLI and helper functions.

## Prerequisites

### Install glab

**macOS:**
```bash
brew install glab
```

**Linux (Debian/Ubuntu):**
```bash
# Add repository
curl -fsSL https://raw.githubusercontent.com/profclems/glab/trunk/scripts/install.sh | sh
```

**Linux (using snap):**
```bash
sudo snap install glab
```

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

### One-Time Setup

**For Bash:**
```bash
echo 'source ~/.claude/skills/glab/scripts/glab-helpers.sh' >> ~/.bashrc
source ~/.bashrc
```

**For Zsh:**
```bash
echo 'source ~/.claude/skills/glab/scripts/glab-helpers.sh' >> ~/.zshrc
source ~/.zshrc
```

**For Fish:**
```fish
# Fish doesn't directly source bash scripts
# Create a wrapper or use bass plugin
# https://github.com/edc/bass
bass source ~/.claude/skills/glab/scripts/glab-helpers.sh
```

### Verify Helpers are Loaded

```bash
# Should list all available commands
gl-help

# Test a function
glcis  # Should show pipeline status (or error if not in git repo)
```

### Manual Sourcing (Per Session)

If you don't want persistent loading:

```bash
source ~/.claude/skills/glab/scripts/glab-helpers.sh
```

### In Scripts

```bash
#!/bin/bash
# At the top of your script
source ~/.claude/skills/glab/scripts/glab-helpers.sh

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

# Load glab helpers
source ~/.claude/skills/glab/scripts/glab-helpers.sh
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

### Permission denied on helpers script

```bash
chmod +x ~/.claude/skills/glab/scripts/glab-helpers.sh
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
# Remove from shell config
# Edit ~/.bashrc or ~/.zshrc and remove the source line

# Or comment it out
sed -i 's/^source.*glab-helpers.sh/#&/' ~/.bashrc
```
