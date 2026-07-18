local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Seraphim"
	local R, RingCount, s, Wingspan = (c.k11 or 80), (c.k12 or 4), (c.k13 or 15) * x9.c2, (c.k14 or 40)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.2 then
					d.v1 = 0
				elseif roll < 0.6 then
					d.v1 = math.random(1, RingCount)
				else
					d.v1 = -1
				end
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end

			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local phase = d.phase
			local tx, ty, tz = 0, 0, 0

			if d.v1 == 0 then

				local eye_phase = d.v2 + phase * 4
				tx = 5 * math.cos(eye_phase)
				ty = 10 * math.sin(eye_phase)
				tz = 0
			elseif d.v1 > 0 then

				local ring_idx = d.v1
				local ring_phase = d.v2 + (phase * (1 + ring_idx * 0.2))
				local tilt_x = (ring_idx / RingCount) * math.pi
				local tilt_z = phase * 0.5 + ring_idx


				local bx = R * math.cos(ring_phase)
				local by = 0
				local bz = R * math.sin(ring_phase)


				local cx, sx = math.cos(tilt_x), math.sin(tilt_x)
				local cz, sz = math.cos(tilt_z), math.sin(tilt_z)


				local rx1 = bx
				local ry1 = by * cx - bz * sx
				local rz1 = by * sx + bz * cx


				tx = rx1 * cz - ry1 * sz
				ty = rx1 * sz + ry1 * cz
				tz = rz1
			else

				local wing_side = (d.v2 % 2 > 1) and 1 or -1
				local wing_pos = (d.v2 / (math.pi * 2))
				local wing_w = wing_pos * Wingspan * 2

				local wing_flap = math.sin(phase * 2) * 15 * wing_pos

				tx = wing_w * wing_side
				ty = wing_flap + math.abs(wing_side * wing_w * 0.5)
				tz = -20 - (wing_pos * 30)
			end
			local target_pos = cen + Vector3.new(tx, ty, tz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 20, Max = 200, Key = "k11" },
	{ Type = "Slider", Name = "Ring Count", Min = 1, Max = 10, Key = "k12", IntOnly = true },
	{ Type = "Slider", Name = "Speed", Min = 1, Max = 100, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Wingspan", Min = 10, Max = 150, Key = "k14" }
}



return M
