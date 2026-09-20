local M = { ContinuousMotion = true }
local NAME = "Klein Bottle"
local TAU = math.pi * 2

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then st = { phase = 0, t = t }; x6.pre[NAME] = st end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 20, 0, 40) * x9.c2
	st.t = t
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local u = ((id * 0.6180339887498949) % 1) * TAU + phase
	local v = ((id * 0.8191725133961645) % 1) * TAU + phase * 0.5
	local radius = math.clamp(c.k11 or 60, 10, 300)
	local tube = radius * 0.42
	-- Standard figure-eight immersion. The half-angle reverses the cross section
	-- after one turn: (u + 2*pi, v) = (u, -v). Do not wrap u at 2*pi, which
	-- would teleport a slot across that seam. Every term scales with the radius.
	local cu, su = math.cos(u * 0.5), math.sin(u * 0.5)
	local s1, s2 = math.sin(v), math.sin(2 * v)
	local r = radius + tube * (cu * s1 - su * s2)
	local target = cen + Vector3.new(r * math.cos(u), tube * (su * s1 + cu * s2), r * math.sin(u))
	if x6.motion_offset then target = target + x6.motion_offset end
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 10, Max = 300, Key = "k11", Default = 60 },
	{ Type = "Slider", Name = "Flow Speed", Min = 0, Max = 400, Key = "k13", Default = 20, Div = 10, ExactMax = true },
}
return M
