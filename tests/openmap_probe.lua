-- Diagnostic: runs the three reported-broken shapes under conditions the existing
-- suite never covers -- an open baseplate instead of a closed box, and a core that
-- is standing still instead of being walked in a circle.
--
--   luajit tests/openmap_probe.lua

-- This harness only printed. With no assertions, no counter and no exit code it
-- could never fail a run, so a regression in any of the three shapes it covers
-- showed up as different numbers nobody was comparing against anything.
local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if cond then
		print("  ok   " .. msg)
	else
		fails = fails + 1
		print("  FAIL " .. msg)
	end
end

package.path = "tests/?.lua;" .. package.path
local rm = require("robloxmath")
Vector3, CFrame = rm.Vector3, rm.CFrame

Color3 = { new = function() return {} end }
Color3.fromRGB = Color3.new
if not table.create then
	table.create = function(n, v)
		local t = {}
		if v ~= nil then for i = 1, n do t[i] = v end end
		return t
	end
end
if not math.clamp then
	math.clamp = function(x, lo, hi) return x < lo and lo or (x > hi and hi or x) end
end

local character = {
	FindFirstChild = function() return nil end,
	FindFirstChildWhichIsA = function() return nil end,
}
game = {
	GetService = function(_, name)
		if name == "Players" then
			return { LocalPlayer = { Character = character }, GetPlayers = function() return {} end }
		end
		return setmetatable({}, { __index = function() return function() end end })
	end,
}

-- An open baseplate: ground at y = 0, nothing else. This is the overwhelmingly
-- common map for this script, and it is the case the closed test room hides.
local RAYS_CAST = 0
local RAY_HITS = 0
workspace = {
	CurrentCamera = { CFrame = CFrame.new(0, 0, 0) },
	Raycast = function(_, org, dv)
		RAYS_CAST = RAYS_CAST + 1
		local reach = dv.Magnitude
		if reach < 1e-6 then return nil end
		local dir = dv / reach
		if dir.Y < -1e-6 then
			local t = (0 - org.Y) / dir.Y
			if t > 0.01 and t < reach then
				RAY_HITS = RAY_HITS + 1
				return { Position = org + dir * t, Normal = Vector3.new(0, 1, 0) }
			end
		end
		return nil
	end,
}
RaycastParams = { new = function() return {} end }
Enum = setmetatable({}, {
	__index = function() return setmetatable({}, { __index = function() return 0 end }) end,
})

-- shapes/ first, then shapes-onreview/. Three shapes moved to the review folder and
-- this asserted straight onto the old path, so both harnesses crashed on load --
-- shapes_smoke before it reached any of its geometry checks at all.
local function load_shape(name)
	local f = io.open("shapes/" .. name .. ".lua")
	local from = "shapes/"
	if not f then
		f = io.open("shapes-onreview/" .. name .. ".lua")
		from = "shapes-onreview/"
	end
	assert(f, "cannot find " .. name .. ".lua in shapes/ or shapes-onreview/")
	local src = f:read("a"); f:close()
	return assert(load(src, from .. name))()
end
local function shape_cfg(name)
	local cfg = assert(loadfile("config.lua"))().x2[name]
	-- The shapes in shapes-onreview/ deliberately have no config block yet, so seed
	-- from the module's own Controls the way main.lua's local-shape loader does.
	if not cfg then
		local mod = load_shape(name)
		local seeded = {}
		for _, ctl in ipairs(mod.Controls or {}) do
			if type(ctl) == "table" and ctl.Key then
				local dv = ctl.Default
				if dv == nil then
					dv = ctl.Min or 0
					if ctl.Div then dv = dv / ctl.Div end
				end
				seeded[ctl.Key] = dv
			end
		end
		return seeded
	end
	local copy = {}
	for k, v in pairs(cfg) do copy[k] = v end
	return copy
end
local function mk_x6() return { pre = {}, f = 0, n = 400 } end
local function part(pos) return { Position = pos } end

local x1 = { k10 = 20, k7 = 4 }
local x9 = { c1 = 0.15, c2 = 0.05 }

local function stats(name, tps, cen)
	local minr, maxr, sum = math.huge, 0, 0
	local uniq, seen = 0, {}
	for _, tp in ipairs(tps) do
		local r = (tp - cen).Magnitude
		if r < minr then minr = r end
		if r > maxr then maxr = r end
		sum = sum + r
		local key = ("%.0f,%.0f,%.0f"):format(tp.X, tp.Y, tp.Z)
		if not seen[key] then seen[key] = true; uniq = uniq + 1 end
	end
	-- #tps can be zero when the stubbed world produces no target at all; the two
	-- guarded call sites further down already knew that, this one did not and printed
	-- nan.
	local avg = (#tps > 0) and (sum / #tps) or 0
	print(("  %-22s n=%d  radius min=%.0f avg=%.0f max=%.0f  distinct=%d")
		:format(name, #tps, minr, avg, maxr, uniq))
	return minr, avg, maxr
end

print("=== Yamata no Orochi, open baseplate, core standing still ===")
do
	local S = load_shape("Yamata no Orochi")
	local cfg = shape_cfg("Yamata no Orochi")
	local x6 = mk_x6()
	local cen = Vector3.new(0, 12, 0)
	x6.b = { Position = cen }
	RAYS_CAST, RAY_HITS = 0, 0
	for frame = 1, 240 do
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	check(RAYS_CAST > 0, "the envelope probe cast at least one ray")
	local open_pct = (RAYS_CAST > 0) and (100 - RAY_HITS / RAYS_CAST * 100) or 0
	print(("  rays cast=%d  hits=%d (%.0f%% of the sphere is open sky)")
		:format(RAYS_CAST, RAY_HITS, open_pct))
	local st = x6.pre["World Envelope"]
	print(("  heads published=%d"):format(st.pK or 0))
	for i = 1, (st.pK or 0) do
		local h = st.phd[i]
		print(("    head %d: dir=(%.2f, %.2f, %.2f)  measured depth=%.0f")
			:format(i, h.dir.X, h.dir.Y, h.dir.Z, h.d))
	end
	local tps = {}
	for id = 40000, 40400 do
		local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 4.0, cfg, x1, x6, x9)
		tps[#tps + 1] = tp
	end
	check(#tps > 0, "every id got a target on an open baseplate")
	if #tps > 0 then
		stats("part targets", tps, cen)
	end
	local below = 0
	for _, tp in ipairs(tps) do if tp.Y < 0 then below = below + 1 end end
	print(("  parts driven under the floor: %d/%d"):format(below, #tps))
end

print("\n=== Wake Spline pair, core standing still (never dragged) ===")
for _, name in ipairs({ "Dragons Teeth", "Mugen Train" }) do
	local S = load_shape(name)
	local cfg = shape_cfg(name)
	local x6 = mk_x6()
	local cen = Vector3.new(0, 12, 0)
	x6.b = { Position = cen }
	for frame = 1, 240 do
		x6.f = frame
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	local st = x6.pre["Wake Spline"]
	print(("  %s: samples=%d head_count=%d"):format(name, st.count, st.head_count))
	local anti, tps = 0, {}
	for id = 40000, 40400 do
		local vel, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 4.0, cfg, x1, x6, x9)
		if tp == nil then anti = anti + 1 else tps[#tps + 1] = tp end
	end
	print(("  %s: %d/401 parts got no target at all (ANTI_SLEEP)"):format(name, anti))
	if #tps > 0 then stats(name .. " targets", tps, cen) end
end

print("\n=== Wake Spline pair, core dragged in a straight line ===")
for _, name in ipairs({ "Dragons Teeth", "Mugen Train" }) do
	local S = load_shape(name)
	local cfg = shape_cfg(name)
	local x6 = mk_x6()
	x6.b = { Position = Vector3.new(0, 12, 0) }
	for frame = 1, 600 do
		x6.f = frame
		-- 30 studs/s, a plausible drag speed.
		x6.b.Position = Vector3.new(frame / 60 * 30, 12, 0)
		S.px(frame / 60, cfg, x6, x9, x1)
	end
	local st = x6.pre["Wake Spline"]
	local cen = x6.b.Position
	print(("  %s: samples=%d head_count=%d gy probed=%s")
		:format(name, st.count, st.head_count, tostring(st.gy[st.w] ~= false)))
	local anti, tps = 0, {}
	for id = 40000, 40400 do
		local _, tp = S.f2(part(Vector3.new(0, 0, 0)), cen, { id = id }, 10.0, cfg, x1, x6, x9)
		if tp == nil then anti = anti + 1 else tps[#tps + 1] = tp end
	end
	print(("  %s: %d/401 no target"):format(name, anti))
	check(anti < 401, ("%s returns a target for at least some ids"):format(name))
	if #tps > 0 then stats(name .. " targets", tps, cen) end
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
