local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Big Ring Things"
	local rc = c.k11 or 2
			if not d.v1 or d.v2 ~= rc then
				d.v1 = math.random(1, rc)
				d.v2 = rc
				d.v3 = math.random() * math.pi * 2
			end
			local gap, spd = c.k12 or 170, (x9.c2 - (d.v1 - 1) * x9.c3) * (c.k13 or 10)
			if d.v1 % 2 == 0 then
				spd = -spd
			end
			local a = d.v3 + (t * spd)
			local tx, tz = math.cos(a) * (x1.k9 + (d.v1 - 1) * gap), math.sin(a) * (x1.k9 + (d.v1 - 1) * gap)
			local ty = 0
			local sw = math.sin(t * (c.k16 or x9.c4) + d.v1) * math.rad(c.k15 or 12)
			local rx, rz = sw, sw * 0.5
			if rx ~= 0 then
				local cy, sy = math.cos(rx), math.sin(rx)
				local ny = ty * cy - tz * sy
				local nz = ty * sy + tz * cy
				ty, tz = ny, nz
			end
			if rz ~= 0 then
				local cx, sx = math.cos(rz), math.sin(rz)
				local nx = tx * cx - ty * sx
				local ny = tx * sx + ty * cx
				tx, ty = nx, ny
			end
			local tp = cen + Vector3.new(tx, ty, tz)
			local ho = c.k14 or 5
			if tp.Y < ho then
				tp = Vector3.new(tp.X, ho, tp.Z)
			end
			return (tp - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Ring Count", Min = 1, Max = 20, Key = "k11", IntOnly = true },
	{ Type = "Slider", Name = "Ring Gap", Min = 50, Max = 300, Key = "k12" },
	{ Type = "Slider", Name = "Ring Speed", Min = 0, Max = 200, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Height Offset", Min = 0, Max = 100, Key = "k14" },
	{ Type = "Slider", Name = "Tilt Angle", Min = 0, Max = 90, Key = "k15" },
	{ Type = "Slider", Name = "Tilt Speed", Min = 0, Max = 50, Key = "k16", Div = 10 }
}

return M