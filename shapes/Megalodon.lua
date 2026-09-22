local M = {}
M.ContinuousMotion = true
local NAME = "Megalodon"
local TAU = math.pi * 2
local PHI = 0.6180339887498949
local UP = Vector3.new(0, 1, 0)
local WORLD_FWD = Vector3.new(0, 0, 1)
local flight, build_spine

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, travel = 0, t = t }
		x6.pre[NAME] = st
	end
	local step = (t - st.t) * math.clamp(c.k13 or 7, 0, 40) * x9.c2
	st.phase = st.phase + step
	st.travel = st.travel + step * 0.8
	st.t = t
	st.flight = flight(st.travel, c)
	build_spine(st, c)
end

-- A three-dimensional patrol with a tangent-aligned nose and anticipatory bank.
-- The path is independent of the tail beat, but Hunt Speed drives both clocks.
flight = function(th, c)
    local reach = math.clamp(c.k17 or 100, 0, 300)
    local height = math.clamp(c.k18 or 55, 0, 200)
    local pos = Vector3.new(reach * (math.cos(th) - 1),
        math.clamp(c.k16 or 160, -100, 500) + height * math.sin(th * 0.65),
        reach * math.sin(th * 1.4))
    local dx, dy, dz = -reach * math.sin(th), height * 0.65 * math.cos(th * 0.65),
        reach * 1.4 * math.cos(th * 1.4)
    local flat = math.sqrt(dx * dx + dz * dz)
    local heading = flat > 0.0001 and Vector3.new(dx / flat, 0, dz / flat) or WORLD_FWD
    local pitch = math.atan2(dy, math.sqrt(flat * flat + (height * 0.4) ^ 2 + 1))
    local forward = heading * math.cos(pitch) + UP * math.sin(pitch)
    local right = UP:Cross(heading).Unit
    local up = forward:Cross(right).Unit
    local ddx, ddz = -reach * math.cos(th), -reach * 1.96 * math.sin(th * 1.4)
    local turn = (dz * ddx - dx * ddz) / (flat * flat + reach * reach * 0.2 + 1)
    local bank = math.rad(math.clamp(c.k19 or 20, 0, 55)) * turn / math.sqrt(1 + turn * turn)
    local ca, sa = math.cos(bank), math.sin(bank)
    right, up = right * ca + up * sa, up * ca - right * sa
    return { pos = pos, right = right, up = up, fwd = forward }
end

local function mix_frame(a, b, f)
    local forward = (a.fwd + (b.fwd - a.fwd) * f).Unit
    local right = (a.right + (b.right - a.right) * f).Unit
    local up = forward:Cross(right).Unit
    right = up:Cross(forward).Unit
    return a.pos + (b.pos - a.pos) * f, right, up
end

build_spine = function(st, c)
    local follow = math.clamp(c.k20 or 75, 0, 100) / 100
    local back, front = math.clamp(c.k11 or 140, 50, 300) * 1.45, math.clamp(c.k11 or 140, 50, 300)
    local steps = 24
    st.back_step, st.front_step = back / steps, front / steps
    st.back, st.front = { st.flight }, { st.flight }
    for i = 1, steps do
        local fraction = i / steps
        local trailing = flight(st.travel - follow * fraction * 0.8, c)
        local leading = flight(st.travel + follow * fraction * 0.16, c)
        local prev_back, prev_front = st.back[i], st.front[i]
        trailing.pos = prev_back.pos - (prev_back.fwd + trailing.fwd).Unit * st.back_step
        leading.pos = prev_front.pos + (prev_front.fwd + leading.fwd).Unit * st.front_step
        st.back[i + 1], st.front[i + 1] = trailing, leading
    end
end

local function on_spine(st, z)
    local frames = z < 0 and st.back or st.front
    local step = z < 0 and st.back_step or st.front_step
    local q = math.clamp(math.abs(z) / step, 0, #frames - 1)
    local i = math.min(math.floor(q) + 1, #frames - 1)
    return mix_frame(frames[i], frames[i + 1], q - (i - 1))
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u = (id * 0.8191725133961645) % 1
	local v = (id * 0.6710436067037893) % 1
	local w = (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0

	local length = math.clamp(c.k11 or 140, 50, 300)
	local girth = math.clamp(c.k12 or 38, 12, 90)
	local fin = math.clamp(c.k14 or 100, 30, 240)
	local gape = math.clamp(c.k15 or 30, 0, 80) / 100
	local size = p.Size
	if size and math.max(size.X, size.Y, size.Z) > girth * 0.7 and pick > 0.9 then pick = pick % 0.57 end
	local x, y, z
	if pick < 0.57 then
		local q = 2 * u - 1
		local ring = math.sqrt(math.max(0, 1 - q * q))
		x, y, z = girth * ring * math.cos(v * TAU), girth * 0.85 * ring * math.sin(v * TAU), length * q
		if q > 0.5 then y = y + (y >= 0 and 1 or -1) * girth * gape * (q - 0.5) end
	elseif pick < 0.72 then
		local a = math.sqrt(u)
		local b = v * a
		x = (w - 0.5) * girth * 0.18 * (1 - b)
		y = girth * (1 - a) + (girth + fin) * b + girth * 0.6 * (a - b)
		z = length * (0.12 * (1 - a) - 0.15 * b - 0.6 * (a - b))
	elseif pick < 0.90 then
		local side = id % 2 == 0 and 1 or -1
		local a = math.sqrt(u)
		x = side * (girth * 0.5 + fin * a)
		y = -girth * 0.45 - fin * 0.14 * a
		z = length * (-0.05 - a * 0.5 - v * (1 - a) * 0.55)
	else
		local side = id % 2 == 0 and 1 or -1
		x = (w - 0.5) * girth * 0.16 * (1 - u)
		y = side * fin * u * (side > 0 and 1 or 0.75)
		z = -length * (0.88 + 0.4 * u + v * 0.15 * (1 - u))
	end
	-- A travelling wave grows toward the tail; the rigid snout stays readable.
	local aft = math.max(0, -z / length)
	x = x + girth * 0.22 * aft * aft * math.sin(phase * 1.5 + z / length * 2)
	if not st then
		st = { travel = 0, flight = flight(0, c) }
		build_spine(st, c)
	end
	local center, right, up = on_spine(st, z)
	local target = cen + center + right * x + up * y
	-- Compact by default for disaster-map rubble. Keep the height anchor fixed
	-- while scaling the silhouette, so wall panels help fill broad surfaces.
	local pivot = cen + Vector3.new(0, c.k16 or 160, 0)
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
	{ Type = "Slider", Name = "Patrol Swoop Height", Min = 0, Max = 200, Key = "k18", Default = 55 },
	{ Type = "Slider", Name = "Turn Banking", Min = 0, Max = 55, Key = "k19", Default = 20 },
	{ Type = "Slider", Name = "Body Follow Through %", Min = 0, Max = 100, Key = "k20", Default = 75, IntOnly = true },
	{ Type = "Slider", Name = "Debris Scale %", Min = 25, Max = 150, Key = "k24", Default = 55, IntOnly = true,
		Desc = "Smaller formations stay denser with limited rubble. Increase for more or larger parts." },
	{ Type = "Slider", Name = "Body Half Length", Min = 50, Max = 300, Key = "k11", Default = 140 },
	{ Type = "Slider", Name = "Body Girth", Min = 12, Max = 90, Key = "k12", Default = 38 },
	{ Type = "Slider", Name = "Hunt Speed", Min = 0, Max = 40, Key = "k13", Default = 7, ExactMax = true },
	{ Type = "Slider", Name = "Fin Reach", Min = 30, Max = 240, Key = "k14", Default = 100 },
	{ Type = "Slider", Name = "Jaw Opening %", Min = 0, Max = 80, Key = "k15", Default = 30 },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k16", Default = 160 },
	{ Type = "Slider", Name = "Patrol Reach", Min = 0, Max = 300, Key = "k17", Default = 100 },
}

return M
