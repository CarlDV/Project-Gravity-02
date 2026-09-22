-- Gather a canopy of debris, then release it in a falling wave.
-- Kept in the archive/review folder; import as a local plugin to use it.
local M = { Drop = true, NoBlend = true }
local NAME = "Drop"
local TAU = math.pi * 2

local function state(x6)
    x6.pre = x6.pre or {}
    local st = x6.pre[NAME]
    if not st then st = { clock = 0 }; x6.pre[NAME] = st end
    return st
end

function M.px(t, c, x6)
    local st = state(x6)
    st.clock = st.clock + (st.last_t and math.clamp(t - st.last_t, 0, 0.25) or 0)
    st.last_t = t
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
    local st = state(x6)
    local r = d.drop
    if not r or r.owner ~= st then
        local id = d.slot or d.id or 1
        local u = (id * 0.6180339887498949) % 1
        local a = TAU * ((id * 0.7548776662466927) % 1)
        r = { owner = st, start = st.clock, origin = p.Position,
            spread = Vector3.new(math.cos(a), 0, math.sin(a)) * math.sqrt(u), rank = u }
        d.drop = r
    end
    local gather = math.clamp(c.dpGather or 2.5, 0.2, 12)
    local hold = math.clamp(c.dpHold or 0.8, 0, 10)
    local wave = math.clamp(c.dpWave or 1.2, 0, 8) * r.rank
    local age = st.clock - r.start
    local release_at = st.drop_at and (st.drop_at + wave) or (r.start + gather + hold + wave)
    if st.clock >= release_at then
        local incoming = c.dpMomentum and p.AssemblyLinearVelocity or Vector3.zero
        d.release_velocity = incoming + Vector3.new(0, -math.clamp(c.dpDown or 35, 0, 250), 0)
            + r.spread * math.clamp(c.dpScatter or 8, 0, 120)
        d.unclaim = true
        return d.release_velocity, p.Position
    end
    local goal = cen + Vector3.new(0, math.clamp(c.dpHeight or 75, 0, 250), 0)
        + r.spread * math.clamp(c.dpRadius or 30, 0, 180)
    local s = math.clamp(age / gather, 0, 1)
    local target = r.origin + (goal - r.origin) * (s * s * (3 - 2 * s))
    -- No teleport and no manual gravity. The engine removes the actuators
    -- and restores each part's own collision and material properties.
    return (target - p.Position) * (x1.k10 * x9.c1), target
end

M.Controls = {
    { Type = "Button", Name = "Drop Now", Key = "dpDrop", Callback = function(c, x6)
        local st = state(x6); st.drop_at = st.clock
    end },
    { Type = "Slider", Name = "Gather Time", Min = 2, Max = 120, Div = 10, Key = "dpGather", Default = 2.5 },
    { Type = "Slider", Name = "Hold Time", Min = 0, Max = 100, Div = 10, Key = "dpHold", Default = 0.8 },
    { Type = "Slider", Name = "Drop Height", Min = 0, Max = 250, Key = "dpHeight", Default = 75 },
    { Type = "Slider", Name = "Spread Radius", Min = 0, Max = 180, Key = "dpRadius", Default = 30 },
    { Type = "Slider", Name = "Release Wave", Min = 0, Max = 80, Div = 10, Key = "dpWave", Default = 1.2 },
    { Type = "Slider", Name = "Downward Speed", Min = 0, Max = 250, Key = "dpDown", Default = 35, ExactMax = true },
    { Type = "Slider", Name = "Scatter Speed", Min = 0, Max = 120, Key = "dpScatter", Default = 8, ExactMax = true },
    { Type = "Toggle", Name = "Keep Incoming Momentum", Key = "dpMomentum", Default = false },
}

function M.cleanup(x6)
    if x6.pre then x6.pre[NAME] = nil end
end
return M
