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
local GOLDEN_ANGLE = 2.399963229728653

-- ---- World Envelope ----------------------------------------------------
-- Shared solver. Duplicated VERBATIM from shapes/Ymir's Flesh.lua; shapes cannot
-- require a shared library (main.lua:359 fetches each file standalone), so this
-- is copy-paste, not abstraction. Edit one, edit both.
--
-- A fixed lattice of directions, probed round-robin at a bounded rays-per-frame
-- budget, caching what the world looks like around the anchor. Cost is O(rays),
-- never O(parts).
--
-- THE ONE IDEA: cache world-space PLANES, not radii. Each direction stores a hit
-- point and a surface normal. A radius is only meaningful measured from the
-- origin it was cast from, and this field has to serve an origin it never saw:
-- px never receives cen (System.lua:285-287) while f2 does, and with multiple
-- targets cen is genuinely per-part (System.lua:444-447). A plane can be
-- re-rooted onto an arbitrary origin exactly; a radius cannot.
--
-- Ymir reads the surfaces the rays STOPPED on. This file reads the open air they
-- passed THROUGH -- the same cache, inverted.
local ENV = "World Envelope"
local DIRS = 192 -- lattice size
local RAYS = 12 -- casts per frame
local GRAZE = 0.15 -- |dir . N| under this is too edge-on to re-root
local MIN_S = 4 -- re-root floor, keeps parts out of the camera
local RESEED = 250 -- one-frame origin jump that means teleport

local function root_of(char)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

-- px never receives cen (System.lua:285-287), so probing runs from the core
-- marker the way Platform.lua:380-383 does.
local function anchor_of(x6)
	if x6.b then
		return x6.b.Position
	end
	local lp = plrs.LocalPlayer
	local root = lp and root_of(lp.Character)
	return root and root.Position or nil
end

-- Spherical Fibonacci. Equal solid angle per direction, so sampling the index
-- uniformly is already uniform over the sphere and needs no alias table.
local function build(st)
	st.dir = {}
	st.H = {}
	st.N = {}
	st.S = {}
	st.pH = {}
	st.pN = {}
	st.pS = {}
	for j = 1, DIRS do
		local z = 1 - (2 * j - 1) / DIRS
		local rxy = math.sqrt(math.max(0, 1 - z * z))
		local a = GOLDEN_ANGLE * j
		st.dir[j] = Vector3.new(rxy * math.cos(a), z, rxy * math.sin(a))
	end
end

-- Fills every direction with an open-sky plane at arm's length. This is what
-- makes "no rays cast yet" a non-case: the field is always fully populated with
-- something valid before any f2 runs, so there is no empty first frame to guard.
local function synth(st, org, reach)
	for j = 1, DIRS do
		local u = st.dir[j]
		local h = org + u * reach
		st.H[j] = h
		st.N[j] = -u
		st.S[j] = false
		st.pH[j] = h
		st.pN[j] = -u
		st.pS[j] = false
	end
end

local function probe_params(st)
	local rp = st.rp
	if rp then
		return rp
	end
	rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	-- Claimed parts are all CanCollide = false locally (System.lua:719-721), so a
	-- client with this property probes straight through the debris cloud and finds
	-- the real room. Without it the shape would measure itself. Older clients lack
	-- the property, hence pcall rather than a hard dependency, the same reasoning
	-- as Platform.lua:296-309.
	pcall(function()
		rp.RespectCanCollide = true
	end)
	st.rp = rp
	return rp
end

-- Casts a bounded slice of the lattice. Round-robin, so the whole field refreshes
-- every DIRS/RAYS frames regardless of how many parts are held.
local function sweep(st, org, reach)
	local rp = probe_params(st)
	for _ = 1, RAYS do
		local j = (st.cur % DIRS) + 1
		st.cur = j
		local u = st.dir[j]
		local hit = workspace:Raycast(org, u * reach, rp)
		if hit then
			st.H[j] = hit.Position
			-- A stub or a degenerate surface can return no normal; facing the ray
			-- back at the origin is the safe answer and keeps the plane usable.
			local n = hit.Normal
			st.N[j] = (n and n.Magnitude > 0.001) and n.Unit or -u
			st.S[j] = true
		else
			st.H[j] = org + u * reach
			st.N[j] = -u
			st.S[j] = false
		end
	end
end

-- Publishes the field f2 reads. Copying on the bucket boundary is what keeps a
-- formation from shearing: f2 runs on a stagger (System.lua:431-433), so parts in
-- one cycle must all see the same room even though px keeps casting underneath.
local function stamp(st, x6, x1, org)
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
	if st.gen == gen then
		return false
	end
	st.gen = gen
	for j = 1, DIRS do
		st.pH[j] = st.H[j]
		st.pN[j] = st.N[j]
		st.pS[j] = st.S[j]
	end
	st.porg = org
	return true
end

-- Distance from cen to the cached plane for direction j, along u.
--
-- This is the re-rooting that makes the whole solver work. The plane through
-- H[j] with normal N[j] is a fact about the world, independent of where it was
-- measured from, so it answers correctly for an origin px never saw.
--
--   s = ((H - cen) . N) / (u . N)
--
-- Verified: with cen == the probe origin this returns exactly the measured
-- radius, since the denominator cancels.
local function reroot(st, j, cen, u, reach)
	local N = st.pN[j]
	local H = st.pH[j]
	if not N or not H then
		return reach
	end
	local den = u:Dot(N)
	-- Too edge-on: the intersection runs off toward infinity, and a near-zero
	-- denominator turns float noise into a wild distance. Fall back to the plain
	-- radius from the measured origin.
	if den > -GRAZE and den < GRAZE then
		local d = (H - cen).Magnitude
		return (d > MIN_S) and d or MIN_S
	end
	local s = (H - cen):Dot(N) / den
	if s < MIN_S then
		return MIN_S
	end
	if s > reach then
		return reach
	end
	return s
end

-- ---- Yamata no Orochi --------------------------------------------------

-- Picks the head directions: the longest open runs, spread apart.
--
-- Greedy farthest-point selection over depth, not a plain top-K. A plain top-K
-- would take the deepest direction and then its immediate neighbours, because
-- the lattice is dense and a corridor is many adjacent directions -- eight heads
-- would all crane down the same hallway. Rejecting anything within the
-- separation angle of an already-chosen head is what puts one head down each
-- exit instead.
local function choose_heads(st, org, want, sep_deg)
	local cosmin = math.cos(math.rad(sep_deg))
	local heads = st.heads
	if not heads then
		heads = {}
		st.heads = heads
	end
	local n = 0
	local taken = st.taken or {}
	st.taken = taken
	for j = 1, DIRS do
		taken[j] = false
	end

	while n < want do
		local best, bestd = nil, -1
		for j = 1, DIRS do
			if not taken[j] then
				local H = st.H[j]
				local d = H and (H - org).Magnitude or 0
				if d > bestd then
					best, bestd = j, d
				end
			end
		end
		if not best then
			break
		end
		n = n + 1
		heads[n] = { j = best, d = bestd, dir = st.dir[best] }
		-- Suppress the chosen direction and everything inside the cone around it,
		-- so the next head has to come from a different opening.
		local ub = st.dir[best]
		for j = 1, DIRS do
			if not taken[j] and st.dir[j]:Dot(ub) > cosmin then
				taken[j] = true
			end
		end
	end
	st.nheads = n
end

function M.px(t, c, x6, x9, x1)
	local org = anchor_of(x6)
	if not org then
		return
	end

	local st = x6.pre[ENV]
	local reach = c.k13 or 400
	if not st then
		st = { cur = 0 }
		x6.pre[ENV] = st
		build(st)
		synth(st, org, reach)
	end

	-- A teleport invalidates every plane at once. Re-synthesising is cheaper than
	-- letting the round-robin walk a whole DIRS/RAYS cycle while the heads are
	-- still craning down a corridor on the other side of the map.
	if st.org and (org - st.org).Magnitude > RESEED then
		synth(st, org, reach)
	end
	st.org = org

	sweep(st, org, reach)

	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end
	st.sway = (st.sway or 0) + dt * (c.k22 or 0.3)

	-- Heads are re-chosen only on a publish, not every frame: the selection is a
	-- ranking over a field that is itself only a partial refresh, so re-running it
	-- per frame makes heads flicker between near-tied openings.
	if stamp(st, x6, x1, org) then
		choose_heads(st, org, c.k15 or 5, c.k16 or 50)
		-- Deep-copy into the published list. A reference would let f2 read heads
		-- that choose_heads is rewriting, and a neck whose base reads one frame
		-- and whose tip reads another snaps in half -- the shear documented at
		-- Hover Text.lua:129-138.
		local ph = st.phd
		if not ph then
			ph = {}
			st.phd = ph
		end
		for i = 1, (st.nheads or 0) do
			local h = st.heads[i]
			local dst = ph[i]
			if not dst then
				dst = {}
				ph[i] = dst
			end
			dst.j = h.j
			dst.d = h.d
			dst.dir = h.dir
		end
		st.pK = st.nheads or 0
		st.pub_sway = st.sway
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre and x6.pre[ENV]
	local K = st and st.pK or 0
	if not st or K < 1 then
		return ANTI_SLEEP, nil
	end

	local id = d.id or 1
	local w1 = (id * R3_A) % 1
	local w2 = (id * R3_B) % 1
	local w3 = (id * R3_C) % 1

	local k = math.floor(((id * PHI) % 1) * K) + 1
	if k > K then
		k = K
	end
	local h = st.phd[k]
	if not h or not h.dir then
		return ANTI_SLEEP, nil
	end

	local u = h.dir
	local reach = c.k13 or 400
	-- Head length is the real measured distance, re-rooted onto this part's own
	-- cen. That is the legibility tell: walk at a wall and the neck shortens live,
	-- and a head down a corridor is exactly as long as the corridor.
	local len = reroot(st, h.j, cen, u, reach)

	-- Along the neck. Squared so parts bunch toward the tip, which is what gives
	-- each head a thin base and a heavy knot at the end.
	local along = w1 * w1
	local base = cen + u * (along * len)

	local t1 = u:Cross(UP)
	if t1.Magnitude < 0.001 then
		t1 = u:Cross(Vector3.new(1, 0, 0))
	end
	t1 = (t1.Magnitude > 0.001) and t1.Unit or Vector3.new(1, 0, 0)
	local t2 = u:Cross(t1).Unit

	-- Sway. Zero at the base and growing along the neck, so the head weaves while
	-- the root stays planted -- a constant offset would slide the whole serpent
	-- sideways instead.
	local sw = (c.k20 or 14) * along
	local ph = (st.pub_sway or 0) + k * 1.7
	local swing = t1 * (math.sin(ph) * sw) + t2 * (math.cos(ph * 0.7) * sw * 0.6)

	-- Thicker at the tip: neck thickness at the base, head thickness at the end.
	local thick = (c.k17 or 5) + ((c.k18 or 16) - (c.k17 or 5)) * along
	local a = w2 * math.pi * 2
	local rr = math.sqrt(w3) * thick

	local target_pos = base + swing + t1 * (rr * math.cos(a)) + t2 * (rr * math.sin(a))

	-- pure_target_pos is mandatory, not optional: heads and sway only restamp on a
	-- bucket boundary, so without the feed-forward differentiator
	-- (System.lua:507-535) the necks would step at ~15 Hz.
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	-- x6.pre survives shape switches and only cleanup runs (System.lua:152-158),
	-- so the RaycastParams and the whole cached field go here. Ymir's Flesh shares
	-- the key and rebuilds it, which is what makes swapping between the two
	-- re-probe the room rather than inheriting a stale envelope.
	x6.pre[ENV] = nil
end

M.Testing = true

M.Controls = {
	{ Type = "Slider", Name = "Probe · Reach", Min = 60, Max = 600, Key = "k13", Default = 400 },
	{ Type = "Slider", Name = "Heads · Count", Min = 1, Max = 8, Key = "k15", Default = 5, IntOnly = true },
	{ Type = "Slider", Name = "Heads · Separation (Degrees)", Min = 10, Max = 120, Key = "k16", Default = 50, IntOnly = true },
	{ Type = "Slider", Name = "Neck · Thickness", Min = 1, Max = 30, Key = "k17", Default = 5 },
	{ Type = "Slider", Name = "Head · Thickness", Min = 2, Max = 60, Key = "k18", Default = 16 },
	{ Type = "Slider", Name = "Sway · Width", Min = 0, Max = 60, Key = "k20", Default = 14 },
	{ Type = "Slider", Name = "Sway · Speed", Min = 1, Max = 300, Key = "k22", Div = 10 },
}

return M
