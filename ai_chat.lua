return function(context)
	local v1, v2, v3, v4, v6, v8 = context.v1, context.v2, context.v3, context.v4, context.v6, context.v8
	local x1, x6_ctx = context.x1, context.x6
	local get_shape = context.get_shape

	local hs = game:GetService("HttpService")
	local req_fn = request or (http and http.request) or http_request or (fluxus and fluxus.request) or (syn and syn.request)

	local AUTH_DIR = "ProjectAI"
	local AUTH_FILE = "ProjectAI/auth.json"
	local REF_LINK = "https://agentrouter.org/register?aff=4pqF"
	local DEFAULT_ENDPOINT = "https://ai.davidcsl.me"

	local sessionState = {
		mode = "free",
		token = "",
		apiKey = "",
		endpoint = DEFAULT_ENDPOINT,
		model = "glm-5.2",
		history = {},
		systemPrompt = [[(YOUR MODEL IS GLM-5.2)
You are an integrated AI assistant and gravity physics controller for Project Gravity.

PROJECT GRAVITY CUSTOM SHAPE PLUGIN SYSTEM DOCS:
1. File Location: Custom shapes are saved to 'GravityShapes/<ShapeName>.lua' using the save_custom_shape tool.
2. Shape Module Contract:
```lua
local M = {}
-- Optional: pre-computation per frame
function M.px(t, c, x6, x9, x1)
    if not x6.pre["ShapeName"] then x6.pre["ShapeName"] = {} end
end
-- Required: per-part physics loop
function M.f2(p, cen, d, t, c, x1, x6, x9)
    -- p: BasePart, cen: Vector3 center, d: per-part state table (e.g. d.spot = math.random()*math.pi*2)
    -- t: elapsed time, c: UI controls table (indexed by Key e.g. c.k11)
    local target_pos = cen + Vector3.new(0, 10, 0)
    -- IMPORTANT: Return force vector AND target_pos as 2nd argument for anti-jitter smoothing!
    return (target_pos - p.Position) * 5000, target_pos
end
-- UI Controls Table (Slider or Toggle)
M.Controls = {
    { Type = "Slider", Name = "Radius", Min = 5, Max = 100, Key = "k11" },
    { Type = "Toggle", Name = "Cut In Half", Key = "k12" }
}
return M
```

Core Rules:
- Always execute appropriate tools for physics or code requests.
- When creating custom shapes, strictly follow the plugin docs above and call save_custom_shape(name, code).
- Use save_script only for general non-shape Luau scripts.
- Keep all responses concise and under 250 characters.
- CRITICAL: DO NOT USE EMOJIS IN YOUR RESPONSES. NEVER USE ANY EMOJIS. OUTPUT PLAIN TEXT ONLY.]]
	}

	local function persistSave()
		if type(writefile) ~= "function" then return end
		if type(makefolder) == "function" then
			local okFolder = pcall(function() return type(isfolder) == "function" and isfolder(AUTH_DIR) end)
			if not okFolder then pcall(makefolder, AUTH_DIR) end
		end
		local data = {
			mode = sessionState.mode,
			token = sessionState.token,
			apiKey = sessionState.apiKey
		}
		pcall(writefile, AUTH_FILE, hs:JSONEncode(data))
	end

	local function persistLoad()
		if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
		local ok, exists = pcall(isfile, AUTH_FILE)
		if not ok or not exists then return false end
		local okRead, content = pcall(readfile, AUTH_FILE)
		if not okRead or not content or content == "" then return false end
		local okDec, decoded = pcall(function() return hs:JSONDecode(content) end)
		if okDec and type(decoded) == "table" then
			sessionState.mode = decoded.mode or "free"
			sessionState.token = decoded.token or ""
			sessionState.apiKey = decoded.apiKey or ""
			return (sessionState.mode == "free" and #sessionState.token > 0) or (sessionState.mode == "key" and #sessionState.apiKey > 0)
		end
		return false
	end

	local function netRequest(urlPath, method, headers, payload)
		local fullUrl = urlPath:find("^https?://") and urlPath or (sessionState.endpoint .. urlPath)
		local opts = {
			Url = fullUrl,
			Method = method or "GET",
			Headers = headers or {}
		}
		if payload and payload ~= "" and method ~= "GET" and method ~= "HEAD" then
			opts.Body = payload
		end
		if req_fn then
			local ok, res = pcall(req_fn, opts)
			if ok and res then
				return {
					StatusCode = res.StatusCode or res.Status or 200,
					Body = res.Body or res.ResponseData or ""
				}
			end
			return nil, ok and "empty executor response" or tostring(res)
		else
			local ok, res = pcall(function() return hs:RequestAsync(opts) end)
			if ok and res then
				return {
					StatusCode = res.StatusCode,
					Body = res.Body
				}
			end
			return nil, ok and "empty HttpService response" or tostring(res)
		end
	end

	local function urlEncode(str)
		return (str:gsub("[^%w%-_%.~]", function(c)
			return string.format("%%%02X", string.byte(c))
		end))
	end

	local function parseHtmlEntities(str)
		return (str
			:gsub("&amp;", "&")
			:gsub("&lt;", "<")
			:gsub("&gt;", ">")
			:gsub("&quot;", '"')
			:gsub("&#x27;", "'")
			:gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end)
		)
	end

	local toolHandlers = {}

	toolHandlers.web_search = function(args)
		local q = tostring(args.query or "")
		if q == "" then return "Query parameter missing" end
		local max = tonumber(args.max) or 5
		local body = string.format("q=%s&b=&l=us-en", urlEncode(q))
		local res = netRequest("https://html.duckduckgo.com/html/", "POST", {
			["Content-Type"] = "application/x-www-form-urlencoded",
			["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
			["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
		}, body)
		if not res or res.StatusCode ~= 200 then return "Search request failed" end
		local records = {}
		for href, title in res.Body:gmatch('<a[^>]+class="result__a"[^>]*href="([^"]*)"[^>]*>(.-)</a>') do
			if #records >= max then break end
			local link = href:match("[?&]uddg=([^&]+)")
			link = link and link:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end) or href
			if not link:find("^https://duckduckgo%.com") then
				table.insert(records, { title = parseHtmlEntities(title), url = link })
			end
		end
		local idx = 1
		for snippet in res.Body:gmatch('<a[^>]+class="result__snippet"[^>]*>(.-)</a>') do
			if records[idx] then
				records[idx].snippet = parseHtmlEntities(snippet):match("^%s*(.-)%s*$")
				idx += 1
			end
		end
		if #records == 0 then return "No results found" end
		local lines = {}
		for i, item in ipairs(records) do
			table.insert(lines, string.format("%d. %s\n   URL: %s\n   Snippet: %s", i, item.title, item.url, item.snippet or "N/A"))
		end
		return table.concat(lines, "\n\n")
	end

	toolHandlers.fetch_page = function(args)
		local target = tostring(args.url or "")
		if target == "" then return "URL missing" end
		local res = netRequest(target, "GET", {
			["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
		})
		if not res or res.StatusCode ~= 200 then return "Fetch failed" end
		local txt = res.Body:gsub("<script[^>]*>.-</script>", " "):gsub("<style[^>]*>.-</style>", " "):gsub("<[^>]+>", " ")
		txt = parseHtmlEntities(txt):gsub("[ \t]+", " "):gsub("\n[ \t]+", "\n"):gsub("\n\n+", "\n\n"):match("^%s*(.-)%s*$") or ""
		if #txt > 3500 then txt = txt:sub(1, 3500) .. "\n...[truncated]" end
		return #txt > 0 and txt or "Empty response"
	end

	toolHandlers.roblox_version = function()
		local res = netRequest("https://clientsettingscdn.roblox.com/v2/client-version/WindowsPlayer/channel/live", "GET", {})
		if not res or res.StatusCode ~= 200 then return "Version request failed" end
		local ok, data = pcall(function() return hs:JSONDecode(res.Body) end)
		if not ok or type(data) ~= "table" then return "Invalid JSON" end
		return string.format("Live: %s\nUpload: %s", data.version or "Unknown", data.clientVersionUpload or "Unknown")
	end

	toolHandlers.inspect_game = function(args)
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

	toolHandlers.execute_script = function(args)
		local code = tostring(args.code or "")
		if code == "" then return "Code buffer empty" end
		local loadFn = loadstring or (getgenv and getgenv().loadstring)
		if not loadFn then return "loadstring unavailable" end
		local fn, err = loadFn(code)
		if not fn then return "Compile error: " .. tostring(err) end
		local env = (getgenv and getgenv()) or (getfenv and getfenv(0)) or _G
		local logs = {}
		local customEnv = setmetatable({
			print = function(...)
				local parts = {}
				for i = 1, select("#", ...) do table.insert(parts, tostring(select(i, ...))) end
				table.insert(logs, table.concat(parts, "\t"))
			end
		}, { __index = env, __newindex = env })
		if setfenv then pcall(setfenv, fn, customEnv) end
		local ok, res = pcall(fn)
		if not ok then return "Runtime error: " .. tostring(res) end
		local out = #logs > 0 and ("\nLogs:\n" .. table.concat(logs, "\n")) or ""
		local ret = res ~= nil and ("\nReturned: " .. tostring(res)) or ""
		return "Success." .. out .. ret
	end

	toolHandlers.save_script = function(args)
		if type(writefile) ~= "function" then return "writefile unavailable" end
		local code = tostring(args.code or "")
		if code == "" then return "Code empty" end
		local name = tostring(args.name or "script"):gsub("[/\\]", "_"):gsub("[^%w%-_%. ]", ""):match("^%s*(.-)%s*$")
		if name == "" then name = "script" end
		if not name:lower():match("%.lua$") then name = name .. ".lua" end
		local path = name
		if type(makefolder) == "function" then
			local okFolder = pcall(function() return type(isfolder) == "function" and isfolder(AUTH_DIR) end)
			if not okFolder then pcall(makefolder, AUTH_DIR) end
			path = AUTH_DIR .. "/" .. name
		end
		local ok, err = pcall(writefile, path, code)
		return ok and ("Saved to: " .. path) or ("Save failed: " .. tostring(err))
	end

	toolHandlers.save_custom_shape = function(args)
		if type(writefile) ~= "function" then return "writefile unavailable" end
		local code = tostring(args.code or "")
		if code == "" then return "Code empty" end
		local rawName = tostring(args.name or "CustomShape"):gsub("[/\\]", ""):match("^%s*(.-)%s*$")
		if rawName == "" then rawName = "CustomShape" end
		if not rawName:lower():match("%.lua$") then rawName = rawName .. ".lua" end

		if type(makefolder) == "function" then
			pcall(function()
				if type(isfolder) == "function" and not isfolder("GravityShapes") then
					makefolder("GravityShapes")
				end
			end)
		end

		local path = "GravityShapes/" .. rawName
		local ok, err = pcall(writefile, path, code)
		return ok and ("Custom shape saved successfully to: " .. path) or ("Save failed: " .. tostring(err))
	end

	toolHandlers.adjust_gravity = function(args)
		local shapeName = args.shape and tostring(args.shape) or nil
		local speed = tonumber(args.speed)
		local damping = tonumber(args.damping)
		local disabled = args.disabled
		local pi_all = args.target_all
		local anchor_self = args.anchor_self

		local changes = {}
		if shapeName and get_shape and get_shape(shapeName) then
			x1.k6 = shapeName
			table.insert(changes, "shape=" .. shapeName)
		end
		if speed then
			x1.MaxSpeed = speed
			table.insert(changes, "speed=" .. tostring(speed))
		end
		if damping then
			x1.Damping = damping
			table.insert(changes, "damping=" .. tostring(damping))
		end
		if disabled ~= nil then
			x1.Disabled = (disabled == true)
			table.insert(changes, "disabled=" .. tostring(x1.Disabled))
		end
		if pi_all ~= nil then
			x1.PI_All = (pi_all == true)
			if x1.PI_All then x1.AnchorSelf = false end
			table.insert(changes, "target_all=" .. tostring(x1.PI_All))
		end
		if anchor_self ~= nil then
			x1.AnchorSelf = (anchor_self == true)
			if x1.AnchorSelf then x1.PI_All = false end
			table.insert(changes, "anchor_self=" .. tostring(x1.AnchorSelf))
		end

		return #changes > 0 and ("Updated physics: " .. table.concat(changes, ", ")) or "No parameters modified"
	end

	local toolDefinitions = {
		{
			type = "function",
			["function"] = {
				name = "web_search",
				description = "Search DDG for live web content and facts.",
				parameters = {
					type = "object",
					properties = { query = { type = "string" }, max = { type = "integer" } },
					required = { "query" }
				}
			}
		},
		{
			type = "function",
			["function"] = {
				name = "fetch_page",
				description = "Fetch raw page text from a URL.",
				parameters = {
					type = "object",
					properties = { url = { type = "string" } },
					required = { "url" }
				}
			}
		},
		{
			type = "function",
			["function"] = {
				name = "roblox_version",
				description = "Get current Roblox release version.",
				parameters = { type = "object", properties = {}, required = {} }
			}
		},
		{
			type = "function",
			["function"] = {
				name = "inspect_game",
				description = "Inspect game instance hierarchy.",
				parameters = {
					type = "object",
					properties = { path = { type = "string" } },
					required = {}
				}
			}
		},
		{
			type = "function",
			["function"] = {
				name = "execute_script",
				description = "Execute dynamic Luau code live in Roblox.",
				parameters = {
					type = "object",
					properties = { code = { type = "string" } },
					required = { "code" }
				}
			}
		},
		{
			type = "function",
			["function"] = {
				name = "save_script",
				description = "Save general Luau script to workspace file.",
				parameters = {
					type = "object",
					properties = {
						code = { type = "string", description = "Luau source code to save." },
						name = { type = "string", description = "File name (e.g. 'my_script.lua')." }
					},
					required = { "code", "name" }
				}
			}
		},
		{
			type = "function",
			["function"] = {
				name = "save_custom_shape",
				description = "Save a custom shape module into the 'GravityShapes/' directory for Project Gravity.",
				parameters = {
					type = "object",
					properties = {
						code = { type = "string", description = "The complete custom shape module code implementing M.f2 and M.Controls." },
						name = { type = "string", description = "The shape name (e.g. 'Spiral Galaxy')." }
					},
					required = { "code", "name" }
				}
			}
		},
		{
			type = "function",
			["function"] = {
				name = "adjust_gravity",
				description = "Modify Project Gravity engine properties dynamically.",
				parameters = {
					type = "object",
					properties = {
						shape = { type = "string", description = "Shape preset name e.g. 'Celestial Ribbon', 'Black Hole'" },
						speed = { type = "number", description = "Max speed limit" },
						damping = { type = "number", description = "Damping value" },
						disabled = { type = "boolean", description = "Disable physics engine" },
						target_all = { type = "boolean", description = "Target all players" },
						anchor_self = { type = "boolean", description = "Anchor to self" }
					},
					required = {}
				}
			}
		}
	}

	local function summarizeToolArgs(tbl)
		if type(tbl) ~= "table" then return "" end
		local parts = {}
		for k, v in pairs(tbl) do
			local s = tostring(v):gsub("%s+", " ")
			if #s > 20 then s = s:sub(1, 20) .. "..." end
			table.insert(parts, tostring(k) .. "=" .. s)
		end
		local res = table.concat(parts, ", ")
		return #res > 35 and (res:sub(1, 35) .. "...") or res
	end

	local function runAgentLoop(prompt, updateStatus, pushStep)
		pushStep = pushStep or function() end
		if #sessionState.history == 0 then
			table.insert(sessionState.history, { role = "system", content = sessionState.systemPrompt })
		end
		table.insert(sessionState.history, { role = "user", content = prompt })

		if #sessionState.history > 12 then
			local trimmed = { sessionState.history[1] }
			for i = #sessionState.history - 9, #sessionState.history do
				table.insert(trimmed, sessionState.history[i])
			end
			sessionState.history = trimmed
		end

		local count = 0
		local lastSig = ""
		local streak = 0

		while count < 30 do
			count += 1
			updateStatus("Thinking...")

			local payload = {
				model = sessionState.model,
				messages = sessionState.history,
				tools = toolDefinitions,
				max_tokens = 2048
			}

			local bodyJson = hs:JSONEncode(payload):gsub('"properties":%[%]', '"properties":{}')
			local reqHeaders = { ["Content-Type"] = "application/json" }
			local endpointPath = "/v1/chat/completions"

			if sessionState.mode == "free" then
				endpointPath = "/free/v1/chat/completions"
				if #sessionState.token > 0 then
					reqHeaders["Cookie"] = "aidavidcsl_session=" .. sessionState.token
				end
			else
				endpointPath = "/key/v1/chat/completions"
				reqHeaders["Authorization"] = "Bearer " .. sessionState.apiKey
				reqHeaders["x-api-key"] = sessionState.apiKey
			end

			local res, err = netRequest(endpointPath, "POST", reqHeaders, bodyJson)
			if not res or res.StatusCode ~= 200 then
				updateStatus("Error")
				return "Request failed: " .. tostring(res and res.StatusCode or err)
			end

			local ok, decoded = pcall(function() return hs:JSONDecode(res.Body) end)
			if not ok or type(decoded) ~= "table" or not decoded.choices or not decoded.choices[1] then
				updateStatus("Error")
				return "Invalid JSON response"
			end

			local choiceMsg = decoded.choices[1].message
			if choiceMsg.tool_calls and type(choiceMsg.tool_calls) == "table" and #choiceMsg.tool_calls > 0 then
				table.insert(sessionState.history, choiceMsg)
				if choiceMsg.content and choiceMsg.content ~= "" then
					pushStep("think", choiceMsg.content)
				end
				for _, call in ipairs(choiceMsg.tool_calls) do
					local name = call["function"].name
					local argsRaw = call["function"].arguments or "{}"
					local okArgs, argsParsed = pcall(function() return hs:JSONDecode(argsRaw) end)
					argsParsed = okArgs and argsParsed or {}

					local argStr = summarizeToolArgs(argsParsed)
					updateStatus("Running " .. tostring(name))
					pushStep("call", tostring(name) .. (argStr ~= "" and (" " .. argStr) or ""))

					local sig = tostring(name) .. ":" .. tostring(argsRaw)
					if sig == lastSig then streak += 1 else lastSig = sig; streak = 1 end

					local resultText
					if streak >= 3 then
						resultText = "Repeated tool call rejected."
					else
						local fn = toolHandlers[name]
						if fn then
							local okFn, resFn = pcall(fn, argsParsed)
							resultText = okFn and tostring(resFn) or ("Error: " .. tostring(resFn))
						else
							resultText = "Unknown tool: " .. tostring(name)
						end
					end

					if #resultText > 1500 then resultText = resultText:sub(1, 1500) .. "\n...[truncated]" end
					pushStep("result", resultText)

					table.insert(sessionState.history, {
						role = "tool",
						tool_call_id = call.id,
						content = resultText
					})
				end
			else
				local text = choiceMsg.content or "Done."
				table.insert(sessionState.history, { role = "assistant", content = text })
				updateStatus("Ready")
				return text
			end
		end

		updateStatus("Ready")
		return "Maximum iteration limit reached."
	end

	local function animateWindow(win, state)
		local scale = win:FindFirstChild("UIScale")
		if not scale then
			scale = Instance.new("UIScale", win)
			scale.Scale = 0.8
		end
		if state then
			win.Visible = true
			v6:Create(win, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
			v6:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			local tw = v6:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { GroupTransparency = 1 })
			v6:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.8 }):Play()
			local conn
			conn = tw.Completed:Connect(function()
				if win.GroupTransparency >= 0.99 then win.Visible = false end
				if conn then conn:Disconnect() end
			end)
			tw:Play()
		end
	end

	local function stripMarkdown(str)
		if type(str) ~= "string" then return "" end
		str = str:gsub("```%w*", ""):gsub("```", ""):gsub("`", ""):gsub("%*%*", ""):gsub("^#+%s*", "")
		return str
	end

	local windowController = {}
	local authWindow, chatWindow

	function windowController.openAuth(parentGui, onAuthenticated)
		if authWindow then
			animateWindow(authWindow, true)
			return
		end

		authWindow = Instance.new("CanvasGroup", parentGui)
		authWindow.Name = "AI_Auth_Modal"
		authWindow.Size = UDim2.new(0, 230, 0, 180)
		authWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
		authWindow.AnchorPoint = Vector2.new(0.5, 0.5)
		authWindow.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
		authWindow.Active = true
		authWindow.Draggable = true
		authWindow.GroupTransparency = 1
		Instance.new("UICorner", authWindow).CornerRadius = UDim.new(0, 10)
		local str = Instance.new("UIStroke", authWindow)
		str.Color = Color3.fromRGB(45, 45, 52)
		str.Thickness = 1

		local sizeLimiter = Instance.new("UISizeConstraint", authWindow)
		sizeLimiter.MinSize = Vector2.new(200, 160)
		sizeLimiter.MaxSize = Vector2.new(250, 200)

		local header = Instance.new("Frame", authWindow)
		header.Size = UDim2.new(1, 0, 0, 32)
		header.BackgroundTransparency = 1

		local title = Instance.new("TextLabel", header)
		title.Position = UDim2.new(0, 12, 0, 0)
		title.Size = UDim2.new(1, -40, 1, 0)
		title.BackgroundTransparency = 1
		title.Text = "PROJECT GRAVITY AI"
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 9
		title.TextXAlignment = Enum.TextXAlignment.Left

		local closeBtn = Instance.new("TextButton", header)
		closeBtn.Position = UDim2.new(1, -24, 0, 6)
		closeBtn.Size = UDim2.new(0, 18, 0, 18)
		closeBtn.BackgroundTransparency = 1
		closeBtn.Text = "X"
		closeBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextSize = 11

		closeBtn.MouseEnter:Connect(function()
			v6:Create(closeBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end)
		closeBtn.MouseLeave:Connect(function()
			v6:Create(closeBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(140, 140, 150) }):Play()
		end)
		closeBtn.MouseButton1Click:Connect(function()
			animateWindow(authWindow, false)
		end)

		local tabRow = Instance.new("Frame", authWindow)
		tabRow.Position = UDim2.new(0, 10, 0, 32)
		tabRow.Size = UDim2.new(1, -20, 0, 24)
		tabRow.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		Instance.new("UICorner", tabRow).CornerRadius = UDim.new(0, 6)

		local btnKey = Instance.new("TextButton", tabRow)
		btnKey.Size = UDim2.new(0.5, 0, 1, 0)
		btnKey.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		btnKey.Text = "API Key"
		btnKey.TextColor3 = Color3.fromRGB(255, 255, 255)
		btnKey.Font = Enum.Font.GothamMedium
		btnKey.TextSize = 9
		Instance.new("UICorner", btnKey).CornerRadius = UDim.new(0, 6)

		local btnServer = Instance.new("TextButton", tabRow)
		btnServer.Position = UDim2.new(0.5, 0, 0, 0)
		btnServer.Size = UDim2.new(0.5, 0, 1, 0)
		btnServer.BackgroundTransparency = 1
		btnServer.Text = "Server Login"
		btnServer.TextColor3 = Color3.fromRGB(140, 140, 150)
		btnServer.Font = Enum.Font.GothamMedium
		btnServer.TextSize = 9
		Instance.new("UICorner", btnServer).CornerRadius = UDim.new(0, 6)

		local bodyKey = Instance.new("Frame", authWindow)
		bodyKey.Position = UDim2.new(0, 10, 0, 62)
		bodyKey.Size = UDim2.new(1, -20, 1, -68)
		bodyKey.BackgroundTransparency = 1
		bodyKey.Visible = true

		local refBtn = Instance.new("TextButton", bodyKey)
		refBtn.Position = UDim2.new(0, 0, 0, 4)
		refBtn.Size = UDim2.new(1, 0, 0, 24)
		refBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		refBtn.Text = "GET API KEY (AGENTROUTER)"
		refBtn.TextColor3 = Color3.fromRGB(0, 230, 190)
		refBtn.Font = Enum.Font.GothamMedium
		refBtn.TextSize = 8
		Instance.new("UICorner", refBtn).CornerRadius = UDim.new(0, 5)
		local refStr = Instance.new("UIStroke", refBtn)
		refStr.Color = Color3.fromRGB(38, 38, 44)

		refBtn.MouseButton1Click:Connect(function()
			local clipFn = setclipboard or toclipboard or (syn and syn.write_clipboard)
			if clipFn then
				pcall(clipFn, REF_LINK)
				refBtn.Text = "LINK COPIED TO CLIPBOARD"
				task.delay(2, function() refBtn.Text = "GET API KEY (AGENTROUTER)" end)
			else
				refBtn.Text = REF_LINK
			end
		end)

		local keyInput = Instance.new("TextBox", bodyKey)
		keyInput.Position = UDim2.new(0, 0, 0, 34)
		keyInput.Size = UDim2.new(1, 0, 0, 26)
		keyInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		keyInput.PlaceholderText = "Paste API Key (sk-...)"
		keyInput.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
		keyInput.Text = sessionState.apiKey
		keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		keyInput.Font = Enum.Font.Gotham
		keyInput.TextSize = 9
		Instance.new("UICorner", keyInput).CornerRadius = UDim.new(0, 5)
		local keyInputStr = Instance.new("UIStroke", keyInput)
		keyInputStr.Color = Color3.fromRGB(38, 38, 44)

		local saveKeyBtn = Instance.new("TextButton", bodyKey)
		saveKeyBtn.Position = UDim2.new(0, 0, 0, 66)
		saveKeyBtn.Size = UDim2.new(1, 0, 0, 26)
		saveKeyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		saveKeyBtn.Text = "SAVE API KEY"
		saveKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		saveKeyBtn.Font = Enum.Font.GothamMedium
		saveKeyBtn.TextSize = 9
		Instance.new("UICorner", saveKeyBtn).CornerRadius = UDim.new(0, 5)
		local saveStr = Instance.new("UIStroke", saveKeyBtn)
		saveStr.Color = Color3.fromRGB(50, 50, 58)

		saveKeyBtn.MouseEnter:Connect(function()
			v6:Create(saveKeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(40, 40, 48) }):Play()
		end)
		saveKeyBtn.MouseLeave:Connect(function()
			v6:Create(saveKeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(30, 30, 36) }):Play()
		end)

		local bodyServer = Instance.new("Frame", authWindow)
		bodyServer.Position = UDim2.new(0, 10, 0, 62)
		bodyServer.Size = UDim2.new(1, -20, 1, -68)
		bodyServer.BackgroundTransparency = 1
		bodyServer.Visible = false

		local userInput = Instance.new("TextBox", bodyServer)
		userInput.Position = UDim2.new(0, 0, 0, 4)
		userInput.Size = UDim2.new(1, 0, 0, 24)
		userInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		userInput.PlaceholderText = "Username"
		userInput.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
		userInput.Text = ""
		userInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		userInput.Font = Enum.Font.Gotham
		userInput.TextSize = 9
		Instance.new("UICorner", userInput).CornerRadius = UDim.new(0, 5)
		local uStr = Instance.new("UIStroke", userInput)
		uStr.Color = Color3.fromRGB(38, 38, 44)

		local passInput = Instance.new("TextBox", bodyServer)
		passInput.Position = UDim2.new(0, 0, 0, 32)
		passInput.Size = UDim2.new(1, 0, 0, 24)
		passInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		passInput.PlaceholderText = "Password"
		passInput.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
		passInput.Text = ""
		passInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		passInput.Font = Enum.Font.Gotham
		passInput.TextSize = 9
		Instance.new("UICorner", passInput).CornerRadius = UDim.new(0, 5)
		local pStr = Instance.new("UIStroke", passInput)
		pStr.Color = Color3.fromRGB(38, 38, 44)

		local errLbl = Instance.new("TextLabel", bodyServer)
		errLbl.Position = UDim2.new(0, 0, 0, 58)
		errLbl.Size = UDim2.new(1, 0, 0, 12)
		errLbl.BackgroundTransparency = 1
		errLbl.Text = ""
		errLbl.TextColor3 = Color3.fromRGB(255, 90, 90)
		errLbl.Font = Enum.Font.Gotham
		errLbl.TextSize = 8
		errLbl.TextXAlignment = Enum.TextXAlignment.Left

		local loginBtn = Instance.new("TextButton", bodyServer)
		loginBtn.Position = UDim2.new(0, 0, 0, 72)
		loginBtn.Size = UDim2.new(1, 0, 0, 26)
		loginBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		loginBtn.Text = "LOGIN TO SERVER"
		loginBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		loginBtn.Font = Enum.Font.GothamMedium
		loginBtn.TextSize = 9
		Instance.new("UICorner", loginBtn).CornerRadius = UDim.new(0, 5)
		local logBtnStr = Instance.new("UIStroke", loginBtn)
		logBtnStr.Color = Color3.fromRGB(50, 50, 58)

		loginBtn.MouseEnter:Connect(function()
			v6:Create(loginBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(40, 40, 48) }):Play()
		end)
		loginBtn.MouseLeave:Connect(function()
			v6:Create(loginBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(30, 30, 36) }):Play()
		end)

		btnServer.MouseButton1Click:Connect(function()
			btnServer.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
			btnServer.BackgroundTransparency = 0
			btnServer.TextColor3 = Color3.fromRGB(255, 255, 255)
			btnKey.BackgroundTransparency = 1
			btnKey.TextColor3 = Color3.fromRGB(140, 140, 150)
			bodyServer.Visible = true
			bodyKey.Visible = false
		end)

		btnKey.MouseButton1Click:Connect(function()
			btnKey.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
			btnKey.BackgroundTransparency = 0
			btnKey.TextColor3 = Color3.fromRGB(255, 255, 255)
			btnServer.BackgroundTransparency = 1
			btnServer.TextColor3 = Color3.fromRGB(140, 140, 150)
			bodyKey.Visible = true
			bodyServer.Visible = false
		end)

		loginBtn.MouseButton1Click:Connect(function()
			local uText = userInput.Text:match("^%s*(.-)%s*$")
			local pText = passInput.Text:match("^%s*(.-)%s*$")
			if uText == "" or pText == "" then
				errLbl.Text = "Please enter username and password"
				return
			end
			errLbl.Text = "Logging in..."
			local body = hs:JSONEncode({ user = uText, pass = pText })
			local res, err = netRequest("/api/login", "POST", { ["Content-Type"] = "application/json" }, body)
			if res and res.StatusCode == 200 then
				sessionState.mode = "free"
				sessionState.token = "active"
				persistSave()
				authWindow:Destroy()
				authWindow = nil
				if onAuthenticated then onAuthenticated() end
			else
				errLbl.Text = "Login failed: Check credentials"
			end
		end)

		saveKeyBtn.MouseButton1Click:Connect(function()
			local kText = keyInput.Text:match("^%s*(.-)%s*$")
			if kText == "" then return end
			sessionState.mode = "key"
			sessionState.apiKey = kText
			persistSave()
			authWindow:Destroy()
			authWindow = nil
			if onAuthenticated then onAuthenticated() end
		end)

		animateWindow(authWindow, true)
	end

	function windowController.openChat(parentGui)
		if chatWindow then
			animateWindow(chatWindow, not chatWindow.Visible)
			return
		end

		chatWindow = Instance.new("CanvasGroup", parentGui)
		chatWindow.Name = "AI_Chat_Panel"
		chatWindow.Size = UDim2.new(0, 300, 0, 240)
		chatWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
		chatWindow.AnchorPoint = Vector2.new(0.5, 0.5)
		chatWindow.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
		chatWindow.Active = true
		chatWindow.Draggable = true
		chatWindow.GroupTransparency = 1
		Instance.new("UICorner", chatWindow).CornerRadius = UDim.new(0, 8)
		local str = Instance.new("UIStroke", chatWindow)
		str.Color = Color3.fromRGB(45, 45, 52)
		str.Thickness = 1

		local sizeLimiter = Instance.new("UISizeConstraint", chatWindow)
		sizeLimiter.MinSize = Vector2.new(240, 180)
		sizeLimiter.MaxSize = Vector2.new(340, 270)

		local header = Instance.new("Frame", chatWindow)
		header.Size = UDim2.new(1, 0, 0, 30)
		header.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		local headerLine = Instance.new("Frame", header)
		headerLine.Position = UDim2.new(0, 0, 1, -1)
		headerLine.Size = UDim2.new(1, 0, 0, 1)
		headerLine.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		headerLine.BorderSizePixel = 0

		local title = Instance.new("TextLabel", header)
		title.Position = UDim2.new(0, 10, 0, 0)
		title.Size = UDim2.new(0, 64, 1, 0)
		title.BackgroundTransparency = 1
		title.Text = "project ai"
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Font = Enum.Font.GothamMedium
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left

		local modelLbl = Instance.new("TextLabel", header)
		modelLbl.Position = UDim2.new(0, 74, 0, 0)
		modelLbl.Size = UDim2.new(0, 50, 1, 0)
		modelLbl.BackgroundTransparency = 1
		modelLbl.Text = sessionState.model
		modelLbl.TextColor3 = Color3.fromRGB(110, 110, 120)
		modelLbl.Font = Enum.Font.Gotham
		modelLbl.TextSize = 10
		modelLbl.TextXAlignment = Enum.TextXAlignment.Left

		local statusLbl = Instance.new("TextLabel", header)
		statusLbl.Position = UDim2.new(0, 126, 0, 0)
		statusLbl.Size = UDim2.new(1, -205, 1, 0)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Text = "ready"
		statusLbl.TextColor3 = Color3.fromRGB(110, 110, 120)
		statusLbl.Font = Enum.Font.Gotham
		statusLbl.TextSize = 10
		statusLbl.TextXAlignment = Enum.TextXAlignment.Right

		local logoutBtn = Instance.new("TextButton", header)
		logoutBtn.Position = UDim2.new(1, -92, 0.5, -9)
		logoutBtn.Size = UDim2.new(0, 46, 0, 18)
		logoutBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		logoutBtn.Text = "Logout"
		logoutBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
		logoutBtn.Font = Enum.Font.GothamMedium
		logoutBtn.TextSize = 8
		Instance.new("UICorner", logoutBtn).CornerRadius = UDim.new(0, 4)
		local logStr = Instance.new("UIStroke", logoutBtn)
		logStr.Color = Color3.fromRGB(45, 35, 35)

		logoutBtn.MouseButton1Click:Connect(function()
			sessionState.mode = ""
			sessionState.token = ""
			sessionState.apiKey = ""
			persistSave()
			chatWindow:Destroy()
			chatWindow = nil
			windowController.openAuth(parentGui, function()
				windowController.openChat(parentGui)
			end)
		end)

		local minBtn = Instance.new("TextButton", header)
		minBtn.Position = UDim2.new(1, -40, 0, 6)
		minBtn.Size = UDim2.new(0, 16, 0, 18)
		minBtn.BackgroundTransparency = 1
		minBtn.Text = "-"
		minBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
		minBtn.Font = Enum.Font.GothamBold
		minBtn.TextSize = 13

		minBtn.MouseEnter:Connect(function()
			v6:Create(minBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end)
		minBtn.MouseLeave:Connect(function()
			v6:Create(minBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(140, 140, 150) }):Play()
		end)
		minBtn.MouseButton1Click:Connect(function()
			animateWindow(chatWindow, false)
		end)

		local closeBtn = Instance.new("TextButton", header)
		closeBtn.Position = UDim2.new(1, -22, 0, 6)
		closeBtn.Size = UDim2.new(0, 18, 0, 18)
		closeBtn.BackgroundTransparency = 1
		closeBtn.Text = "X"
		closeBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextSize = 11

		closeBtn.MouseEnter:Connect(function()
			v6:Create(closeBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end)
		closeBtn.MouseLeave:Connect(function()
			v6:Create(closeBtn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(140, 140, 150) }):Play()
		end)
		closeBtn.MouseButton1Click:Connect(function()
			animateWindow(chatWindow, false)
		end)

		local scrollFeed = Instance.new("ScrollingFrame", chatWindow)
		scrollFeed.Position = UDim2.new(0, 7, 0, 34)
		scrollFeed.Size = UDim2.new(1, -14, 1, -68)
		scrollFeed.BackgroundTransparency = 1
		scrollFeed.ScrollBarThickness = 2
		scrollFeed.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 52)
		scrollFeed.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scrollFeed.CanvasSize = UDim2.new(0, 0, 0, 0)

		local feedLayout = Instance.new("UIListLayout", scrollFeed)
		feedLayout.Padding = UDim.new(0, 5)
		feedLayout.SortOrder = Enum.SortOrder.LayoutOrder

		local footer = Instance.new("Frame", chatWindow)
		footer.Position = UDim2.new(0, 7, 1, -30)
		footer.Size = UDim2.new(1, -14, 0, 24)
		footer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		Instance.new("UICorner", footer).CornerRadius = UDim.new(0, 5)
		local footerStr = Instance.new("UIStroke", footer)
		footerStr.Color = Color3.fromRGB(38, 38, 44)

		local inputTxt = Instance.new("TextBox", footer)
		inputTxt.Position = UDim2.new(0, 6, 0, 0)
		inputTxt.Size = UDim2.new(1, -40, 1, 0)
		inputTxt.BackgroundTransparency = 1
		inputTxt.PlaceholderText = "Ask AI or command engine..."
		inputTxt.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
		inputTxt.Text = ""
		inputTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
		inputTxt.Font = Enum.Font.Gotham
		inputTxt.TextSize = 10
		inputTxt.ClearTextOnFocus = false

		local sendBtn = Instance.new("TextButton", footer)
		sendBtn.Position = UDim2.new(1, -32, 0.5, -9)
		sendBtn.Size = UDim2.new(0, 28, 0, 18)
		sendBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		sendBtn.Text = "GO"
		sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		sendBtn.Font = Enum.Font.GothamMedium
		sendBtn.TextSize = 9
		Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 4)
		local sendStr = Instance.new("UIStroke", sendBtn)
		sendStr.Color = Color3.fromRGB(50, 50, 58)

		local isBusy = false

		local function addBubble(sender, text)
			local isUser = sender == "You"
			local wrap = Instance.new("Frame", scrollFeed)
			wrap.Size = UDim2.new(1, 0, 0, 0)
			wrap.AutomaticSize = Enum.AutomaticSize.Y
			wrap.BackgroundTransparency = 1

			local card = Instance.new("Frame", wrap)
			card.Size = UDim2.new(0, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.XY
			card.Position = isUser and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
			card.AnchorPoint = isUser and Vector2.new(1, 0) or Vector2.new(0, 0)
			card.BackgroundColor3 = isUser and Color3.fromRGB(35, 35, 42) or Color3.fromRGB(25, 25, 30)
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

			local maxC = Instance.new("UISizeConstraint", card)
			maxC.MaxSize = Vector2.new(220, 9999)

			local pad = Instance.new("UIPadding", card)
			pad.PaddingTop = UDim.new(0, 5)
			pad.PaddingBottom = UDim.new(0, 5)
			pad.PaddingLeft = UDim.new(0, 8)
			pad.PaddingRight = UDim.new(0, 8)

			local list = Instance.new("UIListLayout", card)
			list.Padding = UDim.new(0, 2)

			local tag = Instance.new("TextLabel", card)
			tag.BackgroundTransparency = 1
			tag.Size = UDim2.new(0, 0, 0, 0)
			tag.AutomaticSize = Enum.AutomaticSize.XY
			tag.Text = ""
			tag.TextColor3 = Color3.fromRGB(0, 255, 200)
			tag.Font = Enum.Font.GothamMedium
			tag.TextSize = 9
			tag.Visible = false

			local bodyLbl = Instance.new("TextLabel", card)
			bodyLbl.BackgroundTransparency = 1
			bodyLbl.Size = UDim2.new(0, 0, 0, 0)
			bodyLbl.AutomaticSize = Enum.AutomaticSize.XY
			bodyLbl.Text = text
			bodyLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
			bodyLbl.Font = Enum.Font.Gotham
			bodyLbl.TextSize = 11
			bodyLbl.TextWrapped = true
			bodyLbl.TextXAlignment = Enum.TextXAlignment.Left

			scrollFeed.CanvasPosition = Vector2.new(0, 9999)
			return bodyLbl, tag
		end

		addBubble("System", "AI Agent connected. Command physics or search.")

		local function handleSend()
			local prompt = inputTxt.Text:match("^%s*(.-)%s*$")
			if prompt == "" or isBusy then return end

			inputTxt.Text = ""
			isBusy = true
			sendBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)

			addBubble("You", prompt)
			local aiLbl, tagLbl = addBubble("AI", ".")

			task.spawn(function()
				local dotCount = 0
				while isBusy do
					dotCount = (dotCount % 3) + 1
					aiLbl.Text = string.rep(".", dotCount)
					task.wait(0.3)
				end
			end)

			task.spawn(function()
				local okRun, reply = pcall(runAgentLoop, prompt, function(st)
					statusLbl.Text = st:lower()
				end, function(kind, val)
					if kind == "call" then
						tagLbl.Text = "[" .. tostring(val) .. "]"
						tagLbl.Visible = true
					elseif kind == "think" then
						tagLbl.Text = "[ thinking ]"
						tagLbl.Visible = true
					end
				end)

				isBusy = false
				statusLbl.Text = "ready"
				sendBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
				tagLbl.Visible = false

				local resText = okRun and tostring(reply or "No response.") or ("Error: " .. tostring(reply))
				resText = resText:gsub("```%w*", ""):gsub("```", ""):gsub("`", ""):gsub("%*%*", "")

				local len = #resText
				local step = math.max(1, math.floor(len / 30))
				for idx = 1, len, step do
					aiLbl.Text = resText:sub(1, idx)
					scrollFeed.CanvasPosition = Vector2.new(0, 9999)
					task.wait(0.015)
				end
				aiLbl.Text = resText
				scrollFeed.CanvasPosition = Vector2.new(0, 9999)
			end)
		end

		sendBtn.MouseButton1Click:Connect(handleSend)
		inputTxt.FocusLost:Connect(function(ep) if ep then handleSend() end end)

		animateWindow(chatWindow, true)
	end

	local circleWidget = nil
	function windowController.ensureFloatingWidget(parentGui)
		if circleWidget and circleWidget.Parent then return circleWidget end
		circleWidget = Instance.new("TextButton", parentGui)
		circleWidget.Name = "AI_Circle_Toggle"
		circleWidget.Size = UDim2.new(0, 36, 0, 36)
		circleWidget.Position = UDim2.new(1, -48, 0.5, -18)
		circleWidget.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
		circleWidget.Text = "AI"
		circleWidget.TextColor3 = Color3.fromRGB(255, 255, 255)
		circleWidget.Font = Enum.Font.GothamBold
		circleWidget.TextSize = 11
		circleWidget.Active = true
		circleWidget.Draggable = true
		circleWidget.ZIndex = 100
		Instance.new("UICorner", circleWidget).CornerRadius = UDim.new(0.5, 0)
		local str = Instance.new("UIStroke", circleWidget)
		str.Color = Color3.fromRGB(45, 45, 52)
		str.Thickness = 1

		circleWidget.MouseButton1Click:Connect(function()
			windowController.toggle(parentGui)
		end)
		return circleWidget
	end

	function windowController.toggle(parentGui)
		windowController.ensureFloatingWidget(parentGui)
		local isAuthenticated = persistLoad()
		if isAuthenticated then
			windowController.openChat(parentGui)
		else
			windowController.openAuth(parentGui, function()
				windowController.openChat(parentGui)
			end)
		end
	end

	return windowController
end
