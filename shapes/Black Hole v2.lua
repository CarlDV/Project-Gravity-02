-- Capture, spiral inward, and pack the parts into a single spinning ball.
-- Released parts have no active actuators.
local M = { AlwaysProcess = true, NoBlend = true }
local NAME = "Black Hole v2"
local TAU = math.pi * 2
local UP = Vector3.new(0, 1, 0)

local function state(x6)
    x6.pre = x6.pre or {}
    local st = x6.pre[NAME]
    if not st then
        st = { clock = 0, pull_distance = 0, ball_angle = 0, ball_spin = 0,
            state = "grab", gen = 0, explosion = 0 }
        x6.pre[NAME] = st
    end
    return st
end

local function seed(d, st)
    local r = d.black_hole_v2
    if not r or r.owner ~= st then
        local id = d.slot or d.id or 1
        local y = 2 * ((id * 0.8191725133961645) % 1) - 1
        local a = TAU * ((id * 0.5698402909980532) % 1)
        local flat = math.sqrt(math.max(0, 1 - y * y))
        r = {
            owner = st, roll = (id * 0.6180339887498949) % 1,
            phase = a, dir = Vector3.new(math.cos(a) * flat, y, math.sin(a) * flat),
            rad = ((id * 0.438579021) % 1) ^ (1 / 3),
        }
        d.black_hole_v2 = r
    end
    return r
end

local function explode(p, cen, d, r, st, c)
    d.free_physics = true
    d.angular_velocity = nil
    d.collisions = c.rwNoclip == false
    if r.explosion ~= st.explosion then
        r.explosion = st.explosion
        local away = p.Position - cen
        away = away.Magnitude > 0.5 and away.Unit or r.dir
        local dir = away + r.dir * 0.22 + UP * 0.12
        local speed = math.clamp(c.rwForce or 400, 50, 1500) * (0.75 + r.roll * 0.5)
        d.launch_velocity = dir.Unit * speed
    end
end

local function command(action)
    return function(c, x6, x1)
        local st = state(x6)
        st.state = action
        if action == "grab" then st.gen = st.gen + 1 end
        if action == "explode" then
            st.explosion = st.explosion + 1
            st.explode_at = st.clock
        end
        -- Release also works while paused. The engine owns the actuators;
        -- preview markers never enter this table.
        for p, d in pairs(x6.a or {}) do
            if not d.pc_mode then
                if action == "release" then
                    d.free_physics, d.collisions, d.launch_velocity = true, nil, nil
                    d.angular_velocity = nil
                elseif action == "explode" then
                    local r = seed(d, st)
                    local cen = r.center or (x6.b and x6.b.Position) or p.Position
                    explode(p, cen, d, r, st, c)
                end
                if action ~= "grab" and x6.apply_shape_physics then
                    pcall(x6.apply_shape_physics, p, d)
                end
            end
        end
    end
end

function M.px(t, c, x6, x9, x1)
    local st = state(x6)
    local dt = st.last_t and math.clamp(t - st.last_t, 0, 0.25) or 0
    st.last_t = t
    st.clock = st.clock + dt
    st.pull_distance = st.pull_distance + dt * math.clamp(c.rwPull or 40, 0, 400)
    -- One control drives the ball. Store the angular speed (for each part's own
    -- tumble) and the shared accumulated angle (so the whole ball spins together).
    st.ball_spin = math.rad(math.clamp(c.rwBallSpin or 180, 0, 1440))
    st.ball_angle = (st.ball_angle + st.ball_spin * dt) % TAU
    if st.state == "explode" and st.clock - st.explode_at >= math.clamp(c.rwExplodeTime or 1.6, 0, 5) then
        -- Restore collisions even for a bucketed part whose ownership changed.
        command("release")(c, x6, x1)
    end
end

local function smooth(s) return s * s * (3 - 2 * s) end

function M.f2(p, cen, d, t, c, x1, x6, x9)
    local st = state(x6)
    local r = seed(d, st)
    r.center = cen
    if st.state == "release" then
        d.free_physics, d.collisions = true, nil
        d.angular_velocity = nil
        return p.AssemblyLinearVelocity, p.Position
    elseif st.state == "explode" then
        explode(p, cen, d, r, st, c)
        return d.launch_velocity or p.AssemblyLinearVelocity, p.Position
    end
    d.free_physics, d.launch_velocity = nil, nil
    d.collisions = c.rwNoclip == false
    if r.gen ~= st.gen then
        r.gen, r.last = st.gen, st.clock
        r.pull_start = st.pull_distance
        local off = p.Position - cen
        r.distance = math.max(off.Magnitude, 1)
        r.h0, r.r0 = off.Y, math.sqrt(off.X * off.X + off.Z * off.Z)
        r.angle = math.atan2(off.Z, off.X)
    end
    -- Integrate pull speed once per frame. Changing the slider does not reset
    -- progress, and bucketed parts consume the same distance as every other part.
    local s = math.clamp((st.pull_distance - r.pull_start) / r.distance, 0, 1)
    local pull = smooth(s)
    local bw = smooth(math.clamp((s - 0.35) / 0.65, 0, 1))
    local ball = math.clamp(c.rwBall or 12, 0, 70)
    local ring = math.clamp((c.rwRing or 0) / 100, 0, 1)
    local role = r.roll < ring and 1 or 0
    local floor = role == 1 and (ball * 2.5 + 4) or 0
    local radius = floor + (r.r0 - floor) * (1 - pull)
    local height = r.h0 * (1 - pull)
    -- Orbital speed rises as a part spirals inward (angular momentum feel).
    local mid_s = ((r.progress or 0) + s) * 0.5
    local mid_radius = floor + (r.r0 - floor) * (1 - smooth(mid_s))
    local omega = math.min(math.clamp(c.rwSpin or 10, 0, 30) * 4 / math.max(mid_radius, ball * 0.5, 1), 8)
    r.angle = r.angle + (st.clock - r.last) * omega
    r.last, r.progress = st.clock, s
    if role == 1 then
        local width = math.clamp(c.rwRingWidth or 3, 0, 20)
        radius = radius + r.dir.X * width * bw
        height = height + r.dir.Y * width * 0.45 * bw
    end
    local total = Vector3.new(math.cos(r.angle) * radius, height, math.sin(r.angle) * radius)
    if role == 0 then
        -- A real spinning ball: parts fill a sphere (cube-root radius gives an
        -- even volume) and rotate together about one axis, so the poles hold
        -- still while the equator moves fastest, just like a spinning globe.
        local sphere = CFrame.Angles(0, st.ball_angle, 0) * (r.dir * (r.rad * ball))
        total = total + sphere * bw
        d.angular_velocity = Vector3.new(0, st.ball_spin, 0) * bw
    else
        d.angular_velocity = nil
    end
    local tilt = math.rad(math.clamp(c.rwTilt or 25, 0, 80)) * pull
    local target = cen + CFrame.Angles(tilt, 0, 0) * total
    return (target - p.Position) * (x1.k10 * x9.c1), target
end

M.Controls = {
    { Type = "Button", Name = "Regrab All Parts", Key = "rwRegrab", Callback = command("grab") },
    { Type = "Button", Name = "Stop Grabbing", Key = "rwRelease", Callback = command("release") },
    { Type = "Button", Name = "Explode", Key = "rwExplode", Callback = command("explode") },
    { Type = "Toggle", Name = "Noclip Parts", Key = "rwNoclip", Default = true,
        Desc = "During gathering and the explosion interval. Original collisions return on release." },
    { Type = "Slider", Name = "Pull In Speed", Min = 0, Max = 400, Key = "rwPull", Default = 40, ExactMax = true,
        Desc = "Nominal studs per second toward the core, with a smooth arrival. Zero holds the current spiral radius." },
    { Type = "Slider", Name = "Spiral Speed", Min = 0, Max = 30, Key = "rwSpin", Default = 10, ExactMax = true,
        Desc = "How fast parts orbit while they are being drawn inward." },
    { Type = "Slider", Name = "Ball Spin Speed (deg/s)", Min = 0, Max = 1440, Key = "rwBallSpin", Default = 180, IntOnly = true, ExactMax = true,
        Desc = "How fast the finished ball spins about its axis." },
    { Type = "Slider", Name = "Ball Radius", Min = 0, Max = 70, Key = "rwBall", Default = 12 },
    { Type = "Slider", Name = "Accretion Ring %", Min = 0, Max = 60, Key = "rwRing", Default = 0, IntOnly = true,
        Desc = "Fraction of parts that form a flat orbiting ring instead of joining the ball." },
    { Type = "Slider", Name = "Ring Width", Min = 0, Max = 20, Key = "rwRingWidth", Default = 3 },
    { Type = "Slider", Name = "Disc Tilt", Min = 0, Max = 80, Key = "rwTilt", Default = 25 },
    { Type = "Slider", Name = "Explosion Force", Min = 50, Max = 1500, Key = "rwForce", Default = 400, IntOnly = true },
    { Type = "Slider", Name = "Explosion Noclip Time", Min = 0, Max = 50, Div = 10, Key = "rwExplodeTime", Default = 1.6 },
}

function M.cleanup(x6)
    if x6.pre then x6.pre[NAME] = nil end
end

return M
