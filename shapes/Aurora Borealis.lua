local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Aurora Borealis"
	local Span, Height, s, RibbonWidth = (c.k11 or 600), (c.k12 or 300), (c.k13 or 15) * x9.c2, (c.k14 or 100)
			if not d.v1 then
				d.v1 = (math.random() - 0.5) * 2
			end
			if not d.v2 then
				d.v2 = math.random()
			end
			if not d.v3 then
				d.v3 = math.random() * math.pi * 2
			end

			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local phase = d.phase


			local x_pos = d.v1 * (Span * 0.5)


			local fold_1 = math.sin((x_pos / 100) + phase) * (Span * 0.1)
			local fold_2 = math.sin((x_pos / 50) - phase * 1.5) * (Span * 0.05)
			local z_pos = fold_1 + fold_2


			z_pos = z_pos + math.pow(d.v1, 2) * (Span * 0.2)


			local y_pos = Height + (d.v2 * RibbonWidth)

			y_pos = y_pos + math.sin((x_pos / 100) + phase * 2 + d.v3) * (RibbonWidth * 0.5)

			local target_pos = cen + Vector3.new(x_pos, y_pos, z_pos)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Sky Span", Min = 100, Max = 2000, Key = "k11" },
	{ Type = "Slider", Name = "Sky Height", Min = 50, Max = 1500, Key = "k12" },
	{ Type = "Slider", Name = "Flow Speed", Min = 1, Max = 100, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Band Width", Min = 50, Max = 500, Key = "k14" }
}

return M