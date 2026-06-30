local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Pulsar Vortex"
	local Spread, Speed, Torsion = (c.k11 or 200), (c.k12 or 8) * x9.c2, (c.k13 or 10)
	
	if not d.v1 then
		d.v1 = math.random() * math.pi * 2
	end
	if not d.v2 then
		d.v2 = math.random()
	end
	if not d.v3 then
		d.v3 = math.random() * math.pi
	end
	if not d.v4 then
		d.v4 = math.random() * math.pi * 2
	end

	local phase = t * Speed + d.v4
	local r = Spread * d.v2 * (0.6 + 0.4 * math.sin(phase * 0.5))

	local px = r * math.sin(d.v3) * math.cos(d.v1)
	local py = r * math.cos(d.v3)
	local pz = r * math.sin(d.v3) * math.sin(d.v1)

	local drift_x = math.sin(t * 1.2 + d.v2 * 15) * (Spread * 0.15)
	local drift_y = math.cos(t * 1.5 + d.v3 * 15) * (Spread * 0.15)
	local drift_z = math.sin(t * 0.9 + d.v1 * 15) * (Spread * 0.15)
	
	px = px + drift_x
	py = py + drift_y
	pz = pz + drift_z

	local horizontal_dist = math.sqrt(px^2 + pz^2)
	local twist = (horizontal_dist / Spread) * Torsion + t * 1.5
	
	local nx = px * math.cos(twist) - pz * math.sin(twist)
	local nz = px * math.sin(twist) + pz * math.cos(twist)
	px, pz = nx, nz

	local tumble = t * 0.3
	local ty = py * math.cos(tumble) - pz * math.sin(tumble)
	local tz = py * math.sin(tumble) + pz * math.cos(tumble)
	py, pz = ty, tz

	local final_y = py
	if c.k23 then
		final_y = math.abs(final_y)
	end

	return ((cen + Vector3.new(px, final_y, pz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Spread", Min = 50, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Speed", Min = 1, Max = 30, Key = "k12" },
	{ Type = "Slider", Name = "Torsion Twist", Min = 1, Max = 50, Key = "k13" },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k23" }
}

return M
