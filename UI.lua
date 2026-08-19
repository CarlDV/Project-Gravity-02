return function(context)
	local v1, v2, v3, v4, v5, v6, v7, v8, v9 = context.v1, context.v2, context.v3, context.v4, context.v5, context.v6, context.v7, context.v8, context.v9
	local x1, x2, x6, x9 = context.x1, context.x2, context.x6, context.x9
	local favorites, save_favs, save_settings = context.favorites, context.save_favs, context.save_settings
	local get_shape = context.get_shape
	local load_module = context.load_module
	local reset_config = context.reset_config
	-- Shared motion vocabulary from main.lua; see the ANIM table there for why
	-- each curve is what it is. Fallback keeps this module loadable standalone.
	local A = context.ANIM or {
		HOVER = TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		TINT = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		OPEN = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		OPEN_POP = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		CLOSE = TweenInfo.new(0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		CLOSE_POP = TweenInfo.new(0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		ROLL = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		FOLD = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		UNFOLD = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		RESCALE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	}

	local Lighting = game:GetService("Lighting")
	
	-- Weak keys, the same reason scaled_windows below uses them. These tables are
	-- keyed by every BasePart, PostEffect and emitter in the map, so with strong keys
	-- every one destroyed after the snapshot was pinned until the toggle went off --
	-- in a map with any part churn that is an unbounded leak. The restore functions
	-- already expect entries to go dead (they test part.Parent), so dropping them
	-- early changes nothing they do.
	local PerfOriginals = {
		Shadows = nil,
		FX = setmetatable({}, { __mode = "k" }),
		Materials = setmetatable({}, { __mode = "k" }),
		Particles = setmetatable({}, { __mode = "k" })
	}
	
	local function RestorePerfShadows()
		if PerfOriginals.Shadows ~= nil then
			Lighting.GlobalShadows = PerfOriginals.Shadows
			PerfOriginals.Shadows = nil
		end
	end
	
	local function ApplyPerfShadows(disable)
		if disable then
			if PerfOriginals.Shadows == nil then
				PerfOriginals.Shadows = Lighting.GlobalShadows
			end
			Lighting.GlobalShadows = false
		else
			RestorePerfShadows()
		end
	end
	
	local function RestorePerfPostFX()
		for fx, was_enabled in pairs(PerfOriginals.FX) do
			if fx.Parent then fx.Enabled = was_enabled end
		end
		table.clear(PerfOriginals.FX)
	end
	
	local function ApplyPerfPostFX(disable)
		if disable then
			for _, effect in pairs(Lighting:GetDescendants()) do
				if effect:IsA("PostEffect") then
					if PerfOriginals.FX[effect] == nil then
						PerfOriginals.FX[effect] = effect.Enabled
					end
					effect.Enabled = false
				end
			end
			local camera = workspace.CurrentCamera
			if camera then
				for _, effect in pairs(camera:GetDescendants()) do
					if effect:IsA("PostEffect") then
						if PerfOriginals.FX[effect] == nil then
							PerfOriginals.FX[effect] = effect.Enabled
						end
						effect.Enabled = false
					end
				end
			end
		else
			RestorePerfPostFX()
		end
	end
	
	local function RestorePerfMaterials()
		for part, mat in pairs(PerfOriginals.Materials) do
			if part.Parent then part.Material = mat end
		end
		table.clear(PerfOriginals.Materials)
	end
	
	local function ApplyPerfMaterials(disable)
		if disable then
			for _, part in pairs(workspace:GetDescendants()) do
				if part:IsA("BasePart") then
					if not PerfOriginals.Materials[part] then
						PerfOriginals.Materials[part] = part.Material
					end
					part.Material = Enum.Material.SmoothPlastic
				end
			end
		else
			RestorePerfMaterials()
		end
	end
	
	local function RestorePerfParticles()
		for p, enabled in pairs(PerfOriginals.Particles) do
			if p.Parent then p.Enabled = enabled end
		end
		table.clear(PerfOriginals.Particles)
	end
	
	local function ApplyPerfParticles(disable)
		if disable then
			for _, obj in pairs(workspace:GetDescendants()) do
				if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
					if PerfOriginals.Particles[obj] == nil then
						PerfOriginals.Particles[obj] = obj.Enabled
					end
					obj.Enabled = false
				end
			end
		else
			RestorePerfParticles()
		end
	end

	local function RestoreAllPerf()
		RestorePerfShadows()
		RestorePerfPostFX()
		RestorePerfMaterials()
		RestorePerfParticles()
	end
	-- UI_elements is a hard dependency, so fail with a message that says which
	-- module rather than "attempt to call a nil value" out of load_module's
	-- failure path, the way main.lua:553 does for UI and System.
	local UI_elements_builder = load_module("UI_elements.lua")
	if not UI_elements_builder then
		error("Failed to load UI_elements", 0)
	end
	local UI_elements = UI_elements_builder(context)
	-- The AI chat is optional: both call sites below already nil-guard it. Calling
	-- load_module's result directly meant a nil threw here first, so one flaky
	-- fetch for the chat took the whole panel down and those guards could never
	-- fire.
	local ai_chat_builder = load_module("ai_chat.lua")
	local ai_chat_module = ai_chat_builder and ai_chat_builder(context)
	local es, et, eb, eh = UI_elements.s, UI_elements.t, UI_elements.b, UI_elements.h
	local etb = UI_elements.tb
	local ekb = UI_elements.kb

	local x5 = {}
	x5.g = nil
	x5.s = es
	x5.t = et
	x5.b = eb
	x5.h = eh

	function x5.st()
		if x5.g and x5.g.Parent and x5.up then
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
		-- Panel geometry. The minimize animation tweens between these, so they
		-- cannot stay as literals duplicated between the constructor and the
		-- handler -- that split is what let the two drift apart before.
		-- CONTENT_GAP is the gap under the header: the content frame's old
		-- 60/-70 pair was really HEADER_H + gap, written out by hand.
		local PANEL_W = 320
		local PANEL_H = 500
		local HEADER_H = 50
		local PILL_SIZE = 44
		local CONTENT_GAP = 10

		-- Roblox honours one UIScale per GuiObject, so the open/close pop and the
		-- user's UI Scale setting have to share it. Every scalable window is
		-- registered here and its scale is always (pop factor * app scale):
		-- toggle_window used to tween the single UIScale straight to 1, which is
		-- what silently threw away the Advanced window's saved scale the first
		-- time it was opened.
		-- Weak keys, because registration outlives the window. The reset-confirm
		-- dialog is registered on open and Destroy()ed on dismiss, and
		-- TargetListContainer is torn down and rebuilt on every refresh -- each
		-- one used to leave a strong reference to a dead Instance behind here.
		-- Nothing swept them: the only prune is the win.Parent check inside
		-- apply_ui_scale, which runs only when the scale setting changes, so the
		-- table grew for the whole session and pinned every corpse it held. A
		-- window that is still parented is kept alive by its parent, so weak keys
		-- drop exactly the dead ones and nothing else.
		local scaled_windows = setmetatable({}, { __mode = "k" })

		local function app_scale()
			local v = tonumber(x1.UIScale) or 1
			if v ~= v or v <= 0 then
				return 1
			end
			return v
		end

		-- pop is where the window sits in its own open/close animation: 1 when
		-- open, 0.8 while hidden. Kept per window so a rescale mid-animation
		-- cannot snap a closed window to full size. Nested windows (the mode
		-- selector and target list live under Main) must not carry the app scale
		-- on their own UIScale as well: their parent's UIScale already applies
		-- it, and applying it twice compounds to scale-squared.
		local function register_window(win, pop, nested)
			local scale = win:FindFirstChild("UIScale")
			if not scale then
				scale = Instance.new("UIScale", win)
			end
			pop = pop or 1
			scale.Scale = pop * ((nested and 1) or app_scale())
			scaled_windows[win] = { scale = scale, pop = pop, nested = nested or false }
			return scale
		end

		local function set_pop(win, pop, tween_info, nested)
			local entry = scaled_windows[win]
			if not entry then
				register_window(win, pop, nested)
				entry = scaled_windows[win]
			end
			entry.pop = pop
			local target = pop * ((entry.nested and 1) or app_scale())
			if tween_info then
				v6:Create(entry.scale, tween_info, { Scale = target }):Play()
			else
				entry.scale.Scale = target
			end
		end

		-- One place the setting is applied, so a popup can never be left at the
		-- old scale. Tweened rather than snapped, and every window moves together.
		local function apply_ui_scale()
			local s = app_scale()
			for win, entry in pairs(scaled_windows) do
				if win.Parent then
					if not entry.nested then
						v6:Create(entry.scale, A.RESCALE, { Scale = entry.pop * s }):Play()
					end
				else
					scaled_windows[win] = nil
				end
			end
		end
		x5.apply_ui_scale = apply_ui_scale

		local function toggle_window(win, state, nested)
			if not scaled_windows[win] then
				register_window(win, win.Visible and 1 or 0.8, nested)
			end
			local prop = win:IsA("CanvasGroup") and "GroupTransparency" or "BackgroundTransparency"
			if state then
				win.Visible = true
				v6:Create(win, A.OPEN, {[prop] = 0}):Play()
				set_pop(win, 1, A.OPEN_POP, nested)
			else
				local tw = v6:Create(win, A.CLOSE, {[prop] = 1})
				set_pop(win, 0.8, A.CLOSE_POP, nested)
				local conn
				conn = tw.Completed:Connect(function()
					if win.Parent and win[prop] >= 0.99 then win.Visible = false end
					if conn then conn:Disconnect() end
				end)
				tw:Play()
			end
		end

		-- Dragging, done by hand rather than with the legacy Draggable property.
		-- Draggable applies to the whole frame, so on Main -- which is mostly a tall
		-- scrolling list of sliders and toggles -- a drag that began on the body moved
		-- the window instead of reaching the control under the cursor. Binding the
		-- drag to the header is the actual fix; the clamp is the second half of it,
		-- because Draggable also happily parked a window fully outside the viewport
		-- where nothing could reach it again. Only Main had a rescue for that
		-- (unfold_header), and only by way of minimizing.
		--
		-- Deltas go straight onto Position's offset and stay 1:1 with the cursor even
		-- under UIScale: a UIScale scales the window's own size and its descendants,
		-- while Position still resolves against the parent, which is the ScreenGui.
		-- The scale components are preserved, so a window anchored to the viewport
		-- centre still tracks a resize.
		local KEEP_ON_SCREEN = 60
		local function make_draggable(win, handle)
			handle = handle or win
			-- A transparent Frame header still reports input; Active makes it consume
			-- the press so it cannot fall through to whatever sits behind. Buttons
			-- inside the header consume their own input, so minb and closeb never
			-- start a drag.
			handle.Active = true

			local dragging = false
			local origin, start_pos

			local function commit(delta)
				local parent = win.Parent
				if not parent then
					return
				end
				local avail = parent.AbsoluteSize
				local size = win.AbsoluteSize
				local want_x = start_pos.X.Scale * avail.X + start_pos.X.Offset + delta.X
				local want_y = start_pos.Y.Scale * avail.Y + start_pos.Y.Offset + delta.Y
				-- Leave a grabbable sliver on screen in both axes. Vertically the
				-- floor is 0: a header dragged above the top edge is a window that
				-- can never be picked up again.
				local max_x = avail.X - KEEP_ON_SCREEN
				local min_x = math.min(-(size.X - KEEP_ON_SCREEN), max_x)
				win.Position = UDim2.new(
					start_pos.X.Scale,
					math.clamp(want_x, min_x, max_x) - start_pos.X.Scale * avail.X,
					start_pos.Y.Scale,
					math.clamp(want_y, 0, math.max(0, avail.Y - 30)) - start_pos.Y.Scale * avail.Y
				)
			end

			table.insert(x6.c, handle.InputBegan:Connect(function(input)
				local ty = input.UserInputType
				if ty ~= Enum.UserInputType.MouseButton1 and ty ~= Enum.UserInputType.Touch then
					return
				end
				dragging = true
				origin = input.Position
				start_pos = win.Position
				-- Latched off the input itself rather than a global InputEnded: a
				-- release over another GUI still ends this input, and without it the
				-- window would stay stuck to the cursor.
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						if conn then
							conn:Disconnect()
						end
					end
				end)
			end))

			table.insert(x6.c, v1.InputChanged:Connect(function(input)
				if not dragging or not start_pos then
					return
				end
				local ty = input.UserInputType
				if ty ~= Enum.UserInputType.MouseMovement and ty ~= Enum.UserInputType.Touch then
					return
				end
				commit(input.Position - origin)
			end))
		end

		local hud = Instance.new("Frame", sg)
		hud.Name = "StatusHUD"
		hud.BackgroundTransparency = 1
		hud.Position = UDim2.new(0.5, -200, 0, 20)
		hud.Size = UDim2.new(0, 400, 0, 30)

		-- Scaled like every other element. The HUD was the one thing never registered,
		-- so at UI Scale 2.0 every window doubled and the status line stayed at 14px,
		-- against the setting's own description ("Scales the entire interface").
		register_window(hud, 1)

		local hud_l = Instance.new("TextLabel", hud)
		hud_l.BackgroundTransparency = 1
		hud_l.Size = UDim2.new(1, 0, 1, 0)
		hud_l.Font = Enum.Font.GothamBold
		hud_l.TextSize = 14
		hud_l.TextColor3 = Color3.fromRGB(255, 255, 255)

		local hud_target, hud_state
		local HUD_ACTIVE = Color3.fromRGB(80, 255, 150)
		local HUD_PAUSED = Color3.fromRGB(255, 180, 80)
		local HUD_DISABLED = Color3.fromRGB(255, 80, 80)
		table.insert(
			x6.c,
			v3.RenderStepped:Connect(function()
				if not x5.g then
					return
				end
				-- x1.Targets, not x1.Tgt: multi-targeting replaced the single slot and
				-- nothing has written Tgt since, so this field read "NONE" even with
				-- a target locked. main.lua strips Tgt from the save file outright.
				local tgt = "None"
				local sel = x1.Targets
				if x1.PI_All then
					tgt = "Everyone"
				elseif sel and #sel > 0 then
					if #sel == 1 then
						tgt = sel[1].DisplayName or sel[1].Name
					else
						tgt = "Multi (" .. tostring(#sel) .. ")"
					end
				elseif x1.AnchorSelf then
					tgt = "Self"
				end
				local state = x1.Disabled and "DISABLED" or (x1.Paused and "PAUSED" or "ACTIVE")
				if tgt ~= hud_target or state ~= hud_state then
					hud_target, hud_state = tgt, state
					hud_l.Text = string.format("TARGET: %s  |  STATUS: %s", tgt:upper(), state)
					hud_l.TextColor3 = x1.Disabled and HUD_DISABLED or (x1.Paused and HUD_PAUSED or HUD_ACTIVE)
				end
			end)
		)
		
		hud.Visible = x1.ShowHUD ~= false

		local m = Instance.new("Frame", sg)
		m.Name = "Main"
		m.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		m.Position = UDim2.new(0, 30, 0.5, -250)
		m.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
		m.Active = true
		-- Dragged by its header only; see make_draggable. The old Draggable made
		-- the whole scrolling body a drag handle.
		local mcorner = Instance.new("UICorner", m)
		mcorner.CornerRadius = UDim.new(0, 10)
		local ms = Instance.new("UIStroke", m)
		ms.Color = Color3.fromRGB(40, 40, 45)
		ms.Thickness = 1

		-- Main is always open, so it starts at full pop.
		register_window(m, 1)

		local h = Instance.new("Frame", m)
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, 0, 0, HEADER_H)
		-- The header is also the whole surface of the collapsed pill, so binding
		-- the drag here keeps the pill draggable without a second code path.
		make_draggable(m, h)

		local t = Instance.new("TextLabel", h)
		t.BackgroundTransparency = 1
		t.Position = UDim2.new(0, 20, 0, 0)
		t.Size = UDim2.new(0.6, 0, 1, 0)
		t.Text = "PROJECT GRAVITY"
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 16
		t.TextXAlignment = 0

		local c = Instance.new("ScrollingFrame", m)
		c.BackgroundTransparency = 1
		c.Position = UDim2.new(0, 0, 0, HEADER_H + CONTENT_GAP)
		c.Size = UDim2.new(1, 0, 1, -(HEADER_H + CONTENT_GAP * 2))
		c.ScrollBarThickness = 0
		c.AutomaticCanvasSize = Enum.AutomaticSize.Y
		c.CanvasSize = UDim2.new(0, 0, 0, 0)
		local l = Instance.new("UIListLayout", c)
		l.Padding = UDim.new(0, 12)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local p = Instance.new("UIPadding", c)
		p.PaddingLeft = UDim.new(0, 20)
		p.PaddingRight = UDim.new(0, 20)
		p.PaddingBottom = UDim.new(0, 20)

		local am = Instance.new("CanvasGroup", sg)
		am.Name = "Advanced"
		am.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		am.Position = UDim2.new(0, 360, 0.5, -200)
		am.Size = UDim2.new(0, 260, 0, 380)
		am.Visible = false
		am.GroupTransparency = 1
		am.Active = true
		Instance.new("UICorner", am).CornerRadius = UDim.new(0, 10)
		local ams = Instance.new("UIStroke", am)
		ams.Color = Color3.fromRGB(40, 40, 45)
		ams.Thickness = 1

		-- Starts hidden, so it starts at the closed pop factor and toggle_window
		-- tweens it up to the app scale rather than to a hardcoded 1.
		register_window(am, 0.8)

		local ah = Instance.new("Frame", am)
		ah.BackgroundTransparency = 1
		ah.Size = UDim2.new(1, 0, 0, 50)
		make_draggable(am, ah)
		local at = Instance.new("TextLabel", ah)
		at.BackgroundTransparency = 1
		at.Position = UDim2.new(0, 20, 0, 0)
		at.Size = UDim2.new(0.6, 0, 1, 0)
		at.Text = "ADVANCED"
		at.TextColor3 = Color3.fromRGB(255, 255, 255)
		at.Font = Enum.Font.GothamBold
		at.TextSize = 14
		at.TextXAlignment = 0

		local ac = Instance.new("ScrollingFrame", am)
		ac.BackgroundTransparency = 1
		ac.Position = UDim2.new(0, 0, 0, 50)
		ac.Size = UDim2.new(1, 0, 1, -60)
		ac.ScrollBarThickness = 0
		ac.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ac.CanvasSize = UDim2.new(0, 0, 0, 0)
		-- Rebuildable, so a reset can repaint it. Every control in here caches its
		-- value at build time -- UI_elements M.s keeps `current` as a private local --
		-- and this block used to be built exactly once. After "Reset All Settings" the
		-- knobs therefore kept the old numbers while x1 held the defaults, and nudging
		-- UI Scale committed from the stale value: a reset from 2.0 then one step down
		-- gave 1.9 instead of 1.1.
		local function populate_advanced()
			ac:ClearAllChildren()
			local acl = Instance.new("UIListLayout", ac)
			acl.Padding = UDim.new(0, 10)
			acl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			local ap = Instance.new("UIPadding", ac)
			ap.PaddingLeft = UDim.new(0, 20)
			ap.PaddingRight = UDim.new(0, 20)

			et(ac, "Predictive Tracking", x1.PredictiveTracking ~= false, function(v)
				x1.PredictiveTracking = v
				save_settings()
			end, "Predicts player movement to smooth out parts when targeting them.")
		
			es(ac, "Prediction Factor", 0, 500, x1.PredictionFactor or 150, function(v)
				x1.PredictionFactor = v
				save_settings()
			end, false, "How far ahead the script predicts the target's movement.")
		
			es(ac, "Damping", 0, 5, x1.Damping, function(v)
				x1.Damping = v
				save_settings()
			end, false, "Slows down parts to reduce jittering. Higher values = smoother but slower.")
		
			es(ac, "Integral Gain", 0, 10, x1.Ki, function(v)
				x1.Ki = v
				save_settings()
			end, false, "Helps parts reach their exact target position faster (fixes sagging).")
		
			es(ac, "Max Speed", 50, 2000, x1.MaxSpeed or 500, function(v)
				x1.MaxSpeed = v
				save_settings()
			end, false, "Caps the maximum velocity of all parts to prevent them from flinging.")
		
			es(ac, "Angular Damp", 0, 1, x1.AngularDamping or 0.5, function(v)
				x1.AngularDamping = v
				save_settings()
			end, false, "Stops parts from spinning uncontrollably on their own axis.")
		
			es(ac, "Vert Stiffness", 0.1, 5, x1.VerticalStiffness or 1.0, function(v)
				x1.VerticalStiffness = v
				save_settings()
			end, false, "Multiplies vertical pull to fight Roblox's gravity. Use 1.0 for normal.")

			es(ac, "UI Scale", 0.5, 2.0, x1.UIScale or 1.0, function(v)
				x1.UIScale = v
				-- Every registered window, not just these two: the mode selector and
				-- the target list are nested under Main and only carry their pop
				-- factor, so Main's UIScale covers them; Advanced, Keybinds and the
				-- dialogs are siblings and used to be missed or overwritten.
				apply_ui_scale()
				save_settings()
			end, false, "Scales the entire interface. 1.0 is default.")

			et(ac, "Aggressive Claiming", x1.AggressiveClaim, function(v)
				x1.AggressiveClaim = v
				save_settings()
			end, "WARNING: Spams CFrames into your character to forcefully steal Network Ownership from other scripts.")
		
			et(ac, "Void Protection", x1.VoidProtection, function(v)
				x1.VoidProtection = v
				save_settings()
			end, "Automatically ignores targets that fall into the void to prevent your parts from being destroyed.")

			et(ac, "Disable Shadows", x1.Perf_DisableShadows, function(v)
				x1.Perf_DisableShadows = v
				ApplyPerfShadows(v)
				save_settings()
			end, "Turns off all game shadows to boost your FPS significantly.")
		
			et(ac, "Disable Post-FX", x1.Perf_DisablePostFX, function(v)
				x1.Perf_DisablePostFX = v
				ApplyPerfPostFX(v)
				save_settings()
			end, "Disables Bloom, Blur, SunRays, and ColorCorrection to save performance.")
		
			et(ac, "Potato Materials", x1.Perf_PotatoMaterials, function(v)
				x1.Perf_PotatoMaterials = v
				ApplyPerfMaterials(v)
				save_settings()
			end, "Forces all parts in the game to use SmoothPlastic to lower rendering load.")
		
			et(ac, "Hide Particles", x1.Perf_HideParticles, function(v)
				x1.Perf_HideParticles = v
				ApplyPerfParticles(v)
				save_settings()
			end, "Hides fire, smoke, beams, trails, and particle emitters.")
		
			ApplyPerfShadows(x1.Perf_DisableShadows)
			ApplyPerfPostFX(x1.Perf_DisablePostFX)
			ApplyPerfMaterials(x1.Perf_PotatoMaterials)
			ApplyPerfParticles(x1.Perf_HideParticles)
		
			local function update_color()
				if x6.b then
					x6.b.Color = x1.k3
					if x6.b:FindFirstChild("Visual") and x6.b.Visual:FindFirstChildOfClass("ImageLabel") then
						x6.b.Visual:FindFirstChildOfClass("ImageLabel").ImageColor3 = x1.k3
					end
				end
				save_settings()
			end

			-- Each channel slider rebuilds the whole colour, so it has to hand the other
			-- two back as the same integers they came in as. Color3 stores 0-1 floats and
			-- v/255 does not round-trip exactly, so passing the bare product re-quantised
			-- the untouched channels on every drag and walked the colour off over a
			-- session of tweaking.
			local function ch(x)
				return math.floor(x * 255 + 0.5)
			end
			es(ac, "Center Color R", 0, 255, ch(x1.k3.R), function(v)
				x1.k3 = Color3.fromRGB(v, ch(x1.k3.G), ch(x1.k3.B))
				update_color()
			end, true)
			es(ac, "Center Color G", 0, 255, ch(x1.k3.G), function(v)
				x1.k3 = Color3.fromRGB(ch(x1.k3.R), v, ch(x1.k3.B))
				update_color()
			end, true)
			es(ac, "Center Color B", 0, 255, ch(x1.k3.B), function(v)
				x1.k3 = Color3.fromRGB(ch(x1.k3.R), ch(x1.k3.G), v)
				update_color()
			end, true)
		end
		populate_advanced()
		x5.refresh_advanced = populate_advanced

		local km = Instance.new("CanvasGroup", sg)
		km.Name = "Keybinds"
		km.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		km.Position = UDim2.new(0, 360, 0.5, -220)
		km.Size = UDim2.new(0, 300, 0, 440)
		km.Visible = false
		km.GroupTransparency = 1
		km.Active = true
		Instance.new("UICorner", km).CornerRadius = UDim.new(0, 10)
		local kms = Instance.new("UIStroke", km)
		kms.Color = Color3.fromRGB(40, 40, 45)
		kms.Thickness = 1
		register_window(km, 0.8)

		local kh = Instance.new("Frame", km)
		kh.BackgroundTransparency = 1
		kh.Size = UDim2.new(1, 0, 0, 44)
		make_draggable(km, kh)
		local kt = Instance.new("TextLabel", kh)
		kt.BackgroundTransparency = 1
		kt.Position = UDim2.new(0, 20, 0, 0)
		kt.Size = UDim2.new(0.6, 0, 1, 0)
		kt.Text = "KEYBINDS"
		kt.TextColor3 = Color3.fromRGB(255, 255, 255)
		kt.Font = Enum.Font.GothamBold
		kt.TextSize = 14
		kt.TextXAlignment = 0

		local kclose = Instance.new("TextButton", kh)
		kclose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		kclose.Position = UDim2.new(1, -30, 0.5, -10)
		kclose.Size = UDim2.new(0, 20, 0, 20)
		kclose.Text = ""
		Instance.new("UICorner", kclose).CornerRadius = UDim.new(1, 0)
		kclose.MouseButton1Click:Connect(function()
			toggle_window(km, false)
		end)

		local ksearch = Instance.new("TextBox", km)
		ksearch.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		ksearch.Position = UDim2.new(0, 20, 0, 44)
		ksearch.Size = UDim2.new(1, -40, 0, 30)
		ksearch.PlaceholderText = "Search shapes..."
		ksearch.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
		ksearch.Text = ""
		ksearch.TextColor3 = Color3.fromRGB(255, 255, 255)
		ksearch.Font = Enum.Font.Gotham
		ksearch.TextSize = 12
		ksearch.ClearTextOnFocus = false
		Instance.new("UICorner", ksearch).CornerRadius = UDim.new(0, 6)

		local kc = Instance.new("ScrollingFrame", km)
		kc.BackgroundTransparency = 1
		kc.Position = UDim2.new(0, 0, 0, 82)
		kc.Size = UDim2.new(1, 0, 1, -92)
		kc.ScrollBarThickness = 0
		kc.AutomaticCanvasSize = Enum.AutomaticSize.Y
		kc.CanvasSize = UDim2.new(0, 0, 0, 0)
		local kcl = Instance.new("UIListLayout", kc)
		kcl.Padding = UDim.new(0, 8)
		kcl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local kcp = Instance.new("UIPadding", kc)
		kcp.PaddingLeft = UDim.new(0, 20)
		kcp.PaddingRight = UDim.new(0, 20)
		kcp.PaddingBottom = UDim.new(0, 20)

		-- Notifications go through System's x7.n when it is up so a rejected key
		-- reads like every other message; before then there is nowhere to show it.
		local function notify(title, text, dur)
			local x8 = context.x8
			if x8 and x8.notify then
				x8.notify(title, text, dur)
				return
			end
			pcall(function()
				v5:SetCore("SendNotification", { Title = title, Text = text, Duration = dur or 3 })
			end)
		end

		local function keybinds_table()
			if type(x1.Keybinds) ~= "table" then
				x1.Keybinds = { Recenter = "E", Reset = "Q", Pause = "P", Disable = "L", Shapes = {} }
			end
			if type(x1.Keybinds.Shapes) ~= "table" then
				x1.Keybinds.Shapes = {}
			end
			return x1.Keybinds
		end

		-- Shared by both kinds of row. exclude_id keeps re-picking the key a row
		-- already holds from being reported as a conflict with itself.
		local function accept_key(key_name, exclude_id, assign)
			local kb = keybinds_table()
			if key_name == "" then
				assign(kb, "")
				save_settings()
				return true
			end
			local x8 = context.x8
			local conflict = x8 and x8.find_conflict and x8.find_conflict(key_name, exclude_id)
			if conflict then
				notify("Keybinds", key_name .. " is already bound to " .. conflict .. ".", 3)
				return false
			end
			assign(kb, key_name)
			save_settings()
			return true
		end

		local function populate_keybinds(filter)
			kc:ClearAllChildren()
			local layout = Instance.new("UIListLayout", kc)
			layout.Padding = UDim.new(0, 8)
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			local pad = Instance.new("UIPadding", kc)
			pad.PaddingLeft = UDim.new(0, 20)
			pad.PaddingRight = UDim.new(0, 20)
			pad.PaddingBottom = UDim.new(0, 20)

			local x8 = context.x8
			filter = (filter or ""):lower()

			if filter == "" then
				eh(kc, "Core")
				local core = (x8 and x8.core_actions) or {}
				for _, entry in ipairs(core) do
					local id = entry.id
					ekb(kc, entry.label, function()
						return keybinds_table()[id]
					end, function(key_name)
						return accept_key(key_name, id, function(kb, v)
							kb[id] = v
						end)
					end, entry.desc)
				end
			end

			eh(kc, filter == "" and "Shapes" or "Shapes matching \"" .. filter .. "\"")
			local names = {}
			for shape_name in pairs(x2) do
				if filter == "" or shape_name:lower():find(filter, 1, true) then
					names[#names + 1] = shape_name
				end
			end
			-- Bound shapes first, then alphabetical, so what the user has set is
			-- at the top of a list this long instead of buried in it.
			table.sort(names, function(a, b)
				local shapes = keybinds_table().Shapes
				local ba = (shapes[a] and shapes[a] ~= "") and 1 or 0
				local bb = (shapes[b] and shapes[b] ~= "") and 1 or 0
				if ba ~= bb then
					return ba > bb
				end
				return a < b
			end)

			if #names == 0 then
				local none = Instance.new("TextLabel", kc)
				none.BackgroundTransparency = 1
				none.Size = UDim2.new(1, 0, 0, 24)
				none.Text = "No shapes match."
				none.TextColor3 = Color3.fromRGB(120, 120, 130)
				none.TextXAlignment = Enum.TextXAlignment.Left
				none.Font = Enum.Font.Gotham
				none.TextSize = 11
			end

			for _, shape_name in ipairs(names) do
				local captured = shape_name
				ekb(kc, captured, function()
					return keybinds_table().Shapes[captured]
				end, function(key_name)
					return accept_key(key_name, "shape:" .. captured, function(kb, v)
						-- "" is how a core action records "unbound", but a shape
						-- with no key does not need an entry at all: dropping it
						-- keeps the settings file from growing a line per shape
						-- the user merely looked at.
						kb.Shapes[captured] = (v ~= "" and v) or nil
					end)
				end)
			end
		end

		ksearch:GetPropertyChangedSignal("Text"):Connect(function()
			populate_keybinds(ksearch.Text)
		end)

		local kb_btn = eb(c, "Keybinds", function()
			local opening = not km.Visible
			toggle_window(km, opening)
			if opening then
				populate_keybinds(ksearch.Text)
			end
		end)
		kb_btn.Size = UDim2.new(1, 0, 0, 36)

		local ab = eb(c, "Advanced Settings", function()
			toggle_window(am, not am.Visible)
		end)
		ab.Size = UDim2.new(1, 0, 0, 36)

		local ai_btn = eb(c, "PROJECT GRAVITY AI", function()
			if ai_chat_module and ai_chat_module.toggle then
				ai_chat_module.toggle(sg)
			end
		end)
		ai_btn.Size = UDim2.new(1, 0, 0, 36)

		local mode_f = Instance.new("Frame", c)
		mode_f.BackgroundTransparency = 1
		mode_f.Size = UDim2.new(1, 0, 0, 44)
		local db = Instance.new("TextButton", mode_f)
		db.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		db.Size = UDim2.new(1, 0, 1, 0)
		db.Text = "  " .. x1.k6:upper()
		db.TextColor3 = Color3.fromRGB(255, 255, 255)
		db.Font = Enum.Font.GothamBold
		db.TextSize = 13
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
				if m:FindFirstChild("TargetListContainer") and m.TargetListContainer.Visible then
					toggle_window(m.TargetListContainer, false, true)
				end
				toggle_window(x6.dlst_container, new_state, true)
				if new_state and x6.populate_modes then
					-- The typed filter, not a hardcoded "". msb lives outside f1 so its
					-- text persists for the session: reopening the dropdown showed the
					-- full list while the box still read the old search.
					x6.populate_modes(x6.mode_filter and x6.mode_filter() or "")
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

			et(gsc, "Simplified Interface", x1.SimpleMode, function(v)
				x1.SimpleMode = v
				save_settings()
				f1()
			end)

			et(gsc, "Show Status HUD", x1.ShowHUD ~= false, function(v)
				x1.ShowHUD = v
				if hud then hud.Visible = v end
				save_settings()
			end)

			et(gsc, "Preserve Collisions", x1.PreserveCollisions, function(v)
				x1.PreserveCollisions = v
				-- while disabled every part already holds its original collision, so
				-- turning this off there would undo that until the next enable
				local keep = v or x1.Disabled
				for part, data in pairs(x6.a) do
					if part and part.Parent then
						part.CanCollide = keep and data.original_can_collide or false
					end
				end
				save_settings()
			end)

			et(gsc, "Anchor to Self", x1.AnchorSelf, function(v)
				x1.AnchorSelf = v
				if v then
					x1.PI_All = false
					table.clear(x1.Targets)
					x1.TgtActive = false
					f1()
				end
				save_settings()
			end)

			if not x1.SimpleMode then
				et(gsc, "Anti-Fling", x1.AntiFling, function(v)
					x1.AntiFling = v
					save_settings()
				end)
				et(gsc, "Force Smooth (Lags)", x1["Force Smooth (Lags)"], function(v)
					x1["Force Smooth (Lags)"] = v
					save_settings()
				end)
				et(gsc, "Realistic Liftoff", x1["Realistic Liftoff"], function(v)
					x1["Realistic Liftoff"] = v
					save_settings()
				end)
			end

			x6.disable_btn = et(gsc, "Disable Gravity", x1.Disabled, function(v)
				-- System owns the switch: parts get their collision back and stop
				-- being driven while disabled, and both are undone on enable. Doing
				-- it here as well would only be a second, partial copy.
				if context.x4 and context.x4.apply_disabled then
					context.x4.apply_disabled(v)
				else
					x1.Disabled = v
				end
				save_settings()
			end)

			if not x1.SimpleMode then
				et(gsc, "Target Everyone", x1.PI_All, function(v)
					x1.PI_All = v
					if v then
						x1.AnchorSelf = false
						table.clear(x1.Targets)
						x1.TgtActive = false
						f1()
					end
					save_settings()
				end)
			end

			local l_btn = Instance.new("TextButton", gsc)
			l_btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			l_btn.Size = UDim2.new(1, 0, 0, 36)
			l_btn.Text = "FORCE LAUNCH"
			l_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			l_btn.Font = Enum.Font.GothamBold
			l_btn.TextSize = 13
			Instance.new("UICorner", l_btn).CornerRadius = UDim.new(0, 6)
			-- == true, not the bare value: Visible rejects nil, and an unset
			-- SlingshotManual made this whole expression nil whenever Slingshot was
			-- the live shape, which threw here and abandoned the rest of f1 --
			-- taking the target selector, the shape controls and reset with it.
			l_btn.Visible = x1.k6 == "Slingshot" and x1.SlingshotManual == true

			l_btn.MouseButton1Click:Connect(function()
				x1.IsLaunching = not x1.IsLaunching
				l_btn.Text = x1.IsLaunching and "RESET SYSTEM" or "FORCE LAUNCH"
				l_btn.BackgroundColor3 = x1.IsLaunching and Color3.fromRGB(50, 150, 200) or Color3.fromRGB(200, 50, 50)
			end)

			table.insert(
				x6.f1_connections,
				v3.Heartbeat:Connect(function()
					if x1.k6 == "Slingshot" and x1.SlingshotManual == true then
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
			tdb.Size = UDim2.new(1, 0, 0, 38)
			tdb.Text = "  " .. tn:upper()
			tdb.TextColor3 = Color3.fromRGB(255, 255, 255)
			tdb.Font = Enum.Font.GothamBold
			tdb.TextSize = 12
			tdb.TextXAlignment = 0
			Instance.new("UICorner", tdb).CornerRadius = UDim.new(0, 6)
			local dst2 = Instance.new("UIStroke", tdb)
			dst2.Color = Color3.fromRGB(40, 40, 45)

			-- Repaints only what the target list feeds -- this button's label and the
			-- HUD -- so a selection does not have to go through f1(), which destroys
			-- and rebuilds the picker hidden. Re-closed over tdb on every f1, so it
			-- always points at the live button. The × affordance appears on the next
			-- real rebuild, which is enough: clearing is one click on an open list.
			x5.refresh_body = function()
				local label = "Select Target"
				if x1.Targets and #x1.Targets > 0 then
					if #x1.Targets == 1 then
						local t1 = x1.Targets[1]
						label = "Target: " .. (t1.DisplayName or t1.Name)
					else
						label = "Multi-Target (" .. tostring(#x1.Targets) .. ")"
					end
				end
				if tdb and tdb.Parent then
					tdb.Text = "  " .. label:upper()
				end
			end

			if x1.Targets and #x1.Targets > 0 then
				local ctb = Instance.new("TextButton", tdb)
				ctb.BackgroundTransparency = 1
				ctb.Position = UDim2.new(1, -30, 0, 0)
				ctb.Size = UDim2.new(0, 30, 1, 0)
				ctb.Text = "×"
				ctb.TextColor3 = Color3.fromRGB(200, 80, 80)
				ctb.TextSize = 20
				ctb.MouseButton1Click:Connect(function()
					table.clear(x1.Targets)
					x1.TgtActive = false
					f1()
				end)
			end

			if m:FindFirstChild("TargetListContainer") then
				m.TargetListContainer:Destroy()
			end
			local tdlst = Instance.new("CanvasGroup", m)
			tdlst.Name = "TargetListContainer"
			tdlst.Visible = false
			tdlst.GroupTransparency = 1
			tdlst.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
			tdlst.Position = UDim2.new(1, 15, 0, 0)
			tdlst.Size = UDim2.new(0, 220, 1, 0)
			Instance.new("UICorner", tdlst).CornerRadius = UDim.new(0, 10)
			local ts = Instance.new("UIStroke", tdlst)
			ts.Color = Color3.fromRGB(40, 40, 45)

			local search_bar = Instance.new("TextBox", tdlst)
			search_bar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
			search_bar.Position = UDim2.new(0, 10, 0, 10)
			search_bar.Size = UDim2.new(1, -20, 0, 34)
			search_bar.PlaceholderText = "Search players..."
			search_bar.Text = ""
			search_bar.TextColor3 = Color3.fromRGB(255, 255, 255)
			search_bar.Font = Enum.Font.Gotham
			search_bar.TextSize = 13
			Instance.new("UICorner", search_bar).CornerRadius = UDim.new(0, 6)

			local scroll_frame = Instance.new("ScrollingFrame", tdlst)
			scroll_frame.BackgroundTransparency = 1
			scroll_frame.Position = UDim2.new(0, 0, 0, 55)
			scroll_frame.Size = UDim2.new(1, 0, 1, -65)
			scroll_frame.ScrollBarThickness = 0
			scroll_frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
			local tdll = Instance.new("UIListLayout", scroll_frame)
			tdll.Padding = UDim.new(0, 5)
			tdll.HorizontalAlignment = Enum.HorizontalAlignment.Center

			local active_highlight = nil
			local function clear_highlight()
				if active_highlight then
					active_highlight:Destroy()
					active_highlight = nil
				end
			end

			local function update_list(filter_text)
				clear_highlight()
				scroll_frame:ClearAllChildren()
				local tdll = Instance.new("UIListLayout", scroll_frame)
				tdll.Padding = UDim.new(0, 5)
				tdll.HorizontalAlignment = Enum.HorizontalAlignment.Center

				for _, pl in ipairs(v2:GetPlayers()) do
					if pl == v8 then
						continue
					end
					if
						filter_text ~= ""
						and not (
							pl.DisplayName:lower():find(filter_text:lower(), 1, true) or pl.Name:lower():find(filter_text:lower(), 1, true)
						)
					then
						continue
					end

					local ib = Instance.new("TextButton", scroll_frame)
					ib.Size = UDim2.new(1, -16, 0, 44)
					ib.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
					ib.Text = ""
					ib.AutoButtonColor = false
					Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 6)
					
					local is_selected = table.find(x1.Targets, pl) ~= nil
					local sel_indicator = Instance.new("Frame", ib)
					sel_indicator.Position = UDim2.new(1, -24, 0.5, -6)
					sel_indicator.Size = UDim2.new(0, 12, 0, 12)
					sel_indicator.BackgroundColor3 = is_selected and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(60, 60, 65)
					Instance.new("UICorner", sel_indicator).CornerRadius = UDim.new(1, 0)

					local pfp = Instance.new("ImageLabel", ib)
					pfp.Size = UDim2.new(0, 32, 0, 32)
					pfp.Position = UDim2.new(0, 6, 0.5, -16)
					pfp.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
					pfp.Image = "rbxthumb://type=AvatarHeadShot&id=" .. pl.UserId .. "&w=48&h=48"
					Instance.new("UICorner", pfp).CornerRadius = UDim.new(1, 0)

					local dname = Instance.new("TextLabel", ib)
					dname.BackgroundTransparency = 1
					dname.Position = UDim2.new(0, 46, 0, 6)
					dname.Size = UDim2.new(1, -54, 0, 16)
					dname.Text = pl.DisplayName
					dname.TextColor3 = Color3.fromRGB(255, 255, 255)
					dname.Font = Enum.Font.GothamBold
					dname.TextSize = 13
					dname.TextXAlignment = 0

					local uname = Instance.new("TextLabel", ib)
					uname.BackgroundTransparency = 1
					uname.Position = UDim2.new(0, 46, 0, 22)
					uname.Size = UDim2.new(1, -54, 0, 14)
					uname.Text = "@" .. pl.Name
					uname.TextColor3 = Color3.fromRGB(150, 150, 150)
					uname.Font = Enum.Font.GothamMedium
					uname.TextSize = 10
					uname.TextXAlignment = 0

					ib.MouseEnter:Connect(function()
						ib.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
						-- Cleared first: moving the pointer fast enough gets the next
						-- row's MouseEnter in before this row's MouseLeave, and the
						-- single-slot handle would otherwise drop the older one
						-- unreachable while it stayed parented to its character.
						clear_highlight()
						if pl.Character then
							local h = Instance.new("Highlight")
							h.FillColor = Color3.fromRGB(255, 255, 255)
							h.OutlineColor = Color3.fromRGB(255, 255, 255)
							-- Adopted by the row rather than the character, so the
							-- teardown below takes it with it. Clicking a row calls
							-- f1(), which Destroy()s this whole list, and a Destroy
							-- fires no MouseLeave -- so a highlight parented to the
							-- character outlived the only handle to it and left that
							-- player glowing for the rest of the session.
							h.Adornee = pl.Character
							h.Parent = ib
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
							x1.AnchorSelf = false
							x1.PI_All = false
						end
						x1.TgtActive = (#x1.Targets > 0)
						-- Repaint the HUD and the panel body, but leave this list alone.
						-- f1() destroys and rebuilds the picker hidden, so selecting three
						-- players meant reopening it three times -- and the two
						-- sel_indicator writes above were dead work, overwritten by a
						-- rebuild microseconds later. Any typed search text survives too.
						if x5.refresh_body then
							x5.refresh_body()
						end
					end)
				end
			end

			table.insert(x6.f1_connections, search_bar:GetPropertyChangedSignal("Text"):Connect(function()
				update_list(search_bar.Text)
			end))
			tdb.MouseButton1Click:Connect(function()
				local new_state = not tdlst.Visible
				if x6.dlst_container and x6.dlst_container.Visible then
					toggle_window(x6.dlst_container, false, true)
				end
				toggle_window(tdlst, new_state, true)
				if new_state then
					update_list("")
				end
			end)

			if not x1.SimpleMode then
				local shape_mod = get_shape(x1.k6)
				if shape_mod and shape_mod.Controls then
					for _, ctrl in ipairs(shape_mod.Controls) do
						local current_val = s[ctrl.Key]
						local p_frame = ctrl.Parent == "gsc" and gsc or sc
						if ctrl.Type == "Slider" then
							if ctrl.LegacyToggle and type(current_val) == "boolean" then
								current_val = current_val and 2 or 1
								s[ctrl.Key] = current_val
							end
							if current_val == nil then
								if ctrl.Default ~= nil then
									current_val = ctrl.Default
								else
									current_val = ctrl.Min
								end
							end
							local max_val = ctrl.Max
							if string.find(ctrl.Name:lower(), "speed") and not ctrl.ExactMax then
								max_val = max_val + 300
							end
							if ctrl.Div then current_val = current_val * ctrl.Div end
							current_val = math.clamp(current_val, ctrl.Min, max_val)
							s[ctrl.Key] = ctrl.Div and (current_val / ctrl.Div) or current_val
							es(p_frame, ctrl.Name, ctrl.Min, max_val, current_val, function(v)
								if ctrl.Div then s[ctrl.Key] = v / ctrl.Div else s[ctrl.Key] = v end
							end, ctrl.IntOnly, ctrl.Desc)
						elseif ctrl.Type == "Toggle" then
							if type(current_val) ~= "boolean" then
								current_val = ctrl.Default == true
							end
							-- Seated back into the config like the Slider and TextBox
							-- branches already do. Without it a Toggle whose key is
							-- missing from config.lua draws itself ON from its Default
							-- while the shape keeps reading c[key] as nil and behaves
							-- OFF, and the two only agree once the user clicks it.
							s[ctrl.Key] = current_val
							et(p_frame, ctrl.Name, current_val, function(v)
								s[ctrl.Key] = v
							end, ctrl.Desc)
						elseif ctrl.Type == "TextBox" and etb then
							if type(current_val) ~= "string" then
								current_val = type(ctrl.Default) == "string" and ctrl.Default or ""
							end
							s[ctrl.Key] = current_val
							etb(p_frame, ctrl.Name, current_val, function(v)
								s[ctrl.Key] = v
							end, ctrl.Desc, ctrl.MaxChars)
						end
					end
				end
			end

			local reset_btn = Instance.new("TextButton", sc)
		reset_btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		reset_btn.Size = UDim2.new(1, 0, 0, 40)
		reset_btn.Text = "⚠ RESET ALL SETTINGS"
		reset_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		reset_btn.Font = Enum.Font.GothamBold
		reset_btn.TextSize = 13
		reset_btn.AutoButtonColor = false
		Instance.new("UICorner", reset_btn).CornerRadius = UDim.new(0, 6)
		local reset_stroke = Instance.new("UIStroke", reset_btn)
		reset_stroke.Color = Color3.fromRGB(255, 80, 80)
		reset_stroke.Thickness = 1

		reset_btn.MouseEnter:Connect(function()
			v6:Create(reset_btn, A.HOVER, { BackgroundColor3 = Color3.fromRGB(220, 50, 50) }):Play()
			v6:Create(reset_stroke, A.HOVER, { Color = Color3.fromRGB(255, 120, 120) }):Play()
		end)
		reset_btn.MouseLeave:Connect(function()
			v6:Create(reset_btn, A.HOVER, { BackgroundColor3 = Color3.fromRGB(180, 40, 40) }):Play()
			v6:Create(reset_stroke, A.HOVER, { Color = Color3.fromRGB(255, 80, 80) }):Play()
		end)

			reset_btn.MouseButton1Click:Connect(function()
				if x6.reset_confirm then
					x6.reset_confirm:Destroy()
					x6.reset_confirm = nil
				end

				local confirm = Instance.new("CanvasGroup", sg)
				confirm.Name = "ResetConfirm"
				confirm.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
				confirm.Position = UDim2.new(0.5, -160, 0.5, -100)
				confirm.Size = UDim2.new(0, 320, 0, 200)
				confirm.GroupTransparency = 1
				confirm.ZIndex = 100
				Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 12)
				local confirm_stroke = Instance.new("UIStroke", confirm)
				confirm_stroke.Color = Color3.fromRGB(120, 40, 40)
				confirm_stroke.Thickness = 1

				local warning_icon = Instance.new("TextLabel", confirm)
				warning_icon.BackgroundTransparency = 1
				warning_icon.Position = UDim2.new(0.5, -15, 0, 15)
				warning_icon.Size = UDim2.new(0, 30, 0, 30)
				warning_icon.Text = "⚠"
				warning_icon.TextColor3 = Color3.fromRGB(255, 100, 100)
				warning_icon.TextSize = 24
				warning_icon.ZIndex = 101

				local confirm_title = Instance.new("TextLabel", confirm)
				confirm_title.BackgroundTransparency = 1
				confirm_title.Position = UDim2.new(0, 20, 0, 50)
				confirm_title.Size = UDim2.new(1, -40, 0, 30)
				confirm_title.Text = "RESET ALL SETTINGS?"
				confirm_title.TextColor3 = Color3.fromRGB(255, 255, 255)
				confirm_title.Font = Enum.Font.GothamBold
				confirm_title.TextSize = 16
				confirm_title.ZIndex = 101

				local confirm_desc = Instance.new("TextLabel", confirm)
				confirm_desc.BackgroundTransparency = 1
				confirm_desc.Position = UDim2.new(0, 20, 0, 80)
				confirm_desc.Size = UDim2.new(1, -40, 0, 40)
				confirm_desc.Text = "This will reset all settings and shape configurations to their default values. This cannot be undone."
				confirm_desc.TextColor3 = Color3.fromRGB(150, 150, 160)
				confirm_desc.Font = Enum.Font.Gotham
				confirm_desc.TextSize = 12
				confirm_desc.TextWrapped = true
				confirm_desc.ZIndex = 101

				local cancel_btn = Instance.new("TextButton", confirm)
				cancel_btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
				cancel_btn.Position = UDim2.new(0, 20, 1, -50)
				cancel_btn.Size = UDim2.new(0.5, -30, 0, 36)
				cancel_btn.Text = "CANCEL"
				cancel_btn.TextColor3 = Color3.fromRGB(200, 200, 210)
				cancel_btn.Font = Enum.Font.GothamBold
				cancel_btn.TextSize = 12
				cancel_btn.AutoButtonColor = false
				cancel_btn.ZIndex = 101
				Instance.new("UICorner", cancel_btn).CornerRadius = UDim.new(0, 6)
				local cancel_stroke = Instance.new("UIStroke", cancel_btn)
				cancel_stroke.Color = Color3.fromRGB(50, 50, 55)

				local confirm_reset_btn = Instance.new("TextButton", confirm)
				confirm_reset_btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
				confirm_reset_btn.Position = UDim2.new(0.5, 10, 1, -50)
				confirm_reset_btn.Size = UDim2.new(0.5, -30, 0, 36)
				confirm_reset_btn.Text = "RESET"
				confirm_reset_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				confirm_reset_btn.Font = Enum.Font.GothamBold
				confirm_reset_btn.TextSize = 12
				confirm_reset_btn.AutoButtonColor = false
				confirm_reset_btn.ZIndex = 101
				Instance.new("UICorner", confirm_reset_btn).CornerRadius = UDim.new(0, 6)
				local confirm_reset_stroke = Instance.new("UIStroke", confirm_reset_btn)
				confirm_reset_stroke.Color = Color3.fromRGB(120, 30, 30)

				-- Both buttons dismiss the same way, and the destroy has to wait out
				-- the fade -- so the delay is read off the curve rather than
				-- repeating its duration as a literal that drifts when A.CLOSE
				-- changes.
				local function dismiss_confirm()
					v6:Create(confirm, A.CLOSE, { GroupTransparency = 1 }):Play()
					set_pop(confirm, 0.9, A.CLOSE_POP)
					task.delay(A.CLOSE.Time, function()
						if confirm.Parent then confirm:Destroy() end
						if x6.reset_confirm == confirm then x6.reset_confirm = nil end
					end)
				end

				cancel_btn.MouseButton1Click:Connect(dismiss_confirm)

				confirm_reset_btn.MouseButton1Click:Connect(function()
					if reset_config then
						reset_config()
						save_settings()
						-- The four Perf_* flags describe changes already made to the
						-- game -- Lighting.GlobalShadows, every part's Material, every
						-- emitter -- and reset_config only puts the flags back to
						-- false. Without this the config and the save file said
						-- "shadows on" while the game still had them off, and the
						-- toggle needed a manual extra click before it would actually
						-- undo anything.
						RestoreAllPerf()
						-- Keybinds and UIScale are both part of the reset, and
						-- neither takes effect on its own: the hotkeys have to be
						-- rebound from the restored table and every window
						-- rescaled, or the panel keeps the old values until the
						-- next launch.
						local x8 = context.x8
						if x8 and x8.rebind_all then
							pcall(x8.rebind_all)
						end
						apply_ui_scale()
						-- Repaint the two windows that are built once and never rebuilt
						-- by f1. Every control in them cached its value at build time,
						-- so without this they all sat showing pre-reset numbers while
						-- x1 held the defaults.
						if x5.refresh_advanced then
							pcall(x5.refresh_advanced)
						end
						pcall(populate_keybinds, ksearch.Text)
						if x5.up then
							x5.up()
						end
						if x6.b then
							x6.b.Color = x1.k3
							if x6.b:FindFirstChild("Visual") and x6.b.Visual:FindFirstChildOfClass("ImageLabel") then
								x6.b.Visual:FindFirstChildOfClass("ImageLabel").ImageColor3 = x1.k3
							end
						end
					end
					dismiss_confirm()
				end)

				x6.reset_confirm = confirm

				-- Registered like every other window so it opens at the user's
				-- scale instead of always at 1. AnchorPoint moves to the middle
				-- because a UIScale grows a frame from its top-left corner, which
				-- would walk a centred dialog off-centre as the scale went up.
				confirm.AnchorPoint = Vector2.new(0.5, 0.5)
				confirm.Position = UDim2.new(0.5, 0, 0.5, 0)
				register_window(confirm, 0.9)
				-- Split the way every other window opens: the fade rides OPEN
				-- because transparency has no momentum to overshoot -- Back on it
				-- just drives the value past 0 where it clamps and stalls -- while
				-- the scale gets OPEN_POP, which is where the spring belongs.
				v6:Create(confirm, A.OPEN, { GroupTransparency = 0 }):Play()
				set_pop(confirm, 1, A.OPEN_POP)
			end)
		end
		x5.up = f1

		local dlst_container = Instance.new("CanvasGroup", m)
		dlst_container.Name = "ModeSelector"
		dlst_container.Visible = false
		dlst_container.GroupTransparency = 1
		dlst_container.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		dlst_container.Position = UDim2.new(1, 15, 0, 0)
		dlst_container.Size = UDim2.new(0, 220, 1, 0)
		Instance.new("UICorner", dlst_container).CornerRadius = UDim.new(0, 10)
		local dls = Instance.new("UIStroke", dlst_container)
		dls.Color = Color3.fromRGB(40, 40, 45)

		local msb = Instance.new("TextBox", dlst_container)
		msb.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		msb.Position = UDim2.new(0, 10, 0, 10)
		msb.Size = UDim2.new(1, -20, 0, 34)
		msb.PlaceholderText = "Search modes..."
		msb.Text = ""
		msb.TextColor3 = Color3.fromRGB(255, 255, 255)
		msb.Font = Enum.Font.Gotham
		msb.TextSize = 13
		Instance.new("UICorner", msb).CornerRadius = UDim.new(0, 6)

		local dlst = Instance.new("ScrollingFrame", dlst_container)
		dlst.BackgroundTransparency = 1
		dlst.Position = UDim2.new(0, 0, 0, 55)
		dlst.Size = UDim2.new(1, 0, 1, -65)
		dlst.ScrollBarThickness = 0
		dlst.AutomaticCanvasSize = Enum.AutomaticSize.Y
		dlst.CanvasSize = UDim2.new(0, 0, 0, 0)

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
				return a < b
			end)

			for _, mn in ipairs(modes) do
				-- Plain search, like populate_keybinds:756. Without the flag the typed
				-- text is a Lua pattern, so a single "(" throws "unfinished capture"
				-- out of the Text callback -- after dlst:ClearAllChildren() has already
				-- run, so the list stays empty and every further keystroke re-errors.
				if filter ~= "" and not mn:lower():find(filter:lower(), 1, true) then
					continue
				end

				local f = Instance.new("Frame", dlst)
				f.Size = UDim2.new(1, -16, 0, 40)
				f.BackgroundColor3 = mn == x1.k6 and Color3.fromRGB(40, 40, 180) or Color3.fromRGB(25, 25, 30)
				Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

				local ib = Instance.new("TextButton", f)
				ib.Size = UDim2.new(1, -40, 1, 0)
				ib.Position = UDim2.new(0, 8, 0, 0)
				ib.BackgroundTransparency = 1
				ib.Text = "  " .. mn
				ib.TextColor3 = Color3.fromRGB(255, 255, 255)
				ib.Font = Enum.Font.GothamBold
				ib.TextSize = 12
				ib.TextXAlignment = 0

				local sb = Instance.new("TextButton", f)
				sb.Position = UDim2.new(1, -35, 0, 0)
				sb.Size = UDim2.new(0, 35, 1, 0)
				sb.BackgroundTransparency = 1
				sb.Text = favorites[mn] and "★" or "☆"
				sb.TextColor3 = favorites[mn] and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(80, 80, 85)
				sb.Font = Enum.Font.GothamBold
				sb.TextSize = 14

				sb.MouseButton1Click:Connect(function()
					favorites[mn] = not favorites[mn]
					save_favs()
					populate_modes(filter)
				end)

				ib.MouseButton1Click:Connect(function()
					local x4 = context.x4
					if x4 and x4.switch_shape then
						if x4.switch_shape(mn) and db then
							db.Text = "  " .. mn:upper()
						end
					else
						-- fallback before System is up
						local shape = get_shape(mn)
						if shape then
							-- switch_shape owns this notice on the normal path; repeat it
							-- here because this branch sets k6 itself and never reaches it.
							if shape.Testing and context.x8 and context.x8.notify then
								context.x8.notify("Testing", mn .. " is still in testing.", 4)
							end
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
							save_settings()
							if x5.up then
								x5.up()
							end
						end
					end
					toggle_window(dlst_container, false, true)
				end)
			end
		end

		msb:GetPropertyChangedSignal("Text"):Connect(function()
			populate_modes(msb.Text)
		end)

		x6.populate_modes = populate_modes
		x6.mode_filter = function()
			return msb and msb.Text or ""
		end
		populate_modes("")

		-- System calls this after every shape switch, including one driven by a
		-- hotkey while the mode list was never opened, so the dropdown label and
		-- the highlighted row cannot fall out of step with x1.k6.
		function x5.sync_shape(name)
			if db then
				db.Text = "  " .. tostring(name):upper()
			end
			if dlst_container and dlst_container.Visible then
				populate_modes(msb.Text)
			end
		end

		-- Declared ahead of the header buttons because their click handlers close
		-- over it: while the panel is a pill every extra is invisible but still
		-- hit-testable, and stacked on top of minb. See set_header_extras below.
		local collapsed = false

		local minb = Instance.new("TextButton", h)
		minb.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
		minb.Position = UDim2.new(1, -60, 0.5, -10)
		minb.Size = UDim2.new(0, 20, 0, 20)
		minb.Text = ""
		Instance.new("UICorner", minb).CornerRadius = UDim.new(1, 0)
		
		local dcb = Instance.new("TextButton", h)
		dcb.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
		dcb.Position = UDim2.new(1, -120, 0.5, -10)
		dcb.Size = UDim2.new(0, 20, 0, 20)
		dcb.Text = "D"
		dcb.TextColor3 = Color3.fromRGB(255, 255, 255)
		dcb.Font = Enum.Font.GothamBold
		dcb.TextSize = 11
		Instance.new("UICorner", dcb).CornerRadius = UDim.new(1, 0)
		dcb.MouseButton1Click:Connect(function()
			if collapsed then return end
			pcall(function()
				if setclipboard then
					setclipboard("https://discord.gg/9xYyyYuKap")
				elseif toclipboard then
					toclipboard("https://discord.gg/9xYyyYuKap")
				end
			end)
			pcall(function()
				v5:SetCore("SendNotification", { Title = "Discord", Text = "Invite link copied to clipboard!", Duration = 3 })
			end)
		end)

		local tutb = Instance.new("TextButton", h)
		tutb.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
		tutb.Position = UDim2.new(1, -90, 0.5, -10)
		tutb.Size = UDim2.new(0, 20, 0, 20)
		tutb.Text = "?"
		tutb.TextColor3 = Color3.fromRGB(255, 255, 255)
		tutb.Font = Enum.Font.GothamBold
		tutb.TextSize = 14
		Instance.new("UICorner", tutb).CornerRadius = UDim.new(1, 0)

		local tut_container = Instance.new("CanvasGroup", sg)
		tut_container.Name = "Tutorial"
		tut_container.Visible = false
		tut_container.GroupTransparency = 1
		tut_container.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		tut_container.Position = UDim2.new(0.5, -200, 0.5, -150)
		tut_container.Size = UDim2.new(0, 400, 0, 300)
		tut_container.Active = true
		Instance.new("UICorner", tut_container).CornerRadius = UDim.new(0, 10)
		local tuls = Instance.new("UIStroke", tut_container)
		tuls.Color = Color3.fromRGB(40, 40, 45)

		local tut_header = Instance.new("Frame", tut_container)
		tut_header.BackgroundTransparency = 1
		tut_header.Size = UDim2.new(1, 0, 0, 40)
		make_draggable(tut_container, tut_header)
		
		local tut_title = Instance.new("TextLabel", tut_header)
		tut_title.BackgroundTransparency = 1
		tut_title.Position = UDim2.new(0, 20, 0, 0)
		tut_title.Size = UDim2.new(0.8, 0, 1, 0)
		tut_title.Text = "HOW TO USE PROJECT GRAVITY"
		tut_title.TextColor3 = Color3.fromRGB(255, 255, 255)
		tut_title.Font = Enum.Font.GothamBlack
		tut_title.TextSize = 14
		tut_title.TextXAlignment = 0

		local tut_close = Instance.new("TextButton", tut_header)
		tut_close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		tut_close.Position = UDim2.new(1, -30, 0.5, -10)
		tut_close.Size = UDim2.new(0, 20, 0, 20)
		tut_close.Text = ""
		Instance.new("UICorner", tut_close).CornerRadius = UDim.new(1, 0)
		tut_close.MouseButton1Click:Connect(function()
			toggle_window(tut_container, false)
		end)

		local tut_text = Instance.new("TextLabel", tut_container)
		tut_text.BackgroundTransparency = 1
		tut_text.Position = UDim2.new(0, 20, 0, 50)
		tut_text.Size = UDim2.new(1, -40, 1, -70)
		tut_text.Text = "• Core Controls: Press 'E' to reposition the gravitational center. Press 'Q' to wipe all parts and reset.\n\n• Targeting: Click 'Select Target' to focus the gravitational pull onto a specific player.\n\n• Hotkeys: Press 'P' to instantly Pause physics (freezing parts). Press 'L' to toggle Disable mode.\n\n• Modes: The Mode Selector allows you to morph between different geometrical formations.\n\n• Configuration: Scroll down the main menu to tune the shape config (radius, spin, etc.). Open 'Advanced Settings' to tweak global physics limits."
		tut_text.TextColor3 = Color3.fromRGB(200, 200, 205)
		tut_text.Font = Enum.Font.GothamMedium
		tut_text.TextSize = 13
		tut_text.TextXAlignment = 0
		tut_text.TextYAlignment = 0
		tut_text.TextWrapped = true

		tutb.MouseButton1Click:Connect(function()
			if collapsed then return end
			toggle_window(tut_container, not tut_container.Visible)
		end)

		local closeb = Instance.new("TextButton", h)
		closeb.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		closeb.Position = UDim2.new(1, -30, 0.5, -10)
		closeb.Size = UDim2.new(0, 20, 0, 20)
		closeb.Text = ""
		Instance.new("UICorner", closeb).CornerRadius = UDim.new(1, 0)

		-- Minimize runs in two stages: the body rolls up into the header, then
		-- the header folds left into a round pill holding just this button.
		-- Maximize is the inverse, and the order matters -- the header has to be
		-- back at full width before the body rolls down, or the content is laid
		-- out against a 44px frame and every label wraps.
		local im = false
		-- The stages are chained on Completed, so a second click mid-flight would
		-- start the opposite sequence while tweens from the first are still
		-- running and leave the panel stuck at an intermediate size.
		local anim_busy = false
		-- Where the body was scrolled to when the panel collapsed; nil when the
		-- panel is open and there is nothing banked. See roll_up.
		local saved_canvas = nil

		local ROLL, FOLD, UNFOLD = A.ROLL, A.FOLD, A.UNFOLD

		-- The header extras all vanish for the pill and come back with it.
		-- Transparency alone is not enough: a fully transparent TextButton still
		-- takes clicks, and once the panel is pill-width closeb's (1,-30) anchor
		-- lands on top of minb -- so a click meant to restore would tear the UI
		-- down instead. Visible is the only thing that removes them from
		-- hit-testing, but it cannot be driven off the fade alone: the fade runs
		-- 0.4s while the panel is already narrowing underneath it, and the
		-- unfold has to make them visible again up front so they can fade in.
		-- collapsed (declared above the header buttons) is the authority for
		-- hit-testing, flipped the instant the button is pressed.
		local extras = { dcb, tutb, closeb }
		local function set_header_extras(hidden)
			local a = hidden and 1 or 0
			-- Deliberately not UNFOLD on the way back. UNFOLD is Back/Out, and a
			-- transparency has nowhere to overshoot to: the curve drives the value
			-- below 0, Roblox clamps it, and the fade finishes early then sits
			-- frozen for the rest of the tween instead of easing in. The geometry
			-- below still gets UNFOLD -- that is where the spring belongs.
			local info = hidden and FOLD or A.OPEN
			v6:Create(t, info, { TextTransparency = a }):Play()
			for _, b in ipairs(extras) do
				if not hidden then
					b.Visible = true
				end
				local tw = v6:Create(b, info, {
					BackgroundTransparency = a,
					TextTransparency = a,
				})
				if hidden then
					local conn
					conn = tw.Completed:Connect(function()
						if conn then conn:Disconnect() end
						-- Not if a fast re-click already started fading them back.
						if collapsed then b.Visible = false end
					end)
				end
				tw:Play()
			end
		end

		local function fold_to_pill()
			set_header_extras(true)
			-- 0.5 is resolved against the width as it animates, so the button
			-- curves rather than sliding straight in. Endpoints are what matter.
			v6:Create(minb, FOLD, { Position = UDim2.new(0.5, -10, 0.5, -10) }):Play()
			-- h carries an absolute height, so it has to come down with the panel
			-- or minb's 0.5 anchor centres against 50px inside a 44px pill.
			v6:Create(h, FOLD, { Size = UDim2.new(1, 0, 0, PILL_SIZE) }):Play()
			v6:Create(mcorner, FOLD, { CornerRadius = UDim.new(0, PILL_SIZE / 2) }):Play()
			local tw = v6:Create(m, FOLD, { Size = UDim2.new(0, PILL_SIZE, 0, PILL_SIZE) })
			local conn
			conn = tw.Completed:Connect(function()
				anim_busy = false
				if conn then conn:Disconnect() end
			end)
			tw:Play()
		end

		local function roll_up()
			-- Clipped rather than hidden, so the body is cut off as the panel
			-- shrinks instead of vanishing a frame before the tween starts.
			m.ClipsDescendants = true
			-- The scroll offset has to be banked before the body shrinks. c is
			-- sized against m, so collapsing drives its height to zero, and a
			-- ScrollingFrame clamps CanvasPosition against its own window size --
			-- at zero height that clamp stops holding the offset anywhere sensible.
			-- Restoring from a stale value is what left the panel reopening onto
			-- the middle of the list, or past the end of it entirely, whenever it
			-- was minimized from anywhere but the very top.
			saved_canvas = c.CanvasPosition
			c.CanvasPosition = Vector2.new(0, 0)
			if am.Visible then toggle_window(am, false) end
			if km.Visible then toggle_window(km, false) end
			if tut_container.Visible then toggle_window(tut_container, false) end
			if x6.dlst_container and x6.dlst_container.Visible then
				toggle_window(x6.dlst_container, false, true)
			end
			if m:FindFirstChild("TargetListContainer") and m.TargetListContainer.Visible then
				toggle_window(m.TargetListContainer, false, true)
			end
			-- The AI chat is a sibling of the panel, not a child, and it stays up
			-- when the panel collapses: a long generation is worth watching while
			-- the panel is out of the way. The reset dialog still goes, since it is
			-- a modal belonging to a panel that is no longer on screen.
			if x6.reset_confirm then
				if x6.reset_confirm.Parent then
					x6.reset_confirm:Destroy()
				end
				x6.reset_confirm = nil
			end
			local tw = v6:Create(m, ROLL, { Size = UDim2.new(0, PANEL_W, 0, HEADER_H) })
			local conn
			conn = tw.Completed:Connect(function()
				if conn then conn:Disconnect() end
				-- The else is unreachable while anim_busy holds across both
				-- stages, but skipping stage 2 without clearing the guard would
				-- wedge the button dead with the panel stranded half-collapsed.
				if im then
					fold_to_pill()
				else
					anim_busy = false
				end
			end)
			tw:Play()
		end

		local function roll_down()
			local tw = v6:Create(m, ROLL, { Size = UDim2.new(0, PANEL_W, 0, PANEL_H) })
			local conn
			conn = tw.Completed:Connect(function()
				if conn then conn:Disconnect() end
				-- Only now: the nested mode selector and target list sit outside
				-- Main's bounds, so leaving this on would clip them away.
				m.ClipsDescendants = false
				-- Put the reader back where they left off, now that the body is at
				-- full height again and the clamp means something. Deferred to the
				-- end of the tween for the same reason.
				if saved_canvas then
					c.CanvasPosition = saved_canvas
					saved_canvas = nil
				end
				if ai_chat_module and ai_chat_module.showWidget then
					pcall(ai_chat_module.showWidget)
				end
				anim_busy = false
			end)
			tw:Play()
		end

		local function unfold_header()
			-- The pill is draggable, so it can be anywhere by now. Expanding from
			-- near an edge would put most of the panel off-screen.
			--
			-- Measured, not computed. Deriving the offset from ViewportSize is
			-- wrong twice over: sg does not set IgnoreGuiInset, so the parent is
			-- 36px shorter than the viewport, and the expanded panel is
			-- PANEL_* * app_scale() because UIScale grows m from its top-left.
			-- AbsolutePosition and AbsoluteSize are both post-scale and relative
			-- to the real parent, so they carry the inset and the scale already.
			local parent = m.Parent
			local avail = (parent and parent.AbsoluteSize) or Vector2.new(1280, 720)
			local scale = app_scale()
			local pw, ph = PANEL_W * scale, PANEL_H * scale
			local origin = (parent and parent.AbsolutePosition) or Vector2.new(0, 0)
			local ax = m.AbsolutePosition.X - origin.X
			local ay = m.AbsolutePosition.Y - origin.Y
			-- A panel taller than the screen cannot be fully fitted; pin it to the
			-- top edge rather than letting max() shove the header out of reach.
			local cx = math.max(10, math.min(ax, avail.X - pw - 10))
			local cy = math.max(10, math.min(ay, avail.Y - ph - 10))
			if avail.X - pw - 10 < 10 then cx = 10 end
			if avail.Y - ph - 10 < 10 then cy = 10 end
			-- Snapped, not tweened: UNFOLD is Back/Out, and overshoot on a
			-- correction meant to pull the panel on-screen would push it further
			-- off first. The move is hidden by the size tween starting alongside.
			if math.abs(cx - ax) > 0.5 or math.abs(cy - ay) > 0.5 then
				m.Position = UDim2.new(0, cx, 0, cy)
			end

			set_header_extras(false)
			v6:Create(minb, UNFOLD, { Position = UDim2.new(1, -60, 0.5, -10) }):Play()
			v6:Create(h, UNFOLD, { Size = UDim2.new(1, 0, 0, HEADER_H) }):Play()
			v6:Create(mcorner, UNFOLD, { CornerRadius = UDim.new(0, 10) }):Play()
			local tw = v6:Create(m, UNFOLD, { Size = UDim2.new(0, PANEL_W, 0, HEADER_H) })
			local conn
			conn = tw.Completed:Connect(function()
				if conn then conn:Disconnect() end
				-- As in roll_up: unreachable today, but skipping stage 2 here
				-- would also strand ClipsDescendants on, and that is the one
				-- thing that hides the mode selector on an expanded panel.
				if not im then
					roll_down()
				else
					m.ClipsDescendants = false
					anim_busy = false
				end
			end)
			tw:Play()
		end

		minb.MouseButton1Click:Connect(function()
			if anim_busy then return end
			anim_busy = true
			im = not im
			-- Set before any tween starts: the extras overlap minb for the whole
			-- fold, and this is what makes their handlers ignore the press.
			collapsed = im
			if im then
				roll_up()
			else
				unfold_header()
			end
		end)

		closeb.MouseButton1Click:Connect(function()
			-- Invisible on the pill but still hit-testable, and stacked over minb.
			if collapsed then return end
			RestoreAllPerf()
			if context.x4 and context.x4.f5 then
				context.x4.f5()
			end
			if sg.Parent then sg:Destroy() end
		end)
		
		pcall(function()
			sg.Destroying:Connect(function()
				RestoreAllPerf()
				if x5.g == sg then x5.g = nil end
				if x6.sg == sg then x6.sg = nil end
			end)
		end)

		-- The body lives entirely inside f1, so without this the panel comes up
		-- holding only the header buttons and the mode dropdown: no toggles, no
		-- target selector, no shape controls, no reset. It used to fill in only
		-- once something called x5.st() a second time -- recenter or stop -- which
		-- read as the panel being half-built until the first keypress.
		f1()
	end

	return x5
end
