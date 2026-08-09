-- Throwaway harness: loads every ai/ module through a stubbed Roblox env to prove
-- the require graph resolves and no module errors at load time.
local function stub_index(name)
	return setmetatable({}, {
		__index = function(_, k) return setmetatable({}, { __tostring = function() return name .. "." .. tostring(k) end }) end
	})
end

Color3 = { fromRGB = function() return "Color3" end }
Vector2 = { new = function() return "Vector2" end }
Vector3 = { new = function() return "Vector3" end }
UDim = { new = function() return "UDim" end }
UDim2 = { new = function() return "UDim2" end }
TweenInfo = { new = function() return "TweenInfo" end }
Enum = setmetatable({}, { __index = function(_, k) return stub_index("Enum." .. k) end })

-- Scripted JSON decode: the agent loop's only real dependency on HttpService is
-- decoding the response body, so tests queue decoded payloads here.
local decode_queue = {}
local encoded_bodies = {}

-- Every unknown member resolves to a callable that returns another stub, so
-- chained Roblox calls like v6:Create(...):Play() and :Connect() work.
local function new_instance()
	local props = {}
	local inst
	local chain
	chain = setmetatable({}, {
		__index = function() return chain end,
		__call = function() return chain end
	})
	inst = setmetatable({}, {
		__index = function(_, k)
			if props[k] ~= nil then return props[k] end
			if k == "GetChildren" then return function() return {} end end
			if k == "FindFirstChild" then return function() return nil end end
			if k == "IsA" then return function() return true end end
			return chain
		end,
		__newindex = function(_, k, v) props[k] = v end
	})
	return inst
end
Instance = { new = function() return new_instance() end }

-- spawn runs the body immediately: execute_script's watchdog polls a flag the
-- spawned thread sets, so a no-op stub would make every exec look timed out.
task = {
	spawn = function(fn, ...) fn(...) end,
	delay = function() end,
	wait = function() end
}
game = {
	GetService = function()
		return {
			JSONEncode = function(_, v)
				table.insert(encoded_bodies, v)
				-- Mimics the shape the real encoder produces for an empty table so
				-- the loop's '"properties":[]' fixup has something to match.
				return '{"properties":[]}'
			end,
			JSONDecode = function(_, body)
				-- The loop decodes two kinds of string: the response body (which the
				-- stubbed transport leaves empty) and each tool call's arguments.
				-- Only the former is scripted.
				if body ~= "" then return {} end
				local nxt = table.remove(decode_queue, 1)
				if nxt == nil then return {} end
				return nxt
			end,
			RequestAsync = function() return { StatusCode = 0, Body = "" } end,
			GetPlayers = function() return {} end
		}
	end,
	GetFullName = function() return "game" end,
	GetChildren = function() return {} end,
	FindFirstChild = function() return nil end
}

table.find = function(t, v)
	for i, x in ipairs(t) do if x == v then return i end end
	return nil
end
table.clear = function(t)
	for k in pairs(t) do t[k] = nil end
end

local function read_lua(path)
	local f = assert(io.open(path, "r"))
	local src = f:read("*a")
	f:close()
	-- LuaJIT has no compound assignment; Luau does.
	src = src:gsub("([%w_.]+) %+= ", "%1 = %1 + ")
	return src
end

local context = {
	v1 = new_instance(), v2 = new_instance(), v3 = new_instance(), v4 = new_instance(),
	v5 = new_instance(), v6 = new_instance(), v8 = new_instance(),
	x1 = { Targets = {}, k6 = "Celestial Ribbon" },
	x2 = { ["Celestial Ribbon"] = { k11 = 1 } },
	x6 = {},
	local_shapes = {},
	loaded_shapes = {},
	get_shape = function() return nil end,
	load_module = function(path)
		local chunk, err = loadstring(read_lua(path), path)
		if not chunk then error("syntax error in " .. path .. ": " .. tostring(err)) end
		return chunk()
	end
}

local entry = loadstring(read_lua("ai_chat.lua"), "ai_chat.lua")()
local controller = entry(context)

assert(type(controller.toggle) == "function", "missing toggle")
assert(type(controller.hide) == "function", "missing hide")
assert(type(controller.showWidget) == "function", "missing showWidget")
print("entry surface OK: toggle, hide, showWidget")

-- showWidget runs on every panel expand, including before the chat has ever been
-- opened. It must not error or force the UI modules to load. hide() is no longer
-- called on collapse -- the chat deliberately stays up -- but it remains public
-- API, so it still has to be safe to call cold.
controller.hide()
controller.showWidget()
print("hide/showWidget before first open OK")

-- Now drive the real open path, which pulls in the widget, auth and chat modules
-- and builds every instance.
local parentGui = new_instance()
controller.toggle(parentGui)
controller.hide()
controller.showWidget()
controller.toggle(parentGui)
print("toggle/hide/showWidget round trip OK")

-- Force every lazily-required module to load, then assert the tool registry.
local names = {
	"state", "net", "prompt", "freegate", "agent",
	"tools/init", "tools/web", "tools/roblox", "tools/files", "tools/engine",
	"ui/kit", "ui/auth", "ui/chat", "ui/transcript", "ui/composer", "ui/modelmenu", "ui/widget"
}

-- The entry point keeps env private, so rebuild an equivalent env to exercise the
-- same graph.
local env
env = {
	context = context,
	v1 = context.v1, v2 = context.v2, v3 = context.v3, v4 = context.v4,
	v5 = context.v5, v6 = context.v6, v8 = context.v8,
	hs = game:GetService("HttpService"),
	req_fn = nil
}
local cache = {}
function env.require(name)
	if cache[name] ~= nil then return cache[name] end
	local mod = context.load_module("ai/" .. name .. ".lua")(env)
	cache[name] = mod
	return mod
end

for _, n in ipairs(names) do
	local mod = env.require(n)
	assert(mod ~= nil, "nil module: " .. n)
	print("loaded " .. n)
end

local tools = env.require("tools/init")
local expected = {
	"web_search", "fetch_page", "roblox_version", "inspect_game", "execute_script",
	"save_script", "save_custom_shape", "read_custom_shape", "set_target",
	"get_gravity_state", "control_shape", "adjust_gravity"
}
for _, name in ipairs(expected) do
	assert(type(tools.handlers[name]) == "function", "missing handler: " .. name)
end
assert(#tools.definitions == #expected, ("definition count %d, expected %d"):format(#tools.definitions, #expected))
for _, def in ipairs(tools.definitions) do
	local f = def["function"]
	assert(def.type == "function" and f.name and f.description and f.parameters, "malformed definition")
	assert(f.parameters.type == "object" and f.parameters.properties and f.parameters.required, "bad schema: " .. tostring(f.name))
end
print(("tool registry OK: %d tools"):format(#tools.definitions))

-- Handlers that touch no network: verify they still read/write engine state.
print("get_gravity_state ->", tools.handlers.get_gravity_state())
print("control_shape ->", tools.handlers.control_shape({ key = "k11", val = 42 }))
assert(context.x2["Celestial Ribbon"].k11 == 42, "control_shape did not write x2")
print("control_shape bad key ->", tools.handlers.control_shape({ key = "nope", val = 1 }))
print("adjust_gravity ->", tools.handlers.adjust_gravity({
	speed = 500, damping = 2, target_all = true, anti_fling = true, paused = false
}))
assert(context.x1.MaxSpeed == 500 and context.x1.PI_All == true and context.x1.Paused == false, "adjust_gravity did not write x1")
assert(context.x1.AnchorSelf == false, "target_all did not clear anchor_self")
print("adjust_gravity empty ->", tools.handlers.adjust_gravity({}))
print("set_target clear ->", tools.handlers.set_target({ action = "clear" }))
print("read_custom_shape empty ->", tools.handlers.read_custom_shape({ name = "  " }))

-- adjust_gravity's disabled flag has to route through System, not write x1 raw.
local routed = false
context.x4 = { apply_disabled = function(val) routed = true; context.x1.Disabled = val end }
print("adjust_gravity disabled ->", tools.handlers.adjust_gravity({ disabled = true }))
assert(routed and context.x1.Disabled == true, "disabled did not route through x4.apply_disabled")
print("disabled routes through x4 OK")

-- Drive the agent loop against a scripted response: one tool call, then text.
local st = env.require("state")
local agent = env.require("agent")
st.session.mode = "key"
st.session.apiKey = "sk-test"

local net = env.require("net")
net.request = function() return { StatusCode = 200, Body = "" } end

decode_queue = {
	{ choices = { { message = { tool_calls = {
		{ id = "call_1", ["function"] = { name = "get_gravity_state", arguments = "{}" } }
	} } } } },
	{ choices = { { message = { content = "All set." } } } }
}

local statuses, steps = {}, {}
local reply = agent.run("test prompt",
	function(s) table.insert(statuses, s) end,
	function(kind, val) table.insert(steps, kind) end,
	function() return false end)

assert(reply == "All set.", "agent reply was: " .. tostring(reply))
assert(st.session.history[1].role == "system", "history missing system message")
assert(st.session.history[1].content:find("SK%-TEST") == nil, "api key leaked into system message")
assert(st.session.history[1].content:find("KEY%-TEST") == nil, "api key leaked into system message")
assert(st.session.history[1].content:find("CLAUDE%-OPUS%-5"), "model not stated in system message")
assert(st.session.history[2].content == "test prompt", "user message not recorded")
local sawTool = false
for _, m in ipairs(st.session.history) do
	if m.role == "tool" and m.tool_call_id == "call_1" then sawTool = true end
end
assert(sawTool, "tool result not appended to history")
assert(st.session.history[#st.session.history].content == "All set.", "assistant reply not appended")
local sawCall = false
for _, k in ipairs(steps) do if k == "call" then sawCall = true end end
assert(sawCall, "pushStep never reported the tool call")
assert(statuses[#statuses] == "Ready", "final status was: " .. tostring(statuses[#statuses]))
print(("agent loop OK: reply=%q, %d history entries, %d steps"):format(reply, #st.session.history, #steps))

-- Abort must short-circuit before any request.
st.session.history = {}
local aborted = agent.run("stop me", function() end, function() end, function() return true end)
assert(aborted == "Generation stopped by user.", "abort path returned: " .. tostring(aborted))
print("abort path OK")

-- A non-200 must surface as an error string rather than throwing.
st.session.history = {}
net.request = function() return { StatusCode = 401, Body = "" } end
local failed = agent.run("bad auth", function() end, function() end, function() return false end)
assert(failed:find("Request failed: 401"), "error path returned: " .. tostring(failed))
print("request failure path OK")

-- Free mode must hit the custom route and must NOT name a model: the plain
-- /free/v1/chat/completions path answers 400 for any model that isn't the
-- server's current default, which is what broke chat while logged in.
st.session.history = {}
st.session.mode = "free"
st.session.token = "payload.signature"
local seenPath, seenHeaders
net.request = function(path, _, headers)
	seenPath, seenHeaders = path, headers
	return { StatusCode = 200, Body = "" }
end
decode_queue = { { choices = { { message = { content = "free ok" } } } } }
table.clear(encoded_bodies)
local freeReply = agent.run("free prompt", function() end, function() end, function() return false end)
assert(freeReply == "free ok", "free mode reply was: " .. tostring(freeReply))
assert(seenPath == st.FREE_PATH, "free mode path was: " .. tostring(seenPath))
assert(seenPath == "/free/v1/projectai", "free path is not the custom route: " .. tostring(seenPath))
assert(seenHeaders and seenHeaders["Cookie"] == "aidavidcsl_session=payload.signature", "session cookie not sent in free mode")
assert(seenHeaders["Authorization"] == nil, "free mode must not send an Authorization header")
local freePayload = encoded_bodies[#encoded_bodies]
assert(type(freePayload) == "table", "no payload captured for free mode")
assert(freePayload.model == nil, "free mode must not send a model, got: " .. tostring(freePayload.model))
assert(freePayload.messages and freePayload.tools, "free mode payload lost messages or tools")
-- The prompt body itself mentions the words "YOUR MODEL IS", so this checks the
-- injected header specifically rather than any occurrence of the phrase.
assert(st.session.history[1].content:sub(1, 15) ~= "(YOUR MODEL IS ", "free mode system prompt should not claim a model")
print("free mode uses custom route with no model OK")

-- Key mode still names its model and still uses the caller-key path.
st.session.history = {}
st.session.mode = "key"
st.session.apiKey = "sk-test"
decode_queue = { { choices = { { message = { content = "key ok" } } } } }
table.clear(encoded_bodies)
local keyReply = agent.run("key prompt", function() end, function() end, function() return false end)
assert(keyReply == "key ok", "key mode reply was: " .. tostring(keyReply))
assert(seenPath == st.KEY_PATH, "key mode path was: " .. tostring(seenPath))
assert(seenHeaders["Authorization"] == "Bearer sk-test", "key mode lost its Authorization header")
assert(seenHeaders["Cookie"] == nil, "key mode must not send a session cookie")
local keyPayload = encoded_bodies[#encoded_bodies]
assert(keyPayload.model == "claude-opus-5", "key mode model was: " .. tostring(keyPayload.model))
assert(st.session.history[1].content:sub(1, 15) == "(YOUR MODEL IS ", "key mode system prompt lost its model line")
assert(st.session.history[1].content:find("CLAUDE%-OPUS%-5"), "key mode system prompt lost its model name")
print("key mode still sends model and caller key OK")

-- Set-Cookie parsing. The token is a payload.signature pair and the header
-- carries attributes after it, so the value must stop at the first semicolon.
local REAL_COOKIE = "eyJleHAiOjE3MzAwfQ.abc-_123"
assert(st.readSessionCookie("aidavidcsl_session=" .. REAL_COOKIE .. "; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=43200") == REAL_COOKIE, "did not parse the token out of a full Set-Cookie header")
assert(st.readSessionCookie("aidavidcsl_session=" .. REAL_COOKIE) == REAL_COOKIE, "did not parse a bare cookie")
assert(st.readSessionCookie("other=1; aidavidcsl_session=" .. REAL_COOKIE .. "; x=2") == REAL_COOKIE, "did not find the cookie among others")
assert(st.readSessionCookie("aidavidcsl_session=; Max-Age=0") == nil, "a cleared cookie must not count as a token")
assert(st.readSessionCookie("someother_session=abc") == nil, "matched the wrong cookie name")
assert(st.readSessionCookie(nil) == nil, "nil header must yield no token")
assert(st.readSessionCookie(42) == nil, "non-string header must yield no token")
print("Set-Cookie parsing OK")

-- Header lookup must be case-insensitive: RequestAsync and the executors
-- disagree on casing, and some hand back a list of values.
assert(net.header({ Headers = { ["Set-Cookie"] = "a=1" } }, "Set-Cookie") == "a=1", "exact-case lookup failed")
assert(net.header({ Headers = { ["set-cookie"] = "a=1" } }, "Set-Cookie") == "a=1", "lowercase lookup failed")
assert(net.header({ Headers = { ["SET-COOKIE"] = { "a=1", "b=2" } } }, "Set-Cookie") == "a=1", "list-valued header lookup failed")
assert(net.header({ Headers = {} }, "Set-Cookie") == nil, "missing header should be nil")
assert(net.header({}, "Set-Cookie") == nil, "absent Headers table should be nil")
assert(net.header(nil, "Set-Cookie") == nil, "nil response should be nil")
print("case-insensitive header lookup OK")

-- An expired session must clear the saved credentials and hand back to the UI
-- rather than failing forever with the dead token still on disk.
st.session.history = {}
st.session.mode = "free"
st.session.token = REAL_COOKIE
local reprompted = false
agent.onSessionExpired = function() reprompted = true end
net.request = function() return { StatusCode = 401, Body = "" } end
local expired = agent.run("stale", function() end, function() end, function() return false end)
assert(expired == "Session expired. Please log in again.", "401 path returned: " .. tostring(expired))
assert(st.session.token == "", "expired token was not cleared")
assert(st.session.mode == "", "expired session kept its mode")
assert(reprompted, "onSessionExpired was never called")
print("expired session clears credentials and re-prompts OK")

-- A 401 in key mode is a bad API key, not a stale cookie: it must report
-- normally instead of silently wiping the key.
st.session.history = {}
st.session.mode = "key"
st.session.apiKey = "sk-bad"
reprompted = false
local keyFail = agent.run("bad key", function() end, function() end, function() return false end)
assert(keyFail:find("Request failed: 401"), "key mode 401 returned: " .. tostring(keyFail))
assert(st.session.apiKey == "sk-bad", "key mode 401 must not clear the API key")
assert(not reprompted, "key mode 401 must not trigger the session-expired path")
print("key mode 401 reports normally OK")

-- Roblox's HttpService strips Set-Cookie and executors differ, so a login the
-- server accepted must still succeed with no cookie to read: the window closes
-- and the session is usable. This is what broke the login UI when the token was
-- briefly made mandatory.
assert(st.readSessionCookie(net.header({ Headers = nil }, "Set-Cookie")) == nil, "a cookie-less response should yield no token")
-- load()/save() need executor file functions; back them with an in-memory file.
local fakeFiles = {}
writefile = function(path, body) fakeFiles[path] = body end
readfile = function(path) return fakeFiles[path] end
isfile = function(path) return fakeFiles[path] ~= nil end
st.session.mode = "free"
st.session.token = st.readSessionCookie(net.header({ Headers = nil }, "Set-Cookie")) or ""
assert(st.session.token == "", "cookie-less login should leave an empty token")
st.save()
assert(fakeFiles[st.AUTH_FILE], "save() wrote nothing")
print("cookie-less login stays logged in OK")

-- The harness's JSONDecode is scripted for the agent loop and returns {} for any
-- body, which would make load() fall back to mode="free" and pass regardless of
-- what was saved. Swap in a real encode/decode for the flat auth object so the
-- round trip below actually proves something, then restore.
local prevEncode, prevDecode = env.hs.JSONEncode, env.hs.JSONDecode
env.hs.JSONEncode = function(_, v)
    local parts = {}
    for k, val in pairs(v) do
        table.insert(parts, ('"%s":"%s"'):format(k, tostring(val)))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
env.hs.JSONDecode = function(_, body)
    local out = {}
    for k, val in body:gmatch('"([^"]+)":"([^"]*)"') do out[k] = val end
    return out
end

-- The free gate (status.txt = true) skips the auth wall entirely, so load()
-- reports logged in whatever is on disk. With the gate off, key mode still has
-- to have its key or a blank auth file would read as valid.
local gate = env.require("freegate")
local gateWas = gate.active
gate.active = false

st.session.mode = "free"
st.session.token = ""
st.save()
st.session.mode = ""
assert(st.load(), "gate off: a free session with no token must count as logged in")
assert(st.session.mode == "free", "free mode did not survive the round trip")

st.session.mode = "key"
st.session.apiKey = ""
st.save()
st.session.mode = ""
assert(not st.load(), "key mode with no API key must not count as logged in")
assert(st.session.mode == "key", "key mode did not survive the round trip")

st.session.mode = "key"
st.session.apiKey = "sk-real"
st.save()
assert(st.load(), "key mode with a key must count as logged in")

gate.active = true
st.session.mode = "key"
st.session.apiKey = ""
st.save()
assert(st.load(), "free gate must skip the auth wall regardless of stored mode")
assert(st.session.mode == "free", "free gate should force free mode")

gate.active = gateWas
env.hs.JSONEncode, env.hs.JSONDecode = prevEncode, prevDecode
print("free gate overrides the auth wall OK")

-- With no token stored, a 401 is the route rejecting the server's own key, not
-- a lapsed session: logging the user out would loop them through a login that
-- cannot fix it.
st.session.history = {}
st.session.mode = "free"
st.session.token = ""
reprompted = false
net.request = function() return { StatusCode = 401, Body = "" } end
local noTokenFail = agent.run("no token", function() end, function() end, function() return false end)
assert(noTokenFail:find("Request failed: 401"), "tokenless 401 returned: " .. tostring(noTokenFail))
assert(st.session.mode == "free", "tokenless 401 must not clear the session")
assert(not reprompted, "tokenless 401 must not trigger the session-expired path")
print("tokenless free-mode 401 does not log out OK")

-- Reply text goes into a wrapped, auto-sized label, so any leading blank line
-- renders as empty rows above the message. Reasoning models open with them and
-- stripping a ```lua fence leaves one behind, which is what put the gap at the
-- top of the reply bubble.
local kit = env.require("ui/kit")
local stripCases = {
    { "\n\nHello! How can I help you with Project Gravity today?", "Hello! How can I help you with Project Gravity today?", "leading blank lines" },
    { "\n\n\n\nHi", "Hi", "many leading newlines" },
    { "```lua\nprint(1)\n```", "print(1)", "fence leaves newlines" },
    { "\r\n\r\nWindows newlines", "Windows newlines", "CRLF" },
    { "Text   \n\n\n\nMore", "Text\n\nMore", "collapse blank runs and trailing spaces" },
    { "## Heading\nBody", "Heading\nBody", "leading heading" },
    { "Intro\n### Mid\nBody", "Intro\nMid\nBody", "heading past line one" },
    { "  \n \t \n ", "", "whitespace only collapses to empty" },
    { "**bold** and `code`", "bold and code", "inline markers" },
    { "Keep\ninternal\nsingle breaks", "Keep\ninternal\nsingle breaks", "single newlines preserved" },
    { 42, "", "non-string" }
}
for _, case in ipairs(stripCases) do
    local got = kit.stripMarkdown(case[1])
    assert(got == case[2], ("stripMarkdown %s: got %q, expected %q"):format(case[3], got, case[2]))
end
-- The composer's fallback fires on an empty result, and the typing animation
-- slices by byte, so index 1 must already be a visible character.
assert(kit.stripMarkdown("\n\n\n"):match("^%s*$"), "an all-whitespace reply must still hit the fallback")
assert(kit.stripMarkdown("\n\nHi"):sub(1, 1) == "H", "first typed byte must be visible text")
print(("stripMarkdown OK: %d cases"):format(#stripCases))

-- execute_script used to run generated code inline, so `while true do end` froze
-- the client with no way out. Bare infinite loops are rewritten to yield, which
-- is what lets the watchdog and the Stop button reach them at all.
local exec = tools.handlers.execute_script
assert(type(exec) == "function", "execute_script handler missing")
assert(exec({ code = "" }):find("empty"), "empty code should be rejected")

-- Assert the rewrite without ever running an endless loop: task.wait is a no-op
-- here and spawn is synchronous, so executing one would hang this process --
-- which is the very failure being fixed. Compiling proves the result is valid
-- Luau; a stub loadstring captures the transformed source without running it.
local seen
local realLoadstring = loadstring
loadstring = function(src, ...) seen = src; return function() end end

local rewrites = {
	{ "while true do end", "while true do task.wait() end", "bare while-true" },
	{ "while  true  do  end", "while true do task.wait() end", "while-true with extra spacing" },
	{ "repeat until false", "repeat task.wait() until false", "bare repeat-until-false" },
	{ "while true do task.wait(1) print('x') end", nil, "loop that already yields" },
	{ "for i = 1, 3 do print(i) end", nil, "counted loop" },
	{ "print('hi')", nil, "no loop at all" }
}
for _, case in ipairs(rewrites) do
	seen = nil
	exec({ code = case[1] })
	local want = case[2] or case[1]
	assert(seen == want, ("%s: got %q, expected %q"):format(case[3], tostring(seen), want))
	assert(realLoadstring(seen), "rewrite produced invalid Luau for " .. case[3])
end
loadstring = realLoadstring
print(("execute_script loop guard OK: %d cases"):format(#rewrites))

-- Normal code still runs, reports its return value and captures print output.
local okRes = exec({ code = "print('hello') return 7" })
assert(okRes:find("Success"), "normal exec did not succeed: " .. tostring(okRes))
assert(okRes:find("hello"), "print output was not captured: " .. tostring(okRes))
assert(okRes:find("7"), "return value was not reported: " .. tostring(okRes))
assert(exec({ code = "error('boom')" }):find("Runtime error"), "runtime errors should be reported")
assert(exec({ code = "this is not lua" }):find("Compile error"), "compile errors should be reported")
print("execute_script reporting OK")

print("ALL CHECKS PASSED")
