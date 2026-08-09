-- The tool-calling loop: send history, run any requested tools, repeat until the
-- model answers with plain text.
local MAX_TURNS = 40
local HISTORY_LIMIT = 12
local HISTORY_KEEP = 10
local REPEAT_LIMIT = 3
local RESULT_CAP = 1500

return function(env)
	local hs = env.hs
	local net = env.require("net")
	local st = env.require("state")

	local function summarizeArgs(tbl)
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

	local function trimHistory(session)
		if #session.history <= HISTORY_LIMIT then return end
		local trimmed = { session.history[1] }
		for i = #session.history - (HISTORY_KEEP - 1), #session.history do
			table.insert(trimmed, session.history[i])
		end
		session.history = trimmed
	end

	-- Free mode goes through the server's custom route, which supplies the model
	-- and the key upstream. The plain /free/v1/chat/completions path instead
	-- rejects any model that isn't the operator's current default with a 400, so
	-- picking a model here used to break the moment the server default moved.
	local function authHeaders(session)
		local headers = { ["Content-Type"] = "application/json" }
		if session.mode == "free" then
			if #session.token > 0 then
				headers["Cookie"] = st.SESSION_COOKIE .. "=" .. session.token
			end
			return st.FREE_PATH, headers
		end
		headers["Authorization"] = "Bearer " .. session.apiKey
		headers["x-api-key"] = session.apiKey
		return st.KEY_PATH, headers
	end

	local M = {}

	function M.run(prompt, updateStatus, pushStep, checkAborted)
		pushStep = pushStep or function() end
		local session = st.session
		local tools = env.require("tools/init")

		if #session.history == 0 then
			table.insert(session.history, { role = "system", content = st.systemContent() })
		end
		table.insert(session.history, { role = "user", content = prompt })
		trimHistory(session)

		local count = 0
		local lastSig, streak = "", 0

		while count < MAX_TURNS do
			if checkAborted and checkAborted() then
				updateStatus("aborted")
				return "Generation stopped by user."
			end
			count += 1
			updateStatus("Thinking...")

			local payload = {
				messages = session.history,
				tools = tools.definitions,
				max_tokens = 2048
			}
			-- Only key mode names a model; in free mode the server decides.
			if session.mode ~= "free" then
				payload.model = session.model
			end

			-- Empty Luau tables encode as [], which the API rejects for properties.
			local bodyJson = hs:JSONEncode(payload):gsub('"properties":%[%]', '"properties":{}')
			local endpointPath, reqHeaders = authHeaders(session)

			local res, err = net.request(endpointPath, "POST", reqHeaders, bodyJson)
			if not res or res.StatusCode ~= 200 then
				updateStatus("Error")
				-- A signed-in route answers 401 once the 12h session lapses. The
				-- saved token is dead at that point, so drop it and let the caller
				-- put the login window back up rather than failing forever. Only
				-- when a token was actually stored: with no cookie to blame, a 401
				-- is the route rejecting the server's own key, and logging the user
				-- out would just loop them through a login that cannot help.
				if res and res.StatusCode == 401 and session.mode == "free" and #session.token > 0 then
					st.clearCredentials()
					if M.onSessionExpired then M.onSessionExpired() end
					return "Session expired. Please log in again."
				end
				return "Request failed: " .. tostring(res and res.StatusCode or err)
			end

			local ok, decoded = pcall(function() return hs:JSONDecode(res.Body) end)
			if not ok or type(decoded) ~= "table" or not decoded.choices or not decoded.choices[1] then
				updateStatus("Error")
				return "Invalid JSON response"
			end

			local choiceMsg = decoded.choices[1].message
			if not (choiceMsg.tool_calls and type(choiceMsg.tool_calls) == "table" and #choiceMsg.tool_calls > 0) then
				local text = choiceMsg.content or "Done."
				table.insert(session.history, { role = "assistant", content = text })
				updateStatus("Ready")
				return text
			end

			table.insert(session.history, choiceMsg)
			if choiceMsg.content and choiceMsg.content ~= "" then
				pushStep("think", choiceMsg.content)
			end

			for _, call in ipairs(choiceMsg.tool_calls) do
				if checkAborted and checkAborted() then
					updateStatus("aborted")
					return "Generation stopped by user."
				end
				local name = call["function"].name
				local argsRaw = call["function"].arguments or "{}"
				local okArgs, argsParsed = pcall(function() return hs:JSONDecode(argsRaw) end)
				argsParsed = okArgs and argsParsed or {}

				local argStr = summarizeArgs(argsParsed)
				updateStatus("Running " .. tostring(name))
				pushStep("call", tostring(name) .. (argStr ~= "" and (" " .. argStr) or ""))

				local sig = tostring(name) .. ":" .. tostring(argsRaw)
				if sig == lastSig then streak += 1 else lastSig = sig; streak = 1 end

				local resultText
				if streak >= REPEAT_LIMIT then
					resultText = "Repeated tool call rejected."
				else
					local fn = tools.handlers[name]
					if fn then
						local okFn, resFn = pcall(fn, argsParsed)
						resultText = okFn and tostring(resFn) or ("Error: " .. tostring(resFn))
					else
						resultText = "Unknown tool: " .. tostring(name)
					end
				end

				if #resultText > RESULT_CAP then resultText = resultText:sub(1, RESULT_CAP) .. "\n...[truncated]" end
				pushStep("result", resultText)

				table.insert(session.history, {
					role = "tool",
					tool_call_id = call.id,
					content = resultText
				})
			end
		end

		updateStatus("Ready")
		return "Maximum iteration limit reached."
	end

	return M
end
