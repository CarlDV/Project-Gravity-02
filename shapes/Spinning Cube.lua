local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	if not d.u then
		d.u = math.random() * 2 - 1
		d.v = math.random() * 2 - 1
		d.w = math.random() * 2 - 1
	end

	local rad = c.k11 or 40
	local spd = (c.k12 or 50) * 0.1

	local dt = t - (d.last_t or t)
	d.last_t = t
	d.phase = (d.phase or 0) + (dt * spd)

	local fu = (c.k13 and d.u < 0) and -d.u or d.u
	local fv = d.v
	local fw = d.w

	local lx = fu * rad
	local ly = fv * rad
	local lz = fw * rad

	local ax = d.phase
	local ay = d.phase * 1.2
	local az = d.phase * 0.8

	local cx, sx = math.cos(ax), math.sin(ax)
	local cy, sy = math.cos(ay), math.sin(ay)
	local cz, sz = math.cos(az), math.sin(az)

	local y1 = ly * cx - lz * sx
	local z1 = ly * sx + lz * cx

	local x2 = lx * cy + z1 * sy
	local z2 = -lx * sy + z1 * cy

	local x3 = x2 * cz - y1 * sz
	local y3 = x2 * sz + y1 * cz

	local target_pos = cen + Vector3.new(x3, y3, z2)
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 5, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Spin Speed", Min = 0, Max = 200, Key = "k12", Div = 10 },
	{ Type = "Toggle", Name = "Cut In Half", Key = "k13" }
}

return M
