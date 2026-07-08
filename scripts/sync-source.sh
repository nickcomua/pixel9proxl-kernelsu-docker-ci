#!/usr/bin/env bash
set -euo pipefail

dest="${1:-work/caimito}"
manifest_url="https://android.googlesource.com/kernel/manifest"
branch="android-gs-caimito-6.1-android16"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pinned_manifest="${repo_root}/manifests/caimito-pinned.xml"

mkdir -p "$dest"

if ! command -v repo >/dev/null 2>&1; then
  mkdir -p "$HOME/bin"
  curl -fsSL "https://storage.googleapis.com/git-repo-downloads/repo" -o "$HOME/bin/repo"
  chmod +x "$HOME/bin/repo"
  export PATH="$HOME/bin:$PATH"
fi

cd "$dest"
if [[ "${USE_MOVING_MANIFEST:-0}" == "1" ]]; then
  repo init -u "$manifest_url" -b "$branch"
else
  repo init -u "file://${repo_root}" -m "${pinned_manifest#${repo_root}/}"
fi
repo sync -c --no-tags --no-clone-bundle -j"$(nproc)"
