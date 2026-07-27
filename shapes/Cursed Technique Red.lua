local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local blast_radius = c.k12 or 100
	local radial = wp - cen
	local distance = radial.Magnitude
	if distance >= blast_radius then
		return Vector3.zero, wp
	end
	if distance < 0.001 then
		if not d.red_direction then
			d.red_direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		end
	else
		d.red_direction = radial.Unit
	end

	local edge_pos = cen + d.red_direction * blast_radius
	local edge_delta = edge_pos - wp
	local intensity = 1 + ((blast_radius - distance) / blast_radius) * 4
	return edge_delta * (x1.k10 * x9.c1 * intensity), edge_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Blast Radius", Min = 10, Max = 1000, Key = "k12" }
}

return M
