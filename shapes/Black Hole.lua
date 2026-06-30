local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Black Hole"
	local event_horizon, disk_radius, spin, disk_height =
				(c.k11 or 40), (c.k12 or 100), (c.k13 or 15) * x9.c2, (c.k14 or 50)
			if not d.v2 then
				d.v2 = math.random()
			end
			if not d.v6 then
				d.v6 = math.random() * math.pi * 2
			end
			local rad = event_horizon + (d.v2 * (disk_radius - event_horizon))
			local local_spin = spin * (disk_radius / rad)
			local disk_phase = (t * local_spin) + d.v6
			local thickness = (math.random() - 0.5) * disk_height * math.sin(disk_phase * 2) * (event_horizon / rad)
			local tx = rad * math.cos(disk_phase)
			local tz = rad * math.sin(disk_phase)
			return ((cen + Vector3.new(tx, thickness, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Event Horizon", Min = 10, Max = 200, Key = "k11" },
	{ Type = "Slider", Name = "Disk Radius", Min = 50, Max = 2000, Key = "k12" },
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 200, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Disk Height", Min = 5, Max = 200, Key = "k14" }
}

M.Description = "Pulls all parts into a dense singularity at the center."

return M
