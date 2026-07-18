local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Alien Mothership"
	local Radius, CoreHeight, s, BeamLen = (c.k11 or 120), (c.k12 or 40), (c.k13 or 15) * x9.c2, (c.k14 or 200)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.6 then
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

			if d.v1 == 1 then

				local r = Radius * math.sqrt(d.v3)
				local y_curve = math.sin(math.acos(d.v3)) * CoreHeight
				if d.v2 > math.pi then
					y_curve = -y_curve
				end

				local rot = d.v4 + phase
				tx = r * math.cos(rot)
				tz = r * math.sin(rot)
				ty = y_curve
			elseif d.v1 == 2 then

				local beam_prog = (d.v3 + phase * 2) % 1
				ty = -CoreHeight - (beam_prog * BeamLen)
				local beam_rad = 10 + (beam_prog * Radius * 0.4)
				local rot = d.v2 + phase * 3
				tx = beam_rad * math.cos(rot)
				tz = beam_rad * math.sin(rot)
			else

				local group = math.floor(d.v3 * 3)
				local orbit_phase = phase * 0.5 + (group * math.pi * 2 / 3)
				local orbit_r = Radius * 1.5
				local cx = orbit_r * math.cos(orbit_phase)
				local cz = orbit_r * math.sin(orbit_phase)
				local cy = math.sin(phase * 2 + group) * 20

				local local_rot = d.v4 + phase * 5
				local local_r = math.random() * 10
				tx = cx + local_r * math.cos(local_rot)
				tz = cz + local_r * math.sin(local_rot)
				ty = cy + (math.random() - 0.5) * 5
			end

			local target_pos = cen + Vector3.new(tx, ty, tz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 50, Max = 400, Key = "k11" },
	{ Type = "Slider", Name = "Core Height", Min = 10, Max = 150, Key = "k12" },
	{ Type = "Slider", Name = "Speed", Min = 1, Max = 100, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Beam Length", Min = 50, Max = 500, Key = "k14" }
}

return M