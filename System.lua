return function(context)
	local v1, v2, v3, v4, v5, v6, v7, v8, v9 = context.v1, context.v2, context.v3, context.v4, context.v5, context.v6, context.v7, context.v8, context.v9
	local x1, x2, x6, x9 = context.x1, context.x2, context.x6, context.x9
	local x5 = context.x5
	local get_shape = context.get_shape
	local load_module = context.load_module

	local x4, x8 = {}, {}
	local x7 = {}

	function x7.n(t, x, d)
		pcall(function()
			v5:SetCore("SendNotification", { Title = t, Text = x, Duration = d or 3 })
		end)
	end

	local EXCLUDED_NAMES = {
		Baseplate = true,
		HumanoidRootPart = true,
		Terrain = true,
		Handle = true,
		Head = true,
		Torso = true,
		["Left Arm"] = true,
		["Right Arm"] = true,
		["Left Leg"] = true,
		["Right Leg"] = true,
		UpperTorso = true,
		LowerTorso = true,
		LeftUpperArm = true,
		LeftLowerArm = true,
		LeftHand = true,
		RightUpperArm = true,
		RightLowerArm = true,
		RightHand = true,
		LeftUpperLeg = true,
		LeftLowerLeg = true,
		LeftFoot = true,
		RightUpperLeg = true,
		RightLowerLeg = true,
		RightFoot = true,
	}

	function x7.e(p)
		if not p:IsA("BasePart") then
			return true
		end
		if p.Anchored then
			return true
		end
		if EXCLUDED_NAMES[p.Name] then
			return true
		end
		for _, t in ipairs(x1.k5) do
			if p:FindFirstChild(t) or (p.Parent and p.Parent:FindFirstChild(t)) then
				return true
			end
		end
		local target = p.Parent
		while target and target ~= v4 and target ~= game do
			if target:IsA("Accessory") or target:IsA("Tool") then
				return true
			end
			if target:IsA("Model") and (target:FindFirstChildOfClass("Humanoid") or target:FindFirstChildOfClass("AnimationController")) then
				return true
			end
			target = target.Parent
		end
		return false
	end

	local function x3()
		return x1.S[x1.k6] or {}
	end

	local function px(md, t, c)
		local shape = get_shape(md)
		if shape and shape.px then
			shape.px(t, c, x6, x9)
		end
	end

	local function get_predicted_pos(root, factor)
		local pos = root.Position
		local vel = root.AssemblyLinearVelocity
		if vel.Magnitude > 250 then
			vel = vel.Unit * 250
		end
		local y_vel = math.clamp(vel.Y, -50, 15)
		vel = Vector3.new(vel.X, y_vel, vel.Z)
		return pos + (vel * (factor / 1000))
	end

	local no_damp = { ["Slingshot"] = true, ["Point Impact"] = true, ["Deflect"] = true }

	local function f3(real_dt)
		real_dt = real_dt or (1/60)
		if not x6.b or x1.Disabled then
			return
		end
		if x1.Paused then
			for _, d in pairs(x6.a) do
				if d.lv then
					d.lv.VectorVelocity = Vector3.new(0, 0.01, 0)
				end
			end
			return
		end
		pcall(function()
			local c = x6.b.Position
			x6.f = x6.f + 1
			local dt = x6.n > 5000 and 10 or (x6.n > 2500 and 6 or (x6.n > 1000 and 3 or 1))
			local et, ft = x1.k7 or dt, time()
			if x1["SM(ps.lag)"] then
				dt = 1
				et = 1
			end
			local i = 0
			if ft > x6.pi_timer then
				x6.pi_timer = ft + 1
				x6.pi_targets = {}
				if x1.PI_All then
					for _, pl in ipairs(v2:GetPlayers()) do
						if pl ~= v8 and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
							table.insert(x6.pi_targets, pl)
						end
					end
				else
					if x1.Targets and #x1.Targets > 0 then
						for _, tgt in ipairs(x1.Targets) do
							if tgt and tgt.Parent and tgt.Character and tgt.Character:FindFirstChild("HumanoidRootPart") then
								table.insert(x6.pi_targets, tgt)
							end
						end
					end
				end

				for _, pl in ipairs(v2:GetPlayers()) do
					if pl.Character and pl.Character:FindFirstChild("Head") then
						local head = pl.Character.Head
						local is_tgt = table.find(x6.pi_targets, pl) ~= nil
						local marker = head:FindFirstChild("GravityTargetMarker")
						
						if is_tgt and not marker then
							local bg = Instance.new("BillboardGui")
							bg.Name = "GravityTargetMarker"
							bg.Size = UDim2.new(1.5, 0, 1.5, 0)
							bg.StudsOffset = Vector3.new(0, 2.5, 0)
							bg.AlwaysOnTop = true
							
							local txt = Instance.new("TextLabel", bg)
							txt.BackgroundTransparency = 1
							txt.Size = UDim2.new(1, 0, 1, 0)
							txt.Text = "▼"
							txt.TextColor3 = Color3.fromRGB(255, 60, 60)
							txt.TextScaled = true
							txt.Font = Enum.Font.GothamBlack
							
							local str = Instance.new("UIStroke", txt)
							str.Color = Color3.fromRGB(0, 0, 0)
							str.Thickness = 2
							bg.Parent = head
						elseif not is_tgt and marker then
							marker:Destroy()
						end
					end
				end
			end
			px(x1.k6, ft, x3())
			local cur_no_damp = no_damp[x1.k6]
			
			local target_positions = {}
			local valid_targets = 0
			if #x6.pi_targets > 0 then
				for _, tgt in ipairs(x6.pi_targets) do
					if tgt and tgt.Character and tgt.Character:FindFirstChild("HumanoidRootPart") then
						local root = tgt.Character.HumanoidRootPart
						local pos = root.Position
						if x1.PredictiveTracking then
							pos = get_predicted_pos(root, x1.PredictionFactor or 150)
						end
						table.insert(target_positions, pos)
						valid_targets = valid_targets + 1
					end
				end
			end
			local cur_shape_mod = get_shape(x1.k6)
			local cur_shape_cfg = x1.S[x1.k6] or {}

			local k1 = x1.k1
			local c7 = x9.c7
			local ki = x1.Ki or 0
			local damping = x1.Damping or 0
			local max_speed = x1.MaxSpeed
			local vert_stiff = x1.VerticalStiffness or 1
			local vert_mult = vert_stiff ~= 1 and Vector3.new(1, vert_stiff, 1) or nil
			local dt_mult = real_dt * 60 * dt

			local smoothing = (x1.k6 == "Point Impact" and 1) or x1.k8
			if x1.DramaMode and x1.k6 == "Point Impact" then
				smoothing = 1
			end
			local sm_alpha = smoothing >= 1 and 1 or (1 - math.exp(-dt_mult * -math.log(math.max(0.001, 1 - smoothing))))

			local ang_damp_mult = 1
			if x1.AngularDamping and x1.AngularDamping > 0 then
				local damp_rate = -60 * math.log(math.max(0.001, 1 - math.clamp(x1.AngularDamping, 0, 0.99)))
				ang_damp_mult = math.exp(-damp_rate * real_dt * dt)
			end

			local trans_ease = 1
			local in_transition = false
			if x6.transition_time and x6.transition_time > 0 then
				in_transition = true
				local alpha = math.clamp((ft - x6.transition_time) / x6.transition_dur, 0, 1)
				if alpha < 1 then
					trans_ease = alpha * alpha * (3 - 2 * alpha)
				else
					x6.transition_time = 0
					in_transition = false
				end
			end

			for k = #x6.active_array, 1, -1 do
				local p = x6.active_array[k]
				local d = x6.a[p]

				if not d or not p.Parent then
					if d then
						if d.at and d.at.Parent then d.at:Destroy() end
						if d.lv and d.lv.Parent then d.lv:Destroy() end
						if d.av and d.av.Parent then d.av:Destroy() end
						x6.a[p] = nil
					end
					local last = #x6.active_array
					if k ~= last then
						x6.active_array[k] = x6.active_array[last]
					end
					x6.active_array[last] = nil
					x6.n = math.max(0, x6.n - 1)
					continue
				end
				i = i + 1
				if i % et ~= (x6.f % et) then
					continue
				end
				local p_vel = p.AssemblyLinearVelocity
				local active_c = c
				if valid_targets > 0 then
					active_c = target_positions[((i - 1) % valid_targets) + 1]
				end
				local tc = active_c - p.Position
				local tc_mag = tc.Magnitude
				if tc_mag > k1 then
					continue
				end
				if tc_mag > c7 then
					local target_pos_delta = Vector3.new(0, 0.01, 0)
					if cur_shape_mod then
						target_pos_delta = cur_shape_mod.f2(p, active_c, d, ft, cur_shape_cfg, x1, x6, x9)
					end
					if vert_mult then
						target_pos_delta = target_pos_delta * vert_mult
					end
					if ki > 0 and d.integral then
						d.integral = d.integral + (target_pos_delta * dt_mult)
						if d.integral.Magnitude > 100 then
							d.integral = d.integral.Unit * 100
						end
						target_pos_delta = target_pos_delta + (d.integral * ki)
					end
					local tv = target_pos_delta
					if damping > 0 and not cur_no_damp then
						tv = tv - (p_vel * damping)
					end



					d.vl = d.vl and d.vl:Lerp(tv, sm_alpha) or tv
					if in_transition and d.trans_vl then
						if trans_ease < 1 then
							d.vl = d.trans_vl:Lerp(d.vl, trans_ease)
						else
							d.trans_vl = nil
						end
					end
					
					if max_speed and not cur_no_damp then
						if d.vl.Magnitude > max_speed then
							d.vl = d.vl.Unit * max_speed
						end
					else
						if d.vl.Magnitude > 3000 then
							d.vl = d.vl.Unit * 3000
						end
					end
					d.lv.VectorVelocity = d.vl
					
					if ang_damp_mult ~= 1 then
						p.AssemblyAngularVelocity = p.AssemblyAngularVelocity * ang_damp_mult
					end
				end
			end
		end)
	end

	function x4.ProcessQueue()
		local queue = x6.claim_queue
		local qi = x6.queue_idx or 1
		local qn = #queue
		if qi > qn then
			if qn > 0 then
				table.clear(queue)
				x6.queue_idx = 1
			end
			return
		end
		local start = os.clock()
		local loops = 0
		while qi <= qn do
			loops = loops + 1
			if loops % 20 == 0 and os.clock() - start > 0.0015 then
				break
			end
			local p = queue[qi]
			qi = qi + 1
			if p and p:IsA("BasePart") and p:IsDescendantOf(v4) then
				x4.f1(p)
			end
		end
		x6.queue_idx = qi
		if qi > qn then
			table.clear(queue)
			x6.queue_idx = 1
		end
	end

	local function f4(real_dt)
		real_dt = real_dt or (1/60)
		if not x6.b or x1.Disabled then
			return
		end
		if x1.TgtActive and x1.Targets and #x1.Targets > 0 then
			local tgt = x1.Targets[1]
			if tgt and tgt.Character and tgt.Character:FindFirstChild("HumanoidRootPart") then
				local root = tgt.Character.HumanoidRootPart
				local pos = root.Position
				if x1.PredictiveTracking then
					pos = get_predicted_pos(root, x1.PredictionFactor or 150)
				end
				x6.b.Position = pos
				x6.b.AssemblyLinearVelocity = Vector3.zero
				return
			end
		elseif x1.AnchorSelf and v8.Character and v8.Character:FindFirstChild("HumanoidRootPart") then
			local root = v8.Character.HumanoidRootPart
			local pos = root.Position
			if x1.PredictiveTracking then
				pos = get_predicted_pos(root, x1.PredictionFactor or 150)
			end
			x6.b.Position = pos
			x6.b.AssemblyLinearVelocity = Vector3.zero
			return
		elseif x6.d then
			local c = v4.CurrentCamera
			if not c then
				return
			end
			x6.p = x6.p or (x6.b.Position - c.CFrame.Position).Magnitude
			local mp = v1:GetMouseLocation()
			local r = c:ViewportPointToRay(mp.X, mp.Y)
			local tp = r.Origin + (r.Direction * x6.p)
			local alpha = x9.c8 >= 1 and 1 or (1 - math.exp(-60 * real_dt * -math.log(math.max(0.001, 1 - x9.c8))))
			x6.b.Position = x6.b.Position:Lerp(tp, alpha)
			x6.b.AssemblyLinearVelocity = Vector3.zero
		end
	end

	function x4.f1(p)
		if not p:IsA("BasePart") or x7.e(p) or x6.a[p] then
			return
		end
		for _, c in ipairs(p:GetChildren()) do
			if c:IsA("BodyMover") or c:IsA("Constraint") or c:IsA("Attachment") then
				c:Destroy()
			end
		end
		p.CanCollide = false
		p.Anchored = false
		p.CustomPhysicalProperties = PhysicalProperties.new(0.001, 0, 0, 0, 0)
		
		local a = Instance.new("Attachment")
		a.Name = "GRV_ATT"
		
		local lv = Instance.new("LinearVelocity")
		lv.Name = "GRV_LV"
		lv.MaxForce = x1.k4
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Attachment0 = a
		
		local av = Instance.new("AngularVelocity")
		av.Name = "GRV_AV"
		av.MaxTorque = math.huge
		av.RelativeTo = Enum.ActuatorRelativeTo.World
		av.AngularVelocity = Vector3.zero
		av.Attachment0 = a
		
		a.Parent = p
		lv.Parent = p
		av.Parent = p
		
		x6.a[p] = { at = a, lv = lv, av = av, integral = Vector3.zero }
		table.insert(x6.active_array, p)
		x6.n = x6.n + 1
	end

	function x4.f2(p)
		local d = x6.a[p]
		if d then
			if d.at and d.at.Parent then
				d.at:Destroy()
			end
			if d.lv and d.lv.Parent then
				d.lv:Destroy()
			end
			if d.av and d.av.Parent then
				d.av:Destroy()
			end
			x6.a[p] = nil
		end
		local idx = table.find(x6.active_array, p)
		if idx then
			local last = #x6.active_array
			if idx ~= last then
				x6.active_array[idx] = x6.active_array[last]
			end
			table.remove(x6.active_array, last)
			x6.n = math.max(0, x6.n - 1)
		end
	end

	function x4.f3()
		pcall(function()
			settings().Physics.AllowSleep = false
		end)
		local last_upd = 0
		table.insert(
			x6.c,
			v3.Heartbeat:Connect(function(dt)
				if time() - last_upd > 0.5 then
					last_upd = time()
					for _, p in ipairs(v2:GetPlayers()) do
						if p ~= v8 then
							pcall(function()
								p.MaximumSimulationRadius = 0
								if sethiddenproperty then
									sethiddenproperty(p, "SimulationRadius", 0)
								end
							end)
						end
					end
					pcall(function()
						if sethiddenproperty then
							sethiddenproperty(v8, "NetworkIsSleeping", false)
						end
					end)
					pcall(function()
						if setscriptable then
							setscriptable(v8, "SimulationRadius", true)
							setscriptable(v8, "MaximumSimulationRadius", true)
						end
					end)

					pcall(function()
						v8.MaximumSimulationRadius = 9e9
					end)

					pcall(function()
						if sethiddenproperty then
							sethiddenproperty(v8, "SimulationRadius", 9e9)
						elseif setsimulationradius then
							setsimulationradius(9e9)
						end
					end)

					pcall(function()
						if x6.b then
							v8.ReplicationFocus = x6.b
						else
							v8.ReplicationFocus = nil
						end
					end)
				end
			end)
		)
		table.insert(
			x6.c,
			v3.Stepped:Connect(function()
				if x1.AntiFling then
					for _, p in ipairs(v2:GetPlayers()) do
						if p ~= v8 and p.Character then
							for _, part in ipairs(p.Character:GetChildren()) do
								if part:IsA("BasePart") and part.CanCollide then
									part.CanCollide = false
								end
							end
						end
					end
				end
			end)
		)
	end

	function x4.f4(pos)
		if x6.b then
			v6:Create(x6.b, TweenInfo.new(x9.c7), { Position = pos }):Play()
			return
		end
		local f = Instance.new("Folder", v4)
		f.Name = "AS"
		x6.b = Instance.new("Part", f)
		x6.b.Size = x1.k2
		x6.b.Shape = "Ball"
		x6.b.Color = x1.k3
		x6.b.Anchored = true
		x6.b.CanCollide = false
		x6.b.Material = "Neon"
		x6.b.Position = pos
		x6.b.Transparency = x9.c7
		local bg = Instance.new("BillboardGui", x6.b)
		bg.Name = "Visual"
		bg.Adornee = x6.b
		bg.Size = UDim2.new(0, 20, 0, 20)
		bg.AlwaysOnTop = true
		local img = Instance.new("ImageLabel", bg)
		img.BackgroundTransparency = 1
		img.Size = UDim2.new(1, 0, 1, 0)
		img.Image = "rbxassetid://3570695787"
		img.ImageColor3 = x1.k3
		v6
			:Create(
				x6.b,
				TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Size = x1.k2 * 1.2 }
			)
			:Play()
		local descendants = v4:GetDescendants()
		for i, v in ipairs(descendants) do
			if v:IsA("BasePart") then
				table.insert(x6.claim_queue, v)
			end
			if i % 5000 == 0 then
				task.wait()
			end
		end

		table.insert(
			x6.c,
			v4.DescendantAdded:Connect(function(v)
				if v:IsA("BasePart") then
					table.insert(x6.claim_queue, v)
				end
			end)
		)
		x6.o = true
		x7.n("Sys", "Started", 3)
		x5.st()
		table.insert(
			x6.c,
			v3.Heartbeat:Connect(function(real_dt)
				f3(real_dt)
				f4(real_dt)
				x4.ProcessQueue()
			end)
		)
	end

	function x4.f5()
		if x6.b then
			x6.b.Parent:Destroy()
			x6.b = nil
		end
		if x6.sg then
			x6.sg:Destroy()
			x6.sg = nil
		end
		for p, _ in pairs(x6.a) do
			x4.f2(p)
		end
		for _, c in ipairs(x6.c) do
			c:Disconnect()
		end
		x6.c = {}
		if x6.f1_connections then
			for _, c in ipairs(x6.f1_connections) do
				if c then c:Disconnect() end
			end
			table.clear(x6.f1_connections)
		end
		x6.a = {}
		x6.o = false
		v7:UnbindAction("C")
		v7:UnbindAction("R")
		if x5.g then
			x5.g:Destroy()
		end
		x7.n("Sys", "Stopped", 2)
	end

	function x8.h(n, s, o)
		if s ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if n == "C" then
			x4.f4(v9.Hit.p)
			return Enum.ContextActionResult.Sink
		elseif n == "R" then
			x4.f5()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end

	function x8.i()
		v7:BindAction("C", x8.h, false, Enum.KeyCode.E)
		v7:BindAction("R", x8.h, false, Enum.KeyCode.Q)
		v7:BindAction("P", function(_, s)
			if s == Enum.UserInputState.Begin then
				x1.Paused = not x1.Paused
				x7.n("Sys", x1.Paused and "Paused" or "Resumed", 2)
			end
		end, false, Enum.KeyCode.P)
		v7:BindAction("Disable", function(_, s)
			if s == Enum.UserInputState.Begin then
				x1.Disabled = not x1.Disabled
				local state = x1.Disabled and "Disabled" or "Enabled"
				x7.n("Sys", "Script " .. state, 2)
				if x6.disable_btn then
					x6.disable_btn.BackgroundColor3 = x1.Disabled and Color3.fromRGB(100, 255, 100)
						or Color3.fromRGB(60, 60, 60)
					local v = x1.Disabled
					if x6.b then
						x6.b.Transparency = v and 1 or x9.c7
						if x6.b:FindFirstChild("Visual") then
							x6.b.Visual.Enabled = not v
						end
					end
					for _, d in pairs(x6.a) do
						if d.lv then
							d.lv.MaxForce = v and 0 or x1.k4
						end
						if d.av then
							d.av.MaxTorque = v and 0 or math.huge
						end
					end
				end
			end
		end, false, Enum.KeyCode.L)
		table.insert(
			x6.c,
			v1.InputBegan:Connect(function(i, p)
				if p or not x6.b then
					return
				end
				if i.UserInputType == Enum.UserInputType.MouseButton1 and v9.Target == x6.b then
					x6.d = true
					x6.p = (v4.CurrentCamera and (x6.b.Position - v4.CurrentCamera.CFrame.Position).Magnitude) or 50
				end
			end)
		)
		table.insert(
			x6.c,
			v1.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					x6.d = false
				end
			end)
		)

		local sculptor_binder = load_module("System_sculptor.lua")(context, x7)
		sculptor_binder()

		x7.n("Rdy", "System Initialized", 5)
		
		task.spawn(function()
			local spawnPos = Vector3.new(0, 50, 0)
			pcall(function()
				if v8.Character and v8.Character:FindFirstChild("HumanoidRootPart") then
					spawnPos = v8.Character.HumanoidRootPart.Position + (v8.Character.HumanoidRootPart.CFrame.LookVector * 15) + Vector3.new(0, 10, 0)
				end
			end)
			x4.f4(spawnPos)
		end)
	end

	return { x4 = x4, x8 = x8 }
end
