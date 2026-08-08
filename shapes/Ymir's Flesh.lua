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
-- Shared solver. Duplicated VERBATIM into shapes/Yamata no Orochi.lua; shapes
-- cannot require a shared library (main.lua:359 fetches each file standalone), so
-- this is copy-paste, not abstraction. Edit one, edit both.
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

-- ---- Ymir's Flesh ------------------------------------------------------

function M.px(t, c, x6, x9, x1)
	local org = anchor_of(x6)
	if not org then
		return
	end

	local st = x6.pre[ENV]
	local reach = c.k13 or 300
	if not st then
		st = { cur = 0 }
		x6.pre[ENV] = st
		build(st)
		synth(st, org, reach)
	end

	-- A teleport invalidates every plane at once. Re-synthesising is cheaper than
	-- letting the round-robin walk a whole DIRS/RAYS cycle while the crust is
	-- still wrapped around a room on the other side of the map.
	if st.org and (org - st.org).Magnitude > RESEED then
		synth(st, org, reach)
	end
	st.org = org

	sweep(st, org, reach)
	stamp(st, x6, x1, org)

	-- The pulse phase integrates every frame for smooth travel but is only read
	-- through its stamped copy, so the whole crust agrees on where the crest is
	-- for a full cycle.
	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end
	st.phase = (st.phase or 0) + dt * (c.k21 or 60)
	if st.gen ~= st.pub_gen then
		st.pub_gen = st.gen
		st.pub_phase = st.phase
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre and x6.pre[ENV]
	if not st or not st.pH then
		return ANTI_SLEEP, nil
	end

	local id = d.id or 1
	local w1 = (id * R3_A) % 1
	local w2 = (id * R3_B) % 1
	local w3 = (id * R3_C) % 1

	-- Weyl stride onto a lattice direction, never id % DIRS.
	local j = math.floor(((id * PHI) % 1) * DIRS) + 1
	if j > DIRS then
		j = DIRS
	end

	local u = st.dir[j]
	local reach = c.k13 or 300
	local surf = c.k18 or 1

	-- Surface filter, applied to the measured normal rather than to the direction
	-- probed, so "floor" means a surface you could stand on regardless of which
	-- way the ray happened to travel to reach it.
	if surf > 1 then
		local N = st.pN[j]
		local ny = N and N.Y or 0
		local keep
		if surf == 2 then
			keep = ny > 0.6 -- floor
		elseif surf == 3 then
			keep = ny > -0.6 and ny < 0.6 -- wall
		else
			keep = ny < -0.6 -- ceiling
		end
		if not keep then
			-- Fold rejected parts onto a neighbouring direction rather than
			-- dropping them: an idle part still gets a velocity every frame, and
			-- parking a third of the cloud in place looks like a bug.
			local step = math.floor(w1 * DIRS)
			for probe = 1, 12 do
				local jj = ((j + step * probe - 1) % DIRS) + 1
				local NN = st.pN[jj]
				local yy = NN and NN.Y or 0
				local ok
				if surf == 2 then
					ok = yy > 0.6
				elseif surf == 3 then
					ok = yy > -0.6 and yy < 0.6
				else
					ok = yy < -0.6
				end
				if ok then
					j = jj
					u = st.dir[jj]
					break
				end
			end
		end
	end

	local s = reroot(st, j, cen, u, reach)
	local base = cen + u * s
	local N = st.pN[j] or -u

	-- Open sky: with nothing to cling to, the crust would balloon out to full
	-- reach and read as a plain sphere. Pulling it in to its own radius keeps the
	-- shape recognisably a skin rather than a bubble.
	if not st.pS[j] then
		local sky = c.k14 or 140
		if s > sky then
			base = cen + u * sky
		end
	end

	-- Patch scatter, spread in the plane of the surface so the crust reads as a
	-- sheet lying on the face rather than a fog around it.
	local t1 = N:Cross(UP)
	if t1.Magnitude < 0.001 then
		t1 = N:Cross(Vector3.new(1, 0, 0))
	end
	t1 = (t1.Magnitude > 0.001) and t1.Unit or Vector3.new(1, 0, 0)
	local t2 = N:Cross(t1).Unit

	local spread = (c.k15 or 110) / 100 * (s * 0.12)
	local a = w2 * math.pi * 2
	local rr = math.sqrt(w3) * spread

	-- The pulse. Displacement runs along the MEASURED normal, which is the tell no
	-- fixed-geometry shape can fake: one crest heaves vertically off the floor,
	-- punches sideways off a wall and drops off the ceiling, all in the same
	-- frame, because each part is riding its own surface.
	local plen = c.k22 or 120
	if plen < 1 then
		plen = 1
	end
	local ph = (st.pub_phase or 0)
	local wave = math.sin((s - ph) / plen * math.pi * 2)
	local lift = (c.k17 or 1) + (c.k20 or 40) * 0.5 * (wave + 1) * 0.5

	local thick = (c.k16 or 4) * (w1 - 0.5)
	local target_pos = base + t1 * (rr * math.cos(a)) + t2 * (rr * math.sin(a)) + N * (lift + thick)

	-- pure_target_pos is mandatory, not optional: the field and the pulse phase
	-- only restamp on a bucket boundary, so without the feed-forward
	-- differentiator (System.lua:507-535) the crest would step at ~15 Hz.
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	-- x6.pre survives shape switches and only cleanup runs (System.lua:152-158),
	-- so the RaycastParams and the whole cached field go here. Orochi shares the
	-- key and rebuilds it, which is what makes swapping between the two re-probe
	-- the room rather than inheriting a stale envelope.
	x6.pre[ENV] = nil
end

M.Testing = true

M.Controls = {
	{ Type = "Slider", Name = "Probe · Reach", Min = 60, Max = 600, Key = "k13", Default = 300 },
	{ Type = "Slider", Name = "Open Sky · Radius", Min = 20, Max = 600, Key = "k14", Default = 140 },
	{ Type = "Slider", Name = "Surface (1 All, 2 Floor, 3 Walls, 4 Ceiling)", Min = 1, Max = 4, Key = "k18", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Skin · Patch %", Min = 40, Max = 250, Key = "k15", Default = 110, IntOnly = true },
	{ Type = "Slider", Name = "Skin · Thickness", Min = 0, Max = 40, Key = "k16", Default = 4 },
	{ Type = "Slider", Name = "Skin · Lift", Min = -6, Max = 40, Key = "k17", Default = 1 },
	{ Type = "Slider", Name = "Pulse · Height", Min = 0, Max = 200, Key = "k20", Default = 40 },
	{ Type = "Slider", Name = "Pulse · Speed", Min = 0, Max = 300, Key = "k21", Default = 60 },
	{ Type = "Slider", Name = "Pulse · Length", Min = 20, Max = 400, Key = "k22", Default = 120 },
}

return M
