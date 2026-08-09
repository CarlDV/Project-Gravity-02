-- Roblox-side tools: version lookup, instance tree inspection, live Luau exec.
local EXEC_TIMEOUT = 10

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

				-- A loop that never yields blocks the Luau scheduler outright, so no
				-- timeout, thread or Stop button can reach it. These two forms are
				-- unconditional freezes with no legitimate use, so they get a yield.
				-- Loops with a real body are left alone: injecting a wait into one
				-- that already yields would silently halve its speed.
				code = code
					:gsub("while%s+true%s+do%s*end", "while true do task.wait() end")
					:gsub("repeat%s*until%s+false", "repeat task.wait() until false")

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

				-- Generated code used to run inline, so a loop that never returned
				-- froze the client with no way out -- not even the Stop button, since
				-- the agent thread was the one blocked. It now runs on its own thread
				-- and this one stops waiting after EXEC_TIMEOUT.
				local done, ok, res = false, false, nil
				task.spawn(function()
					ok, res = pcall(fn)
					done = true
				end)

				-- task.spawn runs the body inline until its first yield, so code that
				-- never yields is already finished here and must not be made to wait:
				-- polling first would put a scheduler tick on every single call.
				-- Anything that did yield is polled per frame rather than on a fixed
				-- sleep, so a script finishing in 10ms is not billed for a 50ms nap.
				-- Elapsed comes from task.wait's own delta, not os.clock: os.clock
				-- reports CPU time, which stalls while a thread is yielded, so a
				-- script full of task.wait would blow far past the deadline in real
				-- seconds before the budget looked spent.
				if not done then
					local elapsed = 0
					repeat
						elapsed = elapsed + (task.wait() or 0)
					until done or elapsed >= EXEC_TIMEOUT
				end

				if not done then
					-- The thread is abandoned, not killed: it keeps running until it
					-- finishes on its own. Say so rather than implying it stopped.
					return ("Timed out after %ds and was left running in the background. "):format(EXEC_TIMEOUT)
						.. "Do not retry the same code; make it finish or yield instead."
				end
				if not ok then return "Runtime error: " .. tostring(res) end
				local out = #logs > 0 and ("\nLogs:\n" .. table.concat(logs, "\n")) or ""
				local ret = res ~= nil and ("\nReturned: " .. tostring(res)) or ""
				return "Success." .. out .. ret
			end
		}
	}
end
