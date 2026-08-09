-- Shared look and behaviour for the AI windows: palette, small instance
-- factories, open/close animation, and the title-bar drag.
return function(env)
	local v1, v6 = env.v1, env.v6

	local M = {}

	M.COL = {
		bg = Color3.fromRGB(12, 12, 15),
		panel = Color3.fromRGB(18, 18, 22),
		field = Color3.fromRGB(20, 20, 25),
		raised = Color3.fromRGB(24, 24, 28),
		btn = Color3.fromRGB(30, 30, 36),
		btnHover = Color3.fromRGB(40, 40, 48),
		stroke = Color3.fromRGB(45, 45, 52),
		strokeSoft = Color3.fromRGB(38, 38, 44),
		strokeBtn = Color3.fromRGB(50, 50, 58),
		text = Color3.fromRGB(255, 255, 255),
		dim = Color3.fromRGB(140, 140, 150),
		muted = Color3.fromRGB(110, 110, 120),
		label = Color3.fromRGB(150, 150, 165),
		accent = Color3.fromRGB(0, 230, 190),
		danger = Color3.fromRGB(255, 100, 100),
		-- Same teal as accent, dropped in value so it can sit behind text or as a
		-- hairline without pulling the eye off the message itself.
		accentDim = Color3.fromRGB(0, 150, 128),
		-- Bubble fills. These lived as literals in transcript.lua, which put half
		-- the panel's colour outside the palette; the values are unchanged.
		bubbleUser = Color3.fromRGB(35, 35, 42),
		bubbleAi = Color3.fromRGB(25, 25, 30),
		bubbleSys = Color3.fromRGB(19, 19, 24),
		bodyText = Color3.fromRGB(240, 240, 240),
		dangerBg = Color3.fromRGB(150, 40, 40),
		dangerStroke = Color3.fromRGB(180, 50, 50)
	}

	function M.corner(inst, radius)
		Instance.new("UICorner", inst).CornerRadius = UDim.new(0, radius)
		return inst
	end

	function M.stroke(inst, color, thickness)
		local s = Instance.new("UIStroke", inst)
		s.Color = color or M.COL.strokeSoft
		if thickness then s.Thickness = thickness end
		return s
	end

	-- Hover tint that reverts on leave. Returns nothing; purely decorative.
	function M.hover(inst, props, restore)
		inst.MouseEnter:Connect(function()
			v6:Create(inst, TweenInfo.new(0.15), props):Play()
		end)
		inst.MouseLeave:Connect(function()
			v6:Create(inst, TweenInfo.new(0.15), restore):Play()
		end)
	end

	function M.textButton(parent, opts)
		local b = Instance.new("TextButton", parent)
		b.Text = opts.text or ""
		b.TextColor3 = opts.color or M.COL.text
		b.Font = opts.font or Enum.Font.GothamMedium
		b.TextSize = opts.size or 9
		if opts.pos then b.Position = opts.pos end
		if opts.dim then b.Size = opts.dim end
		if opts.bg then
			b.BackgroundColor3 = opts.bg
		else
			b.BackgroundTransparency = 1
		end
		if opts.radius then M.corner(b, opts.radius) end
		if opts.stroke then M.stroke(b, opts.stroke) end
		return b
	end

	function M.label(parent, opts)
		local l = Instance.new("TextLabel", parent)
		l.BackgroundTransparency = 1
		l.Text = opts.text or ""
		l.TextColor3 = opts.color or M.COL.text
		l.Font = opts.font or Enum.Font.Gotham
		l.TextSize = opts.size or 9
		l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
		if opts.pos then l.Position = opts.pos end
		if opts.dim then l.Size = opts.dim end
		return l
	end

	function M.textBox(parent, opts)
		local t = Instance.new("TextBox", parent)
		t.BackgroundColor3 = M.COL.field
		t.PlaceholderText = opts.placeholder or ""
		t.PlaceholderColor3 = M.COL.muted
		t.Text = opts.text or ""
		t.TextColor3 = M.COL.text
		t.Font = Enum.Font.Gotham
		t.TextSize = opts.size or 9
		if opts.pos then t.Position = opts.pos end
		if opts.dim then t.Size = opts.dim end
		M.corner(t, opts.radius or 5)
		M.stroke(t)
		return t
	end

	function M.window(parent, opts)
		local w = Instance.new("CanvasGroup", parent)
		w.Name = opts.name
		w.Size = opts.dim
		w.Position = UDim2.new(0.5, 0, 0.5, 0)
		w.AnchorPoint = Vector2.new(0.5, 0.5)
		w.BackgroundColor3 = M.COL.bg
		w.Active = true
		w.GroupTransparency = 1
		M.corner(w, opts.radius or 8)
		M.stroke(w, M.COL.stroke, 1)
		local limit = Instance.new("UISizeConstraint", w)
		limit.MinSize = opts.minSize
		limit.MaxSize = opts.maxSize
		return w
	end

	function M.animate(win, state)
		local scale = win:FindFirstChild("UIScale")
		if not scale then
			scale = Instance.new("UIScale", win)
			scale.Scale = 0.8
		end
		if state then
			win.Visible = true
			v6:Create(win, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
			v6:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			local tw = v6:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { GroupTransparency = 1 })
			v6:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.8 }):Play()
			local conn
			conn = tw.Completed:Connect(function()
				if win.GroupTransparency >= 0.99 then win.Visible = false end
				if conn then conn:Disconnect() end
			end)
			tw:Play()
		end
	end

	-- Reasoning models tend to open their reply with blank lines, and removing a
	-- ```lua fence leaves the newline that followed it. Both survive into a
	-- wrapped, auto-sized label as empty rows above the text, so the result is
	-- trimmed at both ends and runs of blank lines are collapsed to one.
	function M.stripMarkdown(str)
		if type(str) ~= "string" then return "" end
		local out = str:gsub("```%w*", ""):gsub("```", ""):gsub("`", ""):gsub("%*%*", "")
		out = out:gsub("\r\n", "\n"):gsub("\r", "\n")
		-- Headings can appear on any line once fences are gone, not just line one.
		out = out:gsub("^#+%s*", ""):gsub("\n#+%s*", "\n")
		out = out:gsub("[ \t]+\n", "\n"):gsub("\n\n\n+", "\n\n")
		return (out:match("^%s*(.-)%s*$"))
	end

	-- Replaces the deprecated Frame.Draggable on this module's windows. Draggable
	-- treats the entire surface as a drag handle, which on the chat panel meant the
	-- transcript could not be dragged to scroll and the prompt box could not be
	-- swiped to select -- both gestures moved the window instead. Binding the drag
	-- to the title bar hands those gestures back.
	--
	-- The delta goes onto Position's offset unchanged: a UIScale scales a window's
	-- size and its descendants, not its Position, which resolves against the parent
	-- ScreenGui in plain screen pixels. The scale components of Position are kept,
	-- which matters here because these windows are centred with AnchorPoint 0.5 and
	-- a (0.5, 0.5) scale -- flattening that would jump them by half a screen on the
	-- first drag.
	--
	-- Returns a was_dragged() probe. The floating widget is a TextButton that both
	-- drags and clicks, and Roblox fires MouseButton1Click on release even after a
	-- drag, so without this every reposition would also toggle the chat open.
	local DRAG_SLOP = 6
	function M.draggable(win, handle)
		handle = handle or win
		handle.Active = true

		local dragging, moved = false, false
		local origin, start_pos

		handle.InputBegan:Connect(function(input)
			local ty = input.UserInputType
			if ty ~= Enum.UserInputType.MouseButton1 and ty ~= Enum.UserInputType.Touch then
				return
			end
			dragging, moved = true, false
			origin = input.Position
			start_pos = win.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if conn then
						conn:Disconnect()
					end
				end
			end)
		end)

		v1.InputChanged:Connect(function(input)
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
			local delta = input.Position - origin
			-- A few pixels of travel is a shaky click, not a drag.
			if math.abs(delta.X) > DRAG_SLOP or math.abs(delta.Y) > DRAG_SLOP then
				moved = true
			end
			local avail = parent.AbsoluteSize
			local size = win.AbsoluteSize
			-- AnchorPoint shifts where Position lands, so the on-screen edges are
			-- offset by it. Folding it in here keeps the clamp honest for both the
			-- centred windows and the top-left anchored widget.
			local anchor = win.AnchorPoint
			local want_x = start_pos.X.Scale * avail.X + start_pos.X.Offset + delta.X
			local want_y = start_pos.Y.Scale * avail.Y + start_pos.Y.Offset + delta.Y
			local keep = math.min(30, size.X, size.Y)
			local min_x = keep - size.X * (1 - anchor.X)
			local max_x = avail.X - keep + size.X * anchor.X
			local min_y = size.Y * anchor.Y
			local max_y = avail.Y - keep + size.Y * anchor.Y
			win.Position = UDim2.new(
				start_pos.X.Scale,
				math.clamp(want_x, math.min(min_x, max_x), math.max(min_x, max_x)) - start_pos.X.Scale * avail.X,
				start_pos.Y.Scale,
				math.clamp(want_y, math.min(min_y, max_y), math.max(min_y, max_y)) - start_pos.Y.Scale * avail.Y
			)
		end)

		return function()
			return moved
		end
	end

	return M
end
