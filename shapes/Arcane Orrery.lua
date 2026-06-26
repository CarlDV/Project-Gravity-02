local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Arcane Orrery"
	local R, Arms, s, H = (c.k11 or 120), (c.k12 or 4), (c.k13 or 8) * x9.c2, (c.k14 or 200)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.12 then
					d.v1 = 1
				elseif roll < 0.30 then
					d.v1 = 2
				elseif roll < 0.48 then
					d.v1 = 3
				elseif roll < 0.72 then
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

			local phase = t * s
			local tx, ty, tz = 0, 0, 0

			if d.v1 == 1 then

				local prog = d.v3
				ty = (prog - 0.5) * H
				local helix_r = 12 + math.sin(prog * math.pi * 6) * 3
				local strand = (d.v2 > math.pi) and math.pi or 0
				local helix_angle = prog * math.pi * 8 + phase * 3 + strand
				tx = helix_r * math.cos(helix_angle)
				tz = helix_r * math.sin(helix_angle)
				ty = ty + math.sin(phase * 2 + prog * 10) * 3
			elseif d.v1 == 2 then

				local teeth = 16
				local gear_r = R * 0.5
				local gear_phase = d.v2 + phase
				local tooth_bump = math.abs(math.sin(gear_phase * teeth / 2)) * 12
				local r = gear_r + tooth_bump
				tx = r * math.cos(gear_phase)
				tz = r * math.sin(gear_phase)
				ty = H * 0.4 + math.sin(phase + d.v2) * 3
			elseif d.v1 == 3 then

				local teeth = 20
				local gear_r = R * 0.8
				local gear_phase = d.v2 - phase * 0.7
				local tooth_bump = math.abs(math.sin(gear_phase * teeth / 2)) * 15
				local r = gear_r + tooth_bump
				tx = r * math.cos(gear_phase)
				tz = r * math.sin(gear_phase)
				ty = H * 0.4 + math.sin(phase * 1.3 + d.v2) * 5
			elseif d.v1 == 4 then

				local arm_idx = math.floor(d.v2 / (math.pi * 2) * Arms)
				local arm_angle = (arm_idx / Arms) * math.pi * 2 + phase * 0.3
				local dist = d.v3 * R
				local planet_r = 8 + math.sin(d.v4 * 6) * 4
				local planet_phase = d.v4 + phase * 4
				tx = dist * math.cos(arm_angle) + planet_r * math.cos(planet_phase)
				tz = dist * math.sin(arm_angle) + planet_r * math.sin(planet_phase)
				ty = H * 0.5 + math.sin(arm_angle * 3 + phase) * 15 + planet_r * math.sin(planet_phase * 0.5) * 0.5
			else

				local belt_r = R * 1.1
				local belt_phase = d.v2 + phase * 0.5
				local tilt = math.pi * 0.25
				local bx = belt_r * math.cos(belt_phase)
				local bz = belt_r * math.sin(belt_phase)
				local by = 0
				local cy, sy2 = math.cos(tilt), math.sin(tilt)
				local ry = by * cy - bz * sy2
				local rz = by * sy2 + bz * cy
				tx = bx
				ty = H * 0.8 + ry
				tz = rz

				local node = math.floor(belt_phase / (math.pi * 2) * 12) * (math.pi * 2 / 12)
				local near_node = math.abs(belt_phase % (math.pi * 2 / 12) - math.pi / 12)
				if near_node < 0.15 then
					local pulse = math.sin(phase * 3 + node * 5) * 8
					tx = tx + math.cos(d.v4) * pulse
					tz = tz + math.sin(d.v4) * pulse
				end
			end
			return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Orrery Radius", Min = 40, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Arm Count", Min = 2, Max = 8, Key = "k12", IntOnly = true },
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 50, Key = "k13" },
	{ Type = "Slider", Name = "Height", Min = 50, Max = 500, Key = "k14" }
}

return M