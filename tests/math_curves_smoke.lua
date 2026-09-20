-- Invariants that finite-target checks cannot prove.
-- lune run tools/test_luau.luau tests/math_curves_smoke.lua
package.path = "tests/?.lua;" .. package.path
local rm = require("robloxmath")
Vector3, CFrame = rm.Vector3, rm.CFrame
Color3 = { fromRGB = function() return {} end }
math.clamp = math.clamp or function(x, lo, hi) return math.max(lo, math.min(x, hi)) end
table.create = table.create or function() return {} end
local config = assert(loadfile("config.lua"))()
local x9 = { c1 = 0.15, c2 = 0.05, c5 = 0.6 }
local part = { Position = Vector3.zero }
local checks, fails = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then fails = fails + 1; print("FAIL " .. label) end
end
local function copy(t) local out = {}; for k, v in pairs(t) do out[k] = v end; return out end
local function setup(name)
	local mod = assert(loadfile("shapes/" .. name .. ".lua"))()
	local cfg = copy(config.x2[name])
	local ctx = { pre = {} }
	mod.px(0, cfg, ctx, x9, config.x1)
	return mod, cfg, ctx
end
local function target(mod, cfg, ctx, id)
	local _, pos = mod.f2(part, Vector3.zero, { id = id }, 0, cfg, config.x1, ctx, x9)
	return pos
end

do
	local mod, cfg, ctx = setup("Torus Knot")
	local lo, hi = math.huge, 0
	local before = target(mod, cfg, ctx, 1)
	for frame = 1, 1800 do
		mod.px(frame / 120, cfg, ctx, x9)
		local pos = target(mod, cfg, ctx, 1)
		local step = (pos - before).Magnitude
		lo, hi, before = math.min(lo, step), math.max(hi, step), pos
		local radial = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
		check(math.abs((radial - cfg.k14) ^ 2 + pos.Y ^ 2 - cfg.k15 ^ 2) < 1e-6, "knot lies on its torus")
	end
	check(hi / lo < 1.015, "arc-length flow has uniform speed (ratio " .. hi / lo .. ")")
	for _, pair in ipairs({ { 2, 2 }, { 4, 6 }, { 6, 9 }, { 10, 10 } }) do
		cfg.k11, cfg.k12 = pair[1], pair[2]
		mod.px(0, cfg, ctx, x9)
		local a, b = pair[1], pair[2]
		while b ~= 0 do a, b = b, a % b end
		check(ctx.pre["Torus Knot"].layout.count == a, "non-coprime winding has separate link components")
		local cloud, minimum = {}, math.huge
		for i = 1, 180 do cloud[i] = target(mod, cfg, ctx, 1 + (i - 1) * a) end
		for i = 1, 180 do
			local pos = target(mod, cfg, ctx, 2 + (i - 1) * a)
			for _, other in ipairs(cloud) do minimum = math.min(minimum, (pos - other).Magnitude) end
		end
		check(minimum > 0.1, "link components do not retrace the same curve")
	end
end

for _, name in ipairs({ "Klein Bottle", "Möbius Strip" }) do
	local mod, cfg, ctx = setup(name)
	local before = {}
	for id = 1, 180 do before[id] = target(mod, cfg, ctx, id) end
	mod.px(4 * math.pi / (cfg.k13 * x9.c2), cfg, ctx, x9)
	for id = 1, 180 do
		check((target(mod, cfg, ctx, id) - before[id]).Magnitude < 1e-7, name .. ": double cover closes")
	end
	local source = target(mod, cfg, ctx, 1)
	local maxStep = 0
	for frame = 1, 2400 do
		mod.px(frame / 120, cfg, ctx, x9)
		local pos = target(mod, cfg, ctx, 1)
		maxStep = math.max(maxStep, (pos - source).Magnitude)
		source = pos
	end
	check(maxStep < 3, name .. ": crossing the twist never teleports a slot")
	if name == "Klein Bottle" then
		local small = target(mod, cfg, ctx, 17)
		cfg.k11 = cfg.k11 * 3
		local large = target(mod, cfg, ctx, 17)
		check((large - small * 3).Magnitude < 1e-7, "Klein bottle scales in all three dimensions")
	end
end

do
	local mod, cfg, ctx = setup("Hopf Fibration")
	cfg.k15 = 100
	for _, time in ipairs({ 0, 3, 12 }) do
		mod.px(time, cfg, ctx, x9)
		local rings = ctx.pre["Hopf Fibration"].fibres
		for i = 1, #rings do
			local ring = rings[i]
			check(math.abs(ring.first:Dot(ring.second)) < 1e-9, "Hopf circle basis is orthogonal")
			for j = i + 1, #rings do
				local other = rings[j]
				local d = (other.center - ring.center):Dot(ring.normal)
				local a = other.radius * other.first:Dot(ring.normal)
				local b = other.radius * other.second:Dot(ring.normal)
				local amplitude = math.sqrt(a * a + b * b)
				local inside = 0
				if amplitude > 1e-9 and math.abs(d) < amplitude then
					local angle = math.atan2(b, a)
					local delta = math.acos(-d / amplitude)
					for _, root in ipairs({ angle - delta, angle + delta }) do
						local pos = other.center + other.first * (other.radius * math.cos(root)) + other.second * (other.radius * math.sin(root))
						if (pos - ring.center).Magnitude < ring.radius then inside = inside + 1 end
					end
				end
				-- A linked circle pierces the other's spanning disk exactly once.
				check(inside == 1, "Hopf fibres stay pairwise linked during 4D motion")
			end
		end
	end
end

do
	local mod, cfg, ctx = setup("Celestial Ribbon")
	mod.px(2, cfg, ctx, x9)
	local pose = {}
	for i, node in ipairs(ctx.pre["Celestial Ribbon_1"]) do pose[i] = node.p end
	mod.px(2, cfg, ctx, x9)
	for i, node in ipairs(ctx.pre["Celestial Ribbon_1"]) do
		check((node.p - pose[i]).Magnitude < 1e-9, "ribbon stops when its clock stops")
	end
	mod.px(-3, cfg, ctx, x9)
	mod.px(2, cfg, ctx, x9)
	for i, node in ipairs(ctx.pre["Celestial Ribbon_1"]) do
		check((node.p - pose[i]).Magnitude < 1e-7, "ribbon reverses and restores the same pose")
	end
end

print(("%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
