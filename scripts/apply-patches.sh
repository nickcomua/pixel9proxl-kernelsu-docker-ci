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

python3 - <<'PY'
from pathlib import Path

build = Path("private/devices/google/caimito/BUILD.bazel")
text = build.read_text()
needle = '        "caimito_defconfig",\n'
if '        "docker_defconfig",\n' not in text:
    text = text.replace(needle, needle + '        "docker_defconfig",\n', 1)
build.write_text(text)

Path("private/devices/google/caimito/docker_defconfig").write_text("""\
CONFIG_PID_NS=y
CONFIG_USER_NS=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_BRIDGE_NETFILTER=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y

# These optional modules fail modpost in this GKI tree because they reference
# non-exported helpers. They are not needed for Docker/container support.
# CONFIG_PPTP is not set
# CONFIG_USB_RTL8150 is not set
# CONFIG_TIPC is not set
""")
PY

python3 "$repo_root/scripts/patch-common-kernels.py" build/kernel/kleaf/common_kernels.bzl

chmod +x aosp/scripts/config
for opt in PID_NS USER_NS CGROUP_PIDS CGROUP_DEVICE BRIDGE_NETFILTER NETFILTER_XT_MATCH_ADDRTYPE OVERLAY_FS VETH BRIDGE NET_NS; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -e "$opt"
done
for opt in BT BT_QCA BT_RFCOMM BT_BNEP BT_HIDP BT_HCIBTUSB BT_HCIBTSDIO BT_HCIUART BT_HCIVHCI; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -m "$opt"
done
for opt in PPTP USB_RTL8150 TIPC; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -d "$opt"
done
python3 - <<'PY'
from pathlib import Path
p = Path("aosp/arch/arm64/configs/gki_defconfig")
remove_prefixes = ()
remove_exact = {
    "# CONFIG_TIPC is not set",
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
bt_lines = [
    "CONFIG_BT=m",
    "CONFIG_BT_QCA=m",
    "CONFIG_BT_RFCOMM=m",
    "CONFIG_BT_BNEP=m",
    "CONFIG_BT_HIDP=m",
    "CONFIG_BT_HCIBTUSB=m",
    "CONFIG_BT_HCIBTSDIO=m",
    "CONFIG_BT_HCIUART=m",
    "CONFIG_BT_HCIVHCI=m",
]
lines = [line for line in lines if not line.startswith("CONFIG_BT")]
out = []
inserted = False
for line in lines:
    out.append(line)
    if line == "CONFIG_CAN=m" and not inserted:
        out.extend(bt_lines)
        inserted = True
if not inserted:
    out.extend(bt_lines)
p.write_text("\n".join(out) + "\n")
PY

python3 - <<'PY'
from pathlib import Path

p = Path("aosp/modules.bzl")
disabled_modules = {
    "drivers/net/ppp/pptp.ko",
    "drivers/net/usb/rtl8150.ko",
    "net/tipc/diag.ko",
    "net/tipc/tipc.ko",
}
lines = []
for line in p.read_text().splitlines():
    if any(f'"{module}"' in line for module in disabled_modules):
        continue
    lines.append(line)
p.write_text("\n".join(lines) + "\n")
PY
