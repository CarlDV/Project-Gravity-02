local M = { ContinuousMotion = true }
local NAME = "Torus Knot"
local TAU = math.pi * 2
local PHI = 0.6180339887498949
local RES = 512

local function layout(c)
	local p, q = math.clamp(math.floor(c.k11 or 3), 1, 10), math.clamp(math.floor(c.k12 or 2), 1, 10)
	local major, minor = math.clamp(c.k14 or 50, 10, 300), math.clamp(c.k15 or 20, 5, 100)
	local a, b = p, q
	while b ~= 0 do a, b = b, a % b end
	local out = { p = p / a, q = q / a, count = a, major = major, minor = minor, lanes = {} }
	for lane = 0, a - 1 do
		-- A non-coprime pair describes a torus LINK. Offsetting its minor angle
		-- gives gcd(p,q) distinct components instead of retracing one curve.
		local offset = lane * TAU / p
		local lengths = { 0 }
		local total = 0
		local function speed(t)
			local r = major + minor * math.cos(out.q * t + offset)
			return math.sqrt((out.p * r) ^ 2 + (out.q * minor) ^ 2)
		end
		local previous = speed(0)
		for i = 1, RES do
			local current = speed(i * TAU / RES)
			total = total + (previous + current) * 0.5 * TAU / RES
			lengths[i + 1], previous = total, current
		end
		out.lanes[lane + 1] = { offset = offset, lengths = lengths, total = total }
	end
	return out
end

local function point(st, id, phase)
	local lane = st.lanes[(id - 1) % st.count + 1]
	local localId = math.floor((id - 1) / st.count) + 1
	local distance = ((localId * PHI + phase / TAU) % 1) * lane.total
	local lo, hi = 1, RES + 1
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if lane.lengths[mid] <= distance then lo = mid else hi = mid end
	end
	local fraction = (distance - lane.lengths[lo]) / (lane.lengths[hi] - lane.lengths[lo])
	local t = (lo - 1 + fraction) * TAU / RES
	local minor = st.q * t + lane.offset
	local r = st.major + st.minor * math.cos(minor)
	return Vector3.new(r * math.cos(st.p * t), st.minor * math.sin(minor), r * math.sin(st.p * t))
end

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then st = { phase = 0, t = t }; x6.pre[NAME] = st end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 10, 0, 40) * x9.c2
	st.t = t
	local key = table.concat({ c.k11 or 3, c.k12 or 2, c.k14 or 50, c.k15 or 20 }, ":")
	if st.key ~= key then st.layout, st.key = layout(c), key end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local st = x6.pre and x6.pre[NAME]
	local target = cen + point(st and st.layout or layout(c), d.slot or d.id or 1, st and st.phase or 0)
	if x6.motion_offset then target = target + x6.motion_offset end
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "P Knot", Min = 1, Max = 10, Key = "k11", Default = 3, IntOnly = true },
	{ Type = "Slider", Name = "Q Knot", Min = 1, Max = 10, Key = "k12", Default = 2, IntOnly = true },
	{ Type = "Slider", Name = "Flow Speed", Min = 0, Max = 400, Key = "k13", Default = 10, Div = 10, ExactMax = true },
	{ Type = "Slider", Name = "Radius", Min = 10, Max = 300, Key = "k14", Default = 50 },
	{ Type = "Slider", Name = "Tube Size", Min = 5, Max = 100, Key = "k15", Default = 20 },
}
return M
