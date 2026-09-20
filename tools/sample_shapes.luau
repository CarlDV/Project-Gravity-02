-- Persistent, deterministic offline trajectory sampler for preview_shapes.py.
-- Lune supplies Roblox's Vector3/CFrame value types. Services below are explicit
-- fixtures; this is shape math, not a recording of Roblox physics or ownership.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local rb = require("@lune/roblox")
local req = serde.decode("json", assert(process.args[1], "supply a JSON request"))
local name = assert(req.name, "name is required")
local count = req.parts or 384
local frames = req.frames or 1
local start = req.time or 0
local duration = req.duration or 6
assert(count >= 1 and count <= 10000 and count % 1 == 0, "invalid part count")
assert(frames >= 1 and frames <= 120 and frames % 1 == 0, "invalid frame count")
assert(start >= 0 and duration > 0, "invalid time range")

local V, CF = rb.Vector3, rb.CFrame
local now = 0
local env = setmetatable({}, { __index = getfenv() })
env._G = env
env.math = table.clone(math)
env.math.randomseed(731)
env.Vector3, env.CFrame, env.Color3 = V, CF, rb.Color3
env.Vector2, env.Enum = rb.Vector2, rb.Enum
env.RaycastParams = { new = function() return {} end }
env.time, env.tick = function() return now end, function() return now end
env.warn = function(...) stdio.ewrite(tostring(...) .. "\n") end

local function event()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local conn = { Connected = true }
			function conn:Disconnect() self.Connected = false end
			callbacks[#callbacks + 1] = { fn, conn }
			return conn
		end,
		Fire = function(_, ...)
			for _, entry in ipairs(callbacks) do
				if entry[2].Connected then entry[1](...) end
			end
		end,
	}
end

-- Strict small Instances: missing methods are errors, never permissive zeroes.
local function instance(class, parent)
	local kids, props = {}, {
		ClassName = class, Name = class, Parent = parent,
		CFrame = CF.new(), Size = V.new(2, 2, 2), Transparency = 0,
		AssemblyLinearVelocity = V.zero, AssemblyAngularVelocity = V.zero,
		Anchored = false, CanCollide = false,
	}
	local methods = {}
	local self = setmetatable({}, {
		__index = function(_, k)
			if k == "Position" then return props.CFrame.Position end
			if methods[k] then return methods[k] end
			if k == "_children" then return kids end
			return props[k]
		end,
		__newindex = function(_, k, value)
			if k == "Position" then props.CFrame = props.CFrame + (value - props.CFrame.Position)
			else props[k] = value end
		end,
	})
	function methods:IsA(wanted)
		return wanted == class or (wanted == "BasePart" and (class == "Part" or class == "MeshPart"))
	end
	function methods:GetChildren() return kids end
	function methods:GetDescendants() return kids end
	function methods:FindFirstChild(wanted)
		for _, child in ipairs(kids) do if child.Name == wanted then return child end end
	end
	function methods:FindFirstChildWhichIsA(wanted)
		for _, child in ipairs(kids) do if child:IsA(wanted) then return child end end
	end
	methods.FindFirstChildOfClass = methods.FindFirstChildWhichIsA
	function methods:Destroy() props.Parent = nil end
	function methods:GetAttribute() return nil end
	if parent and parent._children then table.insert(parent._children, self) end
	return self
end
env.Instance = { new = instance }
local world = instance("Workspace")
env.workspace = world
world.Gravity = 196.2
local floor = instance("Part", world)
floor.Name, floor.Size, floor.Anchored = "Fixture floor", V.new(500, 1, 500), true

local camera = instance("Camera", world)
camera.CFrame = CF.lookAt(V.new(0, 35, 200), V.new(0, 20, 0))
camera.ViewportSize = rb.Vector2.new(1280, 720)
world.CurrentCamera = camera
local mouse = { Hit = CF.new(100, 25, 120) }
function camera:ViewportPointToRay()
	return { Origin = self.CFrame.Position, Direction = (mouse.Hit.Position - self.CFrame.Position).Unit }
end
camera.ScreenPointToRay = camera.ViewportPointToRay

local rig = instance("Model", world)
rig.Name = "Preview R6"
local specs = {
	{ "HumanoidRootPart", V.new(2, 2, 1), V.new(0, 3, 0) },
	{ "Head", V.new(2, 1, 1), V.new(0, 4.5, 0) },
	{ "Torso", V.new(2, 2, 1), V.new(0, 3, 0) },
	{ "Left Arm", V.new(1, 2, 1), V.new(-1.5, 3, 0) },
	{ "Right Arm", V.new(1, 2, 1), V.new(1.5, 3, 0) },
	{ "Left Leg", V.new(1, 2, 1), V.new(-0.5, 1, 0) },
	{ "Right Leg", V.new(1, 2, 1), V.new(0.5, 1, 0) },
}
local limbs = {}
for i, spec in ipairs(specs) do
	local part = instance("Part", rig)
	part.Name, part.Size, part.Position = spec[1], spec[2], spec[3]
	part.Transparency = i == 1 and 1 or 0
	limbs[i] = part
end
local humanoid = instance("Humanoid", rig)
humanoid.MoveDirection, humanoid.Health = V.zero, 100
local player = { Name = "Preview", Character = rig, Parent = true, GetMouse = function() return mouse end }
local input = { TouchEnabled = false, KeyboardEnabled = true,
	InputBegan = event(), InputEnded = event(), InputChanged = event(),
	GetMouseLocation = function() return rb.Vector2.new(640, 360) end }
local services = { Players = { LocalPlayer = player, GetPlayers = function() return { player } end }, UserInputService = input }
env.game = { GetService = function(_, key) return assert(services[key], "missing fixture service " .. key) end }

-- Floor for outdoor shapes; the two wall-probing shapes get a room with a door.
function world:Raycast(origin, delta)
	local reach = delta.Magnitude
	if reach < 1e-8 then return nil end
	local dir, best, normal = delta / reach, reach, nil
	local function plane(distance, n)
		if distance > 0.01 and distance < best then best, normal = distance, n end
	end
	if dir.Y < -1e-6 then plane(-origin.Y / dir.Y, V.yAxis) end
	if name == "Ymir's Flesh" or name == "Yamata no Orochi" then
		if dir.Y > 1e-6 then plane((40 - origin.Y) / dir.Y, -V.yAxis) end
		if dir.X > 1e-6 then
			local hit = (100 - origin.X) / dir.X
			local y = origin.Y + dir.Y * hit
			if y <= 5 or y >= 20 then plane(hit, -V.xAxis) end
		end
		if dir.X < -1e-6 then plane((-100 - origin.X) / dir.X, V.xAxis) end
		if dir.Z > 1e-6 then plane((100 - origin.Z) / dir.Z, -V.zAxis) end
		if dir.Z < -1e-6 then plane((-100 - origin.Z) / dir.Z, V.zAxis) end
	end
	if normal then return { Position = origin + dir * best, Normal = normal, Distance = best,
		Instance = floor, Material = rb.Enum.Material.Concrete } end
	return nil
end

local function load_module(path)
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
	setfenv(fn, env)
	return fn()
end
local config = load_module("config.lua")
local path = "shapes/" .. name .. ".lua"
local review = not fs.isFile(path)
if review then path = "shapes-onreview/" .. name .. ".lua" end
assert(fs.isFile(path), "unknown shape: " .. name)
local mod = load_module(path)
local cfg = table.clone(config.x2[name] or {})
for _, ctl in ipairs(mod.Controls or {}) do
	if ctl.Key and cfg[ctl.Key] == nil then
		local value = ctl.Default
		if value == nil then
			if ctl.Type == "Toggle" then value = false
			else value = (ctl.Min or 0) / (ctl.Div or 1) end
		end
		cfg[ctl.Key] = value
	end
end
for key, value in pairs(req.overrides or {}) do
	assert(cfg[key] ~= nil, "unknown override: " .. key)
	cfg[key] = value
end
local x1 = table.clone(config.x1)
x1.k6, x1.k7, x1.Targets, x1.PI_All = name, 1, {}, false
local x9 = { c1 = 0.15, c2 = 0.05, c3 = 0.01, c4 = 0.2, c5 = 0.6, c6 = 0.8, c7 = 0.1, c8 = 0.25 }
local core = instance("Part", world)
local ctx = { pre = {}, n = count, f = 0, part_id_counter = count, b = core,
	a = {}, active_array = {}, sculptor_selected = {} }
local mix = { V.new(4, 2, 2), V.new(6, 1, 4), V.new(3, 3, 3), V.new(8, 2, 4),
	V.new(12, 1, 8), V.new(2, 18, 2), V.new(24, 1, 12), V.new(40, 2, 16) }
local weights = { 0.23, 0.42, 0.55, 0.7, 0.82, 0.9, 0.97, 1 }
local parts, records, sizes = {}, {}, {}
for id = 1, count do
	local size = V.new(2, 2, 2)
	if req.mode ~= "markers" then
		local pick = (id * 0.4142135623730951) % 1
		for i, cut in ipairs(weights) do if pick < cut then size = mix[i]; break end end
	end
	-- Only Drop writes a debris CFrame. Keep ordinary target samples as plain
	-- records to avoid constructing a native CFrame on every position update.
	local part = { Name = "Debris " .. id, Size = size, Parent = world,
		CFrame = CF.new(), Anchored = false, AssemblyLinearVelocity = V.zero }
	part.Position = V.new(((id * 0.754877666) % 1 - 0.5) * 100,
		20 + ((id * 0.569840291) % 1) * 60, ((id * 0.438579021) % 1 - 0.5) * 80)
	local data = { id = id, slot = id, slot_n = count, claim_t = 0 }
	parts[id], records[id], ctx.a[part], ctx.active_array[id] = part, data, data, part
	sizes[id] = { size.X, size.Y, size.Z }
	if name == "Sculptor" then
		local cols = math.ceil(count ^ (1 / 3))
		local offset = V.new(((id - 1) % cols - (cols - 1) / 2) * 9,
			(math.floor((id - 1) / cols) % cols - (cols - 1) / 2) * 6,
			(math.floor((id - 1) / (cols * cols)) - (cols - 1) / 2) * 9)
		ctx.sculptor_selected[part] = offset
		part.Position = offset + V.new(0, 70, 0)
	end
end

-- Scripted input is deliberately restricted to interactive shapes. Ordinary
-- formations get a fixed core and camera, so the gallery cannot invent motion.
local fixture = "Fixed core"
local priorHeld = false
local function update_fixture(t)
	local center = V.zero
	if req.fixtures ~= false then
		if name == "Mech Suit" or name == "Platform" then
			fixture = "Walking R6 fixture"
			local root = CF.new(18 * math.sin(t * 0.65), 0, 10 * math.sin(t * 0.4)) * CF.Angles(0, 0.22 * math.sin(t * 0.7), 0)
			for i, spec in ipairs(specs) do
				local pose = CF.new(spec[3])
				if i >= 4 then
					local arm = i <= 5
					local sign = i % 2 == 0 and 1 or -1
					local pivot = V.new(spec[3].X, arm and 4 or 2, 0)
					pose = CF.new(pivot) * CF.Angles(math.sin(t * 5) * 0.7 * sign * (arm and -1 or 1), 0, 0) * CF.new(0, -1, 0)
				end
				limbs[i].CFrame = root * pose
				limbs[i].AssemblyLinearVelocity = V.new(11.7 * math.cos(t * 0.65), 0, 4 * math.cos(t * 0.4))
			end
			humanoid.MoveDirection = limbs[1].AssemblyLinearVelocity.Unit
		elseif name == "Sculptor" then
			fixture = "Scripted selection + drag"
			ctx.sculptor_dragging = true
			ctx.sculptor_drag_target = V.new(65 * math.sin(t * 0.7), 70 + 25 * math.sin(t * 1.1), 35 * math.sin(t * 0.5))
		elseif name == "Mugen Train" or name == "Dragons Teeth" then
			fixture = "Scripted core trail"
			center = V.new(130 * math.sin(t * 0.85), 15 + 8 * math.sin(t * 0.6), 100 * math.sin(t * 1.7))
		elseif name == "Mochi Mochi no Mi" or name == "Meteor Hammer" then
			fixture = "Scripted core swing"
			center = V.new(90 * math.sin(t * 1.2), 75 + 30 * math.sin(t * 0.7), 65 * math.sin(t * 0.8))
		elseif name == "Point Impact" or name == "Cursed Technique Red" then
			fixture = "Scripted moving core"
			center = V.new(55 * math.sin(t), 30 + 20 * math.sin(t * 0.7), 35 * math.sin(t * 0.6))
		elseif name == "Big Bad Broom" or name == "Twin Core Beam" or name == "Goro Goro no Mi" then
			fixture = "Scripted aim + hold/release"
			mouse.Hit = CF.new(90 * math.sin(t * 0.6), 25 + 15 * math.sin(t), 140)
			local held = t % 4 > 0.5 and t % 4 < 3
			local cursor = V.new(640 + 120 * math.sin(t * 1.5), 360, 0)
			local inp = { UserInputType = rb.Enum.UserInputType.MouseButton1, Position = cursor }
			if held ~= priorHeld then
				if held then input.InputBegan:Fire(inp, false) else input.InputEnded:Fire(inp) end
			end
			priorHeld = held
			input.InputChanged:Fire({ UserInputType = rb.Enum.UserInputType.MouseMovement, Position = cursor }, false)
		elseif name == "Raigo" then
			fixture = "Scripted launch + return"
			mouse.Hit = CF.new(85, 25, 65)
			x1.IsLaunching = t % 3.5 > 0.6 and t % 3.5 < 0.85
		elseif name == "Drop" then
			fixture = "Reselect + drop every 2.5 s"
			center = V.new(0, 90, 0)
		end
	end
	core.Position = center
	return center
end

local derivedTarget = { ["Big Ring Things"] = true, ["Halo Ring"] = true, ["Quantum Atoms"] = true }
local velocityDemo = { Slingshot = true, Sculptor = true, ["Gods Call"] = true,
	["Point Impact"] = true, ["Cursed Technique Red"] = true }
local output, labels, centers = {}, {}, {}
local function finite(v)
	return v and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e7 and math.abs(v.Y) < 1e7 and math.abs(v.Z) < 1e7
end
local function step(t, dt, capture)
	now, ctx.f = t, ctx.f + 1
	local center = update_fixture(t)
	local a = t * 1.2
	ctx.motion_offset = V.new(6 * (math.cos(a) - 1), 1.5 * math.sin(a * 2), 6 * math.sin(a))
	if mod.px then mod.px(t, cfg, ctx, x9, x1) end
	local cloud = capture and {} or nil
	for id, part in ipairs(parts) do
		local data = records[id]
		if mod.Drop then
			local cycle = req.fixtures == false and 0 or math.floor(t / 2.5)
			if data.drop_cycle ~= cycle then
				data.unclaim, data.drop_cycle, data.fall_speed = false, cycle, 0
				part.CFrame = CF.new(part.Position)
				mod.f2(part, center, data, t, cfg, x1, ctx, x9)
				part.Position = part.CFrame.Position
			else
				data.fall_speed = data.fall_speed - world.Gravity * dt
				local pos = part.Position + V.new(0, data.fall_speed * dt, 0)
				part.Position = V.new(pos.X, math.max(part.Size.Y / 2, pos.Y), pos.Z)
			end
		else
			local velocity, target = mod.f2(part, center, data, t, cfg, x1, ctx, x9)
			assert(finite(velocity), name .. ": invalid velocity at part " .. id .. ", time " .. t)
			if derivedTarget[name] then target = part.Position + velocity / (x1.k10 * x9.c1) end
			if target then assert(finite(target), name .. ": invalid target at part " .. id .. ", time " .. t) end
			if target and not velocityDemo[name] then
				part.Position = target
			else
				-- Integrate fields that depend on the part's current position. There
				-- are no collisions/inertia here. Avoid a numeric overshoot at a point.
				local move = velocity * dt
				if target and move.Magnitude > (target - part.Position).Magnitude then move = target - part.Position end
				part.Position = part.Position + move
			end
			part.AssemblyLinearVelocity = velocity
		end
		assert(finite(part.Position), name .. ": invalid position at part " .. id)
		if capture then
			local pos = part.Position
			cloud[id] = { pos.X, pos.Y, pos.Z }
		end
	end
	if capture then
		output[#output + 1] = cloud
		centers[#centers + 1] = { center.X, center.Y, center.Z }
		local st = ctx.pre.Raigo
		labels[#labels + 1] = st and st.phase or fixture
	end
end

-- Advance all state at 60 Hz, including the warm-up, rather than recreating a
-- record for each frame. This is essential for histories, random slots and px.
local clock = 0
step(0, 0, start == 0)
for frame = (start == 0 and 2 or 1), frames do
	local targetTime = start + (frames == 1 and 0 or (frame - 1) * duration / frames)
	while clock + 1 / 60 < targetTime - 1e-8 do
		step(clock + 1 / 60, 1 / 60, false)
		clock = clock + 1 / 60
	end
	local dt = targetTime - clock
	step(targetTime, dt, true)
	clock = targetTime
end
if mod.cleanup then mod.cleanup(ctx, x1) end
stdio.write(serde.encode("json", {
	name = name, review = review, fixture = fixture, config = cfg,
	sizes = sizes, frames = output, labels = labels, centers = centers,
	continuous_motion = mod.ContinuousMotion == true,
	method = mod.Drop and "release + gravity fixture" or (velocityDemo[name] and "integrated velocity field" or "shape targets"),
}))
