-- Roblox-side tools: version lookup, instance tree inspection, live Luau exec.
return function(env)
	local hs = env.hs
	local net = env.require("net")

	return {
		{
			name = "roblox_version",
			description = "Get current Roblox release version.",
			parameters = { type = "object", properties = {}, required = {} },
			run = function()
				local res = net.request("https://clientsettingscdn.roblox.com/v2/client-version/WindowsPlayer/channel/live", "GET", {})
				if not res or res.StatusCode ~= 200 then return "Version request failed" end
				local ok, data = pcall(function() return hs:JSONDecode(res.Body) end)
				if not ok or type(data) ~= "table" then return "Invalid JSON" end
				return string.format("Live: %s\nUpload: %s", data.version or "Unknown", data.clientVersionUpload or "Unknown")
			end
		},
		{
			name = "inspect_game",
			description = "Inspect game instance hierarchy.",
			parameters = {
				type = "object",
				properties = { path = { type = "string" } },
				required = {}
			},
			run = function(args)
				local path = tostring(args.path or "Workspace")
				local target = game
				if path ~= "" and path ~= "game" then
					for part in path:gmatch("[^%.]+") do
						if target then target = target:FindFirstChild(part) end
					end
				end
				if not target then return "Path not found: " .. path end
				local list = {}
				for _, child in ipairs(target:GetChildren()) do
					if #list < 30 then
						table.insert(list, string.format("- %s [%s] (%d children)", child.Name, child.ClassName, #child:GetChildren()))
					end
				end
				return string.format("Path: %s (%s)\nChildren: %d\nList:\n%s", target:GetFullName(), target.ClassName, #target:GetChildren(), table.concat(list, "\n"))
			end
		},
		{
			name = "execute_script",
			description = "Execute dynamic Luau code live in Roblox.",
			parameters = {
				type = "object",
				properties = { code = { type = "string" } },
				required = { "code" }
			},
			run = function(args)
				local code = tostring(args.code or "")
				if code == "" then return "Code buffer empty" end
				local loadFn = loadstring or (getgenv and getgenv().loadstring)
				if not loadFn then return "loadstring unavailable" end
				local fn, err = loadFn(code)
				if not fn then return "Compile error: " .. tostring(err) end
				local genv = (getgenv and getgenv()) or (getfenv and getfenv(0)) or _G
				local logs = {}
				local customEnv = setmetatable({
					print = function(...)
						local parts = {}
						for i = 1, select("#", ...) do table.insert(parts, tostring(select(i, ...))) end
						table.insert(logs, table.concat(parts, "\t"))
					end
				}, { __index = genv, __newindex = genv })
				if setfenv then pcall(setfenv, fn, customEnv) end
				local ok, res = pcall(fn)
				if not ok then return "Runtime error: " .. tostring(res) end
				local out = #logs > 0 and ("\nLogs:\n" .. table.concat(logs, "\n")) or ""
				local ret = res ~= nil and ("\nReturned: " .. tostring(res)) or ""
				return "Success." .. out .. ret
			end
		}
	}
end
