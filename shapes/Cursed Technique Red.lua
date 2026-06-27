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
		d.start_pos = wp
	end
	
	d.nx = d.nx or math.random() * 1000
	d.ny = d.ny or math.random() * 1000
	d.nz = d.nz or math.random() * 1000
	d.start_pos = d.start_pos or wp
	
	local dir
	if mag < 0.1 then
		dir = Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5).Unit
	else
		dir = dist.Unit
	end
	
	if mag > radius * 0.95 then
		
		local time_scale_slow = t * 0.5
		local time_scale_fast = t * 3.0
		
		local nx = math.noise(d.nx, time_scale_slow, 0)
		local ny = math.noise(d.ny, time_scale_slow, 0)
		local nz = math.noise(d.nz, time_scale_slow, 0)
		local drift = Vector3.new(nx, ny, nz) * 5
		
		local jx = math.noise(d.nx, 0, time_scale_fast)
		local jy = math.noise(d.ny, 0, time_scale_fast)
		local jz = math.noise(d.nz, 0, time_scale_fast)
		local jitter = Vector3.new(jx, jy, jz) * 10
		
		local hover_pull = Vector3.zero
		if not d.blasted and d.start_pos then
			local target_y = d.start_pos.Y + 4
			hover_pull = Vector3.new(0, (target_y - wp.Y) * 3, 0)
		end
		
		return drift + jitter + hover_pull + Vector3.new(0, math.sin(t * 1.5 + d.v6) * 5, 0)
	end
	
	d.blasted = true
	return dir * power
end

M.Controls = {
	{ Type = "Slider", Name = "Repulsion Power", Min = 100, Max = 5000, Key = "k11" },
	{ Type = "Slider", Name = "Blast Radius", Min = 10, Max = 500, Key = "k12" }
}

return M
