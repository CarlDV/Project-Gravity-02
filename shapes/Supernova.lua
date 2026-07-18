local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Supernova"
	local ExpandingRad, MaxSize, s = (c.k11 or 15), (c.k12 or 100), (c.k13 or 25) * x9.c2
			if not d.v1 then
				d.v1 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
			end
			if not d.v2 then
				d.v2 = math.random()
			end
			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local cycle = d.phase % math.pi
			local burst = math.sin(cycle)

			local core_jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
			local shockwave = d.v1 * (burst * MaxSize * d.v2)
			local current_pos = (burst > 0.1) and shockwave or (d.v1 * ExpandingRad + core_jitter)

			local target_pos = cen + current_pos
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Core Radius", Min = 5, Max = 100, Key = "k11" },
	{ Type = "Slider", Name = "Blast Radius", Min = 50, Max = 800, Key = "k12" },
	{ Type = "Slider", Name = "Pulse Speed", Min = 1, Max = 200, Key = "k13", Div = 10 }
}

return M