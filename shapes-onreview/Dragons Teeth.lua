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
-- Shared solver. Duplicated VERBATIM into shapes/Mugen Train.lua; shapes cannot
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

local function probe_params(st)
	local rp = st.rp
	if rp then
		return rp
	end
	rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	-- Claimed parts are all CanCollide = false locally (System.lua:719-721), so a
	-- client with this property steps straight through the debris cloud and finds
	-- real ground. Older clients have no such property, hence pcall rather than a
	-- hard dependency -- the same reasoning as Platform.lua:296-309.
	pcall(function()
		rp.RespectCanCollide = true
	end)
	st.rp = rp
	return rp
end

-- Fills in ground height for a few unprobed nodes per frame. Bounded by
-- RAY_BUDGET so cost never scales with trail length or part count.
--
-- This is the one value f2 reads that can change mid-cycle: the probe walks back
-- from the live write cursor, which overlaps the range f2 is reading from the
-- stamped head. A node therefore pops once from its fallback height to real
-- ground the first time it is probed. Left deliberately: gy is written once and
-- never revised, and the probe lands during the tooth's 0.35 s rise while it is
-- still short, so the pop is small and happens at most once per node.
local function ws_probe_ground(st, reach)
	local budget = RAY_BUDGET
	local scanned = 0
	local limit = st.count
	if limit > NODES_MAX then
		limit = NODES_MAX
	end
	while budget > 0 and scanned < limit do
		local i = st.probe % limit
		st.probe = i + 1
		scanned = scanned + 1
		local idx = ((st.w - i - 1) % K) + 1
		local p = st.p[idx]
		if p and st.gy[idx] == false then
			local origin = Vector3.new(p.X, p.Y + reach, p.Z)
			local hit = workspace:Raycast(origin, Vector3.new(0, -(reach * 2), 0), probe_params(st))
			-- A miss stores the node's own height, so the tooth still stands
			-- somewhere sane over a void instead of retrying the ray forever.
			st.gy[idx] = hit and hit.Position.Y or p.Y
			budget = budget - 1
		end
	end
end

-- Horizontal tangent at a node, for laying the ridge across the path. Vertical
-- is dropped because the ridge is a wall standing on the ground, not a ribbon
-- following a jump arc.
local function ws_tangent(st, i, n)
	local a = st.p[ws_at(st, math.min(i + 1, n - 1))]
	local b = st.p[ws_at(st, math.max(i - 1, 0))]
	if not a or not b then
		return WORLD_FWD
	end
	local d = b - a
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 0.001 then
		return WORLD_FWD
	end
	return flat.Unit
end

-- ---- Dragons Teeth -----------------------------------------------------

function M.px(t, c, x6, x9, x1)
	local st = ws_state(x6)
	ws_advance(st, anchor_of(x6), t, c.k22 == true)
	if c.k21 == true then
		ws_probe_ground(st, 120)
	end
	ws_stamp(st, x6, x1)
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre and x6.pre[WAKE]
	if not st or st.head_count < 1 then
		return ANTI_SLEEP, nil
	end

	local n = ws_nodes(st, c.k11 or 300)
	local arc = n * STEP

	local id = d.id or 1
	local w1 = (id * R3_A) % 1
	local w2 = (id * R3_B) % 1
	local w3 = (id * R3_C) % 1
	local pick = (id * PHI) % 1

	local snap = c.k21 == true
	local target_pos

	if pick < (c.k16 or 75) / 100 then
		-- A fang. Teeth sit on a fixed pitch along the path rather than at every
		-- node, so the row reads as discrete spikes instead of a continuous comb,
		-- and the pitch stays put as the trail grows.
		local pitch = c.k14 or 18
		if pitch < 1 then
			pitch = 1
		end
		local teeth = math.floor(arc / pitch)
		if teeth < 1 then
			teeth = 1
		end
		local k = math.floor(w1 * teeth)
		if k >= teeth then
			k = teeth - 1
		end
		local i = math.floor((k * pitch) / STEP + 0.5)
		if i > n - 1 then
			i = n - 1
		end
		local idx = ws_at(st, i)
		local base = st.p[idx]
		if not base then
			return ANTI_SLEEP, nil
		end

		local gy = st.gy[idx]
		local base_y = (snap and gy) and gy or (base.Y - (c.k20 or 3))

		-- Birth time, not wall clock: a tooth is flat the instant its node is laid
		-- and rises on its own schedule, so behind a sprinting player the fangs
		-- slam up in the order the ground was crossed. Keying this to t would
		-- raise the whole row in unison and lose the sequence entirely.
		--
		-- k19 carries Div = 10, which scales only the panel reading
		-- (UI.lua:1223-1225) -- the stored value is already seconds, as Rocket
		-- Engine.lua:75 relies on for its own Div slider.
		local rise = c.k19 or 0.35
		if rise < 0.01 then
			rise = 0.01
		end
		local age = t - (st.age[idx] or t)
		local u = age / rise
		if u < 0 then
			u = 0
		elseif u > 1 then
			u = 1
		end
		local grow = u * u * (3 - 2 * u)

		local h = w2
		local height = (c.k13 or 34) * grow
		-- Taper to a point, so it reads as a fang rather than a post.
		local r = (c.k15 or 7) * (1 - h)
		local a = w3 * math.pi * 2
		target_pos = Vector3.new(
			base.X + math.cos(a) * r,
			base_y + h * height,
			base.Z + math.sin(a) * r
		)
	else
		-- The ridge: a low continuous kerb joining the fangs, so the trail reads
		-- as one wall rather than a scatter of unrelated spikes.
		local i = w1 * (n - 1)
		local fi = math.floor(i)
		if fi > n - 1 then
			fi = n - 1
		end
		local idx = ws_at(st, fi)
		local base = st.p[idx]
		if not base then
			return ANTI_SLEEP, nil
		end
		local gy = st.gy[idx]
		local base_y = (snap and gy) and gy or (base.Y - (c.k20 or 3))

		local tan = ws_tangent(st, fi, n)
		local right = tan:Cross(UP)
		if right.Magnitude < 0.001 then
			right = Vector3.new(1, 0, 0)
		else
			right = right.Unit
		end

		local lateral = (w2 * 2 - 1) * (c.k18 or 6) * 0.5
		local height = w3 * (c.k17 or 4)
		target_pos = base + right * lateral + UP * (height + (base_y - base.Y))
	end

	-- pure_target_pos is mandatory, not optional: the trail head only restamps on
	-- a bucket boundary, so without the feed-forward differentiator
	-- (System.lua:507-535) the whole wall would visibly step at ~15 Hz.
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	-- x6.pre survives shape switches and only cleanup runs (System.lua:152-158),
	-- so the RaycastParams and the whole ring go here. Mugen Train shares the key
	-- and rebuilds it from scratch, which is what makes swapping between the two
	-- start a fresh trail rather than inheriting a stale one.
	x6.pre[WAKE] = nil
end

M.Testing = true

M.Controls = {
	{ Type = "Slider", Name = "Trail · Length", Min = 40, Max = 1400, Key = "k11", Default = 300 },
	{ Type = "Slider", Name = "Tooth · Height", Min = 5, Max = 120, Key = "k13", Default = 34 },
	{ Type = "Slider", Name = "Tooth · Pitch", Min = 6, Max = 80, Key = "k14", Default = 18 },
	{ Type = "Slider", Name = "Tooth · Thickness", Min = 1, Max = 30, Key = "k15", Default = 7 },
	{ Type = "Slider", Name = "Tooth · Fill %", Min = 30, Max = 100, Key = "k16", Default = 75, IntOnly = true },
	{ Type = "Slider", Name = "Ridge · Height", Min = 0, Max = 30, Key = "k17", Default = 4 },
	{ Type = "Slider", Name = "Ridge · Width", Min = 1, Max = 40, Key = "k18", Default = 6 },
	{ Type = "Slider", Name = "Rise · Seconds", Min = 1, Max = 30, Key = "k19", Div = 10 },
	{ Type = "Slider", Name = "Base · Drop", Min = 0, Max = 30, Key = "k20", Default = 3 },
	{ Type = "Toggle", Name = "Ground Snap", Key = "k21", Default = true },
	{ Type = "Toggle", Name = "Freeze Wall", Key = "k22", Default = false },
}

return M
