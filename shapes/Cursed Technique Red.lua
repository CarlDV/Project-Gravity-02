local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local dist = wp - cen
	local mag = dist.Magnitude
	
	local power = c.k11 or 1500
	local radius = c.k12 or 80
	
	if not d.v6 then
		d.v6 = math.random() * math.pi * 2
		d.nx = math.random() * 1000
		d.ny = math.random() * 1000
		d.nz = math.random() * 1000
	end
	
	d.nx = d.nx or math.random() * 1000
	d.ny = d.ny or math.random() * 1000
	d.nz = d.nz or math.random() * 1000
	
	local dir
	if mag < 0.1 then
		dir = Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5).Unit
	else
		dir = dist.Unit
	end
	
	if mag > radius * 0.95 then
		local hover_y = math.sin(t * 2.0 + d.v6) * 20
		
		local hover_x = math.sin(t * 1.2 + d.nx) * 8
		local hover_z = math.cos(t * 1.3 + d.nz) * 8
		
		return Vector3.new(hover_x, hover_y, hover_z)
	end
	
	return dir * power
end

M.Controls = {
	{ Type = "Slider", Name = "Repulsion Power", Min = 100, Max = 5000, Key = "k11" },
	{ Type = "Slider", Name = "Blast Radius", Min = 10, Max = 500, Key = "k12" }
}

return M
