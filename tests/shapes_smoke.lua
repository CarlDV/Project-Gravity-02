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
			-- Standing still by default; the walk tests drive this directly.
			AssemblyLinearVelocity = Vector3.new(0, 0, 0),
			IsA = function(_, cls) return cls == "BasePart" end,
		}
	end
	character.GetChildren = function() return kids end
	character.FindFirstChild = function(_, n)
		for _, k in ipairs(kids) do if k.Name == n then return k end end
	end
	character.FindFirstChildWhichIsA = function() return kids[1] end
	character.root = kids[1]
end

-- Other players, for the targeting and hunt tests. Distances from the local
-- player are deliberately out of order so a "nearest first" claim has to sort.
local function mk_player(name, pos)
	local char
	local root = {
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		Position = pos,
		CFrame = CFrame.new(pos),
		AssemblyLinearVelocity = Vector3.new(0, 0, 0),
		IsA = function(_, cls) return cls == "BasePart" end,
	}
	char = {
		GetChildren = function() return { root } end,
		FindFirstChild = function(_, n) return n == "HumanoidRootPart" and root or nil end,
		FindFirstChildWhichIsA = function() return root end,
	}
	-- A real BasePart is always parented to its character model. Shapes use that
	-- to tell a live quarry from one that has despawned mid-chase.
	root.Parent = char
	return { Name = name, Parent = true, Character = char, root = root }
end

local FAR = mk_player("Far", Vector3.new(900, 0, 0))
local NEAR = mk_player("Near", Vector3.new(120, 0, 0))
local MID = mk_player("Mid", Vector3.new(400, 0, 0))

local local_player

local MOUSE_HIT = Vector3.new(140, 8, 40)
local ROSTER = {}
game = {
	GetService = function(_, name)
		if name == "Players" then
			return {
				LocalPlayer = local_player,
				GetPlayers = function()
					local out = { local_player }
					for _, pl in ipairs(ROSTER) do out[#out + 1] = pl end
					return out
				end,
			}
		end
		return {
			TouchEnabled = false, KeyboardEnabled = true,
			InputBegan = signal(), InputEnded = signal(), InputChanged = signal(),
			GetMouseLocation = function() return { X = 400, Y = 300 } end,
		}
	end,
}
local_player = {
	Name = "Host",
	Character = character,
	GetMouse = function() return { Hit = CFrame.new(MOUSE_HIT) } end,
}
-- A room for the probe shapes: floor at y=0, ceiling at y=40, walls at +-100 in
-- x and z, and a gap in the +x wall between y=5 and y=20 so head selection has a
-- real doorway to find. Returning a Normal as well as a Position matters: a stub
-- that omits it leaves every cached normal nil, and a plane with no normal NaNs
-- the whole envelope.
local ROOM_ON = false
local function ray_room(org, dv)
	local reach = dv.Magnitude
	if reach < 1e-6 then
		return nil
	end
	local dir = dv / reach
	local best, bn = reach, nil
	local function face(t, n)
		if t and t > 0.01 and t < best then
			best, bn = t, n
		end
	end
	if dir.Y < -1e-6 then face((0 - org.Y) / dir.Y, Vector3.new(0, 1, 0)) end
	if dir.Y > 1e-6 then face((40 - org.Y) / dir.Y, Vector3.new(0, -1, 0)) end
	if dir.X > 1e-6 then
		local t = (100 - org.X) / dir.X
		local hy = org.Y + dir.Y * t
		if not (hy > 5 and hy < 20) then face(t, Vector3.new(-1, 0, 0)) end
	end
	if dir.X < -1e-6 then face((-100 - org.X) / dir.X, Vector3.new(1, 0, 0)) end
	if dir.Z > 1e-6 then face((100 - org.Z) / dir.Z, Vector3.new(0, 0, -1)) end
	if dir.Z < -1e-6 then face((-100 - org.Z) / dir.Z, Vector3.new(0, 0, 1)) end
	if not bn then
		return nil
	end
	return { Position = org + dir * best, Normal = bn }
end

workspace = {
	CurrentCamera = { CFrame = CFrame.new(0, 0, 0) },
	Raycast = function(_, org, dv)
		if ROOM_ON then
			return ray_room(org, dv)
		end
		return { Position = MOUSE_HIT }
	end,
}

-- Not needed by the three original shapes, but the probe shapes construct both
-- inside px.
RaycastParams = { new = function() return {} end }
Enum = setmetatable({}, {
	__index = function()
		return setmetatable({}, { __index = function() return 0 end })
	end,
})

-- Defaults come from config.lua rather than being restated here. A hand-copied
-- fixture silently goes stale the moment a default changes, which is exactly how
-- an earlier run of this file "failed" on a shape that was correct.
-- shapes/ first, then shapes-onreview/. Three shapes moved to the review folder and
-- this asserted straight onto the old path, so both harnesses crashed on load --
-- shapes_smoke before it reached any of its geometry checks at all.
local function load_shape(name)
	local f = io.open("shapes/" .. name .. ".lua")
	local from = "shapes/"
	if not f then
		f = io.open("shapes-onreview/" .. name .. ".lua")
		from = "shapes-onreview/"
	end
	assert(f, "cannot find " .. name .. ".lua in shapes/ or shapes-onreview/")
	local src = f:read("a"); f:close()
	return assert(load(src, from .. name))()
end
local function shape_cfg(name)
	local cfg = assert(loadfile("config.lua"))().x2[name]
	-- The shapes in shapes-onreview/ deliberately have no config block yet, so seed
	-- from the module's own Controls the way main.lua's local-shape loader does.
	-- Asserting here crashed the whole suite the moment a shape moved to review.
	if not cfg then
		local mod = load_shape(name)
		cfg = {}
		for _, ctl in ipairs(mod.Controls or {}) do
			if type(ctl) == "table" and ctl.Key then
				local dv = ctl.Default
				if dv == nil then
					dv = ctl.Min or 0
					if ctl.Div then dv = dv / ctl.Div end
				end
				cfg[ctl.Key] = dv
			end
		end
		return cfg
	end
	local copy = {}
	for k, v in pairs(cfg) do copy[k] = v end
	return copy
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

	-- Lobe axis: k20 picks whether the two loops stack vertically or spread
	-- sideways. This used to fall out of the circle's Plane slider, so it could
	-- not be set independently and depended on where the target stood.
	local function lobe_spread()
		local lo_y, hi_y, lo_h, hi_h = math.huge, -math.huge, math.huge, -math.huge
		-- side is the horizontal axis square to the span; the span here runs along
		-- +X, so Z carries any sideways bulge.
		for frame = 13, 400 do
			x6.f = frame
			S.px(frame / 60, cfg, x6, x9, x1)
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), target, { id = 1 }, frame / 60, cfg, x1, x6, x9)
			if finite(tp) then
				if tp.Y < lo_y then lo_y = tp.Y end
				if tp.Y > hi_y then hi_y = tp.Y end
				if tp.Z < lo_h then lo_h = tp.Z end
				if tp.Z > hi_h then hi_h = tp.Z end
			end
		end
		return hi_y - lo_y, hi_h - lo_h
	end

	cfg.k20 = 1
	local up_v, up_h = lobe_spread()
	check(up_v > up_h * 4,
		("up/down lobes bulge vertically: %.1f vs %.1f sideways"):format(up_v, up_h))

	cfg.k20 = 2
	local sd_v, sd_h = lobe_spread()
	check(sd_h > sd_v * 4,
		("side by side lobes bulge sideways: %.1f vs %.1f vertical"):format(sd_h, sd_v))

	-- Both settings must still span the two foci; the axis changes the bulge, not
	-- the reach.
	for _, mode in ipairs({ 1, 2 }) do
		cfg.k20 = mode
		local hit_c, hit_t = 0, 0
		for frame = 13, 400 do
			x6.f = frame
			S.px(frame / 60, cfg, x6, x9, x1)
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), target, { id = 1 }, frame / 60, cfg, x1, x6, x9)
			if finite(tp) then
				if (tp - st.caster).Magnitude < 130 then hit_c = hit_c + 1 end
				if (tp - target).Magnitude < 130 then hit_t = hit_t + 1 end
			end
		end
		check(hit_c > 0 and hit_t > 0, ("lobe mode %d still spans both foci"):format(mode))
	end

	-- Target directly overhead leaves no horizontal perpendicular. Both modes must
	-- still produce a finite path rather than collapsing onto the span.
	for _, mode in ipairs({ 1, 2 }) do
		cfg.k20 = mode
		local ok = true
		for frame = 13, 120 do
			x6.f = frame
			S.px(frame / 60, cfg, x6, x9, x1)
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), st.caster + Vector3.new(0, 300, 0),
				{ id = 1 }, frame / 60, cfg, x1, x6, x9)
			-- A nil target counts as a failure. It used to be skipped, so this check
			-- went green if f2 returned no target at all for all 108 frames -- a worse
			-- outcome than a NaN, not a better one.
			if tp == nil or not finite(tp) then ok = false end
		end
		check(ok, ("lobe mode %d survives a vertical span"):format(mode))
	end
	cfg.k20 = 1

	-- No target selected: cen == caster, so the span collapses. Must not NaN.
	local same = st.caster
	local _, tp = S.f2(part(Vector3.new(0, 0, 0)), same, { id = 3 }, 1.0, cfg, x1, x6, x9)
	check(finite(tp), "figure 8 degenerate span falls back cleanly")

	-- Hunt: one rocket that works through the lobby, nearest first, on a loop.
	cfg.k12 = 1
	cfg.k21 = true
	cfg.k22 = 2
	ROSTER = { FAR, NEAR, MID }
	local x1h = { k10 = 20, k7 = 4, PI_All = true }

	local function hunt_step(frame, tt)
		x6.f = frame
		S.px(tt, cfg, x6, x9, x1h)
		return st.hunt
	end

	-- Opens on the nearest, not on roster order: NEAR is listed second.
	local first = hunt_step(500, 100)
	check(first ~= nil, "hunt picks a quarry")
	check((first - NEAR.root.Position).Magnitude < 1,
		"hunt opens on the nearest player")

	-- Holds that quarry for the dwell, then advances.
	local held = hunt_step(504, 101)
	check((held - NEAR.root.Position).Magnitude < 1, "hunt holds a quarry for its dwell")
	local second = hunt_step(508, 103)
	check((second - MID.root.Position).Magnitude < 1, "hunt advances to the next nearest")
	local third = hunt_step(512, 106)
	check((third - FAR.root.Position).Magnitude < 1, "hunt advances again")
	local wrapped = hunt_step(516, 109)
	check((wrapped - NEAR.root.Position).Magnitude < 1, "hunt loops back to the start")

	-- A moving quarry is chased between dwells, not left at where it stood.
	NEAR.root.Position = Vector3.new(150, 0, 200)
	local chased = hunt_step(520, 110)
	check((chased - NEAR.root.Position).Magnitude < 1, "hunt tracks a moving quarry")
	NEAR.root.Position = Vector3.new(120, 0, 0)

	-- Every part must fly the same path, or Target Everyone splits the rocket
	-- into one thin copy per player. Different cen per part, same result.
	hunt_step(524, 112)
	local a1, a2
	do
		local _, p1 = S.f2(part(Vector3.new(0, 0, 0)), Vector3.new(0, 0, 0), { id = 5 }, 112, cfg, x1h, x6, x9)
		local _, p2 = S.f2(part(Vector3.new(0, 0, 0)), Vector3.new(800, 40, -600), { id = 5 }, 112, cfg, x1h, x6, x9)
		a1, a2 = p1, p2
	end
	check((a1 - a2).Magnitude < 0.001, "hunt overrides per-part cen so the rocket stays whole")

	-- An empty lobby has to fall back to cen rather than freezing or erroring.
	ROSTER = {}
	local empty = hunt_step(528, 120)
	check(empty == nil, "hunt clears when there is nobody to chase")
	local _, fb = S.f2(part(Vector3.new(0, 0, 0)), Vector3.new(0, 10, 0), { id = 1 }, 120, cfg, x1h, x6, x9)
	check(finite(fb), "hunt with an empty lobby still produces a finite path")

	cfg.k21 = false
	ROSTER = {}
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
	check((st.reach or 0) > 0, "reach measured from the live pose")

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

	-- Height slider must move the body vertically and only vertically.
	cfg.k13 = 2
	cfg.k17 = 0; local low = centroid()
	cfg.k17 = 50; local high = centroid()
	check(math.abs((high.Y - low.Y) - 50) < 0.01, ("height slider lifts by its own studs: %.2f"):format(high.Y - low.Y))
	check(math.abs(high.X - low.X) < 0.01 and math.abs(high.Z - low.Z) < 0.01, "height slider does not drift sideways")
	cfg.k17 = 0

	-- Height must apply in every placement, not just the offset ones.
	for _, place in ipairs({ 1, 2, 3, 4 }) do
		cfg.k13 = place
		cfg.k17 = 0; local a = centroid()
		cfg.k17 = 25; local b = centroid()
		check(math.abs((b.Y - a.Y) - 25) < 0.01, ("height applies at placement %d"):format(place))
		cfg.k17 = 0
	end
	cfg.k13 = 2

	-- Feet must hold their height as the mech scales, or a large one sinks into
	-- the floor. Lowest point is what matters here, not the centroid.
	local function lowest()
		local y = math.huge
		for id = 1, 200 do
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 0.2, cfg, x1, x6, x9)
			if tp.Y < y then y = tp.Y end
		end
		return y
	end
	cfg.k11 = 1; local feet_small = lowest()
	cfg.k11 = 4; local feet_big = lowest()
	cfg.k11 = 12; local feet_huge = lowest()
	check(math.abs(feet_big - feet_small) < 0.5,
		("feet hold at 4x vs 1x: %.2f vs %.2f"):format(feet_big, feet_small))
	check(math.abs(feet_huge - feet_small) < 0.5,
		("feet hold at 12x vs 1x: %.2f vs %.2f"):format(feet_huge, feet_small))
	cfg.k11 = 2

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

	-- Targeting. The mech must stand on a selected target, stay one whole body
	-- while doing it, and ignore Target Everyone.
	local function body_at(cfg2, x1b, frame)
		x6.f = frame
		S.px(frame / 60, cfg2, x6, x9, x1b)
		local sx, sy, sz = 0, 0, 0
		for id = 1, 150 do
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), Vector3.new(0, 5, 0), { id = id }, frame / 60, cfg2, x1b, x6, x9)
			sx, sy, sz = sx + tp.X, sy + tp.Y, sz + tp.Z
		end
		return Vector3.new(sx / 150, sy / 150, sz / 150)
	end

	local untargeted = body_at(cfg, { k10 = 20, k7 = 4 }, 40)
	check((untargeted - character.root.Position).Magnitude < 120,
		"with no target the mech stays on the host")

	local targeted = body_at(cfg, { k10 = 20, k7 = 4, Targets = { MID } }, 48)
	check((targeted - MID.root.Position).Magnitude < 120,
		"a selected target moves the mech onto them")
	check((targeted - untargeted).Magnitude > 200, "targeting actually relocates the body")

	-- Target Everyone must not deal the body out across the lobby. Whatever it
	-- picks, the result has to be one coherent mech, not several thin ones.
	local all_on = body_at(cfg, { k10 = 20, k7 = 4, PI_All = true }, 56)
	check((all_on - untargeted).Magnitude < 1,
		"Target Everyone is ignored; the mech stays whole on the host")

	-- Tracking. The mech mirrors the character's live pose, so moving a limb has to
	-- move the mech -- and only the points that limb owns. This replaces a test that
	-- asserted a synthetic sine-wave gait, which is precisely what stopped the suit
	-- from following the character: the pose was snapshotted once and a canned walk
	-- cycle was played over it, so a jump, a crouch, a tool pose or an emote did
	-- nothing at all.
	local x1w = { k10 = 20, k7 = 4 }
	local function pose(frame)
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1w)
		local out = {}
		for id = 1, 240 do
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, frame / 60, cfg, x1w, x6, x9)
			out[id] = tp
		end
		return out
	end
	local function moved_count(a, b)
		local n = 0
		for id = 1, 240 do
			if a[id] and b[id] and (a[id] - b[id]).Magnitude > 0.01 then n = n + 1 end
		end
		return n
	end

	local arm = character:FindFirstChild("Right Arm")
	local arm_base = arm.CFrame
	local before = pose(64)
	-- Swing the arm out ninety degrees about the shoulder.
	arm.CFrame = CFrame.new(arm_base.Position) * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.pi / 2)
	local after = pose(68)
	local moved = moved_count(before, after)
	check(moved > 0, ("moving a limb moves the mech: %d/240 points followed"):format(moved))
	check(moved < 240, ("and only that limb: %d/240 held still"):format(240 - moved))

	-- Motion Gain 0 pins the mech to the pose the cloud was built in.
	arm.CFrame = arm_base
	local rigid_cfg = {}
	for k, v in pairs(cfg) do rigid_cfg[k] = v end
	rigid_cfg.k18 = 0
	local x6r = mk_x6()
	local function rigid_pose(frame)
		x6r.f = frame
		S.px(frame / 60, rigid_cfg, x6r, x9, x1w)
		local out = {}
		for id = 1, 240 do
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, frame / 60, rigid_cfg, x1w, x6r, x9)
			out[id] = tp
		end
		return out
	end
	local r0 = rigid_pose(64)
	arm.CFrame = CFrame.new(arm_base.Position) * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.pi / 2)
	local r1 = rigid_pose(68)
	check(moved_count(r0, r1) == 0, "Motion Gain 0 ignores the animation entirely")
	arm.CFrame = arm_base

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
	-- px stamps aim and input state only. The grip is deliberately not stamped:
	-- px never receives cen, so deriving it here is what made the broom ignore
	-- the anchor. f2 builds it from cen instead.
	check(st.aim ~= nil, "aim resolved")
	check(st.grip == nil, "grip is not stamped in px")

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
	local grip = cen + Vector3.new(0, 1, 0) * cfg.k19
	check((extended - grip).Magnitude > (retracted - grip).Magnitude, "hold extends the broom")
	st.pub_ext = 0

	-- The broom must be built off cen, so it follows the anchor and rides a
	-- selected target. It used to hang off the character root and ignore both.
	local moved = Vector3.new(500, 60, -300)
	local here = centroid()
	local there = (function()
		local sx, sy, sz = 0, 0, 0
		for id = 1, 100 do
			local _, tp = S.f2(part(Vector3.new(0, 0, 0)), moved, { id = id }, 0.2, cfg, x1, x6, x9)
			sx, sy, sz = sx + tp.X, sy + tp.Y, sz + tp.Z
		end
		return Vector3.new(sx / 100, sy / 100, sz / 100)
	end)()
	check((there - here).Magnitude > 100, "broom follows cen when the anchor moves")
	check((there - moved).Magnitude < (there - cen).Magnitude, "broom sits at the new centre, not the old one")

	-- Grip Height raises the hand off the centre.
	cfg.k19 = 0; local at_cen = centroid()
	cfg.k19 = 40; local lifted = centroid()
	check(lifted.Y > at_cen.Y, "grip height raises the broom")

	S.cleanup(x6, x1)
	check(x6.pre["Big Bad Broom"] == nil, "cleanup drops state")
	local live = 0
	for _, c in ipairs(st.conns) do if c.Connected then live = live + 1 end end
	check(live == 0, ("cleanup disconnects all listeners (%d still live)"):format(live))
end

-- ---- Wake Spline pair ---------------------------------------------------
-- Dragons Teeth and Mugen Train share one ring buffer of the anchor's own path.
-- The invariants worth asserting are the ones a syntax check cannot see: that
-- standing still does not collapse the trail, that a teleport starts a new one
-- instead of drawing a line across the map, and that the ring stays bounded.
for _, name in ipairs({ "Dragons Teeth", "Mugen Train" }) do
	print(name)
	local S = load_shape(name)
	local cfg = shape_cfg(name)
	local x1 = { k10 = 20, k7 = 4 }
	local x9 = { c1 = 0.15, c2 = 0.05 }

	local x6 = mk_x6()
	x6.b = { Position = Vector3.new(0, 10, 0) }
	-- Walk a circle for ten seconds: 300 studs of arc at STEP 5 is 60 samples.
	for frame = 1, 600 do
		x6.f = frame
		local th = frame / 60 * 0.5
		x6.b.Position = Vector3.new(math.cos(th) * 60, 10, math.sin(th) * 60)
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	local st = x6.pre["Wake Spline"]
	check(st ~= nil, name .. ": px builds the ring")
	check(st.count > 40 and st.count <= 768, ("%s: ring bounded (%d)"):format(name, st.count))

	local cen = Vector3.new(0, 10, 0)
	local seen, maxd = {}, 0
	for id = 40000, 40400 do
		local vel, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 10.0, cfg, x1, x6, x9)
		check(finite(vel) and finite(tp), name .. " finite id=" .. id)
		seen[("%.0f,%.0f,%.0f"):format(tp.X, tp.Y, tp.Z)] = true
		local dd = (tp - cen).Magnitude
		if dd > maxd then maxd = dd end
	end
	local uniq = 0
	for _ in pairs(seen) do uniq = uniq + 1 end
	-- id % n would pile 401 parts onto a handful of slots; the Weyl stride must not.
	check(uniq > 200, ("%s: no clumping (%d/401 distinct)"):format(name, uniq))
	check(maxd < 2000, ("%s: inside the k1 cull (%.0f)"):format(name, maxd))

	-- Standing still must not collapse the trail onto one point.
	local idle = mk_x6()
	idle.b = { Position = Vector3.new(0, 10, 0) }
	for frame = 1, 300 do
		idle.f = frame
		S.px(frame / 60, cfg, idle, x9, x1)
	end
	check(idle.pre["Wake Spline"].count == 1, name .. ": idle appends nothing")

	-- A teleport starts a fresh trail rather than laying a line across the map.
	local tp6 = mk_x6()
	tp6.b = { Position = Vector3.new(0, 10, 0) }
	for frame = 1, 120 do
		tp6.f = frame
		tp6.b.Position = Vector3.new(frame * 2, 10, 0)
		S.px(frame / 60, cfg, tp6, x9, x1)
	end
	tp6.f = 121
	tp6.b.Position = Vector3.new(9000, 10, 9000)
	S.px(121 / 60, cfg, tp6, x9, x1)
	check(tp6.pre["Wake Spline"].count == 1, name .. ": teleport reseeds the trail")

	S.cleanup(x6, x1)
	check(x6.pre["Wake Spline"] == nil, name .. ": cleanup drops state")
end

-- ---- Lag Tree pair ------------------------------------------------------
-- Meteor Hammer and Mochi share a damped-spring chain. An explicit integrator is
-- only conditionally stable, so the test that matters is the whole slider range
-- against a punishing frame rate: a fixed 240 Hz sub-step sent the tip to 8.6e14
-- studs at k=400 and 20 fps before the step count was derived from stiffness.
for _, name in ipairs({ "Meteor Hammer", "Mochi Mochi no Mi" }) do
	print(name)
	local S = load_shape(name)
	local x1 = { k10 = 20, k7 = 4 }
	local x9 = { c1 = 0.15, c2 = 0.05 }

	local worst = 0
	for _, k in ipairs({ 5, 60, 400 }) do
		for _, dr in ipairs({ 0.1, 0.8, 3.0 }) do
			for _, g in ipairs({ 0, 60, 300 }) do
				for _, fps in ipairs({ 20, 60, 240 }) do
					local cfg = shape_cfg(name)
					if name == "Meteor Hammer" then
						cfg.k13, cfg.k14, cfg.k15 = k, dr, g
					else
						cfg.k13, cfg.k15, cfg.k14 = 45, dr * 33, g
					end
					local x6 = mk_x6()
					x6.b = { Position = Vector3.new(0, 50, 0) }
					for frame = 1, fps * 4 do
						x6.f = frame
						local tt = frame / fps
						-- Yank the anchor 200 studs every second: an outside energy
						-- source the stability bound does not model.
						x6.b.Position = Vector3.new(math.floor(tt) % 2 == 0 and 0 or 200, 50, 0)
						S.px(tt, cfg, x6, x9, x1)
					end
					local st = x6.pre["Lag Tree"]
					for i = 1, 24 do
						check(finite(st.p[i]), ("%s: finite k=%d drag=%.1f g=%d fps=%d"):format(name, k, dr, g, fps))
						local dd = (st.p[i] - x6.b.Position).Magnitude
						if dd > worst then worst = dd end
					end
				end
			end
		end
	end
	check(worst < 2000, ("%s: 81 configs stay inside the k1 cull (%.0f)"):format(name, worst))

	-- Energy decay, which is the invariant that actually distinguishes a stable
	-- integrator from a clamped unstable one. The leash and the velocity cap keep
	-- an exploding chain bounded and finite, so a position check alone passes
	-- either way -- verified by reverting the derived sub-step and watching the
	-- bounds test stay green.
	--
	-- Decay is asserted rather than a settling deadline. A 24-node chain has
	-- collective modes far slower than one spring, so at the softest stiffness it
	-- legitimately rings for over ten seconds; demanding it be at rest by a fixed
	-- time fails correct code. An unstable integrator cannot decay at all, which
	-- is the property worth pinning.
	for _, k in ipairs({ 5, 60, 400 }) do
		for _, fps in ipairs({ 20, 60 }) do
			local cfg = shape_cfg(name)
			if name == "Meteor Hammer" then
				cfg.k13, cfg.k14, cfg.k15, cfg.k16 = k, 0.8, 0, 0
			else
				cfg.k13, cfg.k15, cfg.k14 = 45, 26, 0
			end
			local x6 = mk_x6()
			x6.b = { Position = Vector3.new(0, 50, 0) }
			-- Kick it hard, then hold perfectly still and watch the energy go.
			for frame = 1, fps do
				x6.f = frame
				x6.b.Position = Vector3.new((frame % 2 == 0) and 0 or 220, 50, 0)
				S.px(frame / fps, cfg, x6, x9, x1)
			end
			local st = x6.pre["Lag Tree"]
			local function peak()
				local m = 0
				for i = 1, 24 do
					local sp = st.v[i].Magnitude
					if sp > m then m = sp end
				end
				return m
			end
			local function hold(upto)
				for frame = fps + 1, fps * upto do
					x6.f = frame
					x6.b.Position = Vector3.new(0, 50, 0)
					S.px(frame / fps, cfg, x6, x9, x1)
				end
			end
			hold(4)
			local early = peak()
			hold(16)
			local late = peak()
			check(late < early * 0.6,
				("%s: sheds energy at rest, k=%d fps=%d (%.1f -> %.1f studs/s)"):format(name, k, fps, early, late))
		end
	end

	local cfg = shape_cfg(name)
	local x6 = mk_x6()
	x6.b = { Position = Vector3.new(0, 50, 0) }
	for frame = 1, 240 do
		x6.f = frame
		x6.b.Position = Vector3.new(math.cos(frame / 40) * 80, 50, math.sin(frame / 40) * 80)
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	local seen = {}
	for id = 40000, 40400 do
		local vel, tp = S.f2(part(Vector3.new(0, 0, 0)), Vector3.new(0, 50, 0), { id = id }, 4.0, cfg, x1, x6, x9)
		check(finite(vel) and finite(tp), name .. " finite id=" .. id)
		seen[("%.0f,%.0f,%.0f"):format(tp.X, tp.Y, tp.Z)] = true
	end
	local uniq = 0
	for _ in pairs(seen) do uniq = uniq + 1 end
	check(uniq > 200, ("%s: no clumping (%d/401 distinct)"):format(name, uniq))

	S.cleanup(x6, x1)
	check(x6.pre["Lag Tree"] == nil, name .. ": cleanup drops state")
end

-- ---- World Envelope pair ------------------------------------------------
-- Ymir's Flesh and Yamata no Orochi share a probe lattice that caches world
-- PLANES rather than radii, because px never sees cen and cen is per-part. The
-- claim to test is that the field re-roots onto an origin it never probed from.
ROOM_ON = true
for _, name in ipairs({ "Ymir's Flesh", "Yamata no Orochi" }) do
	print(name)
	local S = load_shape(name)
	local cfg = shape_cfg(name)
	local x1 = { k10 = 20, k7 = 4 }
	local x9 = { c1 = 0.15, c2 = 0.05 }

	local org = Vector3.new(0, 20, 0)
	local x6 = mk_x6()
	x6.b = { Position = org }
	-- Long enough for the round-robin to cover the lattice several times over.
	for frame = 1, 200 do
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	check(x6.pre["World Envelope"] ~= nil, name .. ": px builds the field")

	local seen, escapees = {}, 0
	for id = 40000, 40500 do
		local vel, tp = S.f2(part(Vector3.new(0, 0, 0)), org, { id = id }, 3.0, cfg, x1, x6, x9)
		check(finite(vel) and finite(tp), name .. " finite id=" .. id)
		seen[("%.0f,%.0f,%.0f"):format(tp.X, tp.Y, tp.Z)] = true
		-- The room is 200 x 40 x 200; the pulse may lift parts through a face, but
		-- nothing should be flung to the far side of the map.
		if math.abs(tp.X) > 340 or math.abs(tp.Z) > 340 or tp.Y < -120 or tp.Y > 260 then
			escapees = escapees + 1
		end
	end
	local uniq = 0
	for _ in pairs(seen) do uniq = uniq + 1 end
	check(uniq > 250, ("%s: no clumping (%d/501 distinct)"):format(name, uniq))
	check(escapees == 0, ("%s: every part stays in the room (%d escaped)"):format(name, escapees))

	-- The re-root claim: serve a cen the probe never ran from. A cached radius
	-- would put parts through the walls here; a cached plane does not.
	local moved = org + Vector3.new(40, 0, -25)
	local inside = 0
	for id = 40000, 40200 do
		local _, tp = S.f2(part(Vector3.new(0, 0, 0)), moved, { id = id }, 3.0, cfg, x1, x6, x9)
		if finite(tp) and math.abs(tp.X) < 340 and math.abs(tp.Z) < 340 then
			inside = inside + 1
		end
	end
	check(inside > 190, ("%s: re-roots onto an unprobed origin (%d/201)"):format(name, inside))

	S.cleanup(x6, x1)
	check(x6.pre["World Envelope"] == nil, name .. ": cleanup drops state")
end

-- Orochi must put one head through the doorway rather than piling every head
-- into the single deepest direction, which is what a plain top-K would do.
do
	print("Yamata no Orochi · head selection")
	local S = load_shape("Yamata no Orochi")
	local cfg = shape_cfg("Yamata no Orochi")
	local x1 = { k10 = 20, k7 = 4 }
	local x9 = { c1 = 0.15, c2 = 0.05 }
	local x6 = mk_x6()
	x6.b = { Position = Vector3.new(0, 12, 0) }
	for frame = 1, 400 do
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	local st = x6.pre["World Envelope"]
	local through = false
	for i = 1, (st.pK or 0) do
		if st.phd[i].dir.X > 0.75 then through = true end
	end
	check(through, "a head cranes through the doorway")

	-- Assert the loop below has something to do. With pK nil, 0 or 1 neither loop
	-- executed, minsep stayed at its 999 sentinel and the separation check passed
	-- without comparing a single pair.
	check((st.pK or 0) >= 2, ("at least two heads published to compare: pK=%s"):format(tostring(st.pK)))
	local minsep = 999
	for i = 1, (st.pK or 0) do
		for j = i + 1, (st.pK or 0) do
			local dot = st.phd[i].dir:Dot(st.phd[j].dir)
			if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
			local deg = math.deg(math.acos(dot))
			if deg < minsep then minsep = deg end
		end
	end
	check(minsep >= (cfg.k16 or 50) - 1, ("heads stay %.0f deg apart, not clustered"):format(minsep))
end
ROOM_ON = false

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
