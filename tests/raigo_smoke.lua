package.path = "tests/?.lua;" .. package.path
local env = require("robloxenv")
local newInstance = env.newInstance

local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print("  FAIL  " .. msg)
	end
end

local M = assert(loadfile("shapes/Raigo.lua"))()

local function mk_part(pos)
	local p = newInstance("Part", nil)
	p.Position = pos or Vector3.new(0, 0, 0)
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(100, 100, 100)
	return p
end

local function mk_ctx()
	return {
		x1 = { k10 = 20, k3 = Color3.fromRGB(0, 255, 255), IsLaunching = false },
		x6 = { pre = {}, f = 0, n = 50 },
		x9 = { c1 = 0.15 },
		c = {
			k11 = 8,
			k12 = 250,
			k13 = 80,
			k14 = 0.7,
			k15 = 12,
			-- Shell Fill (100 = solid) and Surface Jitter (0 = exact sphere). These are
			-- new keys, not the k16/k17 that used to be Arc Count and Arc Jaggedness:
			-- load_settings restores any saved value of matching type, so reusing them
			-- would have handed an existing user's 8 and 12 straight to the new controls.
			-- k20 was a Neon Glow toggle and is gone with the code that repainted parts.
			k18 = true,
			k19 = true,
			k21 = 100,
			k22 = 0,
		},
	}
end

print("Raigo · hover phase")
do
	local ctx = mk_ctx()
	local p = mk_part(Vector3.new(0, 0, 0))
	local cen = Vector3.new(0, 50, 0)
	local d = { id = 1 }

	local delta, pos = M.f2(p, cen, d, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(delta ~= nil and pos ~= nil, "f2 returns delta and target position")
	check(pos.Y > cen.Y, "orb hovers above the center/head")

	local st = ctx.x6.pre["Raigo"]
	check(st ~= nil, "state machine is stored in x6.pre")
	check(st.phase == "HOVER", "initial state is HOVER")
end

print("Raigo · launch and flight")
do
	local ctx = mk_ctx()
	local p = mk_part(Vector3.new(0, 50, 0))
	local cen = Vector3.new(0, 50, 0)
	local d = { id = 1 }

	M.f2(p, cen, d, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	local st = ctx.x6.pre["Raigo"]

	st.dest_pos = Vector3.new(200, 50, 0)
	st.start_pos = st.orb_pos
	st.phase = "LAUNCH"
	st.t_launch = 1.0

	local delta, pos = M.f2(p, cen, d, 1.2, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.phase == "LAUNCH" or st.phase == "EXPLODE", "phase progresses during flight")
	check(st.orb_pos.X > 10, "orb moves toward destination")

	M.f2(p, cen, d, 3.0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.phase == "EXPLODE", "reaching destination triggers EXPLODE")
end

print("Raigo · explosion and return")
do
	local ctx = mk_ctx()
	local p = mk_part(Vector3.new(200, 50, 0))
	local cen = Vector3.new(0, 50, 0)
	local d = { id = 1 }

	M.f2(p, cen, d, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	local st = ctx.x6.pre["Raigo"]
	st.phase = "EXPLODE"
	st.t_blast = 2.0
	st.blast_origin = Vector3.new(200, 50, 0)

	local delta, pos = M.f2(p, cen, d, 2.3, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.phase == "EXPLODE", "in explosion phase during blast duration")
	check((pos - st.blast_origin).Magnitude > 0, "parts expand outward")

	M.f2(p, cen, d, 3.0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.phase == "RETURN", "blast duration elapsing triggers RETURN")

	M.f2(p, cen, d, 6.0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.phase == "HOVER", "returning completes and resets to HOVER")
end

print("Raigo · force launch is a latch, not a pulse")
do
	local ctx = mk_ctx()
	local p = mk_part(Vector3.new(0, 50, 0))
	local cen = Vector3.new(0, 50, 0)
	local d = { id = 1 }

	M.f2(p, cen, d, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	local st = ctx.x6.pre["Raigo"]
	check(st.phase == "HOVER", "starts hovering")

	-- FORCE LAUNCH is a held flag: the button's own label reads off it, and Twin
	-- Core Beam and Slingshot read it as state. Raigo used to write it back to
	-- false, which fired once and then left the button showing "RESET SYSTEM"
	-- while the flag was down, and stole the flag from every other reader.
	ctx.x1.IsLaunching = true
	M.f2(p, cen, d, 1.0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(ctx.x1.IsLaunching == true, "the shared flag is not consumed")
	check(st.phase == "LAUNCH", "the rising edge fires a launch")

	-- Still held on the next frame: it must not re-fire mid-flight.
	st.phase = "HOVER"
	M.f2(p, cen, d, 1.1, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.phase == "HOVER", "a still-held flag does not re-fire")

	-- Released and pressed again is a new edge.
	ctx.x1.IsLaunching = false
	M.f2(p, cen, d, 1.2, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	ctx.x1.IsLaunching = true
	M.f2(p, cen, d, 1.3, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.phase == "LAUNCH", "a fresh edge fires again")
end

print("Raigo · zero-length launch")
do
	local ctx = mk_ctx()
	local cen = Vector3.new(0, 50, 0)
	local d = { id = 700 }
	local p = mk_part(cen)

	M.f2(p, cen, d, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	local st = ctx.x6.pre["Raigo"]
	-- Clicking the orb where it already is. Vector3.zero.Unit is NaN in Roblox,
	-- and the trail offset carried that straight into the part's target position,
	-- which the constraint then applied -- the part is gone for good.
	st.phase = "LAUNCH"
	st.start_pos = st.orb_pos
	st.dest_pos = st.orb_pos
	st.t_launch = 1.0

	local worst = 0
	for id = 1, 60 do
		local delta, pos = M.f2(p, cen, { id = id }, 1.0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
		check(pos.X == pos.X and pos.Y == pos.Y and pos.Z == pos.Z,
			("id %d target is not NaN"):format(id))
		check(delta.X == delta.X and delta.Y == delta.Y and delta.Z == delta.Z,
			("id %d delta is not NaN"):format(id))
		local m = (pos - cen).Magnitude
		if m > worst then worst = m end
		st.phase = "LAUNCH"
		st.dest_pos = st.orb_pos
		st.start_pos = st.orb_pos
	end
	check(worst < 1e4, ("targets stay bounded (worst %.1f)"):format(worst))
end

print("Raigo · click to fire honours the live toggle")
do
	local ctx = mk_ctx()
	local p = mk_part(Vector3.new(0, 50, 0))
	local cen = Vector3.new(0, 50, 0)

	M.f2(p, cen, { id = 1 }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	local st = ctx.x6.pre["Raigo"]
	check(st.click_enabled == true, "Click To Fire on arms the handler")

	-- The listener is made once and f2 can never re-make it, so the toggle has to
	-- reach it through the state table rather than through the closure.
	ctx.c.k19 = false
	M.f2(p, cen, { id = 1 }, 0.1, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(st.click_enabled == false, "turning it off disarms the handler")
end

print("Raigo · the idle form is a solid ball")
do
	local ctx = mk_ctx()
	local cen = Vector3.new(0, 50, 0)
	local p = mk_part(cen)
	local R = ctx.c.k11
	ctx.x6.n = 400

	M.f2(p, cen, { id = 1 }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	local st = ctx.x6.pre["Raigo"]
	-- Settle the hover lerp so the orb centre is the head position, not somewhere
	-- along the way to it.
	for _ = 1, 80 do
		M.f2(p, cen, { id = 1 }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	end
	local centre = st.orb_pos

	-- Radial structure. A solid ball has to put parts inside as well as on the
	-- surface: the form this replaced placed 55 % of its parts on a single shell at
	-- exactly R and ran the other 45 % out to 1.8 R on arcs and tendrils, so it
	-- failed both halves of this -- nothing inside, and plenty outside.
	local bands = {}
	local outside, worst = 0, 0
	local half, most = 0, 0
	local N = 400
	for id = 1, N do
		local _, pos = M.f2(p, cen, { id = id }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
		local r = (pos - centre).Magnitude
		if r > worst then worst = r end
		if r > R + 1e-6 then outside = outside + 1 end
		if r <= R * 0.5 then half = half + 1 end
		if r <= R * 0.8 then most = most + 1 end
		local b = math.min(10, math.floor(r / R * 10) + 1)
		bands[b] = (bands[b] or 0) + 1
	end
	check(outside == 0, ("no part sits outside the radius (%d of %d, worst %.3f vs %d)")
		:format(outside, N, worst, R))
	-- Volume-uniform is what "solid" means, and it has three signatures at this
	-- sample size: an eighth of the parts inside half the radius, half of them
	-- inside 0.8 R, and 1 - 0.9^3 = 27 % in the outermost tenth. A shell scores
	-- 0/0/100; a radius drawn straight from u scores 50/80/10.
	check(half / N > 0.06 and half / N < 0.20,
		("an eighth of the parts sit inside half the radius (%.3f)"):format(half / N))
	check(most / N > 0.40 and most / N < 0.62,
		("half of them sit inside 0.8 R (%.3f)"):format(most / N))
	local outer = (bands[10] or 0) / N
	check(outer > 0.18 and outer < 0.38,
		("the outer tenth of the radius holds about a quarter of the parts (%.3f)"):format(outer))
	-- Bands 1 and 2 are deliberately not required: at 400 parts they expect 0.4 and
	-- 2.8 respectively, so an empty innermost band is the distribution being right,
	-- not wrong.
	local empty = 0
	for b = 3, 10 do
		if (bands[b] or 0) == 0 then empty = empty + 1 end
	end
	check(empty == 0, ("every radial band from the third out is populated (%d of 8 empty)"):format(empty))
end

print("Raigo · Shell Fill and Surface Jitter")
do
	local ctx = mk_ctx()
	local cen = Vector3.new(0, 50, 0)
	local p = mk_part(cen)
	local R = ctx.c.k11
	ctx.x6.n = 200
	ctx.c.k21 = 0

	M.f2(p, cen, { id = 1 }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	local st = ctx.x6.pre["Raigo"]
	for _ = 1, 80 do
		M.f2(p, cen, { id = 1 }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	end
	local centre = st.orb_pos

	local worst = 0
	for id = 1, 200 do
		local _, pos = M.f2(p, cen, { id = id }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
		local off = math.abs((pos - centre).Magnitude - R)
		if off > worst then worst = off end
	end
	check(worst < 1e-6, ("Shell Fill 0 puts every part exactly on the surface (worst %.6f)"):format(worst))

	-- Jitter is the only thing that may push a part off the shell, and it has to
	-- do so by no more than its own amplitude on each axis.
	ctx.c.k22 = 3
	local moved, over = 0, 0
	for id = 1, 200 do
		local _, pos = M.f2(p, cen, { id = id }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
		local off = math.abs((pos - centre).Magnitude - R)
		if off > 1e-6 then moved = moved + 1 end
		if off > 3 * math.sqrt(3) + 1e-6 then over = over + 1 end
	end
	check(moved > 150, ("jitter moves the parts off the shell (%d of 200)"):format(moved))
	check(over == 0, ("and never by more than its amplitude (%d over)"):format(over))
end

print("Raigo · writes no appearance properties")
do
	-- The glow set p.Material and p.Color on every part it touched, and x4.f1
	-- snapshots CanCollide, Anchored and CustomPhysicalProperties -- not Material,
	-- not Color -- so there was nothing to restore from and every part Raigo had
	-- ever held stayed neon for the session. A behavioural check cannot prove the
	-- absence of a write on a path it did not take, so this reads the source.
	local fh = assert(io.open("shapes/Raigo.lua"))
	local src = fh:read("a")
	fh:close()
	check(src:find("p%.Material") == nil, "Raigo.lua never assigns p.Material")
	check(src:find("p%.Color") == nil, "Raigo.lua never assigns p.Color")
	check(src:find("Neon") == nil, "no Neon left anywhere in the file")
	check(src:find("k20") == nil, "the Neon Glow control is gone with it")

	-- And the live path leaves a part it has driven exactly as it found it.
	local ctx = mk_ctx()
	local cen = Vector3.new(0, 50, 0)
	local p = mk_part(cen)
	local mat, col = p.Material, p.Color
	for id = 1, 20 do
		M.f2(p, cen, { id = id }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	end
	check(p.Material == mat, "a driven part keeps its Material")
	check(p.Color == col, "a driven part keeps its Color")
end

print("Raigo · cleanup")
do
	local ctx = mk_ctx()
	local p = mk_part(Vector3.new(0, 0, 0))
	M.f2(p, Vector3.new(0, 0, 0), { id = 1 }, 0, ctx.c, ctx.x1, ctx.x6, ctx.x9)
	check(ctx.x6.pre["Raigo"] ~= nil, "state exists before cleanup")
	M.cleanup(ctx.x6, ctx.x1)
	check(ctx.x6.pre["Raigo"] == nil, "cleanup drops state")
	local ok = pcall(M.cleanup, ctx.x6, ctx.x1)
	check(ok, "cleanup is safe to call twice")
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
