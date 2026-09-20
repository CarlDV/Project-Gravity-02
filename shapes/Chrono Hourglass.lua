local M = {}
M.ContinuousMotion = true
local NAME = "Chrono Hourglass"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 7, 0, 40) * x9.c2
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

	local radius = math.clamp(c.k11 or 95, 35, 240)
	local height = math.clamp(c.k12 or 240, 80, 550)
	local pillars = math.clamp(math.floor(c.k14 or 6), 3, 12)
	local waist = math.clamp(c.k15 or 14, 8, 45) / 100
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > radius * 0.24 and pick > 0.76 then pick = pick % 0.6 end
	local x, y, z
	if pick < 0.6 then
		local side = id % 2 == 0 and 1 or -1
		local r = radius * (waist + (1 - waist) * u ^ 1.15)
		local angle = v * TAU + side * phase * 0.16
		x, y, z = r * math.cos(angle), side * height * 0.5 * u, r * math.sin(angle)
	elseif pick < 0.76 then
		local side = id % 2 == 0 and 1 or -1
		local angle = u * TAU
		local r = radius * (1.05 + 0.045 * math.cos(v * TAU))
		x, y, z = r * math.cos(angle), side * height * 0.5 + radius * 0.045 * math.sin(v * TAU), r * math.sin(angle)
	elseif pick < 0.92 then
		local pillar = (id - 1) % pillars
		local angle = pillar * TAU / pillars
		local r = radius * (1.1 + 0.1 * math.sin(u * math.pi))
		x, y, z = r * math.cos(angle), height * (u - 0.5), r * math.sin(angle)
	else
		-- A closed elliptical stream has no modulo-reset teleport at the bottom.
		local angle = u * TAU - phase
		x = radius * waist * 0.48 * math.sin(angle)
		y = height * 0.48 * math.cos(angle)
		z = radius * waist * 0.3 * math.sin(v * TAU)
	end
	local tilt = math.rad(math.clamp(c.k17 or 18, 0, 60)) * math.sin(phase * 0.24)
	local ct, sn = math.cos(tilt), math.sin(tilt)
	x, y = x * ct - y * sn, x * sn + y * ct
	local ca, sa = math.cos(phase * 0.12), math.sin(phase * 0.12)
	local target = cen + Vector3.new(x * ca - z * sa, y + math.clamp(c.k16 or 200, -100, 600), x * sa + z * ca)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 200, 0)
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
	{ Type = "Slider", Name = "Bowl Radius", Min = 35, Max = 240, Key = "k11", Default = 95 },
	{ Type = "Slider", Name = "Hourglass Height", Min = 80, Max = 550, Key = "k12", Default = 240 },
	{ Type = "Slider", Name = "Sand Flow Speed", Min = 0, Max = 40, Key = "k13", Default = 7, ExactMax = true },
	{ Type = "Slider", Name = "Cage Pillars", Min = 3, Max = 12, Key = "k14", Default = 6, IntOnly = true },
	{ Type = "Slider", Name = "Throat Width %", Min = 8, Max = 45, Key = "k15", Default = 14 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 600, Key = "k16", Default = 200 },
	{ Type = "Slider", Name = "Precession Tilt", Min = 0, Max = 60, Key = "k17", Default = 18 },
}

return M
