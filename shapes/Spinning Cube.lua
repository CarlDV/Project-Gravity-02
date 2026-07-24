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

	if c.k13 and f == 2 then
		return (cen - wp) * (x1.k10 * x9.c1), cen
	end

	local lx, ly, lz = 0, 0, 0
	if f == 1 then lx, ly, lz = 1, u, v
	elseif f == 2 then lx, ly, lz = -1, u, v
	elseif f == 3 then lx, ly, lz = u, 1, v
	elseif f == 4 then lx, ly, lz = u, -1, v
	elseif f == 5 then lx, ly, lz = u, v, 1
	else lx, ly, lz = u, v, -1
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

	local rotY = (c.k14 == true)
	local rotX = (c.k15 == true)

	if not rotY and not rotX then
		rotX = true
	end

	if rotY then
		local nx = rx * ca + rz * sa
		local nz = -rx * sa + rz * ca
		rx, rz = nx, nz
	end

	if rotX then
		local ny = ry * ca - rz * sa
		local nz = ry * sa + rz * ca
		ry, rz = ny, nz
	end

	local target_pos = cen + Vector3.new(rx, ry, rz)
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 5, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Spin Speed", Min = 0, Max = 400, Key = "k12", Div = 10 },
	{ Type = "Toggle", Name = "Cut In Half", Key = "k13" },
	{ Type = "Toggle", Name = "Rotate Y Axis", Key = "k14" },
	{ Type = "Toggle", Name = "Rotate X Axis", Key = "k15" }
}

return M
