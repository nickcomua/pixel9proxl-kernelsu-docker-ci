#!/usr/bin/env bash
set -euo pipefail

root="${1:-work/caimito}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$root"

printf '%s\n' "-gbd23337e42e7-ab14791245" > aosp/.scmversion

(
  cd aosp
  if [ ! -d KernelSU-Next ]; then
    git clone https://github.com/KernelSU-Next/KernelSU-Next
  fi
  cd KernelSU-Next
  git fetch --tags --force
  git checkout v3.3.0
  cd ..
  sh KernelSU-Next/kernel/setup.sh v3.3.0
)

patch -p1 < "$repo_root/patches/aosp-build-tool-filegroups.patch"
patch -p1 < "$repo_root/patches/kleaf-common-kernels.patch"
patch -p1 < "$repo_root/patches/caimito-docker-defconfig.patch"
