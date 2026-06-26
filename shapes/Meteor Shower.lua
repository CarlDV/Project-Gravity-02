local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Meteor Shower"
	local SpreadXZ, HeightSpawn, FallSpeed, Density = (c.k11 or 500), (c.k12 or 300), (c.k13 or 150), (c.k14 or 50)
			if not d.v1 then
				d.v1 = (math.random() - 0.5) * SpreadXZ
			end
			if not d.v2 then
				d.v2 = (math.random() - 0.5) * SpreadXZ
			end
			if not d.v3 then
				d.v3 = math.random()
			end


			local drop_dist = HeightSpawn * 2
			local fall_time = drop_dist / FallSpeed
			local current_fall = ((t + d.v3 * fall_time) % fall_time) / fall_time

			local y_pos = HeightSpawn - (current_fall * drop_dist)

			local x_pos = d.v1 - (current_fall * (SpreadXZ * 0.5))
			local z_pos = d.v2 - (current_fall * (SpreadXZ * 0.25))

			return ((cen + Vector3.new(x_pos, y_pos, z_pos)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "XZ Spread", Min = 100, Max = 1500, Key = "k11" },
	{ Type = "Slider", Name = "Spawn Height", Min = 50, Max = 1500, Key = "k12" },
	{ Type = "Slider", Name = "Fall Speed", Min = 50, Max = 2000, Key = "k13" }
}

return M