local M = {}

function M.px(t, c, x6, x9)
	if not x6.pre["Celestial Ribbon"] then
		x6.pre["Celestial Ribbon"] = table.create(200)
	end
	if not x6.pre["Celestial Ribbon_B"] then
		x6.pre["Celestial Ribbon_B"] = table.create(200)
	end
	if not x6.pre["Celestial Ribbon_meta"] then
		x6.pre["Celestial Ribbon_meta"] = { phase = 0, last_t = t }
	end
	local meta = x6.pre["Celestial Ribbon_meta"]
	local s, w, h, l = (c.k13 or 10) * x9.c2, (c.k11 or 8), c.k14 or 50, (c.k16 or x9.c5) * 100
	local dt = t - meta.last_t
	meta.last_t = t
	meta.phase = meta.phase + dt * s

	local r = x6.pre["Celestial Ribbon"]
	local r2 = x6.pre["Celestial Ribbon_B"]
	table.clear(r)
	table.clear(r2)
	local res = 200
	local R = (c.k17 or 150)
	for i = 1, res do
		local pc = (i - 1) / (res - 1)
		local ph = meta.phase - (pc * (l * x9.c2))
		
		local function get_pos(phi)
			return Vector3.new(math.cos(phi) * R, math.sin(phi * 0.577) * h, math.sin(phi * 1.618) * R)
		end
		
		local p_cur = get_pos(ph)
		local p_next = get_pos(ph - 0.05)
		local T = (p_next - p_cur).Unit
		if T.Magnitude ~= T.Magnitude then T = Vector3.xAxis end

		local Rv = T:Cross(Vector3.yAxis)
		if Rv.Magnitude < 0.001 then Rv = Vector3.xAxis end
		Rv = Rv.Unit
		
		local trn = Rv * math.cos(ph * 0.5) + (T:Cross(Rv)) * math.sin(ph * 0.5)
		r[i] = { p = p_cur, t = trn.Unit, ph = ph }

		local ph2 = ph + 2.37
		local function get_pos2(phi)
			return Vector3.new(math.cos(phi * 1.247) * R, math.sin(phi * 0.693) * h, math.sin(phi * 0.831) * R)
		end
		
		local p_cur2 = get_pos2(ph2)
		local p_next2 = get_pos2(ph2 - 0.05)
		local T2 = (p_next2 - p_cur2).Unit
		if T2.Magnitude ~= T2.Magnitude then T2 = Vector3.xAxis end

		local Rv2 = T2:Cross(Vector3.yAxis)
		if Rv2.Magnitude < 0.001 then Rv2 = Vector3.xAxis end
		Rv2 = Rv2.Unit
		
		local trn2 = Rv2 * math.cos(ph2 * 0.5) + (T2:Cross(Rv2)) * math.sin(ph2 * 0.5)
		r2[i] = { p = p_cur2, t = trn2.Unit, ph = ph2 }
	end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local md = "Celestial Ribbon"
	local w = c.k11 or 8
	if not d.v7 then
		d.v7 = math.random() - 0.5
		d.v6 = math.random()
	end
	if c.k19 and not d.v9 then
		d.v9 = math.random(0, 1)
	end

	local spine_key = md
	if c.k19 and d.v9 == 1 then
		spine_key = md .. "_B"
	end

	local p_data = x6.pre and x6.pre[spine_key]
	local fin
	if p_data and #p_data > 0 then
		local idx = math.floor(d.v6 * (#p_data - 1)) + 1
		local node = p_data[idx]
		fin = node.p
			+ (node.t * (d.v7 * w))
			+ (c.k18 and (node.t * math.sin(node.ph * 8)) * (w * 2.0) or Vector3.zero)
	else
		local s, h, l = (c.k13 or 10) * x9.c2, c.k14 or 50, (c.k16 or x9.c5) * 100
		local isB = c.k19 and d.v9 == 1
		local dt = t - (d.last_t or t)
		d.last_t = t
		d.phase = (d.phase or 0) + dt * s
		local ph = d.phase - (d.v6 * (l * x9.c2)) + (isB and 2.37 or 0)
		local R = (c.k17 or 150)
		local function get_pos_fallback(phi, is_b)
			if is_b then
				return Vector3.new(math.cos(phi * 1.247) * R, math.sin(phi * 0.693) * h, math.sin(phi * 0.831) * R)
			else
				return Vector3.new(math.cos(phi) * R, math.sin(phi * 0.577) * h, math.sin(phi * 1.618) * R)
			end
		end

		local p_cur = get_pos_fallback(ph, isB)
		local p_next = get_pos_fallback(ph - 0.05, isB)
		local T = (p_next - p_cur).Unit
		if T.Magnitude ~= T.Magnitude then T = Vector3.xAxis end

		local Rvec = T:Cross(Vector3.yAxis)
		if Rvec.Magnitude < 0.001 then
			Rvec = Vector3.xAxis
		end
		Rvec = Rvec.Unit
		local trn = Rvec * math.cos(ph * 0.5) + (T:Cross(Rvec)) * math.sin(ph * 0.5)
		
		fin = p_cur
			+ (trn.Unit * (d.v7 * w))
			+ (c.k18 and (trn.Unit * math.sin(ph * 8)) * (w * 2.0) or Vector3.zero)
	end
	local target_pos = cen + fin
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Ribbon Speed", Min = 1, Max = 300, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Ribbon Length", Min = 10, Max = 500, Key = "k16", Div = 100 },
	{ Type = "Slider", Name = "Ribbon Width", Min = 1, Max = 150, Key = "k11", Div = 2 },
	{ Type = "Slider", Name = "Height Limit", Min = 0, Max = 200, Key = "k14" },
	{ Type = "Slider", Name = "Move Area", Min = 50, Max = 800, Key = "k17" },
	{ Type = "Toggle", Name = "Enable Slither", Key = "k18" },
	{ Type = "Toggle", Name = "Dual Dragons", Key = "k19" }
}

return M