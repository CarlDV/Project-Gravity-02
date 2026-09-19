local M = {}
local NAME = "Phoenix Ascendant"
local TAU = math.pi * 2
local PHI = 0.6180339887498949

local UP = Vector3.new(0, 1, 0)
local WORLD_RIGHT = Vector3.new(1, 0, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)

-- The wings flap several times per lap of the flight path. Travelling at the
-- raw wingbeat rate would whip the bird along the curve faster than it could
-- beat its wings, so the path advances at a fraction of it. Both still ride the
-- one Flight Speed slider (k13), which keeps "speed zero holds pose" true for
-- the path as well as the flap.
local PATH_RATE = 0.4

-- The three incommensurate frequencies that make the path wander like Celestial
-- Ribbon's spine rather than close into a plain loop: a Lissajous curve whose X
-- sweeps once while Z loops ~1.6 times and the height rises ~0.58 times, so it
-- never quite repeats and swoops through all three axes.
local FREQ_X, FREQ_Y, FREQ_Z = 1.0, 0.577, 1.618

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, travel = 0, t = t }
		x6.pre[NAME] = st
	end

	-- Wingbeat and flight both ride the one Flight Speed slider so that speed
	-- zero (or a frozen clock) holds the whole pose. The path advances at a
	-- fraction of the flap rate so the bird beats its wings several times per
	-- lap rather than being whipped round the circle.
	local dt = t - st.t
	st.t = t
	local speed = math.clamp(c.k13 or 24, 0, 60) * x9.c2
	st.phase = st.phase + dt * speed
	st.travel = st.travel + dt * speed * PATH_RATE
end

-- A point on the Celestial-Ribbon-style Lissajous path. Move Area (k18) sets the
-- horizontal reach, Swoop Height (k20) the vertical rise.
local function path_point(cen, th, R, h)
	return cen + Vector3.new(math.cos(th * FREQ_X) * R, math.sin(th * FREQ_Y) * h, math.sin(th * FREQ_Z) * R)
end

-- Where the bird is along the wandering path, and the direction it is heading.
-- The heading is a short forward difference along the curve, the same way
-- Celestial Ribbon derives its spine tangent, so the nose follows the swoop
-- through all three axes instead of tracing a flat loop.
local function flight(cen, th, c)
	local R = math.clamp(c.k18 or 250, 0, 800)
	local h = math.clamp(c.k20 or 120, 0, 300)
	local pos = path_point(cen, th, R, h)
	local fwd = path_point(cen, th + 0.05, R, h) - pos
	return pos, (fwd.Magnitude > 0.001) and fwd.Unit or WORLD_FWD
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u, v, w = (id * 0.8191725133961645) % 1, (id * 0.6710436067037893) % 1, (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local span = math.clamp(c.k11 or 160, 40, 400)
	local feathers = math.clamp(math.floor(c.k12 or 14), 4, 28)
	local tail = math.clamp(c.k14 or 180, 30, 500)
	local flap = math.rad(math.clamp(c.k15 or 45, 0, 80))
	local sweep = math.clamp(c.k17 or 45, 10, 100) / 100
	local x, y, z

	if pick < 0.65 then
		-- Paired feathers make a readable silhouette even with a small part budget.
		local side = id % 2 == 0 and 1 or -1
		local feather = math.floor((id - 1) / 2) % feathers
		local s = (feather + 0.5) / feathers
		local length = span * (0.13 + sweep * math.sqrt(math.sin(math.pi * s)))
		local width = span / feathers * 0.48 * math.sin(math.pi * u) ^ 0.7
		local lx = span * s + length * u * 0.18 + (v * 2 - 1) * width
		local ly = span * (0.08 + 0.18 * math.sin(math.pi * s)) - length * u * 0.1
		local angle = flap * math.sin(phase) + 0.15 * s * math.sin(phase - 0.8)
		x = side * (lx * math.cos(angle) - ly * math.sin(angle))
		y = lx * math.sin(angle) + ly * math.cos(angle)
		z = -span * 0.16 * s - length * u + width * 0.12 * math.sin(w * TAU)
	elseif pick < 0.85 then
		local streamer = (id - 1) % 5 - 2
		local wave = u * TAU * 1.4 - phase * 2 + streamer * 0.45
		local r = span * 0.015 * (1 - u) * math.sin(v * TAU)
		x = streamer * span * (0.025 + 0.11 * u) + tail * 0.09 * u * math.sin(wave) + r
		y = -tail * 0.32 * u + tail * 0.12 * u * math.cos(wave)
		z = -span * 0.18 - tail * u
	elseif pick < 0.97 then
		local sy = 1 - 2 * u
		local ring = math.sqrt(math.max(0, 1 - sy * sy))
		local a = v * TAU
		if w < 0.7 then
			x, y, z = span * 0.11 * ring * math.cos(a), span * 0.12 * ring * math.sin(a), span * 0.25 * sy
		else
			x, y, z = span * 0.075 * ring * math.cos(a), span * (0.15 + 0.075 * sy),
				span * (0.23 + 0.075 * ring * math.sin(a))
		end
	else
		-- Beak and three swept crown plumes.
		if w < 0.4 then
			x, y, z = (v - 0.5) * span * 0.06 * (1 - u), span * (0.15 - 0.035 * u), span * (0.29 + 0.14 * u)
		else
			local plume = (id - 1) % 3 - 1
			x, y, z = plume * span * 0.04 * u, span * (0.21 + 0.18 * u), span * (0.22 - 0.12 * u)
		end
	end

	-- Fly the path: lift the whole route to hover height, find the point on it
	-- and the heading there, then build an upright frame around that heading so
	-- the bird turns to face the way it is going. fwd is the local +Z (nose),
	-- right is the local +X (wing line), up stays near world up so it never rolls
	-- fully upside down.
	local center = cen + Vector3.new(0, c.k16 or 100, 0)
	local pos, fwd = flight(center, st and st.travel or 0, c)
	local right = UP:Cross(fwd)
	right = (right.Magnitude > 0.001) and right.Unit or WORLD_RIGHT
	local up = fwd:Cross(right).Unit

	local target = pos + right * x + up * y + fwd * z
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Wing Reach", Min = 40, Max = 400, Key = "k11", Default = 160 },
	{ Type = "Slider", Name = "Feathers per Wing", Min = 4, Max = 28, Key = "k12", Default = 14, IntOnly = true },
	{ Type = "Slider", Name = "Flight Speed", Min = 0, Max = 60, Key = "k13", Default = 24, ExactMax = true },
	{ Type = "Slider", Name = "Tail Length", Min = 30, Max = 500, Key = "k14", Default = 180 },
	{ Type = "Slider", Name = "Wingbeat Angle", Min = 0, Max = 80, Key = "k15", Default = 45 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k16", Default = 100 },
	{ Type = "Slider", Name = "Feather Sweep %", Min = 10, Max = 100, Key = "k17", Default = 45, IntOnly = true },
	{ Type = "Slider", Name = "Flight · Move Area", Min = 0, Max = 800, Key = "k18", Default = 250 },
	{ Type = "Slider", Name = "Flight · Swoop Height", Min = 0, Max = 300, Key = "k20", Default = 120 },
}

return M
