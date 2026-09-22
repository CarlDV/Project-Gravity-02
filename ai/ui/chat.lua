-- Chat panel: header controls wired to the transcript and composer.
return function(env)
	local kit = env.require("ui/kit")
	local st = env.require("state")
	local COL = kit.COL
	local SZ = kit.SZ

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
			dim = UDim2.new(0, SZ.chatW, 0, SZ.chatH),
			minSize = Vector2.new(SZ.chatMinW, SZ.chatMinH),
			maxSize = Vector2.new(SZ.chatMaxW, SZ.chatMaxH)
		})

		local header = Instance.new("Frame", window)
		header.Size = UDim2.new(1, 0, 0, SZ.headerH)
		header.BackgroundColor3 = COL.panel
		kit.draggable(window, header)

		local headerLine = Instance.new("Frame", header)
		headerLine.Position = UDim2.new(0, 0, 1, -1)
		headerLine.Size = UDim2.new(1, 0, 0, 1)
		headerLine.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		headerLine.BorderSizePixel = 0

		kit.label(header, {
			text = "PROJECT UAI",
			font = Enum.Font.GothamMedium,
			size = SZ.titleSize,
			pos = UDim2.new(0, SZ.titlePad, 0, 0),
			dim = UDim2.new(0, SZ.titleW, 1, 0)
		})

		-- Free mode's model is the server's to pick, so the picker only appears
		-- for API-key sessions where the choice actually reaches the upstream.
		local showModelMenu = st.session.mode ~= "free"
		if showModelMenu then
			env.require("ui/modelmenu").new(window, header)
		end

		-- Every header control used to be pinned to its own fixed x offset, so the
		-- status text was handed "1,-260" -- about 40px on the default 300px window,
		-- and negative at the 240px minimum, where Logout landed on top of Clear.
		-- The right-hand cluster is a right-anchored row now: it spaces its own
		-- controls, so growing one of them for desktop cannot leave it sitting on
		-- top of the next, and status takes the gap genuinely left over.
		local cluster = Instance.new("Frame", header)
		cluster.AnchorPoint = Vector2.new(1, 0.5)
		cluster.Position = UDim2.new(1, -SZ.headerPad, 0.5, 0)
		cluster.Size = UDim2.new(0, 0, 0, SZ.ctrlH)
		cluster.AutomaticSize = Enum.AutomaticSize.X
		cluster.BackgroundTransparency = 1

		local clusterRow = Instance.new("UIListLayout", cluster)
		clusterRow.FillDirection = Enum.FillDirection.Horizontal
		clusterRow.VerticalAlignment = Enum.VerticalAlignment.Center
		clusterRow.SortOrder = Enum.SortOrder.LayoutOrder
		clusterRow.Padding = UDim.new(0, SZ.headerGap)

		-- Where the status text may start and stop. The left bound clears the title,
		-- plus the model picker when it is shown; the right bound is the cluster's
		-- own width, which AutomaticSize resolves to exactly this sum.
		local HEADER_LEFT = SZ.modelX + (showModelMenu and (SZ.modelW + SZ.headerGap) or 0)
		local HEADER_RIGHT = SZ.headerPad + SZ.statusGap
			+ SZ.clearW + SZ.logoutW + SZ.iconW * 2 + SZ.headerGap * 3

		local statusLbl = kit.label(header, {
			text = "ready",
			color = COL.muted,
			size = SZ.statusSize,
			pos = UDim2.new(0, HEADER_LEFT, 0, 0),
			dim = UDim2.new(1, -(HEADER_LEFT + HEADER_RIGHT), 1, 0),
			align = Enum.TextXAlignment.Right
		})
		statusLbl.TextTruncate = Enum.TextTruncate.AtEnd

		local feed = env.require("ui/transcript").new(window)
		env.require("ui/composer").new(window, feed, statusLbl)

		local clrBtn = kit.textButton(cluster, {
			text = "Clear",
			color = COL.label,
			size = SZ.ctrlSize,
			bg = COL.raised,
			dim = UDim2.new(0, SZ.clearW, 0, SZ.ctrlH),
			radius = 4,
			stroke = COL.strokeSoft
		})
		clrBtn.LayoutOrder = 1
		kit.hover(clrBtn,
			{ BackgroundColor3 = Color3.fromRGB(32, 32, 38), TextColor3 = Color3.fromRGB(220, 220, 240) },
			{ BackgroundColor3 = COL.raised, TextColor3 = COL.label })
		clrBtn.MouseButton1Click:Connect(function()
			st.session.history = {}
			feed.clear()
			feed.addBubble("System", "Context cleared. AI ready.")
			statusLbl.Text = "ready"
		end)

		local logoutBtn = kit.textButton(cluster, {
			text = "Logout",
			color = COL.danger,
			size = SZ.ctrlSize,
			bg = Color3.fromRGB(25, 25, 30),
			dim = UDim2.new(0, SZ.logoutW, 0, SZ.ctrlH),
			radius = 4,
			stroke = Color3.fromRGB(45, 35, 35)
		})
		logoutBtn.LayoutOrder = 2
		-- Shared by the button and by an expired session: both have to drop the
		-- credentials, tear the panel down and hand back to the login window.
		local function logout()
			st.clearCredentials()
			if window then
				window:Destroy()
				window = nil
			end
			if onLogout then onLogout() end
		end

		logoutBtn.MouseButton1Click:Connect(logout)

		-- The agent loop cannot reach the UI, so it calls this after clearing a
		-- token the server rejected.
		env.require("agent").onSessionExpired = logout

		-- The dash reads small next to an X set at the same point size, so it takes
		-- two extra points -- the relationship these two carried as literals.
		local minBtn = kit.textButton(cluster, {
			text = "-",
			color = COL.dim,
			font = Enum.Font.GothamBold,
			size = SZ.titleSize + 2,
			dim = UDim2.new(0, SZ.iconW, 0, SZ.ctrlH)
		})
		minBtn.LayoutOrder = 3
		kit.hover(minBtn, { TextColor3 = COL.text }, { TextColor3 = COL.dim })
		minBtn.MouseButton1Click:Connect(function()
			kit.animate(window, false)
		end)

		local closeBtn = kit.textButton(cluster, {
			text = "X",
			color = COL.dim,
			font = Enum.Font.GothamBold,
			size = SZ.titleSize,
			dim = UDim2.new(0, SZ.iconW, 0, SZ.ctrlH)
		})
		closeBtn.LayoutOrder = 4
		kit.hover(closeBtn, { TextColor3 = COL.text }, { TextColor3 = COL.dim })
		closeBtn.MouseButton1Click:Connect(function()
			kit.animate(window, false)
		end)

		feed.addBubble("System", "AI Agent connected. Command physics or search.")

		kit.animate(window, true)
	end

	return M
end
