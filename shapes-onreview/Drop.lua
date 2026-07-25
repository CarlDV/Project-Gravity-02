local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	if p.Anchored then
		d.unclaim = true
		return Vector3.zero, p.Position
	end

	if not d.unclaim then
		p.CFrame = p.CFrame + (cen - p.Position)
		d.unclaim = true
	end

	return Vector3.zero, cen
end

M.Drop = true

M.Controls = {}

return M
