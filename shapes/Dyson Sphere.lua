local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Dyson Sphere"
	local R, ShellDensity, s = (c.k11 or 150), (c.k12 or 8), (c.k13 or 10) * x9.c2
			if not d.v1 then
				d.v1 = math.random()
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random() * math.pi
			end
			if not d.v4 then
				local roll = math.random()
				if roll < 0.15 then
					d.v4 = 1
				elseif roll < 0.85 then
					d.v4 = 2
				else
					d.v4 = 3
				end
			end

			local phase = (t * s)

			if d.v4 == 1 then

				local core_r = 15 + math.sin(phase * 2) * 2
				local tx = core_r * math.sin(d.v3) * math.cos(d.v2 + phase * 3)
				local ty = core_r * math.cos(d.v3)
				local tz = core_r * math.sin(d.v3) * math.sin(d.v2 + phase * 3)
				return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
			elseif d.v4 == 2 then

				local p_theta = math.floor(d.v2 * ShellDensity) / ShellDensity
				local p_phi = math.floor(d.v3 * (ShellDensity / 2)) / (ShellDensity / 2)
				local rot_theta = p_theta + (phase * 0.2)

				local tx = R * math.sin(p_phi) * math.cos(rot_theta)
				local ty = R * math.cos(p_phi)
				local tz = R * math.sin(p_phi) * math.sin(rot_theta)
				return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
			else

				local stream_progress = (d.v1 + phase * 1.5) % 1
				local current_r = 15 + stream_progress * (R - 15)

				local p_theta = math.floor(d.v2 * 10) / 10
				local p_phi = math.floor(d.v3 * 10) / 10
				local rot_theta = p_theta + (phase * 0.2)

				local tx = current_r * math.sin(p_phi) * math.cos(rot_theta)
				local ty = current_r * math.cos(p_phi)
				local tz = current_r * math.sin(p_phi) * math.sin(rot_theta)
				return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
			end
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 50, Max = 400, Key = "k11" },
	{ Type = "Slider", Name = "Grid Density", Min = 2, Max = 50, Key = "k12" },
	{ Type = "Slider", Name = "Speed", Min = 1, Max = 100, Key = "k13", Div = 10 }
}

return M