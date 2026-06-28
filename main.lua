--!native

local function safe_service(name)
	local service = game:GetService(name)
	if cloneref then
		return cloneref(service)
	end
	return service
end

local v1, v2, v3, v4, v5, v6, v7 =
	safe_service("UserInputService"),
	safe_service("Players"),
	safe_service("RunService"),
	safe_service("Workspace"),
	safe_service("StarterGui"),
	safe_service("TweenService"),
	safe_service("ContextActionService")
local HttpService = safe_service("HttpService")

if setthreadidentity then
	pcall(function()
		setthreadidentity(8)
	end)
end

local function cleanup_previous()
	if gethui then
		for _, gui in ipairs(gethui():GetChildren()) do
			if gui:IsA("ScreenGui") and (gui.Name == "GravityLoading" or string.sub(gui.Name, 1, 2) == "G_") then
				pcall(function() gui:Destroy() end)
			end
		end
	elseif syn and syn.protect_gui then
		local core = game:GetService("CoreGui")
		for _, gui in ipairs(core:GetChildren()) do
			if gui:IsA("ScreenGui") and (gui.Name == "GravityLoading" or string.sub(gui.Name, 1, 2) == "G_") then
				pcall(function() gui:Destroy() end)
			end
		end
	else
		local pg = v2.LocalPlayer:FindFirstChild("PlayerGui")
		if pg then
			for _, gui in ipairs(pg:GetChildren()) do
				if gui:IsA("ScreenGui") and (gui.Name == "GravityLoading" or string.sub(gui.Name, 1, 2) == "G_") then
					pcall(function() gui:Destroy() end)
				end
			end
		end
	end
end
cleanup_previous()

local v8, v9 = v2.LocalPlayer, v2.LocalPlayer:GetMouse()
local is_mobile = v1.TouchEnabled and not v1.KeyboardEnabled
local SUB_DIR = is_mobile and "mobilever/" or ""

local loading_sg = Instance.new("ScreenGui")
loading_sg.Name = "GravityLoading"
loading_sg.DisplayOrder = 99999
loading_sg.IgnoreGuiInset = true
if gethui then
	loading_sg.Parent = gethui()
elseif syn and syn.protect_gui then
	syn.protect_gui(loading_sg)
	loading_sg.Parent = game:GetService("CoreGui")
else
	loading_sg.Parent = v8:WaitForChild("PlayerGui")
end
local spinner = Instance.new("Frame", loading_sg)
spinner.Size = UDim2.new(0, 36, 0, 36)
spinner.Position = UDim2.new(0.5, -18, 0.5, -18)
spinner.BackgroundTransparency = 1
local uic = Instance.new("UICorner", spinner)
uic.CornerRadius = UDim.new(1, 0)
local uis = Instance.new("UIStroke", spinner)
uis.Thickness = 3
uis.Color = Color3.fromRGB(255, 255, 255)
local uig = Instance.new("UIGradient", uis)
uig.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1)
})
local spin_t = 0
local spin_conn = v3.RenderStepped:Connect(function(dt)
	spin_t = spin_t + dt
	spinner.Rotation = spin_t * 400
end)

local loading_text = Instance.new("TextLabel", loading_sg)
loading_text.Size = UDim2.new(0, 100, 0, 20)
loading_text.Position = UDim2.new(0.5, -50, 0.5, 25)
loading_text.BackgroundTransparency = 1
loading_text.Text = "LOADING..."
loading_text.TextColor3 = Color3.fromRGB(200, 200, 200)
loading_text.Font = Enum.Font.GothamMedium
loading_text.TextSize = 12

local x9 = { c1 = 0.15, c2 = 0.05, c3 = 0.01, c4 = 0.2, c5 = 0.6, c6 = 0.8, c7 = 0.1, c8 = 0.25 }
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)
local BASE_URL = "https://raw.githubusercontent.com/CarlDV/Project-Gravity-02/main/"

local function safe_http_get(url)
	local cache_buster = "?cb=" .. tostring(math.random(1000000, 9999999))
	local fetch_url = url .. cache_buster
	local success, result = pcall(function()
		return game:HttpGet(fetch_url)
	end)
	if success and result then
		return result
	end
	local req = (type(request) == "function" and request) or (type(http) == "table" and http.request) or (type(syn) == "table" and syn.request)
	if req then
		local s, r = pcall(function()
			return req({Url = fetch_url, Method = "GET"})
		end)
		if s and type(r) == "table" and r.Body then
			return r.Body
		end
	end
	return nil
end

local function load_module(path)
	local code = safe_http_get(BASE_URL .. path)
	if code and not string.match(code, "^404: Not Found") then
		local func, err = loadstring(code)
		if func then
			return func()
		end
		warn("Syntax error in module " .. path .. ": " .. tostring(err))
		return nil
	end
	warn("Failed to download module: " .. path)
	return nil
end

local config = load_module("config.lua")
local x1 = config.x1
local x2 = config.x2
x1.S = x2

local serialization = load_module("math/serialization.lua")
local sanitize = serialization.sanitize
local desanitize = serialization.desanitize

local favorites = {}
local function save_favs()
	if writefile then
		pcall(function()
			writefile("GravityFavorites.json", HttpService:JSONEncode(favorites))
		end)
	end
end
local function load_favs()
	if isfile and isfile("GravityFavorites.json") then
		pcall(function()
			favorites = HttpService:JSONDecode(readfile("GravityFavorites.json"))
		end)
	end
end
load_favs()

local save_pending = false
local function save_settings()
	if not writefile then
		return
	end
	if save_pending then return end
	save_pending = true
	task.delay(0.5, function()
		save_pending = false
		local data = { x1 = sanitize(x1), x2 = sanitize(x2) }
		data.x1.Tgt = nil
		data.x1.IsLaunching = nil
		local success, json = pcall(function()
			return HttpService:JSONEncode(data)
		end)
		if success then
			pcall(function()
				writefile("GravitySettings_Auto.json", json)
			end)
		end
	end)
end

local function load_settings()
	if isfile and isfile("GravitySettings_Auto.json") then
		local success, data = pcall(function()
			return HttpService:JSONDecode(readfile("GravitySettings_Auto.json"))
		end)
		if success and data then
			local cx1 = desanitize(data.x1)
			local cx2 = desanitize(data.x2)
			for k, v in pairs(cx1) do
				if k ~= "S" and x1[k] ~= nil and typeof(x1[k]) == typeof(v) then
					x1[k] = v
				end
			end
			for mk, mv in pairs(cx2) do
				if x2[mk] and type(mv) == "table" then
					for sk, sv in pairs(mv) do
						x2[mk][sk] = sv
					end
				end
			end
		end
	end
end
load_settings()

if setfpscap then
	pcall(function()
		setfpscap(x1.FPSCap or 60)
	end)
end

local loaded_shapes = {}
local function get_shape(name)
	if not loaded_shapes[name] then
		local url = BASE_URL .. "shapes/" .. HttpService:UrlEncode(name) .. ".lua"
		local code = safe_http_get(url)
		local success, result = false, nil
		if code then
			local func = loadstring(code)
			if func then
				success, result = pcall(func)
			else
				result = "Syntax error in shape source"
			end
		else
			result = "HTTP Request Failed"
		end
		if success and result then
			loaded_shapes[name] = result
		else
			warn("Failed to load shape: " .. tostring(name) .. " Error: " .. tostring(result))
		end
	end
	return loaded_shapes[name]
end

local x6 = {
	b = nil,
	c = {},
	a = setmetatable({}, {__mode = "k"}),
	o = false,
	d = false,
	p = 0,
	f = 0,
	n = 0,
	pi_targets = {},
	pi_timer = 0,
	ex_nodes = {},
	ex_timer = 0,
	esp_timer = 0,
	claim_queue = {},
	active_array = {},
	pre = {},
	pre_buffer = table.create(200),
	sculptor_selected = setmetatable({}, {__mode = "k"}),
	sculptor_dragging = false,
	sculptor_drag_start = nil,
	sculptor_box_start = nil,
	sculptor_box = nil,
	sculptor_highlights = setmetatable({}, {__mode = "k"}),
	sculptor_preset_ui = nil,
	transition_time = 0,
	transition_dur = 2,
	f1_connections = {},
}

get_shape(x1.k6)

coroutine.wrap(function()
	for mn, _ in pairs(x2) do
		if mn ~= x1.k6 then
			pcall(function()
				get_shape(mn)
			end)
			if task and task.wait then
				task.wait(0.05)
			end
		end
	end
end)()

local context = {
	v1 = v1,
	v2 = v2,
	v3 = v3,
	v4 = v4,
	v5 = v5,
	v6 = v6,
	v7 = v7,
	v8 = v8,
	v9 = v9,
	x1 = x1,
	x2 = x2,
	x6 = x6,
	x9 = x9,
	favorites = favorites,
	save_favs = save_favs,
	save_settings = save_settings,
	get_shape = get_shape,
	load_module = load_module,
	is_mobile = is_mobile,
	SUB_DIR = SUB_DIR,
}

local function destroy()
	if spin_conn then
		pcall(function() spin_conn:Disconnect() end)
		spin_conn = nil
	end
	if loading_sg then
		pcall(function() loading_sg:Destroy() end)
		loading_sg = nil
	end
	for i = #x6.c, 1, -1 do
		pcall(function() x6.c[i]:Disconnect() end)
		x6.c[i] = nil
	end
	for _, d in pairs(x6.a) do
		if d and d.lv then
			pcall(function() d.lv:Destroy() end)
		end
	end
	x6.a = setmetatable({}, {__mode = "k"})
end

local success, err = pcall(function()
	local UI_builder = load_module(SUB_DIR .. "UI.lua")
	if not UI_builder then error("Failed to load UI") end
	local x5 = UI_builder(context)
	context.x5 = x5

	local system_builder = load_module(SUB_DIR .. "System.lua")
	if not system_builder then error("Failed to load System") end
	local sys = system_builder(context)
	local x4 = sys.x4
	local x8 = sys.x8
	context.x4 = x4

	x4.f3()
	x8.i()
	x5.st()
end)

spin_conn:Disconnect()
loading_sg:Destroy()
spin_conn = nil
loading_sg = nil

if not success then
	destroy()
	warn("Project Gravity Initialization Failed: " .. tostring(err))
end