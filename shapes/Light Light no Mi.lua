local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 150
	local speed = c.k12 or 350
	local orbit_speed = (c.k13 or 15) / 10
	local cut_in_half = c.k18 ~= false

	if not d.orb_phase then
		d.orb_phase = (d.id * 2.399963229728653) % (math.pi * 2)
		d.beam_state = 0
		d.next_shift = t + (d.id % 7) * 0.4 + 1.2
	end

	if d.beam_state == 0 then
		local orb_angle = t * orbit_speed + d.orb_phase
		local height_val = math.sin(orb_angle * 0.8) * (radius * 0.35)
		if cut_in_half then
			height_val = math.abs(height_val)
		end
		local orb_target = cen + Vector3.new(math.cos(orb_angle) * radius, height_val, math.sin(orb_angle) * radius)

		if t >= (d.next_shift or 0) then
			d.beam_state = 1
			d.beam_pos = p.Position
			local initial_dir = (cen - p.Position)
			if initial_dir.Magnitude < 0.001 then
				initial_dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
			end
			d.beam_dir = initial_dir.Unit
			d.beam_end = t + 2.2 + (d.id % 4) * 0.5
			d.last_t = t
		end

		return (orb_target - p.Position) * (x1.k10 * x9.c1), orb_target
	else
		local delta_t = t - (d.last_t or t)
		d.last_t = t
		if delta_t <= 0 or delta_t > 0.1 then
			delta_t = 1 / 60
		end

		d.beam_pos = d.beam_pos + d.beam_dir * (speed * delta_t)

		local rel_pos = d.beam_pos - cen
		local cur_dist = rel_pos.Magnitude
		if cur_dist >= radius then
			local boundary_norm = rel_pos.Unit
			d.beam_dir = (d.beam_dir - boundary_norm * (2 * d.beam_dir:Dot(boundary_norm))).Unit
			d.beam_pos = cen + boundary_norm * (radius - 1)
		end

		if cut_in_half and d.beam_pos.Y < cen.Y then
			d.beam_dir = Vector3.new(d.beam_dir.X, math.abs(d.beam_dir.Y), d.beam_dir.Z).Unit
			d.beam_pos = Vector3.new(d.beam_pos.X, cen.Y + 1, d.beam_pos.Z)
		end

		if t >= d.beam_end then
			d.beam_state = 0
			d.next_shift = t + 2.5 + (d.id % 5) * 0.6
		end

		return (d.beam_pos - p.Position) * (x1.k10 * x9.c1), d.beam_pos
	end
end

M.Controls = {
	{ Type = "Slider", Name = "Containment Radius", Min = 25, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Light Speed", Min = 50, Max = 1000, Key = "k12", ExactMax = true },
	{ Type = "Slider", Name = "Orbit Speed", Min = 1, Max = 50, Key = "k13", Div = 10, ExactMax = true },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true }
}

return M