local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 150
	local swap_interval = (c.k12 or 20) / 10
	local orbit_speed = (c.k13 or 15) / 10
	local cut_in_half = c.k18 ~= false

	local meta = x6.pre["ROOM Ope Ope no Mi"]
	if not meta then
		meta = { next_swap = t + swap_interval }
		x6.pre["ROOM Ope Ope no Mi"] = meta
	end

	if not d.room_orbit_phase then
		d.room_orbit_phase = (d.id * 2.399963229728653) % (math.pi * 2)
	end

	if t >= meta.next_swap then
		meta.next_swap = t + swap_interval
		local active_items = {}
		for _, part in ipairs(x6.active_array) do
			local part_data = x6.a[part]
			if part_data and part.Parent then
				table.insert(active_items, part_data)
			end
		end

		local total_cnt = #active_items
		if total_cnt >= 2 then
			local num_swaps = math.clamp(math.floor(total_cnt * 0.2), 2, 4)
			num_swaps = math.min(num_swaps, total_cnt)

			local chosen_indices = {}
			while #chosen_indices < num_swaps do
				local idx = math.random(1, total_cnt)
				local exists = false
				for _, prev in ipairs(chosen_indices) do
					if prev == idx then
						exists = true
						break
					end
				end
				if not exists then
					table.insert(chosen_indices, idx)
				end
			end

			local first_phase = active_items[chosen_indices[1]].room_orbit_phase or 0
			for i = 1, #chosen_indices - 1 do
				local curr_idx = chosen_indices[i]
				local next_idx = chosen_indices[i + 1]
				active_items[curr_idx].room_orbit_phase = active_items[next_idx].room_orbit_phase or 0
			end
			active_items[chosen_indices[#chosen_indices]].room_orbit_phase = first_phase
		end
	end

	local cur_angle = t * orbit_speed + d.room_orbit_phase
	local height_offset = math.sin(cur_angle * 0.5) * (radius * 0.35)
	if cut_in_half then
		height_offset = math.abs(height_offset)
	end

	local target_pos = cen + Vector3.new(math.cos(cur_angle) * radius, height_offset, math.sin(cur_angle) * radius)
	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "ROOM Radius", Min = 25, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Shambles Interval", Min = 5, Max = 100, Key = "k12", Div = 10 },
	{ Type = "Slider", Name = "Orbit Speed", Min = 1, Max = 50, Key = "k13", Div = 10, ExactMax = true },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true }
}

return M