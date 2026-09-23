-- Offline trajectories for the changed shapes, run by tools/test_luau.py.
-- Controlled pieces follow targets; released pieces use a gravity/floor fixture.
package.path = "tests/?.lua;" .. package.path
require("robloxenv")
local Controls = assert(loadfile("PluginControls.lua"))()
local Physics = assert(loadfile("ShapePhysics.lua"))()
local config = assert(loadfile("config.lua"))()
local kind, count, frames = arg[1] or "creatures", tonumber(arg[2]) or 512, tonumber(arg[3]) or 96
local duration = kind == "creatures" and 12 or 6
local names = kind == "creatures" and { "Phoenix Ascendant", "Megalodon" } or { "Black Hole v2", "Drop" }
local x9, dt = { c1 = 0.15, c2 = 0.05 }, 1 / 60
local sizes = { Vector3.new(4, 2, 2), Vector3.new(8, 2, 4), Vector3.new(12, 1.6, 3),
    Vector3.new(20, 2, 6), Vector3.new(32, 2, 12) }
local function vector(v)
    assert(v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6, "non-finite sample")
    return string.format("[%.4f,%.4f,%.4f]", v.X, v.Y, v.Z)
end

local output = {}
for _, name in ipairs(names) do
    local path = (name == "Drop" and "shapes-onreview/" or "shapes/") .. name .. ".lua"
    local mod = assert(loadfile(path))()
    local c = table.clone(config.x2[name] or Controls.defaults(mod.Controls))
    if name == "Black Hole v2" then c.rwPull, c.rwForce, c.rwExplodeTime = 60, 70, 0.8 end
    local cen = kind == "creatures" and Vector3.zero or Vector3.new(0, 60, 0)
    local x6 = { pre = {}, a = {}, n = count, f = 0, b = { Position = cen } }
    x6.apply_shape_physics = function(p, d) return Physics.apply(p, d, config.x1) end
    local parts, records, dimensions = {}, {}, {}
    for id = 1, count do
        local a = id * 2.399963229728653
        local r = 90 * math.sqrt((id * 0.754877666) % 1)
        local size = sizes[(id % 17 == 0) and 5 or ((id - 1) % 4 + 1)]
        local p = { Size = size, Position = Vector3.new(math.cos(a) * r, 10 + (id * 0.81917 % 1) * 35, math.sin(a) * r),
            AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero,
            CanCollide = true, Anchored = false }
        local d = { id = id, original_can_collide = true, original_anchored = false,
            lv = { Enabled = true }, av = { Enabled = true } }
        parts[id], records[id], dimensions[id], x6.a[p] = p, d, vector(size), d
    end
    local function action(key)
        for _, control in ipairs(mod.Controls or {}) do
            if control.Key == key then assert(Controls.activate(control, c, x6, config.x1)); return end
        end
    end
    local sampled, labels, next_frame = {}, {}, 0
    local exploded, regrabbed = false, false
    for step = 0, math.ceil(duration * 60) do
        local t = step * dt
        x6.f = step
        if name == "Black Hole v2" then
            if t >= 3.8 and not exploded then action("rwExplode"); exploded = true end
            if t >= 4.8 and not regrabbed then action("rwRegrab"); regrabbed = true end
        end
        if mod.ContinuousMotion then
            x6.motion_offset = Vector3.new(math.sin(t * 0.35) * 6, math.sin(t * 0.53) * 1.5,
                (math.cos(t * 0.35) - 1) * 6)
        end
        if mod.px then mod.px(t, c, x6, x9, config.x1) end
        for id, p in ipairs(parts) do
            local d = records[id]
            if not d.released then
                local _, target = mod.f2(p, cen, d, t, c, config.x1, x6, x9)
                if d.unclaim then
                    if not d.keep_velocity then p.AssemblyLinearVelocity = d.release_velocity or Vector3.zero end
                    d.released, x6.a[p] = true, nil
                elseif not Physics.apply(p, d, config.x1) then
                    local delta = target - p.Position
                    p.AssemblyLinearVelocity = delta / dt
                    p.Position = target
                end
            end
            if d.released or d.free_active then
                local velocity = p.AssemblyLinearVelocity + Vector3.new(0, -workspace.Gravity * dt, 0)
                p.Position = p.Position + velocity * dt
                local floor = p.Size.Y * 0.5
                if p.Position.Y < floor then
                    p.Position = Vector3.new(p.Position.X, floor, p.Position.Z)
                    velocity = Vector3.new(velocity.X * 0.85, 0, velocity.Z * 0.85)
                end
                p.AssemblyLinearVelocity = velocity
            end
        end
        if next_frame < frames and t + 1e-8 >= next_frame * duration / frames then
            local cloud = {}
            for id, p in ipairs(parts) do cloud[id] = vector(p.Position) end
            sampled[#sampled + 1] = "[" .. table.concat(cloud, ",") .. "]"
            local label = kind == "creatures" and "Articulated flight path"
                or (name == "Drop" and (t < 2.5 and "Gather canopy" or (t < 3.3 and "Hold" or "Release wave")))
                or (regrabbed and "Regrab" or (exploded and "Impulse + gravity" or (t < 2 and "Tightening spiral" or "Stable sphere / 720 deg/s")))
            labels[#labels + 1] = '"' .. label .. '"'
            next_frame = next_frame + 1
        end
    end
    assert(#sampled == frames, "incorrect frame count")
    mod.cleanup(x6, config.x1)
    output[#output + 1] = '"' .. name .. '":{"review":' .. tostring(name == "Drop")
        .. ',"continuous_motion":' .. tostring(mod.ContinuousMotion == true)
        .. ',"sizes":[' .. table.concat(dimensions, ",") .. '],"frames":[' .. table.concat(sampled, ",")
        .. '],"labels":[' .. table.concat(labels, ",") .. ']}'
end
print("{" .. table.concat(output, ",") .. "}")
