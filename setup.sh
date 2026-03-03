#!/bin/bash
# setup.sh
SKILLS_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.claude"

if [ -e "$SKILLS_DIR" ] && [ ! -L "$SKILLS_DIR" ]; then
    echo "Backing up existing skills to ~/.claude/skills.bak"
    mv "$SKILLS_DIR" "${SKILLS_DIR}.bak"
fi

ln -sf "$SCRIPT_DIR/skills" "$SKILLS_DIR"
echo "Linked $SKILLS_DIR -> $SCRIPT_DIR"
