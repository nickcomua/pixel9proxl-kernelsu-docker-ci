#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = 'name = "common_kernel_sources"'
if "resolve_btfids_sources" in text:
    raise SystemExit(0)
start = text.index(needle)
glob_end = text.index("\n        ),", start)
old = "\n        ),"
new = """
        ) + ([
            "@//aosp/tools/bpf/resolve_btfids:resolve_btfids_sources",
            "@//aosp/tools/build:build_tool_sources",
            "@//aosp/tools/lib/bpf:libbpf_sources",
            "@//aosp/tools/lib/subcmd:libsubcmd_sources",
        ] if native.package_name() == "aosp" else []),"""
text = text[:glob_end] + new + text[glob_end + len(old):]
path.write_text(text)
