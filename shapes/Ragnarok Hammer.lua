local M = {}
M.ContinuousMotion = true
local NAME = "Ragnarok Hammer"
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

	local head = math.clamp(c.k11 or 85, 35, 220)
	local depth = math.clamp(c.k12 or 42, 15, 100)
	local handle = math.clamp(c.k14 or 220, 60, 500)
	local halo = math.clamp(c.k15 or 125, 50, 350)
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > depth * 0.65 and pick >= 0.6 then pick = pick % 0.6 end
	local x, y, z
	if pick < 0.6 then
		local face = (id - 1) % 6
		x, y, z = (2 * u - 1) * head, (2 * v - 1) * depth, (2 * w - 1) * depth * 0.8
		if face == 0 then x = head elseif face == 1 then x = -head
		elseif face == 2 then y = depth elseif face == 3 then y = -depth
		elseif face == 4 then z = depth * 0.8 else z = -depth * 0.8 end
		y = y + handle * 0.4
	elseif pick < 0.84 then
		local angle = v * TAU + u * TAU * 3
		local r = depth * (0.2 + 0.045 * math.cos(u * 30))
		x, z = r * math.cos(angle), r * math.sin(angle)
		y = handle * (u - 0.6)
	elseif pick < 0.93 then
		local q = 2 * u - 1
		local r = depth * 0.52 * math.sqrt(math.max(0, 1 - q * q))
		x, y, z = r * math.cos(v * TAU), -handle * 0.6 + depth * 0.52 * q, r * math.sin(v * TAU)
	else
		local angle = u * TAU - phase * 0.6
		x, z = halo * math.cos(angle), halo * math.sin(angle) * 0.75
		y = handle * 0.4 + halo * math.sin(angle) * 0.45
	end
	local tilt = math.rad(math.clamp(c.k17 or 20, -60, 60))
	local cx, sx = math.cos(tilt), math.sin(tilt)
	x, y = x * cx - y * sx, x * sx + y * cx
	local ca, sa = math.cos(phase * 0.18), math.sin(phase * 0.18)
	local target = cen + Vector3.new(x * ca - z * sa, y + math.clamp(c.k16 or 220, -100, 600), x * sa + z * ca)
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
	{ Type = "Slider", Name = "Hammer Half Width", Min = 35, Max = 220, Key = "k11", Default = 85 },
	{ Type = "Slider", Name = "Head Thickness", Min = 15, Max = 100, Key = "k12", Default = 42 },
	{ Type = "Slider", Name = "Relic Spin Speed", Min = 0, Max = 40, Key = "k13", Default = 6, ExactMax = true },
	{ Type = "Slider", Name = "Handle Length", Min = 60, Max = 500, Key = "k14", Default = 220 },
	{ Type = "Slider", Name = "Storm Halo Radius", Min = 50, Max = 350, Key = "k15", Default = 125 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 600, Key = "k16", Default = 220 },
	{ Type = "Slider", Name = "Hammer Tilt", Min = -60, Max = 60, Key = "k17", Default = 20 },
}

return M
