return function(context)
	local v1, v2, v3, v4, v5, v6, v7, v8, v9 = context.v1, context.v2, context.v3, context.v4, context.v5, context.v6, context.v7, context.v8, context.v9
	local x1, x2, x6, x9 = context.x1, context.x2, context.x6, context.x9
	local favorites, save_favs, save_settings = context.favorites, context.save_favs, context.save_settings
	local get_shape = context.get_shape
	local load_module = context.load_module
	local SUB_DIR = context.SUB_DIR or "mobilever/"

	local UI_elements = load_module(SUB_DIR .. "UI_elements.lua")(context)
	local es, et, eb, eh = UI_elements.s, UI_elements.t, UI_elements.b, UI_elements.h

	local x5 = {}
	x5.g = nil
	x5.s = es
	x5.t = et
	x5.b = eb
	x5.h = eh

	local stable_shapes = {
		["Cursed Technique Red"] = true,
		["Galactic Web"] = true,
		["Celestial Ribbon"] = true,
		["Big Ring Things"] = true,
		["Point Impact"] = true,
		["Orbital Shell"] = true
	}

	function x5.st()
		if x5.g and x5.up then
			x5.up()
			return
		end
		if x5.g then
			x5.g:Destroy()
		end
		local sg = Instance.new("ScreenGui")
		sg.Name = "G_" .. math.random(999)
		if gethui then
			sg.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(sg)
			sg.Parent = game:GetService("CoreGui")
		else
			sg.Parent = v8:WaitForChild("PlayerGui")
		end
		x6.sg = sg
		x5.g = sg
		x5.mw(sg)
	end

	function x5.mw(sg)
		local function toggle_window(win, state)
			local scale = win:FindFirstChild("UIScale")
			if not scale then
				scale = Instance.new("UIScale", win)
				scale.Scale = 0.8
			end
			local prop = win:IsA("CanvasGroup") and "GroupTransparency" or "BackgroundTransparency"
			if state then
				win.Visible = true
				v6:Create(win, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {[prop] = 0}):Play()
				v6:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			else
				local tw = v6:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {[prop] = 1})
				v6:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {Scale = 0.8}):Play()
				local conn
				conn = tw.Completed:Connect(function() 
					if win[prop] >= 0.99 then win.Visible = false end 
					if conn then conn:Disconnect() end
				end)
				tw:Play()
			end
		end

		local hud = Instance.new("Frame", sg)
		hud.Name = "StatusHUD"
		hud.BackgroundTransparency = 1
		hud.Position = UDim2.new(0.5, -150, 0, 10)
		hud.Size = UDim2.new(0, 300, 0, 30)

		local hud_l = Instance.new("TextLabel", hud)
		hud_l.BackgroundTransparency = 1
		hud_l.Size = UDim2.new(1, 0, 1, 0)
		hud_l.Font = Enum.Font.GothamBold
		hud_l.TextSize = 9
		hud_l.TextColor3 = Color3.fromRGB(255, 255, 255)

		table.insert(
			x6.c,
			v3.RenderStepped:Connect(function()
				if not x5.g then
					return
				end
				local tgt = x1.Tgt and (x1.Tgt.DisplayName or x1.Tgt.Name) or "None"
				local state = x1.Disabled and "DISABLED" or (x1.Paused and "PAUSED" or "ACTIVE")
				local col = x1.Disabled and Color3.fromRGB(255, 80, 80)
					or (x1.Paused and Color3.fromRGB(255, 180, 80) or Color3.fromRGB(80, 255, 150))
				hud_l.Text = string.format("TARGET: %s  |  STATUS: %s", tgt:upper(), state)
				hud_l.TextColor3 = col
			end)
		)

		hud.Visible = x1.ShowHUD ~= false

		local m = Instance.new("Frame", sg)
		m.Name = "Main"
		m.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		m.Position = UDim2.new(0.5, -110, 0.5, -160)
		m.Size = UDim2.new(0, 180, 0, 250)
		m.Active = true
		m.Draggable = true
		Instance.new("UICorner", m).CornerRadius = UDim.new(0, 10)
		local ms = Instance.new("UIStroke", m)
		ms.Color = Color3.fromRGB(40, 40, 45)
		ms.Thickness = 1

		local h = Instance.new("Frame", m)
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, 0, 0, 26)

		local t = Instance.new("TextLabel", h)
		t.BackgroundTransparency = 1
		t.Position = UDim2.new(0, 15, 0, 0)
		t.Size = UDim2.new(0.6, 0, 1, 0)
		t.Text = "PROJECT GRAVITY"
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 10
		t.TextXAlignment = 0

		local c = Instance.new("ScrollingFrame", m)
		c.BackgroundTransparency = 1
		c.Position = UDim2.new(0, 0, 0, 40)
		c.Size = UDim2.new(1, 0, 1, -50)
		c.ScrollBarThickness = 0
		c.AutomaticCanvasSize = Enum.AutomaticSize.Y
		c.CanvasSize = UDim2.new(0, 0, 0, 0)
		local l = Instance.new("UIListLayout", c)
		l.Padding = UDim.new(0, 10)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local p = Instance.new("UIPadding", c)
		p.PaddingLeft = UDim.new(0, 15)
		p.PaddingRight = UDim.new(0, 15)
		p.PaddingBottom = UDim.new(0, 15)

		local am = Instance.new("Frame", sg)
		am.Name = "Advanced"
		am.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		am.Position = UDim2.new(0.5, -90, 0.5, -125)
		am.Size = UDim2.new(0, 140, 0, 190)
		am.Visible = false
		am.Active = true
		am.Draggable = true
		Instance.new("UICorner", am).CornerRadius = UDim.new(0, 10)
		local ams = Instance.new("UIStroke", am)
		ams.Color = Color3.fromRGB(40, 40, 45)
		ams.Thickness = 1

		local ah = Instance.new("Frame", am)
		ah.BackgroundTransparency = 1
		ah.Size = UDim2.new(1, 0, 0, 26)
		local at = Instance.new("TextLabel", ah)
		at.BackgroundTransparency = 1
		at.Position = UDim2.new(0, 15, 0, 0)
		at.Size = UDim2.new(0.6, 0, 1, 0)
		at.Text = "ADVANCED"
		at.TextColor3 = Color3.fromRGB(255, 255, 255)
		at.Font = Enum.Font.GothamBold
		at.TextSize = 8
		at.TextXAlignment = 0

		local close_am = Instance.new("TextButton", ah)
		close_am.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		close_am.Position = UDim2.new(1, -22, 0.5, -7)
		close_am.Size = UDim2.new(0, 14, 0, 14)
		close_am.Text = ""
		Instance.new("UICorner", close_am).CornerRadius = UDim.new(1, 0)
		close_am.MouseButton1Click:Connect(function()
			am.Visible = false
		end)

		local ac = Instance.new("ScrollingFrame", am)
		ac.BackgroundTransparency = 1
		ac.Position = UDim2.new(0, 0, 0, 35)
		ac.Size = UDim2.new(1, 0, 1, -45)
		ac.ScrollBarThickness = 0
		ac.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ac.CanvasSize = UDim2.new(0, 0, 0, 0)
		local acl = Instance.new("UIListLayout", ac)
		acl.Padding = UDim.new(0, 8)
		acl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local ap = Instance.new("UIPadding", ac)
		ap.PaddingLeft = UDim.new(0, 15)
		ap.PaddingRight = UDim.new(0, 15)

		et(ac, "Predictive Tracking", x1.PredictiveTracking ~= false, function(v)
			x1.PredictiveTracking = v
			save_settings()
		end)
		es(ac, "Prediction Factor", 0, 500, x1.PredictionFactor or 150, function(v)
			x1.PredictionFactor = v
			save_settings()
		end)
		es(ac, "Damping", 0, 5, x1.Damping, function(v)
			x1.Damping = v
			save_settings()
		end)
		es(ac, "Integral Gain", 0, 10, x1.Ki, function(v)
			x1.Ki = v
			save_settings()
		end)
		es(ac, "Max Speed", 50, 2000, x1.MaxSpeed or 500, function(v)
			x1.MaxSpeed = v
			save_settings()
		end)
		es(ac, "Angular Damp", 0, 1, x1.AngularDamping or 0.5, function(v)
			x1.AngularDamping = v
			save_settings()
		end)
		es(ac, "Vert Stiffness", 0.1, 5, x1.VerticalStiffness or 1.0, function(v)
			x1.VerticalStiffness = v
			save_settings()
		end)
		if setfpscap then
			es(ac, "FPS Cap (0=Unc)", 0, 144, x1.FPSCap or 60, function(v)
				x1.FPSCap = v
				setfpscap(v)
				save_settings()
			end, true)
		end

		local ab = eb(c, "Advanced Settings", function()
			am.Visible = not am.Visible
		end)
		ab.Size = UDim2.new(1, 0, 0, 20)

		local mode_f = Instance.new("Frame", c)
		mode_f.BackgroundTransparency = 1
		mode_f.Size = UDim2.new(1, 0, 0, 24)
		local db = Instance.new("TextButton", mode_f)
		db.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		db.Size = UDim2.new(1, 0, 1, 0)
		db.Text = "  " .. x1.k6:upper()
		db.TextColor3 = Color3.fromRGB(255, 255, 255)
		db.Font = Enum.Font.GothamBold
		db.TextSize = 9
		db.TextXAlignment = 0
		Instance.new("UICorner", db).CornerRadius = UDim.new(0, 6)
		local dst = Instance.new("UIStroke", db)
		dst.Color = Color3.fromRGB(40, 40, 45)

		local arr = Instance.new("TextLabel", db)
		arr.BackgroundTransparency = 1
		arr.Position = UDim2.new(1, -30, 0, 0)
		arr.Size = UDim2.new(0, 30, 1, 0)
		arr.Text = "▼"
		arr.TextColor3 = Color3.fromRGB(150, 150, 160)
		arr.TextSize = 10

		db.MouseButton1Click:Connect(function()
			if x6.dlst_container then
				local new_state = not x6.dlst_container.Visible
				if x6.tdlst_container and x6.tdlst_container.Visible then
					toggle_window(x6.tdlst_container, false)
				end
				toggle_window(x6.dlst_container, new_state)
				if new_state and x6.populate_modes then
					x6.populate_modes("")
				end
			end
		end)

		local gsc = Instance.new("Frame", c)
		gsc.BackgroundTransparency = 1
		gsc.Size = UDim2.new(1, 0, 0, 0)
		gsc.AutomaticSize = Enum.AutomaticSize.Y
		local gscl = Instance.new("UIListLayout", gsc)
		gscl.Padding = UDim.new(0, 8)
		gscl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local sc = Instance.new("Frame", c)
		sc.BackgroundTransparency = 1
		sc.Size = UDim2.new(1, 0, 0, 0)
		sc.AutomaticSize = Enum.AutomaticSize.Y
		local scl = Instance.new("UIListLayout", sc)
		scl.Padding = UDim.new(0, 8)
		scl.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local function f1()
			if x6.f1_connections then
				for _, conn in ipairs(x6.f1_connections) do
					if conn then conn:Disconnect() end
				end
				table.clear(x6.f1_connections)
			else
				x6.f1_connections = {}
			end
			sc:ClearAllChildren()
			gsc:ClearAllChildren()
			local gscl = Instance.new("UIListLayout", gsc)
			gscl.Padding = UDim.new(0, 10)
			gscl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			local scl = Instance.new("UIListLayout", sc)
			scl.Padding = UDim.new(0, 8)
			scl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			local s = x1.S[x1.k6] or {}

			eh(gsc, "Control")


			et(gsc, "Show HUD", x1.ShowHUD ~= false, function(v)
				x1.ShowHUD = v
				if hud then hud.Visible = v end
				save_settings()
			end)

			et(gsc, "Anchor to Self", x1.AnchorSelf, function(v)
				x1.AnchorSelf = v
				save_settings()
			end)

			if not x1.SimpleMode then
				et(gsc, "Anti-Fling", x1.AntiFling, function(v)
					x1.AntiFling = v
					save_settings()
				end)
				et(gsc, "SM(ps.lag)", x1["SM(ps.lag)"], function(v)
					x1["SM(ps.lag)"] = v
					save_settings()
				end)
			end

			x6.disable_btn = et(gsc, "Disable Gravity", x1.Disabled, function(v)
				x1.Disabled = v
				save_settings()
				if x6.b then
					x6.b.Transparency = v and 1 or 0.8
					if x6.b:FindFirstChild("Visual") then
						x6.b.Visual.Enabled = not v
					end
				end
				for _, d in pairs(x6.a) do
					if d.lv then
						d.lv.MaxForce = v and 0 or x1.k4
					end
				end
			end)

			if not x1.SimpleMode then
				et(gsc, "Target Everyone", x1.PI_All, function(v)
					x1.PI_All = v
					save_settings()
				end)
			end

			local l_btn = Instance.new("TextButton", gsc)
			l_btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			l_btn.Size = UDim2.new(1, 0, 0, 20)
			l_btn.Text = "FORCE LAUNCH"
			l_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			l_btn.Font = Enum.Font.GothamBold
			l_btn.TextSize = 9
			Instance.new("UICorner", l_btn).CornerRadius = UDim.new(0, 6)
			l_btn.Visible = x1.ImpactManual or (x1.k6 == "Slingshot" and x1.SlingshotManual)

			l_btn.MouseButton1Click:Connect(function()
				x1.IsLaunching = not x1.IsLaunching
				l_btn.Text = x1.IsLaunching and "RESET SYSTEM" or "FORCE LAUNCH"
				l_btn.BackgroundColor3 = x1.IsLaunching and Color3.fromRGB(50, 150, 200) or Color3.fromRGB(200, 50, 50)
			end)

			table.insert(
				x6.f1_connections,
				v3.Heartbeat:Connect(function()
					if x1.ImpactManual or (x1.k6 == "Slingshot" and x1.SlingshotManual) then
						l_btn.Visible = true
						l_btn.Text = x1.IsLaunching and "RESET SYSTEM" or "FORCE LAUNCH"
						l_btn.BackgroundColor3 = x1.IsLaunching and Color3.fromRGB(50, 150, 200)
							or Color3.fromRGB(200, 50, 50)
					else
						l_btn.Visible = false
					end
				end)
			)

			local tn = "Select Target"
			if x1.Targets and #x1.Targets > 0 then
				if #x1.Targets == 1 then
					tn = "Target: " .. (x1.Targets[1].DisplayName or x1.Targets[1].Name)
				else
					tn = "Multi-Target (" .. tostring(#x1.Targets) .. ")"
				end
			end

			local tdb = Instance.new("TextButton", gsc)
			tdb.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
			tdb.Size = UDim2.new(1, 0, 0, 22)
			tdb.Text = "  " .. tn:upper()
			tdb.TextColor3 = Color3.fromRGB(255, 255, 255)
			tdb.Font = Enum.Font.GothamBold
			tdb.TextSize = 8
			tdb.TextXAlignment = 0
			Instance.new("UICorner", tdb).CornerRadius = UDim.new(0, 6)
			local dst2 = Instance.new("UIStroke", tdb)
			dst2.Color = Color3.fromRGB(40, 40, 45)

			if x1.Targets and #x1.Targets > 0 then
				local ctb = Instance.new("TextButton", tdb)
				ctb.BackgroundTransparency = 1
				ctb.Position = UDim2.new(1, -25, 0, 0)
				ctb.Size = UDim2.new(0, 25, 1, 0)
				ctb.Text = "×"
				ctb.TextColor3 = Color3.fromRGB(200, 80, 80)
				ctb.TextSize = 16
				ctb.MouseButton1Click:Connect(function()
					table.clear(x1.Targets)
					x1.TgtActive = false
					f1()
				end)
			end

			tdb.MouseButton1Click:Connect(function()
				if x6.tdlst_container then
					local new_state = not x6.tdlst_container.Visible
					if x6.dlst_container and x6.dlst_container.Visible then
						toggle_window(x6.dlst_container, false)
					end
					toggle_window(x6.tdlst_container, new_state)
					if new_state and x6.update_targets then
						x6.update_targets("")
					end
				end
			end)

			if not x1.SimpleMode then
				eh(sc, "Shape")
				local shape_mod = get_shape(x1.k6)
				if shape_mod and shape_mod.Controls then
					for _, ctrl in ipairs(shape_mod.Controls) do
						local current_val = s[ctrl.Key]
						local p_frame = ctrl.Parent == "gsc" and gsc or sc
						if ctrl.Type == "Slider" then
							if current_val == nil then
								if ctrl.Default ~= nil then
									current_val = ctrl.Default
								else
									current_val = ctrl.Min
								end
							end
							if ctrl.Div then current_val = current_val * ctrl.Div end
							es(p_frame, ctrl.Name, ctrl.Min, ctrl.Max, current_val, function(v)
								if ctrl.Div then s[ctrl.Key] = v / ctrl.Div else s[ctrl.Key] = v end
							end, ctrl.IntOnly)
						elseif ctrl.Type == "Toggle" then
							if current_val == nil then
								current_val = ctrl.Default ~= nil and ctrl.Default or false
							end
							et(p_frame, ctrl.Name, current_val, function(v)
								s[ctrl.Key] = v
							end)
						end
					end
				end
			end
		end
		x5.up = f1

		local dlst_container = Instance.new("CanvasGroup", sg)
		dlst_container.Name = "ModeSelector"
		dlst_container.Visible = false
		dlst_container.GroupTransparency = 1
		dlst_container.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		dlst_container.Position = UDim2.new(0.5, 90, 0.5, -160)
		dlst_container.Size = UDim2.new(0, 180, 0, 250)
		dlst_container.Active = true
		dlst_container.Draggable = true
		Instance.new("UICorner", dlst_container).CornerRadius = UDim.new(0, 10)
		local dls = Instance.new("UIStroke", dlst_container)
		dls.Color = Color3.fromRGB(40, 40, 45)

		local top_dlst = Instance.new("Frame", dlst_container)
		top_dlst.BackgroundTransparency = 1
		top_dlst.Size = UDim2.new(1, 0, 0, 30)
		top_dlst.ZIndex = 11

		local back_dlst = Instance.new("TextButton", top_dlst)
		back_dlst.BackgroundTransparency = 1
		back_dlst.Position = UDim2.new(0, 10, 0, 5)
		back_dlst.Size = UDim2.new(0, 50, 0, 30)
		back_dlst.Text = "◄ Back"
		back_dlst.TextColor3 = Color3.fromRGB(150, 150, 155)
		back_dlst.Font = Enum.Font.GothamBold
		back_dlst.TextSize = 12
		back_dlst.ZIndex = 12
		back_dlst.MouseButton1Click:Connect(function()
			toggle_window(dlst_container, false)
		end)

		local msb = Instance.new("TextBox", dlst_container)
		msb.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		msb.Position = UDim2.new(0, 10, 0, 35)
		msb.Size = UDim2.new(1, -20, 0, 20)
		msb.PlaceholderText = "Search modes..."
		msb.Text = ""
		msb.TextColor3 = Color3.fromRGB(255, 255, 255)
		msb.Font = Enum.Font.Gotham
		msb.TextSize = 9
		msb.ZIndex = 11
		Instance.new("UICorner", msb).CornerRadius = UDim.new(0, 6)

		local dlst = Instance.new("ScrollingFrame", dlst_container)
		dlst.BackgroundTransparency = 1
		dlst.Position = UDim2.new(0, 0, 0, 70)
		dlst.Size = UDim2.new(1, 0, 1, -80)
		dlst.ScrollBarThickness = 0
		dlst.AutomaticCanvasSize = Enum.AutomaticSize.Y
		dlst.CanvasSize = UDim2.new(0, 0, 0, 0)
		dlst.ZIndex = 11

		x6.dlst_container = dlst_container

		local function populate_modes(filter)
			dlst:ClearAllChildren()
			local dll = Instance.new("UIListLayout", dlst)
			dll.Padding = UDim.new(0, 5)
			dll.HorizontalAlignment = Enum.HorizontalAlignment.Center

			local modes = {}
			for mn, _ in pairs(x2) do
				table.insert(modes, mn)
			end

			table.sort(modes, function(a, b)
				local fa, fb = favorites[a] and 1 or 0, favorites[b] and 1 or 0
				if fa ~= fb then
					return fa > fb
				end
				local sa, sb = stable_shapes[a] and 1 or 0, stable_shapes[b] and 1 or 0
				if sa ~= sb then
					return sa > sb
				end
				return a < b
			end)

			for _, mn in ipairs(modes) do
				if filter ~= "" and not mn:lower():find(filter:lower()) then
					continue
				end

				local is_stable = stable_shapes[mn]
				local f = Instance.new("Frame", dlst)
				f.Size = UDim2.new(1, -16, 0, 24)
				f.BackgroundColor3 = mn == x1.k6 and Color3.fromRGB(40, 40, 180) or Color3.fromRGB(25, 25, 30)
				f.ZIndex = 12
				Instance.new("UICorner", f).CornerRadius = is_stable and UDim.new(1, 0) or UDim.new(0, 4)
				
				if not is_stable then
					local fs = Instance.new("UIStroke", f)
					fs.Color = Color3.fromRGB(200, 80, 80)
					fs.Thickness = 1
					fs.Transparency = 0.5
				end

				local ib = Instance.new("TextButton", f)
				ib.Size = UDim2.new(1, -40, 1, 0)
				ib.Position = UDim2.new(0, 8, 0, 0)
				ib.BackgroundTransparency = 1
				ib.Text = "  " .. mn
				ib.TextColor3 = Color3.fromRGB(255, 255, 255)
				ib.Font = Enum.Font.GothamBold
				ib.TextSize = 9
				ib.TextXAlignment = 0
				ib.ZIndex = 13

				local sb = Instance.new("TextButton", f)
				sb.Position = UDim2.new(1, -35, 0, 0)
				sb.Size = UDim2.new(0, 35, 1, 0)
				sb.BackgroundTransparency = 1
				sb.Text = favorites[mn] and "★" or "☆"
				sb.TextColor3 = favorites[mn] and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(80, 80, 85)
				sb.Font = Enum.Font.GothamBold
				sb.TextSize = 12
				sb.ZIndex = 13

				sb.MouseButton1Click:Connect(function()
					favorites[mn] = not favorites[mn]
					save_favs()
					populate_modes(filter)
				end)

				ib.MouseButton1Click:Connect(function()
					local shape = get_shape(mn)
					if shape then
						x1.k6 = mn
						x6.transition_time = time()
						x6.transition_dur = 1.5
						for _, d in pairs(x6.a) do
							d.trans_vl = d.vl or Vector3.zero
							d.v1, d.v2, d.v3, d.v4, d.v5, d.v6, d.v7, d.v8, d.v9 = nil, nil, nil, nil, nil, nil, nil, nil, nil
							d.integral = Vector3.zero
						end
						if db then
							db.Text = "  " .. mn:upper()
						end
						toggle_window(dlst_container, false)
						save_settings()
						if x5.up then
							x5.up()
						end
					end
				end)
			end
		end

		msb:GetPropertyChangedSignal("Text"):Connect(function()
			populate_modes(msb.Text)
		end)

		x6.populate_modes = populate_modes
		populate_modes("")

		local tdlst = Instance.new("CanvasGroup", sg)
		tdlst.Name = "TargetListContainer"
		tdlst.Visible = false
		tdlst.GroupTransparency = 1
		tdlst.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		tdlst.Position = UDim2.new(0.5, 90, 0.5, -160)
		tdlst.Size = UDim2.new(0, 180, 0, 250)
		tdlst.Active = true
		tdlst.Draggable = true
		x6.tdlst_container = tdlst
		Instance.new("UICorner", tdlst).CornerRadius = UDim.new(0, 10)
		local ts = Instance.new("UIStroke", tdlst)
		ts.Color = Color3.fromRGB(40, 40, 45)

		local top_tdlst = Instance.new("Frame", tdlst)
		top_tdlst.BackgroundTransparency = 1
		top_tdlst.Size = UDim2.new(1, 0, 0, 30)
		top_tdlst.ZIndex = 11

		local back_tdlst = Instance.new("TextButton", top_tdlst)
		back_tdlst.BackgroundTransparency = 1
		back_tdlst.Position = UDim2.new(0, 10, 0, 5)
		back_tdlst.Size = UDim2.new(0, 50, 0, 30)
		back_tdlst.Text = "◄ Back"
		back_tdlst.TextColor3 = Color3.fromRGB(150, 150, 155)
		back_tdlst.Font = Enum.Font.GothamBold
		back_tdlst.TextSize = 12
		back_tdlst.ZIndex = 12
		back_tdlst.MouseButton1Click:Connect(function()
			toggle_window(tdlst, false)
		end)

		local target_search = Instance.new("TextBox", tdlst)
		target_search.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		target_search.Position = UDim2.new(0, 10, 0, 35)
		target_search.Size = UDim2.new(1, -20, 0, 20)
		target_search.PlaceholderText = "Search players..."
		target_search.Text = ""
		target_search.TextColor3 = Color3.fromRGB(255, 255, 255)
		target_search.Font = Enum.Font.Gotham
		target_search.TextSize = 9
		target_search.ZIndex = 11
		Instance.new("UICorner", target_search).CornerRadius = UDim.new(0, 6)

		local t_scroll = Instance.new("ScrollingFrame", tdlst)
		t_scroll.BackgroundTransparency = 1
		t_scroll.Position = UDim2.new(0, 0, 0, 70)
		t_scroll.Size = UDim2.new(1, 0, 1, -80)
		t_scroll.ScrollBarThickness = 0
		t_scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		t_scroll.ZIndex = 11

		local active_highlight = nil
		local function clear_highlight()
			if active_highlight then
				active_highlight:Destroy()
				active_highlight = nil
			end
		end

		local function update_targets(filter_text)
			clear_highlight()
			t_scroll:ClearAllChildren()
			local tdll = Instance.new("UIListLayout", t_scroll)
			tdll.Padding = UDim.new(0, 5)
			tdll.HorizontalAlignment = Enum.HorizontalAlignment.Center

			for _, pl in ipairs(v2:GetPlayers()) do
				if pl == v8 then continue end
				if filter_text ~= "" and not (pl.DisplayName:lower():find(filter_text:lower()) or pl.Name:lower():find(filter_text:lower())) then
					continue
				end

				local ib = Instance.new("TextButton", t_scroll)
				ib.Size = UDim2.new(1, -16, 0, 36)
				ib.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
				ib.Text = ""
				ib.AutoButtonColor = false
				ib.ZIndex = 12
				Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 6)
				
				local is_selected = table.find(x1.Targets, pl) ~= nil
				local sel_indicator = Instance.new("Frame", ib)
				sel_indicator.Position = UDim2.new(1, -20, 0.5, -5)
				sel_indicator.Size = UDim2.new(0, 10, 0, 10)
				sel_indicator.BackgroundColor3 = is_selected and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(60, 60, 65)
				sel_indicator.ZIndex = 12
				Instance.new("UICorner", sel_indicator).CornerRadius = UDim.new(1, 0)

				local pfp = Instance.new("ImageLabel", ib)
				pfp.Size = UDim2.new(0, 26, 0, 26)
				pfp.Position = UDim2.new(0, 6, 0.5, -13)
				pfp.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
				pfp.Image = "rbxthumb://type=AvatarHeadShot&id=" .. pl.UserId .. "&w=48&h=48"
				pfp.ZIndex = 12
				Instance.new("UICorner", pfp).CornerRadius = UDim.new(1, 0)

				local dname = Instance.new("TextLabel", ib)
				dname.BackgroundTransparency = 1
				dname.Position = UDim2.new(0, 38, 0, 4)
				dname.Size = UDim2.new(1, -44, 0, 14)
				dname.Text = pl.DisplayName
				dname.TextColor3 = Color3.fromRGB(255, 255, 255)
				dname.Font = Enum.Font.GothamBold
				dname.TextSize = 10
				dname.TextXAlignment = 0
				dname.ZIndex = 12

				local uname = Instance.new("TextLabel", ib)
				uname.BackgroundTransparency = 1
				uname.Position = UDim2.new(0, 38, 0, 18)
				uname.Size = UDim2.new(1, -44, 0, 12)
				uname.Text = "@" .. pl.Name
				uname.TextColor3 = Color3.fromRGB(150, 150, 150)
				uname.Font = Enum.Font.GothamMedium
				uname.TextSize = 8
				uname.TextXAlignment = 0
				uname.ZIndex = 12

				ib.MouseEnter:Connect(function()
					ib.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
					if pl.Character then
						local h = Instance.new("Highlight", pl.Character)
						h.FillColor = Color3.fromRGB(255, 255, 255)
						h.OutlineColor = Color3.fromRGB(255, 255, 255)
						active_highlight = h
					end
				end)
				ib.MouseLeave:Connect(function()
					ib.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
					clear_highlight()
				end)

				ib.MouseButton1Click:Connect(function()
					local idx = table.find(x1.Targets, pl)
					if idx then
						table.remove(x1.Targets, idx)
						sel_indicator.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
					else
						table.insert(x1.Targets, pl)
						sel_indicator.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
					end
					x1.TgtActive = (#x1.Targets > 0)
					if x5.up then x5.up() end
				end)
			end
		end
		x6.update_targets = update_targets

		target_search:GetPropertyChangedSignal("Text"):Connect(function()
			update_targets(target_search.Text)
		end)

		local minb = Instance.new("TextButton", h)
		minb.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
		minb.Position = UDim2.new(1, -44, 0.5, -7)
		minb.Size = UDim2.new(0, 14, 0, 14)
		minb.Text = ""
		Instance.new("UICorner", minb).CornerRadius = UDim.new(1, 0)
		
		local tutb = Instance.new("TextButton", h)
		tutb.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
		tutb.Position = UDim2.new(1, -66, 0.5, -7)
		tutb.Size = UDim2.new(0, 14, 0, 14)
		tutb.Text = "?"
		tutb.TextColor3 = Color3.fromRGB(255, 255, 255)
		tutb.Font = Enum.Font.GothamBold
		tutb.TextSize = 10
		Instance.new("UICorner", tutb).CornerRadius = UDim.new(1, 0)

		local tut_container = Instance.new("CanvasGroup", sg)
		tut_container.Name = "Tutorial"
		tut_container.Visible = false
		tut_container.GroupTransparency = 1
		tut_container.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		tut_container.Position = UDim2.new(0.5, -100, 0.5, -120)
		tut_container.Size = UDim2.new(0, 200, 0, 240)
		tut_container.Active = true
		tut_container.Draggable = true
		Instance.new("UICorner", tut_container).CornerRadius = UDim.new(0, 10)
		local tuls = Instance.new("UIStroke", tut_container)
		tuls.Color = Color3.fromRGB(40, 40, 45)

		local tut_header = Instance.new("Frame", tut_container)
		tut_header.BackgroundTransparency = 1
		tut_header.Size = UDim2.new(1, 0, 0, 30)
		
		local tut_title = Instance.new("TextLabel", tut_header)
		tut_title.BackgroundTransparency = 1
		tut_title.Position = UDim2.new(0, 15, 0, 0)
		tut_title.Size = UDim2.new(0.8, 0, 1, 0)
		tut_title.Text = "HOW TO USE"
		tut_title.TextColor3 = Color3.fromRGB(255, 255, 255)
		tut_title.Font = Enum.Font.GothamBlack
		tut_title.TextSize = 10
		tut_title.TextXAlignment = 0

		local tut_close = Instance.new("TextButton", tut_header)
		tut_close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		tut_close.Position = UDim2.new(1, -22, 0.5, -7)
		tut_close.Size = UDim2.new(0, 14, 0, 14)
		tut_close.Text = ""
		Instance.new("UICorner", tut_close).CornerRadius = UDim.new(1, 0)
		tut_close.MouseButton1Click:Connect(function()
			toggle_window(tut_container, false)
		end)

		local tut_text = Instance.new("TextLabel", tut_container)
		tut_text.BackgroundTransparency = 1
		tut_text.Position = UDim2.new(0, 15, 0, 35)
		tut_text.Size = UDim2.new(1, -30, 1, -45)
		tut_text.Text = "• Core Controls: Tap 'PLC' to spawn the gravitational center. Tap 'CLN' to wipe active parts.\n\n• Targeting: Use 'Select Target' to focus gravity onto a specific player.\n\n• Elevation: Use 'UP' and 'DWN' buttons to manually adjust the vertical height of the formation.\n\n• System: Tap 'PAU' to instantly pause physics. Tap 'DIS' to disable the system.\n\n• Modes: Select modes to seamlessly morph between geometry.\n\n• Config: Scroll down the main menu to tune the shape config. Open 'Advanced Settings' for global physics."
		tut_text.TextColor3 = Color3.fromRGB(200, 200, 205)
		tut_text.Font = Enum.Font.GothamMedium
		tut_text.TextSize = 9
		tut_text.TextXAlignment = 0
		tut_text.TextYAlignment = 0
		tut_text.TextWrapped = true

		tutb.MouseButton1Click:Connect(function()
			toggle_window(tut_container, not tut_container.Visible)
		end)

		local closeb = Instance.new("TextButton", h)
		closeb.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		closeb.Position = UDim2.new(1, -22, 0.5, -7)
		closeb.Size = UDim2.new(0, 14, 0, 14)
		closeb.Text = ""
		Instance.new("UICorner", closeb).CornerRadius = UDim.new(1, 0)

		local im = false
		minb.MouseButton1Click:Connect(function()
			im = not im
			c.Visible = not im
			if im then
				am.Visible = false
				if x6.dlst_container and x6.dlst_container.Visible then
					toggle_window(x6.dlst_container, false)
				end
				if x6.tdlst_container and x6.tdlst_container.Visible then
					toggle_window(x6.tdlst_container, false)
				end
			end
			m:TweenSize(im and UDim2.new(0, 180, 0, 26) or UDim2.new(0, 180, 0, 250), "Out", "Quart", 0.3, true)
		end)

		closeb.MouseButton1Click:Connect(function()
			if context.x4 and context.x4.f5 then
				context.x4.f5()
			else
				sg:Destroy()
			end
		end)

		local ctrl_container = Instance.new("Frame", sg)
		ctrl_container.BackgroundTransparency = 1
		ctrl_container.Position = UDim2.new(0, 15, 0.05, 0)
		ctrl_container.Size = UDim2.new(0, 60, 0, 200)

		local hide_btn = Instance.new("TextButton", ctrl_container)
		hide_btn.Size = UDim2.new(0, 14, 0, 14)
		hide_btn.Position = UDim2.new(0, 0, 0, 6)
		hide_btn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
		hide_btn.Text = ""
		Instance.new("UICorner", hide_btn).CornerRadius = UDim.new(1, 0)

		local ctrl = Instance.new("Frame", ctrl_container)
		ctrl.BackgroundTransparency = 1
		ctrl.Position = UDim2.new(0, 22, 0, 0)
		ctrl.Size = UDim2.new(1, -22, 1, 0)

		local layout = Instance.new("UIListLayout", ctrl)
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder

		local function create_btn(txt, col, order)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, 22, 0, 22)
			b.BackgroundColor3 = col
			b.Text = txt
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 6
			b.LayoutOrder = order
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
			b.Parent = ctrl
			return b
		end

		local btn_place = create_btn("PLC", Color3.fromRGB(50, 150, 200), 2)
		local btn_clean = create_btn("CLN", Color3.fromRGB(200, 80, 80), 3)
		local btn_up = create_btn("UP", Color3.fromRGB(80, 80, 85), 4)
		local btn_down = create_btn("DWN", Color3.fromRGB(80, 80, 85), 5)
		local btn_pause = create_btn("PAU", Color3.fromRGB(200, 150, 50), 6)
		local btn_dis = create_btn("DIS", Color3.fromRGB(60, 60, 60), 7)

		local controls_visible = true
		hide_btn.MouseButton1Click:Connect(function()
			controls_visible = not controls_visible
			hide_btn.BackgroundColor3 = controls_visible and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(200, 60, 60)
			btn_place.Visible = controls_visible
			btn_clean.Visible = controls_visible
			btn_up.Visible = controls_visible
			btn_down.Visible = controls_visible
			btn_pause.Visible = controls_visible
			btn_dis.Visible = controls_visible
		end)

		btn_place.MouseButton1Click:Connect(function()
			if context.x4 and context.x4.f4 then
				local cam = v4.CurrentCamera
				if cam then
					local vp = cam.ViewportSize
					local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Exclude
					rp.FilterDescendantsInstances = {v8.Character}
					local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, rp)
					local pos = res and res.Position or (ray.Origin + ray.Direction * 20)
					context.x4.f4(pos)
				end
			end
		end)

		btn_clean.MouseButton1Click:Connect(function()
			if context.x4 and context.x4.clean_physics then
				context.x4.clean_physics()
			end
		end)

		local holding_up = false
		btn_up.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				holding_up = true
				task.spawn(function()
					while holding_up and x6.b do
						x6.b.Position = x6.b.Position + Vector3.new(0, 1, 0)
						task.wait()
					end
				end)
			end
		end)
		btn_up.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				holding_up = false
			end
		end)

		local holding_down = false
		btn_down.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				holding_down = true
				task.spawn(function()
					while holding_down and x6.b do
						x6.b.Position = x6.b.Position - Vector3.new(0, 1, 0)
						task.wait()
					end
				end)
			end
		end)
		btn_down.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				holding_down = false
			end
		end)

		btn_pause.MouseButton1Click:Connect(function()
			x1.Paused = not x1.Paused
			btn_pause.BackgroundColor3 = x1.Paused and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(200, 150, 50)
		end)

		btn_dis.MouseButton1Click:Connect(function()
			x1.Disabled = not x1.Disabled
			btn_dis.BackgroundColor3 = x1.Disabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(60, 60, 60)
			if x6.disable_btn then x6.disable_btn.BackgroundColor3 = btn_dis.BackgroundColor3 end
			
			local v = x1.Disabled
			if x6.b then
				x6.b.Transparency = v and 1 or x9.c7
				if x6.b:FindFirstChild("Visual") then
					x6.b.Visual.Enabled = not v
				end
			end
			for _, d in pairs(x6.a) do
				if d.lv then d.lv.MaxForce = v and 0 or x1.k4 end
				if d.av then d.av.MaxTorque = v and 0 or math.huge end
			end
		end)

		f1()
	end

	return x5
end
