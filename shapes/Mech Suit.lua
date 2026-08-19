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

local function gcd(a, b)
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

local function root_of(char)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

-- Samples the player's own character into a point cloud.
--
-- The offsets stored here are PART-LOCAL, not root-local, and each point records
-- which part owns it. That is the whole basis of the tracking: px re-reads every
-- part's live CFrame once per bucket cycle, so recomposing owner_transform *
-- offset reproduces the character's actual pose -- every joint angle, a jump, a
-- crouch, a tool pose, an emote, ragdoll -- rather than a canned gait played over
-- a snapshot. It also means R6 and R15 both work with no branching, and any
-- bundle, package or scaling the player wears is reproduced as-is.
--
-- pts[] keeps the pose at build time as a rest reference so Motion Gain can
-- interpolate: gain 1 is exactly the live pose, 0 is rigid, above 1 exaggerates.
--
-- Each part contributes points in proportion to its volume, so the torso reads
-- solid while arms stay thin instead of every limb getting an equal share and the
-- hands looking as dense as the chest.
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
				boxes[#boxes + 1] = {
					part = part,
					cf = inv * part.CFrame,
					size = sz,
					vol = vol,
				}
			end
		end
	end
	if total <= 0 then
		return nil
	end

	local pts = table.create(detail)
	local offs = table.create(detail)
	local owner = table.create(detail)
	local n = 0

	for bi, b in ipairs(boxes) do
		local want = math.floor(detail * (b.vol / total) + 0.5)
		if want < 1 then
			want = 1
		end
		local sx, sy, sz = b.size.X, b.size.Y, b.size.Z
		for i = 1, want do
			local off = Vector3.new(
				((i * R3_A) % 1 - 0.5) * sx,
				((i * R3_B) % 1 - 0.5) * sy,
				((i * R3_C) % 1 - 0.5) * sz
			)
			n = n + 1
			offs[n] = off
			owner[n] = bi
			pts[n] = b.cf * off
		end
	end
	if n == 0 then
		return nil
	end

	-- Stride that shares no factor with n, so consecutive ids land on unrelated
	-- points and thinning degrades the whole silhouette evenly instead of erasing
	-- a limb. Testing `n % step == 0` only rules out step *dividing* n, which
	-- leaves every shared factor in place -- at n = 1200 that reached 400 of the
	-- 1200 slots and silently tripled the effective spacing. Same real gcd walk
	-- Hover Text uses.
	local step = math.floor(n * PHI)
	if step < 1 then
		step = 1
	end
	while n > 1 and gcd(step, n) ~= 1 do
		step = step + 1
		if step >= n then
			step = 1
			break
		end
	end
	return { boxes = boxes, pts = pts, offs = offs, owner = owner, n = n, step = step }
end

-- Re-reads the live pose, then stamps the placement basis once per bucket cycle.
--
-- The cycle gate is what holds the mech rigid: f2 runs per part on one frame in
-- et (k7), so if each part read the live placement the body would shear across
-- frames -- the constraint Hover Text.lua:139 documents. The pose is refreshed on
-- the same gate for the same reason: every part in a cycle must agree on which
-- frame of the animation it is drawing.
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

	local lp = plrs.LocalPlayer
	local char = lp and lp.Character
	local root = root_of(char)
	if not root then
		st.cloud = nil
		st.xf = nil
		return
	end

	-- Which body the mech stands on and animates from.
	--
	-- The mech deliberately does not read the per-part cen System hands f2. With
	-- several targets that value differs per part (System.lua:446), which would
	-- deal the body out across all of them and leave one thin copy standing on
	-- each. One target is chosen here and every part uses it, so the mech is
	-- always a single whole body. Target Everyone is ignored for the same reason;
	-- with no explicit target the mech stays on you.
	local anchor_root = root
	local targets = x1 and x1.Targets
	if targets then
		for _, pl in ipairs(targets) do
			local r = pl and pl.Parent and root_of(pl.Character)
			if r then
				anchor_root = r
				break
			end
		end
	end

	local gen = math.floor((x6.f or 0) / et)
	if st.gen == gen then
		return
	end
	st.gen = gen

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
	local cloud = st.cloud
	if not cloud then
		st.xf = nil
		return
	end

	-- The live pose. One inverse-root compose per BasePart -- six for R6, fifteen
	-- for R15 -- and f2 then costs a single CFrame*Vector3 per part it touches.
	--
	-- low and reach are re-derived here rather than cached on the cloud because
	-- both move with the pose: crouching raises the lowest point, a raised arm
	-- extends the reach. Each is taken from the part's oriented box projected onto
	-- the axis of interest, which is exact for a box and costs no per-point work.
	local inv = root_of(char).CFrame:Inverse()
	local xf = st.xf
	if not xf then
		xf = {}
		st.xf = xf
	end
	local low, reach = 0, 0
	for bi, b in ipairs(cloud.boxes) do
		local part = b.part
		-- Not gated on part.Parent. A BasePart answers CFrame whether or not it is
		-- parented, and gating on it froze the whole silhouette any frame a limb was
		-- momentarily detached. A part that has genuinely gone is caught by the live
		-- count check above, which rebuilds the cloud.
		xf[bi] = inv * part.CFrame
	end
	-- low and reach are measured over the sampled points, not the parts' boxes.
	-- f2 places a part at origin + basis * lp * scale, so the lowest thing drawn is
	-- at origin.Y + min(lp.Y) * scale -- and the lift term below cancels the scale
	-- against exactly that number to keep the feet still. Measuring the full oriented
	-- box instead over-corrects, because the low-discrepancy offsets sit inside the
	-- box and only approach its corners. One pass per bucket cycle, which is the same
	-- order of work f2 already does per frame.
	local offs, owner = cloud.offs, cloud.owner
	for i = 1, cloud.n do
		local lp = xf[owner[i]] * offs[i]
		if lp.Y < low then
			low = lp.Y
		end
		local m = lp.Magnitude
		if m > reach then
			reach = m
		end
	end
	st.low, st.reach = low, reach

	local cf = anchor_root.CFrame
	local lv = cf.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	local fwd = (flat.Magnitude > 0.001) and flat.Unit or WORLD_FWD
	st.player_pos = cf.Position
	st.player_fwd = fwd
	-- The tracked body's own up axis, so pitch and roll carry through: lie down,
	-- ragdoll or swim and the mech goes with you. Yaw is deliberately not taken
	-- from here -- placement and Face You own that -- so this is only the tilt.
	st.player_up = cf.UpVector
	-- Where you actually are, which is what Face You turns toward. Separate from
	-- player_pos now that the mech can be standing on somebody else.
	st.host_pos = root.Position

	-- Stationary latches a world pose the first cycle it is on, so the mech is
	-- left standing where you were rather than snapping to the origin. Position
	-- and facing only: the pose keeps tracking, because Stationary is about not
	-- following you around, not about freezing the animation. Cleared when the
	-- toggle goes off so re-arming re-latches at the new spot.
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
	local xf = st and st.xf
	if not cloud or not xf then
		return ANTI_SLEEP, nil
	end

	local scale = c.k11 or 2
	local base = st.anchor or st.player_pos or cen
	local fwd = st.anchor_fwd or st.player_fwd or WORLD_FWD
	local right = fwd:Cross(UP)

	-- Placement offset. Clearance scales with the mech so a big one does not end
	-- up standing inside you: reach is the cloud's furthest point from the root.
	local place = math.floor(c.k13 or 2)
	local gap = (c.k12 or 30) + (st.reach or 3) * scale
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
	local lift = (st.low or 0) * (1 - scale) + (c.k17 or 0)
	origin = origin + UP * lift

	-- Face You turns the mech to look back at you; otherwise it faces the same way
	-- the body it stands on does, so it reads as an escort rather than a mirror.
	-- Turning toward host_pos, not base: with a target selected the mech stands on
	-- them, and facing base would have it staring at its own feet.
	local f = fwd
	if c.k15 == true then
		local look = (st.host_pos or base) - origin
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			f = flat.Unit
		end
	end

	-- Body basis. Tilt Track blends world up toward the tracked body's own up, so
	-- 0 keeps the mech standing however you are lying and 1 matches you exactly.
	-- The forward axis is then re-orthogonalised against that up rather than used
	-- raw, otherwise a tilted basis would shear the whole silhouette.
	local u = UP
	local tilt = c.k19
	if tilt == nil then
		tilt = 1
	end
	if tilt > 0 and st.player_up then
		u = (tilt >= 1) and st.player_up or UP:Lerp(st.player_up, tilt)
		local um = u.Magnitude
		u = (um > 0.001) and (u / um) or UP
	end
	local r = f:Cross(u)
	if r.Magnitude < 0.0001 then
		r = f:Cross(UP)
		if r.Magnitude < 0.0001 then
			r = Vector3.new(1, 0, 0)
		end
	end
	r = r.Unit
	f = u:Cross(r)

	local id = d.id or 1
	local n = cloud.n
	local i = (id * cloud.step) % n + 1

	-- The tracked point. owner tells us which part carries this sample, xf holds
	-- that part's live transform in root space, so this single compose is what
	-- makes the mech mirror the character instead of replaying a fixed pose.
	local m = xf[cloud.owner[i]]
	local off = cloud.offs[i]
	local lp
	if m then
		lp = m * off
	else
		lp = cloud.pts[i]
	end

	-- Motion Gain interpolates against the pose the cloud was built in: 1 is the
	-- live pose untouched, 0 freezes the mech rigid, above 1 overdrives every
	-- joint away from rest. Skipped entirely at 1, which is the default.
	local gain = c.k18
	if gain == nil then
		gain = 1
	end
	if gain ~= 1 then
		local rest = cloud.pts[i]
		lp = rest + (lp - rest) * gain
	end

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
	local target_pos = origin + (r * lp.X + u * lp.Y + f * -lp.Z) * sc

	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	if x6.pre then
		x6.pre["Mech Suit"] = nil
	end
end

M.Controls = {
	{ Type = "Slider", Name = "Size", Min = 5, Max = 120, Key = "k11", Default = 2, Div = 10 },
	{ Type = "Slider", Name = "Place (1 On You, 2 Front, 3 Behind, 4 Beside)", Min = 1, Max = 4, Key = "k13", Default = 2, IntOnly = true, Desc = "1 on you, 2 in front, 3 behind, 4 beside." },
	{ Type = "Slider", Name = "Standoff", Min = 0, Max = 200, Key = "k12", Default = 30 },
	{ Type = "Slider", Name = "Height", Min = -100, Max = 300, Key = "k17", Default = 0 },
	{ Type = "Slider", Name = "Detail", Min = 200, Max = 4000, Key = "k16", Default = 1200, IntOnly = true },
	{ Type = "Slider", Name = "Motion Gain", Min = 0, Max = 200, Key = "k18", Default = 1, Div = 100, Desc = "100 mirrors you exactly. 0 stands rigid. Above 100 overdrives every joint." },
	{ Type = "Slider", Name = "Tilt Track", Min = 0, Max = 100, Key = "k19", Default = 1, Div = 100, Desc = "How much of your pitch and roll the mech copies. 0 always stands upright." },
	{ Type = "Toggle", Name = "Stationary", Key = "k14", Default = false, Desc = "Leaves the mech standing where it was instead of following you." },
	{ Type = "Toggle", Name = "Face You", Key = "k15", Default = true, Desc = "Turns the mech to look back at you." },
}

return M
