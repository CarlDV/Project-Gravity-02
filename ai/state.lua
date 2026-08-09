-- Session state, persisted credentials and model list for the AI chat.
return function(env)
	local hs = env.hs

	local M = {}

	M.AUTH_DIR = "ProjectAI"
	M.AUTH_FILE = "ProjectAI/auth.json"
	M.REF_LINK = "https://agentrouter.org/register?aff=4pqF"
	M.DEFAULT_ENDPOINT = "https://ai.davidcsl.me"
	M.MODELS = {
		"claude-opus-5",
		"gpt-5.6-sol"
	}

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
	function M.systemContent()
		return "(YOUR MODEL IS " .. tostring(M.session.model):upper() .. ")\n" .. env.require("prompt").text
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
			return (M.session.mode == "free" and #M.session.token > 0) or (M.session.mode == "key" and #M.session.apiKey > 0)
		end
		return false
	end

	return M
end
