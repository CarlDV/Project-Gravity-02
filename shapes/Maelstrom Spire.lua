local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Maelstrom Spire"
	local BaseR, H, s, Jets = (c.k11 or 30), (c.k12 or 200), (c.k13 or 15) * x9.c2, (c.k14 or 6)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.25 then
					d.v1 = 1
				elseif roll < 0.50 then
					d.v1 = 2
				elseif roll < 0.70 then
					d.v1 = 3
				elseif roll < 0.92 then
					d.v1 = 4
				else
					d.v1 = 5
				end
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random()
			end
			if not d.v4 then
				d.v4 = math.random() * math.pi * 2
			end

			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local phase = d.phase
			local tx, ty, tz = 0, 0, 0
			local TopR = BaseR * 4

			if d.v1 == 1 then

				local spiral_a = d.v2 + phase * 2
				local spiral_r = BaseR * 0.5 + d.v3 * TopR * 1.2
				local log_r = spiral_r * (1 + math.log(1 + d.v3 * 2))
				tx = log_r * math.cos(spiral_a)
				tz = log_r * math.sin(spiral_a)
				ty = -5 + math.sin(spiral_a * 3) * 3
			elseif d.v1 == 2 then

				local prog = d.v3
				local funnel_r = TopR * (1 - prog * 0.8)
				local angular_speed = 1 + prog * 3
				local funnel_phase = d.v2 + phase * angular_speed
				tx = funnel_r * math.cos(funnel_phase)
				tz = funnel_r * math.sin(funnel_phase)
				ty = prog * H
			elseif d.v1 == 3 then

				local jet_idx = math.floor(d.v2 / (math.pi * 2) * Jets)
				local jet_angle = (jet_idx / Jets) * math.pi * 2 + phase * 0.3
				local jet_dist = d.v3 * TopR * 2
				local wobble = math.sin(phase * 3 + jet_idx * 1.5) * 10
				tx = jet_dist * math.cos(jet_angle + wobble * 0.02)
				tz = jet_dist * math.sin(jet_angle + wobble * 0.02)
				ty = H + wobble + math.sin(d.v4 + phase) * 5
			elseif d.v1 == 4 then

				local arc_prog = (d.v3 + phase * 0.5) % 1
				local arc_angle = d.v2 + phase * 0.2
				local arc_r = TopR * 1.5 + arc_prog * TopR * 0.5
				local arc_y = H * (1 - 4 * (arc_prog - 0.5) * (arc_prog - 0.5))
				tx = arc_r * math.cos(arc_angle)
				tz = arc_r * math.sin(arc_angle)
				ty = arc_y
			else

				local eye_r = 5 + math.sin(phase * 0.5 + d.v2) * 2
				tx = eye_r * math.cos(d.v2 + phase * 0.1)
				tz = eye_r * math.sin(d.v2 + phase * 0.1)
				ty = H + math.sin(phase + d.v3 * math.pi) * 2
			end
			local target_pos = cen + Vector3.new(tx, ty, tz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Base Radius", Min = 10, Max = 150, Key = "k11" },
	{ Type = "Slider", Name = "Tower Height", Min = 50, Max = 500, Key = "k12" },
	{ Type = "Slider", Name = "Vortex Speed", Min = 1, Max = 50, Key = "k13" },
	{ Type = "Slider", Name = "Jet Count", Min = 3, Max = 12, Key = "k14", IntOnly = true }
}

return M