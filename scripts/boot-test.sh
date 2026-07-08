#!/usr/bin/env bash
set -euo pipefail

artifact_dir="${1:-artifacts-local-forced-source}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
boot_timeout="${BOOT_TIMEOUT_SECONDS:-60}"

cd "$repo_root"

"$repo_root/scripts/validate-artifacts.sh" "$artifact_dir" >/dev/null

mapfile -t fastboot_devices < <(fastboot devices | awk 'NF {print $1}')
if [[ "${#fastboot_devices[@]}" -ne 1 ]]; then
  echo "expected exactly one fastboot device, found ${#fastboot_devices[@]}" >&2
  fastboot devices >&2 || true
  exit 2
fi

echo "Non-flashing boot test for ${fastboot_devices[0]}"
echo "Boot image: ${artifact_dir}/boot.img"
fastboot boot "${artifact_dir}/boot.img"

deadline=$((SECONDS + boot_timeout))
while (( SECONDS < deadline )); do
  if adb get-state >/dev/null 2>&1; then
    boot_completed="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$boot_completed" == "1" ]]; then
      break
    fi
  fi
  sleep 2
done

boot_completed="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
if [[ "$boot_completed" != "1" ]]; then
  echo "Android did not report sys.boot_completed=1 within ${boot_timeout}s" >&2
  echo "This script did not flash anything. Reboot to bootloader if the phone is stuck." >&2
  exit 3
fi

echo "Android booted"
adb shell uname -a
adb shell getprop ro.boot.slot_suffix
adb shell getprop init.svc.surfaceflinger
adb shell 'ls -ld /sys/fs/cgroup /sys/fs/cgroup/* 2>/dev/null | head -20' || true

if adb shell su -c id >/dev/null 2>&1; then
  echo "KernelSU root shell available"
  adb shell su -c 'set -e; zcat /proc/config.gz 2>/dev/null | grep -xE "CONFIG_(KSU|USER_NS|NET_NS|PID_NS|IPC_NS|UTS_NS|CGROUPS|CGROUP_DEVICE|OVERLAY_FS|VETH|BRIDGE|BRIDGE_NETFILTER)=y" || true'
  adb shell su -c 'set -e; ip link add docker_probe0 type veth peer name docker_probe1; ip link del docker_probe0; echo veth_probe=ok' || echo "veth_probe=failed"
  adb shell su -c 'set -e; base=/data/local/tmp/overlay-probe; rm -rf "$base"; mkdir -p "$base"/{lower,upper,work,merged}; echo ok > "$base/lower/file"; mount -t overlay overlay -o lowerdir="$base/lower",upperdir="$base/upper",workdir="$base/work" "$base/merged"; cat "$base/merged/file"; umount "$base/merged"; rm -rf "$base"; echo overlay_probe=ok' || echo "overlay_probe=failed"
else
  echo "KernelSU root shell not available through adb yet; skipping root-only Docker probes"
fi
