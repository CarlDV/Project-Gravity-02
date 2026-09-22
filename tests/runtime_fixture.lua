-- Signals and instance destruction with observable ownership for lifecycle tests.
local env = require("robloxenv")
local M = { env = env, instances = {}, signals = {} }
function M.signal()
	local listeners = {}
	local signal = {}
	function signal:Connect(fn)
		local conn = { Connected = true }
		function conn:Disconnect() self.Connected = false end
		listeners[#listeners + 1] = { fn = fn, conn = conn }
		return conn
	end
	function signal:Fire(...)
		local snapshot = {}
		for i, v in ipairs(listeners) do snapshot[i] = v end
		for _, v in ipairs(snapshot) do if v.conn.Connected then v.fn(...) end end
	end
	function signal:disconnect()
		for _, v in ipairs(listeners) do v.conn:Disconnect() end
	end
	function signal:count()
		local n = 0
		for _, v in ipairs(listeners) do if v.conn.Connected then n = n + 1 end end
		return n
	end
	M.signals[#M.signals + 1] = signal
	return signal
end

local factory = Instance.new
local children_by_parent = {}
local function reparent(inst, previous, parent)
	if previous and children_by_parent[previous] then children_by_parent[previous][inst] = nil end
	if parent then
		children_by_parent[parent] = children_by_parent[parent] or {}
		children_by_parent[parent][inst] = inst.Name
	end
end
Instance.new = function(class, parent)
	local inst = factory(class, parent)
	local meta = getmetatable(inst)
	local read, write, actual_parent = meta.__index, meta.__newindex, parent
	local events = {}
	reparent(inst, nil, parent)
	meta.__index = function(self, key)
		if key == "Parent" then return actual_parent end
		for child, name in pairs(children_by_parent[self] or {}) do
			if name == key then return child end
		end
		return read(self, key)
	end
	meta.__newindex = function(self, key, value)
		local parent_changed = key == "Parent" and actual_parent ~= value
		if key == "Parent" then
			reparent(self, actual_parent, value)
			actual_parent = value
		elseif key == "Name" and actual_parent then
			children_by_parent[actual_parent][self] = value
		end
		write(self, key, value)
		if parent_changed and events.AncestryChanged then events.AncestryChanged:Fire(self, value) end
	end
	local owned = {}
	for _, name in ipairs({ "MouseButton1Click", "Activated", "InputBegan", "InputEnded", "Destroying", "AncestryChanged" }) do
		local signal = M.signal()
		events[name] = signal
		inst[name] = signal
		owned[#owned + 1] = signal
	end
	local gone = false
	local old_destroy = inst.Destroy
	rawset(inst, "Destroy", function(self)
		if gone then return end
		gone = true
		inst.Destroying:Fire()
		for _, child in ipairs(self:GetChildren()) do child:Destroy() end
		self.Parent = nil
		for _, signal in ipairs(owned) do signal:disconnect() end
		old_destroy(self)
		children_by_parent[self] = nil
		inst._destroyed = true
	end)
	M.instances[#M.instances + 1] = inst
	rawset(inst, "GetChildren", function(self)
		local children = {}
		for child in pairs(children_by_parent[self] or {}) do children[#children + 1] = child end
		return children
	end)
	rawset(inst, "FindFirstChild", function(self, name)
		for _, child in ipairs(self:GetChildren()) do if child.Name == name then return child end end
	end)
	rawset(inst, "ClearAllChildren", function(self)
		for _, child in ipairs(self:GetChildren()) do child:Destroy() end
	end)
	return inst
end

local input, run = env.svc("UserInputService"), env.svc("RunService")
for _, key in ipairs({ "InputBegan", "InputChanged", "InputEnded", "WindowFocusReleased", "LastInputTypeChanged" }) do
	input[key] = M.signal()
end
for _, key in ipairs({ "Heartbeat", "RenderStepped", "Stepped" }) do run[key] = M.signal() end
env.svc("Players").PlayerRemoving = M.signal()
M.input, M.run = input, run
M.actions = {}
env.svc("ContextActionService").BindAction = function(_, name, fn) M.actions[name] = fn end
env.svc("ContextActionService").UnbindAction = function(_, name) M.actions[name] = nil end
function M.find(name)
	for i = #M.instances, 1, -1 do
		local inst = M.instances[i]
		if inst.Name == name and inst.Parent ~= nil then return inst end
	end
end
return M
