local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Halo Ring"
	local s, R, H = (c.k13 or 5) * x9.c2, (c.k11 or 40), (c.k14 or 80)
			if not d.v6 then
				d.v6 = math.random() * math.pi * 2
			end
			return ((cen + Vector3.new((function() local dt = t - (d.last_t or t); d.last_t = t; d.phase = (d.phase or 0) + (dt * s); return math.cos(d.v6 + d.phase) end)() * R, H, (function() local dt = t - (d.last_t or t); d.last_t = t; d.phase = (d.phase or 0) + (dt * s); return math.sin(d.v6 + d.phase) end)() * R)) - wp)
				* (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Spin Speed", Min = 0, Max = 200, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Halo Radius", Min = 20, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Height Offset", Min = 20, Max = 200, Key = "k14" }
}



return M
