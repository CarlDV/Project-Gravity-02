-- Run the existing Lua smoke suites in a real Luau VM, including continue.
-- lune run tools/test_luau.luau tests/formation_smoke.lua
-- Filesystem access also preserves Unicode shape names on Windows.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local nativeRequire = require
local test = assert(process.args[1], "supply a test path")
local env = setmetatable({}, { __index = getfenv() })
env._G = env
env.math, env.table, env.string, env.os = table.clone(math), table.clone(table), table.clone(string), table.clone(os)
env.os.exit = process.exit
env.os.getenv = function(key) return process.env[key] end
env.package = { path = "tests/?.lua;./?.lua", loaded = {} }
env.arg = { [0] = test }
for i = 2, #process.args do env.arg[i - 1] = process.args[i] end

local function reader(text)
	text = text:gsub("\r\n", "\n")
	return {
		read = function() return text end,
		close = function() return true end,
		lines = function()
			local pos = 1
			return function()
				if pos > #text then return nil end
				local stop = text:find("\n", pos, true)
				local line = text:sub(pos, stop and stop - 1 or #text):gsub("\r$", "")
				pos = stop and stop + 1 or #text + 1
				return line
			end
		end,
	}
end

env.io = {
	open = function(path, mode)
		assert(mode == nil or mode == "r" or mode == "rb", "test adapter only opens files for reading")
		if not fs.isFile(path) then return nil, "No such file: " .. path end
		return reader(fs.readFile(path))
	end,
	popen = function(command)
		local path = command:match("^ls%s+(.+)$")
		assert(path, "test adapter only supports directory listings")
		path = path:gsub("^['\"]", ""):gsub("['\"]$", "")
		local names = fs.readDir(path)
		table.sort(names)
		return reader(table.concat(names, "\n"))
	end,
	write = function(...) stdio.write(table.concat({ ... })) end,
}

env.load = function(source, name)
	local ok, result = pcall(luau.load, source, { debugName = name or "test", environment = env })
	if ok then setfenv(result, env); return result end
	return nil, tostring(result)
end
env.loadstring = env.load
env.loadfile = function(path)
	if not fs.isFile(path) then return nil, "No such file: " .. path end
	return env.load(fs.readFile(path), path)
end
env.dofile = function(path) return assert(env.loadfile(path))() end
env.require = function(name)
	if name:sub(1, 1) == "@" then return nativeRequire(name) end
	if env.package.loaded[name] ~= nil then return env.package.loaded[name] end
	for template in env.package.path:gmatch("[^;]+") do
		local path = template:gsub("%?", (name:gsub("%.", "/")))
		if fs.isFile(path) then
			local result = assert(env.loadfile(path))()
			env.package.loaded[name] = result == nil and true or result
			return env.package.loaded[name]
		end
	end
	error("module not found: " .. name)
end

assert(env.loadfile(test))()
