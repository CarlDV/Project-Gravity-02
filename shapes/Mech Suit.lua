local M = {}

local plrs = game:GetService("Players")

local UP = Vector3.new(0, 1, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)

-- R3 low-discrepancy sequence (successive powers of the 3D plastic constant).
-- Same reason as the R2 pair in Rocket Engine: ids are a sliding window, so a
-- modulo would clump. Three decorrelated strides fill each limb box evenly.
local R3_A = 0.8191725133961645
local R3_B = 0.6710436067037893
local R3_C = 0.5497004779019702
local PHI = 0.6180339887498949

local function root_of(char)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

-- Samples the player's own character into a point cloud in root-local space.
--
-- Reading the live BaseParts rather than hardcoding a rig means R6 and R15 both
-- work with no branching, and any bundle, package or scaling the player is
-- wearing is reproduced as-is. Each part contributes points in proportion to its
-- volume, so the torso reads solid while arms stay thin instead of every limb
-- getting an equal share and the hands looking as dense as the chest.
local function build_cloud(char, detail)
	local root = root_of(char)
	if not root then
		return nil
	end
	local inv = root.CFrame:Inverse()

	local boxes, total = {}, 0
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			local sz = part.Size
			local vol = sz.X * sz.Y * sz.Z
			if vol > 0 then
				total = total + vol
				boxes[#boxes + 1] = { cf = inv * part.CFrame, size = sz, vol = vol }
			end
		end
	end
	if total <= 0 then
		return nil
	end

	local pts, n = table.create(detail), 0
	local hi = 0
	-- Lowest point in root-local space, so f2 can keep the feet on the floor at
	-- any size. Without it a scaled cloud scales its downward offsets too and the
	-- mech sinks: cen sits about 3 studs up, so at a large Size the legs end up
	-- entirely underground and only the torso shows.
	local lo = 0
	for _, b in ipairs(boxes) do
		local want = math.floor(detail * (b.vol / total) + 0.5)
		if want < 1 then
			want = 1
		end
		local sx, sy, sz = b.size.X, b.size.Y, b.size.Z
		for i = 1, want do
			local ox = ((i * R3_A) % 1 - 0.5) * sx
			local oy = ((i * R3_B) % 1 - 0.5) * sy
			local oz = ((i * R3_C) % 1 - 0.5) * sz
			local lp = b.cf * Vector3.new(ox, oy, oz)
			n = n + 1
			pts[n] = lp
			local m = lp.Magnitude
			if m > hi then
				hi = m
			end
			if lp.Y < lo then
				lo = lp.Y
			end
		end
	end
	if n == 0 then
		return nil
	end

	-- Coprime-ish stride so consecutive ids land on unrelated points: thinning
	-- degrades the whole silhouette evenly instead of erasing a limb.
	local step = math.floor(n * PHI)
	if step < 1 then
		step = 1
	end
	while n % step == 0 and step > 1 do
		step = step - 1
	end
	return { pts = pts, n = n, step = step, reach = hi, low = lo }
end

-- Rebuilds the cloud on respawn or a detail change, then stamps the placement
-- basis once per bucket cycle.
--
-- The cycle gate is what holds the mech rigid: f2 runs per part on one frame in
-- et (k7), so if each part read the live placement the body would shear across
-- frames — the constraint Hover Text.lua:139 documents. Rebuilds are keyed on
-- the character instance and part count, so a respawn or a limb being added
-- refreshes it, but a stationary mech costs nothing per frame.
function M.px(t, c, x6, x9, x1)
	local st = x6.pre["Mech Suit"]
	if not st then
		st = {}
		x6.pre["Mech Suit"] = st
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
	if st.gen == gen then
		return
	end
	st.gen = gen

	local lp = plrs.LocalPlayer
	local char = lp and lp.Character
	local root = root_of(char)
	if not root then
		st.cloud = nil
		return
	end

	local detail = math.floor(c.k16 or 1200)
	local live = 0
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			live = live + 1
		end
	end
	if st.char ~= char or st.detail ~= detail or st.live ~= live or not st.cloud then
		st.cloud = build_cloud(char, detail)
		st.char, st.detail, st.live = char, detail, live
	end

	local cf = root.CFrame
	local lv = cf.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	local fwd = (flat.Magnitude > 0.001) and flat.Unit or WORLD_FWD
	st.player_pos = cf.Position
	st.player_fwd = fwd

	-- Stationary latches a world pose the first cycle it is on, so the mech is
	-- left standing where you were rather than snapping to the origin. Cleared
	-- when the toggle goes off so re-arming re-latches at the new spot.
	if c.k14 == true then
		if not st.anchor then
			st.anchor, st.anchor_fwd = cf.Position, fwd
		end
	else
		st.anchor, st.anchor_fwd = nil, nil
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local st = x6.pre and x6.pre["Mech Suit"]
	local cloud = st and st.cloud
	if not cloud then
		return ANTI_SLEEP, nil
	end

	local scale = c.k11 or 2
	local base = st.anchor or st.player_pos or cen
	local fwd = st.anchor_fwd or st.player_fwd or WORLD_FWD
	local right = fwd:Cross(UP)

	-- Placement offset. Clearance scales with the mech so a big one does not end
	-- up standing inside you: reach is the cloud's furthest point from the root.
	local place = math.floor(c.k13 or 2)
	local gap = (c.k12 or 30) + (cloud.reach or 3) * scale
	local origin = base
	if place == 2 then
		origin = base + fwd * gap
	elseif place == 3 then
		origin = base - fwd * gap
	elseif place == 4 then
		origin = base + right * gap
	end
	-- Height is applied after placement rather than inside it, so it reads the same
	-- whether the mech is in front of you or standing on you.
	--
	-- The first term keeps the feet where they would be at Size 10: the cloud's
	-- downward offsets scale with the mech, so a big one would otherwise drive its
	-- legs through the floor. low is negative and scale > 1 lifts, scale < 1
	-- lowers, and at Size 10 the term is 0 and the mech lines up with your body.
	-- The slider is then a plain stud nudge on top, so its numbers mean the same
	-- thing at every size.
	local lift = (cloud.low or 0) * (1 - scale) + (c.k17 or 0)
	origin = origin + UP * lift

	-- Face You turns the mech to look back at the player; otherwise it faces the
	-- same way you do, so it reads as an escort rather than a mirror.
	local f = fwd
	if c.k15 == true and place ~= 1 then
		local look = base - origin
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			f = flat.Unit
		end
	end
	local r = f:Cross(UP)

	local id = d.id or 1
	local n = cloud.n
	local i = (id * cloud.step) % n + 1
	local lp = cloud.pts[i]

	-- Parts beyond the point count shell outward in golden-angle rings instead of
	-- z-fighting into one blob, the same fallback Hover Text uses for extra parts.
	local ex = 0
	local layers = math.ceil((x6.n or 0) / n)
	if layers > 1 then
		if layers > 8 then
			layers = 8
		end
		local layer = math.floor(id / n) % layers
		if layer > 0 then
			ex = layer * 0.35
		end
	end

	local sc = scale * (1 + ex * 0.06)
	local target_pos = origin + (r * lp.X + UP * lp.Y + f * -lp.Z) * sc

	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	if x6.pre then
		x6.pre["Mech Suit"] = nil
	end
end

M.Controls = {
	{ Type = "Slider", Name = "Size", Min = 5, Max = 120, Key = "k11", Default = 2, Div = 10 },
	{ Type = "Slider", Name = "Place (1 On You, 2 Front, 3 Behind, 4 Beside)", Min = 1, Max = 4, Key = "k13", Default = 2, IntOnly = true },
	{ Type = "Slider", Name = "Standoff", Min = 0, Max = 200, Key = "k12", Default = 30 },
	{ Type = "Slider", Name = "Height", Min = -100, Max = 300, Key = "k17", Default = 0 },
	{ Type = "Slider", Name = "Detail", Min = 200, Max = 4000, Key = "k16", Default = 1200, IntOnly = true },
	{ Type = "Toggle", Name = "Stationary", Key = "k14", Default = false },
	{ Type = "Toggle", Name = "Face You", Key = "k15", Default = true },
}

return M
