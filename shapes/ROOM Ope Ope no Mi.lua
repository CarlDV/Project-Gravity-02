local M = {}

local function shuffle(values)
	for index = #values, 2, -1 do
		local swap_index = math.random(index)
		values[index], values[swap_index] = values[swap_index], values[index]
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 300
	local swap_interval = c.k12 or 1.5
	local meta = x6.pre["ROOM Ope Ope no Mi"]
	if not meta then
		meta = { next_swap = t }
		x6.pre["ROOM Ope Ope no Mi"] = meta
	end

	if t >= meta.next_swap then
		meta.next_swap = t + swap_interval
		local positions = {}
		local affected = {}
		for _, part in ipairs(x6.active_array) do
			local part_data = x6.a[part]
			if part_data and part.Parent and (part.Position - cen).Magnitude <= radius then
				table.insert(positions, part.Position)
				table.insert(affected, part_data)
			end
		end
		shuffle(positions)
		for index, part_data in ipairs(affected) do
			part_data.room_target = positions[index]
		end
	end

	local wp = p.Position
	if (wp - cen).Magnitude > radius then
		return Vector3.zero, wp
	end
	local target_pos = d.room_target or wp
	return (target_pos - wp) * (c.k13 or 35), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "ROOM Radius", Min = 50, Max = 1500, Key = "k11" },
	{ Type = "Slider", Name = "Shambles Interval", Min = 1, Max = 100, Key = "k12", Div = 10 },
	{ Type = "Slider", Name = "Swap Force", Min = 5, Max = 100, Key = "k13" }
}

return M