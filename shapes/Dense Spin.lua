local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	
	if not d.v1 then
		d.v1 = math.random() * math.pi * 2
		d.v2 = math.random() * math.pi * 2
	end
	
	local speed = c.k11 or 50
	local radius = c.k12 or 2
	
	d.v1 = d.v1 + (speed * 0.05)
	d.v2 = d.v2 + (speed * 0.03)
	
	-- Spherical coordinates for a super dense, rapidly spinning ball
	local tx = math.sin(d.v1) * math.cos(d.v2) * radius
	local ty = math.sin(d.v1) * math.sin(d.v2) * radius
	local tz = math.cos(d.v1) * radius
	
	local target_pos = cen + Vector3.new(tx, ty, tz)
	
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Density Radius", Min = 0, Max = 20, Key = "k12" }
}

return M
