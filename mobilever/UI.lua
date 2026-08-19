return function(context)
	local v1, v2, v3, v4, v5, v6, v7, v8, v9 = context.v1, context.v2, context.v3, context.v4, context.v5, context.v6, context.v7, context.v8, context.v9
	local x1, x2, x6, x9 = context.x1, context.x2, context.x6, context.x9
	local favorites, save_favs, save_settings = context.favorites, context.save_favs, context.save_settings
	local get_shape = context.get_shape
	local load_module = context.load_module
	local reset_config = context.reset_config
	local SUB_DIR = context.SUB_DIR or "mobilever/"
	-- Shared motion vocabulary from main.lua; see the ANIM table there for why
	-- each curve is what it is. Fallback keeps this module loadable standalone.
	-- Touch has no hover state, so HOVER here only ever drives the pressed tint.
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
	local UI_elements_builder = load_module(SUB_DIR .. "UI_elements.lua")
	if not UI_elements_builder then
		error("Failed to load UI_elements", 0)
	end
	local UI_elements = UI_elements_builder(context)
	-- The AI chat is optional: the call sites below already nil-guard it. Calling
	-- load_module's result directly meant a nil threw here first, so one flaky
	-- fetch for the chat took the whole panel down.
	local ai_chat_builder = load_module("ai_chat.lua")
	local ai_chat_module = ai_chat_builder and ai_chat_builder(context)
	local es, et, eb, eh = UI_elements.s, UI_elements.t, UI_elements.b, UI_elements.h
	local etb = UI_elements.tb

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
		-- 40/-50 pair was really HEADER_H + gap, written out by hand.
		-- Smaller than desktop throughout: this panel is 180x250 with a 26px
		-- header and 14px buttons, so the pill is sized to the touch target
		-- rather than to desktop's 44.
		local PANEL_W = 180
		local PANEL_H = 250
		local HEADER_H = 26
		local PILL_SIZE = 34
		local CONTENT_GAP = 14

		-- Roblox honours one UIScale per GuiObject, so the open/close pop and the
		-- user's UI Scale setting have to share it. Every scalable window is
		-- registered here and its scale is always (pop factor * app scale):
		-- toggle_window used to tween the single UIScale straight to 1, which
		-- threw the saved scale away and left the shape selector, target list and
		-- tutorial completely unaffected by the UI Scale slider.
		-- Weak keys, because registration outlives the window. The reset-confirm
		-- dialog is registered on open and Destroy()ed on dismiss -- each one used
		-- to leave a strong reference to a dead Instance behind here. Nothing swept
		-- them: the only prune is the win.Parent check inside apply_ui_scale, which
		-- runs only when the scale setting changes, so the table grew for the whole
		-- session and pinned every corpse it held. A window that is still parented
		-- is kept alive by its parent, so weak keys drop exactly the dead ones.
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
		-- cannot snap a closed window to full size.
		local function register_window(win, pop)
			local scale = win:FindFirstChild("UIScale")
			if not scale then
				scale = Instance.new("UIScale", win)
			end
			pop = pop or 1
			scale.Scale = pop * app_scale()
			scaled_windows[win] = { scale = scale, pop = pop }
			return scale
		end

		local function set_pop(win, pop, tween_info)
			local entry = scaled_windows[win]
			if not entry then
				register_window(win, pop)
				entry = scaled_windows[win]
			end
			entry.pop = pop
			local target = pop * app_scale()
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
					v6:Create(entry.scale, A.RESCALE, { Scale = entry.pop * s }):Play()
				else
					scaled_windows[win] = nil
				end
			end
		end
		x5.apply_ui_scale = apply_ui_scale

		local function toggle_window(win, state)
			if not scaled_windows[win] then
				register_window(win, win.Visible and 1 or 0.8)
			end
			local prop = win:IsA("CanvasGroup") and "GroupTransparency" or "BackgroundTransparency"
			if state then
				win.Visible = true
				v6:Create(win, A.OPEN, {[prop] = 0}):Play()
				set_pop(win, 1, A.OPEN_POP)
			else
				local tw = v6:Create(win, A.CLOSE, {[prop] = 1})
				set_pop(win, 0.8, A.CLOSE_POP)
				local conn
				conn = tw.Completed:Connect(function() 
					if win.Parent and win[prop] >= 0.99 then win.Visible = false end 
					if conn then conn:Disconnect() end
				end)
				tw:Play()
			end
		end

		-- Replaces the deprecated Frame.Draggable, which was set on the window itself
		-- and so treated the whole surface as a drag handle. On a touch screen that
		-- took the one gesture the body needs: dragging the settings list scrolled
		-- nothing and slid the panel instead. Binding the handle to the title bar
		-- gives the ScrollingFrame its gesture back.
		--
		-- The delta goes onto Position's offset unchanged. A UIScale on the window
		-- scales its size and its descendants, not its Position, which still
		-- resolves against the parent ScreenGui in plain screen pixels -- so the
		-- offset stays 1:1 with the finger at any UI Scale. Position's scale
		-- components are preserved rather than flattened, so a window anchored to
		-- the viewport centre still tracks a rotation or resize.
		local KEEP_ON_SCREEN = 28
		local function make_draggable(win, handle)
			handle = handle or win
			handle.Active = true

			local dragging = false
			local origin, start_pos

			table.insert(x6.c, handle.InputBegan:Connect(function(input)
				local ty = input.UserInputType
				if ty ~= Enum.UserInputType.MouseButton1 and ty ~= Enum.UserInputType.Touch then
					return
				end
				dragging = true
				origin = input.Position
				start_pos = win.Position
				-- Latched off the input itself: a touch that ends outside the handle
				-- still ends this input, and without it the panel would stay stuck to
				-- the next finger that came down.
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
				local parent = win.Parent
				if not parent then
					dragging = false
					return
				end
				local avail = parent.AbsoluteSize
				local size = win.AbsoluteSize
				local delta = input.Position - origin
				local want_x = start_pos.X.Scale * avail.X + start_pos.X.Offset + delta.X
				local want_y = start_pos.Y.Scale * avail.Y + start_pos.Y.Offset + delta.Y
				-- Leave a grabbable strip on screen. The vertical floor is 0: a title
				-- bar dragged above the top edge can never be picked up again.
				local max_x = avail.X - KEEP_ON_SCREEN
				local min_x = math.min(-(size.X - KEEP_ON_SCREEN), max_x)
				win.Position = UDim2.new(
					start_pos.X.Scale,
					math.clamp(want_x, min_x, max_x) - start_pos.X.Scale * avail.X,
					start_pos.Y.Scale,
					math.clamp(want_y, 0, math.max(0, avail.Y - KEEP_ON_SCREEN)) - start_pos.Y.Scale * avail.Y
				)
			end))
		end

		local hud = Instance.new("Frame", sg)
		hud.Name = "StatusHUD"
		hud.BackgroundTransparency = 1
		hud.Position = UDim2.new(0.5, -150, 0, 10)
		hud.Size = UDim2.new(0, 300, 0, 30)

		-- Scaled like every other element; the HUD was the one thing left out.
		register_window(hud, 1)

		local hud_l = Instance.new("TextLabel", hud)
		hud_l.BackgroundTransparency = 1
		hud_l.Size = UDim2.new(1, 0, 1, 0)
		hud_l.Font = Enum.Font.GothamBold
		hud_l.TextSize = 9
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
				-- x1.Targets, not x1.Tgt: multi-targeting replaced the single slot
				-- and nothing has written Tgt since, so this read "NONE" even with
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
		m.Position = UDim2.new(0.5, -110, 0.5, -160)
		m.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
		m.Active = true
		-- Held onto: the collapse tweens the radius out to a full circle.
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
		-- Also the whole surface of the collapsed pill, so the pill stays draggable
		-- without a second code path.
		make_draggable(m, h)

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
		c.Position = UDim2.new(0, 0, 0, HEADER_H + CONTENT_GAP)
		c.Size = UDim2.new(1, 0, 1, -(HEADER_H + CONTENT_GAP + 10))
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
		Instance.new("UICorner", am).CornerRadius = UDim.new(0, 10)
		local ams = Instance.new("UIStroke", am)
		ams.Color = Color3.fromRGB(40, 40, 45)
		ams.Thickness = 1

		-- Advanced is toggled with plain Visible (no pop animation), so it sits
		-- at full pop but still follows the app scale.
		register_window(am, 1)

		local ah = Instance.new("Frame", am)
		ah.BackgroundTransparency = 1
		ah.Size = UDim2.new(1, 0, 0, 26)
		make_draggable(am, ah)
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
			-- Every registered window, not just Main and Advanced: the shape
			-- selector, target list, tutorial and dialogs are siblings here and
			-- would otherwise be left at the old scale.
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

		if setfpscap then
			es(ac, "FPS Cap (0=Unc)", 0, 144, x1.FPSCap or 60, function(v)
				x1.FPSCap = v
				setfpscap(v)
				save_settings()
			end, true, "Caps your max FPS. 0 means uncapped.")
		end
		
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

		-- Each channel slider rebuilds the whole colour, so it has to hand the
		-- other two back as the same integers they came in as. Color3 stores 0-1
		-- floats and v/255 does not round-trip exactly, so the bare product
		-- re-quantised the untouched channels on every drag.
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

		local ab = eb(c, "Advanced Settings", function()
			am.Visible = not am.Visible
		end)
		ab.Size = UDim2.new(1, 0, 0, 20)

		local ai_btn = eb(c, "PROJECT GRAVITY AI", function()
			if ai_chat_module and ai_chat_module.toggle then
				ai_chat_module.toggle(sg)
			end
		end)
		ai_btn.Size = UDim2.new(1, 0, 0, 20)

		local dcb = eb(c, "Join Discord Server", function()
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
		dcb.Size = UDim2.new(1, 0, 0, 20)

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


			et(gsc, "Show HUD", x1.ShowHUD ~= false, function(v)
				x1.ShowHUD = v
				if hud then hud.Visible = v end
				save_settings()
			end)

			et(gsc, "Anchor to Self", x1.AnchorSelf, function(v)
				x1.AnchorSelf = v
				if v then
					x1.PI_All = false
					table.clear(x1.Targets)
					x1.TgtActive = false
					if x5.up then x5.up() end
				end
				save_settings()
			end)

			-- The writer for a flag this tree only ever read. SimpleMode round-trips
			-- through the shared settings file, so turning it on from desktop hid
			-- Anti-Fling, Force Smooth, Realistic Liftoff, Target Everyone and the
			-- whole per-shape control block here with no way to turn it back off --
			-- a full RESET ALL SETTINGS was the only escape. Left outside the
			-- SimpleMode gate below on purpose: a toggle you cannot reach is the bug.
			et(gsc, "Simplified Interface", x1.SimpleMode, function(v)
				x1.SimpleMode = v
				save_settings()
				f1()
			end, "Hides the advanced toggles and the per-shape controls.")

			-- The touch stand-in for holding Shift in the sculptor. Read by
			-- System_sculptor on this tree and written nowhere, so tapping could never
			-- deselect a part or add to a selection.
			et(gsc, "Sculptor · Add on Tap", x1.SculptorMultiSelect == true, function(v)
				x1.SculptorMultiSelect = v
				save_settings()
			end, "Tapping adds to the selection instead of replacing it.")

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
				if x6.dock_disable_btn then
					x6.dock_disable_btn.BackgroundColor3 = v and Color3.fromRGB(100, 255, 100)
						or Color3.fromRGB(60, 60, 60)
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
						if x5.up then x5.up() end
					end
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
			-- == true, not the bare value: Visible rejects nil, and an unset
			-- SlingshotManual made this nil whenever Slingshot was the live shape,
			-- which threw here and abandoned the rest of f1.
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
							-- branches already do, or a Toggle whose key is missing
							-- from config.lua draws ON from its Default while the
							-- shape reads nil and behaves OFF.
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
		reset_btn.Size = UDim2.new(1, 0, 0, 24)
		reset_btn.Text = "⚠ RESET ALL SETTINGS"
		reset_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		reset_btn.Font = Enum.Font.GothamBold
		reset_btn.TextSize = 9
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
				confirm.Position = UDim2.new(0.5, -100, 0.5, -60)
				confirm.Size = UDim2.new(0, 200, 0, 120)
				confirm.GroupTransparency = 1
				confirm.ZIndex = 100
				Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 12)
				local confirm_stroke = Instance.new("UIStroke", confirm)
				confirm_stroke.Color = Color3.fromRGB(120, 40, 40)
				confirm_stroke.Thickness = 1
				local warning_icon = Instance.new("TextLabel", confirm)
				warning_icon.Position = UDim2.new(0.5, -10, 0, 10)
				warning_icon.Size = UDim2.new(0, 20, 0, 20)
				warning_icon.Text = "⚠"
				warning_icon.TextColor3 = Color3.fromRGB(255, 100, 100)
				warning_icon.TextSize = 16
				warning_icon.ZIndex = 101

				local confirm_title = Instance.new("TextLabel", confirm)
				confirm_title.BackgroundTransparency = 1
				confirm_title.Position = UDim2.new(0, 10, 0, 35)
				confirm_title.Size = UDim2.new(1, -20, 0, 20)
				confirm_title.Text = "RESET ALL SETTINGS?"
				confirm_title.TextColor3 = Color3.fromRGB(255, 255, 255)
				confirm_title.Font = Enum.Font.GothamBold
				confirm_title.TextSize = 10
				confirm_title.ZIndex = 101

				local confirm_desc = Instance.new("TextLabel", confirm)
				confirm_desc.BackgroundTransparency = 1
				confirm_desc.Position = UDim2.new(0, 10, 0, 55)
				confirm_desc.Size = UDim2.new(1, -20, 0, 30)
				confirm_desc.Text = "This will reset all settings to default. This cannot be undone."
				confirm_desc.TextColor3 = Color3.fromRGB(150, 150, 160)
				confirm_desc.Font = Enum.Font.Gotham
				confirm_desc.TextSize = 8
				confirm_desc.TextWrapped = true
				confirm_desc.ZIndex = 101

				local cancel_btn = Instance.new("TextButton", confirm)
				cancel_btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
				cancel_btn.Position = UDim2.new(0, 10, 1, -30)
				cancel_btn.Size = UDim2.new(0.5, -15, 0, 20)
				cancel_btn.Text = "CANCEL"
				cancel_btn.TextColor3 = Color3.fromRGB(200, 200, 210)
				cancel_btn.Font = Enum.Font.GothamBold
				cancel_btn.TextSize = 8
				cancel_btn.AutoButtonColor = false
				cancel_btn.ZIndex = 101
				Instance.new("UICorner", cancel_btn).CornerRadius = UDim.new(0, 4)

				local confirm_reset_btn = Instance.new("TextButton", confirm)
				confirm_reset_btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
				confirm_reset_btn.Position = UDim2.new(0.5, 5, 1, -30)
				confirm_reset_btn.Size = UDim2.new(0.5, -15, 0, 20)
				confirm_reset_btn.Text = "RESET"
				confirm_reset_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				confirm_reset_btn.Font = Enum.Font.GothamBold
				confirm_reset_btn.TextSize = 8
				confirm_reset_btn.AutoButtonColor = false
				confirm_reset_btn.ZIndex = 101
				Instance.new("UICorner", confirm_reset_btn).CornerRadius = UDim.new(0, 4)
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
						-- UIScale is part of the reset and only takes effect when
						-- every window is rescaled, or the panel keeps the old
						-- value until the next launch.
						apply_ui_scale()
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
				-- because a UIScale grows a frame from its top-left corner.
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

		local dlst_container = Instance.new("CanvasGroup", sg)
		dlst_container.Name = "ModeSelector"
		dlst_container.Visible = false
		dlst_container.GroupTransparency = 1
		dlst_container.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		dlst_container.Position = UDim2.new(0.5, 90, 0.5, -160)
		dlst_container.Size = UDim2.new(0, 180, 0, 250)
		dlst_container.Active = true
		Instance.new("UICorner", dlst_container).CornerRadius = UDim.new(0, 10)
		local dls = Instance.new("UIStroke", dlst_container)
		dls.Color = Color3.fromRGB(40, 40, 45)

		-- Starts hidden, so it starts at the closed pop factor.
		register_window(dlst_container, 0.8)

		local top_dlst = Instance.new("Frame", dlst_container)
		top_dlst.BackgroundTransparency = 1
		top_dlst.Size = UDim2.new(1, 0, 0, 30)
		top_dlst.ZIndex = 11
		-- The Back button sits inside this bar and consumes its own input, so it
		-- still clicks rather than starting a drag.
		make_draggable(dlst_container, top_dlst)

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
				return a < b
			end)

			for _, mn in ipairs(modes) do
				-- Plain search: without the flag the typed text is a Lua pattern, so a
				-- single "(" throws out of the Text callback after ClearAllChildren
				-- has already run, leaving the list permanently empty.
				if filter ~= "" and not mn:lower():find(filter:lower(), 1, true) then
					continue
				end

				local f = Instance.new("Frame", dlst)
				f.Size = UDim2.new(1, -16, 0, 24)
				f.BackgroundColor3 = mn == x1.k6 and Color3.fromRGB(40, 40, 180) or Color3.fromRGB(25, 25, 30)
				f.ZIndex = 12
				Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)

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
						-- This tree has no switch_shape at all, so the testing notice has
						-- to live here. context.x8 is populated after this module is built
						-- (main.lua:565) but long before any click, so it resolves at call
						-- time rather than at build time.
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
		x6.tdlst_container = tdlst
		Instance.new("UICorner", tdlst).CornerRadius = UDim.new(0, 10)
		local ts = Instance.new("UIStroke", tdlst)
		ts.Color = Color3.fromRGB(40, 40, 45)

		register_window(tdlst, 0.8)

		local top_tdlst = Instance.new("Frame", tdlst)
		top_tdlst.BackgroundTransparency = 1
		top_tdlst.Size = UDim2.new(1, 0, 0, 30)
		top_tdlst.ZIndex = 11
		make_draggable(tdlst, top_tdlst)

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
				if filter_text ~= "" and not (pl.DisplayName:lower():find(filter_text:lower(), 1, true) or pl.Name:lower():find(filter_text:lower(), 1, true)) then
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
					-- See the desktop copy: cleared first so a fast move between rows
					-- cannot orphan the previous highlight, and parented to the row so
					-- the list teardown takes it along. f1() Destroy()s this list on
					-- click and a Destroy fires no MouseLeave.
					clear_highlight()
					if pl.Character then
						local h = Instance.new("Highlight")
						h.FillColor = Color3.fromRGB(255, 255, 255)
						h.OutlineColor = Color3.fromRGB(255, 255, 255)
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
					if x5.up then x5.up() end
				end)
			end
		end
		x6.update_targets = update_targets

		target_search:GetPropertyChangedSignal("Text"):Connect(function()
			update_targets(target_search.Text)
		end)

		-- Declared ahead of the header buttons because their tap handlers close
		-- over it: while the panel is a pill every extra is invisible but still
		-- hit-testable, and stacked on top of minb. See set_header_extras below.
		local collapsed = false

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
		Instance.new("UICorner", tut_container).CornerRadius = UDim.new(0, 10)
		local tuls = Instance.new("UIStroke", tut_container)
		tuls.Color = Color3.fromRGB(40, 40, 45)

		register_window(tut_container, 0.8)

		local tut_header = Instance.new("Frame", tut_container)
		tut_header.BackgroundTransparency = 1
		tut_header.Size = UDim2.new(1, 0, 0, 30)
		make_draggable(tut_container, tut_header)
		
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
		tut_text.Text = "• Core Controls: Tap 'PLC' to reposition the gravitational center. Tap 'CLN' to wipe active parts.\n\n• Targeting: Use 'Select Target' to focus gravity onto a specific player.\n\n• Elevation: Use 'UP' and 'DWN' buttons to manually adjust the vertical height of the formation.\n\n• System: Tap 'PAU' to instantly pause physics. Tap 'DIS' to disable the system.\n\n• Modes: Select modes to seamlessly morph between geometry.\n\n• Config: Scroll down the main menu to tune the shape config. Open 'Advanced Settings' for global physics."
		tut_text.TextColor3 = Color3.fromRGB(200, 200, 205)
		tut_text.Font = Enum.Font.GothamMedium
		tut_text.TextSize = 9
		tut_text.TextXAlignment = 0
		tut_text.TextYAlignment = 0
		tut_text.TextWrapped = true

		tutb.MouseButton1Click:Connect(function()
			if collapsed then return end
			toggle_window(tut_container, not tut_container.Visible)
		end)

		local closeb = Instance.new("TextButton", h)
		closeb.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		closeb.Position = UDim2.new(1, -22, 0.5, -7)
		closeb.Size = UDim2.new(0, 14, 0, 14)
		closeb.Text = ""
		Instance.new("UICorner", closeb).CornerRadius = UDim.new(1, 0)

		-- Minimize runs in two stages: the body rolls up into the header, then
		-- the header folds left into a round pill holding just this button.
		-- Maximize is the inverse, and the order matters -- the header has to be
		-- back at full width before the body rolls down, or the content is laid
		-- out against a 34px frame and every label wraps.
		local im = false
		-- Scroll offset held across a collapse, since the body's height goes to
		-- zero in between and the live value stops being meaningful.
		local saved_canvas = nil
		-- The stages are chained on Completed, so a second tap mid-flight would
		-- start the opposite sequence while tweens from the first are still
		-- running and leave the panel stuck at an intermediate size.
		local anim_busy = false

		local ROLL, FOLD, UNFOLD = A.ROLL, A.FOLD, A.UNFOLD

		-- collapsed (declared above the header buttons) is the authority for
		-- hit-testing, flipped the instant the button is pressed. Transparency
		-- alone would not do: a fully transparent TextButton still takes taps,
		-- and once the panel is pill-width closeb's (1,-22) anchor lands on top
		-- of minb, so a tap meant to restore would tear the UI down instead.
		local extras = { tutb, closeb }
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
						-- Not if a fast re-tap already started fading them back.
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
			v6:Create(minb, FOLD, { Position = UDim2.new(0.5, -7, 0.5, -7) }):Play()
			-- h carries an absolute height, so it has to come down with the panel
			-- or minb's 0.5 anchor centres against 26px inside a 34px pill.
			v6:Create(h, FOLD, { Size = UDim2.new(1, 0, 0, PILL_SIZE) }):Play()
			v6:Create(mcorner, FOLD, { CornerRadius = UDim.new(0, PILL_SIZE / 2) }):Play()
			local tw = v6:Create(m, FOLD, { Size = UDim2.new(0, PILL_SIZE, 0, PILL_SIZE) })
			local conn
			conn = tw.Completed:Connect(function()
				if conn then conn:Disconnect() end
				anim_busy = false
			end)
			tw:Play()
		end

		local function roll_up()
			-- Clipped rather than hidden, so the body is cut off as the panel
			-- shrinks instead of vanishing a frame before the tween starts.
			m.ClipsDescendants = true
			-- Banked before the body shrinks. c is sized against m, so collapsing
			-- drives its height to zero, and a ScrollingFrame clamps CanvasPosition
			-- against its own window size -- at zero height that clamp no longer
			-- holds the offset anywhere sensible. Restoring from the stale value is
			-- what reopened the panel onto the middle of the list, or past the end
			-- of it, whenever it was minimized from anywhere but the very top.
			saved_canvas = c.CanvasPosition
			c.CanvasPosition = Vector2.new(0, 0)
			am.Visible = false
			if tut_container.Visible then toggle_window(tut_container, false) end
			if x6.dlst_container and x6.dlst_container.Visible then
				toggle_window(x6.dlst_container, false)
			end
			if x6.tdlst_container and x6.tdlst_container.Visible then
				toggle_window(x6.tdlst_container, false)
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
				if im then fold_to_pill() else anim_busy = false end
			end)
			tw:Play()
		end

		local function roll_down()
			local tw = v6:Create(m, ROLL, { Size = UDim2.new(0, PANEL_W, 0, PANEL_H) })
			local conn
			conn = tw.Completed:Connect(function()
				if conn then conn:Disconnect() end
				m.ClipsDescendants = false
				-- Put the reader back where they left off, now that the body is at
				-- full height and the clamp means something again.
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
			-- shorter than the viewport by the topbar, and the expanded panel is
			-- PANEL_* * app_scale() because UIScale grows m from its top-left.
			-- AbsolutePosition and AbsoluteSize are both post-scale and relative
			-- to the real parent, so they carry the inset and the scale already.
			local parent = m.Parent
			local avail = (parent and parent.AbsoluteSize) or Vector2.new(720, 1280)
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
			v6:Create(minb, UNFOLD, { Position = UDim2.new(1, -44, 0.5, -7) }):Play()
			v6:Create(h, UNFOLD, { Size = UDim2.new(1, 0, 0, HEADER_H) }):Play()
			v6:Create(mcorner, UNFOLD, { CornerRadius = UDim.new(0, 10) }):Play()
			local tw = v6:Create(m, UNFOLD, { Size = UDim2.new(0, PANEL_W, 0, HEADER_H) })
			local conn
			conn = tw.Completed:Connect(function()
				if conn then conn:Disconnect() end
				if not im then roll_down() else anim_busy = false end
			end)
			tw:Play()
		end

		minb.MouseButton1Click:Connect(function()
			if anim_busy then return end
			anim_busy = true
			im = not im
			-- Set before any tween starts: the extras overlap minb for the whole
			-- fold, and this is what makes their handlers ignore the tap.
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
		-- the settings panel is rebuilt on every f1(), so the toggle there reaches
		-- the dock through x6 rather than an upvalue that would go stale
		x6.dock_disable_btn = btn_dis
		if x1.Disabled then
			btn_dis.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		end

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
			-- same single entry point as the settings toggle and the hotkey
			if context.x4 and context.x4.apply_disabled then
				context.x4.apply_disabled(not x1.Disabled)
			else
				x1.Disabled = not x1.Disabled
			end
			btn_dis.BackgroundColor3 = x1.Disabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(60, 60, 60)
			if save_settings then
				save_settings()
			end
		end)

		f1()
	end

	return x5
end
