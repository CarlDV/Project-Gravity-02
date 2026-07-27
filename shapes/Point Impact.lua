local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local delta = cen - wp
	return delta.Magnitude > 0 and (delta.Unit * 10000) or Vector3.zero, cen
end

M.Controls = {}

return M