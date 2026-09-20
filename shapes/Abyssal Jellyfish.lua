local M = {}
M.ContinuousMotion = true
local NAME = "Abyssal Jellyfish"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 10, 0, 40) * x9.c2
	st.t = t
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u = (id * 0.8191725133961645) % 1
	local v = (id * 0.6710436067037893) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local radius = math.clamp(c.k11 or 100, 25, 250)
	local size = p.Size
	-- Wall panels build the broad bell; fine debris draws the trailing anatomy.
	if size and math.max(size.X, size.Y, size.Z) > radius * 0.22 and pick >= 0.47 then
		pick = pick % 0.35
	end
	local arms = math.clamp(math.floor(c.k12 or 12), 4, 24)
	local length = math.clamp(c.k14 or 240, 40, 600)
	local pulse = math.clamp(c.k15 or 35, 0, 70) / 100
	local curl = math.clamp(c.k16 or 1.5, 0, 4)
	-- Bell, rim and tendril roots share the same contraction, so the creature
	-- remains attached through its swimming stroke.
	local beat = 0.5 + 0.5 * math.sin(phase)
	local spread = radius * (1 - pulse * 0.42 * beat)
	local height = radius * (0.65 + pulse * 0.5 * beat)
	local x, y, z
	if pick < 0.35 then
		-- Uniform cos(theta) avoids a clump at the top of the bell.
		local ct = u
		local sr = math.sqrt(math.max(0, 1 - ct * ct))
		local a = v * TAU
		local ribs = 1 + 0.035 * math.cos(a * arms) * sr * sr
		x, z = spread * sr * math.cos(a) * ribs, spread * sr * math.sin(a) * ribs
		y = height * ct + radius * 0.025 * math.cos(a * arms) * sr ^ 4
	elseif pick < 0.47 then
		-- A scalloped lip keeps the umbrella readable with a few hundred parts.
		local a = u * TAU
		local r = spread * (1 + 0.035 * math.cos(a * arms)) + radius * 0.018 * math.cos(v * TAU)
		x, z = r * math.cos(a), r * math.sin(a)
		y = radius * 0.025 * math.cos(a * arms) + radius * 0.018 * math.sin(v * TAU)
	elseif pick < 0.87 then
		local arm = (id - 1) % arms
		local a = arm * TAU / arms
		local wave = u * curl * TAU - phase * 1.4 + arm * 0.47
		-- The u^2 envelope leaves the root still and lets the tip curl freely.
		local sway = length * 0.13 * u * u
		local r = spread * 1.035 * (1 - 0.26 * u) + sway * math.sin(wave)
		local sideways = sway * math.cos(wave)
		local tube = radius * 0.016 * (1 - 0.85 * u)
		x = r * math.cos(a) - sideways * math.sin(a) + tube * math.cos(v * TAU)
		z = r * math.sin(a) + sideways * math.cos(a) + tube * math.sin(v * TAU)
		y = radius * 0.025 - length * u + sway * 0.35 * math.sin(wave + 0.7)
	else
		-- Four broad, folded oral ribbons inside the fine outer tentacles.
		local arm = (id - 1) % 4
		local a = arm * TAU / 4 + u * curl * 2 - phase * 0.25
		local r = radius * (0.13 + 0.2 * u) + radius * 0.07 * u * math.sin(u * 18 - phase)
		local width = radius * 0.14 * (1 - 0.7 * u) * (2 * v - 1)
		x, z = r * math.cos(a) - width * math.sin(a), r * math.sin(a) + width * math.cos(a)
		y = height * 0.32 - length * 0.7 * u + radius * 0.06 * math.sin(v * TAU * 2 + u * 24 - phase) * u
	end
	local drift = math.clamp(c.k18 or 45, 0, 200)
	local turn = phase * 0.12
	local ca, sa = math.cos(turn), math.sin(turn)
	local target = cen + Vector3.new(x * ca - z * sa + drift * math.sin(phase * 0.31),
		y + math.clamp(c.k17 or 280, -100, 700) + drift * 0.3 * math.sin(phase * 0.7),
		x * sa + z * ca + drift * math.sin(phase * 0.23))
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k17 or 280, 0)
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
	{ Type = "Slider", Name = "Bell Radius", Min = 25, Max = 250, Key = "k11", Default = 100 },
	{ Type = "Slider", Name = "Trailing Tentacles", Min = 4, Max = 24, Key = "k12", Default = 12, IntOnly = true },
	{ Type = "Slider", Name = "Swim Speed", Min = 0, Max = 40, Key = "k13", Default = 10, ExactMax = true },
	{ Type = "Slider", Name = "Tentacle Length", Min = 40, Max = 600, Key = "k14", Default = 240 },
	{ Type = "Slider", Name = "Bell Pulse %", Min = 0, Max = 70, Key = "k15", Default = 35, IntOnly = true },
	{ Type = "Slider", Name = "Tentacle Curls", Min = 0, Max = 40, Key = "k16", Default = 1.5, Div = 10 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 700, Key = "k17", Default = 280 },
	{ Type = "Slider", Name = "Drift Reach", Min = 0, Max = 200, Key = "k18", Default = 45 },
}

return M
