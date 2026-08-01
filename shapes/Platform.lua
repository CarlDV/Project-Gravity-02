local M = {}

-- A rideable platform that follows you, with its visible surface built out of the
-- parts the script has already claimed.
--
-- Why it is split in two: a shape module only gets to return a velocity for
-- claimed parts, and x4.f1 hands every claimed part CanCollide = false and a
-- 0.001 density. Neither is negotiable from in here, and both mean a floor made
-- purely of claimed parts is one you fall straight through. So M.px owns a single
-- anchored pad that is the thing you actually stand on, and M.f2 arranges the
-- claimed parts into the surface resting on top of it. Turn Solid Pad off and you
-- keep the visual as pure decoration.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local UP = Vector3.new(0, 1, 0)
-- A floor should not swing around when the camera does, so the lattice is built
-- on world axes and the Spin control provides any rotation. That also means there
-- is no camera-derived basis to shear when the sweep is bucketed.
local WORLD_RIGHT = Vector3.new(1, 0, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)
local GOLDEN_ANGLE = 2.399963229728653
local DEG = math.pi / 180

local PAD_THICKNESS = 1
local PART_LIFT = 0.6 -- claimed parts rest just above the pad face, like debris
local LAYER_GAP = 1.2
-- An anchored part driven up through a character launches it. The plane tracks
-- the player's own Y so it normally cannot outrun them, but Look Influence can
-- move it a long way in one frame. Only the climb is capped: a drop has to stay
-- instant or Catch Mode would never catch anything.
local RISE_LIMIT = 80
local FALL_SPEED = -5 -- Y velocity that counts as falling for Catch Mode
local STAND_BAND = 6 -- how far above the plane still counts as standing on it
local SNAP_DIST = 250 -- respawn/teleport: reseat rather than fly across the map
local LEAD_FULL_SPEED = 24 -- horizontal speed at which Lead reaches its full value

-- slot -> a point in the footprint, in units of the Size control (-1 .. 1).
local function layout_xz(layout, slot, count, spin)
	if layout >= 2.5 then
		-- Ring: even angular spread over a thin annulus, three deep so a large
		-- claim reads as a band rather than a single-part-wide circle.
		local r = 0.82 + 0.18 * ((slot % 3) / 2)
		local theta = (slot / count) * math.pi * 2 + spin
		return math.cos(theta) * r, math.sin(theta) * r
	elseif layout >= 1.5 then
		-- Square grid.
		local cols = math.ceil(math.sqrt(count))
		if cols < 1 then
			cols = 1
		end
		local rows = math.ceil(count / cols)
		local u = cols > 1 and ((slot % cols) / (cols - 1)) * 2 - 1 or 0
		local w = rows > 1 and (math.floor(slot / cols) / (rows - 1)) * 2 - 1 or 0
		if spin ~= 0 then
			local cs, sn = math.cos(spin), math.sin(spin)
			u, w = u * cs - w * sn, u * sn + w * cs
		end
		return u, w
	end
	-- Disc: sunflower spiral. sqrt keeps the density even instead of piling every
	-- part into the middle.
	local r = math.sqrt((slot + 0.5) / count)
	local theta = slot * GOLDEN_ANGLE + spin
	return math.cos(theta) * r, math.sin(theta) * r
end

local function make_pad(x6, x1)
	local pad = Instance.new("Part")
	pad.Name = "GRV_PLATFORM"
	pad.Anchored = true
	pad.CanCollide = true
	pad.CanTouch = false -- nothing should be running Touched handlers on this
	pad.CastShadow = false
	pad.Locked = true
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Material = Enum.Material.ForceField
	pad.Color = x1.k3 or Color3.fromRGB(255, 105, 180)
	pad.Transparency = 1
	-- x1.k5 is the tag list x7.e screens candidates against, so tagging the pad is
	-- what keeps our own claim sweep from grabbing the floor out from under you.
	-- Anchored would exclude it too; this survives someone clearing that flag.
	local tag = Instance.new("Folder")
	tag.Name = "NoAttract"
	tag.Parent = pad
	-- Living in the core's folder means Q takes the pad with it even if cleanup
	-- never runs. px re-creates it if the folder goes away underneath us.
	pad.Parent = (x6.b and x6.b.Parent) or workspace
	return pad
end

function M.px(t, c, x6, x9, x1)
	local st = x6.pre["Platform"]
	if not st then
		st = {}
		x6.pre["Platform"] = st
	end

	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end

	local char = LocalPlayer and LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	local anchor, vel
	if c.k22 ~= false and hrp then
		anchor = hrp.Position
		vel = hrp.AssemblyLinearVelocity
	elseif x6.b then
		-- Follow Player off: sit under the core instead, so the platform lands
		-- under whoever is being targeted.
		anchor = x6.b.Position
		vel = Vector3.zero
	end

	if not anchor then
		-- Mid-respawn. Keep the pad but stop it being solid, so it is not left
		-- floating as a collidable slab where the old character died.
		st.plane = nil
		local pad = st.pad
		if pad and pad.Parent and pad.CanCollide then
			pad.CanCollide = false
		end
		return
	end

	local size = c.k11 or 8
	local offset = c.k12 or -3

	local target = anchor + UP * offset

	local lead = c.k14 or 0
	if lead > 0 then
		-- Driven off velocity, not off a per-frame position delta. The original
		-- compared successive positions against a fixed 0.1 threshold, which makes
		-- the whole behaviour framerate-dependent: the same walk clears it at 30fps
		-- and fails it at 240.
		local flat = Vector3.new(vel.X, 0, vel.Z)
		local sp_sq = flat:Dot(flat)
		if sp_sq > 1 then
			local sp = math.sqrt(sp_sq)
			local reach = math.min(sp / LEAD_FULL_SPEED, 1) * lead
			target = target + flat * (reach / sp)
		end
	end

	local look = c.k15 or 0
	if look ~= 0 then
		local cam = workspace.CurrentCamera
		if cam then
			target = target + UP * (cam.CFrame.LookVector.Y * look)
		end
	end

	local pos = st.pos
	if not pos or st.char ~= char or (pos - target).Magnitude > SNAP_DIST then
		-- New character, or a teleport. Reseat instead of lerping, which is what
		-- the original never did: it kept the old platform and a stale reference
		-- position across a respawn.
		pos = target
	else
		-- Exponential decay against real dt. A flat per-frame lerp fraction, as in
		-- the original, converges at whatever rate the client happens to render at.
		local alpha = 1 - math.exp(-(c.k13 or 12) * dt)
		local nxt = pos + (target - pos) * alpha
		local max_rise = RISE_LIMIT * dt
		if nxt.Y - pos.Y > max_rise then
			nxt = Vector3.new(nxt.X, pos.Y + max_rise, nxt.Z)
		end
		pos = nxt
	end
	st.pos = pos
	st.char = char

	local want_pad = c.k19 ~= false
	local pad = st.pad
	if want_pad then
		if not pad or not pad.Parent then
			pad = make_pad(x6, x1)
			st.pad = pad
		end

		local solid = true
		if c.k20 == true then
			-- Catch Mode: out of the way while you are on the ground, solid the
			-- moment you start falling. Standing on it counts as well, or landing
			-- would zero your fall speed and immediately switch the floor off
			-- again.
			solid = vel.Y < FALL_SPEED
			if not solid and hrp then
				local rel = hrp.Position - pos
				local above = rel.Y
				if above > 0 and above < STAND_BAND and math.abs(rel.X) < size and math.abs(rel.Z) < size then
					solid = true
				end
			end
		end

		local span = size * 2
		local want_size = Vector3.new(span, PAD_THICKNESS, span)
		if pad.Size ~= want_size then
			pad.Size = want_size
		end
		-- Top face sits exactly on the plane, so you stand level with the surface
		-- the claimed parts form rather than sunk into it.
		pad.CFrame = CFrame.new(pos - UP * (PAD_THICKNESS * 0.5))
		if pad.CanCollide ~= solid then
			pad.CanCollide = solid
		end
		local want_trans = (c.k21 == true) and 0.6 or 1
		if pad.Transparency ~= want_trans then
			pad.Transparency = want_trans
		end
	elseif pad then
		if pad.Parent then
			pad:Destroy()
		end
		st.pad = nil
	end

	-- Everything below is stamped once per bucket cycle and read by every part in
	-- that cycle. System runs each part's f2 on one frame in every x1.k7
	-- (System.lua f3_body), so a per-frame value would have neighbouring parts
	-- targeting planes a frame or two apart and the surface would ripple. The pad
	-- above is still moved every frame -- the thing you stand on stays smooth
	-- regardless -- and returning pure_target_pos lets System's feed-forward term
	-- turn the stepped target back into continuous motion.
	local et = x1.k7
	if not et then
		local n = x6.n or 0
		et = n > 5000 and 10 or (n > 2500 and 6 or (n > 1000 and 3 or 1))
	end
	if x1["Force Smooth (Lags)"] then
		et = 1
	end
	if et < 1 then
		et = 1
	end
	local gen = math.floor((x6.f or 0) / et)
	if st.gen == gen and st.plane then
		return
	end
	st.gen = gen
	st.plane = pos
	st.size = size
	st.layout = c.k18 or 1
	st.spin = t * (c.k17 or 0) * DEG

	local layers = math.floor(c.k16 or 1)
	if layers < 1 then
		layers = 1
	elseif layers > 6 then
		layers = 6
	end
	st.layers = layers
	-- Quantised so a part being claimed or dropped does not reshuffle the whole
	-- surface. Which slot a part owns is derived from the count, so leaving it raw
	-- means the floor churns continuously during the opening sweep.
	local n = x6.n or 1
	if n < 1 then
		n = 1
	end
	st.count = math.ceil(n / 16) * 16
	st.per_layer = math.ceil(st.count / layers)
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre["Platform"]
	local plane = st and st.plane
	if not plane then
		return ANTI_SLEEP, nil
	end

	local slot = (d.id or 1) % st.count
	local layer = 0
	if st.layers > 1 then
		layer = math.floor(slot / st.per_layer)
		if layer >= st.layers then
			layer = st.layers - 1
		end
		slot = slot % st.per_layer
	end

	local u, w = layout_xz(st.layout, slot, st.per_layer, st.spin)
	local target_pos = plane
		+ WORLD_RIGHT * (u * st.size)
		+ WORLD_FWD * (w * st.size)
		+ UP * (PART_LIFT + layer * LAYER_GAP)

	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

-- Called by System when the shape is switched away, on stop, on disable, and on
-- teardown. Without it the pad would outlive the shape that owns it.
function M.cleanup(x6, x1)
	local st = x6.pre and x6.pre["Platform"]
	if not st then
		return
	end
	if st.pad and st.pad.Parent then
		st.pad:Destroy()
	end
	x6.pre["Platform"] = nil
end

M.Controls = {
	{ Type = "Slider", Name = "Size", Min = 2, Max = 60, Key = "k11", Default = 8 },
	{
		Type = "Slider",
		Name = "Height Offset",
		Min = -40,
		Max = 20,
		Key = "k12",
		Default = -3,
		Desc = "Where the surface sits relative to you. -3 is roughly under your feet.",
	},
	{ Type = "Slider", Name = "Follow Speed", Min = 1, Max = 50, Key = "k13", Default = 12, ExactMax = true },
	{
		Type = "Slider",
		Name = "Lead",
		Min = 0,
		Max = 40,
		Key = "k14",
		Default = 3,
		Desc = "Pushes the platform ahead of you as you move, scaled by how fast you are going.",
	},
	{
		Type = "Slider",
		Name = "Look Influence",
		Min = 0,
		Max = 20,
		Key = "k15",
		Default = 0,
		Desc = "Raises and lowers the platform with the camera pitch. 0 keeps it level.",
	},
	{ Type = "Slider", Name = "Layers", Min = 1, Max = 6, Key = "k16", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Spin", Min = 0, Max = 300, Key = "k17", Default = 0 },
	{
		Type = "Slider",
		Name = "Layout",
		Min = 1,
		Max = 3,
		Key = "k18",
		Default = 1,
		IntOnly = true,
		Desc = "1 disc, 2 square, 3 ring.",
	},
	{
		Type = "Toggle",
		Name = "Solid Pad",
		Key = "k19",
		Default = true,
		Desc = "Adds the anchored slab you actually stand on. Off leaves the parts as decoration only.",
	},
	{
		Type = "Toggle",
		Name = "Catch Mode",
		Key = "k20",
		Default = false,
		Desc = "Pad only turns solid while you are falling, so it stays out of the way on the ground.",
	},
	{ Type = "Toggle", Name = "Show Pad", Key = "k21", Default = false },
	{
		Type = "Toggle",
		Name = "Follow Player",
		Key = "k22",
		Default = true,
		Desc = "Off follows the gravity core instead, so you can drop a platform under a target.",
	},
}

return M
