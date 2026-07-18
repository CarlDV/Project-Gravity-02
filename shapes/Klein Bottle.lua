local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Klein Bottle"
	local R, s = (c.k11 or 60), (c.k13 or 20) * x9.c2
			if not d.v1 then
				d.v1 = math.random() * math.pi * 2
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local u_phase = d.phase + d.v1
			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase2 = (d.phase2 or 0) + (dt * s * 0.5)
			local v_phase = d.phase2 + d.v2

			local cos_u, sin_u = math.cos(u_phase), math.sin(u_phase)
			local cos_v, sin_v = math.cos(v_phase), math.sin(v_phase)

			local tx = (R + cos_u * sin_v - sin_u * sin_v * 2) * cos_v
			local ty = sin_u * sin_v * R
			local tz = (R + cos_u * sin_v - sin_u * sin_v * 2) * sin_v

			local target_pos = cen + Vector3.new(tx, ty, tz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 10, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Flow Speed", Min = 1, Max = 100, Key = "k13", Div = 10 }
}

return M