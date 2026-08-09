-- Auth modal: API key tab and server login tab.
return function(env)
	local hs = env.hs
	local kit = env.require("ui/kit")
	local net = env.require("net")
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

	function M.open(parentGui, onAuthenticated)
		if window then
			kit.animate(window, true)
			return
		end

		window = kit.window(parentGui, {
			name = "AI_Auth_Modal",
			dim = UDim2.new(0, 230, 0, 180),
			radius = 10,
			minSize = Vector2.new(200, 160),
			maxSize = Vector2.new(250, 200)
		})

		local header = Instance.new("Frame", window)
		header.Size = UDim2.new(1, 0, 0, 32)
		header.BackgroundTransparency = 1
		kit.draggable(window, header)

		kit.label(header, {
			text = "PROJECT GRAVITY AI",
			font = Enum.Font.GothamBlack,
			pos = UDim2.new(0, 12, 0, 0),
			dim = UDim2.new(1, -40, 1, 0)
		})

		local closeBtn = kit.textButton(header, {
			text = "X",
			color = COL.dim,
			font = Enum.Font.GothamBold,
			size = 11,
			pos = UDim2.new(1, -24, 0, 6),
			dim = UDim2.new(0, 18, 0, 18)
		})
		kit.hover(closeBtn, { TextColor3 = COL.text }, { TextColor3 = COL.dim })
		closeBtn.MouseButton1Click:Connect(function()
			kit.animate(window, false)
		end)

		local tabRow = Instance.new("Frame", window)
		tabRow.Position = UDim2.new(0, 10, 0, 32)
		tabRow.Size = UDim2.new(1, -20, 0, 24)
		tabRow.BackgroundColor3 = COL.panel
		kit.corner(tabRow, 6)

		local btnKey = kit.textButton(tabRow, {
			text = "API Key",
			bg = COL.btn,
			dim = UDim2.new(0.5, 0, 1, 0),
			radius = 6
		})

		local btnServer = kit.textButton(tabRow, {
			text = "Server Login",
			color = COL.dim,
			pos = UDim2.new(0.5, 0, 0, 0),
			dim = UDim2.new(0.5, 0, 1, 0),
			radius = 6
		})

		local bodyKey = Instance.new("Frame", window)
		bodyKey.Position = UDim2.new(0, 10, 0, 62)
		bodyKey.Size = UDim2.new(1, -20, 1, -68)
		bodyKey.BackgroundTransparency = 1

		local refBtn = kit.textButton(bodyKey, {
			text = "GET API KEY (AGENTROUTER)",
			color = COL.accent,
			size = 8,
			bg = COL.field,
			pos = UDim2.new(0, 0, 0, 4),
			dim = UDim2.new(1, 0, 0, 24),
			radius = 5,
			stroke = COL.strokeSoft
		})
		refBtn.MouseButton1Click:Connect(function()
			local clipFn = setclipboard or toclipboard or (syn and syn.write_clipboard)
			if clipFn then
				pcall(clipFn, st.REF_LINK)
				refBtn.Text = "LINK COPIED TO CLIPBOARD"
				task.delay(2, function() refBtn.Text = "GET API KEY (AGENTROUTER)" end)
			else
				refBtn.Text = st.REF_LINK
			end
		end)

		local keyInput = kit.textBox(bodyKey, {
			placeholder = "Paste API Key (sk-...)",
			text = st.session.apiKey,
			pos = UDim2.new(0, 0, 0, 34),
			dim = UDim2.new(1, 0, 0, 26)
		})

		local saveKeyBtn = kit.textButton(bodyKey, {
			text = "SAVE API KEY",
			bg = COL.btn,
			pos = UDim2.new(0, 0, 0, 66),
			dim = UDim2.new(1, 0, 0, 26),
			radius = 5,
			stroke = COL.strokeBtn
		})
		kit.hover(saveKeyBtn, { BackgroundColor3 = COL.btnHover }, { BackgroundColor3 = COL.btn })

		local bodyServer = Instance.new("Frame", window)
		bodyServer.Position = UDim2.new(0, 10, 0, 62)
		bodyServer.Size = UDim2.new(1, -20, 1, -68)
		bodyServer.BackgroundTransparency = 1
		bodyServer.Visible = false

		local userInput = kit.textBox(bodyServer, {
			placeholder = "Username",
			pos = UDim2.new(0, 0, 0, 4),
			dim = UDim2.new(1, 0, 0, 24)
		})

		local passInput = kit.textBox(bodyServer, {
			placeholder = "Password",
			pos = UDim2.new(0, 0, 0, 32),
			dim = UDim2.new(1, 0, 0, 24)
		})

		local errLbl = kit.label(bodyServer, {
			color = Color3.fromRGB(255, 90, 90),
			size = 8,
			pos = UDim2.new(0, 0, 0, 58),
			dim = UDim2.new(1, 0, 0, 12)
		})

		local loginBtn = kit.textButton(bodyServer, {
			text = "LOGIN TO SERVER",
			bg = COL.btn,
			pos = UDim2.new(0, 0, 0, 72),
			dim = UDim2.new(1, 0, 0, 26),
			radius = 5,
			stroke = COL.strokeBtn
		})
		kit.hover(loginBtn, { BackgroundColor3 = COL.btnHover }, { BackgroundColor3 = COL.btn })

		local function selectTab(showServer)
			btnServer.BackgroundColor3 = COL.btn
			btnKey.BackgroundColor3 = COL.btn
			btnServer.BackgroundTransparency = showServer and 0 or 1
			btnKey.BackgroundTransparency = showServer and 1 or 0
			btnServer.TextColor3 = showServer and COL.text or COL.dim
			btnKey.TextColor3 = showServer and COL.dim or COL.text
			bodyServer.Visible = showServer
			bodyKey.Visible = not showServer
		end

		btnServer.MouseButton1Click:Connect(function() selectTab(true) end)
		btnKey.MouseButton1Click:Connect(function() selectTab(false) end)

		local function finish()
			st.save()
			window:Destroy()
			window = nil
			if onAuthenticated then onAuthenticated() end
		end

		loginBtn.MouseButton1Click:Connect(function()
			local uText = userInput.Text:match("^%s*(.-)%s*$")
			local pText = passInput.Text:match("^%s*(.-)%s*$")
			if uText == "" or pText == "" then
				errLbl.Text = "Please enter username and password"
				return
			end
			errLbl.Text = "Logging in..."
			local body = hs:JSONEncode({ user = uText, pass = pText })
			local res = net.request("/api/login", "POST", { ["Content-Type"] = "application/json" }, body)
			if res and res.StatusCode == 200 then
				-- Capture the real session cookie when the transport exposes it:
				-- routes set to "Signed-in only" verify its HMAC. Roblox's
				-- HttpService filters Set-Cookie out of responses and executors
				-- differ, so a missing cookie is normal and must not fail a login
				-- the server already accepted -- an "Anyone" route needs no token.
				st.session.mode = "free"
				st.session.token = st.readSessionCookie(net.header(res, "Set-Cookie")) or ""
				finish()
			elseif res and res.StatusCode == 403 then
				errLbl.Text = "Login failed: account disabled"
			else
				errLbl.Text = "Login failed: Check credentials"
			end
		end)

		saveKeyBtn.MouseButton1Click:Connect(function()
			local kText = keyInput.Text:match("^%s*(.-)%s*$")
			if kText == "" then return end
			st.session.mode = "key"
			st.session.apiKey = kText
			finish()
		end)

		kit.animate(window, true)
	end

	return M
end
