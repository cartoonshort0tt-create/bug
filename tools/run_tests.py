#!/usr/bin/env python3
"""Run the shared-module tests with the standalone `luau` CLI (no Studio needed).

Roblox modules require each other through instances (`require(script.Parent.X)`),
which plain Luau doesn't have. This script bundles every module under src/shared
into one chunk with a tiny fake instance tree, appends tests/shared_tests.luau,
and runs it.

    python3 tools/run_tests.py            # uses `luau` from PATH
    LUAU=/path/to/luau python3 tools/run_tests.py

Get the CLI from https://github.com/luau-lang/luau/releases (luau-ubuntu.zip,
luau-macos.zip or luau-windows.zip).
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
TESTS = ROOT / "tests" / "shared_tests.luau"

# Modules that touch Roblox services; tests never require them.
SKIP = {"Remotes"}

PRELUDE = """
local __loaders = {}
local __cache = {}
local function __node(path, parent)
\tlocal node = { __path = path, __kids = {}, Parent = parent, Name = string.match(path, "[^/]+$") }
\treturn setmetatable(node, {
\t\t__index = function(_, key)
\t\t\terror("no child '" .. tostring(key) .. "' in " .. path, 2)
\t\tend,
\t})
end
local function __add(parent, name, path)
\tlocal node = __node(path, parent)
\trawget(parent, "__kids")[name] = node
\trawset(parent, name, node)
\treturn node
end
local function require(node)
\tlocal path = rawget(node, "__path")
\tlocal cached = __cache[path]
\tif cached ~= nil then
\t\treturn cached
\tend
\tlocal loader = __loaders[path]
\tassert(loader, "not a module: " .. path)
\tlocal result = loader(node)
\t__cache[path] = result
\treturn result
end
local Shared = __node("shared", nil)
"""


def main() -> int:
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        print("luau CLI not found: put it on PATH or set LUAU=/path/to/luau", file=sys.stderr)
        return 2

    parts = [PRELUDE]
    folders = {SHARED: "Shared"}
    for path in sorted(SHARED.rglob("*")):
        rel = path.relative_to(SHARED).with_suffix("")
        var = "__n_" + re.sub(r"\W", "_", str(rel))
        parent_var = folders[path.parent]
        if path.is_dir():
            folders[path] = var
            parts.append(f'local {var} = __add({parent_var}, "{path.name}", "shared/{rel.as_posix()}")')
        elif path.suffix == ".luau" and path.stem not in SKIP:
            body = path.read_text()
            # `export type` is only legal at a chunk's top level; inside the loader it's a local type.
            body = re.sub(r"^export type ", "type ", body, flags=re.M)
            parts.append(f'local {var} = __add({parent_var}, "{path.stem}", "shared/{rel.as_posix()}")')
            parts.append(f'__loaders["shared/{rel.as_posix()}"] = function(script)\n{body}\nend')

    parts.append(TESTS.read_text())

    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write("\n".join(parts))
        bundle = f.name
    try:
        return subprocess.run([luau, bundle]).returncode
    finally:
        os.unlink(bundle)


if __name__ == "__main__":
    sys.exit(main())
