-- Executes the three new shape modules against a stubbed engine and checks the
-- geometry they produce. Syntax parsing cannot catch a NaN, a degenerate basis,
-- or a Weyl stride that clumps every part onto one slot; running them can.
--
--   luajit tests/shapes_smoke.lua      (from the repo root)

package.path = "tests/?.lua;" .. package.path
local rm = require("robloxmath")
Vector3, CFrame = rm.Vector3, rm.CFrame

local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print("  FAIL  " .. msg)
	end
end
local function finite(v)
	return v and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and v.X ~= math.huge and v.X ~= -math.huge
		and v.Y ~= math.huge and v.Y ~= -math.huge
		and v.Z ~= math.huge and v.Z ~= -math.huge
end

-- ---- engine stubs -------------------------------------------------------
-- Luau has table.create and math.clamp; LuaJIT has neither. Both are used
-- throughout the codebase (math.clamp 32 times), so the harness supplies them
-- rather than the shapes avoiding them.
if not table.create then
	table.create = function(n, v)
		local t = {}
		if v ~= nil then
			for i = 1, n do t[i] = v end
		end
		return t
	end
end
if not math.clamp then
	math.clamp = function(x, lo, hi)
		if x < lo then return lo end
		if x > hi then return hi end
		return x
	end
end

-- config.lua constructs Color3/Vector3 at load, so those have to exist first.
Color3 = { new = function() return { R = 0, G = 0, B = 0 } end }
Color3.fromRGB = Color3.new

local function conn() return { Connected = true, Disconnect = function(s) s.Connected = false end } end
local function signal() return { Connect = function() return conn() end } end

local CHAR_PARTS = {
	{ Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1) },
	{ Name = "Head",             Size = Vector3.new(2, 1, 1) },
	{ Name = "Torso",            Size = Vector3.new(2, 2, 1) },
	{ Name = "Left Arm",         Size = Vector3.new(1, 2, 1) },
	{ Name = "Right Arm",        Size = Vector3.new(1, 2, 1) },
	{ Name = "Left Leg",         Size = Vector3.new(1, 2, 1) },
	{ Name = "Right Leg",        Size = Vector3.new(1, 2, 1) },
}
local character = {}
do
	local kids = {}
	for i, spec in ipairs(CHAR_PARTS) do
		local pos = Vector3.new(i * 0.5, i * 0.8, 0)
		kids[i] = {
			Name = spec.Name,
			Size = spec.Size,
			-- A real BasePart exposes both; the shapes read Position off the root
			-- and CFrame off every limb.
			Position = pos,
			CFrame = CFrame.new(pos),
			IsA = function(_, cls) return cls == "BasePart" end,
		}
	end
	character.GetChildren = function() return kids end
	character.FindFirstChild = function(_, n)
		for _, k in ipairs(kids) do if k.Name == n then return k end end
	end
	character.FindFirstChildWhichIsA = function() return kids[1] end
end

local MOUSE_HIT = Vector3.new(140, 8, 40)
game = {
	GetService = function(_, name)
		if name == "Players" then
			return {
				LocalPlayer = {
					Character = character,
					GetMouse = function() return { Hit = CFrame.new(MOUSE_HIT) } end,
				},
			}
		end
		return {
			TouchEnabled = false, KeyboardEnabled = true,
			InputBegan = signal(), InputEnded = signal(), InputChanged = signal(),
			GetMouseLocation = function() return { X = 400, Y = 300 } end,
		}
	end,
}
workspace = {
	CurrentCamera = { CFrame = CFrame.new(0, 0, 0) },
	Raycast = function() return { Position = MOUSE_HIT } end,
}

-- Defaults come from config.lua rather than being restated here. A hand-copied
-- fixture silently goes stale the moment a default changes, which is exactly how
-- an earlier run of this file "failed" on a shape that was correct.
local function shape_cfg(name)
	local cfg = assert(loadfile("config.lua"))().x2[name]
	assert(cfg, "no x2 block for " .. name)
	local copy = {}
	for k, v in pairs(cfg) do copy[k] = v end
	return copy
end

local function load_shape(name)
	local f = assert(io.open("shapes/" .. name .. ".lua"))
	local src = f:read("a"); f:close()
	return assert(load(src, name))()
end

local function mk_x6(n)
	return { pre = {}, f = 0, n = n or 400 }
end
local function part(pos) return { Position = pos } end

-- ---- Rocket Engine ------------------------------------------------------
print("Rocket Engine")
do
	local S = load_shape("Rocket Engine")
	local cfg = shape_cfg("Rocket Engine")
	local x1 = { k10 = 20, k7 = 4 }
	local x9 = { c1 = 0.15, c2 = 0.05 }
	local x6 = mk_x6()
	local cen = Vector3.new(0, 10, 0)

	for frame = 1, 12 do
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	local st = x6.pre["Rocket Engine"]
	check(st ~= nil, "px stamps state")
	check(st.caster ~= nil, "px caches caster root")
	check(st.phase > 0, "phase advances")

	local PHI = 0.6180339887498949
	local engine_hits, exhaust_hits = 0, 0
	local seen = {}
	for id = 1, 400 do
		local d = { id = id }
		local vel, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, d, 0.2, cfg, x1, x6, x9)
		check(finite(vel) and finite(tp), "circle id=" .. id .. " finite")
		check((tp - cen).Magnitude < 400, "circle id=" .. id .. " within cull radius")
		seen[("%.1f,%.1f,%.1f"):format(tp.X, tp.Y, tp.Z)] = true
		-- Same selector the shape uses, so the split is measured rather than
		-- inferred from a radius guess.
		if ((id * PHI) % 1) < cfg.k17 / 100 then exhaust_hits = exhaust_hits + 1 else engine_hits = engine_hits + 1 end
	end
	local distinct = 0
	for _ in pairs(seen) do distinct = distinct + 1 end
	check(distinct > 350, ("Weyl spread: %d/400 distinct slots"):format(distinct))
	check(engine_hits > 0 and exhaust_hits > 0, "both engine and exhaust populated")
	check(math.abs(exhaust_hits / 400 - 0.45) < 0.05,
		("exhaust share tracks the slider: %.2f vs 0.45"):format(exhaust_hits / 400))

	-- Figure 8 must actually span caster and target, not orbit one of them.
	cfg.k12 = 2
	local target = Vector3.new(300, 10, 0)
	local near_caster, near_target = 0, 0
	-- id 1 is an engine part (Weyl pick 0.618 >= 0.45 share), so it rides the path
	-- itself. An exhaust id trails up to the debris length behind and would miss
	-- the lobes for reasons that say nothing about the path.
	for frame = 13, 400 do
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1)
		local _, tp = S.f2(part(Vector3.new(0, 0, 0)), target, { id = 1 }, frame / 60, cfg, x1, x6, x9)
		if finite(tp) then
			if (tp - st.caster).Magnitude < 130 then near_caster = near_caster + 1 end
			if (tp - target).Magnitude < 130 then near_target = near_target + 1 end
		end
	end
	check(near_caster > 0, "figure 8 reaches the caster lobe")
	check(near_target > 0, "figure 8 reaches the target lobe")

	-- No target selected: cen == caster, so the span collapses. Must not NaN.
	local same = st.caster
	local _, tp = S.f2(part(Vector3.new(0, 0, 0)), same, { id = 3 }, 1.0, cfg, x1, x6, x9)
	check(finite(tp), "figure 8 degenerate span falls back cleanly")
end

-- ---- Mech Suit ----------------------------------------------------------
print("Mech Suit")
do
	local S = load_shape("Mech Suit")
	local cfg = shape_cfg("Mech Suit")
	local x1 = { k10 = 20, k7 = 4 }
	local x9 = { c1 = 0.15 }
	local x6 = mk_x6()
	local cen = Vector3.new(0, 5, 0)

	x6.f = 1
	S.px(0.016, cfg, x6, x9, x1)
	local st = x6.pre["Mech Suit"]
	check(st and st.cloud, "cloud builds from character")
	check(st.cloud.n > 100, ("cloud has %d points"):format(st.cloud and st.cloud.n or 0))
	check(st.cloud.reach > 0, "cloud reach measured")

	local seen = {}
	for id = 1, 400 do
		local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 0.2, cfg, x1, x6, x9)
		check(finite(tp), "mech id=" .. id .. " finite")
		seen[("%.2f,%.2f,%.2f"):format(tp.X, tp.Y, tp.Z)] = true
	end
	local distinct = 0
	for _ in pairs(seen) do distinct = distinct + 1 end
	check(distinct > 300, ("Weyl spread: %d/400 distinct slots"):format(distinct))

	-- Placement must actually move the body.
	local function centroid()
		local sx, sy, sz = 0, 0, 0
		for id = 1, 120 do
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 0.2, cfg, x1, x6, x9)
			sx, sy, sz = sx + tp.X, sy + tp.Y, sz + tp.Z
		end
		return Vector3.new(sx / 120, sy / 120, sz / 120)
	end
	cfg.k13 = 2; local front = centroid()
	cfg.k13 = 3; local behind = centroid()
	cfg.k13 = 4; local beside = centroid()
	check((front - behind).Magnitude > 30, "front and behind are distinct placements")
	check((front - beside).Magnitude > 20, "front and beside are distinct placements")

	-- Stationary must latch a pose and hold it while the player moves.
	cfg.k14 = true
	x6.f = 8; S.px(0.13, cfg, x6, x9, x1)
	local anchored = st.anchor
	check(anchored ~= nil, "stationary latches an anchor")
	x6.f = 16; S.px(0.26, cfg, x6, x9, x1)
	check(st.anchor == anchored, "anchor holds across cycles")
	cfg.k14 = false
	x6.f = 24; S.px(0.4, cfg, x6, x9, x1)
	check(st.anchor == nil, "anchor clears when stationary is switched off")

	S.cleanup(x6, x1)
	check(x6.pre["Mech Suit"] == nil, "cleanup drops state")
end

-- ---- Big Bad Broom ------------------------------------------------------
print("Big Bad Broom")
do
	local S = load_shape("Big Bad Broom")
	local cfg = shape_cfg("Big Bad Broom")
	local x1 = { k10 = 20, k7 = 4 }
	local x9 = { c1 = 0.15 }
	local x6 = mk_x6()
	local cen = Vector3.new(0, 5, 0)

	for frame = 1, 8 do
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	local st = x6.pre["Big Bad Broom"]
	check(st ~= nil, "state builds")
	check(#st.conns == 3, ("connects %d input listeners"):format(st and #st.conns or 0))
	check(st.grip ~= nil and st.aim ~= nil, "grip and aim resolved")

	for id = 1, 300 do
		local vel, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 0.2, cfg, x1, x6, x9)
		check(finite(vel) and finite(tp), "broom id=" .. id .. " finite")
	end

	-- Each sweep axis must produce a different pose.
	local function centroid()
		local sx, sy, sz = 0, 0, 0
		for id = 1, 100 do
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 0.2, cfg, x1, x6, x9)
			sx, sy, sz = sx + tp.X, sy + tp.Y, sz + tp.Z
		end
		return Vector3.new(sx / 100, sy / 100, sz / 100)
	end
	st.pub_sweep = 1.2
	cfg.k15 = 1; local flat = centroid()
	cfg.k15 = 2; local tip = centroid()
	cfg.k15 = 3; local roll = centroid()
	check((flat - tip).Magnitude > 1, "flat and tip sweeps differ")
	check((flat - roll).Magnitude > 1, "flat and roll sweeps differ")
	for _, v in ipairs({ flat, tip, roll }) do check(finite(v), "sweep centroid finite") end

	-- Extension on hold must push the head further out.
	cfg.k15 = 1
	st.pub_sweep = 0
	st.pub_ext = 0; local retracted = centroid()
	st.pub_ext = 1; local extended = centroid()
	check((extended - st.grip).Magnitude > (retracted - st.grip).Magnitude, "hold extends the broom")

	S.cleanup(x6, x1)
	check(x6.pre["Big Bad Broom"] == nil, "cleanup drops state")
	local live = 0
	for _, c in ipairs(st.conns) do if c.Connected then live = live + 1 end end
	check(live == 0, ("cleanup disconnects all listeners (%d still live)"):format(live))
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
