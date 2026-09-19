local M = {}
local NAME = "Astral Kraken"
local TAU = math.pi * 2
local PHI = 0.6180339887498949
local UP = Vector3.new(0, 1, 0)

-- One clock for the creature, including parts claimed after it started moving.
-- Signed deltas preserve Formation Time Scale's freeze and reverse controls.
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

local function tentacle(u, arm, count, radius, reach, curl, phase)
	local bend = u * curl * TAU - phase * 1.8 + arm * 0.7
	local r = radius * 0.72 + reach * (0.9 * u + 0.22 * u * u * math.sin(bend))
	local a = arm * TAU / count + 0.24 * u * math.sin(phase + arm) + 0.15 * u * math.sin(bend)
	local y = radius * 0.12 - reach * 0.48 * u + reach * 0.22 * u * u * math.cos(bend)
	return Vector3.new(r * math.cos(a), y, r * math.sin(a))
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u, v, w = (id * 0.8191725133961645) % 1, (id * 0.6710436067037893) % 1, (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local radius = math.clamp(c.k11 or 38, 10, 120)
	local count = math.clamp(math.floor(c.k12 or 8), 4, 16)
	local reach = math.clamp(c.k14 or 180, 40, 500)
	local curl = math.clamp(c.k15 or 1.5, 0, 4)
	local thickness = math.clamp(c.k16 or 7, 1, 25)
	local offset

	if pick < 0.72 then
		local arm = (id - 1) % count
		local base = tentacle(u, arm, count, radius, reach, curl, phase)
		local tangent = tentacle(u + 0.002, arm, count, radius, reach, curl, phase) - base
		local along = tangent.Magnitude > 0.0001 and tangent.Unit or UP
		local side = along:Cross(UP)
		side = side.Magnitude > 0.0001 and side.Unit or Vector3.new(1, 0, 0)
		local normal = side:Cross(along)
		local r = thickness * (0.08 + 0.92 * (1 - u) ^ 1.2)
		-- Raised sucker ridges follow the moving tube instead of floating around it.
		r = r * (1 + 0.22 * math.cos(u * 36 * math.pi))
		local a = v * TAU
		offset = base + side * (r * math.cos(a)) + normal * (r * math.sin(a))
	elseif pick < 0.96 then
		local y = 1 - 2 * u
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = v * TAU
		local breathe = 1 + 0.055 * math.sin(phase * 2)
		local ribs = 1 + 0.06 * math.cos(a * count)
		offset = Vector3.new(radius * r * math.cos(a) * breathe * ribs,
			radius * (0.9 + y * 1.18), radius * r * math.sin(a) * breathe * ribs)
	else
		-- Two raised eyes on the forward face of the mantle.
		local side = id % 2 == 0 and 1 or -1
		local a, r = u * TAU, radius * (0.055 + 0.12 * math.sqrt(w))
		offset = Vector3.new(side * radius * 0.4 + r * math.cos(a),
			radius * 1.12 + r * math.sin(a), radius * 0.92)
	end

	local turn = phase * 0.12
	local ca, sa = math.cos(turn), math.sin(turn)
	local target = cen + Vector3.new(offset.X * ca - offset.Z * sa,
		offset.Y + (c.k17 or 120), offset.X * sa + offset.Z * ca)
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Mantle Radius", Min = 10, Max = 120, Key = "k11", Default = 38 },
	{ Type = "Slider", Name = "Tentacles", Min = 4, Max = 16, Key = "k12", Default = 8, IntOnly = true },
	{ Type = "Slider", Name = "Motion Speed", Min = 0, Max = 40, Key = "k13", Default = 8, ExactMax = true },
	{ Type = "Slider", Name = "Tentacle Reach", Min = 40, Max = 500, Key = "k14", Default = 180 },
	{ Type = "Slider", Name = "Tentacle Curls", Min = 0, Max = 40, Key = "k15", Default = 1.5, Div = 10 },
	{ Type = "Slider", Name = "Tentacle Thickness", Min = 1, Max = 25, Key = "k16", Default = 7 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k17", Default = 120 },
}

return M
