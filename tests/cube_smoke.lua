-- Spinning Cube: the half-cut and the shared spin phase.
--
--   luajit tests/cube_smoke.lua      (from the repo root)

package.path = "tests/?.lua;" .. package.path
local rm = require("robloxmath")
Vector3, CFrame = rm.Vector3, rm.CFrame
Color3 = { new = function() return {} end }
Color3.fromRGB = Color3.new

local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print("  FAIL  " .. msg)
	end
end

local S = assert(load(assert(io.open("shapes/Spinning Cube.lua")):read("a"), "cube"))()
local cfg = assert(loadfile("config.lua"))().x2["Spinning Cube"]
local function copy(t)
	local o = {}
	for k, v in pairs(t) do o[k] = v end
	return o
end

local x1 = { k10 = 20, k7 = 4 }
local x9 = { c1 = 0.15 }
local cen = Vector3.new(0, 50, 0)
local function part() return { Position = Vector3.new(0, 0, 0) } end

-- Deterministic face/offset assignment: seed each part's scratch directly so the
-- distribution is the same across runs and across the cases being compared.
local function mk_parts(n)
	local out = {}
	for i = 1, n do
		out[i] = {
			id = i,
			f = (i % 6) + 1,
			u = ((i * 0.7548776662466927) % 1) * 2 - 1,
			v = ((i * 0.5698402909980532) % 1) * 2 - 1,
		}
	end
	return out
end

local function sweep(c, x6, ds, t)
	local pts = {}
	for i, d in ipairs(ds) do
		local _, tp = S.f2(part(), cen, d, t, c, x1, x6, x9)
		pts[i] = tp
	end
	return pts
end

-- ---- half cut ----------------------------------------------------------
print("Spinning Cube")
do
	local c = copy(cfg)
	c.k12 = 0 -- hold still; the cut is a shape question, not a spin one
	c.k13 = true
	local x6 = { pre = {}, f = 4, n = 300 }
	S.px(0.1, c, x6, x9, x1)

	local ds = mk_parts(300)
	local pts = sweep(c, x6, ds, 0.1)

	local at_centre, kept, culled = 0, 0, 0
	for _, tp in ipairs(pts) do
		if (tp - cen).Magnitude < 1 then at_centre = at_centre + 1 end
		-- Spin is off and no rotation is applied, so local +x maps to world +x.
		if tp.X > 0.001 then kept = kept + 1 elseif tp.X < -0.001 then culled = culled + 1 end
	end

	check(at_centre == 0, ("cut leaves no parts piled at the centre (%d found)"):format(at_centre))
	check(culled == 0, ("cut keeps every part on one side (%d strayed)"):format(culled))
	check(kept > 250, ("cut retains the parts rather than dropping them (%d of 300)"):format(kept))

	-- Uncut, the cube must still be a full cube: both sides populated.
	c.k13 = false
	local full = sweep(c, x6, mk_parts(300), 0.1)
	local l, r = 0, 0
	for _, tp in ipairs(full) do
		if tp.X > 0.001 then r = r + 1 elseif tp.X < -0.001 then l = l + 1 end
	end
	check(l > 50 and r > 50, ("uncut cube spans both halves (%d / %d)"):format(l, r))
end

-- ---- shared spin phase -------------------------------------------------
do
	local c = copy(cfg)
	c.k13 = false
	c.k14 = true -- both axes, which is where the shear showed
	c.k15 = true
	local x6 = { pre = {}, f = 0, n = 300 }

	-- Run the cube for a while with an established set of parts.
	local early = mk_parts(200)
	for frame = 1, 60 do
		x6.f = frame
		S.px(frame / 60, c, x6, x9, x1)
		sweep(c, x6, early, frame / 60)
	end

	-- A part claimed only now must land on the same cube as the veterans, not
	-- start its own rotation from zero.
	local late = { { id = 999, f = early[1].f, u = early[1].u, v = early[1].v } }
	x6.f = 61
	S.px(61 / 60, c, x6, x9, x1)
	local vet = sweep(c, x6, { early[1] }, 61 / 60)[1]
	local new = sweep(c, x6, late, 61 / 60)[1]
	check((vet - new).Magnitude < 0.001,
		("a late part matches an established one at the same face slot: %.3f apart"):format((vet - new).Magnitude))

	-- The cube must actually be turning, or the check above passes trivially.
	local before = sweep(c, x6, { early[2] }, 61 / 60)[1]
	for frame = 62, 90 do
		x6.f = frame
		S.px(frame / 60, c, x6, x9, x1)
	end
	local after = sweep(c, x6, { early[2] }, 90 / 60)[1]
	check((before - after).Magnitude > 1, "the cube is genuinely spinning")

	-- Every part must read one angle within a bucket cycle, so the body stays
	-- rigid: radius from the centre is invariant under rotation.
	local rad = c.k11
	local worst = 0
	local pts = sweep(c, x6, early, 90 / 60)
	for _, tp in ipairs(pts) do
		local r = (tp - cen).Magnitude
		local err = math.abs(r - rad)
		-- Corner-to-face distance varies across a cube face, so compare against
		-- the legal band rather than a single radius.
		if r < rad - 0.001 or r > rad * math.sqrt(3) + 0.001 then
			if err > worst then worst = err end
		end
	end
	check(worst == 0, ("every part sits on the cube surface (worst stray %.3f)"):format(worst))
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
