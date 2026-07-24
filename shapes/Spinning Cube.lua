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

	local a = d.phase
	local ca, sa = math.cos(a), math.sin(a)

	local rx, ry, rz = lx, ly, lz
	if c.k14 then
		rx = lx * ca + lz * sa
		ry = ly
		rz = -lx * sa + lz * ca
	else
		rx = lx
		ry = ly * ca - lz * sa
		rz = ly * sa + lz * ca
	end

	local target_pos = cen + Vector3.new(rx, ry, rz)
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 5, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Spin Speed", Min = 0, Max = 400, Key = "k12", Div = 10 },
	{ Type = "Toggle", Name = "Cut In Half", Key = "k13" },
	{ Type = "Toggle", Name = "Rotate Y Axis", Key = "k14" }
}

return M
