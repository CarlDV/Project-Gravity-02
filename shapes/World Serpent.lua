local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "World Serpent"
	local Length, Amplitude, s, Wavelength =
				(c.k11 or 400), (c.k12 or 100), (c.k13 or 20) * x9.c2, (c.k14 or 20) * 10
			if not d.v1 then
				d.v1 = math.random()
			end

			local phase = t * s
			local pos_along_body = d.v1 * Length


			local wave_offset = (pos_along_body - (phase * 500)) / Wavelength


			local outer_radius = Length / math.pi
			local angle = (pos_along_body / Length) * math.pi * 2 + phase

			local undulation_y = math.sin(wave_offset * math.pi * 2) * Amplitude
			local undulation_r = math.cos(wave_offset * math.pi * 2) * (Amplitude * 0.5)

			local current_radius = outer_radius + undulation_r
			local tx = current_radius * math.cos(angle)
			local tz = current_radius * math.sin(angle)
			local ty = undulation_y

			return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Snake Length", Min = 100, Max = 2000, Key = "k11" },
	{ Type = "Slider", Name = "Wave Height", Min = 10, Max = 500, Key = "k12" },
	{ Type = "Slider", Name = "Move Speed", Min = 1, Max = 100, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Frequency", Min = 10, Max = 200, Key = "k14" }
}

return M