local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Graviton Engine"
	local Turbines, R, s, H = (c.k11 or 4), (c.k12 or 60), (c.k13 or 12) * x9.c2, (c.k14 or 200)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.25 then
					d.v1 = 1
				elseif roll < 0.45 then
					d.v1 = 2
				elseif roll < 0.60 then
					d.v1 = 3
				elseif roll < 0.72 then
					d.v1 = 4
				elseif roll < 0.88 then
					d.v1 = 5
				else
					d.v1 = 6
				end
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random()
			end
			if not d.v4 then
				d.v4 = math.random()
			end

			local phase = t * s
			local tx, ty, tz = 0, 0, 0
			local turb_spacing = H / (Turbines + 1)

			if d.v1 == 1 then

				local turb_idx = math.floor(d.v3 * Turbines)
				local turb_y = turb_spacing * (turb_idx + 1)
				local turb_phase = d.v2 + phase * (1 + turb_idx * 0.3)
				if turb_idx % 2 == 1 then
					turb_phase = -turb_phase
				end
				tx = R * math.cos(turb_phase)
				tz = R * math.sin(turb_phase)
				ty = turb_y
			elseif d.v1 == 2 then

				local turb_idx = math.floor(d.v3 * Turbines)
				local turb_y = turb_spacing * (turb_idx + 1)
				local blade_count = 6
				local blade_idx = math.floor(d.v2 / (math.pi * 2) * blade_count)
				local blade_base_angle = (blade_idx / blade_count) * math.pi * 2 + phase * (1 + turb_idx * 0.3)
				if turb_idx % 2 == 1 then
					blade_base_angle = -blade_base_angle
				end
				local blade_len = R * 0.4
				local blade_prog = d.v4
				local blade_r = R * 0.6 + blade_prog * blade_len
				local blade_tilt = math.pi * 0.15
				tx = blade_r * math.cos(blade_base_angle)
				tz = blade_r * math.sin(blade_base_angle)
				ty = turb_y + math.sin(blade_tilt) * blade_prog * blade_len * 0.3
			elseif d.v1 == 3 then

				local turb_idx = math.floor(d.v3 * math.max(1, Turbines - 1))
				local lower_y = turb_spacing * (turb_idx + 1)
				local upper_y = turb_spacing * (turb_idx + 2)
				local pipe_count = 4
				local pipe_idx = math.floor(d.v2 / (math.pi * 2) * pipe_count)
				local pipe_angle = (pipe_idx / pipe_count) * math.pi * 2 + phase * 0.2
				local prog = (d.v4 + phase * 2) % 1
				local pipe_r = 15
				tx = pipe_r * math.cos(pipe_angle)
				tz = pipe_r * math.sin(pipe_angle)
				ty = lower_y + prog * (upper_y - lower_y)
			elseif d.v1 == 4 then

				local turb_idx = math.floor(d.v3 * Turbines)
				local turb_y = turb_spacing * (turb_idx + 1)
				local exhaust_prog = (d.v4 + phase * 3) % 1
				local exhaust_r = R * 0.3 + exhaust_prog * R * 0.5
				local exhaust_angle = d.v2 + phase * 2
				tx = exhaust_r * math.cos(exhaust_angle)
				tz = exhaust_r * math.sin(exhaust_angle)
				ty = turb_y - exhaust_prog * turb_spacing * 0.6
			elseif d.v1 == 5 then

				local dish_r = d.v3 * R * 1.2
				local dish_angle = d.v2 + phase * 0.3
				local dish_y = H + (dish_r * dish_r) / (R * 2)
				tx = dish_r * math.cos(dish_angle)
				tz = dish_r * math.sin(dish_angle)
				ty = dish_y
			else

				local beam_r = 3 + math.sin(phase * 5 + d.v2 * 10) * 2
				local beam_prog = (d.v3 + phase * 4) % 1
				tx = beam_r * math.cos(d.v2)
				tz = beam_r * math.sin(d.v2)
				ty = H + 20 + beam_prog * H * 0.8

				if beam_prog > 0.7 then
					local scatter = (beam_prog - 0.7) / 0.3
					tx = tx + math.cos(d.v4 * math.pi * 2) * scatter * 40
					tz = tz + math.sin(d.v4 * math.pi * 2) * scatter * 40
				end
			end
			return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Turbine Count", Min = 2, Max = 8, Key = "k11", IntOnly = true },
	{ Type = "Slider", Name = "Radius", Min = 20, Max = 200, Key = "k12" },
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 50, Key = "k13" },
	{ Type = "Slider", Name = "Tower Height", Min = 50, Max = 500, Key = "k14" }
}

return M