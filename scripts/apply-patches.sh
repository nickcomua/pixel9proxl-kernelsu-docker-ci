#!/usr/bin/env bash
set -euo pipefail

root="${1:-work/caimito}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$root"

printf '%s\n' "-gbd23337e42e7-ab14791245" > aosp/.scmversion

if [[ "${ENABLE_KSU:-1}" == "1" ]]; then
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
fi

python3 - <<'PY'
from pathlib import Path

filegroups = {
    "aosp/tools/bpf/resolve_btfids": ("resolve_btfids_sources", True),
    "aosp/tools/build": ("build_tool_sources", False),
    "aosp/tools/lib/bpf": ("libbpf_sources", True),
    "aosp/tools/lib/subcmd": ("libsubcmd_sources", True),
}

for directory, (name, exclude_archives) in filegroups.items():
    excludes = [
        "BUILD",
        "BUILD.bazel",
        "**/*.cmd",
        "**/*.d",
        "**/*.o",
    ]
    if exclude_archives:
        excludes.append("**/*.a")
    content = (
        'package(default_visibility = ["//visibility:public"])\n\n'
        "filegroup(\n"
        f'    name = "{name}",\n'
        "    srcs = glob(\n"
        '        ["**"],\n'
        "        exclude = [\n"
        + "".join(f'            "{item}",\n' for item in excludes)
        + "        ],\n"
        "    ),\n"
        ")\n"
    )
    path = Path(directory)
    path.joinpath("BUILD").write_text(content)
    path.joinpath("BUILD.bazel").write_text(content)

PY

python3 "$repo_root/scripts/patch-common-kernels.py" build/kernel/kleaf/common_kernels.bzl

python3 - <<'PY'
from pathlib import Path

p = Path("build/kernel/kleaf/impl/stamp.bzl")
text = p.read_text()
old = '        stable_scmversion_cmd = _get_status_at_path(ctx, "STABLE_SCMVERSIONS", \'"${KERNEL_DIR}"\')'
new = '        stable_scmversion_cmd = "echo \'-gbd23337e42e7-ab14791245\'"'
if new not in text:
    text, count = text.replace(old, new, 1), text.count(old)
    if count != 1:
        raise SystemExit("stamp.bzl stable_scmversion_cmd shape not found")
p.write_text(text)
PY

python3 - <<'PY'
from pathlib import Path
import re

p = Path("aosp/scripts/setlocalversion")
text = p.read_text()
replacement = 'scm_version()\n{\n\treturn\n'
if 'scm_version()\n{\n\treturn\n' not in text:
    text, count = re.subn(r"scm_version\(\)\n\s*\{", replacement, text, count=1)
    if count != 1:
        raise SystemExit("setlocalversion scm_version() shape not found")
p.write_text(text)
PY

chmod +x aosp/scripts/config
for opt in USER_NS CGROUP_DEVICE CGROUP_PIDS BRIDGE_NETFILTER NETFILTER_XT_MATCH_ADDRTYPE; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -e "$opt"
done
for opt in TIPC TIPC_DIAG; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -m "$opt"
done
for opt in BT BT_BCM BT_RFCOMM BT_HIDP BT_HCIBTSDIO BT_HCIUART; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -m "$opt"
done
for opt in BT_HCIUART_BCM BT_HCIUART_QCA TIPC_MEDIA_UDP TIPC_CRYPTO; do
  aosp/scripts/config --file aosp/arch/arm64/configs/gki_defconfig -e "$opt"
done
for opt in BT_BNEP BT_HCIBTUSB BT_HCIVHCI PPTP USB_RTL8150; do
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
    "# CONFIG_BT_BNEP is not set",
    "# CONFIG_BT_HCIBTUSB is not set",
    "# CONFIG_BT_HCIVHCI is not set",
    "CONFIG_USER_NS=y",
    "CONFIG_CGROUP_DEVICE=y",
    "CONFIG_CGROUP_PIDS=y",
    "CONFIG_BRIDGE_NETFILTER=y",
    "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y",
    "CONFIG_TIPC=m",
    "CONFIG_BT_BCM=m",
    "CONFIG_BT_QCA=m",
    "CONFIG_TIPC_DIAG=m",
    "CONFIG_TIPC_MEDIA_UDP=y",
    "CONFIG_TIPC_CRYPTO=y",
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
    "CONFIG_BT_RFCOMM=m",
    "CONFIG_BT_HIDP=m",
    "CONFIG_BT_HCIBTSDIO=m",
    "CONFIG_BT_HCIUART=m",
    "CONFIG_BT_HCIUART_BCM=y",
    "CONFIG_BT_HCIUART_QCA=y",
]
lines = [line for line in lines if not line.startswith("CONFIG_BT")]
out = []
inserted = False
for line in lines:
    out.append(line)
    if line == "CONFIG_UCLAMP_TASK_GROUP=y":
        out.append("CONFIG_CGROUP_PIDS=y")
    if line == "CONFIG_CPUSETS=y":
        out.append("CONFIG_CGROUP_DEVICE=y")
    if line == "CONFIG_NAMESPACES=y":
        out.append("CONFIG_USER_NS=y")
    if line == "CONFIG_NETFILTER=y":
        out.append("CONFIG_BRIDGE_NETFILTER=y")
    if line == "CONFIG_NETFILTER_XT_TARGET_TCPMSS=y":
        out.append("CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y")
    if line == "CONFIG_IP6_NF_RAW=y":
        out.append("CONFIG_TIPC=m")
    if line == "CONFIG_CAN=m" and not inserted:
        out.extend(bt_lines)
        inserted = True
if not inserted:
    out.extend(bt_lines)
if __import__("os").environ.get("ENABLE_KSU", "1") == "1":
    out.append("CONFIG_KSU=y")
p.write_text("\n".join(out) + "\n")
PY

python3 - <<'PY'
from pathlib import Path

p = Path("aosp/modules.bzl")
disabled_modules = {
    "drivers/net/ppp/pptp.ko",
    "drivers/net/usb/rtl8150.ko",
}
lines = []
for line in p.read_text().splitlines():
    if any(f'"{module}"' in line for module in disabled_modules):
        continue
    lines.append(line)
p.write_text("\n".join(lines) + "\n")
PY
