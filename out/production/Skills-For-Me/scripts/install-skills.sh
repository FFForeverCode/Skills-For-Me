#!/usr/bin/env bash
set -euo pipefail

# Install by copying skill directories (not symlink), useful for CI/distribution.
# Usage:
#   bash scripts/install-skills.sh [DEST]
# Default DEST:
#   $HOME/.codex/skills

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HOME/.codex/skills}"

mkdir -p "$DEST"

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  rm -rf "$target"
  cp -R "$src" "$target"
  echo "installed $name -> $target"
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -print0)

echo "Done. Installed skills to: $DEST"
