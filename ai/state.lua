-- Session state, persisted credentials and model list for the AI chat.
return function(env)
	local hs = env.hs

	local M = {}

	M.AUTH_DIR = "ProjectAI"
	M.AUTH_FILE = "ProjectAI/auth.json"
	M.REF_LINK = "https://agentrouter.org/register?aff=4pqF"
	M.DEFAULT_ENDPOINT = "https://ai.davidcsl.me"
	-- Free mode uses the server's custom route: it carries its own upstream and
	-- key, and unlike /free/v1/chat/completions it does not reject requests whose
	-- model differs from the operator's current default.
	M.FREE_PATH = "/free/v1/projectai"
	M.KEY_PATH = "/key/v1/chat/completions"
	M.SESSION_COOKIE = "aidavidcsl_session"
	M.MODELS = {
		"claude-opus-5",
		"gpt-5.6-sol"
	}

	-- Pulls the session value out of a Set-Cookie header. The token is a
	-- payload.signature pair, so it contains dots and base64url characters but
	-- never a semicolon, which is what ends the value.
	function M.readSessionCookie(raw)
		if type(raw) ~= "string" then return nil end
		local value = raw:match(M.SESSION_COOKIE .. "=([^;]+)")
		if not value then return nil end
		value = value:match("^%s*(.-)%s*$")
		-- A cleared cookie (logout) comes back empty; treat that as no token.
		if value == "" then return nil end
		return value
	end

	M.session = {
		mode = "free",
		token = "",
		apiKey = "",
		endpoint = M.DEFAULT_ENDPOINT,
		model = M.MODELS[1],
		history = {}
	}

	-- The prompt is a large blob that is only needed once a message is actually
	-- sent, so it stays behind a lazy require instead of loading with the panel.
	-- In free mode the server chooses the model, so claiming one here would just
	-- state something that may well be wrong.
	function M.systemContent()
		local prompt = env.require("prompt").text
		if M.session.mode == "free" then return prompt end
		return "(YOUR MODEL IS " .. tostring(M.session.model):upper() .. ")\n" .. prompt
	end

	-- Sessions expire server-side after 12h, and the token is persisted, so a
	-- stale one would otherwise 401 on every message with no way back to the
	-- login window. Callers drop the credentials and re-prompt.
	function M.clearCredentials()
		M.session.mode = ""
		M.session.token = ""
		M.session.apiKey = ""
		M.session.history = {}
		M.save()
	end

	function M.save()
		if type(writefile) ~= "function" then return end
		if type(makefolder) == "function" then
			local okFolder = pcall(function() return type(isfolder) == "function" and isfolder(M.AUTH_DIR) end)
			if not okFolder then pcall(makefolder, M.AUTH_DIR) end
		end
		local data = {
			mode = M.session.mode,
			token = M.session.token,
			apiKey = M.session.apiKey,
			model = M.session.model
		}
		pcall(writefile, M.AUTH_FILE, hs:JSONEncode(data))
	end

	function M.load()
		if env.require("freegate").active then
			M.session.mode = "free"
			return true
		end
		if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
		local ok, exists = pcall(isfile, M.AUTH_FILE)
		if not ok or not exists then return false end
		local okRead, content = pcall(readfile, M.AUTH_FILE)
		if not okRead or not content or content == "" then return false end
		local okDec, decoded = pcall(function() return hs:JSONDecode(content) end)
		if okDec and type(decoded) == "table" then
			M.session.mode = decoded.mode or "free"
			M.session.token = decoded.token or ""
			M.session.apiKey = decoded.apiKey or ""
			M.session.model = (decoded.model and table.find(M.MODELS, decoded.model)) and decoded.model or M.MODELS[1]
			-- A free session counts as logged in even with an empty token: the
			-- transport often cannot read Set-Cookie, and routes open to "Anyone"
			-- never ask for one. Key mode still needs its key.
			return M.session.mode == "free" or (M.session.mode == "key" and #M.session.apiKey > 0)
		end
		return false
	end

	return M
end
