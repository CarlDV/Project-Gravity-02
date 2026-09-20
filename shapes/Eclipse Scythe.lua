local M = {}
M.ContinuousMotion = true
local NAME = "Eclipse Scythe"
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
	local u = (id * 0.8191725133961645) % 1
	local v = (id * 0.6710436067037893) % 1
	local w = (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0

	local radius = math.clamp(c.k11 or 115, 40, 260)
	local blade = math.clamp(c.k12 or 38, 12, 90)
	local handle = math.clamp(c.k14 or 260, 80, 600)
	local opening = math.clamp(c.k15 or 110, 50, 150) / 100
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > blade * 0.8 and pick > 0.58 then pick = pick % 0.58 end
	local x, y, z
	if pick < 0.58 then
		local angle = u * math.pi * opening
		local width = blade * math.sin(math.pi * u) ^ 0.6
		local r = radius - width * v
		x, y, z = -radius + r * math.cos(angle), handle * 0.4 + r * math.sin(angle), (w - 0.5) * width * 0.35
	elseif pick < 0.84 then
		local angle = v * TAU + u * 8
		local r = blade * 0.2
		x, y, z = r * math.cos(angle), handle * (u - 0.6), r * math.sin(angle)
	elseif pick < 0.94 then
		local angle = u * TAU - phase * 0.5
		local r = blade * 1.1 + blade * 0.14 * math.cos(v * TAU)
		x, y, z = r * math.cos(angle), handle * 0.4 + r * math.sin(angle), blade * 0.14 * math.sin(v * TAU)
	else
		local q = 2 * u - 1
		local r = blade * 0.55 * (1 - math.abs(q))
		x, y, z = r * math.cos(v * TAU), -handle * 0.6 + q * blade, r * math.sin(v * TAU)
	end
	local tilt = math.rad(math.clamp(c.k17 or -15, -60, 60))
	local ct, sn = math.cos(tilt), math.sin(tilt)
	x, y = x * ct - y * sn, x * sn + y * ct
	local ca, sa = math.cos(phase * 0.16), math.sin(phase * 0.16)
	local target = cen + Vector3.new(x * ca - z * sa, y + math.clamp(c.k16 or 230, -100, 650), x * sa + z * ca)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 230, 0)
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
	{ Type = "Slider", Name = "Crescent Radius", Min = 40, Max = 260, Key = "k11", Default = 115 },
	{ Type = "Slider", Name = "Blade Width", Min = 12, Max = 90, Key = "k12", Default = 38 },
	{ Type = "Slider", Name = "Reaper Spin Speed", Min = 0, Max = 40, Key = "k13", Default = 6, ExactMax = true },
	{ Type = "Slider", Name = "Haft Length", Min = 80, Max = 600, Key = "k14", Default = 260 },
	{ Type = "Slider", Name = "Crescent Sweep %", Min = 50, Max = 150, Key = "k15", Default = 110 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 650, Key = "k16", Default = 230 },
	{ Type = "Slider", Name = "Scythe Tilt", Min = -60, Max = 60, Key = "k17", Default = -15 },
}

return M
