local M = {}

function M.px(t, c, x6, x9)
	if not x6.pre["Orbital Shell"] then
		x6.pre["Orbital Shell"] = table.create(200)
	end
	local r = x6.pre["Orbital Shell"]
	table.clear(r)
	local s = (c.k13 or 10) * x9.c2
	local ph = t * s
	r[1] = { ca = math.cos(ph), sa = math.sin(ph) }
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Orbital Shell"
	local R = (c.k11 or 200)
			if not d.v4 then
				d.v4 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
			end
			local pd = x6.pre and x6.pre[md] and x6.pre[md][1]
			local ca, sa
			if pd then
				ca, sa = pd.ca, pd.sa
			else
				local s = (c.k13 or 10) * x9.c2
				ca, sa = math.cos(t * s), math.sin(t * s)
			end
			local rv
			if c.k19 then
				rv = Vector3.new(d.v4.X * ca - d.v4.Z * sa, d.v4.Y, d.v4.X * sa + d.v4.Z * ca)
			else
				if not d.v5 then
					d.v5 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
				end
				local k, v = d.v5, d.v4
				rv = v * ca + k:Cross(v) * sa + k * (k:Dot(v) * (1 - ca))
			end
			if c.k18 then
				rv = Vector3.new(rv.X, math.abs(rv.Y), rv.Z)
			end
			return ((cen + (rv * R)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 300, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Shell Radius", Min = 50, Max = 1000, Key = "k11" },
	{ Type = "Slider", Name = "Move Area", Min = 50, Max = 1500, Key = "k17" },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18" },
	{ Type = "Toggle", Name = "Stable Flow", Key = "k19" }
}

return M