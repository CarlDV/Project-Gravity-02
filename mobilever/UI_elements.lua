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

		local vl = Instance.new("TextLabel", f)
		vl.BackgroundTransparency = 1
		vl.Position = UDim2.new(1, -50, 0, 0)
		vl.Size = UDim2.new(0, 50, 0, 12)
		vl.Text = tostring(df)
		vl.TextColor3 = Color3.fromRGB(255, 255, 255)
		vl.TextXAlignment = 1
		vl.Font = Enum.Font.GothamBold
		vl.TextSize = 8

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
		local function u(pos_x)
			local rp = pos_x - sc.AbsolutePosition.X
			local pc = math.clamp(rp / sc.AbsoluteSize.X, 0, 1)
			local v = mn + (mx - mn) * pc
			if is_int or mx - mn > 50 then
				v = math.floor(v + 0.5)
			else
				v = math.floor(v * 10 + 0.5) / 10
			end
			local snapped_pc = (v - mn) / (mx - mn)
			v6:Create(fl, TweenInfo.new(0.1), { Size = UDim2.new(snapped_pc, 0, 1, 0) }):Play()
			v6:Create(k, TweenInfo.new(0.1), { Position = UDim2.new(snapped_pc, 0, 0.5, 0) }):Play()
			vl.Text = tostring(v)
			cb(v)
			if save_settings then
				save_settings()
			end
		end

		k.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				active_input = i
				u(i.Position.X)
			end
		end)
		sb.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				active_input = i
				u(i.Position.X)
			end
		end)
		local c1 = v1.InputEnded:Connect(function(i)
			if i == active_input then
				active_input = nil
			end
		end)
		local c2 = v1.InputChanged:Connect(function(i)
			if i == active_input then
				u(i.Position.X)
			end
		end)

		f.AncestryChanged:Connect(function(_, parent)
			if not parent then
				c1:Disconnect()
				c2:Disconnect()
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
			v6:Create(
				bg,
				TweenInfo.new(0.2),
				{ BackgroundColor3 = df and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(40, 40, 45) }
			):Play()
			v6:Create(
				toggle,
				TweenInfo.new(0.2),
				{ Position = df and UDim2.new(1, -10, 0.5, -4) or UDim2.new(0, 2, 0.5, -4) }
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
