local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Möbius Strip"
	local R, width, s = (c.k11 or 50), (c.k12 or 20), (c.k13 or 15) * x9.c2
			if not d.v6 then
				d.v6 = math.random() * math.pi * 2
			end
			if not d.v1 then
				d.v1 = (math.random() - 0.5) * 2
			end
			local v_ang = (t * s) + d.v6
			local w_offset = d.v1 * width
			local tx = (R + w_offset * math.cos(v_ang / 2)) * math.cos(v_ang)
			local tz = (R + w_offset * math.cos(v_ang / 2)) * math.sin(v_ang)
			local ty = w_offset * math.sin(v_ang / 2)
			return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 10, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Width", Min = 5, Max = 200, Key = "k12" },
	{ Type = "Slider", Name = "Speed", Min = 1, Max = 100, Key = "k13", Div = 10 }
}

return M