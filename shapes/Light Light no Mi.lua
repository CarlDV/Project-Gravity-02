local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 150
	local speed = c.k12 or 350
	local beam_spacing = c.k13 or 3
	local cut_in_half = c.k18 ~= false

	local meta = x6.pre["Light Light no Mi"]
	if not meta then
		meta = {
			beam_pos = cen,
			beam_dir = Vector3.new(0.707, 0.3, 0.64).Unit,
			last_t = t
		}
		x6.pre["Light Light no Mi"] = meta
	end

	local delta_t = t - (meta.last_t or t)
	meta.last_t = t
	if delta_t <= 0 or delta_t > 0.1 then
		delta_t = 1 / 60
	end

	meta.beam_pos = meta.beam_pos + meta.beam_dir * (speed * delta_t)

	local rel_pos = meta.beam_pos - cen
	local cur_dist = rel_pos.Magnitude
	if cur_dist >= radius then
		local boundary_norm = rel_pos.Unit
		meta.beam_dir = (meta.beam_dir - boundary_norm * (2 * meta.beam_dir:Dot(boundary_norm))).Unit
		meta.beam_pos = cen + boundary_norm * (radius - 5)
	end

	if cut_in_half and meta.beam_pos.Y < cen.Y then
		meta.beam_dir = Vector3.new(meta.beam_dir.X, math.abs(meta.beam_dir.Y), meta.beam_dir.Z).Unit
		meta.beam_pos = Vector3.new(meta.beam_pos.X, cen.Y + 2, meta.beam_pos.Z)
	end

	local active_cnt = #x6.active_array
	local item_idx = d.id or 1
	local mid_idx = (active_cnt + 1) / 2
	local offset_dist = (item_idx - mid_idx) * beam_spacing

	local target_pos = meta.beam_pos + meta.beam_dir * offset_dist
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Containment Radius", Min = 25, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Light Speed", Min = 50, Max = 1000, Key = "k12", ExactMax = true },
	{ Type = "Slider", Name = "Beam Spacing", Min = 1, Max = 20, Key = "k13" },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true }
}

return M