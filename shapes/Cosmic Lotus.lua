local M = {}
local NAME = "Cosmic Lotus"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 6, 0, 40) * x9.c2
	st.t = t
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u, v, w = (id * 0.8191725133961645) % 1, (id * 0.6710436067037893) % 1, (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local radius = math.clamp(c.k11 or 130, 30, 350)
	local petals = math.clamp(math.floor(c.k12 or 8), 4, 20)
	local layers = math.clamp(math.floor(c.k14 or 3), 1, 5)
	local depth = math.clamp(c.k15 or 75, 0, 100) / 100
	local x, y, z

	if pick < 0.84 then
		local layer = (id - 1) % layers
		local petal = math.floor((id - 1) / layers) % petals
		local scale = 1 / (1 + layer * 0.75)
		local open = 1 - depth * (0.5 - 0.5 * math.cos(phase * 1.5 - layer * 0.85)) * 0.72
		local direction = c.k17 ~= false and (layer % 2 == 0 and 1 or -1) or 1
		-- Spend most of the parts on the outline and midrib so separate petals
		-- remain visible at preview counts instead of dissolving into a disk.
		local side
		if w < 0.35 then side = -1
		elseif w < 0.70 then side = 1
		elseif w < 0.80 then side = 0
		else side = v * 2 - 1 end
		u = u ^ 0.75
		local width = math.sin(math.pi * u) ^ 0.8
		local a = petal * TAU / petals + layer * math.pi / petals + direction * phase * 0.16
			+ side * (math.pi / petals) * 0.70 * width
		local r = radius * scale * (0.08 + u * open)
		x, z = r * math.cos(a), r * math.sin(a)
		-- A cupped surface with a pointed tip; closing lifts petals into a bud.
		y = radius * scale * (0.85 * (1 - open) * u + 0.25 * math.sin(math.pi * u)
			+ 0.09 * side * side * width) + layer * radius * 0.1
	elseif pick < 0.96 then
		local sy = 1 - 2 * u
		local r = radius * 0.16 * (1 + 0.1 * math.sin(phase * 2))
		local ring = math.sqrt(math.max(0, 1 - sy * sy))
		local a = v * TAU + phase
		x, y, z = r * ring * math.cos(a), radius * 0.23 + r * sy, r * ring * math.sin(a)
	else
		local a = u * TAU - phase * 0.5
		local r = radius * (0.29 + 0.015 * math.cos(w * TAU))
		x, y, z = r * math.cos(a), radius * 0.28 + r * 0.32 * math.sin(a), r * math.sin(a)
	end

	local target = cen + Vector3.new(x, y + (c.k16 or 40), z)
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Bloom Radius", Min = 30, Max = 350, Key = "k11", Default = 130 },
	{ Type = "Slider", Name = "Petals per Layer", Min = 4, Max = 20, Key = "k12", Default = 8, IntOnly = true },
	{ Type = "Slider", Name = "Bloom Speed", Min = 0, Max = 40, Key = "k13", Default = 6, ExactMax = true },
	{ Type = "Slider", Name = "Petal Layers", Min = 1, Max = 5, Key = "k14", Default = 3, IntOnly = true },
	{ Type = "Slider", Name = "Bloom Depth %", Min = 0, Max = 100, Key = "k15", Default = 75, IntOnly = true,
		Desc = "How far the petals close during each bloom. Zero holds the flower open." },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k16", Default = 40 },
	{ Type = "Toggle", Name = "Counter-Rotate Layers", Key = "k17", Default = true },
}

return M
