-- AI chat entry point. Owns nothing but the module loader and the public surface
-- UI.lua calls (toggle / hide / showWidget); everything else lives under ai/.
local MODULE_DIR = "ai/"

return function(context)
	local env = {
		context = context,
		v1 = context.v1,
		v2 = context.v2,
		v3 = context.v3,
		v4 = context.v4,
		v5 = context.v5,
		v6 = context.v6,
		v8 = context.v8,
		hs = game:GetService("HttpService"),
		req_fn = request or (http and http.request) or http_request or (fluxus and fluxus.request) or (syn and syn.request)
	}

	-- Submodules are fetched on first use and cached. Each returns a factory taking
	-- this env, so any module can pull in a sibling without load-order rules.
	local cache = {}
	function env.require(name)
		local hit = cache[name]
		if hit ~= nil then return hit end
		local builder = context.load_module(MODULE_DIR .. name .. ".lua")
		if type(builder) ~= "function" then
			error("AI module failed to load: " .. name)
		end
		local mod = builder(env)
		if mod == nil then
			error("AI module returned nothing: " .. name)
		end
		cache[name] = mod
		return mod
	end

	env.require("freegate").notify()

	local windowController = {}

	-- The UI modules are only fetched when the panel is actually opened, so the
	-- cost of a user who never touches the chat stays at this one file. hide() and
	-- showWidget() run on every panel collapse, so they must not force that fetch:
	-- they check the cache instead of requiring.
	local function loaded(name)
		return cache[name]
	end

	local function openChat(parentGui)
		env.require("ui/chat").open(parentGui, function()
			env.require("ui/auth").open(parentGui, function()
				openChat(parentGui)
			end)
		end)
	end

	function windowController.toggle(parentGui)
		env.require("ui/widget").ensure(parentGui, function()
			windowController.toggle(parentGui)
		end)
		if env.require("state").load() then
			openChat(parentGui)
		else
			env.require("ui/auth").open(parentGui, function()
				openChat(parentGui)
			end)
		end
	end

	-- Called when the main panel collapses to its pill. These windows and the
	-- floating widget are siblings of the panel rather than children, so nothing
	-- about minimizing reaches them on its own -- they used to be left hanging in
	-- the middle of the screen next to a 44px pill. Only hides: the session and
	-- the chat history live on these instances, so tearing them down would lose
	-- the conversation every time the panel was minimized.
	function windowController.hide()
		local chat = loaded("ui/chat")
		if chat then chat.hide() end
		local auth = loaded("ui/auth")
		if auth then auth.hide() end
		local widget = loaded("ui/widget")
		if widget then widget.setVisible(false) end
	end

	function windowController.showWidget()
		local widget = loaded("ui/widget")
		if widget then widget.setVisible(true) end
	end

	return windowController
end
