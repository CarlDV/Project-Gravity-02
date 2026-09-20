local M = { ContinuousMotion = true }
local NAME = "Möbius Strip"
local TAU = math.pi * 2

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then st = { phase = 0, t = t }; x6.pre[NAME] = st end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 15, 0, 40) * x9.c2
	st.t = t
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local st = x6.pre and x6.pre[NAME]
	local angle = ((id * 0.6180339887498949) % 1) * TAU + (st and st.phase or 0)
	local width = (((id * 0.8191725133961645) % 1) * 2 - 1) * math.clamp(c.k12 or 20, 5, 200)
	-- Follow the double cover continuously. One turn swaps the two edges; only
	-- two turns return a particle to its starting point on a Mobius strip.
	local r = math.clamp(c.k11 or 50, 10, 300) + width * math.cos(angle * 0.5)
	local target = cen + Vector3.new(r * math.cos(angle), width * math.sin(angle * 0.5), r * math.sin(angle))
	if x6.motion_offset then target = target + x6.motion_offset end
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 10, Max = 300, Key = "k11", Default = 50 },
	{ Type = "Slider", Name = "Width", Min = 5, Max = 200, Key = "k12", Default = 20 },
	{ Type = "Slider", Name = "Flow Speed", Min = 0, Max = 400, Key = "k13", Default = 15, Div = 10, ExactMax = true },
}
return M
