local M = {}

local plrs = game:GetService("Players")

local UP = Vector3.new(0, 1, 0)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)

-- R3 low-discrepancy triple and the golden ratio (Mech Suit.lua:12-15). Part ids
-- are a sliding window sitting wherever x6.part_id_counter has got to, never
-- 1..n, so id % n clumps every part onto a handful of slots. Decorrelated
-- irrational strides spread any id window evenly instead.
local R3_A = 0.8191725133961645
local R3_B = 0.6710436067037893
local R3_C = 0.5497004779019702
local PHI = 0.6180339887498949

-- ---- Lag Tree ----------------------------------------------------------
-- Shared solver. Duplicated VERBATIM into shapes/Mochi Mochi no Mi.lua; shapes
-- cannot require a shared library (main.lua:359 fetches each file standalone), so
-- this is copy-paste, not abstraction. Edit one, edit both.
--
-- A short chain of critically-damped springs, each node chasing the one in front.
-- Lag accumulates down the chain, so the tip trails the anchor by a real
-- distance rather than a phase offset -- that is what makes it swing on its own
-- weight instead of orbiting on a sine.
local LAG = "Lag Tree"
local NODES = 24 -- chain length; the tip is NODES
local SUB_MAX = 16 -- sub-steps per frame, ceiling
local SAFE_DT = 0.35 -- max stable value of h * sqrt(k), semi-implicit Euler
local LEASH = 700 -- max node offset from anchor; x1.k1 culls at 2000

-- Why the sub-step count is derived rather than fixed: a damped spring integrated
-- explicitly is stable only while h * sqrt(k) stays below about 0.5, and the
-- stiffness slider spans 5..400, so sqrt(k) alone moves by 9x. A fixed rate that
-- holds at k = 60 gains energy every step at k = 400 and the chain leaves the
-- map -- measured, not theorised: at 20 fps the tip reached 8.6e14 studs before
-- this was derived from k instead.
--
-- Solving h <= SAFE_DT / sqrt(k) for the step count gives the loop below. SAFE_DT
-- sits under the true limit because the damping term and the anchor's own motion
-- both add energy the bound does not model.
--
-- SUB_MAX caps the catch-up: after an alt-tab dt can be seconds, and honouring it
-- would burn thousands of steps in one frame. Clamping loses time rather than
-- hanging, and because the leftover is dropped rather than crammed into oversized
-- steps, the chain stays stable while it settles.

local function root_of(char)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

-- px never receives cen (System.lua:285-287), so this reads the core marker the
-- way Platform.lua:380-383 does: the chain hangs off the marker you are dragging
-- rather than off a selected target.
local function anchor_of(x6)
	if x6.b then
		return x6.b.Position
	end
	local lp = plrs.LocalPlayer
	local root = lp and root_of(lp.Character)
	return root and root.Position or nil
end

local function lt_state(x6, a)
	local st = x6.pre[LAG]
	if st then
		return st
	end
	st = { p = {}, v = {}, pub = {} }
	-- Born collapsed onto the anchor. Seeding the chain spread out would fling it
	-- on the first frame as every spring released at once.
	for i = 1, NODES do
		st.p[i] = a
		st.v[i] = Vector3.new(0, 0, 0)
		st.pub[i] = a
	end
	x6.pre[LAG] = st
	return st
end

-- One spring step for the whole chain.
--
-- Node 1 chases the anchor; node i chases node i-1. Critical damping is
-- 2 * sqrt(k), which is the most lag the chain can carry without oscillating
-- about its rest length -- past that it wobbles, short of it it springs.
local function lt_step(st, a, k, drag, gravity, seg, dt)
	local damp = 2 * math.sqrt(k) * drag
	-- Damping is itself an explicit term, so v * damp * dt overshoots and flips
	-- sign once damp * dt passes 1 -- which turns the drag slider into an
	-- amplifier at exactly the settings meant to calm the chain down. Capping the
	-- per-step factor is what makes high damping behave like high damping.
	local dfac = damp * dt
	if dfac > 0.9 then
		dfac = 0.9
	end
	local prev = a
	for i = 1, NODES do
		local p = st.p[i]
		local v = st.v[i]
		local to = prev - p
		local dist = to.Magnitude
		local dir = dist > 0.001 and (to / dist) or UP

		-- The spring pulls toward a point one segment behind its parent, not onto
		-- the parent itself. Chasing the parent's exact position would let the
		-- whole chain collapse to a dot when the anchor stops.
		local slack = dist - seg
		v = v + (dir * (slack * k) - UP * gravity) * dt - v * dfac

		-- Terminal velocity. The bound above is derived for the spring alone; the
		-- anchor being yanked is an outside energy source it does not model, so
		-- this is the backstop that keeps a bad frame from becoming an escape.
		local sp = v.Magnitude
		if sp > 900 then
			v = v * (900 / sp)
		end

		p = p + v * dt

		-- Hard leash. Everything above bounds the rate of change; this bounds the
		-- result. A node that ends up past x1.k1 = 2000 from the anchor is culled
		-- and parked by System.lua:451-466 and never comes back, so the formation
		-- would quietly lose parts rather than look wrong. Measured worst case
		-- across the full slider range was 3522 studs before this existed.
		local off = p - a
		local od = off.Magnitude
		if od > LEASH then
			p = a + off * (LEASH / od)
			-- Drop the velocity that got it there too, or it presses against the
			-- leash every step and the chain goes rigid.
			v = v * 0.25
		end

		st.v[i] = v
		st.p[i] = p
		prev = p
	end
end

-- Advances the chain and, on a bucket boundary, publishes the copy f2 reads.
--
-- The publish is the whole reason this is two arrays: f2 runs on a stagger
-- (System.lua:431-433), so parts in the same cycle must all see one pose. Reading
-- st.p live would shear the hammer across the frames of a cycle.
local function lt_advance(st, a, t, x6, x1, k, drag, gravity, seg)
	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end

	-- Step count derived from stiffness, not from a fixed rate: see SAFE_DT above.
	local steps = math.ceil(dt * math.sqrt(k) / SAFE_DT)
	if steps < 1 then
		steps = 1
	elseif steps > SUB_MAX then
		steps = SUB_MAX
	end
	local h = dt / steps
	-- If the cap bit, the honest move is to advance less time rather than take
	-- oversized steps, which is the thing that made it explode.
	local hmax = SAFE_DT / math.sqrt(k)
	if h > hmax then
		h = hmax
	end

	for _ = 1, steps do
		lt_step(st, a, k, drag, gravity, seg, h)
	end

	local et = x1 and x1.k7
	if not et then
		local n = x6.n or 0
		et = n > 5000 and 10 or (n > 2500 and 6 or (n > 1000 and 3 or 1))
	end
	if x1 and x1["Force Smooth (Lags)"] then
		et = 1
	end
	if et < 1 then
		et = 1
	end
	local gen = math.floor((x6.f or 0) / et)
	if st.gen ~= gen then
		st.gen = gen
		st.pub_a = a
		for i = 1, NODES do
			st.pub[i] = st.p[i]
		end
	end
end

-- Frame at a node, built from the chain's own direction of travel.
local function lt_frame(st, i)
	local p = st.pub[i]
	local prev = (i > 1) and st.pub[i - 1] or st.pub_a
	if not p or not prev then
		return nil, UP, Vector3.new(1, 0, 0)
	end
	local d = p - prev
	local along = (d.Magnitude > 0.001) and d.Unit or UP
	local side = along:Cross(UP)
	if side.Magnitude < 0.001 then
		side = Vector3.new(1, 0, 0)
	else
		side = side.Unit
	end
	return p, along, side
end

-- ---- Meteor Hammer -----------------------------------------------------

function M.px(t, c, x6, x9, x1)
	local a = anchor_of(x6)
	if not a then
		return
	end
	local st = lt_state(x6, a)

	-- Swing drive. A chain hanging off a stationary anchor settles straight down,
	-- which is correct and dull, so the point the chain chases is orbited instead
	-- of the chain being forced directly. Driving the root and letting lag do the
	-- shaping is what keeps the tip obeying its own weight: it lags the orbit,
	-- flattens out as the rate climbs, and keeps swinging after the rate drops.
	local dtp = t - (st.st or t)
	st.st = t
	if dtp < 0 then
		dtp = 0
	elseif dtp > 0.25 then
		dtp = 0.25
	end
	-- k14 and k16 carry Div = 10, which scales only the panel reading
	-- (UI.lua:1223-1225) -- the stored values below are already the real ones, as
	-- Rocket Engine.lua:75 relies on for its own Div slider.
	local rate = c.k16 or 1.2
	st.spin = (st.spin or 0) + rate * dtp

	local len = c.k11 or 90
	-- Radius rides on chain length rather than its own slider: an orbit wider than
	-- the chain just drags the whole thing in a circle with no swing in it.
	local swing_r = (rate > 0) and (len * 0.3) or 0
	local drive = a
	if swing_r > 0 then
		drive = a + Vector3.new(math.cos(st.spin) * swing_r, 0, math.sin(st.spin) * swing_r)
	end

	local seg = len / NODES
	lt_advance(st, drive, t, x6, x1, c.k13 or 60, c.k14 or 0.8, c.k15 or 60, seg)
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre and x6.pre[LAG]
	if not st or not st.pub_a then
		return ANTI_SLEEP, nil
	end

	local id = d.id or 1
	local w1 = (id * R3_A) % 1
	local w2 = (id * R3_B) % 1
	local w3 = (id * R3_C) % 1
	local pick = (id * PHI) % 1

	local head_share = (c.k19 or 55) / 100
	local target_pos

	if pick < head_share then
		-- The head: a ball at the tip, the mass that sells the swing.
		local tip, along, side = lt_frame(st, NODES)
		if not tip then
			return ANTI_SLEEP, nil
		end
		local up2 = side:Cross(along)
		if up2.Magnitude < 0.001 then
			up2 = UP
		else
			up2 = up2.Unit
		end

		local r = c.k17 or 16
		-- Sphere by inverse-cosine latitude, so parts land evenly over the surface
		-- instead of bunching at the poles the way a uniform angle sweep does.
		local phi = math.acos(1 - 2 * w1)
		local th = w2 * math.pi * 2
		local sp = math.sin(phi)
		-- Shell, not solid: a fixed part budget spent on an invisible interior
		-- leaves the surface too sparse to read as a ball.
		local rr = r * (0.82 + w3 * 0.18)
		target_pos = tip
			+ side * (rr * sp * math.cos(th))
			+ up2 * (rr * sp * math.sin(th))
			+ along * (rr * math.cos(phi))

		-- Spikes on the head, so it reads as a weapon rather than a bead.
		if w3 > 0.93 then
			target_pos = tip + (target_pos - tip) * 1.45
		end
	else
		-- The chain. Parts spread along the links by arc position, with a little
		-- radial thickness so a chain at distance is still visible.
		local u = w1 * (NODES - 1) + 1
		local i = math.floor(u)
		if i > NODES - 1 then
			i = NODES - 1
		end
		local a1 = st.pub[i]
		local a2 = st.pub[i + 1]
		if not a1 or not a2 then
			return ANTI_SLEEP, nil
		end
		local base = a1 + (a2 - a1) * (u - i)

		local _, along, side = lt_frame(st, i + 1)
		local up2 = side:Cross(along)
		up2 = (up2.Magnitude > 0.001) and up2.Unit or UP

		local r = (c.k18 or 4) * math.sqrt(w2)
		local th = w3 * math.pi * 2
		target_pos = base + side * (r * math.cos(th)) + up2 * (r * math.sin(th))
	end

	-- pure_target_pos is mandatory, not optional: the pose only restamps on a
	-- bucket boundary, so without the feed-forward differentiator
	-- (System.lua:507-535) a tip moving at swing speed would step at ~15 Hz.
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	-- x6.pre survives shape switches and only cleanup runs (System.lua:152-158).
	-- Mochi shares the key and rebuilds it, so swapping between the two drops the
	-- chain onto the anchor and re-hangs it rather than inheriting a stale pose.
	x6.pre[LAG] = nil
end

M.Testing = true

M.Controls = {
	{ Type = "Slider", Name = "Chain · Length", Min = 10, Max = 400, Key = "k11", Default = 90 },
	{ Type = "Slider", Name = "Stiffness", Min = 5, Max = 400, Key = "k13", Default = 60 },
	{ Type = "Slider", Name = "Damping", Min = 1, Max = 30, Key = "k14", Div = 10 },
	{ Type = "Slider", Name = "Gravity", Min = 0, Max = 300, Key = "k15", Default = 60 },
	{ Type = "Slider", Name = "Swing · Rate", Min = 0, Max = 100, Key = "k16", Div = 10 },
	{ Type = "Slider", Name = "Head · Radius", Min = 2, Max = 60, Key = "k17", Default = 16 },
	{ Type = "Slider", Name = "Chain · Thickness", Min = 1, Max = 20, Key = "k18", Default = 4 },
	{ Type = "Slider", Name = "Head · Share %", Min = 10, Max = 90, Key = "k19", Default = 55, IntOnly = true },
}

return M
