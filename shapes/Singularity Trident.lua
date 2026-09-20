local M = {}
M.ContinuousMotion = true
local NAME = "Singularity Trident"
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

	local spread = math.clamp(c.k11 or 95, 35, 240)
	local thick = math.clamp(c.k12 or 22, 8, 60)
	local handle = math.clamp(c.k14 or 240, 70, 550)
	local reach = math.clamp(c.k15 or 150, 50, 320)
	local twists = math.clamp(c.k17 or 3, 0, 8)
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > thick * 1.1 and pick > 0.86 then pick = 0.34 + pick % 0.38 end
	local x, y, z
	if pick < 0.34 then
		local angle = v * TAU + u * twists * TAU
		local r = thick * (0.35 + 0.08 * math.cos(u * TAU * twists))
		x, y, z = r * math.cos(angle), handle * (u - 0.65), r * math.sin(angle)
	elseif pick < 0.72 then
		local prong = (id - 1) % 3 - 1
		local stem = u * u * (3 - 2 * u)
		local r = thick * (0.12 + 0.45 * (1 - u) + 0.7 * math.sin(math.pi * math.clamp((u - 0.55) / 0.45, 0, 1)))
		x = prong * spread * (0.2 + 0.8 * stem) + r * math.cos(v * TAU)
		y = handle * 0.3 + reach * u * (prong == 0 and 1.2 or 0.9)
		z = r * math.sin(v * TAU) * 0.65
	elseif pick < 0.86 then
		x = spread * (2 * u - 1)
		y = handle * 0.3 + reach * 0.28 * (x / spread) ^ 2
		z = thick * 0.4 * math.sin(v * TAU)
	elseif pick < 0.94 then
		local q = 2 * u - 1
		local r = thick * 1.3 * math.sqrt(math.max(0, 1 - q * q))
		x, y, z = r * math.cos(v * TAU), handle * 0.2 + thick * 1.3 * q, r * math.sin(v * TAU)
	else
		local angle = u * TAU - phase * 0.4
		x, y, z = spread * 0.65 * math.cos(angle), handle * 0.1 + spread * 0.22 * math.sin(angle), spread * 0.65 * math.sin(angle)
	end
	local ca, sa = math.cos(phase * 0.16), math.sin(phase * 0.16)
	local target = cen + Vector3.new(x * ca - z * sa, y + math.clamp(c.k16 or 220, -100, 650), x * sa + z * ca)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 220, 0)
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
	{ Type = "Slider", Name = "Fork Spread", Min = 35, Max = 240, Key = "k11", Default = 95 },
	{ Type = "Slider", Name = "Relic Thickness", Min = 8, Max = 60, Key = "k12", Default = 22 },
	{ Type = "Slider", Name = "Trident Spin Speed", Min = 0, Max = 40, Key = "k13", Default = 6, ExactMax = true },
	{ Type = "Slider", Name = "Handle Length", Min = 70, Max = 550, Key = "k14", Default = 240 },
	{ Type = "Slider", Name = "Prong Length", Min = 50, Max = 320, Key = "k15", Default = 150 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 650, Key = "k16", Default = 220 },
	{ Type = "Slider", Name = "Grip Spirals", Min = 0, Max = 8, Key = "k17", Default = 3, IntOnly = true },
}

return M
