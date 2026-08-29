local M = {}

-- A rideable platform that follows you, with its visible surface built out of the
-- parts the script has already claimed.
--
-- Why it is split in two: a shape module only gets to return a velocity for
-- claimed parts, and x4.f1 hands every claimed part CanCollide = false and a
-- 0.001 density. Neither is negotiable from in here, and both mean a floor made
-- purely of claimed parts is one you fall straight through. So M.px owns the
-- anchored rig -- the slabs you actually stand on, plus any rails -- and M.f2
-- arranges the claimed parts into the surface resting on top of it. Turn Solid
-- Pad off and you keep the visual as pure decoration.
--
-- The rig is updated every frame; the lattice is restamped once per bucket
-- cycle. That split is deliberate and is explained at the stamp itself.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local UP = Vector3.new(0, 1, 0)
local WORLD_RIGHT = Vector3.new(1, 0, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)
local ZERO = Vector3.zero
local GOLDEN_ANGLE = 2.399963229728653
local DEG = math.pi / 180
local TAU = math.pi * 2

local RIG_NAME = "GRV_PLATFORM"
local MAX_LAYERS = 12
local MAX_RAILS = 64
-- Roughly a character's standing height, used to decide how much headroom the
-- ceiling clamp has to leave above the surface.
local HEAD_ROOM = 6

local PAD_SHAPES = { Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Ball }
local PAD_MATERIALS = {
	Enum.Material.ForceField,
	Enum.Material.Neon,
	Enum.Material.Glass,
	Enum.Material.SmoothPlastic,
	Enum.Material.Metal,
	Enum.Material.Ice,
}

-- Stable per-part noise. Has to be a pure function of the part id rather than a
-- stored field: System only clears a fixed list of d.* keys when the shape
-- changes (System.lua f3_body), so anything this file parked on d would survive
-- into the next shape. Deriving it means there is nothing to leak.
local function noise(n, salt)
	local x = math.sin(n * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- slot -> a point in the footprint, in units of the Size control (-1 .. 1).
-- Layouts 1-3 are the originals and are byte-for-byte what they always were, so
-- a saved Layout value still means what it used to.
local function layout_xz(layout, slot, count, spin, sides, hole)
	if count < 1 then
		count = 1
	end

	if layout == 2 then
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
	elseif layout == 3 then
		-- Ring: even angular spread over a thin annulus, three deep so a large
		-- claim reads as a band rather than a single-part-wide circle.
		local r = 0.82 + 0.18 * ((slot % 3) / 2)
		local theta = (slot / count) * TAU + spin
		return math.cos(theta) * r, math.sin(theta) * r
	elseif layout == 7 then
		-- Cross: two bars through the anchor. Rectangular, so it never goes
		-- near the polar path below.
		local half = math.floor(count / 2)
		if half < 1 then
			half = 1
		end
		local bar = slot % 2
		local along = half > 1 and ((math.floor(slot / 2) % half) / (half - 1)) * 2 - 1 or 0
		-- Spread across the bar's width so it reads as a plank, not a line.
		local thin = (((slot % 7) / 6) - 0.5) * 0.36
		local u, w
		if bar == 0 then
			u, w = along, thin
		else
			u, w = thin, along
		end
		if spin ~= 0 then
			local cs, sn = math.cos(spin), math.sin(spin)
			u, w = u * cs - w * sn, u * sn + w * cs
		end
		return u, w
	elseif layout == 10 then
		-- Hex packing: a grid with every other row nudged half a cell across,
		-- which is what turns square cells into a honeycomb.
		local cols = math.ceil(math.sqrt(count))
		if cols < 1 then
			cols = 1
		end
		local rows = math.ceil(count / cols)
		local row = math.floor(slot / cols)
		local col = slot % cols
		local u = cols > 1 and ((((col + (row % 2) * 0.5) / cols) * 2) - 1) or 0
		local w = rows > 1 and ((row / (rows - 1)) * 2 - 1) or 0
		if spin ~= 0 then
			local cs, sn = math.cos(spin), math.sin(spin)
			u, w = u * cs - w * sn, u * sn + w * cs
		end
		return u, w
	end

	-- Everything below is polar. The sunflower spiral supplies an evenly spread
	-- (r, theta) -- sqrt keeps the density even instead of piling every part
	-- into the middle -- and each layout only reshapes the radius from there.
	-- Every reshape below is a factor in (0, 1], so r can never leave the disc.
	local r = math.sqrt((slot + 0.5) / count)
	local theta = slot * GOLDEN_ANGLE + spin

	if layout == 4 then
		-- Filled regular polygon: push the radius out to the polygon edge at
		-- this angle. Inscribed, so the corners touch r = 1.
		local seg = TAU / sides
		local a = (theta % seg) - seg * 0.5
		r = r * (math.cos(math.pi / sides) / math.cos(a))
	elseif layout == 5 then
		-- Star / cog: the same idea with the radius alternating around the rim.
		r = r * (0.45 + 0.55 * (0.5 + 0.5 * math.cos(sides * theta)))
	elseif layout == 6 then
		-- Spiral arms. The angle is rebuilt rather than reshaped, so the parts
		-- in one arm stay in that arm as the claim grows.
		local per = math.ceil(count / sides)
		if per < 1 then
			per = 1
		end
		local arm = slot % sides
		local along = (math.floor(slot / sides) + 0.5) / per
		if along > 1 then
			along = 1
		end
		r = math.sqrt(along)
		theta = arm * (TAU / sides) + along * 2.5 + spin
	elseif layout == 8 then
		-- Diamond: the L1 ball, i.e. a square stood on one corner.
		local d = math.abs(math.cos(theta)) + math.abs(math.sin(theta))
		if d > 0.0001 then
			r = r / d
		end
	elseif layout == 9 then
		-- Concentric rings, `sides` of them, each offset a little so the spokes
		-- do not line up into radial spikes.
		local rings = sides
		local per = math.ceil(count / rings)
		if per < 1 then
			per = 1
		end
		local ring = slot % rings
		r = (ring + 1) / rings
		theta = (math.floor(slot / rings) / per) * TAU + spin + ring * 0.4
	end

	-- The hole is applied last so it works the same way for every polar layout:
	-- the whole radial range is remapped into [hole, 1] rather than clipped,
	-- which keeps the part count on the surface instead of throwing it away.
	r = hole + r * (1 - hole)
	if r > 1 then
		r = 1
	end
	return math.cos(theta) * r, math.sin(theta) * r
end

local function ensure_rig(st, x6)
	local rig = st.rig
	if rig and rig.Parent then
		return rig
	end
	-- The folder went away -- core teardown, or somebody cleared it -- and
	-- everything that lived in it went with it, so both pools now describe dead
	-- instances and have to be dropped before they are indexed again.
	table.clear(st.pads)
	table.clear(st.rails)
	st.style = nil
	st.rail_style = nil

	rig = Instance.new("Folder")
	rig.Name = RIG_NAME
	-- x1.k5 is the tag list x7.e screens candidates against, and it checks the
	-- candidate's parent as well as the candidate itself, so a single tag on the
	-- folder keeps the whole rig out of our own claim sweep -- which is what
	-- stops the floor being pulled out from under you. Anchored would exclude
	-- these too; this survives someone clearing that flag.
	local tag = Instance.new("Folder")
	tag.Name = "NoAttract"
	tag.Parent = rig
	-- Living in the core's folder means Q takes the rig with it even if cleanup
	-- never runs. px re-creates it if the folder goes away underneath us.
	rig.Parent = (x6.b and x6.b.Parent) or workspace
	st.rig = rig
	return rig
end

local function new_slab(rig, x1, name, own_tag)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false -- nothing should be running Touched handlers on this
	p.CastShadow = false
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.ForceField
	p.Color = x1.k3 or Color3.fromRGB(255, 105, 180)
	p.Transparency = 1
	if own_tag then
		-- The slab you actually stand on gets its own tag as well as the
		-- folder's, because it is the one instance that must never be claimed.
		local tag = Instance.new("Folder")
		tag.Name = "NoAttract"
		tag.Parent = p
	end
	p.Parent = rig
	return p
end

local function trim(pool, keep)
	for i = #pool, keep + 1, -1 do
		local p = pool[i]
		if p and p.Parent then
			p:Destroy()
		end
		pool[i] = nil
	end
end

-- Cosmetic properties are the ones that never change frame to frame, so they are
-- applied on creation and then only when the signature below moves. Writing
-- Material/Transparency/Shape to every slab every frame would be a physics
-- property write per slab per frame for a value that is almost always identical.
local function style_slab(p, shape, mat, trans, grip, no_query, colour)
	if p.Shape ~= shape then
		p.Shape = shape
	end
	-- Colour belongs in the restyle, not only at creation. It used to be set once in
	-- new_slab and left out of the signature below, so changing Center Color re-tinted
	-- the core immediately while every pad and rail kept the old colour until the rig
	-- happened to be rebuilt by a shape switch, a disable or a stop.
	if colour and p.Color ~= colour then
		p.Color = colour
	end
	if p.Material ~= mat then
		p.Material = mat
	end
	if p.Transparency ~= trans then
		p.Transparency = trans
	end
	if p.CanQuery == no_query then
		-- CanQuery is left on by default: the E hotkey places the core at
		-- v9.Hit, and an invisible slab under your feet will happily swallow
		-- that ray. Turning it off fixes that, but it is opt-in because
		-- character floor detection is not something we get to test from here.
		p.CanQuery = not no_query
	end
	if grip > 0 then
		-- Anchored, so density and elasticity are inert; the weights are what
		-- make this slab's friction win against whatever you are wearing.
		p.CustomPhysicalProperties = PhysicalProperties.new(0.7, grip, 0, 100, 1)
	elseif p.CustomPhysicalProperties then
		p.CustomPhysicalProperties = nil
	end
end

-- One point on the rim, in world space. At module scope rather than a closure
-- inside px because px runs every frame: a nested function would allocate one
-- closure per frame purely to capture the basis, which is the same allocation
-- System.lua goes out of its way to avoid in its own hot loop.
local function rim_point(j, count, square, pos, right, fwd, half_x, half_z)
	local a = (j / count) * TAU
	local ru, rw = math.cos(a), math.sin(a)
	if square then
		-- Project the circle onto the square by dividing through by the larger
		-- component, so the rail follows the corners instead of cutting them.
		local au, aw = math.abs(ru), math.abs(rw)
		local m = au > aw and au or aw
		if m > 0.0001 then
			ru, rw = ru / m, rw / m
		end
	end
	return pos + right * (ru * half_x) + fwd * (rw * half_z)
end

local function probe_params(st, x6, char)
	local rp = st.rp
	if not rp then
		rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		-- Claimed parts are all CanCollide = false, so on a client that has this
		-- property the probe steps straight through the debris cloud and finds
		-- real ground. Older clients fall back to the filter list below, which
		-- covers the rig but not the claim -- hence the pcall rather than a
		-- hard dependency.
		pcall(function()
			rp.RespectCanCollide = true
		end)
		st.rp = rp
	end
	local filter = st.rp_filter
	if not filter then
		filter = {}
		st.rp_filter = filter
	end
	-- Rebuilt per probe: the character is replaced on every respawn and the rig
	-- folder is recreated whenever the core is, so a cached list goes stale.
	table.clear(filter)
	local n = 0
	if char then
		n = n + 1
		filter[n] = char
	end
	if st.rig then
		n = n + 1
		filter[n] = st.rig
	end
	if x6.b and x6.b.Parent then
		n = n + 1
		filter[n] = x6.b.Parent
	end
	rp.FilterDescendantsInstances = filter
	return rp
end

function M.px(t, c, x6, x9, x1)
	local st = x6.pre["Platform"]
	if not st then
		st = { pads = {}, rails = {} }
		x6.pre["Platform"] = st
	end

	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end

	-- System runs each part's f2 on one frame in every x1.k7 (System.lua
	-- f3_body), so anything every part has to agree on is stamped once per cycle
	-- rather than recomputed per frame -- otherwise neighbouring parts target
	-- planes a frame or two apart and the surface ripples. Two things ride on
	-- this cycle: the stamp at the bottom of this function, and the ground
	-- probes, which are far too dear to run at 60 Hz for a target that only
	-- moves at ~15.
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
	local new_cycle = st.gen ~= gen or st.plane == nil

	local char = LocalPlayer and LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local frozen = c.k55 == true

	local anchor, vel
	local following = c.k22 ~= false
	if following and hrp then
		anchor = hrp.Position
		vel = hrp.AssemblyLinearVelocity
	elseif not following and x6.b then
		-- Follow Player off: sit under the core instead, so the platform lands
		-- under whoever is being targeted.
		anchor = x6.b.Position
		vel = ZERO
	end
	-- Deliberately not falling through to the core when Follow Player is ON and the
	-- character is mid-respawn. x6.b is always non-nil here (f3 returns early when it
	-- is not, and f3_body reads x6.b.Position before calling px), so the old
	-- `elseif x6.b` always succeeded: anchor was never nil, the mid-respawn branch
	-- below was unreachable, and the user's Follow Player setting silently inverted
	-- to core-tracking for the whole RespawnTime -- teleporting a solid slab across
	-- the map and back.
	vel = vel or ZERO

	local pos = st.pos
	local parked = frozen and pos ~= nil

	if not anchor and not parked then
		-- Mid-respawn. Keep the rig but stop it being solid, so it is not left
		-- floating as a collidable slab where the old character died. A frozen
		-- platform is the deliberate exception: parking it is exactly a request
		-- for it to stay put and stay standable.
		st.plane = nil
		local pads = st.pads
		for i = 1, #pads do
			local p = pads[i]
			if p and p.Parent and p.CanCollide then
				p.CanCollide = false
			end
		end
		-- Rails go through new_slab too, so they are created CanCollide = true and
		-- were never turned off by either this path or Catch Mode. Leaving them solid
		-- fences you inside a ring with no floor, which is the opposite of what
		-- de-colliding the pad is for.
		local rails = st.rails
		if rails then
			for i = 1, #rails do
				local r = rails[i]
				if r and r.Parent and r.CanCollide then
					r.CanCollide = false
				end
			end
		end
		return
	end

	local size = c.k11 or 8
	if size < 0.5 then
		size = 0.5
	end
	local aspect = c.k23 or 1
	if aspect < 0.05 then
		aspect = 0.05
	end
	local ramp = c.k43 or 24
	if ramp < 1 then
		ramp = 1
	end

	local target
	if parked then
		target = pos
	else
		target = anchor + UP * (c.k12 or -3)

		local lead = c.k14 or 0
		if lead > 0 then
			-- Driven off velocity, not off a per-frame position delta. The
			-- original compared successive positions against a fixed 0.1
			-- threshold, which makes the whole behaviour framerate-dependent:
			-- the same walk clears it at 30fps and fails it at 240.
			local flat = Vector3.new(vel.X, 0, vel.Z)
			local sp_sq = flat:Dot(flat)
			if sp_sq > 1 then
				local sp = math.sqrt(sp_sq)
				local reach = math.min(sp / ramp, 1) * lead
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

		local orbit = c.k46 or 0
		if orbit > 0 then
			local ang = t * (c.k56 or 60) * DEG
			target = target + WORLD_RIGHT * (math.cos(ang) * orbit) + WORLD_FWD * (math.sin(ang) * orbit)
		end

		local dead = c.k44 or 0
		if dead > 0 and pos then
			-- Stops the platform twitching under a player who is standing
			-- still. The outside branch pulls the target back by exactly the
			-- radius rather than passing it through, so crossing the boundary
			-- is continuous instead of a jump of one deadzone.
			local dx, dz = target.X - pos.X, target.Z - pos.Z
			local d_sq = dx * dx + dz * dz
			if d_sq < dead * dead then
				target = Vector3.new(pos.X, target.Y, pos.Z)
			else
				local k = (math.sqrt(d_sq) - dead) / math.sqrt(d_sq)
				target = Vector3.new(pos.X + dx * k, target.Y, pos.Z + dz * k)
			end
		end
	end

	-- Both probes are skipped while parked. Freeze means the surface stays where
	-- it was put, and a probe would still be free to walk it up and down as the
	-- ground under it changed.
	if c.k48 == true and not parked then
		if new_cycle then
			local reach = c.k49 or 60
			if reach < 1 then
				reach = 1
			end
			local origin = Vector3.new(target.X, target.Y + reach, target.Z)
			local hit = workspace:Raycast(origin, Vector3.new(0, -(reach * 2), 0), probe_params(st, x6, char))
			st.ground = hit and hit.Position.Y or nil
		end
		if st.ground then
			-- Ground Snap owns the vertical: it replaces the height the follow
			-- model asked for rather than adding to it, so Height Offset has no
			-- effect while it is on and Clearance is the knob instead.
			target = Vector3.new(target.X, st.ground + (c.k50 or 3), target.Z)
		end
	elseif st.ground then
		st.ground = nil
	end

	if c.k57 == true and not parked then
		if new_cycle then
			-- Fixed clearance, not the Catch Mode band. This used to read c.k41
			-- (Pad · Stand Band, max 40), so widening the standing band also drove the
			-- ceiling probe out to 46 studs and pinned the surface that far below any
			-- ceiling it found -- below the floor in any room shorter than that, from
			-- a slider whose name says nothing about ceilings. HEAD_ROOM * 2 is the 12
			-- the default band produced, so behaviour at defaults is unchanged.
			local head = HEAD_ROOM * 2
			local hit = workspace:Raycast(target, UP * head, probe_params(st, x6, char))
			st.ceiling = hit and (hit.Position.Y - head) or nil
		end
		if st.ceiling and target.Y > st.ceiling then
			target = Vector3.new(target.X, st.ceiling, target.Z)
		end
	elseif st.ceiling then
		st.ceiling = nil
	end

	local snap = c.k42 or 250
	if not pos or st.char ~= char or (pos - target).Magnitude > snap then
		-- New character, or a teleport. Reseat instead of lerping, which is what
		-- the original never did: it kept the old platform and a stale reference
		-- position across a respawn.
		pos = target
	else
		-- Exponential decay against real dt. A flat per-frame lerp fraction, as
		-- in the original, converges at whatever rate the client happens to
		-- render at. Vertical gets its own rate so the platform can chase you
		-- tightly across the ground while still easing up and down.
		local follow = c.k13 or 12
		local vf = (c.k45 or 100) * 0.01
		if vf < 0.01 then
			vf = 0.01
		end
		local a_h = 1 - math.exp(-follow * dt)
		local a_v = 1 - math.exp(-follow * vf * dt)
		local ny = pos.Y + (target.Y - pos.Y) * a_v
		-- An anchored part driven up through a character launches it. The plane
		-- tracks the player's own Y so it normally cannot outrun them, but Look
		-- Influence and Ground Snap can both move it a long way in one frame.
		-- Only the climb is capped: a drop has to stay instant or Catch Mode
		-- would never catch anything.
		local max_rise = (c.k39 or 80) * dt
		if ny - pos.Y > max_rise then
			ny = pos.Y + max_rise
		end
		pos = Vector3.new(pos.X + (target.X - pos.X) * a_h, ny, pos.Z + (target.Z - pos.Z) * a_h)
	end
	st.pos = pos
	st.char = char

	-- Integrated rather than derived from t directly. The original computed
	-- t * rate, so every move of the Spin slider re-evaluated the whole history
	-- at the new rate and snapped the surface to a different phase.
	st.spin_live = ((st.spin_live or 0) + (c.k17 or 0) * DEG * dt) % TAU

	-- The basis is recomputed every frame for the rig and snapshotted once per
	-- cycle for the lattice. The rig is the thing you stand on, so it gets the
	-- smooth value; the lattice is decoration, and System's feed-forward term
	-- turns its stepped target back into continuous motion anyway.
	local facing = math.floor((c.k47 or 1) + 0.5)
	local fwd
	if facing == 2 then
		local cam = workspace.CurrentCamera
		local lv = cam and cam.CFrame.LookVector
		fwd = lv and Vector3.new(lv.X, 0, lv.Z) or nil
	elseif facing == 3 then
		fwd = Vector3.new(vel.X, 0, vel.Z)
	elseif facing == 4 and x6.b then
		local to_core = x6.b.Position - pos
		fwd = Vector3.new(to_core.X, 0, to_core.Z)
	end
	if fwd and fwd:Dot(fwd) > 1e-6 then
		st.face = fwd.Unit
	elseif facing == 1 or not st.face then
		-- Mode 1 is world axes, and a floor should not swing around when the
		-- camera does. The other modes hold their last good heading rather than
		-- snapping back, so standing still under Face Movement does not reset
		-- the platform under you.
		st.face = WORLD_FWD
	end
	local base_fwd = st.face
	local base_right = base_fwd:Cross(UP)

	local live_up = UP
	local bank = c.k59 or 0
	if bank > 0 then
		local flat = Vector3.new(vel.X, 0, vel.Z)
		local sp_sq = flat:Dot(flat)
		if sp_sq > 1 then
			local sp = math.sqrt(sp_sq)
			local axis = UP:Cross(flat / sp)
			if axis:Dot(axis) > 1e-6 then
				-- Tips the surface nose-down into the direction of travel. The
				-- whole basis turns with it, so the lattice stays flat against
				-- the slab instead of hovering through it.
				local rot = CFrame.fromAxisAngle(axis.Unit, math.min(sp / ramp, 1) * bank * DEG)
				live_up = rot:VectorToWorldSpace(UP)
				base_right = rot:VectorToWorldSpace(base_right)
				base_fwd = rot:VectorToWorldSpace(base_fwd)
			end
		end
	end

	-- Spin rotates the pattern inside the basis, so the rig has to rotate the
	-- basis by the same angle and in the same sense, or a visible slab and the
	-- lattice on top of it would drift apart.
	local cs, sn = math.cos(st.spin_live), math.sin(st.spin_live)
	local rig_right = base_right * cs + base_fwd * sn
	local rig_fwd = base_fwd * cs - base_right * sn

	local layers = math.floor(c.k16 or 1)
	if layers < 1 then
		layers = 1
	elseif layers > MAX_LAYERS then
		layers = MAX_LAYERS
	end

	local gap = c.k29 or 1.2
	local taper = c.k30 or 1
	local stair = c.k31 or 0
	local margin = c.k34 or 0
	local half_x = size * aspect + margin
	local half_z = size + margin
	if half_x < 0.1 then
		half_x = 0.1
	end
	if half_z < 0.1 then
		half_z = 0.1
	end

	local want_pad = c.k19 ~= false
	local pad_n = 0
	if want_pad then
		pad_n = (c.k32 == true) and layers or 1
	end

	local rig = pad_n > 0 and ensure_rig(st, x6) or st.rig
	local pads = st.pads

	-- Hoisted out of the pad branch so the rails can honour it too. Rails are built
	-- by new_slab, which creates every slab CanCollide = true, and nothing ever
	-- turned them back off -- so with Catch Mode on and Rail Height above zero,
	-- standing on real ground correctly de-collided the pad and left you fenced
	-- inside a solid ring with no floor.
	local solid = true
	if pad_n > 0 and c.k20 == true then
		-- Catch Mode: out of the way while you are on the ground, solid the
		-- moment you start falling. Standing on it counts as well, or
		-- landing would zero your fall speed and immediately switch the
		-- floor off again.
		solid = vel.Y < -(c.k40 or 5)
		if not solid and hrp then
			local rel = hrp.Position - pos
			local band = c.k41 or 6
			-- Projected onto the surface's own axes rather than the world's.
			-- The original compared against world X/Z, which silently stops
			-- describing the footprint the moment Facing or Spin turns it.
			local ru = rel:Dot(rig_right)
			local rw = rel:Dot(rig_fwd)
			if rel.Y > 0 and rel.Y < band and math.abs(ru) < half_x and math.abs(rw) < half_z then
				solid = true
			end
		end
	end

	if pad_n > 0 then
		local shape_i = math.floor((c.k36 or 1) + 0.5)
		local mat_i = math.floor((c.k37 or 1) + 0.5)
		local pshape = PAD_SHAPES[shape_i] or PAD_SHAPES[1]
		local pmat = PAD_MATERIALS[mat_i] or PAD_MATERIALS[1]
		local ptrans = (c.k21 == true) and math.clamp(c.k35 or 0.6, 0, 1) or 1
		local pgrip = c.k38 or 0
		local no_query = c.k58 == true
		local thick = c.k33 or 1
		if thick < 0.05 then
			thick = 0.05
		end

		local pcol = x1.k3
		local sig = shape_i .. "/" .. mat_i .. "/" .. ptrans .. "/" .. pgrip .. "/" .. tostring(no_query) .. "/" .. tostring(pcol)
		local restyle = st.style ~= sig
		st.style = sig

		trim(pads, pad_n)
		for i = 1, pad_n do
			local pad = pads[i]
			if not pad or not pad.Parent then
				pad = new_slab(rig, x1, i == 1 and RIG_NAME or (RIG_NAME .. "_L" .. i), i == 1)
				pads[i] = pad
				style_slab(pad, pshape, pmat, ptrans, pgrip, no_query, pcol)
			elseif restyle then
				style_slab(pad, pshape, pmat, ptrans, pgrip, no_query, pcol)
			end

			local li = i - 1
			local scale = taper ^ li
			local sx, sz = half_x * scale, half_z * scale
			local want_size
			if pshape == Enum.PartType.Cylinder then
				-- A Cylinder's axis runs along its local X, so the CFrame below
				-- stands it up and the extents shift one place across.
				want_size = Vector3.new(thick, sx * 2, sz * 2)
			elseif pshape == Enum.PartType.Ball then
				local d = (sx < sz and sx or sz) * 2
				want_size = Vector3.new(d, d, d)
			else
				want_size = Vector3.new(sx * 2, thick, sz * 2)
			end
			if pad.Size ~= want_size then
				pad.Size = want_size
			end

			-- Top face sits exactly on its layer's plane, so you stand level
			-- with the surface the claimed parts form rather than sunk into it.
			local drop = (pshape == Enum.PartType.Ball) and (want_size.Y * 0.5) or (thick * 0.5)
			-- Spin rotates the pattern inside the basis, so the slab's *orientation*
			-- follows the spun axes -- but the stair marches along the unspun one,
			-- because that is the axis f2 offsets the lattice layers along. Mixing
			-- the two would walk the slabs out from under the parts they carry.
			local centre = pos + live_up * (li * gap - drop) + base_fwd * (stair * li)
			local cf = CFrame.fromMatrix(centre, rig_right, live_up, -rig_fwd)
			if pshape == Enum.PartType.Cylinder then
				cf = cf * CFrame.Angles(0, 0, math.pi * 0.5)
			end
			pad.CFrame = cf

			if pad.CanCollide ~= solid then
				pad.CanCollide = solid
			end
		end
	elseif #pads > 0 then
		trim(pads, 0)
		st.style = nil
	end

	local rails = st.rails
	local rail_h = c.k51 or 0
	local rail_n = 0
	if rail_h > 0 then
		rail_n = math.floor(c.k52 or 16)
		if rail_n < 4 then
			rail_n = 4
		elseif rail_n > MAX_RAILS then
			rail_n = MAX_RAILS
		end
		rig = ensure_rig(st, x6)
		-- ensure_rig clears both pools when it has to rebuild, so re-read.
		rails = st.rails
	end

	if rail_n > 0 then
		local rail_t = c.k53 or 0.5
		if rail_t < 0.05 then
			rail_t = 0.05
		end
		local rail_trans = math.clamp(c.k54 or 0.5, 0, 1)
		local mat_i = math.floor((c.k37 or 1) + 0.5)
		local rmat = PAD_MATERIALS[mat_i] or PAD_MATERIALS[1]
		local no_query = c.k58 == true
		local rcol = x1.k3
		local sig = mat_i .. "/" .. rail_trans .. "/" .. tostring(no_query) .. "/" .. tostring(rcol)
		local restyle = st.rail_style ~= sig
		st.rail_style = sig

		-- A block slab has a square footprint and a round one an elliptical one;
		-- the rail has to trace whichever it is or it will float off the edge.
		local square = (PAD_SHAPES[math.floor((c.k36 or 1) + 0.5)] or PAD_SHAPES[1]) == Enum.PartType.Block

		trim(rails, rail_n)
		local prev = rim_point(0, rail_n, square, pos, rig_right, rig_fwd, half_x, half_z)
		for j = 1, rail_n do
			local rail = rails[j]
			if not rail or not rail.Parent then
				rail = new_slab(rig, x1, RIG_NAME .. "_R" .. j, false)
				rails[j] = rail
				style_slab(rail, Enum.PartType.Block, rmat, rail_trans, 0, no_query, rcol)
			elseif restyle then
				style_slab(rail, Enum.PartType.Block, rmat, rail_trans, 0, no_query, rcol)
			end

			local nxt = rim_point(j, rail_n, square, pos, rig_right, rig_fwd, half_x, half_z)
			local span = nxt - prev
			local len = span.Magnitude
			if len < 0.01 then
				len = 0.01
				span = rig_right * 0.01
			end
			local want_size = Vector3.new(rail_t, rail_h, len)
			if rail.Size ~= want_size then
				rail.Size = want_size
			end
			-- Sits on the layer-0 surface, spanning this segment of the rim.
			local mid = (prev + nxt) * 0.5 + live_up * (rail_h * 0.5)
			rail.CFrame = CFrame.lookAt(mid, mid + span / len, live_up)
			-- Follows the pad. Without this the ring stayed solid whatever Catch Mode
			-- decided, which turns "pad out of the way on the ground" into a cage.
			if rail.CanCollide ~= solid then
				rail.CanCollide = solid
			end
			prev = nxt
		end
	elseif #rails > 0 then
		trim(rails, 0)
		st.rail_style = nil
	end

	if st.rig and st.rig.Parent and pad_n == 0 and rail_n == 0 then
		-- Nothing left to hold. Dropping the folder means Solid Pad off really
		-- is pure decoration, with no invisible instance left in the workspace.
		st.rig:Destroy()
		st.rig = nil
	end

	if not new_cycle then
		return
	end
	st.gen = gen
	st.plane = pos
	st.right = base_right
	st.fwd = base_fwd
	st.up = live_up
	st.spin = st.spin_live
	st.size = size
	st.aspect = aspect
	st.layout = math.floor(c.k18 or 1)
	st.sides = math.floor(c.k27 or 6)
	if st.sides < 3 then
		st.sides = 3
	end
	st.hole = math.clamp(c.k28 or 0, 0, 0.95)
	st.curve = c.k24 or 0
	st.jitter = c.k25 or 0
	st.lift = c.k26 or 0.6
	st.gap = gap
	st.taper = taper
	st.stair = stair
	st.layers = layers
	-- Quantised so a part being claimed or dropped does not reshuffle the whole
	-- surface. Which slot a part owns is derived from the count, so leaving it
	-- raw means the floor churns continuously during the opening sweep.
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

	local id = d.id or 1
	local slot = id % st.count
	local layer = 0
	if st.layers > 1 then
		layer = math.floor(slot / st.per_layer)
		if layer >= st.layers then
			layer = st.layers - 1
		end
		slot = slot % st.per_layer
	end

	local u, w = layout_xz(st.layout, slot, st.per_layer, st.spin, st.sides, st.hole)

	-- Taper shrinks each layer against the one below it, which is what turns a
	-- stack into a ziggurat; the slabs under it are scaled by the same factor.
	if st.taper ~= 1 then
		local scale = st.taper ^ layer
		u, w = u * scale, w * scale
	end

	local rr = u * u + w * w
	if rr > 1 then
		rr = 1
	end
	local lift = st.lift + layer * st.gap + st.curve * (1 - rr)

	local target_pos = plane
		+ st.right * (u * st.size * st.aspect)
		+ st.fwd * (w * st.size + st.stair * layer)
		+ st.up * lift

	local jitter = st.jitter
	if jitter > 0 then
		-- Keyed off the part id, so it is fixed scatter rather than a shimmer:
		-- a floor that wobbles per frame is a floor you cannot read the edge of.
		target_pos = target_pos
			+ Vector3.new(
				(noise(id, 1) - 0.5) * jitter,
				(noise(id, 2) - 0.5) * jitter,
				(noise(id, 3) - 0.5) * jitter
			)
	end

	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

-- Called by System when the shape is switched away, on stop, on disable, and on
-- teardown. Without it the rig would outlive the shape that owns it. Destroying
-- the folder takes every pad and rail with it.
function M.cleanup(x6, x1)
	local st = x6.pre and x6.pre["Platform"]
	if not st then
		return
	end
	if st.rig and st.rig.Parent then
		st.rig:Destroy()
	end
	x6.pre["Platform"] = nil
end

-- Desc is carried for the shapes that render it and as source documentation;
-- UI.lua forwards it for Slider, Toggle and TextBox controls alike.
-- Note also that UI.lua widens any slider whose name contains "speed" by 300
-- unless ExactMax is set -- every speed control below sets it.
M.Controls = {
	-- ---- surface -------------------------------------------------------
	{
		Type = "Slider",
		Name = "Surface · Layout",
		Min = 1,
		Max = 10,
		Key = "k18",
		Default = 1,
		IntOnly = true,
		Desc = "1 disc, 2 square, 3 ring, 4 polygon, 5 star, 6 spiral arms, 7 cross, 8 diamond, 9 rings, 10 hex.",
	},
	{
		Type = "Slider",
		Name = "Surface · Sides",
		Min = 3,
		Max = 16,
		Key = "k27",
		Default = 6,
		IntOnly = true,
		Desc = "Corners for polygon and star, arms for spiral, ring count for concentric.",
	},
	{ Type = "Slider", Name = "Surface · Size", Min = 2, Max = 250, Key = "k11", Default = 8 },
	{
		Type = "Slider",
		Name = "Surface · Aspect %",
		Min = 25,
		Max = 400,
		Key = "k23",
		Default = 1,
		Div = 100,
		Desc = "Stretches the surface sideways. 100 is square-on.",
	},
	{
		Type = "Slider",
		Name = "Surface · Hole %",
		Min = 0,
		Max = 90,
		Key = "k28",
		Default = 0,
		Div = 100,
		Desc = "Opens the middle out into a donut. Ignored by the grid, ring and cross layouts.",
	},
	{ Type = "Slider", Name = "Surface · Layers", Min = 1, Max = 12, Key = "k16", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Surface · Layer Gap", Min = 0, Max = 200, Key = "k29", Default = 1.2, Div = 10 },
	{
		Type = "Slider",
		Name = "Surface · Layer Taper %",
		Min = 20,
		Max = 150,
		Key = "k30",
		Default = 1,
		Div = 100,
		Desc = "Each layer scaled against the one below. Under 100 builds a ziggurat.",
	},
	{
		Type = "Slider",
		Name = "Surface · Stair Offset",
		Min = 0,
		Max = 40,
		Key = "k31",
		Default = 0,
		Desc = "Marches each layer forward instead of stacking it. With Solid Layers on, this is a staircase.",
	},
	{
		Type = "Slider",
		Name = "Surface · Curve",
		Min = -40,
		Max = 40,
		Key = "k24",
		Default = 0,
		Desc = "Positive domes the middle up, negative dishes it into a bowl.",
	},
	{ Type = "Slider", Name = "Surface · Jitter", Min = 0, Max = 20, Key = "k25", Default = 0 },
	{ Type = "Slider", Name = "Surface · Part Lift", Min = 0, Max = 200, Key = "k26", Default = 0.6, Div = 10 },
	{ Type = "Slider", Name = "Surface · Spin", Min = -300, Max = 300, Key = "k17", Default = 0 },

	-- ---- motion --------------------------------------------------------
	{ Type = "Slider", Name = "Motion · Follow Speed", Min = 1, Max = 50, Key = "k13", Default = 12, ExactMax = true },
	{
		Type = "Slider",
		Name = "Motion · Vertical Follow %",
		Min = 10,
		Max = 400,
		Key = "k45",
		Default = 100,
		Desc = "Vertical tracking rate as a share of Follow Speed. Under 100 eases up and down.",
	},
	{
		Type = "Slider",
		Name = "Motion · Height Offset",
		Min = -60,
		Max = 40,
		Key = "k12",
		Default = -3,
		Desc = "Where the surface sits relative to you. -3 is roughly under your feet.",
	},
	{
		Type = "Slider",
		Name = "Motion · Lead",
		Min = 0,
		Max = 60,
		Key = "k14",
		Default = 3,
		Desc = "Pushes the platform ahead of you as you move, scaled by how fast you are going.",
	},
	{
		Type = "Slider",
		Name = "Motion · Lead Ramp",
		Min = 1,
		Max = 100,
		Key = "k43",
		Default = 24,
		Desc = "Horizontal speed at which Lead and Bank reach their full value.",
	},
	{
		Type = "Slider",
		Name = "Motion · Deadzone",
		Min = 0,
		Max = 40,
		Key = "k44",
		Default = 0,
		Desc = "Ignores drift inside this radius so the platform holds still under a standing player.",
	},
	{
		Type = "Slider",
		Name = "Motion · Look Influence",
		Min = -40,
		Max = 40,
		Key = "k15",
		Default = 0,
		Desc = "Raises and lowers the platform with the camera pitch. 0 keeps it level.",
	},
	{
		Type = "Slider",
		Name = "Motion · Rise Limit",
		Min = 10,
		Max = 400,
		Key = "k39",
		Default = 80,
		Desc = "Studs per second the surface may climb. Caps how hard it can punt you upward.",
	},
	{ Type = "Slider", Name = "Motion · Snap Distance", Min = 50, Max = 2000, Key = "k42", Default = 250 },
	{ Type = "Slider", Name = "Motion · Orbit Radius", Min = 0, Max = 120, Key = "k46", Default = 0 },
	{ Type = "Slider", Name = "Motion · Orbit Speed", Min = 0, Max = 300, Key = "k56", Default = 60, ExactMax = true },
	{
		Type = "Slider",
		Name = "Motion · Bank",
		Min = 0,
		Max = 45,
		Key = "k59",
		Default = 0,
		Desc = "Degrees the surface tips into the direction of travel. You will slide on a steep one.",
	},
	{
		Type = "Slider",
		Name = "Motion · Facing",
		Min = 1,
		Max = 4,
		Key = "k47",
		Default = 1,
		IntOnly = true,
		Desc = "1 world axes, 2 camera, 3 direction of travel, 4 toward the core.",
	},

	-- ---- ground --------------------------------------------------------
	{
		Type = "Toggle",
		Name = "Ground · Snap",
		Key = "k48",
		Default = false,
		Desc = "Rides at a fixed height over whatever is below, instead of tracking your own height.",
	},
	{ Type = "Slider", Name = "Ground · Clearance", Min = 0, Max = 40, Key = "k50", Default = 3 },
	{ Type = "Slider", Name = "Ground · Probe", Min = 10, Max = 500, Key = "k49", Default = 60 },
	{
		Type = "Toggle",
		Name = "Ground · Ceiling Clamp",
		Key = "k57",
		Default = false,
		Desc = "Holds the surface down far enough to keep you from being pushed into a roof.",
	},

	-- ---- pad -----------------------------------------------------------
	{
		Type = "Toggle",
		Name = "Pad · Solid",
		Key = "k19",
		Default = true,
		Desc = "Adds the anchored slab you actually stand on. Off leaves the parts as decoration only.",
	},
	{
		Type = "Toggle",
		Name = "Pad · Solid Layers",
		Key = "k32",
		Default = false,
		Desc = "One standable slab per layer rather than just the bottom one.",
	},
	{
		Type = "Toggle",
		Name = "Pad · Catch Mode",
		Key = "k20",
		Default = false,
		Desc = "Pad only turns solid while you are falling, so it stays out of the way on the ground.",
	},
	{
		Type = "Slider",
		Name = "Pad · Catch Fall Speed",
		Min = 1,
		Max = 100,
		Key = "k40",
		Default = 5,
		ExactMax = true,
		Desc = "How fast you have to be dropping before Catch Mode turns the floor on.",
	},
	{ Type = "Slider", Name = "Pad · Stand Band", Min = 1, Max = 40, Key = "k41", Default = 6 },
	{ Type = "Toggle", Name = "Pad · Visible", Key = "k21", Default = false },
	{ Type = "Slider", Name = "Pad · Transparency", Min = 0, Max = 100, Key = "k35", Default = 0.6, Div = 100 },
	{ Type = "Slider", Name = "Pad · Thickness", Min = 1, Max = 200, Key = "k33", Default = 1, Div = 10 },
	{
		Type = "Slider",
		Name = "Pad · Margin",
		Min = -20,
		Max = 60,
		Key = "k34",
		Default = 0,
		Desc = "Studs the slab overhangs the lattice by. Negative tucks it inside.",
	},
	{
		Type = "Slider",
		Name = "Pad · Shape",
		Min = 1,
		Max = 3,
		Key = "k36",
		Default = 1,
		IntOnly = true,
		Desc = "1 block, 2 cylinder, 3 ball. Cylinder matches the round layouts.",
	},
	{
		Type = "Slider",
		Name = "Pad · Material",
		Min = 1,
		Max = 6,
		Key = "k37",
		Default = 1,
		IntOnly = true,
		Desc = "1 forcefield, 2 neon, 3 glass, 4 smooth plastic, 5 metal, 6 ice.",
	},
	{
		Type = "Slider",
		Name = "Pad · Grip %",
		Min = 0,
		Max = 200,
		Key = "k38",
		Default = 0,
		Div = 100,
		Desc = "Friction override. 0 leaves the engine default alone.",
	},
	{
		Type = "Toggle",
		Name = "Pad · Ignore Cursor",
		Key = "k58",
		Default = false,
		Desc = "Stops the slab swallowing the mouse ray, so E still places the core on real ground.",
	},

	-- ---- rails ---------------------------------------------------------
	{
		Type = "Slider",
		Name = "Rail · Height",
		Min = 0,
		Max = 30,
		Key = "k51",
		Default = 0,
		Desc = "Guard rail around the rim to stop you walking off. 0 is no rail.",
	},
	{ Type = "Slider", Name = "Rail · Segments", Min = 4, Max = 64, Key = "k52", Default = 16, IntOnly = true },
	{ Type = "Slider", Name = "Rail · Thickness", Min = 1, Max = 80, Key = "k53", Default = 0.5, Div = 10 },
	{ Type = "Slider", Name = "Rail · Transparency", Min = 0, Max = 100, Key = "k54", Default = 0.5, Div = 100 },

	-- ---- mode ----------------------------------------------------------
	{
		Type = "Toggle",
		Name = "Follow Player",
		Key = "k22",
		Default = true,
		Desc = "Off follows the gravity core instead, so you can drop a platform under a target.",
	},
	{
		Type = "Toggle",
		Name = "Freeze",
		Key = "k55",
		Default = false,
		Desc = "Parks the platform where it is and stops it tracking anything. Survives a respawn.",
	},
}

return M
