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
-- Shared solver. Duplicated VERBATIM from shapes/Meteor Hammer.lua; shapes cannot
-- require a shared library (main.lua:359 fetches each file standalone), so this
-- is copy-paste, not abstraction. Edit one, edit both.
--
-- A short chain of critically-damped springs, each node chasing the one in front.
-- Meteor Hammer reads the chain as a chain. Here only the first node is used, as
-- the centre of a blob, and the rest of the chain becomes the wake that the
-- squash-and-stretch is measured against.
local LAG = "Lag Tree"
local NODES = 24
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

-- ---- Mochi Mochi no Mi -------------------------------------------------

function M.px(t, c, x6, x9, x1)
	local a = anchor_of(x6)
	if not a then
		return
	end
	local st = lt_state(x6, a)

	-- The blob hangs one segment behind the anchor, so trail distance is a real
	-- spring length rather than a fixed offset: it stretches when you accelerate
	-- and closes up when you stop, which is the whole point of the shape.
	local seg = (c.k12 or 26) / NODES
	local soft = (c.k13 or 45) / 100
	-- Softness is one slider driving two coupled quantities, because a soft blob
	-- that is also stiff reads as a bug rather than a setting. Low softness is a
	-- taut ball that tracks tightly; high softness is slack and wobbly.
	local k = 8 + (1 - soft) * 90
	local drag = (c.k15 or 22) / 100
	lt_advance(st, a, t, x6, x1, k, 0.35 + drag * 1.4, c.k14 or 0, seg)

	-- Squash and stretch, stamped once per cycle so every part deforms together.
	-- Measured from the centre's own velocity rather than the anchor's: the blob
	-- keeps stretching for as long as it is still catching up, which is what makes
	-- the follow-through read after the player has already stopped.
	if st.gen ~= st.def_gen then
		st.def_gen = st.gen
		local c1 = st.pub[1]
		local last = st.def_p or c1
		st.def_p = c1
		local dv = c1 - last
		local sp = dv.Magnitude
		local dir = (sp > 0.001) and (dv / sp) or UP
		-- Normalised against a reference speed so the slider means the same thing
		-- at any movement speed, then capped: past the cap the blob would invert
		-- through itself.
		local amt = sp / 12
		if amt > 1 then
			amt = 1
		end
		st.stretch = 1 + amt * (c.k17 or 62) / 100
		st.dir = dir
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre and x6.pre[LAG]
	if not st or not st.pub[1] then
		return ANTI_SLEEP, nil
	end

	local centre = st.pub[1]
	local id = d.id or 1
	local w1 = (id * R3_A) % 1
	local w2 = (id * R3_B) % 1
	local w3 = (id * R3_C) % 1
	local pick = (id * PHI) % 1

	local r = c.k11 or 60
	local skin = (c.k16 or 70) / 100

	-- Sphere by inverse-cosine latitude, so parts land evenly over the surface
	-- rather than bunching at the poles.
	local phi = math.acos(1 - 2 * w1)
	local th = w2 * math.pi * 2
	local sp = math.sin(phi)
	local dirv = Vector3.new(sp * math.cos(th), math.cos(phi), sp * math.sin(th))

	-- Most parts on the skin, the rest scattered through the interior so the blob
	-- reads as a solid volume rather than a hollow bubble when it deforms.
	local rad
	if pick < skin then
		rad = r * (0.92 + w3 * 0.08)
	else
		-- Cube root, not linear: the linear form piles parts at the centre because
		-- volume grows as the cube of radius.
		rad = r * (w3 ^ (1 / 3)) * 0.9
	end

	local base = dirv * rad

	-- Stretch along the direction of travel and preserve volume by thinning the
	-- two cross axes, so the blob squashes as it elongates instead of just
	-- growing. This is the whole squash-and-stretch tell.
	local s = st.stretch or 1
	local sd = st.dir or UP
	local along = base:Dot(sd)
	local perp = base - sd * along
	local target_pos = centre + sd * (along * s) + perp * (1 / math.sqrt(s))

	-- pure_target_pos is mandatory, not optional: the pose only restamps on a
	-- bucket boundary, so without the feed-forward differentiator
	-- (System.lua:507-535) a moving blob would step at ~15 Hz.
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	-- x6.pre survives shape switches and only cleanup runs (System.lua:152-158).
	-- Meteor Hammer shares the key and rebuilds it, so swapping between the two
	-- re-forms the blob on the anchor rather than inheriting a stale pose.
	x6.pre[LAG] = nil
end

M.Testing = true

M.Controls = {
	{ Type = "Slider", Name = "Body · Radius", Min = 10, Max = 220, Key = "k11", Default = 60 },
	{ Type = "Slider", Name = "Body · Trail", Min = 0, Max = 200, Key = "k12", Default = 26 },
	{ Type = "Slider", Name = "Body · Softness %", Min = 5, Max = 100, Key = "k13", Default = 45, IntOnly = true },
	{ Type = "Slider", Name = "Body · Sag", Min = 0, Max = 200, Key = "k14", Default = 0 },
	{ Type = "Slider", Name = "Jiggle Damping %", Min = 0, Max = 100, Key = "k15", Default = 22, IntOnly = true },
	{ Type = "Slider", Name = "Body · Skin %", Min = 0, Max = 100, Key = "k16", Default = 70, IntOnly = true },
	{ Type = "Slider", Name = "Wobble %", Min = 0, Max = 100, Key = "k17", Default = 62, IntOnly = true },
}

return M
