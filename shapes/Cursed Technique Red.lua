local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local dist = wp - cen
	local mag = dist.Magnitude
	
	local power = c.k11 or 1500
	local radius = c.k12 or 80
	
	if not d.v6 then
		d.v6 = math.random() * math.pi * 2
	end
	
	local dir
	if mag < 0.1 then
		dir = Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5).Unit
	else
		dir = dist.Unit
	end
	
	if mag > radius then
		return Vector3.new(0, math.sin(t + d.v6) * 10, 0)
	end
	
	return dir * power
end

M.Controls = {
	{ Type = "Slider", Name = "Repulsion Power", Min = 100, Max = 5000, Key = "k11" },
	{ Type = "Slider", Name = "Blast Radius", Min = 10, Max = 500, Key = "k12" }
}

return M
