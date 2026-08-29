local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 150
	local swap_interval = (c.k12 or 20) / 10
	local orbit_speed = c.k13 or 1.5
	local cut_in_half = c.k18 ~= false

	local meta = x6.pre["ROOM Ope Ope no Mi"]
	if not meta then
		meta = { next_swap = t + swap_interval }
		x6.pre["ROOM Ope Ope no Mi"] = meta
	end

	local active_items = x6.active_array
	local total_cnt = #active_items
	if total_cnt == 0 then
		return Vector3.zero, cen
	end

	if not d.room_slot then
		d.room_slot = d.id or 1
	end

	if t >= meta.next_swap then
		meta.next_swap = t + swap_interval
		if total_cnt >= 2 then
			local num_swaps = math.clamp(math.floor(total_cnt * 0.25), 2, 6)
			num_swaps = math.min(num_swaps, total_cnt)
			local chosen = {}
			for _ = 1, num_swaps do
				local idx = math.random(1, total_cnt)
				local part = active_items[idx]
				local part_data = x6.a[part]
				if part_data then
					table.insert(chosen, part_data)
				end
			end
			if #chosen >= 2 then
				local first_slot = chosen[1].room_slot or 1
				for i = 1, #chosen - 1 do
					chosen[i].room_slot = chosen[i + 1].room_slot or (i + 1)
				end
				chosen[#chosen].room_slot = first_slot
			end
		end
	end

	local slot_idx = (d.room_slot or 1) % total_cnt
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
	local cur_angle = (slot_idx * golden_angle) + (t * orbit_speed)

	local offset = Vector3.new(
		r_scale * math.cos(cur_angle) * radius,
		y_val * radius,
		r_scale * math.sin(cur_angle) * radius
	)

	local target_pos = cen + offset
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "ROOM Radius", Min = 25, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Shambles Interval", Min = 5, Max = 100, Key = "k12", Div = 10 },
	{ Type = "Slider", Name = "Orbit Speed", Min = 1, Max = 50, Key = "k13", Div = 10, ExactMax = true },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true }
}

-- next_swap lives in x6.pre and time() keeps advancing while another shape is
-- selected, so a stale meta triggers an immediate swap burst on return.
function M.cleanup(x6, x1)
	if not x6.pre then
		return
	end
	x6.pre["ROOM Ope Ope no Mi"] = nil
end

return M