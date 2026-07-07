#!/usr/bin/env bash
set -euo pipefail

root="${1:-${KERNEL_WORKDIR:-work/caimito}}"

if [[ "${USE_NIX_BAZEL:-0}" == "1" ]]; then
  if [[ -z "${KLEAF_NIX_BAZEL:-}" || -z "${KLEAF_NIX_JDK:-}" ]]; then
    echo "USE_NIX_BAZEL=1 requires KLEAF_NIX_BAZEL and KLEAF_NIX_JDK" >&2
    exit 2
  fi

  python3 - "$root" <<'PY'
from pathlib import Path
import os
import sys

root = Path(sys.argv[1])
tools_bazel = root / "tools/bazel"
bazel_py = root / "build/kernel/kleaf/bazel.py"
workspace_status = root / "build/kernel/kleaf/workspace_status.sh"
workspace_bzl = root / "build/kernel/kleaf/workspace.bzl"

tools_text = tools_bazel.read_text()
tools_text = tools_text.replace(
    'exec "$ROOT_DIR"/prebuilts/build-tools/path/linux-x86/python3 $(dirname $(readlink -f "$0"))/bazel.py "$ROOT_DIR" "$@"',
    'exec python3 $(dirname $(readlink -f "$0"))/bazel.py "$ROOT_DIR" "$@"',
)
tools_bazel.write_text(tools_text)

bazel_text = bazel_py.read_text()
bazel_text = bazel_text.replace(
    'self.bazel_path = f"{self.root_dir}/{_BAZEL_REL_PATH}"',
    'self.bazel_path = self.env.get("KLEAF_NIX_BAZEL", f"{self.root_dir}/{_BAZEL_REL_PATH}")',
)
bazel_text = bazel_text.replace(
    'bazel_jdk_path = f"{self.root_dir}/{_BAZEL_JDK_REL_PATH}"',
    'bazel_jdk_path = self.env.get("KLEAF_NIX_JDK", f"{self.root_dir}/{_BAZEL_JDK_REL_PATH}")',
)
bazel_py.write_text(bazel_text)

status_text = workspace_status.read_text()
status_text = status_text.replace(
    "prebuilts/build-tools/path/linux-x86/python3 build/kernel/kleaf/workspace_status_stamp.py",
    "python3 build/kernel/kleaf/workspace_status_stamp.py",
)
workspace_status.write_text(status_text)

workspace_text = workspace_bzl.read_text()
workspace_text = workspace_text.replace(
    'path = "prebuilts/jdk/jdk11/linux-x86",\n        build_file = "build/kernel/kleaf/jdk11.BUILD",',
    f'path = "{Path(os.environ["KLEAF_NIX_JDK"])}",\n        build_file = Label("//build/kernel/kleaf:jdk11.BUILD"),',
)
workspace_bzl.write_text(workspace_text)
PY
fi

if [[ "${SKIP_SYNC:-0}" != "1" ]]; then
  ./scripts/sync-source.sh "$root"
fi

if [[ "${SKIP_PATCHES:-0}" != "1" ]]; then
  ./scripts/apply-patches.sh "$root"
fi

./scripts/build.sh "$root"
