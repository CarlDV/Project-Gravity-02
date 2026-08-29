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
			k16 = 8,
			k17 = 12,
			k18 = true,
			k19 = true,
			k20 = true,
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
