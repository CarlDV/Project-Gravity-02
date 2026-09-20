local M = {}
M.ContinuousMotion = true
local NAME = "Ouroboros"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 8, 0, 40) * x9.c2
	st.t = t
end

-- An analytic moving frame: radial and tangent remain perpendicular even when
-- the vertical serpent loop ripples out of its plane. No world-up cross product
-- can flip the scales or horns at the top and bottom of the loop.
local function spine(a, radius, wave, phase)
	local ca, sa = math.cos(a), math.sin(a)
	local z = wave * math.sin(3 * a - phase)
	local dz = wave * 3 * math.cos(3 * a - phase)
	local center = Vector3.new(radius * ca, radius * sa, z)
	local normal = Vector3.new(ca, sa, 0)
	local tangent = Vector3.new(-radius * sa, radius * ca, dz).Unit
	return center, normal, tangent:Cross(normal).Unit, tangent
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u = (id * 0.8191725133961645) % 1
	local v = (id * 0.6710436067037893) % 1
	local w = (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local radius = math.clamp(c.k11 or 145, 50, 350)
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > radius * 0.18 and pick >= 0.65 then
		pick = pick % 0.65
	end
	-- Preserve an open central hole even with the largest thickness setting.
	local thick = math.min(math.clamp(c.k12 or 20, 5, 60), radius * 0.28)
	local wave = math.clamp(c.k14 or 28, 0, 100)
	local spines = math.clamp(math.floor(c.k15 or 32), 8, 64)
	local crown = math.clamp(c.k16 or 35, 0, 100)
	local jaw = math.clamp(c.k18 or 35, 0, 70) / 100
	local offset
	if pick < 0.65 then
		local a = 0.16 + u * (TAU - 0.25)
		local center, normal, binormal = spine(a, radius, wave, phase)
		-- A long taper feeds the tail into the mouth at the seam.
		local taper = 0.12 + 0.88 * math.sin(math.pi * math.min(1, (1 - u) * 4) * 0.5)
		local scales = 1 + 0.09 * math.cos(a * spines + 0.7 * math.sin(v * TAU * 5))
		local r = thick * taper * scales
		offset = center + normal * (r * math.cos(v * TAU)) + binormal * (r * math.sin(v * TAU))
	elseif pick < 0.80 then
		local tooth = (id - 1) % spines
		local a = 0.22 + (tooth + 0.5) / spines * (TAU - 0.5)
		local center, normal, binormal, tangent = spine(a, radius, wave, phase)
		local fin = crown * math.sin(math.pi * u) ^ 0.8 * (0.4 + 0.6 * math.sin(a * 0.5))
		offset = center + normal * (thick + fin) + tangent * ((u - 0.5) * radius * TAU / spines * 0.85)
			+ binormal * ((v - 0.5) * thick * 0.18 * math.sin(math.pi * u))
	elseif pick < 0.94 then
		local center, normal, binormal, tangent = spine(0, radius, wave, phase)
		local angle = v * TAU
		local sy = 1 - 2 * u
		local ring = math.sqrt(math.max(0, 1 - sy * sy))
		local side = math.sin(angle) >= 0 and 1 or -1
		local gape = thick * jaw * (0.7 + 0.3 * math.sin(phase * 1.7))
		offset = center + tangent * (thick * (0.15 + 1.8 * sy))
			+ normal * (thick * 1.25 * ring * math.cos(angle))
			+ binormal * (thick * 0.9 * ring * math.sin(angle) + side * gape)
	else
		local center, normal, binormal, tangent = spine(0, radius, wave, phase)
		local side = id % 2 == 0 and 1 or -1
		if w < 0.4 then
			-- Raised eye rings on the two sides of the dragon's head.
			local eye = thick * (0.14 + 0.05 * v)
			offset = center + tangent * (thick * 0.5 + eye * math.cos(u * TAU))
				+ normal * (thick * 0.72 + eye * math.sin(u * TAU)) + binormal * (side * thick * 0.9)
		else
			local horn = crown * u
			offset = center - tangent * (thick + horn * 0.5) + normal * (thick * 0.7 + horn)
				+ binormal * (side * (thick * 0.7 + horn * 0.28))
		end
	end
	-- Roll the entire loop, then tip it slightly in depth. All anatomy uses the
	-- same transform, including the tail-to-jaw join.
	local roll = phase * 0.18
	local ca, sa = math.cos(roll), math.sin(roll)
	local x, y = offset.X * ca - offset.Y * sa, offset.X * sa + offset.Y * ca
	local tilt = math.rad(math.clamp(c.k19 or 18, -70, 70))
	local ct, sn = math.cos(tilt), math.sin(tilt)
	local target = cen + Vector3.new(x, y * ct - offset.Z * sn + math.clamp(c.k17 or 210, -100, 600),
		y * sn + offset.Z * ct)
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k17 or 210, 0)
	target = pivot + (target - pivot) * (math.clamp(c.k24 or 55, 25, 150) / 100)
	-- The runtime supplies this even at speed zero or Formation Time Scale zero.
	-- The same offset on every piece keeps the silhouette intact while it moves.
	if x6.motion_offset then target = target + x6.motion_offset end
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Debris Scale %", Min = 25, Max = 150, Key = "k24", Default = 55, IntOnly = true,
		Desc = "Smaller formations stay denser with limited rubble. Increase for more or larger parts." },
	{ Type = "Slider", Name = "Serpent Radius", Min = 50, Max = 350, Key = "k11", Default = 145 },
	{ Type = "Slider", Name = "Body Thickness", Min = 5, Max = 60, Key = "k12", Default = 20 },
	{ Type = "Slider", Name = "Coil Speed", Min = 0, Max = 40, Key = "k13", Default = 8, ExactMax = true },
	{ Type = "Slider", Name = "Body Undulation", Min = 0, Max = 100, Key = "k14", Default = 28 },
	{ Type = "Slider", Name = "Dorsal Fins", Min = 8, Max = 64, Key = "k15", Default = 32, IntOnly = true },
	{ Type = "Slider", Name = "Crown and Fin Reach", Min = 0, Max = 100, Key = "k16", Default = 35 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 600, Key = "k17", Default = 210 },
	{ Type = "Slider", Name = "Jaw Opening %", Min = 0, Max = 70, Key = "k18", Default = 35, IntOnly = true },
	{ Type = "Slider", Name = "Loop Tilt", Min = -70, Max = 70, Key = "k19", Default = 18 },
}

return M
