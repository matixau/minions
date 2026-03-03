#!/usr/bin/env bash
# install.sh — Symlink matix-minions skills to ~/.claude/skills/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
MANIFESTS_DIR="$HOME/.claude/minions/manifests"

echo "Installing matix-minions..."

# Create target directories
mkdir -p "$SKILLS_DIR"
mkdir -p "$MANIFESTS_DIR"

# Symlink each skill
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_DIR/$skill_name"

    if [[ -L "$target" ]]; then
        rm "$target"
    elif [[ -d "$target" ]]; then
        echo "WARNING: $target exists and is not a symlink. Skipping."
        continue
    fi

    ln -s "$skill_dir" "$target"
    echo "  Linked: $skill_name → $target"
done

echo ""
echo "Installed skills:"
ls -la "$SKILLS_DIR" | grep -E "^l"
echo ""
echo "Manifest directory: $MANIFESTS_DIR"
echo ""
echo "Done. Restart Claude Code to pick up new skills."
echo "Type / in Claude Code to verify: plan-feature, decompose, dispatch-minions, retry-minion, review-minions"
