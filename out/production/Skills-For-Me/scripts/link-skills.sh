#!/usr/bin/env bash
set -euo pipefail

# Dev helper: symlink each local skill folder into local agent skill homes.

REPO="$(cd "$(dirname "$0")/.." && pwd)"

DEFAULT_DESTS=(
  "$HOME/.codex/skills"
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
)

if [ "$#" -gt 0 ]; then
  DESTS=("$@")
else
  DESTS=("${DEFAULT_DESTS[@]}")
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
  mkdir -p "$dest"

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$dest/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      rm -rf "$target"
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src ($dest)"
  done
done
