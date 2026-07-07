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
  rm -rf drivers/kernelsu
  cp -a KernelSU-Next/kernel drivers/kernelsu
  cp -a KernelSU-Next/uapi drivers/kernelsu/uapi
)

patch -p1 < "$repo_root/patches/aosp-build-tool-filegroups.patch"
patch -p1 < "$repo_root/patches/caimito-docker-defconfig.patch"

python3 "$repo_root/scripts/patch-common-kernels.py" build/kernel/kleaf/common_kernels.bzl

chmod +x aosp/scripts/config
for opt in PID_NS USER_NS CGROUP_PIDS CGROUP_DEVICE BRIDGE_NETFILTER NETFILTER_XT_MATCH_ADDRTYPE OVERLAY_FS VETH BRIDGE NET_NS; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -e "$opt"
done
for opt in PPTP USB_RTL8150 BT TIPC; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -d "$opt"
done
python3 - <<'PY'
from pathlib import Path
p = Path("aosp/arch/arm64/configs/gki_defconfig")
remove_prefixes = ("CONFIG_BT_",)
remove_exact = {
    "# CONFIG_TIPC is not set",
    "# CONFIG_BT is not set",
    "# CONFIG_PPTP is not set",
    "# CONFIG_USB_RTL8150 is not set",
    "CONFIG_PID_NS=y",
    "CONFIG_NET_NS=y",
    "CONFIG_KSU=y",
}
lines = []
for line in p.read_text().splitlines():
    if line in remove_exact:
        continue
    if any(line.startswith(prefix) for prefix in remove_prefixes):
        continue
    lines.append(line)
p.write_text("\n".join(lines) + "\n")
PY
