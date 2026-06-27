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
		local time_scale = t * 0.3
		local nx = math.noise(d.nx, time_scale, 0)
		local ny = math.noise(d.ny, time_scale, 0)
		local nz = math.noise(d.nz, time_scale, 0)
		
		local drift = Vector3.new(nx, ny, nz) * 8
		
		local tangent = dir:Cross(Vector3.new(0, 1, 0))
		if tangent.Magnitude < 0.001 then
			tangent = Vector3.new(1, 0, 0)
		end
		local swirl = tangent.Unit * 15
		
		local target_pos = cen + (dir * radius)
		
		if target_pos.Y < cen.Y + 2 then
			target_pos = Vector3.new(target_pos.X, cen.Y + 2, target_pos.Z)
		end
		
		local pull = (target_pos - wp) * 4
		
		local equator_push = Vector3.zero
		if wp.Y < cen.Y + 1 then
			equator_push = Vector3.new(0, (cen.Y + 1 - wp.Y) * 10, 0)
		end
		
		return pull + drift + swirl + equator_push + Vector3.new(0, math.sin(t * 1.2 + d.v6) * 10, 0)
	end
	
	return dir * power
end

M.Controls = {
	{ Type = "Slider", Name = "Repulsion Power", Min = 100, Max = 5000, Key = "k11" },
	{ Type = "Slider", Name = "Blast Radius", Min = 10, Max = 500, Key = "k12" }
}

return M
