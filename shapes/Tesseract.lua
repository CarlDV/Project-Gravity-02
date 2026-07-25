local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Tesseract"
	local size, outer_size, s = (c.k11 or 40), (c.k12 or 80), (c.k13 or 10) * x9.c2
			if not d.v1 then
				d.v1 = math.random(0, 31)
			end
			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local target_rot = d.phase

			local function proj_4d(x, y, z, w, rot)
				local nw = w * math.cos(rot) - x * math.sin(rot)
				local nx = w * math.sin(rot) + x * math.cos(rot)
				local projection_distance = math.max(size, outer_size * 1.5)
				local perspective = projection_distance / (projection_distance - nw * 0.5)
				return nx * perspective, y * perspective, z * perspective
			end

			local edge = d.v1
			local direction = math.floor(edge / 8) + 1
			local vertex = edge % 8
			local from = { -1, -1, -1, -1 }
			local bit_index = 0
			for dimension = 1, 4 do
				if dimension ~= direction then
					from[dimension] = math.floor(vertex / (2 ^ bit_index)) % 2 == 1 and 1 or -1
					bit_index = bit_index + 1
				end
			end
			local to = { from[1], from[2], from[3], from[4] }
			to[direction] = 1

			local lerp = (math.sin(d.phase + d.v1) + 1) / 2
			local lx = from[1] + (to[1] - from[1]) * lerp
			local ly = from[2] + (to[2] - from[2]) * lerp
			local lz = from[3] + (to[3] - from[3]) * lerp
			local lw = from[4] + (to[4] - from[4]) * lerp

			local rx, ry, rz = proj_4d(lx * outer_size, ly * outer_size, lz * outer_size, lw * outer_size, target_rot)
			local target_pos = cen + Vector3.new(rx, ry, rz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Inner Size", Min = 10, Max = 200, Key = "k11" },
	{ Type = "Slider", Name = "Outer Size", Min = 20, Max = 400, Key = "k12" },
	{ Type = "Slider", Name = "Rotation Speed", Min = 1, Max = 100, Key = "k13", Div = 10 }
}

return M