local M = {}

function M.px(t, c, x6, x9)
	if not x6.pre["Cosmic Comet"] then
		x6.pre["Cosmic Comet"] = table.create(200)
	end
	if not x6.pre["Cosmic Comet_meta"] then
		x6.pre["Cosmic Comet_meta"] = { phase = 0, last_t = t }
	end
	local meta = x6.pre["Cosmic Comet_meta"]
	local s, h, l = (c.k13 or 10) * x9.c2, c.k14 or 50, (c.k16 or x9.c5) * 100
	local dt = t - meta.last_t
	meta.last_t = t
	meta.phase = meta.phase + dt * s

	local r = x6.pre["Cosmic Comet"]
	table.clear(r)
	local res = 200
	local R = (c.k17 or 150)
	for i = 1, res do
		local pc = (i - 1) / (res - 1)
		local ph = meta.phase - (pc * (l * x9.c2))
		r[i] = Vector3.new(math.cos(ph) * R, math.sin(ph * (c.k15 or 5) * x9.c7) * h, math.sin(ph) * R)
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Cosmic Comet"
	local hr, ts = (c.k11 or 4), (c.k12 or 50) * x9.c7
			if not d.v4 then
				d.v4 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
				d.v6 = math.random()
			end
			if not d.v8 then
				d.v8 = math.random()
			end
			local p_data = x6.pre and x6.pre[md]
			local center_pos
			if p_data and #p_data > 0 then
				local idx = math.floor(d.v6 * (#p_data - 1)) + 1
				center_pos = p_data[idx]
			else
				local s, h, l = (c.k13 or 10) * x9.c2, c.k14 or 50, (c.k16 or x9.c5) * 100
				local dt = t - (d.last_t or t)
				d.last_t = t
				d.phase = (d.phase or 0) + dt * s
				local ph = d.phase - (d.v6 * (l * x9.c2))
				local R = (c.k17 or 150)
				center_pos = Vector3.new(math.cos(ph) * R, math.sin(ph * (c.k15 or 5) * x9.c7) * h, math.sin(ph) * R)
			end
			local target_pos = cen + center_pos + (d.v4 * (d.v8 * (hr + (d.v6 * d.v6 * 30 * ts))))
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Comet Speed", Min = 1, Max = 300, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Tail Length", Min = 10, Max = 500, Key = "k16", Div = 100 },
	{ Type = "Slider", Name = "Head Radius", Min = 1, Max = 50, Key = "k11", Div = 2 },
	{ Type = "Slider", Name = "Tail Spread", Min = 0, Max = 200, Key = "k12" },
	{ Type = "Slider", Name = "Height Limit", Min = 0, Max = 200, Key = "k14" },
	{ Type = "Slider", Name = "Move Area", Min = 50, Max = 800, Key = "k17" }
}



return M