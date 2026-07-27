local M = {}

local function random_direction()
	local direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	return direction.Magnitude > 0.001 and direction.Unit or Vector3.xAxis
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local radius = c.k11 or 300
	local speed = c.k12 or 12000
	local redirect_interval = c.k13 or 0.12
	local offset = p.Position - cen

	if not d.pika_direction or t >= (d.pika_redirect_at or 0) then
		d.pika_direction = random_direction()
		d.pika_redirect_at = t + redirect_interval
	end

	local distance = offset.Magnitude
	if distance >= radius then
		d.pika_direction = distance > 0.001 and (-offset.Unit) or random_direction()
		d.pika_redirect_at = t + redirect_interval
	else
		local next_offset = offset + d.pika_direction * (speed / 60)
		if next_offset.Magnitude >= radius then
			local normal = next_offset.Unit
			d.pika_direction = (d.pika_direction - normal * (2 * d.pika_direction:Dot(normal))).Unit
			d.pika_redirect_at = t + redirect_interval
		end
	end

	local velocity = d.pika_direction * speed
	return velocity
end

M.Controls = {
	{ Type = "Slider", Name = "Containment Radius", Min = 50, Max = 1500, Key = "k11" },
	{ Type = "Slider", Name = "Light Speed", Min = 1000, Max = 15000, Key = "k12" },
	{ Type = "Slider", Name = "Redirect Interval", Min = 1, Max = 50, Key = "k13", Div = 100 }
}

return M