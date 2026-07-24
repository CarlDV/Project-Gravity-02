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

	local cut = (c.k13 == true)

	if f == 1 then
		local yu = cut and (u * 0.5 + 0.5) or u
		lx, ly, lz = 1, yu, v
	elseif f == 2 then
		local yu = cut and (u * 0.5 + 0.5) or u
		lx, ly, lz = -1, yu, v
	elseif f == 3 then
		lx, ly, lz = u, 1, v
	elseif f == 4 then
		local yval = cut and 0 or -1
		lx, ly, lz = u, yval, v
	elseif f == 5 then
		local yv = cut and (v * 0.5 + 0.5) or v
		lx, ly, lz = u, yv, 1
	else
		local yv = cut and (v * 0.5 + 0.5) or v
		lx, ly, lz = u, yv, -1
	end

	local rad = c.k11 or 40
	lx, ly, lz = lx * rad, ly * rad, lz * rad

	local spd = (c.k12 or 200) * 0.05
	local dt = t - (d.last_t or t)
	d.last_t = t
	d.phase = (d.phase or 0) + (dt * spd)

	local ax = d.phase
	local cx, sx = math.cos(ax), math.sin(ax)

	local ry = ly * cx - lz * sx
	local rz = ly * sx + lz * cx
	local rx = lx

	local target_pos = cen + Vector3.new(rx, ry, rz)
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 5, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Spin Speed", Min = 0, Max = 400, Key = "k12", Div = 10 },
	{ Type = "Toggle", Name = "Cut In Half", Key = "k13" }
}

return M
