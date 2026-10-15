#!/usr/bin/env bash
# Clones the upstream sources into external/ at the pinned commits and applies patches/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/config/versions.env"

fetch() { # dir repo commit [branch]
  local dir="$1" repo="$2" commit="$3" branch="${4:-}"
  if [ ! -d "$dir/.git" ]; then
    echo ">> Cloning $repo"
    git clone ${branch:+-b "$branch"} --filter=blob:none "$repo" "$dir"
  fi
  git -C "$dir" fetch --quiet origin "$commit" 2>/dev/null || git -C "$dir" fetch --quiet origin
  if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ] && [ "${FORCE:-0}" != 1 ]; then
    echo "!! $dir has local changes. Save them to patches/ (see patches/README.md) or use FORCE=1." >&2
    exit 1
  fi
  git -C "$dir" checkout --quiet --force "$commit"
  git -C "$dir" clean -fdxq
  echo "   $dir @ ${commit:0:10}"
}

mkdir -p "$ROOT/external"
fetch "$ROOT/external/zelda3-ds"       "$ZELDA3_DS_REPO"       "$ZELDA3_DS_COMMIT" "$ZELDA3_DS_BRANCH"
fetch "$ROOT/external/zelda3-upstream" "$ZELDA3_UPSTREAM_REPO" "$ZELDA3_UPSTREAM_COMMIT"

shopt -s nullglob
patches=("$ROOT"/patches/*.patch)
if [ ${#patches[@]} -gt 0 ]; then
  echo ">> Applying ${#patches[@]} patch(es) to external/zelda3-ds"
  git -C "$ROOT/external/zelda3-ds" -c user.name=zelda3-ds -c user.email=zelda3-ds@localhost \
    am --quiet --keep-cr --3way "${patches[@]}"
fi
echo ">> Sources ready."
