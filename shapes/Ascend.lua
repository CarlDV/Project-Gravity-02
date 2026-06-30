local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Ascend"
	local ascent_speed = c.k11 or 10
			return Vector3.new(0, ascent_speed, 0)
end

M.Controls = {
	{ Type = "Slider", Name = "Ascent Speed", Min = 1, Max = 100, Key = "k11" }
}

M.Description = "Draws parts rapidly upwards into a vertical column."

return M
