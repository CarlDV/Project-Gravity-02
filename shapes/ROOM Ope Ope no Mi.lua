local M = {}

local function shuffle(values)
	for index = #values, 2, -1 do
		local swap_index = math.random(index)
		values[index], values[swap_index] = values[swap_index], values[index]
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 150
	local swap_interval = c.k12 or 2
	local orbit_speed = c.k13 or 1.5
	local swap_force = c.k14 or 20
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
		local phases = {}
		local affected = {}
		for _, part in ipairs(x6.active_array) do
			local part_data = x6.a[part]
			if part_data and part.Parent then
				table.insert(affected, part_data)
				table.insert(phases, part_data.room_orbit_phase or ((part_data.id * 2.399963229728653) % (math.pi * 2)))
			end
		end
		shuffle(phases)
		for index, part_data in ipairs(affected) do
			part_data.room_orbit_phase = phases[index]
		end
	end

	local angle = t * orbit_speed + d.room_orbit_phase
	local height = math.sin(angle * 0.5) * (radius * 0.35)
	if c.k18 ~= false then
		height = math.abs(height)
	end
	local target_pos = cen + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	return (target_pos - p.Position) * swap_force, target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "ROOM Radius", Min = 25, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Shambles Interval", Min = 5, Max = 100, Key = "k12", Div = 10 },
	{ Type = "Slider", Name = "Orbit Speed", Min = 1, Max = 50, Key = "k13", Div = 10, ExactMax = true },
	{ Type = "Slider", Name = "Swap Force", Min = 5, Max = 50, Key = "k14" },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true }
}

return M