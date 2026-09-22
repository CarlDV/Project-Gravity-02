local M = { ContinuousMotion = true }
local NAME = "Orbit Bloom"

local function state(x6)
    x6.pre = x6.pre or {}
    local st = x6.pre[NAME]
    if not st then st = { phase = 0 }; x6.pre[NAME] = st end
    return st
end

function M.px(t, c, x6, x9, x1)
    local st = state(x6)
    local dt = st.last_t and (t - st.last_t) or 0
    st.last_t = t
    st.phase = st.phase + dt * math.clamp(c.speed or 8, 0, 40) * x9.c2
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
    local st = state(x6)
    local id = d.slot or d.id or 1
    local a = id * 2.399963229728653 + st.phase
    local radius = math.clamp(c.radius or 40, 0, 150)
    local target = cen + Vector3.new(math.cos(a) * radius,
        20 + (c.bob and math.sin(a * 3 + st.phase) * 8 or 0), math.sin(a) * radius)
    if x6.motion_offset then target = target + x6.motion_offset end
    return (target - p.Position) * (x1.k10 * x9.c1), target
end

M.Controls = {
    { Type = "Slider", Name = "Radius", Key = "radius", Min = 0, Max = 150, Default = 40 },
    { Type = "Slider", Name = "Orbit Speed", Key = "speed", Min = 0, Max = 40, Default = 8, ExactMax = true },
    { Type = "Toggle", Name = "Petal Wave", Key = "bob", Default = true },
    { Type = "Button", Name = "Restart Orbit", Key = "restart", Callback = function(c, x6)
        state(x6).phase = 0
    end },
}

function M.cleanup(x6, x1)
    if x6.pre then x6.pre[NAME] = nil end
end

return M
