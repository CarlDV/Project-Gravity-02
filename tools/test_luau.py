"""Run the offline Lua suites with the standalone luau-lang CLI and Python.

Usage: python tools/test_luau.py --luau PATH tests/load_build_smoke.lua
The CLI is supplied by the caller; this runner never downloads a runtime.
"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def literal(value):
    fence = "="
    while "]" + fence + "]" in value:
        fence += "="
    return "[" + fence + "[" + value + "]" + fence + "]"


def bundle(test, args):
    # These are virtual, read-only files. No shell execution is exposed to tests.
    paths = sorted(p for p in ROOT.rglob("*.lua") if ".git" not in p.parts)
    files = "\n".join(
        f"files[ {literal(p.relative_to(ROOT).as_posix())} ] = {literal(p.read_text(encoding='utf-8-sig'))}"
        for p in paths
    )
    arguments = ",".join(literal(a) for a in args)
    return "local files = {}\n" + files + "\n" + r'''
local nativeLoad = loadstring
local env = setmetatable({}, { __index = getfenv() })
env._G = env
env.math, env.table, env.string, env.os = table.clone(math), table.clone(table), table.clone(string), table.clone(os)
env.os.exit = function(code) if code and code ~= 0 then error("Test exited with status " .. code, 0) end end
env.os.getenv = function() return nil end
env.package = { path = "tests/?.lua;./?.lua", loaded = {} }
local function reader(source)
    source = source:gsub("\r\n", "\n")
    return {
        read = function() return source end,
        close = function() return true end,
        lines = function()
            local pos = 1
            return function()
                if pos > #source then return nil end
                local stop = source:find("\n", pos, true)
                local line = source:sub(pos, stop and stop - 1 or #source)
                pos = stop and stop + 1 or #source + 1
                return line
            end
        end,
    }
end
env.io = {
    open = function(path, mode)
        assert(mode == nil or mode == "r" or mode == "rb", "read-only test fixture")
        path = path:gsub("\\", "/"):gsub("^%./", "")
        return files[path] and reader(files[path]) or nil
    end,
    popen = function(command)
        local dir = assert(command:match("^ls%s+(.+)$"), "only directory listings are supported")
        dir = dir:gsub("^['\"]", ""):gsub("['\"]$", ""):gsub("/$", "") .. "/"
        local names = {}
        for path in pairs(files) do
            if path:sub(1, #dir) == dir and not path:sub(#dir + 1):find("/", 1, true) then
                names[#names + 1] = path:sub(#dir + 1)
            end
        end
        table.sort(names)
        return reader(table.concat(names, "\n"))
    end,
    write = function(...) print(table.concat({ ... })) end,
}
env.load = function(source, name)
    local fn, err = nativeLoad(source, name)
    if fn then setfenv(fn, env) end
    return fn, err
end
env.loadstring = env.load
env.loadfile = function(path)
    path = path:gsub("\\", "/"):gsub("^%./", "")
    if not files[path] then return nil, "Missing file: " .. path end
    return env.load(files[path], "@" .. path)
end
env.dofile = function(path) return assert(env.loadfile(path))() end
env.require = function(name)
    if env.package.loaded[name] ~= nil then return env.package.loaded[name] end
    for template in env.package.path:gmatch("[^;]+") do
        local path = template:gsub("%?", (name:gsub("%.", "/")))
        local fn = env.loadfile(path)
        if fn then
            local result = fn()
            env.package.loaded[name] = result == nil and true or result
            return env.package.loaded[name]
        end
    end
    error("Module not found: " .. name)
end
''' + f"\nenv.arg = {{ [0] = {literal(test)}, {arguments} }}\nassert(env.loadfile({literal(test)}))()\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default=os.environ.get("LUAU") or shutil.which("luau"))
    parser.add_argument("test")
    parser.add_argument("args", nargs="*")
    options = parser.parse_args()
    if not options.luau:
        parser.error("supply --luau PATH or put the standalone Luau CLI on PATH")
    with tempfile.TemporaryDirectory(prefix="gravity-test-") as temp:
        script = Path(temp) / "suite.luau"
        script.write_text(bundle(options.test.replace("\\", "/"), options.args), encoding="utf-8")
        result = subprocess.run([options.luau, str(script)], cwd=ROOT)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
