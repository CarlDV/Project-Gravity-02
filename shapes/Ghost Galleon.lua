local M = {}
M.ContinuousMotion = true
local NAME = "Ghost Galleon"
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

	local length = math.clamp(c.k11 or 155, 60, 350)
	local width = math.clamp(c.k12 or 52, 20, 130)
	local height = math.clamp(c.k14 or 170, 60, 350)
	local fullness = math.clamp(c.k15 or 80, 30, 130) / 100
	local masts = math.clamp(math.floor(c.k17 or 3), 1, 4)
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > width * 0.5 and pick > 0.82 then pick = pick % 0.82 end
	local x, y, z
	if pick < 0.38 then
		local q = 2 * u - 1
		local beam = width * math.sqrt(math.max(0, 1 - q * q))
		x, y, z = beam * math.cos(v * math.pi), -width * 0.85 * math.sin(v * math.pi) * (0.7 + 0.3 * (1 - q * q)), length * q
	elseif pick < 0.5 then
		local q = 2 * u - 1
		x, y, z = width * math.sqrt(math.max(0, 1 - q * q)) * (2 * v - 1), 0, length * q
	elseif pick < 0.82 then
		local mast = (id - 1) % masts
		local mz = masts == 1 and 0 or length * (mast / (masts - 1) - 0.5) * 1.2
		local sail = width * fullness * (1.05 - 0.22 * u)
		x = (2 * v - 1) * sail
		y = height * (0.14 + 0.78 * u)
		z = mz + width * fullness * 0.5 * math.sin(u * math.pi) * math.sin(v * math.pi) * (0.85 + 0.15 * math.sin(phase))
	elseif pick < 0.94 then
		local mast = (id - 1) % masts
		z = masts == 1 and 0 or length * (mast / (masts - 1) - 0.5) * 1.2
		if math.floor((id - 1) / masts) % 2 == 0 then
			x, y = width * 0.045 * math.cos(v * TAU), height * u
		else
			x, y = (2 * u - 1) * width * fullness, height * 0.91
		end
	else
		x, y, z = width * 0.045 * math.cos(v * TAU), height * (0.04 + 0.12 * u), length * (0.78 + 0.75 * u)
	end
	local rock = 0.055 * math.sin(phase * 0.7)
	local cr, sr = math.cos(rock), math.sin(rock)
	x, y = x * cr - y * sr, x * sr + y * cr
	local ca, sa = math.cos(phase * 0.1), math.sin(phase * 0.1)
	local target = cen + Vector3.new(x * ca - z * sa, y + math.clamp(c.k16 or 115, -100, 500) + width * 0.12 * math.sin(phase), x * sa + z * ca)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 115, 0)
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
	{ Type = "Slider", Name = "Hull Half Length", Min = 60, Max = 350, Key = "k11", Default = 155 },
	{ Type = "Slider", Name = "Hull Half Width", Min = 20, Max = 130, Key = "k12", Default = 52 },
	{ Type = "Slider", Name = "Voyage Speed", Min = 0, Max = 40, Key = "k13", Default = 5, ExactMax = true },
	{ Type = "Slider", Name = "Mast Height", Min = 60, Max = 350, Key = "k14", Default = 170 },
	{ Type = "Slider", Name = "Sail Fullness %", Min = 30, Max = 130, Key = "k15", Default = 80 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k16", Default = 115 },
	{ Type = "Slider", Name = "Masts", Min = 1, Max = 4, Key = "k17", Default = 3, IntOnly = true },
}

return M
