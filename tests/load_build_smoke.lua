-- Loads and builds System.lua and UI.lua for BOTH trees against a stubbed Roblox
-- environment, then runs the three entry points main.lua calls and the startup
-- notice it sends. Nothing in this suite executed either file before, and they are
-- the two largest in the project: this is what caught main.lua's unguarded
-- x8.notify, which took the whole script down on mobile whenever the saved shape
-- was flagged Testing.
--
--   luajit tests/load_build_smoke.lua      (from the repo root)

package.path = "tests/?.lua;" .. package.path
local env = require("robloxenv")
local svc, newInstance, LocalPlayer = env.svc, env.newInstance, env.LocalPlayer

-- ---------------------------------------------------------------------------
local fails, checks = 0, 0
local function attempt(label, fn)
  checks = checks + 1
  local ok, err = pcall(fn)
  if ok then print(("  ok    %s"):format(label))
  else fails=fails+1; print(("  FAIL  %s\n          %s"):format(label, tostring(err))) end
  return ok
end

local config = assert(loadfile("config.lua"))()
local function freshContext(subdir)
  local x1 = config.x1
  local x2 = config.x2
  x1.S = x2
  local x6 = {
    b=nil, c={}, a=setmetatable({},{__mode="k"}), o=false, d=false, p=0, f=0, n=0,
    pi_targets={}, pi_timer=0, ex_nodes={}, ex_timer=0, esp_timer=0,
    claim_queue={}, active_array={}, run_connections={}, pre={}, pre_buffer=table.create(200),
    sculptor_selected=setmetatable({},{__mode="k"}), sculptor_dragging=false,
    sculptor_drag_start=nil, sculptor_box_start=nil, sculptor_box=nil,
    sculptor_highlights=setmetatable({},{__mode="k"}), sculptor_preset_ui=nil,
    transition_time=0, transition_dur=2, f1_connections={},
  }
  local ANIM = {}
  for _,k in ipairs({"HOVER","PRESS","RELEASE","TOGGLE","TINT","SLIDE","OPEN","OPEN_POP",
                     "CLOSE","CLOSE_POP","ROLL","FOLD","UNFOLD","RESCALE"}) do
    ANIM[k]=TweenInfo.new(0.1)
  end
  local loaded = {}
  local function get_shape(name)
    if loaded[name]==nil then
      local f=io.open("shapes/"..name..".lua")
      if not f then loaded[name]=false return nil end
      local src=f:read("a"); f:close()
      local ok,m=pcall(assert(load(src,name)))
      loaded[name]= ok and m or false
    end
    return loaded[name] or nil
  end
  return {
    v1=svc("UserInputService"), v2=svc("Players"), v3=svc("RunService"),
    v4=svc("Workspace"), v5=svc("StarterGui"), v6=svc("TweenService"),
    v7=svc("ContextActionService"), v8=LocalPlayer, v9=newInstance("Mouse",nil),
    x1=x1, x2=x2, x6=x6, x9={c1=0.15,c2=0.05,c3=0.01,c4=0.2,c5=0.6,c6=0.8,c7=0.1,c8=0.25},
    favorites={}, save_favs=function() end, save_settings=function() end,
    get_shape=get_shape, local_shapes={}, loaded_shapes=loaded,
    load_module=function(p) local ch=loadfile(p); if not ch then error("no module "..p) end return ch() end,
    is_mobile=(subdir~=""), SUB_DIR=subdir, reset_config=function() end, ANIM=ANIM,
  }
end

for _, tree in ipairs({ {label="DESKTOP (root)", dir=""}, {label="MOBILE (mobilever/)", dir="mobilever/"} }) do
  print("\n════════ "..tree.label.." ════════")
  local ctx = freshContext(tree.dir)
  local x5, sys
  attempt("load+build "..tree.dir.."UI.lua", function()
    local b = assert(loadfile(tree.dir.."UI.lua"))()
    x5 = b(ctx); ctx.x5 = x5
    assert(type(x5)=="table", "UI builder must return a table")
  end)
  attempt("load+build "..tree.dir.."System.lua", function()
    local b = assert(loadfile(tree.dir.."System.lua"))()
    sys = b(ctx)
    assert(type(sys)=="table" and sys.x4 and sys.x8, "System must return {x4=,x8=}")
    ctx.x4, ctx.x8 = sys.x4, sys.x8
  end)
  if sys then
    attempt("x4.f3()  (start physics loop)", function() sys.x4.f3() end)
    attempt("x8.i()   (init keybinds)",      function() sys.x8.i() end)
  end
  if x5 and x5.st then attempt("x5.st()  (build panel)", function() x5.st() end) end
  -- the exact call main.lua:575-578 makes, on this tree
  attempt("main.lua:577 startup Testing notice", function()
    local shape = ctx.get_shape("Meteor Hammer")   -- a shape with M.Testing = true
    assert(shape and shape.Testing, "harness: expected Meteor Hammer to be Testing")
    ctx.x8.notify("Testing", "Meteor Hammer is still in testing.", 4)
  end)
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
