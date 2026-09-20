local M = {}
M.ContinuousMotion = true
local NAME = "Infernal Skull"
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

	local radius = math.clamp(c.k11 or 95, 40, 220)
	local jaw = math.clamp(c.k12 or 55, 20, 140)
	local horns = math.clamp(c.k14 or 115, 30, 280)
	local sweep = math.clamp(c.k15 or 60, 0, 120) / 100
	local gape = math.clamp(c.k17 or 30, 0, 80) / 100
	local size = p.Size
	local bulky = size and math.max(size.X, size.Y, size.Z) > radius * 0.24
	if bulky and pick >= 0.56 then pick = pick % 0.56 end
	local x, y, z
	if pick < 0.56 then
		local q = 2 * u - 1
		local ring = math.sqrt(math.max(0, 1 - q * q))
		x, y, z = radius * ring * math.cos(v * TAU), radius * (0.2 + 0.95 * q), radius * 0.72 * ring * math.sin(v * TAU)
		-- Wall panels form the forehead. The sockets are tunnels through both
		-- sides of the cranium, so rear skull pieces cannot plug the visible holes.
		if bulky then
			y = radius * (0.94 + 0.16 * u)
			x, z = radius * 0.7 * math.cos(v * TAU), radius * 0.5 * math.sin(v * TAU)
		end
		local eyeX = (math.abs(x) - radius * 0.36) / (radius * 0.25)
		local eyeY = (y - radius * 0.35) / (radius * 0.24)
		local nose = math.abs(x) < radius * 0.14 and y < radius * 0.12 and y > -radius * 0.25
		if eyeX * eyeX + eyeY * eyeY < 1 or nose then
			local side = x >= 0 and 1 or -1
			x = side * radius * 0.36 + radius * 0.28 * math.cos(w * TAU)
			y = radius * 0.35 + radius * 0.27 * math.sin(w * TAU)
		end
	elseif pick < 0.68 then
		local side = id % 2 == 0 and 1 or -1
		local angle = u * TAU
		x = side * radius * 0.36 + radius * (0.25 + 0.025 * v) * math.cos(angle)
		y = radius * 0.35 + radius * (0.24 + 0.025 * v) * math.sin(angle)
		z = radius * 0.65
	elseif pick < 0.83 then
		local angle = u * math.pi
		x, z = radius * 0.76 * math.cos(angle), radius * 0.62 * math.sin(angle)
		y = -radius * 0.52 - jaw * (0.2 + gape * (0.75 + 0.25 * math.sin(phase))) + (v - 0.5) * jaw * 0.3
	elseif pick < 0.95 then
		local side = id % 2 == 0 and 1 or -1
		local r = radius * 0.13 * (1 - u) ^ 0.7
		x = side * (radius * 0.62 + horns * 0.55 * math.sin(u * math.pi * 0.7)) + r * math.cos(v * TAU)
		y = radius * 0.88 + horns * u
		z = -horns * sweep * u * u + r * math.sin(v * TAU)
	else
		local tooth = (id - 1) % 8
		x = radius * ((tooth + 0.5) / 8 - 0.5) * 1.15
		y = -radius * 0.45 - jaw * 0.35 * u
		z = radius * 0.62 * math.sqrt(math.max(0, 1 - (x / radius) ^ 2))
	end
	local ca, sa = math.cos(phase * 0.12), math.sin(phase * 0.12)
	local target = cen + Vector3.new(x * ca - z * sa, y + math.clamp(c.k16 or 210, -100, 600), x * sa + z * ca)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 210, 0)
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
	{ Type = "Slider", Name = "Skull Radius", Min = 40, Max = 220, Key = "k11", Default = 95 },
	{ Type = "Slider", Name = "Jaw Size", Min = 20, Max = 140, Key = "k12", Default = 55 },
	{ Type = "Slider", Name = "Apparition Speed", Min = 0, Max = 40, Key = "k13", Default = 6, ExactMax = true },
	{ Type = "Slider", Name = "Horn Length", Min = 30, Max = 280, Key = "k14", Default = 115 },
	{ Type = "Slider", Name = "Horn Sweep %", Min = 0, Max = 120, Key = "k15", Default = 60 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 600, Key = "k16", Default = 210 },
	{ Type = "Slider", Name = "Jaw Opening %", Min = 0, Max = 80, Key = "k17", Default = 30 },
}

return M
