local M = {}

local function random_direction(cut_in_half)
	local direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	if direction.Magnitude < 0.001 then
		direction = Vector3.xAxis
	end
	direction = direction.Unit
	if cut_in_half then
		direction = Vector3.new(direction.X, math.abs(direction.Y), direction.Z).Unit
	end
	return direction
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 150
	local speed = c.k12 or 400
	local redirect_interval = c.k13 or 0.2
	local cut_in_half = c.k18 ~= false
	local offset = p.Position - cen

	if not d.light_direction or t >= (d.light_redirect_at or 0) then
		d.light_direction = random_direction(cut_in_half)
		d.light_redirect_at = t + redirect_interval
	end

	local distance = offset.Magnitude
	if distance >= radius or (cut_in_half and offset.Y < 0) then
		local inward = distance > 0.001 and (-offset.Unit) or random_direction(cut_in_half)
		if cut_in_half and inward.Y < 0 then
			inward = Vector3.new(inward.X, math.abs(inward.Y), inward.Z).Unit
		end
		d.light_direction = inward
		d.light_redirect_at = t + redirect_interval
	else
		local next_offset = offset + d.light_direction * (speed / 60)
		if next_offset.Magnitude >= radius or (cut_in_half and next_offset.Y < 0) then
			local normal = next_offset.Magnitude > 0.001 and next_offset.Unit or Vector3.yAxis
			d.light_direction = (d.light_direction - normal * (2 * d.light_direction:Dot(normal))).Unit
			if cut_in_half and d.light_direction.Y < 0 then
				d.light_direction = Vector3.new(d.light_direction.X, math.abs(d.light_direction.Y), d.light_direction.Z).Unit
			end
			d.light_redirect_at = t + redirect_interval
		end
	end

	return d.light_direction * speed
end

M.Controls = {
	{ Type = "Slider", Name = "Containment Radius", Min = 25, Max = 800, Key = "k11" },
	{ Type = "Slider", Name = "Light Speed", Min = 50, Max = 1000, Key = "k12", ExactMax = true },
	{ Type = "Slider", Name = "Redirect Interval", Min = 5, Max = 100, Key = "k13", Div = 100 },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true }
}

return M