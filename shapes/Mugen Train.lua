local M = {}

local plrs = game:GetService("Players")

local UP = Vector3.new(0, 1, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)

-- R3 low-discrepancy triple and the golden ratio (Mech Suit.lua:12-15). Part ids
-- are a sliding window sitting wherever x6.part_id_counter has got to, never
-- 1..n, so id % n clumps every part onto a handful of slots. Decorrelated
-- irrational strides spread any id window evenly instead.
local R3_A = 0.8191725133961645
local R3_B = 0.6710436067037893
local R3_C = 0.5497004779019702
local PHI = 0.6180339887498949

-- ---- Wake Spline -------------------------------------------------------
-- Shared solver. Duplicated VERBATIM from shapes/Dragons Teeth.lua; shapes cannot
-- require a shared library (main.lua:359 fetches each file standalone), so this
-- is copy-paste, not abstraction. Edit one, edit both.
--
-- A ring buffer of where the anchor has actually been. Samples are appended at a
-- fixed STEP of arc length rather than once per frame, which is what makes the
-- spacing uniform by construction: node i back from the head is always i * STEP
-- studs along the path, so arc-length lookup is a divide instead of a search.
local WAKE = "Wake Spline"
local K = 768 -- ring capacity
local STEP = 5 -- studs between samples
local MAX_PUSH = 24 -- samples appended in one frame, ceiling
local ARC_MAX = 1400 -- studs; the leash that keeps the tail inside x1.k1 = 2000
local NODES_MAX = ARC_MAX / STEP -- most nodes f2 will ever index
local RAY_BUDGET = 4 -- ground probes per frame

-- Capacity argument. f2 runs on a stagger (System.lua:431-433): with k7 = et a
-- part's f2 may fire up to et-1 frames after the cycle's values were stamped,
-- while px keeps writing the ring every frame. Guard band is K - NODES_MAX =
-- 488. Worst case px writes MAX_PUSH * (et_max - 1) = 24 * 9 = 216 slots in that
-- window, and 216 < 488, so every slot f2 can reach stays immutable for the
-- whole cycle even though the ring is written live.

local function root_of(char)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

-- Where the trail is anchored.
--
-- px never receives cen (System.lua:285-287), so this reads the core marker the
-- way Platform.lua:380-383 does. The trail therefore follows the core rather than
-- a selected target, which is the right call here: the path conceptually belongs
-- to the marker you are dragging around, and re-rooting a recorded history onto
-- someone else's position would draw a trail they never walked.
local function anchor_of(x6)
	if x6.b then
		return x6.b.Position
	end
	local lp = plrs.LocalPlayer
	local root = lp and root_of(lp.Character)
	return root and root.Position or nil
end

local function ws_state(x6)
	local st = x6.pre[WAKE]
	if st then
		return st
	end
	st = { p = {}, age = {}, gy = {}, w = 0, count = 0, head = 1, head_count = 0, probe = 0 }
	-- age and gy are sized up front so a slot is never read before it is written.
	-- st.p cannot be preallocated the same way -- a nil is not a stored value in
	-- Lua -- so every reader checks st.p[idx] and st.count instead of assuming a
	-- full ring.
	for i = 1, K do
		st.age[i] = 0
		st.gy[i] = false
	end
	x6.pre[WAKE] = st
	return st
end

local function ws_push(st, pos, t)
	local w = st.w % K + 1
	st.w = w
	st.p[w] = pos
	st.age[w] = t
	-- false, not nil: a stored miss is a different beast from a hole in a
	-- preallocated array, and the ground probe below walks this looking for
	-- exactly false.
	st.gy[w] = false
	if st.count < K then
		st.count = st.count + 1
	end
end

-- Appends however many fixed-length samples the anchor's motion earned this
-- frame. Returns nothing; all state is in st.
local function ws_advance(st, a, t, frozen)
	if not a then
		return
	end
	if st.count == 0 then
		ws_push(st, a, t)
		return
	end
	if frozen then
		return
	end
	local last = st.p[st.w]
	local dv = a - last
	local dist = dv.Magnitude
	if dist < STEP then
		-- Standing still must not collapse the trail onto one point, so nothing
		-- is appended until the anchor has actually earned a sample.
		return
	end
	local n = math.floor(dist / STEP)
	if n > MAX_PUSH then
		-- Faster than MAX_PUSH * STEP in one frame is a teleport, not a run.
		-- Drawing the intervening samples would lay a straight line across the
		-- whole map, so start a fresh trail at the new position instead.
		st.count = 0
		st.w = 0
		ws_push(st, a, t)
		return
	end
	local dir = dv / dist
	for i = 1, n do
		ws_push(st, last + dir * (STEP * i), t)
	end
end

-- Publishes the read view. f2 indexes backward from st.head, which only moves on
-- a bucket boundary, so every part in a cycle sees the same trail even though px
-- keeps appending underneath it.
local function ws_stamp(st, x6, x1)
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
	st.head = st.w > 0 and st.w or 1
	st.head_count = st.count
	return true
end

-- Ring index of the node i samples back from the published head.
local function ws_at(st, i)
	return ((st.head - i - 1) % K) + 1
end

-- How many nodes this shape may walk back, given its trail slider and how much
-- history actually exists yet.
local function ws_nodes(st, trail_len)
	local want = math.floor((trail_len or 300) / STEP)
	if want > NODES_MAX then
		want = NODES_MAX
	end
	if want > st.head_count then
		want = st.head_count
	end
	if want < 1 then
		want = 1
	end
	return want
end

-- Ground probing is Dragons Teeth's half of the shared solver -- the train rides
-- the path the anchor actually took, including through the air, so it has no use
-- for a ground height. probe_params and ws_probe_ground are therefore omitted
-- here while the RAY_BUDGET constant and the st.gy / st.probe fields stay, so the
-- ring layout the two files share does not diverge.

-- Position at an arbitrary arc distance back from the head, interpolated between
-- the two bracketing samples so the train glides instead of snapping node to
-- node. Uniform spacing is what makes this a divide rather than a search.
local function ws_sample(st, s, n)
	local i = s / STEP
	if i < 0 then
		i = 0
	end
	local fi = math.floor(i)
	if fi > n - 1 then
		fi = n - 1
	end
	local a = st.p[ws_at(st, fi)]
	local b = st.p[ws_at(st, math.min(fi + 1, n - 1))]
	if not a then
		return nil
	end
	if not b then
		return a
	end
	return a + (b - a) * (i - fi)
end

-- ---- Mugen Train -------------------------------------------------------

-- Advances the locomotive along the recorded track.
--
-- The train's position is an arc distance measured back from the head of the
-- trail, so it is expressed in the one coordinate that stays meaningful as the
-- player keeps laying more track ahead of it.
local function run(st, c, dt)
	local speed = c.k13 or 90
	local trail = c.k11 or 420
	local s = st.s or trail

	if (c.k21 or 1) >= 2 then
		-- Shuttle: bounce between the head and the tail.
		local dir = st.dir or -1
		s = s + speed * dt * dir
		if s <= 0 then
			s, dir = 0, 1
		elseif s >= trail then
			s, dir = trail, -1
		end
		st.dir = dir
	else
		-- Chase: run up the trail toward the player, then restart from the far
		-- end. Wrapping on the live trail length rather than a stored one means a
		-- shortened trail cannot strand the train past its own tail.
		s = s - speed * dt
		if s <= 0 then
			s = trail
		end
	end
	st.s = s
end

function M.px(t, c, x6, x9, x1)
	local st = ws_state(x6)

	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end

	ws_advance(st, anchor_of(x6), t, c.k24 == true)

	-- The train integrates every frame for smooth speed, but only the stamped
	-- copy is what f2 reads, so the whole formation agrees on where the engine is
	-- for a full bucket cycle. Integrating in f2 instead would shear the train in
	-- half across a stagger.
	run(st, c, dt)
	if ws_stamp(st, x6, x1) then
		st.pub_s = st.s
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre and x6.pre[WAKE]
	if not st or st.head_count < 2 then
		return ANTI_SLEEP, nil
	end

	local n = ws_nodes(st, c.k11 or 420)
	local arc = n * STEP
	local s = st.pub_s or st.s or 0

	local id = d.id or 1
	local w1 = (id * R3_A) % 1
	local w2 = (id * R3_B) % 1
	local w3 = (id * R3_C) % 1
	local pick = (id * PHI) % 1

	local target_pos

	if pick < (c.k19 or 22) / 100 then
		-- Track. Windowed around the locomotive rather than spread over the whole
		-- trail, so the rails materialise ahead of the train and dissolve behind
		-- it; spreading the same part budget over 1400 studs would leave a scatter
		-- too sparse to read as rails at all.
		local span = 240
		local ts = s - span * 0.5 + w1 * span
		if ts < 0 then
			ts = ts + arc
		elseif ts > arc then
			ts = ts - arc
		end
		local base = ws_sample(st, ts, n)
		if not base then
			return ANTI_SLEEP, nil
		end
		local ahead = ws_sample(st, math.min(ts + STEP, arc), n) or base
		local tan = ahead - base
		local flat = Vector3.new(tan.X, 0, tan.Z)
		local fwd = (flat.Magnitude > 0.001) and flat.Unit or WORLD_FWD
		local right = fwd:Cross(UP)
		right = (right.Magnitude > 0.001) and right.Unit or Vector3.new(1, 0, 0)

		local gauge = (c.k20 or 9) * 0.5
		if w2 < 0.25 then
			-- Sleeper: a cross-tie spanning the gauge.
			target_pos = base + right * ((w3 * 2 - 1) * gauge * 1.3)
		else
			-- Rail: one of the two running lines.
			target_pos = base + right * ((w3 < 0.5) and -gauge or gauge)
		end
	else
		-- Rolling stock. Cars are laid out behind the locomotive along the same
		-- arc coordinate, so they follow the curve of the path instead of a
		-- straight body that would cut every corner you walked.
		local cars = c.k14 or 4
		if cars < 1 then
			cars = 1
		end
		local car_len = c.k15 or 26
		local pitch = car_len + (c.k18 or 10)

		local k = math.floor(w1 * cars)
		if k >= cars then
			k = cars - 1
		end
		local along = w2 * car_len
		local cs = s + k * pitch + along
		if cs > arc then
			cs = cs - arc
		end

		local base = ws_sample(st, cs, n)
		if not base then
			return ANTI_SLEEP, nil
		end
		local ahead = ws_sample(st, math.min(cs + STEP, arc), n) or base
		local tan = ahead - base
		local flat = Vector3.new(tan.X, 0, tan.Z)
		local fwd = (flat.Magnitude > 0.001) and flat.Unit or WORLD_FWD
		local right = fwd:Cross(UP)
		right = (right.Magnitude > 0.001) and right.Unit or Vector3.new(1, 0, 0)

		local hw = (c.k16 or 14) * 0.5
		local hh = c.k17 or 14

		-- A hollow box rather than a filled one. Parts are a fixed budget, and
		-- spending them on an interior nobody can see leaves the walls too thin
		-- to read; pushing every part onto a face keeps the silhouette solid.
		local u = w3 * 4
		local lat, vert
		if u < 1 then
			lat, vert = -hw, (u % 1) * hh
		elseif u < 2 then
			lat, vert = hw, (u % 1) * hh
		elseif u < 3 then
			lat, vert = ((u % 1) * 2 - 1) * hw, hh
		else
			lat, vert = ((u % 1) * 2 - 1) * hw, 0
		end

		target_pos = base + right * lat + UP * (vert + 2)
	end

	-- pure_target_pos is mandatory, not optional: the locomotive's arc position
	-- only restamps on a bucket boundary, so without the feed-forward
	-- differentiator (System.lua:507-535) a train doing 90 studs/s would visibly
	-- step at ~15 Hz instead of rolling.
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	-- x6.pre survives shape switches and only cleanup runs (System.lua:152-158),
	-- so the whole ring goes here. Dragons Teeth shares the key and rebuilds it
	-- from scratch, which is what makes swapping between the two start a fresh
	-- trail rather than inheriting a stale one.
	x6.pre[WAKE] = nil
end

M.Testing = true

M.Controls = {
	{ Type = "Slider", Name = "Trail · Length", Min = 40, Max = 1400, Key = "k11", Default = 420 },
	{ Type = "Slider", Name = "Train · Speed", Min = 10, Max = 600, Key = "k13", Default = 90 },
	{ Type = "Slider", Name = "Train · Cars", Min = 1, Max = 12, Key = "k14", Default = 4, IntOnly = true },
	{ Type = "Slider", Name = "Run Mode (1 Chase, 2 Shuttle)", Min = 1, Max = 2, Key = "k21", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Car · Length", Min = 8, Max = 60, Key = "k15", Default = 26 },
	{ Type = "Slider", Name = "Car · Width", Min = 4, Max = 40, Key = "k16", Default = 14 },
	{ Type = "Slider", Name = "Car · Height", Min = 4, Max = 40, Key = "k17", Default = 14 },
	{ Type = "Slider", Name = "Car · Gap", Min = 0, Max = 40, Key = "k18", Default = 10 },
	{ Type = "Slider", Name = "Rail · Share %", Min = 0, Max = 60, Key = "k19", Default = 22, IntOnly = true },
	{ Type = "Slider", Name = "Rail · Gauge", Min = 2, Max = 40, Key = "k20", Default = 9 },
	{ Type = "Toggle", Name = "Freeze Track", Key = "k24", Default = false },
}

return M
