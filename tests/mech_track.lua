-- Mech Suit follows the character's live pose. The suit used to snapshot the pose
-- once and replay a canned sine-wave gait over it, so a jump, a crouch, a tool pose
-- or an emote did nothing at all. These checks pin the tracking down: a moved limb
-- moves the mech and only that limb, Motion Gain 0 freezes it, Tilt Track carries
-- pitch and roll, and none of it produces a NaN.
--
--   luajit tests/mech_track.lua      (from the repo root)

package.path = "tests/?.lua;" .. package.path
local env = require("robloxenv")
local newInstance, LocalPlayer, ANY = env.newInstance, env.LocalPlayer, env.ANY

-- A real R6-shaped rig whose parts actually report IsA("BasePart"), so the cloud
-- is genuinely built (the generic sweep stub did not, which made Mech Suit a no-op).
local function bp(name, pos, size)
  local p = newInstance("Part", nil)
  local props = { Name=name, Size=size, CFrame=CFrame.new(pos.X,pos.Y,pos.Z), Position=pos,
                  AssemblyLinearVelocity=Vector3.zero, Anchored=false, CanCollide=true }
  local mt = getmetatable(p); local prev = mt.__index
  mt.__index = function(t,k)
    if k=="IsA" then return function(_,c) return c=="BasePart" or c=="Part" end end
    if props[k] ~= nil then return props[k] end
    return prev(t,k)
  end
  -- Position tracks CFrame, the way a real BasePart does.
  mt.__newindex = function(_,k,v)
    props[k]=v
    if k=="CFrame" then props.Position = v.Position end
  end
  return p, props
end

local parts, propmap = {}, {}
local function add(name,pos,size)
  local p,props = bp(name,pos,size); parts[#parts+1]=p; propmap[name]=props; return p
end
add("HumanoidRootPart", Vector3.new(0,3,0), Vector3.new(2,2,1))
add("Torso",            Vector3.new(0,3,0), Vector3.new(2,2,1))
add("Head",             Vector3.new(0,4.5,0), Vector3.new(1,1,1))
add("Left Arm",         Vector3.new(-1.5,3,0), Vector3.new(1,2,1))
add("Right Arm",        Vector3.new(1.5,3,0),  Vector3.new(1,2,1))
add("Left Leg",         Vector3.new(-0.5,1,0), Vector3.new(1,2,1))
add("Right Leg",        Vector3.new(0.5,1,0),  Vector3.new(1,2,1))

local char = newInstance("Model", nil)
local byName = {}
for _,p in ipairs(parts) do byName[p.Name] = p end
getmetatable(char).__index = function(_,k)
  if k=="GetChildren" then return function() return parts end end
  if k=="FindFirstChild" then return function(_,n) return byName[n] end end
  if k=="FindFirstChildWhichIsA" then return function() return parts[1] end end
  if k=="IsA" then return function(_,c) return c=="Model" end end
  if k=="Name" then return "Tester" end
  if byName[k] then return byName[k] end
  return ANY
end
LocalPlayer.Character = char

local BASE = {}
for name, props in pairs(propmap) do BASE[name] = props.CFrame end
local function reset_rig()
  for name, props in pairs(propmap) do
    props.CFrame = BASE[name]; props.Position = BASE[name].Position
  end
end
-- Rotates the WHOLE rig about the root, the way a real character tilts. Rotating
-- only the root would change every other part's root-local offset, which changes
-- the silhouette for reasons that have nothing to do with Tilt Track.
local function rotate_rig(rot)
  local P = CFrame.new(0, 3, 0)
  local X = P * rot * P:Inverse()
  for name, props in pairs(propmap) do
    local cf = X * BASE[name]
    props.CFrame = cf; props.Position = cf.Position
  end
end

local S = assert(loadfile("shapes/Mech Suit.lua"))()
local cfgAll = assert(loadfile("config.lua"))()
local X1 = { k10 = 20, k7 = 4, k1 = 2000 }
local X9 = { c1 = 0.15, c2 = 0.05, c5 = 0.6, c7 = 0.1 }

local fails, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if cond then print("  ok   "..msg)
  else fails = fails + 1; print("  FAIL "..msg) end
end

local function fresh(overrides)
  local cfg = {}
  for k,v in pairs(cfgAll.x2["Mech Suit"]) do cfg[k]=v end
  for k,v in pairs(overrides or {}) do cfg[k]=v end
  return cfg, { pre = {}, f = 0, n = 300 }
end

-- sample f2 target positions for a spread of ids at the current cycle
local function sample(S, cfg, x6, frame, ids)
  x6.f = frame
  S.px(frame/60, cfg, x6, X9, X1)
  local out = {}
  for _, id in ipairs(ids) do
    local _, tp = S.f2({Position=Vector3.zero}, Vector3.new(0,3,0), {id=id}, frame/60, cfg, X1, x6, X9)
    out[id] = tp
  end
  return out
end
local IDS = {}
for i=1,240 do IDS[i]=i end
local function moved(a, b, eps)
  eps = eps or 0.01
  local c = 0
  for _, id in ipairs(IDS) do
    local x,y = a[id], b[id]
    if x and y and (x-y).Magnitude > eps then c = c + 1 end
  end
  return c
end

print("Mech Suit -- 1:1 character tracking")

-- 1. the cloud is actually built now
do
  local cfg, x6 = fresh()
  sample(S, cfg, x6, 0, {1})
  local st = x6.pre["Mech Suit"]
  check(st and st.cloud ~= nil, "cloud builds from a live rig")
  check(st and st.xf ~= nil and st.xf[1] ~= nil, "px stamps a live per-part transform table")
  local n, step = st.cloud.n, st.cloud.step
  local function g(a,b) while b~=0 do a,b=b,a%b end return a end
  check(g(step, n) == 1, ("stride is coprime with n: gcd(%d,%d)=%d"):format(step, n, g(step,n)))
  local seen, cnt = {}, 0
  for id=1,n do local i=(id*step)%n+1; if not seen[i] then seen[i]=true; cnt=cnt+1 end end
  check(cnt == n, ("all %d slots reachable (was 400/1200 before)"):format(n))
end

-- 2. moving a limb moves the mech
do
  local cfg, x6 = fresh()
  local before = sample(S, cfg, x6, 0, IDS)
  -- swing the right arm up 90 degrees about its own shoulder
  propmap["Right Arm"].CFrame = CFrame.fromMatrix(
    Vector3.new(1.5,3,0), Vector3.new(0,1,0), Vector3.new(-1,0,0), Vector3.new(0,0,1))
  local after = sample(S, cfg, x6, 4, IDS)
  local m = moved(before, after)
  check(m > 0, ("rotating the right arm moves the mech: %d of %d sampled points"):format(m, #IDS))
  check(m < #IDS, ("and only that limb: %d of %d unchanged"):format(#IDS - m, #IDS))
end

-- 3. Motion Gain 0 pins the mech to its rest pose
do
  local cfg, x6 = fresh({ k18 = 0 })
  propmap["Right Arm"].CFrame = CFrame.new(1.5,3,0)
  local before = sample(S, cfg, x6, 0, IDS)
  propmap["Right Arm"].CFrame = CFrame.fromMatrix(
    Vector3.new(1.5,3,0), Vector3.new(0,1,0), Vector3.new(-1,0,0), Vector3.new(0,0,1))
  local after = sample(S, cfg, x6, 4, IDS)
  check(moved(before, after) == 0, "Motion Gain 0 ignores the animation entirely")
end

-- 4. Tilt Track, rotating the whole rig rigidly
do
  local pitch = CFrame.fromAxisAngle(Vector3.new(1,0,0), math.pi/4)

  local cfg1, x6a = fresh({ k19 = 1 })
  reset_rig()
  local a0 = sample(S, cfg1, x6a, 0, IDS)
  rotate_rig(pitch)
  local a1 = sample(S, cfg1, x6a, 4, IDS)
  check(moved(a0, a1) > 0, "Tilt Track 100 carries the body's pitch and roll")

  local cfg0, x6b = fresh({ k19 = 0 })
  reset_rig()
  local b0 = sample(S, cfg0, x6b, 0, IDS)
  rotate_rig(pitch)
  local b1 = sample(S, cfg0, x6b, 4, IDS)
  check(moved(b0, b1) == 0, "Tilt Track 0 keeps the mech upright")
  reset_rig()
end

-- 5. no NaN anywhere in the tracked output
do
  local cfg, x6 = fresh()
  local bad = 0
  for frame = 0, 40, 4 do
    local rot = CFrame.fromAxisAngle(Vector3.new(1,0,0), frame*0.1)
    propmap["Left Leg"].CFrame = CFrame.new(-0.5,1,0) * rot
    propmap["Left Leg"].Position = propmap["Left Leg"].CFrame.Position
    local s = sample(S, cfg, x6, frame, IDS)
    for _, id in ipairs(IDS) do
      local tp = s[id]
      if tp then for _,cc in ipairs({tp.X,tp.Y,tp.Z}) do
        if type(cc)~="number" or cc~=cc or cc==math.huge or cc==-math.huge then bad = bad + 1 end
      end end
    end
  end
  check(bad == 0, "animated tracking produces no NaN/inf")
end

-- 6. cleanup
do
  local cfg, x6 = fresh()
  sample(S, cfg, x6, 0, {1})
  S.cleanup(x6, X1)
  check(x6.pre["Mech Suit"] == nil, "cleanup drops state")
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
