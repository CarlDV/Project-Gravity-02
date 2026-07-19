local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	p.CFrame = CFrame.new(cen)
	
	d.unclaim = true
	
	return Vector3.zero, cen
end

M.Controls = {}

return M
