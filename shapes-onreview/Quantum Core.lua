local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Quantum Core"
	local R, RingThickness, s, ParticleSpeed = (c.k11 or 100), (c.k12 or 30), (c.k13 or 40) * x9.c2, (c.k14 or 50)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.4 then
					d.v1 = 1
				elseif roll < 0.8 then
					d.v1 = 2
				else
					d.v1 = 3
				end
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random() * math.pi * 2
			end
			if not d.v4 then
				d.v4 = (math.random() - 0.5) * 2
			end

			local phase = t * s
			local tx, ty, tz = 0, 0, 0

			if d.v1 == 1 then
				local ring_phase = d.v2 + phase
				local torus_x = (R + RingThickness * math.cos(d.v3)) * math.cos(ring_phase)
				local torus_z = (R + RingThickness * math.cos(d.v3)) * math.sin(ring_phase)
				local torus_y = RingThickness * math.sin(d.v3)

				tx, ty, tz = torus_x, torus_y, torus_z
			elseif d.v1 == 2 then
				local ring_phase = d.v2 + phase * 1.1
				local torus_x = (R + RingThickness * math.cos(d.v3)) * math.cos(ring_phase)
				local torus_y = (R + RingThickness * math.cos(d.v3)) * math.sin(ring_phase)
				local torus_z = RingThickness * math.sin(d.v3)

				tx, ty, tz = torus_x, torus_y, torus_z
			else

				local spd = ParticleSpeed * 0.1
				local dist = (math.sin(t * spd + d.v2) * 0.5 + 0.5) * (R * 0.8)
				local phi = d.v3 + phase * 3 * d.v4
				local theta = d.v2 + phase * 4 * d.v4

				tx = dist * math.sin(phi) * math.cos(theta)
				ty = dist * math.cos(phi)
				tz = dist * math.sin(phi) * math.sin(theta)
			end

			return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Ring Radius", Min = 50, Max = 400, Key = "k11" },
	{ Type = "Slider", Name = "Ring Thickness", Min = 10, Max = 100, Key = "k12" },
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 200, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Core Volatility", Min = 10, Max = 200, Key = "k14" }
}

return M