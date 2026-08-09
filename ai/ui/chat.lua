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

		-- Free mode's model is the server's to pick, so the picker only appears
		-- for API-key sessions where the choice actually reaches the upstream.
		local showModelMenu = st.session.mode ~= "free"
		if showModelMenu then
			env.require("ui/modelmenu").new(window, header)
		end

		-- Where the status text may start and stop. The left bound clears the
		-- title, plus the model picker when it is shown; the right bound covers
		-- the Clear / Logout / minimise / close cluster.
		local HEADER_LEFT = showModelMenu and 132 or 58
		local HEADER_RIGHT = 128

		-- Every header control used to be pinned to a fixed x offset, so the status
		-- text was handed "1,-260" -- about 40px on the default 300px window, and
		-- negative at the 240px minimum, where Logout landed on top of Clear. The
		-- right-hand cluster is now right-anchored and status takes the gap that
		-- is genuinely left over, so it stays readable at every allowed width.
		local statusLbl = kit.label(header, {
			text = "ready",
			color = COL.muted,
			size = 8,
			pos = UDim2.new(0, HEADER_LEFT, 0, 0),
			dim = UDim2.new(1, -(HEADER_LEFT + HEADER_RIGHT), 1, 0),
			align = Enum.TextXAlignment.Right
		})
		statusLbl.TextTruncate = Enum.TextTruncate.AtEnd

		local feed = env.require("ui/transcript").new(window)
		env.require("ui/composer").new(window, feed, statusLbl)

		local clrBtn = kit.textButton(header, {
			text = "Clear",
			color = COL.label,
			size = 8,
			bg = COL.raised,
			pos = UDim2.new(1, -124, 0.5, -9),
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
