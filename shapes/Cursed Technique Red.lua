local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local radius = c.k12 or 80

	local distance = (wp - cen).Magnitude
	local mode = distance > radius and "outer" or "inner"
	if d.cursed_hover_mode ~= mode then
		d.cursed_hover_mode = mode
		d.hover_anchor = mode == "outer" and (wp + Vector3.new(0, 20, 0)) or wp
		d.v6 = math.random() * math.pi * 2
	end
	if not d.hover_anchor then
		d.hover_anchor = mode == "outer" and (wp + Vector3.new(0, 20, 0)) or wp
	end
	if not d.v6 then
		d.v6 = math.random() * math.pi * 2
	end

	local phase = t * 1.5 + d.v6
	local hover = Vector3.new(
		math.sin(phase * 0.7) * 0.6,
		math.sin(phase) * 1.5,
		math.cos(phase * 0.8) * 0.6
	)
	local target_pos = d.hover_anchor + hover
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Trigger Radius", Min = 10, Max = 1000, Key = "k12" }
}

return M
