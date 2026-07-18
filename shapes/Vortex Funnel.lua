local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Vortex Funnel"
	local s, R_base, R_top, H = (c.k13 or 10) * x9.c2, (c.k11 or 50), (c.k12 or 300), (c.k14 or 400)
			if not d.v4 then
				d.v4 = math.random()
			end
			if not d.v6 then
				d.v6 = math.random() * math.pi * 2
			end
			local current_r = R_base + ((R_top - R_base) * (d.v4 ^ 2))
			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local phase = d.phase + d.v6 + ((1 - d.v4) * (c.k15 or 5) * 5)
			return ((cen + Vector3.new(current_r * math.cos(phase), d.v4 * H - (H / 2), current_r * math.sin(phase))) - wp)
				* (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Swirl Speed", Min = 1, Max = 300, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Base Radius", Min = 10, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Top Radius", Min = 50, Max = 1000, Key = "k12" },
	{ Type = "Slider", Name = "Funnel Height", Min = 50, Max = 1000, Key = "k14" },
	{ Type = "Slider", Name = "Suction Power", Min = 1, Max = 20, Key = "k15" },
	{ Type = "Slider", Name = "Move Area", Min = 50, Max = 1500, Key = "k17" }
}

return M