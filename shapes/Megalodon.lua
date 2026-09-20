local M = {}
M.ContinuousMotion = true
local NAME = "Megalodon"
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

	local length = math.clamp(c.k11 or 140, 50, 300)
	local girth = math.clamp(c.k12 or 38, 12, 90)
	local fin = math.clamp(c.k14 or 100, 30, 240)
	local gape = math.clamp(c.k15 or 30, 0, 80) / 100
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > girth * 0.7 and pick > 0.9 then pick = pick % 0.57 end
	local x, y, z
	if pick < 0.57 then
		local q = 2 * u - 1
		local ring = math.sqrt(math.max(0, 1 - q * q))
		x, y, z = girth * ring * math.cos(v * TAU), girth * 0.85 * ring * math.sin(v * TAU), length * q
		if q > 0.5 then y = y + (y >= 0 and 1 or -1) * girth * gape * (q - 0.5) end
	elseif pick < 0.72 then
		local a = math.sqrt(u)
		local b = v * a
		x = (w - 0.5) * girth * 0.18 * (1 - b)
		y = girth * (1 - a) + (girth + fin) * b + girth * 0.6 * (a - b)
		z = length * (0.12 * (1 - a) - 0.15 * b - 0.6 * (a - b))
	elseif pick < 0.90 then
		local side = id % 2 == 0 and 1 or -1
		local a = math.sqrt(u)
		x = side * (girth * 0.5 + fin * a)
		y = -girth * 0.45 - fin * 0.14 * a
		z = length * (-0.05 - a * 0.5 - v * (1 - a) * 0.55)
	else
		local side = id % 2 == 0 and 1 or -1
		x = (w - 0.5) * girth * 0.16 * (1 - u)
		y = side * fin * u * (side > 0 and 1 or 0.75)
		z = -length * (0.88 + 0.4 * u + v * 0.15 * (1 - u))
	end
	-- A travelling wave grows toward the tail; the rigid snout stays readable.
	local aft = math.max(0, -z / length)
	x = x + girth * 0.22 * aft * aft * math.sin(phase * 1.5 + z / length * 2)
	local turn = phase * 0.14
	local ca, sa = math.cos(turn), math.sin(turn)
	local travel = math.clamp(c.k17 or 100, 0, 300)
	local target = cen + Vector3.new(x * ca + z * sa + travel * math.sin(turn),
		y + math.clamp(c.k16 or 160, -100, 500), -x * sa + z * ca + travel * (math.cos(turn) - 1))
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 160, 0)
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
	{ Type = "Slider", Name = "Body Half Length", Min = 50, Max = 300, Key = "k11", Default = 140 },
	{ Type = "Slider", Name = "Body Girth", Min = 12, Max = 90, Key = "k12", Default = 38 },
	{ Type = "Slider", Name = "Hunt Speed", Min = 0, Max = 40, Key = "k13", Default = 7, ExactMax = true },
	{ Type = "Slider", Name = "Fin Reach", Min = 30, Max = 240, Key = "k14", Default = 100 },
	{ Type = "Slider", Name = "Jaw Opening %", Min = 0, Max = 80, Key = "k15", Default = 30 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k16", Default = 160 },
	{ Type = "Slider", Name = "Patrol Reach", Min = 0, Max = 300, Key = "k17", Default = 100 },
}

return M
