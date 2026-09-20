local M = {}
M.ContinuousMotion = true
local NAME = "Hopf Fibration"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

local function fibre(index, count, phase, c)
	local longitude = index * TAU / count
	local spread = math.clamp(c.k14 or 55, 10, 100) / 100
	local eta = 0.24 + 0.65 * spread + 0.045 * math.sin(longitude * 2)
	local ce, se = math.cos(eta), math.sin(eta)
	local cp, sp = math.cos(longitude), math.sin(longitude)
	-- q(theta) = a*cos(theta) + b*sin(theta) is a unit great circle on S^3.
	-- These are the fibres (z1,z2) = (cos(eta), sin(eta)*e^i*longitude)*e^i*theta.
	local ax, ay, az, aw = ce, 0, se * cp, se * sp
	local bx, by, bz, bw = 0, ce, -se * sp, se * cp
	local beta = 0.16 * math.clamp(c.k15 or 35, 0, 100) / 100 * math.sin(phase * 0.37)
	local cb, sb = math.cos(beta), math.sin(beta)
	ax, aw = ax * cb - aw * sb, ax * sb + aw * cb
	bx, bw = bx * cb - bw * sb, bx * sb + bw * cb
	-- eta + |beta| <= 1.095 < pi/2: no fibre can hit the projection pole.
	-- Stereographic projection preserves circles and their linking. Recover the
	-- exact 3D circle so slots move at constant arc speed, not at the wildly
	-- uneven speed of the original 4D angular parameter near the pole.
	local a, b = Vector3.new(ax, ay, az), Vector3.new(bx, by, bz)
	local den = 1 - aw * aw - bw * bw
	local center = (a * aw + b * bw) / den
	local normal = a:Cross(b).Unit
	local first = (a / (1 - aw) - center).Unit
	local second = normal:Cross(first).Unit
	return { center = center, first = first, second = second, normal = normal, radius = 1 / math.sqrt(den) }
end

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t, fibres = {} }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 6, 0, 40) * x9.c2
	st.t = t
	local count = math.clamp(math.floor(c.k12 or 8), 4, 64)
	for i = 1, count do st.fibres[i] = fibre(i - 1, count, st.phase, c) end
	for i = count + 1, #st.fibres do st.fibres[i] = nil end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local count = math.clamp(math.floor(c.k12 or 8), 4, 64)
	local index = (id - 1) % count
	local localId = math.floor((id - 1) / count) + 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local ring = st and st.fibres[index + 1] or fibre(index, count, phase, c)
	local angle = ((localId * PHI + index * 0.3819660112501051) % 1) * TAU + phase
	local radial = ring.first * math.cos(angle) + ring.second * math.sin(angle)
	local scale = math.clamp(c.k11 or 85, 20, 250)
	local thickness = math.clamp(c.k16 or 1.5, 0, 6)
	local cross = ((id * 0.8191725133961645) % 1) * TAU
	local point = (ring.center + radial * ring.radius) * scale
		+ radial * (thickness * math.cos(cross)) + ring.normal * (thickness * math.sin(cross))
	local tilt = math.rad(math.clamp(c.k18 or 25, 0, 70))
	local ct, sn = math.cos(tilt), math.sin(tilt)
	local y, z = point.Y * ct - point.Z * sn, point.Y * sn + point.Z * ct
	local turn = phase * 0.12
	ct, sn = math.cos(turn), math.sin(turn)
	local target = cen + Vector3.new(point.X * ct - z * sn, y + math.clamp(c.k17 or 210, -100, 600), point.X * sn + z * ct)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k17 or 210, 0)
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
	{ Type = "Slider", Name = "Fibration Scale", Min = 20, Max = 250, Key = "k11", Default = 85 },
	{ Type = "Slider", Name = "Linked Circles", Min = 4, Max = 64, Key = "k12", Default = 8, IntOnly = true },
	{ Type = "Slider", Name = "Flow Speed", Min = 0, Max = 40, Key = "k13", Default = 6, ExactMax = true },
	{ Type = "Slider", Name = "Bundle Spread %", Min = 10, Max = 100, Key = "k14", Default = 55, IntOnly = true },
	{ Type = "Slider", Name = "4D Wobble %", Min = 0, Max = 100, Key = "k15", Default = 35, IntOnly = true },
	{ Type = "Slider", Name = "Filament Radius", Min = 0, Max = 60, Key = "k16", Default = 1.5, Div = 10 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 600, Key = "k17", Default = 210 },
	{ Type = "Slider", Name = "Bundle Tilt", Min = 0, Max = 70, Key = "k18", Default = 25 },
}

return M
