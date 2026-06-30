local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Shield Wall"
	local s, w, h, d_val, h_off = (c.k13 or 20) * x9.c2, (c.k11 or 1), (c.k12 or 10), (c.k14 or 15), (c.k15 or 0)
			if not d.v4 then
				d.v4 = math.random() - 0.5
				d.v5 = math.random() - 0.5
			end
			local angle = (t * s) + (d.v4 * w)
			local tx = math.cos(angle) * d_val
			local tz = math.sin(angle) * d_val
			local ty = (d.v5 * h) + h_off
			return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 200, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Width", Min = 1, Max = 200, Key = "k11", Div = 10 },
	{ Type = "Slider", Name = "Height", Min = 1, Max = 50, Key = "k12" },
	{ Type = "Slider", Name = "Distance", Min = 5, Max = 100, Key = "k14" },
	{ Type = "Slider", Name = "H-Offset", Min = -50, Max = 50, Key = "k15" }
}

M.Description = "A flat, dense barrier of parts for defense."

return M
