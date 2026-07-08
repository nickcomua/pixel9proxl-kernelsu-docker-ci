#!/usr/bin/env bash
set -euo pipefail

artifact_dir="${1:-artifacts}"
expected_release="${EXPECTED_KERNEL_RELEASE:-6.1.157-android14-11-gbd23337e42e7-ab14791245}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

required_files=(
  boot.img
  vendor_kernel_boot.img
  dtbo.img
  vendor_dlkm.img
  system_dlkm.img
  Image
  .config
)

for file in "${required_files[@]}"; do
  path="${artifact_dir}/${file}"
  if [[ ! -s "${path}" ]]; then
    echo "missing or empty artifact: ${path}" >&2
    exit 1
  fi
done

config="${artifact_dir}/.config"
required_config=(
  CONFIG_KSU=y
  CONFIG_PID_NS=y
  CONFIG_USER_NS=y
  CONFIG_NET_NS=y
  CONFIG_CGROUP_PIDS=y
  CONFIG_CGROUP_DEVICE=y
  CONFIG_OVERLAY_FS=y
  CONFIG_VETH=y
  CONFIG_BRIDGE=y
  CONFIG_BRIDGE_NETFILTER=y
  CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
  CONFIG_BT_HCIUART_BCM=y
  CONFIG_BT_HCIUART_QCA=y
  CONFIG_TIPC=m
)

for symbol in "${required_config[@]}"; do
  if ! grep -qxF "${symbol}" "${config}"; then
    echo "required config missing from ${config}: ${symbol}" >&2
    exit 1
  fi
done

strings "${artifact_dir}/vendor_kernel_boot.img" >"${tmpdir}/vendor_kernel_boot.strings"
strings "${artifact_dir}/Image" >"${tmpdir}/Image.strings"
strings "${artifact_dir}/vendor_dlkm.img" >"${tmpdir}/vendor_dlkm.strings"
strings "${artifact_dir}/system_dlkm.img" >"${tmpdir}/system_dlkm.strings"

if ! grep -qF "${expected_release}" "${tmpdir}/vendor_kernel_boot.strings"; then
  echo "vendor_kernel_boot.img does not contain expected kernel release: ${expected_release}" >&2
  exit 1
fi

if ! grep -qF "KernelSU" "${tmpdir}/Image.strings"; then
  echo "Image does not contain KernelSU marker strings" >&2
  exit 1
fi

for image in vendor_dlkm.img system_dlkm.img; do
  if ! grep -qF "${expected_release}" "${tmpdir}/${image%.img}.strings"; then
    echo "${image} does not contain module vermagic for ${expected_release}" >&2
    exit 1
  fi
done

{
  echo "Validated Pixel kernel artifacts"
  echo "artifact_dir=${artifact_dir}"
  echo "expected_release=${expected_release}"
  echo
  echo "files:"
  for file in "${required_files[@]}"; do
    wc -c "${artifact_dir}/${file}"
  done
  echo
  echo "required config:"
  for symbol in "${required_config[@]}"; do
    grep -xF "${symbol}" "${config}"
  done
  echo
  echo "kernel release evidence:"
  grep -m 3 -F "${expected_release}" "${tmpdir}/vendor_kernel_boot.strings"
  grep -m 3 -F "${expected_release}" "${tmpdir}/vendor_dlkm.strings" || true
  grep -m 3 -F "${expected_release}" "${tmpdir}/system_dlkm.strings" || true
  echo
  echo "KernelSU evidence:"
  grep -m 5 -F "KernelSU" "${tmpdir}/Image.strings"
} >"${artifact_dir}/validation-report.txt"

cat "${artifact_dir}/validation-report.txt"
