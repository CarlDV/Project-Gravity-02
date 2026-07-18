local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Fractal Web"
	local HexR, Depth, BSpeed, RSpeed = (c.k11 or 40), (c.k12 or 3), (c.k13 or 3) * x9.c2, (c.k14 or 5) * x9.c2
			if not d.v1 then
				d.v1 = math.random(0, math.max(1, Depth - 1))
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random()
			end
			if not d.v4 then
				d.v4 = math.floor(math.random() * 6)
			end

			local phase = t * RSpeed
			local breath = math.sin(t * BSpeed) * 0.3 + 1
			local level = d.v1
			local tx, ty, tz = 0, 0, 0


			local accumulated_x, accumulated_z = 0, 0
			local current_r = HexR
			for lv = 0, level do
				local vertex_idx
				if lv == level then
					vertex_idx = d.v4
				else
					vertex_idx = math.floor(d.v2 / (math.pi * 2) * 6 + lv) % 6
				end
				local angle = (vertex_idx / 6) * math.pi * 2 + phase * (1 / (lv + 1))
				local offset_r = current_r * breath * (1 + lv * 0.3)
				accumulated_x = accumulated_x + offset_r * math.cos(angle)
				accumulated_z = accumulated_z + offset_r * math.sin(angle)
				current_r = current_r * 0.5
			end


			local edge_prog = d.v3
			local next_vertex = (d.v4 + 1) % 6
			local cur_angle = (d.v4 / 6) * math.pi * 2 + phase * (1 / (level + 1))
			local nxt_angle = (next_vertex / 6) * math.pi * 2 + phase * (1 / (level + 1))
			local edge_r = current_r * breath * (1 + level * 0.3)
			local ex = edge_r * math.cos(cur_angle) * (1 - edge_prog) + edge_r * math.cos(nxt_angle) * edge_prog
			local ez = edge_r * math.sin(cur_angle) * (1 - edge_prog) + edge_r * math.sin(nxt_angle) * edge_prog

			tx = accumulated_x + ex
			tz = accumulated_z + ez
			ty = 50 + level * 20 + math.sin(phase + d.v2) * 5

			local target_pos = cen + Vector3.new(tx, ty, tz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Hex Radius", Min = 15, Max = 120, Key = "k11" },
	{ Type = "Slider", Name = "Depth", Min = 2, Max = 4, Key = "k12" },
	{ Type = "Slider", Name = "Breath Speed", Min = 1, Max = 20, Key = "k13" },
	{ Type = "Slider", Name = "Rotation Speed", Min = 1, Max = 30, Key = "k14" }
}

return M