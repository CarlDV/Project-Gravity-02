-- One circular touch stick and a separate held action, shared by shape plugins.
return function(context, gui)
	local x6, x1 = context.x6, context.x1
	if x6.torn_down then return function() end end
	local input, run = context.v1, context.v3
	if x6.mobile_cleanup then x6.mobile_cleanup() end
	local connections, closed = {}, false
	local current, stick_touch, action_touch
	local touch_mode = context.is_mobile and true or false
	pcall(function() touch_mode = touch_mode or input:GetLastInputType() == Enum.UserInputType.Touch end)
	local state = { active = false, held = false, presses = 0, generation = x6.mobile_generation or 0,
		x = 0, y = 0, yaw = 0, pitch = 0 }
	x6.mobile_input = state
	local function connect(signal, callback)
		local conn = signal:Connect(callback)
		connections[#connections + 1] = conn
		return conn
	end
	local root = Instance.new("Frame", gui)
	root.Name = "ShapeTouchControls"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -18, 1, -138)
	root.Size = UDim2.new(0, 220, 0, 154)
	root.BackgroundTransparency = 1
	root.Visible = false
	local scale = Instance.new("UIScale", root)
	local pad = Instance.new("TextButton", root)
	pad.Name = "SteeringStick"
	pad.Size = UDim2.new(0, 126, 0, 126)
	pad.Position = UDim2.new(1, -126, 1, -126)
	pad.BackgroundColor3 = Color3.fromRGB(21, 28, 37)
	pad.BackgroundTransparency = 0.18
	pad.AutoButtonColor = false
	pad.Text = ""
	pad.Active = true
	Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)
	local outline = Instance.new("UIStroke", pad)
	outline.Color = Color3.fromRGB(87, 203, 208)
	outline.Thickness = 2
	local knob = Instance.new("Frame", pad)
	knob.Name = "Thumb"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0.5, 0, 0.5, 0)
	knob.Size = UDim2.new(0, 46, 0, 46)
	knob.BackgroundColor3 = Color3.fromRGB(99, 223, 215)
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local action = Instance.new("TextButton", root)
	action.Name = "ShapeAction"
	action.Size = UDim2.new(0, 76, 0, 76)
	action.Position = UDim2.new(0, 0, 1, -102)
	action.BackgroundColor3 = Color3.fromRGB(55, 100, 119)
	action.TextColor3 = Color3.fromRGB(245, 250, 255)
	action.Font = Enum.Font.GothamBold
	action.TextSize = 12
	action.TextWrapped = true
	action.Active = true
	action.AutoButtonColor = false
	Instance.new("UICorner", action).CornerRadius = UDim.new(1, 0)
	local label = Instance.new("TextLabel", root)
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(210, 232, 237)
	label.TextSize = 11
	label.Text = "DRAG TO STEER  /  HOLD TO ACT"

	local function neutral()
		stick_touch, action_touch = nil, nil
		state.x, state.y, state.held = 0, 0, false
		knob.Position = UDim2.new(0.5, 0, 0.5, 0)
		action.BackgroundColor3 = Color3.fromRGB(55, 100, 119)
	end
	local function reset()
		neutral()
		state.active, state.aim, state.base_aim, state.direction = false, nil, nil, nil
		state.yaw, state.pitch, state.presses = 0, 0, 0
		state.generation = state.generation + 1
		x6.mobile_generation = state.generation
	end
	x6.mobile_reset = reset
	local function move(touch)
		local size, origin = pad.AbsoluteSize, pad.AbsolutePosition
		local radius = math.max(1, math.min(size.X, size.Y) * 0.5)
		local x = (touch.Position.X - origin.X - size.X * 0.5) / radius
		local y = (touch.Position.Y - origin.Y - size.Y * 0.5) / radius
		local mag = math.sqrt(x * x + y * y)
		if mag > 1 then x, y = x / mag, y / mag end
		if mag < 0.12 then x, y = 0, 0 end
		state.x, state.y = x, y
		knob.Position = UDim2.new(0.5 + x * 0.3, 0, 0.5 + y * 0.3, 0)
	end
	local function pointer(touch)
		return touch.UserInputType == Enum.UserInputType.Touch
			or touch.UserInputType == Enum.UserInputType.MouseButton1
	end
	connect(pad.InputBegan, function(touch)
		if not state.active or stick_touch or not pointer(touch) then return end
		stick_touch = touch
		move(touch)
	end)
	connect(action.InputBegan, function(touch)
		if not state.active or action_touch or not pointer(touch) then return end
		action_touch = touch
		state.held, state.presses = true, state.presses + 1
		action.BackgroundColor3 = Color3.fromRGB(72, 182, 172)
	end)
	local function release(touch)
		if touch == stick_touch then
			stick_touch = nil
			state.x, state.y = 0, 0
			knob.Position = UDim2.new(0.5, 0, 0.5, 0)
		end
		if touch == action_touch then
			action_touch, state.held = nil, false
			action.BackgroundColor3 = Color3.fromRGB(55, 100, 119)
		end
	end
	connect(input.InputChanged, function(touch)
		if touch.UserInputState == Enum.UserInputState.Cancel or touch.UserInputState == Enum.UserInputState.End then
			release(touch)
		elseif touch == stick_touch or (stick_touch and touch.UserInputType == Enum.UserInputType.MouseMovement
			and stick_touch.UserInputType == Enum.UserInputType.MouseButton1) then move(touch) end
	end)
	connect(input.InputEnded, release)
	connect(input.WindowFocusReleased, neutral)
	connect(input.LastInputTypeChanged, function(kind)
		touch_mode = context.is_mobile or kind == Enum.UserInputType.Touch
	end)
	connect(run.RenderStepped, function(dt)
		if closed or x6.torn_down then return end
		local name = x1.k6
		local mod = context.loaded_shapes and context.loaded_shapes[name]
		local spec = mod and mod.MobileControls
		local camera = context.v4.CurrentCamera
		local active = (touch_mode and camera and type(spec) == "table" and x6.o and not x1.Disabled and not x1.Paused) or false
		if current ~= name or state.active ~= active then
			reset()
			current, state.shape = name, name
		end
		state.active, root.Visible = active and true or false, active and true or false
		if not active then return end
		scale.Scale = math.clamp(camera.ViewportSize.Y / 650, 0.78, 1)
		action.Text = spec.Action or "ACT"
		local elapsed = math.clamp(dt, 0, 0.1)
		state.yaw = state.yaw + state.x * elapsed * 1.8
		state.yaw = math.atan2(math.sin(state.yaw), math.cos(state.yaw))
		state.pitch = math.clamp(state.pitch - state.y * elapsed * 1.4, -1.15, 1.15)
		local cf = camera.CFrame
		local cp = math.cos(state.pitch)
		state.direction = (cf.LookVector * (math.cos(state.yaw) * cp)
			+ cf.RightVector * (math.sin(state.yaw) * cp) + cf.UpVector * math.sin(state.pitch)).Unit
		local reach = math.clamp(spec.Range or 600, 50, 2000)
		state.aim = cf.Position + state.direction * reach
		state.base_aim = cf.Position + cf.LookVector * reach
	end)
	local function cleanup()
		if closed then return end
		closed = true
		reset()
		for _, conn in ipairs(connections) do conn:Disconnect() end
		root:Destroy()
		if x6.mobile_input == state then
			x6.mobile_input, x6.mobile_cleanup, x6.mobile_reset = nil, nil, nil
		end
	end
	x6.mobile_cleanup = cleanup
	connect(gui.Destroying, cleanup)
	return cleanup
end
