local M = {}

function M.px(t, c, x6, x9, x1)
	local md = "Point Impact"
	if not x6.pre[md] then
		x6.pre[md] = {}
	end
	local r = x6.pre[md]
	
	local current_time = t
	local dt = current_time - (r.last_t or current_time)
	r.last_t = current_time
	
	local s = 500
	if x1 and x1.ImpactManual then
		if not x1.IsLaunching then
			s = 1
		else
			s = 1000
		end
	end
	
	r.phase = (r.phase or 0) + (dt * s)
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Point Impact"
	local s = 500
			local radius = c.k11 or 0
			if x1.ImpactManual then
				if not x1.IsLaunching then
					s = 1
					radius = 35
				else
					s = 1000
					radius = 0
				end
			end
			if not d.v5 then
				d.v5 = math.random() - 0.5
			end
			if not d.v4 then
				d.v4 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
			end


			local pr = x6.pre and x6.pre[md]
			local ph = pr and pr.phase or 0
			local cx, sx = math.cos(ph), math.sin(ph)
			local rd = Vector3.new(d.v4.X * cx - d.v4.Z * sx, d.v4.Y + d.v5, d.v4.X * sx + d.v4.Z * cx).Unit


			local target_pos = cen + (rd * radius)
			return (target_pos - wp) * 5000, target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 500, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Closeness", Min = 1, Max = 50, Key = "k11", Div = 2 },
	{ Type = "Slider", Name = "Move Area", Min = 50, Max = 800, Key = "k17" }
}



return M