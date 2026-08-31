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
local function bp(name, pos, size, tr)
  local p = newInstance("Part", nil)
  local props = { Name=name, Size=size, CFrame=CFrame.new(pos.X,pos.Y,pos.Z), Position=pos,
                  AssemblyLinearVelocity=Vector3.zero, Anchored=false, CanCollide=true,
                  -- A real BasePart always answers Transparency, and the cloud filter reads it.
                  Transparency=tr or 0 }
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

-- Wraps a part list in a character model. Factored out because the sampling checks
-- below need rigs of their own -- an invisible hitbox, a root-only rig -- without
-- disturbing the R6 rig every tracking check measures against.
local function mk_char(parts)
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
  return char
end

local char = mk_char(parts)
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

-- 6. only parts that actually draw something get sampled
--
-- HumanoidRootPart renders nothing, and in R6 its 2x2x1 box sits exactly on the
-- Torso's. It used to take the largest volume share of any part -- 267 of 1199
-- points in R6, 18% of the cloud in R15 -- and its transform in root space is the
-- identity by construction, so every part sent there stood rigid at the root while
-- the rest of the mech animated. Reported as "parts following humanoid root part
-- and essentially a waste of parts", which is exactly what it was.
do
  local cfg, x6 = fresh()
  sample(S, cfg, x6, 0, {1})
  local cloud = x6.pre["Mech Suit"].cloud
  local named = {}
  for bi, b in ipairs(cloud.boxes) do named[bi] = b.part.Name end
  local root_pts = 0
  for i = 1, cloud.n do
    if named[cloud.owner[i]] == "HumanoidRootPart" then root_pts = root_pts + 1 end
  end
  check(root_pts == 0, ("no point lands on HumanoidRootPart (was 267 of 1199): %d"):format(root_pts))
  check(#cloud.boxes == 6, ("the six drawn R6 limbs are sampled: %d boxes"):format(#cloud.boxes))
end

-- Fully invisible parts are waste for the same reason: games bolt hitboxes and
-- shadow volumes onto characters, and a part placed inside one draws nothing. The
-- 8x8x8 hitbox here would take 98% of the cloud on volume share alone.
do
  local saved = LocalPlayer.Character
  local torso  = bp("Torso",  Vector3.new(0,3,0), Vector3.new(2,2,1), 0)
  local hitbox = bp("Hitbox", Vector3.new(0,3,0), Vector3.new(8,8,8), 1)
  local ghost  = bp("Ghost",  Vector3.new(0,5,0), Vector3.new(2,2,1), 0.5)
  LocalPlayer.Character = mk_char({ torso, hitbox, ghost })
  local cfg, x6 = fresh()
  sample(S, cfg, x6, 0, {1})
  local names = {}
  for _, b in ipairs(x6.pre["Mech Suit"].cloud.boxes) do names[b.part.Name] = true end
  check(not names.Hitbox, "a fully invisible part is not sampled")
  check(names.Ghost, "a semi-transparent part still is")
  -- This rig has no HumanoidRootPart, so root_of falls back to the first BasePart --
  -- a real limb. Excluding by name rather than by identity with that pick is what
  -- keeps it in the cloud.
  check(names.Torso, "a fallback root part is still sampled when it is a real limb")
  LocalPlayer.Character = saved
end

-- The fallbacks. A character can be nothing but a root part mid-respawn, or wholly
-- invisible because the game hid it. The mech keeps standing in both cases rather
-- than blinking out, which is what filtering down to nothing would do.
do
  local saved = LocalPlayer.Character
  -- Parenthesised: bp returns the part and its prop table, and a bare call at the end
  -- of a constructor would drop that second value into the rig as a bogus child.
  LocalPlayer.Character = mk_char({ (bp("HumanoidRootPart", Vector3.new(0,3,0), Vector3.new(2,2,1), 1)) })
  local cfg, x6 = fresh()
  sample(S, cfg, x6, 0, {1})
  local st = x6.pre["Mech Suit"]
  check(st.cloud ~= nil and st.cloud.n > 0, "a root-only rig still builds a cloud")

  local hidden = {}
  for i, p in ipairs(parts) do hidden[i] = bp(p.Name, propmap[p.Name].Position, p.Size, 1) end
  LocalPlayer.Character = mk_char(hidden)
  local cfg2, x62 = fresh()
  sample(S, cfg2, x62, 0, {1})
  local st2 = x62.pre["Mech Suit"]
  check(st2.cloud ~= nil and st2.cloud.n > 0, "a wholly invisible rig still builds a cloud")
  LocalPlayer.Character = saved
end

-- 7. cleanup
do
  local cfg, x6 = fresh()
  sample(S, cfg, x6, 0, {1})
  S.cleanup(x6, X1)
  check(x6.pre["Mech Suit"] == nil, "cleanup drops state")
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
