return function(context)
	local v1, v6 = context.v1, context.v6
	local save_settings = context.save_settings
	local M = {}

	function M.s(p, t, mn, mx, df, cb, is_int, desc)
		df = df or mn
		if is_int or mx - mn > 50 then
			df = math.floor(df + 0.5)
		else
			df = math.floor(df * 10 + 0.5) / 10
		end
		local f = Instance.new("Frame", p)
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 42)
		f.AutomaticSize = Enum.AutomaticSize.Y

		local l = Instance.new("TextLabel", f)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 20)
		l.Text = t
		l.TextColor3 = Color3.fromRGB(180, 180, 180)
		l.TextXAlignment = 0
		l.Font = Enum.Font.Gotham
		l.TextSize = 12

		local vl = Instance.new("TextBox", f)
		vl.BackgroundTransparency = 1
		vl.Position = UDim2.new(1, -50, 0, 0)
		vl.Size = UDim2.new(0, 50, 0, 20)
		vl.Text = tostring(df)
		vl.TextColor3 = Color3.fromRGB(255, 255, 255)
		vl.TextXAlignment = 1
		vl.Font = Enum.Font.GothamBold
		vl.TextSize = 12
		-- clearing on focus makes the common case one action: click, type, Enter.
		-- an accidental click that types nothing is restored by FocusLost below
		vl.ClearTextOnFocus = true
		vl.TextEditable = true
		-- the name label spans this whole row; lift the box so the click lands here
		vl.ZIndex = 2

		local sc = Instance.new("Frame", f)
		sc.BackgroundTransparency = 1
		sc.Position = UDim2.new(0, 0, 0, 26)
		sc.Size = UDim2.new(1, 0, 0, 4)

		if desc then
			local d = Instance.new("TextLabel", f)
			d.BackgroundTransparency = 1
			d.Position = UDim2.new(0, 0, 0, 38)
			d.Size = UDim2.new(1, 0, 0, 0)
			d.AutomaticSize = Enum.AutomaticSize.Y
			d.Text = desc
			d.TextColor3 = Color3.fromRGB(120, 120, 130)
			d.TextXAlignment = 0
			d.TextYAlignment = 0
			d.Font = Enum.Font.Gotham
			d.TextSize = 10
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
		k.Size = UDim2.new(0, 12, 0, 12)
		k.BorderSizePixel = 0
		k.AutoButtonColor = false
		Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

		local dragging = false
		local hover_slider = false
		local current = df

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
			v6:Create(fl, TweenInfo.new(0.1), { Size = UDim2.new(snapped_pc, 0, 1, 0) }):Play()
			v6:Create(k, TweenInfo.new(0.1), { Position = UDim2.new(snapped_pc, 0, 0.5, 0) }):Play()
			vl.Text = tostring(v)
			cb(v)
			if save_settings then
				save_settings()
			end
		end

		local function u(i)
			local rp = i.Position.X - sc.AbsolutePosition.X
			local pc = math.clamp(rp / sc.AbsoluteSize.X, 0, 1)
			apply(mn + (mx - mn) * pc)
		end

		k.MouseButton1Down:Connect(function()
			dragging = true
		end)
		sb.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				hover_slider = true
				u(i)
			end
		end)
		k.MouseEnter:Connect(function()
			hover_slider = true
		end)
		k.MouseLeave:Connect(function()
			hover_slider = false
		end)
		sb.MouseEnter:Connect(function()
			hover_slider = true
		end)
		sb.MouseLeave:Connect(function()
			hover_slider = false
		end)
		local c1 = v1.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
		local c2 = v1.InputChanged:Connect(function(i)
			if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
				u(i)
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
			v6:Create(vl, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(0, 255, 200) }):Play()
		end)

		vl.FocusLost:Connect(function()
			v6:Create(vl, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
			local typed = tonumber(vl.Text)
			-- nil on garbage, and NaN fails its own equality test
			if not typed or typed ~= typed then
				vl.Text = tostring(current)
				return
			end
			apply(typed)
		end)

		vl.MouseEnter:Connect(function()
			if not vl:IsFocused() then
				v6:Create(vl, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(0, 255, 200) }):Play()
			end
		end)
		vl.MouseLeave:Connect(function()
			if not vl:IsFocused() then
				v6:Create(vl, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
			end
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
		f.Size = UDim2.new(1, 0, 0, 32)
		f.AutomaticSize = Enum.AutomaticSize.Y

		local l = Instance.new("TextLabel", f)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(0.8, 0, 0, 20)
		l.Text = t
		l.TextColor3 = Color3.fromRGB(180, 180, 180)
		l.TextXAlignment = 0
		l.Font = Enum.Font.Gotham
		l.TextSize = 12

		if desc then
			local d = Instance.new("TextLabel", f)
			d.BackgroundTransparency = 1
			d.Position = UDim2.new(0, 0, 0, 20)
			d.Size = UDim2.new(1, -40, 0, 0)
			d.AutomaticSize = Enum.AutomaticSize.Y
			d.Text = desc
			d.TextColor3 = Color3.fromRGB(120, 120, 130)
			d.TextXAlignment = 0
			d.TextYAlignment = 0
			d.Font = Enum.Font.Gotham
			d.TextSize = 10
			d.TextWrapped = true
		end

		local bg = Instance.new("Frame", f)
		bg.BackgroundColor3 = df and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(40, 40, 45)
		bg.Position = UDim2.new(1, -36, 0, 1)
		bg.Size = UDim2.new(0, 36, 0, 18)
		Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

		local toggle = Instance.new("Frame", bg)
		toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		toggle.Position = df and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
		toggle.Size = UDim2.new(0, 14, 0, 14)
		Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

		local b = Instance.new("TextButton", f)
		b.BackgroundTransparency = 1
		b.Size = UDim2.new(1, 0, 1, 0)
		b.Text = ""

		b.MouseButton1Click:Connect(function()
			df = not df
			v6:Create(
				bg,
				TweenInfo.new(0.2),
				{ BackgroundColor3 = df and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(40, 40, 45) }
			):Play()
			v6:Create(
				toggle,
				TweenInfo.new(0.2),
				{ Position = df and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) }
			):Play()
			cb(df)
			if save_settings then
				save_settings()
			end
		end)
		return b
	end

	function M.b(p, t, cb)
		local b = Instance.new("TextButton", p)
		b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		b.Size = UDim2.new(1, 0, 0, 34)
		b.AutoButtonColor = false
		b.Text = t
		b.TextColor3 = Color3.fromRGB(220, 220, 220)
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 13
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

		local str = Instance.new("UIStroke", b)
		str.Color = Color3.fromRGB(50, 50, 55)
		str.Thickness = 1

		b.MouseEnter:Connect(function()
			v6:Create(
				b,
				TweenInfo.new(0.2),
				{ BackgroundColor3 = Color3.fromRGB(40, 40, 45), TextColor3 = Color3.fromRGB(255, 255, 255) }
			):Play()
		end)
		b.MouseLeave:Connect(function()
			v6:Create(
				b,
				TweenInfo.new(0.2),
				{ BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Color3.fromRGB(220, 220, 220) }
			):Play()
		end)

		b.MouseButton1Click:Connect(function()
			cb(b)
		end)
		return b
	end

	function M.sub_b(p, t, cb)
		local b = Instance.new("TextButton", p)
		b.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		b.Size = UDim2.new(1, 0, 0, 32)
		b.AutoButtonColor = false
		b.Text = t
		b.TextColor3 = Color3.fromRGB(0, 255, 200)
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 11
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

		local str = Instance.new("UIStroke", b)
		str.Color = Color3.fromRGB(40, 40, 45)
		str.Thickness = 1

		b.MouseEnter:Connect(function()
			v6:Create(b, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(35, 35, 40) }):Play()
		end)
		b.MouseLeave:Connect(function()
			v6:Create(b, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(25, 25, 30) }):Play()
		end)

		b.MouseButton1Click:Connect(function() cb(b) end)
		return b
	end

	function M.tb(p, t, df, cb, desc, max_chars)
		local f = Instance.new("Frame", p)
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 52)
		f.AutomaticSize = Enum.AutomaticSize.Y

		local l = Instance.new("TextLabel", f)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 20)
		l.Text = t
		l.TextColor3 = Color3.fromRGB(180, 180, 180)
		l.TextXAlignment = 0
		l.Font = Enum.Font.Gotham
		l.TextSize = 12

		local box = Instance.new("TextBox", f)
		box.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		box.Position = UDim2.new(0, 0, 0, 22)
		box.Size = UDim2.new(1, 0, 0, 26)
		box.Text = tostring(df or "")
		box.PlaceholderText = "type a message"
		box.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
		box.TextColor3 = Color3.fromRGB(255, 255, 255)
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 12
		box.ClearTextOnFocus = false
		box.ClipsDescendants = true
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

		local str = Instance.new("UIStroke", box)
		str.Color = Color3.fromRGB(50, 50, 55)
		str.Thickness = 1

		if desc then
			local dl = Instance.new("TextLabel", f)
			dl.BackgroundTransparency = 1
			dl.Position = UDim2.new(0, 0, 0, 50)
			dl.Size = UDim2.new(1, 0, 0, 0)
			dl.AutomaticSize = Enum.AutomaticSize.Y
			dl.Text = desc
			dl.TextColor3 = Color3.fromRGB(120, 120, 130)
			dl.TextXAlignment = 0
			dl.TextYAlignment = 0
			dl.Font = Enum.Font.Gotham
			dl.TextSize = 10
			dl.TextWrapped = true
		end

		box.Focused:Connect(function()
			v6:Create(str, TweenInfo.new(0.2), { Color = Color3.fromRGB(0, 255, 200) }):Play()
		end)

		box.FocusLost:Connect(function()
			v6:Create(str, TweenInfo.new(0.2), { Color = Color3.fromRGB(50, 50, 55) }):Play()
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

	-- Only one row may listen at a time, or two rows would both consume the same
	-- press and the second would overwrite the first.
	local active_capture = nil

	-- A rebindable key row. get_key returns the currently bound key name (""
	-- when unbound); on_capture is handed the new name and returns true if it
	-- accepted it, which is where the caller does its conflict check. Passing ""
	-- means the user cleared the bind.
	function M.kb(p, label_text, get_key, on_capture, desc)
		local f = Instance.new("Frame", p)
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 32)
		f.AutomaticSize = Enum.AutomaticSize.Y

		local l = Instance.new("TextLabel", f)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, -104, 0, 22)
		l.Text = label_text
		l.TextColor3 = Color3.fromRGB(180, 180, 180)
		l.TextXAlignment = 0
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Font = Enum.Font.Gotham
		l.TextSize = 12

		if desc then
			local d = Instance.new("TextLabel", f)
			d.BackgroundTransparency = 1
			d.Position = UDim2.new(0, 0, 0, 22)
			d.Size = UDim2.new(1, -104, 0, 0)
			d.AutomaticSize = Enum.AutomaticSize.Y
			d.Text = desc
			d.TextColor3 = Color3.fromRGB(120, 120, 130)
			d.TextXAlignment = 0
			d.TextYAlignment = 0
			d.Font = Enum.Font.Gotham
			d.TextSize = 10
			d.TextWrapped = true
		end

		local btn = Instance.new("TextButton", f)
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		btn.Position = UDim2.new(1, -100, 0, 0)
		btn.Size = UDim2.new(0, 100, 0, 24)
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.ClipsDescendants = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		local str = Instance.new("UIStroke", btn)
		str.Color = Color3.fromRGB(50, 50, 55)
		str.Thickness = 1

		local capturing = false

		local function refresh()
			if capturing then
				btn.Text = "PRESS A KEY"
				btn.TextColor3 = Color3.fromRGB(0, 255, 200)
				return
			end
			local key = get_key()
			if type(key) == "string" and key ~= "" then
				btn.Text = key
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.Text = "UNBOUND"
				btn.TextColor3 = Color3.fromRGB(110, 110, 120)
			end
		end

		local conn = nil

		local function stop(rebind)
			if conn then
				conn:Disconnect()
				conn = nil
			end
			if active_capture == stop then
				active_capture = nil
			end
			capturing = false
			-- The script's own hotkeys were taken down for the duration of the
			-- capture so that binding Q could not also fire Reset on the way in.
			if rebind then
				local x8 = context.x8
				if x8 and x8.rebind_all then
					pcall(x8.rebind_all)
				end
			end
			v6:Create(str, TweenInfo.new(0.15), { Color = Color3.fromRGB(50, 50, 55) }):Play()
			refresh()
		end

		local function begin()
			if capturing then
				stop(true)
				return
			end
			if active_capture then
				active_capture(true)
			end
			capturing = true
			active_capture = stop
			refresh()
			v6:Create(str, TweenInfo.new(0.15), { Color = Color3.fromRGB(0, 255, 200) }):Play()
			-- Unbound while listening: otherwise the press being captured also
			-- runs whatever currently holds that key.
			local x8 = context.x8
			if x8 and x8.unbind_all then
				pcall(x8.unbind_all)
			end
			conn = v1.InputBegan:Connect(function(i)
				if i.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				-- A focused text box owns the keyboard; capturing here would
				-- steal the keys the user is typing into the search field.
				if v1:GetFocusedTextBox() then
					return
				end
				local code = i.KeyCode
				if code == Enum.KeyCode.Unknown then
					return
				end
				if code == Enum.KeyCode.Escape then
					stop(true)
					return
				end
				if code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete then
					on_capture("")
					stop(true)
					return
				end
				on_capture(code.Name)
				stop(true)
			end)
		end

		btn.MouseButton1Click:Connect(begin)

		btn.MouseEnter:Connect(function()
			if not capturing then
				v6:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(40, 40, 45) }):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			v6:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(30, 30, 35) }):Play()
		end)

		-- The row can be torn down mid-capture (the window rebuilds on every
		-- search keystroke), which would otherwise leave the listener running
		-- and the script's hotkeys unbound for good.
		f.AncestryChanged:Connect(function(_, parent)
			if not parent and capturing then
				stop(true)
			end
		end)

		refresh()
		return f, refresh
	end

	function M.h(p, t)
		local l = Instance.new("TextLabel", p)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 24)
		l.Text = t:upper()
		l.TextColor3 = Color3.fromRGB(100, 100, 110)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 10
		l.TextXAlignment = Enum.TextXAlignment.Left
	end

	return M
end
