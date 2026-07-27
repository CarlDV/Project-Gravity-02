local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local radius = c.k12 or 80

	if not d.hit_wall then
		if (wp - cen).Magnitude > radius then
			return p.AssemblyLinearVelocity, nil, true
		end
		d.hit_wall = true
		d.v4 = wp
		d.v6 = math.random() * math.pi * 2
	end

	local phase = t * 1.5 + d.v6
	local hover = Vector3.new(
		math.sin(phase * 0.7) * 0.6,
		math.sin(phase) * 1.5,
		math.cos(phase * 0.8) * 0.6
	)
	local target_pos = d.v4 + hover
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Trigger Radius", Min = 10, Max = 1000, Key = "k12" }
}

return M
