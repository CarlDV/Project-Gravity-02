local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 150
	local speed = c.k12 or 350
	local spacing = c.k13 or 3
	local cut_in_half = c.k18 ~= false

	local active_items = x6.active_array
	local total_cnt = #active_items
	if total_cnt == 0 then
		return Vector3.zero, cen
	end

	local item_idx = d.id or 1
	local slot_idx = item_idx % total_cnt
	local frac = (slot_idx + 0.5) / total_cnt

	local y_val, r_scale
	if cut_in_half then
		y_val = frac * 0.96 + 0.02
		r_scale = math.sqrt(math.max(0.001, 1 - y_val * y_val))
	else
		y_val = 1 - 2 * frac
		r_scale = math.sqrt(math.max(0.001, 1 - y_val * y_val))
	end

	local golden_angle = 2.399963229728653
	local base_angle = (slot_idx * golden_angle) + (t * (speed * 0.002))

	local dir = Vector3.new(
		r_scale * math.cos(base_angle),
		y_val,
		r_scale * math.sin(base_angle)
	).Unit

	local wave = math.sin(t * (speed * 0.01) + (slot_idx * 0.5))
	local rad_dist = radius * (0.3 + 0.7 * math.abs(wave))

	local beam_group = math.floor(slot_idx / math.max(1, spacing))
	local group_offset = math.sin((t * 3) + beam_group) * (spacing * 1.5)

	local target_pos = cen + (dir * rad_dist) + Vector3.new(0, group_offset * 0.2, 0)

	if cut_in_half and target_pos.Y < cen.Y then
		target_pos = Vector3.new(target_pos.X, cen.Y + math.abs(target_pos.Y - cen.Y), target_pos.Z)
	end

	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Containment Radius", Min = 25, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Light Speed", Min = 50, Max = 1000, Key = "k12", ExactMax = true },
	{ Type = "Slider", Name = "Beam Spacing", Min = 1, Max = 20, Key = "k13" },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true }
}

return M