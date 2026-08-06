return function(context)
	local v1, v6 = context.v1, context.v6
	local save_settings = context.save_settings
	-- Shared motion vocabulary from main.lua. The fallback keeps this module
	-- standalone if it is ever loaded without one; the durations mirror the
	-- table there rather than the old inline values.
	local A = context.ANIM or {
		HOVER = TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		PRESS = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		RELEASE = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		TOGGLE = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		TINT = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		SLIDE = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		OPEN = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	}
	local M = {}

	-- Press feedback shared by every tappable row: a small dip on press and a
	-- springy return on release. Applied to the UIScale so it never fights a
	-- Position or Size tween the caller may also be running.
	--
	-- Touch, unlike a mouse, has no hover to fall back on -- the dip is the only
	-- confirmation a tap registered, so it matters more here than on desktop.
	-- InputBegan/Ended rather than MouseButton1Down/Up: a touch that slides off
	-- the button ends as InputEnded on the button itself, whereas MouseLeave
	-- never fires for a finger and would leave the row stuck shrunk.
	local function add_press_feedback(btn, depth)
		local sc = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
		depth = depth or 0.96
		local down = false
		local function is_press(i)
			return i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch
		end
		btn.InputBegan:Connect(function(i)
			if not is_press(i) then
				return
			end
			down = true
			v6:Create(sc, A.PRESS, { Scale = depth }):Play()
		end)
		local function release(i)
			if not down or (i and not is_press(i)) then
				return
			end
			down = false
			v6:Create(sc, A.RELEASE, { Scale = 1 }):Play()
		end
		btn.InputEnded:Connect(release)
		return sc
	end
	M.press = add_press_feedback

	function M.s(p, t, mn, mx, df, cb, is_int, desc)
		df = df or mn
		if is_int or mx - mn > 50 then
			df = math.floor(df + 0.5)
		else
			df = math.floor(df * 10 + 0.5) / 10
		end
		local f = Instance.new("Frame", p)
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 24)
		f.AutomaticSize = Enum.AutomaticSize.Y

		local l = Instance.new("TextLabel", f)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 12)
		l.Text = t
		l.TextColor3 = Color3.fromRGB(180, 180, 180)
		l.TextXAlignment = 0
		l.Font = Enum.Font.Gotham
		l.TextSize = 8

		local vl = Instance.new("TextBox", f)
		vl.BackgroundTransparency = 1
		vl.Position = UDim2.new(1, -50, 0, 0)
		vl.Size = UDim2.new(0, 50, 0, 12)
		vl.Text = tostring(df)
		vl.TextColor3 = Color3.fromRGB(255, 255, 255)
		vl.TextXAlignment = 1
		vl.Font = Enum.Font.GothamBold
		vl.TextSize = 8
		-- clearing on focus makes the common case one action: tap, type, enter.
		-- an accidental tap that types nothing is restored by FocusLost below
		vl.ClearTextOnFocus = true
		vl.TextEditable = true
		-- the name label spans this whole row; lift the box so the tap lands here
		vl.ZIndex = 2

		local sc = Instance.new("Frame", f)
		sc.BackgroundTransparency = 1
		sc.Position = UDim2.new(0, 0, 0, 14)
		sc.Size = UDim2.new(1, 0, 0, 4)

		if desc then
			local d = Instance.new("TextLabel", f)
			d.BackgroundTransparency = 1
			d.Position = UDim2.new(0, 0, 0, 22)
			d.Size = UDim2.new(1, 0, 0, 0)
			d.AutomaticSize = Enum.AutomaticSize.Y
			d.Text = desc
			d.TextColor3 = Color3.fromRGB(120, 120, 130)
			d.TextXAlignment = 0
			d.TextYAlignment = 0
			d.Font = Enum.Font.Gotham
			d.TextSize = 8
			d.TextWrapped = true
		end

		local sb = Instance.new("Frame", sc)
		sb.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		sb.BorderSizePixel = 0
		sb.Size = UDim2.new(1, 0, 1, 0)
		Instance.new("UICorner", sb).CornerRadius = UDim.new(1, 0)

		local fl = Instance.new("Frame", sb)
		fl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		fl.BorderSizePixel = 0
		fl.Size = UDim2.new((df - mn) / (mx - mn), 0, 1, 0)
		Instance.new("UICorner", fl).CornerRadius = UDim.new(1, 0)

		local k = Instance.new("ImageButton", sc)
		k.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		k.AnchorPoint = Vector2.new(0.5, 0.5)
		k.Position = UDim2.new((df - mn) / (mx - mn), 0, 0.5, 0)
		k.Size = UDim2.new(0, 10, 0, 10)
		k.BorderSizePixel = 0
		k.AutoButtonColor = false
		Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

		local active_input = nil
		local current = df

		-- Touch has no hover, so the knob only has two states: resting and held.
		-- Growing it while held is the whole of the grab affordance here -- and it
		-- also lifts the knob out from under the fingertip covering it.
		local K_IDLE, K_DRAG = 10, 15
		local function refresh_knob()
			local held = active_input ~= nil
			local target = held and K_DRAG or K_IDLE
			v6:Create(k, A.HOVER, { Size = UDim2.new(0, target, 0, target) }):Play()
			v6:Create(sb, A.TINT, {
				BackgroundColor3 = held and Color3.fromRGB(48, 48, 55) or Color3.fromRGB(35, 35, 40),
			}):Play()
		end

		-- single place a value is committed, so the slider and the number box can
		-- never disagree: both paths land here
		local function apply(v)
			if is_int or mx - mn > 50 then
				v = math.floor(v + 0.5)
			else
				v = math.floor(v * 10 + 0.5) / 10
			end
			v = math.clamp(v, mn, mx)
			current = v
			local snapped_pc = (v - mn) / (mx - mn)
			-- A drag wants the knob glued to the finger, but a value typed into the
			-- box is a jump the eye should be able to follow, so that path gets a
			-- longer eased move.
			local move = active_input and A.SLIDE or A.OPEN
			v6:Create(fl, move, { Size = UDim2.new(snapped_pc, 0, 1, 0) }):Play()
			v6:Create(k, move, { Position = UDim2.new(snapped_pc, 0, 0.5, 0) }):Play()
			vl.Text = tostring(v)
			cb(v)
			if save_settings then
				save_settings()
			end
		end

		local function u(pos_x)
			local rp = pos_x - sc.AbsolutePosition.X
			local pc = math.clamp(rp / sc.AbsoluteSize.X, 0, 1)
			apply(mn + (mx - mn) * pc)
		end

		k.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				active_input = i
				refresh_knob()
				u(i.Position.X)
			end
		end)
		sb.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				active_input = i
				refresh_knob()
				u(i.Position.X)
			end
		end)
		local c1 = v1.InputEnded:Connect(function(i)
			if i == active_input then
				active_input = nil
				refresh_knob()
			end
		end)
		local c2 = v1.InputChanged:Connect(function(i)
			if i == active_input then
				u(i.Position.X)
			end
		end)

		-- keep the field numeric as it is typed, so what's on screen is always
		-- something tonumber can read on commit
		local filtering = false
		local c3 = vl:GetPropertyChangedSignal("Text"):Connect(function()
			if filtering then
				return
			end
			local clean = vl.Text:gsub("[^%d%.%-]", "")
			if #clean > 12 then
				clean = clean:sub(1, 12)
			end
			if clean ~= vl.Text then
				filtering = true
				vl.Text = clean
				filtering = false
			end
		end)

		vl.Focused:Connect(function()
			v6:Create(vl, A.TINT, { TextColor3 = Color3.fromRGB(0, 255, 200) }):Play()
		end)

		vl.FocusLost:Connect(function()
			v6:Create(vl, A.TINT, { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
			local typed = tonumber(vl.Text)
			-- nil on garbage, and NaN fails its own equality test
			if not typed or typed ~= typed then
				vl.Text = tostring(current)
				return
			end
			apply(typed)
		end)

		f.AncestryChanged:Connect(function(_, parent)
			if not parent then
				c1:Disconnect()
				c2:Disconnect()
				c3:Disconnect()
			end
		end)
	end

	function M.t(p, t, df, cb, desc)
		local f = Instance.new("Frame", p)
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 20)
		f.AutomaticSize = Enum.AutomaticSize.Y

		local l = Instance.new("TextLabel", f)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(0.8, 0, 0, 12)
		l.Text = t
		l.TextColor3 = Color3.fromRGB(180, 180, 180)
		l.TextXAlignment = 0
		l.Font = Enum.Font.Gotham
		l.TextSize = 8

		if desc then
			local d = Instance.new("TextLabel", f)
			d.BackgroundTransparency = 1
			d.Position = UDim2.new(0, 0, 0, 12)
			d.Size = UDim2.new(1, -28, 0, 0)
			d.AutomaticSize = Enum.AutomaticSize.Y
			d.Text = desc
			d.TextColor3 = Color3.fromRGB(120, 120, 130)
			d.TextXAlignment = 0
			d.TextYAlignment = 0
			d.Font = Enum.Font.Gotham
			d.TextSize = 8
			d.TextWrapped = true
		end

		local bg = Instance.new("Frame", f)
		bg.BackgroundColor3 = df and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(40, 40, 45)
		bg.Position = UDim2.new(1, -24, 0, 0)
		bg.Size = UDim2.new(0, 24, 0, 12)
		Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

		local toggle = Instance.new("Frame", bg)
		toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		toggle.Position = df and UDim2.new(1, -10, 0.5, -4) or UDim2.new(0, 2, 0.5, -4)
		toggle.Size = UDim2.new(0, 8, 0, 8)
		Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

		local b = Instance.new("TextButton", f)
		b.BackgroundTransparency = 1
		b.Size = UDim2.new(1, 0, 1, 0)
		b.Text = ""

		b.MouseButton1Click:Connect(function()
			df = not df
			-- Colour has no momentum; the knob does. Tinting on TOGGLE's Back
			-- curve would make the track flash past its target and back.
			v6:Create(
				bg,
				A.TINT,
				{ BackgroundColor3 = df and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(40, 40, 45) }
			):Play()
			v6:Create(
				toggle,
				A.TOGGLE,
				{ Position = df and UDim2.new(1, -10, 0.5, -4) or UDim2.new(0, 2, 0.5, -4) }
			):Play()
			cb(df)
			if save_settings then
				save_settings()
			end
		end)
		add_press_feedback(b, 0.97)
		return b
	end

	function M.b(p, t, cb)
		local b = Instance.new("TextButton", p)
		b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		b.Size = UDim2.new(1, 0, 0, 20)
		b.AutoButtonColor = false
		b.Text = t
		b.TextColor3 = Color3.fromRGB(220, 220, 220)
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 9
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

		local str = Instance.new("UIStroke", b)
		str.Color = Color3.fromRGB(50, 50, 55)
		str.Thickness = 1

		b.MouseEnter:Connect(function()
			v6:Create(
				b,
				A.HOVER,
				{ BackgroundColor3 = Color3.fromRGB(40, 40, 45), TextColor3 = Color3.fromRGB(255, 255, 255) }
			):Play()
			v6:Create(str, A.HOVER, { Color = Color3.fromRGB(70, 70, 78) }):Play()
		end)
		b.MouseLeave:Connect(function()
			v6:Create(
				b,
				A.HOVER,
				{ BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Color3.fromRGB(220, 220, 220) }
			):Play()
			v6:Create(str, A.HOVER, { Color = Color3.fromRGB(50, 50, 55) }):Play()
		end)

		b.MouseButton1Click:Connect(function()
			cb(b)
		end)
		add_press_feedback(b)
		return b
	end

	function M.tb(p, t, df, cb, desc, max_chars)
		local f = Instance.new("Frame", p)
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 34)
		f.AutomaticSize = Enum.AutomaticSize.Y

		local l = Instance.new("TextLabel", f)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 12)
		l.Text = t
		l.TextColor3 = Color3.fromRGB(180, 180, 180)
		l.TextXAlignment = 0
		l.Font = Enum.Font.Gotham
		l.TextSize = 8

		local box = Instance.new("TextBox", f)
		box.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		box.Position = UDim2.new(0, 0, 0, 14)
		box.Size = UDim2.new(1, 0, 0, 18)
		box.Text = tostring(df or "")
		box.PlaceholderText = "type a message"
		box.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
		box.TextColor3 = Color3.fromRGB(255, 255, 255)
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 9
		box.ClearTextOnFocus = false
		box.ClipsDescendants = true
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

		local str = Instance.new("UIStroke", box)
		str.Color = Color3.fromRGB(50, 50, 55)
		str.Thickness = 1

		if desc then
			local dl = Instance.new("TextLabel", f)
			dl.BackgroundTransparency = 1
			dl.Position = UDim2.new(0, 0, 0, 34)
			dl.Size = UDim2.new(1, 0, 0, 0)
			dl.AutomaticSize = Enum.AutomaticSize.Y
			dl.Text = desc
			dl.TextColor3 = Color3.fromRGB(120, 120, 130)
			dl.TextXAlignment = 0
			dl.TextYAlignment = 0
			dl.Font = Enum.Font.Gotham
			dl.TextSize = 8
			dl.TextWrapped = true
		end

		box.Focused:Connect(function()
			v6:Create(str, A.TINT, { Color = Color3.fromRGB(0, 255, 200) }):Play()
		end)

		box.FocusLost:Connect(function()
			v6:Create(str, A.TINT, { Color = Color3.fromRGB(50, 50, 55) }):Play()
			local v = box.Text:gsub("[\r\n]", " ")
			if max_chars and #v > max_chars then
				v = v:sub(1, max_chars)
			end
			box.Text = v
			cb(v)
			if save_settings then
				save_settings()
			end
		end)

		return box
	end

	function M.h(p, t)
		local l = Instance.new("TextLabel", p)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 20)
		l.Text = t:upper()
		l.TextColor3 = Color3.fromRGB(100, 100, 110)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 9
		l.TextXAlignment = Enum.TextXAlignment.Left
	end

	return M
end
