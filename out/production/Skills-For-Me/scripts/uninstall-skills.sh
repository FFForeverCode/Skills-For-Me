#!/usr/bin/env bash
set -euo pipefail

# Uninstall skills from one or more target directories.
# Usage:
#   bash scripts/uninstall-skills.sh [DEST...]
#   bash scripts/uninstall-skills.sh --all-dests
#
# Defaults:
#   DEST = $HOME/.codex/skills
#
# Safety:
# - Only removes folders/symlinks matching skill names in this repo.
# - If target entry is a symlink, remove only when it points to this repo.

REPO="$(cd "$(dirname "$0")/.." && pwd)"

DEFAULT_DEST="$HOME/.codex/skills"
ALL_DESTS=(
  "$HOME/.codex/skills"
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
)

if [ "$#" -gt 0 ] && [ "$1" = "--all-dests" ]; then
  DESTS=("${ALL_DESTS[@]}")
else
  if [ "$#" -gt 0 ]; then
    DESTS=("$@")
  else
    DESTS=("$DEFAULT_DEST")
  fi
fi

names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -print0)

if [ "${#names[@]}" -eq 0 ]; then
  echo "No SKILL.md found under $REPO/skills"
  exit 1
fi

for dest in "${DESTS[@]}"; do
  if [ ! -d "$dest" ]; then
    echo "skip: $dest (not found)"
    continue
  fi

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$dest/$name"

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
      continue
    fi

    if [ -L "$target" ]; then
      link_target="$(readlink "$target" || true)"
      case "$link_target" in
        "$src"|"$REPO"/*)
          rm -f "$target"
          echo "unlinked $target"
          ;;
        *)
          echo "skip symlink: $target -> $link_target"
          ;;
      esac
      continue
    fi

    rm -rf "$target"
    echo "removed $target"
  done
done

echo "Done."
