#!/bin/bash
# axistia-flutter-skills installer
# One-shot script that installs all skills into ~/.copilot/skills/ (VS Code Copilot)
# and ~/.claude/skills/ (Claude Code), depending on which target is selected.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash -s -- --target=copilot
#   curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash -s -- --target=claude
#   curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash -s -- --target=both

set -e

REPO_URL="https://github.com/axisting/axistia-flutter-skills.git"
REPO_NAME="axistia-flutter-skills"
TARGET="both"  # default

for arg in "$@"; do
  case $arg in
    --target=*)
      TARGET="${arg#*=}"
      ;;
  esac
done

echo ""
echo "=================================================="
echo "  axistia-flutter-skills installer"
echo "=================================================="
echo ""

# Check for required tools
if ! command -v git &> /dev/null; then
  echo "ERROR: git is required but not installed."
  echo "Install git first: https://git-scm.com/downloads"
  exit 1
fi

# Create a temp directory for cloning
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "[1/3] Cloning repo..."
git clone --depth 1 "$REPO_URL" "$TMP_DIR/$REPO_NAME" 2>&1 | grep -v "^Cloning" || true

# Install for Claude Code
install_claude() {
  CLAUDE_DIR="$HOME/.claude/skills"
  mkdir -p "$CLAUDE_DIR"
  echo "[Claude] Installing skills to $CLAUDE_DIR"

  for skill_dir in "$TMP_DIR/$REPO_NAME/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    target_dir="$CLAUDE_DIR/$skill_name"
    if [ -d "$target_dir" ]; then
      echo "  [Claude] Updating $skill_name"
      rm -rf "$target_dir"
    else
      echo "  [Claude] Installing $skill_name"
    fi
    cp -r "$skill_dir" "$target_dir"
  done
}

# Install for VS Code Copilot
install_copilot() {
  COPILOT_DIR="$HOME/.copilot/skills"
  mkdir -p "$COPILOT_DIR"
  echo "[Copilot] Installing skills to $COPILOT_DIR"

  for skill_dir in "$TMP_DIR/$REPO_NAME/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    target_dir="$COPILOT_DIR/$skill_name"
    if [ -d "$target_dir" ]; then
      echo "  [Copilot] Updating $skill_name"
      rm -rf "$target_dir"
    else
      echo "  [Copilot] Installing $skill_name"
    fi
    cp -r "$skill_dir" "$target_dir"
  done
}

# Install AGENTS.md to a known location
install_agents() {
  AGENTS_DIR="$HOME/.axistia"
  mkdir -p "$AGENTS_DIR"
  cp "$TMP_DIR/$REPO_NAME/instructions/AGENTS.md" "$AGENTS_DIR/AGENTS.md"
  echo "[AGENTS] Reference AGENTS.md saved to $AGENTS_DIR/AGENTS.md"
  echo "         (Copy this to each Flutter project root manually)"
}

echo ""
echo "[2/3] Installing skills (target: $TARGET)..."
echo ""

case $TARGET in
  copilot)
    install_copilot
    ;;
  claude)
    install_claude
    ;;
  both|*)
    install_copilot
    install_claude
    ;;
esac

echo ""
echo "[3/3] Saving AGENTS.md reference..."
install_agents

echo ""
echo "=================================================="
echo "  Installation complete!"
echo "=================================================="
echo ""
echo "Installed skills:"
for skill_dir in "$TMP_DIR/$REPO_NAME/skills"/*/; do
  echo "  - $(basename "$skill_dir")"
done
echo ""
echo "Next steps:"
echo ""
echo "  1. Restart VS Code (and/or Claude Code) so it picks up the new skills."
echo ""
echo "  2. Copy AGENTS.md to your project root (per project):"
echo "       cp ~/.axistia/AGENTS.md /path/to/your/project/AGENTS.md"
echo ""
echo "  3. Test by opening a Flutter project and asking:"
echo "       'Detect this project's stack and tell me what skills you'd use.'"
echo ""
echo "  4. Update later by re-running this script."
echo ""
echo "Docs: https://github.com/axisting/axistia-flutter-skills"
echo ""
