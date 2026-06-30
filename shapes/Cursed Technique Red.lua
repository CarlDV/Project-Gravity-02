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
	
	local dir
	if mag < 0.1 then
		dir = Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5).Unit
	else
		dir = dist.Unit
	end
	
	if mag >= radius then
		if not d.hit_wall then
			d.hit_wall = true
			d.vl = Vector3.zero
			p.AssemblyLinearVelocity = Vector3.zero
		end
		
		local hover_y = math.sin(t * 25 + d.v6) * 4
		local hover_x = math.sin(t * 22 + d.nx) * 4
		local hover_z = math.cos(t * 28 + d.nz) * 4
		
		local outward_pressure = dir * (power * 0.01)
		
		return Vector3.new(hover_x, hover_y, hover_z) + outward_pressure
	else
		d.hit_wall = false
		return dir * (power * 3)
	end
end

M.Controls = {
	{ Type = "Slider", Name = "Repulsion Power", Min = 100, Max = 15000, Key = "k11" },
	{ Type = "Slider", Name = "Blast Radius", Min = 10, Max = 1000, Key = "k12" }
}

return M
