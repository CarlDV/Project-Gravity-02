-- Chat panel: header controls wired to the transcript and composer.
return function(env)
	local kit = env.require("ui/kit")
	local st = env.require("state")
	local COL = kit.COL

	local M = {}
	local window

	function M.visible()
		return window and window.Visible
	end

	function M.hide()
		if window and window.Visible then
			kit.animate(window, false)
		end
	end

	function M.open(parentGui, onLogout)
		if window then
			kit.animate(window, not window.Visible)
			return
		end

		window = kit.window(parentGui, {
			name = "AI_Chat_Panel",
			dim = UDim2.new(0, 300, 0, 240),
			minSize = Vector2.new(240, 180),
			maxSize = Vector2.new(340, 270)
		})

		local header = Instance.new("Frame", window)
		header.Size = UDim2.new(1, 0, 0, 30)
		header.BackgroundColor3 = COL.panel
		kit.draggable(window, header)

		local headerLine = Instance.new("Frame", header)
		headerLine.Position = UDim2.new(0, 0, 1, -1)
		headerLine.Size = UDim2.new(1, 0, 0, 1)
		headerLine.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		headerLine.BorderSizePixel = 0

		kit.label(header, {
			text = "PG/AI",
			font = Enum.Font.GothamMedium,
			size = 11,
			pos = UDim2.new(0, 6, 0, 0),
			dim = UDim2.new(0, 52, 1, 0)
		})

		env.require("ui/modelmenu").new(window, header)

		local statusLbl = kit.label(header, {
			text = "ready",
			color = COL.muted,
			pos = UDim2.new(0, 168, 0, 0),
			dim = UDim2.new(1, -260, 1, 0),
			align = Enum.TextXAlignment.Right
		})

		local feed = env.require("ui/transcript").new(window)
		env.require("ui/composer").new(window, feed, statusLbl)

		local clrBtn = kit.textButton(header, {
			text = "Clear",
			color = COL.label,
			size = 8,
			bg = COL.raised,
			pos = UDim2.new(0, 131, 0.5, -9),
			dim = UDim2.new(0, 34, 0, 18),
			radius = 4,
			stroke = COL.strokeSoft
		})
		kit.hover(clrBtn,
			{ BackgroundColor3 = Color3.fromRGB(32, 32, 38), TextColor3 = Color3.fromRGB(220, 220, 240) },
			{ BackgroundColor3 = COL.raised, TextColor3 = COL.label })
		clrBtn.MouseButton1Click:Connect(function()
			st.session.history = {}
			feed.clear()
			feed.addBubble("System", "Context cleared. AI ready.")
			statusLbl.Text = "ready"
		end)

		local logoutBtn = kit.textButton(header, {
			text = "Logout",
			color = COL.danger,
			size = 8,
			bg = Color3.fromRGB(25, 25, 30),
			pos = UDim2.new(1, -88, 0.5, -9),
			dim = UDim2.new(0, 42, 0, 18),
			radius = 4,
			stroke = Color3.fromRGB(45, 35, 35)
		})
		logoutBtn.MouseButton1Click:Connect(function()
			st.session.mode = ""
			st.session.token = ""
			st.session.apiKey = ""
			st.save()
			window:Destroy()
			window = nil
			if onLogout then onLogout() end
		end)

		local minBtn = kit.textButton(header, {
			text = "-",
			color = COL.dim,
			font = Enum.Font.GothamBold,
			size = 13,
			pos = UDim2.new(1, -42, 0, 6),
			dim = UDim2.new(0, 14, 0, 18)
		})
		kit.hover(minBtn, { TextColor3 = COL.text }, { TextColor3 = COL.dim })
		minBtn.MouseButton1Click:Connect(function()
			kit.animate(window, false)
		end)

		local closeBtn = kit.textButton(header, {
			text = "X",
			color = COL.dim,
			font = Enum.Font.GothamBold,
			size = 11,
			pos = UDim2.new(1, -20, 0, 6),
			dim = UDim2.new(0, 14, 0, 18)
		})
		kit.hover(closeBtn, { TextColor3 = COL.text }, { TextColor3 = COL.dim })
		closeBtn.MouseButton1Click:Connect(function()
			kit.animate(window, false)
		end)

		feed.addBubble("System", "AI Agent connected. Command physics or search.")

		kit.animate(window, true)
	end

	return M
end
