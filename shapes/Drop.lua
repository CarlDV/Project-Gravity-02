local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	
	local speed = c.k11 or 500
	local drop_dist = c.k12 or 5
	
	local target_pos = cen
	
	-- If the part is very close to the center, instantly unclaim it
	if tc.Magnitude <= drop_dist then
		d.unclaim = true
	end
	
	return (target_pos - wp) * speed, target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Pull Speed", Min = 50, Max = 2000, Key = "k11" },
	{ Type = "Slider", Name = "Drop Radius", Min = 1, Max = 20, Key = "k12" }
}

return M
