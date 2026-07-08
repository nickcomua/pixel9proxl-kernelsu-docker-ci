#!/usr/bin/env bash
set -euo pipefail

artifact_dir="${1:-artifacts}"
expected_release="${EXPECTED_KERNEL_RELEASE:-6.1.157-android14-11-gbd23337e42e7-ab14791245}"
forbidden_release="${FORBIDDEN_KERNEL_RELEASE:-6.1.124-android14-11-g8d713f9e8e7b-ab13202960}"
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
)

for symbol in "${required_config[@]}"; do
  if ! grep -qxF "${symbol}" "${config}"; then
    echo "required config missing from ${config}: ${symbol}" >&2
    exit 1
  fi
done

strings "${artifact_dir}/boot.img" >"${tmpdir}/boot.strings"
strings "${artifact_dir}/vendor_kernel_boot.img" >"${tmpdir}/vendor_kernel_boot.strings"
strings "${artifact_dir}/Image" >"${tmpdir}/Image.strings"
strings "${artifact_dir}/vendor_dlkm.img" >"${tmpdir}/vendor_dlkm.strings"
strings "${artifact_dir}/system_dlkm.img" >"${tmpdir}/system_dlkm.strings"

for image in boot.img vendor_kernel_boot.img vendor_dlkm.img system_dlkm.img; do
  strings_file="${tmpdir}/${image%.img}.strings"
  if ! grep -qF "${expected_release}" "${strings_file}"; then
    echo "${image} does not contain expected kernel release: ${expected_release}" >&2
    exit 1
  fi
  if grep -qF "${forbidden_release}" "${strings_file}"; then
    echo "${image} contains forbidden stale kernel release: ${forbidden_release}" >&2
    exit 1
  fi
done

{
  echo "Validated Pixel kernel artifacts"
  echo "artifact_dir=${artifact_dir}"
  echo "expected_release=${expected_release}"
  echo "forbidden_release=${forbidden_release}"
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
} >"${artifact_dir}/validation-report.txt"

cat "${artifact_dir}/validation-report.txt"
