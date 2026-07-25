local M = {}

function M.px(t, c, x6, x9)
	if not x6.pre["Celestial Ribbon_meta"] then
		x6.pre["Celestial Ribbon_meta"] = { phase = 0, last_t = t }
	end
	local meta = x6.pre["Celestial Ribbon_meta"]
	local dragon_count
	if type(c.k19) == "number" then
		dragon_count = math.clamp(math.floor(c.k19), 1, 8)
	else
		dragon_count = c.k19 and 2 or 1
	end
	local s, w, h, l = (c.k13 or 10) * x9.c2, (c.k11 or 8), c.k14 or 50, (c.k16 or x9.c5) * 100
	local dt = t - meta.last_t
	meta.last_t = t
	meta.phase = meta.phase + dt * s

	local res = 200
	local R = (c.k17 or 150)
	for dragon_index = 1, dragon_count do
		local key = "Celestial Ribbon_" .. dragon_index
		local spine = x6.pre[key]
		if not spine then
			spine = table.create(res)
			x6.pre[key] = spine
		end
		for i = 1, res do
			local pc = (i - 1) / (res - 1)
			local ph = meta.phase - (pc * (l * x9.c2)) + ((dragon_index - 1) * 2.37)
			local frequency = dragon_index == 1 and 1 or 1.247 + ((dragon_index - 2) * 0.113)
			local height_frequency = dragon_index == 1 and 0.577 or 0.693 + ((dragon_index - 2) * 0.071)
			local depth_frequency = dragon_index == 1 and 1.618 or 0.831 + ((dragon_index - 2) * 0.127)
			local next_ph = ph - 0.05
			local p_cur = Vector3.new(math.cos(ph * frequency) * R, math.sin(ph * height_frequency) * h, math.sin(ph * depth_frequency) * R)
			local p_next = Vector3.new(math.cos(next_ph * frequency) * R, math.sin(next_ph * height_frequency) * h, math.sin(next_ph * depth_frequency) * R)
			local T = (p_next - p_cur).Unit
			if T.Magnitude ~= T.Magnitude then T = Vector3.xAxis end
			local Rv = T:Cross(Vector3.yAxis)
			if Rv.Magnitude < 0.001 then Rv = Vector3.xAxis end
			Rv = Rv.Unit
			local trn = Rv * math.cos(ph * 0.5) + (T:Cross(Rv)) * math.sin(ph * 0.5)
			local node = spine[i]
			if node then
				node.p = p_cur
				node.t = trn.Unit
				node.ph = ph
			else
				spine[i] = { p = p_cur, t = trn.Unit, ph = ph }
			end
		end
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
	local dragon_count
	if type(c.k19) == "number" then
		dragon_count = math.clamp(math.floor(c.k19), 1, 8)
	else
		dragon_count = c.k19 and 2 or 1
	end
	if not d.v9 or d.v10 ~= dragon_count then
		d.v9 = math.random(1, dragon_count)
		d.v10 = dragon_count
	end

	local spine_key = md .. "_" .. d.v9

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
		local dt = t - (d.last_t or t)
		d.last_t = t
		d.phase = (d.phase or 0) + dt * s
		local ph = d.phase - (d.v6 * (l * x9.c2)) + ((d.v9 - 1) * 2.37)
		local R = (c.k17 or 150)
		local frequency = d.v9 == 1 and 1 or 1.247 + ((d.v9 - 2) * 0.113)
		local height_frequency = d.v9 == 1 and 0.577 or 0.693 + ((d.v9 - 2) * 0.071)
		local depth_frequency = d.v9 == 1 and 1.618 or 0.831 + ((d.v9 - 2) * 0.127)
		local next_ph = ph - 0.05
		local p_cur = Vector3.new(math.cos(ph * frequency) * R, math.sin(ph * height_frequency) * h, math.sin(ph * depth_frequency) * R)
		local p_next = Vector3.new(math.cos(next_ph * frequency) * R, math.sin(next_ph * height_frequency) * h, math.sin(next_ph * depth_frequency) * R)
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
	{ Type = "Slider", Name = "Dragon Count", Min = 1, Max = 8, Key = "k19", Default = 2, IntOnly = true, LegacyToggle = true }
}

return M