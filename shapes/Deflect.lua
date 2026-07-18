local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Deflect"
	local range, speed = c.k11 or 50, c.k12 or 500
			if tc.Magnitude < range then
				return (wp - cen).Unit * speed
			end
end

M.Controls = {
	{ Type = "Slider", Name = "Range", Min = 10, Max = 500, Key = "k11" },
	{ Type = "Slider", Name = "Force", Min = 50, Max = 5000, Key = "k12" }
}

return M