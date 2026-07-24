local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	if not d.f then
		d.f = math.random(1, 6)
		d.u = math.random() * 2 - 1
		d.v = math.random() * 2 - 1
	end

	local f = d.f
	local u, v = d.u, d.v
	local lx, ly, lz = 0, 0, 0

	if f == 1 then lx, ly, lz = 1, u, v
	elseif f == 2 then lx, ly, lz = -1, u, v
	elseif f == 3 then lx, ly, lz = u, 1, v
	elseif f == 4 then lx, ly, lz = u, -1, v
	elseif f == 5 then lx, ly, lz = u, v, 1
	else lx, ly, lz = u, v, -1
	end

	if c.k13 and lx < 0 then
		lx = 0
	end

	local rad = c.k11 or 40
	lx, ly, lz = lx * rad, ly * rad, lz * rad

	local spd = (c.k12 or 200) * 0.05
	local dt = t - (d.last_t or t)
	d.last_t = t
	d.phase = (d.phase or 0) + (dt * spd)

	local ay = d.phase
	local cy, sy = math.cos(ay), math.sin(ay)

	local rx = lx * cy + lz * sy
	local ry = ly
	local rz = -lx * sy + lz * cy

	local target_pos = cen + Vector3.new(rx, ry, rz)
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 5, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Spin Speed", Min = 0, Max = 400, Key = "k12", Div = 10 },
	{ Type = "Toggle", Name = "Cut In Half", Key = "k13" }
}

return M
