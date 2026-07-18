local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Leviathan Coil"
	local CoilR, Thick, s, H = (c.k11 or 50), (c.k12 or 15), (c.k13 or 8) * x9.c2, (c.k14 or 250)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.45 then
					d.v1 = 1
				elseif roll < 0.58 then
					d.v1 = 2
				elseif roll < 0.72 then
					d.v1 = 3
				elseif roll < 0.87 then
					d.v1 = 4
				else
					d.v1 = 5
				end
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random()
			end
			if not d.v4 then
				d.v4 = math.random() * math.pi * 2
			end

			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local phase = d.phase
			local tx, ty, tz = 0, 0, 0
			local coil_loops = 4
			local body_length = coil_loops * math.pi * 2

			local bob = math.sin(phase * 0.3) * 15

			if d.v1 == 1 then

				local prog = d.v3
				local coil_angle = prog * body_length + phase
				local body_y = prog * H + bob
				local thickness = Thick * (0.5 + math.sin(prog * math.pi) * 0.5)
				local tube_angle = d.v2
				local body_r = CoilR + math.cos(tube_angle) * thickness
				local body_up = math.sin(tube_angle) * thickness
				tx = body_r * math.cos(coil_angle)
				tz = body_r * math.sin(coil_angle)
				ty = body_y + body_up
			elseif d.v1 == 2 then

				local head_angle = phase
				local head_y = H + bob + 10
				local jaw_open = math.sin(phase * 2) * 0.5 + 0.5
				local head_r = Thick * 1.5
				local is_upper = d.v3 > 0.5
				local jaw_offset = (is_upper and 1 or -1) * jaw_open * 8
				tx = CoilR * math.cos(head_angle) + math.cos(d.v2) * head_r * d.v3
				tz = CoilR * math.sin(head_angle) + math.sin(d.v2) * head_r * d.v3
				ty = head_y + jaw_offset + math.cos(d.v4) * head_r * 0.3
			elseif d.v1 == 3 then

				local prog = d.v3 * 0.3
				local tail_angle = prog * body_length * 0.5 + phase * 2
				local tail_y = prog * H * 0.3 + bob - 10
				local taper = Thick * (1 - d.v3) * 0.4
				local whip_freq = 8
				local whip_offset = math.sin(phase * whip_freq + prog * 20) * taper * 2
				tx = (CoilR + whip_offset) * math.cos(tail_angle) + math.cos(d.v2) * taper
				tz = (CoilR + whip_offset) * math.sin(tail_angle) + math.sin(d.v2) * taper
				ty = tail_y + math.sin(d.v4 + phase * 3) * taper
			elseif d.v1 == 4 then

				local wing_point = d.v3 > 0.5 and 0.35 or 0.65
				local wing_angle = wing_point * body_length + phase
				local wing_y = wing_point * H + bob
				local flare_cycle = math.sin(phase * 1.5 + (d.v3 > 0.5 and 0 or math.pi))
				local flare = math.max(0, flare_cycle)
				local wing_side = (d.v2 > math.pi) and 1 or -1
				local wing_spread = flare * CoilR * 1.5
				local wing_prog = d.v4 / (math.pi * 2)

				local fan_angle = wing_angle + wing_side * math.pi * 0.5
				local fan_r = wing_prog * wing_spread
				tx = CoilR * math.cos(wing_angle) + fan_r * math.cos(fan_angle + (wing_prog - 0.5) * 0.8)
				tz = CoilR * math.sin(wing_angle) + fan_r * math.sin(fan_angle + (wing_prog - 0.5) * 0.8)
				ty = wing_y + fan_r * 0.3 * math.sin(wing_prog * math.pi)
			else

				local prog = d.v3
				local coil_angle = prog * body_length + phase
				local body_y = prog * H + bob
				local spine_r = CoilR
				local spine_up = Thick * (0.5 + math.sin(prog * math.pi) * 0.5) + 5
				tx = spine_r * math.cos(coil_angle)
				tz = spine_r * math.sin(coil_angle)
				ty = body_y + spine_up + math.sin(prog * 30 + phase * 2) * 2
			end
			local target_pos = cen + Vector3.new(tx, ty, tz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Coil Radius", Min = 15, Max = 150, Key = "k11" },
	{ Type = "Slider", Name = "Body Thickness", Min = 5, Max = 50, Key = "k12" },
	{ Type = "Slider", Name = "Coil Speed", Min = 1, Max = 30, Key = "k13" },
	{ Type = "Slider", Name = "Tower Height", Min = 50, Max = 500, Key = "k14" }
}

return M