local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Tesseract"
	local size, outer_size, s = (c.k11 or 40), (c.k12 or 80), (c.k13 or 10) * x9.c2
			if not d.v1 then
				d.v1 = math.random(0, 31)
			end
			local target_rot = (t * s)

			local function proj_4d(x, y, z, w, rot)
				local nw = w * math.cos(rot) - x * math.sin(rot)
				local nx = w * math.sin(rot) + x * math.cos(rot)
				local perspective = size / (size - nw * 0.5)
				return nx * perspective, y * perspective, z * perspective
			end

			local points = {
				{ -1, -1, -1 },
				{ 1, -1, -1 },
				{ -1, 1, -1 },
				{ 1, 1, -1 },
				{ -1, -1, 1 },
				{ 1, -1, 1 },
				{ -1, 1, 1 },
				{ 1, 1, 1 },
			}

			local edge = d.v1
			local from, to
			if edge < 12 then
				from = points[(edge % 4) * 2 + 1]
				to = points[(edge % 4) * 2 + 2]
			elseif edge < 24 then
				from = points[((edge - 12) % 4) * 2 + 1]
				to = points[((edge - 12) % 4) * 2 + 2]
			else
				from = points[(edge - 24) + 1]
				to = points[(edge - 24) + 1]
			end

			local lerp = (math.sin(t * s + d.v1) + 1) / 2
			local lx = from[1] + (to[1] - from[1]) * lerp
			local ly = from[2] + (to[2] - from[2]) * lerp
			local lz = from[3] + (to[3] - from[3]) * lerp
			local lw = (edge >= 12 and edge < 24) and 1 or -1

			local rx, ry, rz = proj_4d(lx * outer_size, ly * outer_size, lz * outer_size, lw * outer_size, target_rot)
			return ((cen + Vector3.new(rx, ry, rz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Inner Size", Min = 10, Max = 200, Key = "k11" },
	{ Type = "Slider", Name = "Outer Size", Min = 20, Max = 400, Key = "k12" },
	{ Type = "Slider", Name = "Rotation Speed", Min = 1, Max = 100, Key = "k13", Div = 10 }
}

return M