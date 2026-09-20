local M = {}
M.ContinuousMotion = true
local NAME = "Void Cathedral"
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
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local radius = math.clamp(c.k11 or 125, 40, 300)
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > radius * 0.18 and pick >= 0.85 then
		pick = pick % 0.4
	end
	local towers = math.clamp(math.floor(c.k12 or 6), 3, 12)
	local height = math.clamp(c.k14 or 240, 80, 550)
	local lift = math.clamp(c.k15 or 65, 20, 120) / 100
	local petals = math.clamp(math.floor(c.k16 or 8), 4, 16)
	local thickness = math.clamp(c.k18 or 1.8, 0, 8)
	local tower = (id - 1) % towers
	-- De-interleave before choosing an edge: an even tower count must not give
	-- alternate towers only two of their four spire edges.
	local localId = math.floor((id - 1) / towers)
	local a = tower * TAU / towers
	local ca, sa = math.cos(a), math.sin(a)
	local half = math.pi / towers
	local width = radius * math.sin(half)
	local x, y, z
	if pick < 0.20 then
		local edge = localId % 4 * TAU / 4 + math.pi * 0.25
		local foot = radius * 0.075 * (1 - 0.35 * u)
		x, z = radius * ca + foot * math.cos(edge), radius * sa + foot * math.sin(edge)
		y = height * 0.52 * u
	elseif pick < 0.40 then
		local edge = localId % 4 * TAU / 4 + math.pi * 0.25
		local foot = radius * 0.085 * (1 - u)
		x, z = radius * ca + foot * math.cos(edge), radius * sa + foot * math.sin(edge)
		y = height * (0.52 + 0.55 * u)
	elseif pick < 0.64 then
		-- Two circular arcs meet at a Gothic point. The end points are exactly
		-- the adjacent pillars; sampling the arc angle avoids a pile at its peak.
		local side = u < 0.5 and -1 or 1
		local along = u < 0.5 and u * 2 or (1 - u) * 2
		local angle = math.pi - along * math.pi / 3
		local across = side * (-width - 2 * width * math.cos(angle))
		local rise = math.sin(angle) / math.sin(math.pi / 3)
		local middle = a + half
		local radial = radius * math.cos(half)
		x = radial * math.cos(middle) - across * math.sin(middle)
		z = radial * math.sin(middle) + across * math.cos(middle)
		y = height * (0.42 + lift * 0.5 * rise)
	elseif pick < 0.76 then
		-- Flying buttresses connect the outer pillars to the suspended crown.
		local r = radius * (1 - 0.74 * u)
		x, z = r * ca, r * sa
		y = height * (0.33 + (0.45 + lift * 0.3) * math.sin(u * math.pi * 0.5))
	elseif pick < 0.85 then
		local upper = localId % 2 == 0
		local r = radius * (upper and 0.26 or 1.04)
		local angle = u * TAU
		x, z = r * math.cos(angle), r * math.sin(angle)
		y = upper and height * (0.78 + lift * 0.3) or 0
	elseif pick < 0.95 then
		local middle = a + half
		local angle = u * TAU
		local window = math.min(width * 0.75, height * 0.13)
		local r = window * (0.68 + 0.32 * math.cos(petals * angle))
		local across = r * math.cos(angle)
		local radial = radius * math.cos(half)
		x = radial * math.cos(middle) - across * math.sin(middle)
		z = radial * math.sin(middle) + across * math.cos(middle)
		y = height * 0.47 + r * math.sin(angle)
	else
		-- A counter-rotating aureole above the roof, with an empty central nave.
		local angle = u * TAU - phase * 0.8
		local r = radius * 0.46
		local tilt = 0.35 + 0.2 * math.sin(phase * 0.6)
		x = r * math.cos(angle)
		y = height * 1.12 + r * math.sin(angle) * math.sin(tilt)
		z = r * math.sin(angle) * math.cos(tilt)
	end
	-- Deterministic filament thickness; no instance changes or per-part state.
	x, z = x + thickness * math.cos(v * TAU), z + thickness * math.sin(v * TAU)
	local turn = phase * 0.2
	local ct, sn = math.cos(turn), math.sin(turn)
	local target = cen + Vector3.new(x * ct - z * sn, y + math.clamp(c.k17 or 55, -100, 500), x * sn + z * ct)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k17 or 55, 0)
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
	{ Type = "Slider", Name = "Cathedral Radius", Min = 40, Max = 300, Key = "k11", Default = 125 },
	{ Type = "Slider", Name = "Spire Towers", Min = 3, Max = 12, Key = "k12", Default = 6, IntOnly = true },
	{ Type = "Slider", Name = "Ascension Speed", Min = 0, Max = 40, Key = "k13", Default = 5, ExactMax = true },
	{ Type = "Slider", Name = "Cathedral Height", Min = 80, Max = 550, Key = "k14", Default = 240 },
	{ Type = "Slider", Name = "Vault Rise %", Min = 20, Max = 120, Key = "k15", Default = 65, IntOnly = true },
	{ Type = "Slider", Name = "Rose Window Petals", Min = 4, Max = 16, Key = "k16", Default = 8, IntOnly = true },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k17", Default = 55 },
	{ Type = "Slider", Name = "Filament Thickness", Min = 0, Max = 80, Key = "k18", Default = 1.8, Div = 10 },
}

return M
