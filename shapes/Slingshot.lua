local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Slingshot"
	local dist = c.k11 or 50
			local cycle = c.k12 or 3
			local speed = c.k13 or 100
			if not d.v1 then
				d.v1 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
				d.v2 = math.random() * cycle
				d.v2 = 0
			end
			local phase = (t + d.v2) % cycle
			local is_charging = phase < (cycle * 0.8)
			if x1.SlingshotManual then
				is_charging = not x1.IsLaunching
			end
			if is_charging then
				local charge_pos = cen + (d.v1 * dist)
				return (charge_pos - wp) * (5 * x9.c1)
			else
				local smash_pos = cen
				return (smash_pos - wp) * (speed * x9.c1)
			end
end

M.Controls = {
	{ Type = "Slider", Name = "Charge Dist", Min = 10, Max = 200, Key = "k11" },
	{ Type = "Slider", Name = "Cycle Time", Min = 1, Max = 10, Key = "k12" },
	{ Type = "Slider", Name = "Fling Speed", Min = 1, Max = 500, Key = "k13" }
}

M.Description = "Pulls parts backwards before launching them forward."

return M
