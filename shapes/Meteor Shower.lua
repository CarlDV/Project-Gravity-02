local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Meteor Shower"
	local SpreadXZ, HeightSpawn, FallSpeed = (c.k11 or 500), (c.k12 or 300), (c.k13 or 150)
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
			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * FallSpeed)
			local current_fall = (d.v3 + (d.phase / drop_dist)) % 1

			local y_pos = HeightSpawn - (current_fall * drop_dist)

			local x_pos = d.v1 - (current_fall * (SpreadXZ * 0.5))
			local z_pos = d.v2 - (current_fall * (SpreadXZ * 0.25))

			local target_pos = cen + Vector3.new(x_pos, y_pos, z_pos)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "XZ Spread", Min = 100, Max = 1500, Key = "k11" },
	{ Type = "Slider", Name = "Spawn Height", Min = 50, Max = 1500, Key = "k12" },
	{ Type = "Slider", Name = "Fall Speed", Min = 50, Max = 2000, Key = "k13" }
}

return M