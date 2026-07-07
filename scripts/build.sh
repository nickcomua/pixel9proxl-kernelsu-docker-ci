#!/usr/bin/env bash
set -euo pipefail

root="${1:-work/caimito}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$root"

mkdir -p out/bazel-ci

tools/bazel --batch \
  --output_user_root="$PWD/out/bazel-ci" \
  run \
  --config=stamp \
  --config=caimito \
  --jobs="${BAZEL_JOBS:-2}" \
  --local_cpu_resources="${BAZEL_CPUS:-2}" \
  --kernel_package=@//aosp \
  //private/devices/google/caimito:zumapro_caimito_dist

mkdir -p "$repo_root/artifacts"
cp -f out/caimito/dist/boot.img "$repo_root/artifacts/"
cp -f out/caimito/dist/vendor_kernel_boot.img "$repo_root/artifacts/"
cp -f out/caimito/dist/dtbo.img "$repo_root/artifacts/"
cp -f out/caimito/dist/vendor_dlkm.img "$repo_root/artifacts/"
cp -f out/caimito/dist/system_dlkm.img "$repo_root/artifacts/"
cp -f out/caimito/dist/Image "$repo_root/artifacts/"
cp -f out/caimito/dist/.config "$repo_root/artifacts/"

strings "$repo_root/artifacts/vendor_kernel_boot.img" | grep '6.1.157-android14-11-gbd23337e42e7-ab14791245'
grep -q '^CONFIG_KSU=y$' "$repo_root/artifacts/.config"
grep -q '^CONFIG_USER_NS=y$' "$repo_root/artifacts/.config"
grep -q '^CONFIG_CGROUP_DEVICE=y$' "$repo_root/artifacts/.config"
grep -q '^CONFIG_OVERLAY_FS=y$' "$repo_root/artifacts/.config"
