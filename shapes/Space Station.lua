local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Space Station"
	local R, RingThickness, s, CoreRadius = (c.k11 or 80), (c.k12 or 30), (c.k13 or 10) * x9.c2, (c.k14 or 150)
			if not d.v1 then
				d.v1 = math.random()
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random(1, 3)
			end

			local dt = t - (d.last_t or t)
			d.last_t = t
			d.phase = (d.phase or 0) + (dt * s)
			local phase = d.phase + d.v2
			local tx, ty, tz = 0, 0, 0

			if d.v3 == 1 then
				ty = (d.v1 - 0.5) * CoreRadius
				tx = math.cos(phase * 3) * (10 + (d.v1 * 5))
				tz = math.sin(phase * 3) * (10 + (d.v1 * 5))
			elseif d.v3 == 2 then
				local ringPhase = phase * 0.5
				local tubeOffset = (d.v1 - 0.5) * RingThickness
				tx = (R + tubeOffset) * math.cos(ringPhase)
				tz = (R + tubeOffset) * math.sin(ringPhase)
				ty = (math.random() - 0.5) * 5
			else
				local spokeCount = 4
				local spokeAngle = math.floor(d.v2 / (math.pi * 2) * spokeCount) * (math.pi * 2 / spokeCount)
				local spokeSpin = phase * 0.5
				local dist = d.v1 * R
				tx = dist * math.cos(spokeAngle + spokeSpin)
				tz = dist * math.sin(spokeAngle + spokeSpin)
				ty = 0
			end
			local target_pos = cen + Vector3.new(tx, ty, tz)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

M.Controls = {
	{ Type = "Slider", Name = "Ring Radius", Min = 20, Max = 400, Key = "k11" },
	{ Type = "Slider", Name = "Ring Thickness", Min = 5, Max = 100, Key = "k12" },
	{ Type = "Slider", Name = "Orbit Speed", Min = 1, Max = 100, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Spindle Length", Min = 20, Max = 500, Key = "k14" }
}

return M