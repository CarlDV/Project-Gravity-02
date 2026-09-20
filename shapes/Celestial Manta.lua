local M = {}
M.ContinuousMotion = true
local NAME = "Celestial Manta"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 8, 0, 40) * x9.c2
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

	local r = math.clamp(c.k11 or 80, 30, 200)
	local span = math.clamp(c.k12 or 170, 60, 400)
	local tail = math.clamp(c.k14 or 200, 40, 500)
	local flap = math.clamp(c.k15 or 35, 0, 80) / 100
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > r * 0.3 and pick > 0.88 then pick = pick % 0.88 end
	local x, y, z
	if pick < 0.68 then
		local side = id % 2 == 0 and 1 or -1
		local s = u
		x = side * (r * 0.1 + span * s)
		z = r * (0.35 - 0.4 * s - v * (1.1 * (1 - s) ^ 0.65 + 0.1))
		y = span * flap * s * s * math.sin(phase - s * 1.2) + (w - 0.5) * r * 0.1 * (1 - s)
	elseif pick < 0.88 then
		local q = 2 * u - 1
		local ring = math.sqrt(math.max(0, 1 - q * q))
		x, y, z = r * 0.32 * ring * math.cos(v * TAU), r * 0.18 * ring * math.sin(v * TAU), r * q
	elseif pick < 0.97 then
		x = tail * 0.08 * u * u * math.sin(u * 8 - phase * 1.4)
		y = -tail * 0.08 * u + r * 0.02 * math.cos(v * TAU) * (1 - u)
		z = -r * 0.8 - tail * u
	else
		local side = id % 2 == 0 and 1 or -1
		x = side * r * (0.22 + 0.12 * math.sin(u * math.pi))
		y = r * 0.1 * math.sin(u * TAU)
		z = r * (0.75 + 0.4 * u)
	end
	local travel = math.clamp(c.k17 or 70, 0, 250)
	local turn = phase * 0.16
	local ca, sa = math.cos(turn), math.sin(turn)
	local target = cen + Vector3.new(x * ca + z * sa + travel * math.sin(turn),
		y + math.clamp(c.k16 or 180, -100, 500) + travel * 0.25 * math.sin(phase * 0.3),
		-x * sa + z * ca + travel * (math.cos(turn) - 1))
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 180, 0)
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
	{ Type = "Slider", Name = "Body Length", Min = 30, Max = 200, Key = "k11", Default = 80 },
	{ Type = "Slider", Name = "Wing Reach", Min = 60, Max = 400, Key = "k12", Default = 170 },
	{ Type = "Slider", Name = "Swim Speed", Min = 0, Max = 40, Key = "k13", Default = 8, ExactMax = true },
	{ Type = "Slider", Name = "Ribbon Tail Length", Min = 40, Max = 500, Key = "k14", Default = 200 },
	{ Type = "Slider", Name = "Wing Ripple %", Min = 0, Max = 80, Key = "k15", Default = 35 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k16", Default = 180 },
	{ Type = "Slider", Name = "Glide Reach", Min = 0, Max = 250, Key = "k17", Default = 70 },
}

return M
