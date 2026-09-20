local M = {}
M.ContinuousMotion = true
local NAME = "World Tree"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 5, 0, 40) * x9.c2
	st.t = t
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u = (id * 0.8191725133961645) % 1
	local v = (id * 0.6710436067037893) % 1
	local w = (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0

	local radius = math.clamp(c.k11 or 135, 50, 300)
	local height = math.clamp(c.k12 or 250, 80, 600)
	local branches = math.clamp(math.floor(c.k14 or 7), 4, 12)
	local foliage = math.clamp(c.k15 or 55, 20, 100) / 100
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > radius * 0.2 and pick > 0.24 and pick < 0.68 then pick = 0.68 + pick % 0.24 end
	if c.k16 == false and pick >= 0.68 then pick = 0.24 + pick % 0.28 end
	local branch = (id - 1) % branches
	local tier = math.floor((id - 1) / branches) % 3
	local a = branch * TAU / branches + tier * 0.53
	local x, y, z
	if pick < 0.24 then
		local r = radius * (0.07 + 0.11 * (1 - u) ^ 2)
		local angle = v * TAU + u * 1.2
		x, z = r * math.cos(angle) + radius * 0.04 * math.sin(u * 4), r * math.sin(angle)
		y = height * 0.84 * u
	elseif pick < 0.52 then
		local reach = radius * (1 - tier * 0.19) * u
		local angle = a + 0.2 * u * math.sin(phase * 0.5 + branch)
		local r = radius * 0.06 * (1 - u) + radius * 0.012
		x = reach * math.cos(angle) + r * math.cos(v * TAU)
		z = reach * math.sin(angle) + r * math.sin(v * TAU)
		y = height * (0.34 + tier * 0.18 + 0.23 * math.sin(u * math.pi * 0.5))
	elseif pick < 0.68 then
		local reach = radius * (0.1 + 0.95 * u)
		local angle = a + u * 0.38
		local r = radius * 0.07 * (1 - u)
		x, z = reach * math.cos(angle) + r * math.cos(v * TAU), reach * math.sin(angle) + r * math.sin(v * TAU)
		y = -height * 0.18 * u + height * 0.09 * math.sin(u * math.pi)
	elseif pick < 0.94 then
		local reach = radius * (1 - tier * 0.19)
		local angle = a + 0.2 * math.sin(phase * 0.5 + branch)
		local sy = 2 * u - 1
		local ring = math.sqrt(math.max(0, 1 - sy * sy))
		local leaf = radius * foliage * (0.55 + 0.12 * w)
		x = reach * math.cos(angle) + leaf * ring * math.cos(v * TAU)
		z = reach * math.sin(angle) + leaf * ring * math.sin(v * TAU)
		y = height * (0.57 + tier * 0.18) + leaf * 0.5 * sy
	else
		local angle = u * TAU - phase * 0.3
		x, z = radius * 1.18 * math.cos(angle), radius * 1.18 * math.sin(angle)
		y = height * 0.06 + radius * 0.015 * math.sin(v * TAU)
	end
	local target = cen + Vector3.new(x, y + math.clamp(c.k17 or 80, -100, 500), z)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k17 or 80, 0)
	target = pivot + (target - pivot) * (math.clamp(c.k24 or 55, 25, 150) / 100)
	-- The runtime supplies this even at speed zero or Formation Time Scale zero.
	-- The same offset on every piece keeps the silhouette intact while it moves.
	if x6.motion_offset then target = target + x6.motion_offset end
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Debris Scale %", Min = 25, Max = 150, Key = "k24", Default = 55, IntOnly = true,
		Desc = "Smaller formations stay denser with limited rubble. Increase for more or larger parts." },
	{ Type = "Slider", Name = "Canopy Reach", Min = 50, Max = 300, Key = "k11", Default = 135 },
	{ Type = "Slider", Name = "Tree Height", Min = 80, Max = 600, Key = "k12", Default = 250 },
	{ Type = "Slider", Name = "Bough Motion Speed", Min = 0, Max = 40, Key = "k13", Default = 5, ExactMax = true },
	{ Type = "Slider", Name = "Boughs per Tier", Min = 4, Max = 12, Key = "k14", Default = 7, IntOnly = true },
	{ Type = "Slider", Name = "Canopy Fullness %", Min = 20, Max = 100, Key = "k15", Default = 55 },
	{ Type = "Toggle", Name = "Leaf Crowns", Key = "k16", Default = true },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k17", Default = 80 },
}

return M
