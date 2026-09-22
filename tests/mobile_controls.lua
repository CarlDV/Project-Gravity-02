package.path = "tests/?.lua;" .. package.path
local fixture = require("runtime_fixture")
local env = fixture.env
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local camera = Instance.new("Camera")
camera.CFrame, camera.ViewportSize = CFrame.new(), Vector2.new(844, 390)
workspace.CurrentCamera = camera
local ctx = {
	x1 = { k6 = "Big Bad Broom" }, x6 = { o = true },
	is_mobile = true,
	v1 = fixture.input, v3 = fixture.run, v4 = workspace,
	loaded_shapes = {
		["Big Bad Broom"] = { MobileControls = { Action = "EXTEND" } },
		Raigo = { MobileControls = { Action = "LAUNCH" } },
	},
}
local gui = Instance.new("ScreenGui", workspace)
local cleanup = assert(loadfile("MobileControls.lua"))()(ctx, gui)
local pad, action = fixture.find("SteeringStick"), fixture.find("ShapeAction")
pad.AbsolutePosition, pad.AbsoluteSize = Vector2.new(0, 0), Vector2.new(126, 126)
fixture.run.RenderStepped:Fire(1 / 60)
local input = ctx.x6.mobile_input
check(input.active and input.shape == "Big Bad Broom", "controls activate for supported shapes")
local a = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(126, 63, 0) }
local b = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(10, 10, 0) }
local other = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.zero }
pad.InputBegan:Fire(a)
action.InputBegan:Fire(b)
fixture.input.InputEnded:Fire(other)
fixture.run.RenderStepped:Fire(1 / 60)
check(input.x == 1 and input.held and input.presses == 1, "two fingers steer and hold independently")
check(input.yaw > 0 and input.aim ~= nil and input.direction.Magnitude > 0.99, "stick drives a finite world aim")
fixture.input.InputEnded:Fire(a)
check(input.x == 0 and input.held, "lifting stick finger does not release action")
fixture.input.InputEnded:Fire(b)
check(not input.held, "lifting action finger releases it")
action.InputBegan:Fire(b)
b.UserInputState = Enum.UserInputState.Cancel
fixture.input.InputChanged:Fire(b)
check(not input.held, "canceled action touch releases its hold")
b.UserInputState = Enum.UserInputState.Begin
pad.InputBegan:Fire(a)
a.Position = Vector3.new(10000, -10000, 0)
fixture.input.InputChanged:Fire(a)
check(input.x * input.x + input.y * input.y <= 1.00001, "drag outside circle clamps to rim")
a.UserInputState = Enum.UserInputState.Cancel
fixture.input.InputChanged:Fire(a)
check(input.x == 0 and input.y == 0, "canceled steering touch centers the stick")
a.UserInputState = Enum.UserInputState.Begin
pad.InputBegan:Fire(a)
fixture.input.WindowFocusReleased:Fire()
check(input.x == 0 and input.y == 0 and not input.held, "focus loss cancels gestures")
local generation = input.generation
ctx.x1.Paused = true
fixture.run.RenderStepped:Fire(1 / 60)
check(not input.active and input.yaw == 0, "pause hides controls and clears steering")
check(input.generation > generation, "reset changes the action generation even if a shape misses the zero counter")
ctx.x1.Paused, ctx.x1.k6 = false, "Raigo"
fixture.run.RenderStepped:Fire(1 / 60)
check(input.shape == "Raigo" and input.presses == 0 and action.Text == "LAUNCH", "shape switch resets actions")
-- Shape processing pauses too: it may never see the counter return to zero.
local Raigo = assert(loadfile("shapes/Raigo.lua"))()
local config = assert(loadfile("config.lua"))()
ctx.x6.pre, ctx.x6.n = {}, 1
local part = { Position = Vector3.zero, AssemblyLinearVelocity = Vector3.zero, Size = Vector3.one }
local record = { id = 1 }
local function step(t) Raigo.f2(part, Vector3.zero, record, t, config.x2.Raigo, config.x1, ctx.x6, { c1 = 0.15 }) end
step(0)
action.InputBegan:Fire(b)
step(0.01)
local state = ctx.x6.pre.Raigo
check(state.phase == "LAUNCH", "mobile action launches Raigo")
state.phase = "HOVER"
ctx.x1.Paused = true
fixture.run.RenderStepped:Fire(1 / 60)
ctx.x1.Paused = false
fixture.run.RenderStepped:Fire(1 / 60)
action.InputBegan:Fire(b)
step(0.02)
check(state.phase == "LAUNCH", "first launch after pause works without a shape frame at zero presses")
Raigo.cleanup(ctx.x6, config.x1)
ctx.x1.k6 = "Megalodon"
fixture.run.RenderStepped:Fire(1 / 60)
check(not input.active and not fixture.find("ShapeTouchControls").Visible, "automatic formations hide touch controls")
gui:Destroy()
check(ctx.x6.mobile_input == nil and fixture.run.RenderStepped:count() == 0, "destroying UI removes touch state and loop")
cleanup()
local previous = input.generation
local replacement = Instance.new("ScreenGui", workspace)
local close_replacement = assert(loadfile("MobileControls.lua"))()(ctx, replacement)
ctx.x1.k6 = "Raigo"
fixture.run.RenderStepped:Fire(1 / 60)
check(ctx.x6.mobile_input.generation > previous, "rebuilding controls cannot reuse an old action generation")
close_replacement()
ctx.is_mobile = false
local hybrid = Instance.new("ScreenGui", workspace)
local close_hybrid = assert(loadfile("MobileControls.lua"))()(ctx, hybrid)
fixture.run.RenderStepped:Fire(1 / 60)
check(not ctx.x6.mobile_input.active, "a touch-capable desktop keeps its normal mouse controls")
fixture.input.LastInputTypeChanged:Fire(Enum.UserInputType.Touch)
fixture.run.RenderStepped:Fire(1 / 60)
check(ctx.x6.mobile_input.active, "a hybrid device can switch to touch controls")
fixture.input.LastInputTypeChanged:Fire(Enum.UserInputType.MouseMovement)
fixture.run.RenderStepped:Fire(1 / 60)
check(not ctx.x6.mobile_input.active, "mouse input restores the desktop fallback on hybrid devices")
close_hybrid()
print(checks .. " mobile gesture checks passed")
