local M = {}

function M.px(t, c, x6, x9)
	if not x6.pre["Hollow Worm"] then
		x6.pre["Hollow Worm"] = table.create(200)
	end
	local r = x6.pre["Hollow Worm"]
	table.clear(r)
	local res = 200
	local s, radius, h, wf, l =
		(c.k13 or 10) * x9.c2, (c.k11 or 8), c.k14 or 50, (c.k15 or 10) * x9.c7, (c.k16 or x9.c5) * 100
	local R = (c.k17 or 150)
	for i = 1, res do
		local pc = (i - 1) / (res - 1)
		local ph = (t * s) - (pc * (l * x9.c2))
		local sx, sz, sy = math.cos(ph) * R, math.sin(ph) * R, math.sin(ph * wf) * h
		r[i] = Vector3.new(sx, sy, sz)
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Hollow Tube"
	local r, wf = (c.k11 or 8), (c.k15 or 10) * x9.c7
			if not d.v4 then
				d.v4 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
				d.v6 = math.random()
			end
			local p_data = x6.pre and x6.pre[md]
			local center_pos
			if p_data and #p_data > 0 then
				local idx = math.floor(d.v6 * (#p_data - 1)) + 1
				center_pos = p_data[idx]
			else
				local s, h, l = (c.k13 or 10) * x9.c2, c.k14 or 50, (c.k16 or x9.c5) * 100
				local ph = (t * s) - (d.v6 * (l * x9.c2))
				local R = (c.k17 or 150)
				center_pos = Vector3.new(math.cos(ph) * R, math.sin(ph * wf) * h, math.sin(ph) * R)
			end
			local cx, sx_spin = math.cos(t * 2), math.sin(t * 2)
			local rd = Vector3.new(d.v4.X * cx - d.v4.Z * sx_spin, d.v4.Y, d.v4.X * sx_spin + d.v4.Z * cx).Unit
			return ((cen + center_pos + (rd * r)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Worm Speed", Min = 1, Max = 300, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Worm Length", Min = 10, Max = 500, Key = "k16", Div = 100 },
	{ Type = "Slider", Name = "Tube Radius", Min = 1, Max = 100, Key = "k11", Div = 2 },
	{ Type = "Slider", Name = "Height Limit", Min = 0, Max = 200, Key = "k14" },
	{ Type = "Slider", Name = "Wavelength", Min = 1, Max = 50, Key = "k15" },
	{ Type = "Slider", Name = "Move Area", Min = 50, Max = 800, Key = "k17" }
}

M.Description = "Arranges parts into a hollow cylindrical tunnel."

return M
