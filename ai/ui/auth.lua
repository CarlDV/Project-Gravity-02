-- Auth modal: API key tab and server login tab.
return function(env)
	local hs = env.hs
	local kit = env.require("ui/kit")
	local net = env.require("net")
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

	function M.open(parentGui, onAuthenticated)
		if window then
			kit.animate(window, true)
			return
		end

		window = kit.window(parentGui, {
			name = "AI_Auth_Modal",
			dim = UDim2.new(0, SZ.authW, 0, SZ.authH),
			radius = 10,
			minSize = Vector2.new(SZ.authMinW, SZ.authMinH),
			maxSize = Vector2.new(SZ.authMaxW, SZ.authMaxH)
		})

		local header = Instance.new("Frame", window)
		header.Size = UDim2.new(1, 0, 0, SZ.authHeaderH)
		header.BackgroundTransparency = 1
		kit.draggable(window, header)

		kit.label(header, {
			text = "PROJECT GRAVITY AI",
			font = Enum.Font.GothamBlack,
			size = SZ.authTitleSize,
			pos = UDim2.new(0, SZ.authPad + 2, 0, 0),
			dim = UDim2.new(1, -(SZ.authPad * 2 + SZ.authIconW), 1, 0)
		})

		local closeBtn = kit.textButton(header, {
			text = "X",
			color = COL.dim,
			font = Enum.Font.GothamBold,
			size = SZ.authTitleSize + 2,
			pos = UDim2.new(1, -(SZ.authIconW + SZ.headerPad), 0.5, -(SZ.authIconW / 2)),
			dim = UDim2.new(0, SZ.authIconW, 0, SZ.authIconW)
		})
		kit.hover(closeBtn, { TextColor3 = COL.text }, { TextColor3 = COL.dim })
		closeBtn.MouseButton1Click:Connect(function()
			kit.animate(window, false)
		end)

		local tabRow = Instance.new("Frame", window)
		tabRow.Position = UDim2.new(0, SZ.authPad, 0, SZ.authHeaderH)
		tabRow.Size = UDim2.new(1, -SZ.authPad * 2, 0, SZ.authTabH)
		tabRow.BackgroundColor3 = COL.panel
		kit.corner(tabRow, 6)

		local btnKey = kit.textButton(tabRow, {
			text = "API Key",
			size = SZ.authTabSize,
			bg = COL.btn,
			dim = UDim2.new(0.5, 0, 1, 0),
			radius = 6
		})

		local btnServer = kit.textButton(tabRow, {
			text = "Server Login",
			color = COL.dim,
			size = SZ.authTabSize,
			pos = UDim2.new(0.5, 0, 0, 0),
			dim = UDim2.new(0.5, 0, 1, 0),
			radius = 6
		})

		-- Both tabs are one vertical stack, so their rows are laid out instead of
		-- each carrying a hand-computed y. That drift is what left the two tabs on
		-- different field heights (26 against 24) and three different row gaps, and
		-- it is what a taller desktop modal would otherwise have to re-derive.
		local bodyTop = SZ.authHeaderH + SZ.authTabH + SZ.authGap
		local function bodyFrame()
			local f = Instance.new("Frame", window)
			f.Position = UDim2.new(0, SZ.authPad, 0, bodyTop)
			f.Size = UDim2.new(1, -SZ.authPad * 2, 1, -(bodyTop + SZ.authGap))
			f.BackgroundTransparency = 1
			local stack = Instance.new("UIListLayout", f)
			stack.SortOrder = Enum.SortOrder.LayoutOrder
			stack.Padding = UDim.new(0, SZ.authGap)
			Instance.new("UIPadding", f).PaddingTop = UDim.new(0, SZ.authTopPad)
			return f
		end

		local bodyKey = bodyFrame()

		local refBtn = kit.textButton(bodyKey, {
			text = "GET API KEY (AGENTROUTER)",
			color = COL.accent,
			size = SZ.authRefSize,
			bg = COL.field,
			dim = UDim2.new(1, 0, 0, SZ.authRefH),
			radius = 5,
			stroke = COL.strokeSoft
		})
		refBtn.LayoutOrder = 1
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
			size = SZ.authFieldSize,
			dim = UDim2.new(1, 0, 0, SZ.authFieldH)
		})
		keyInput.LayoutOrder = 2

		local saveKeyBtn = kit.textButton(bodyKey, {
			text = "SAVE API KEY",
			size = SZ.authBtnSize,
			bg = COL.btn,
			dim = UDim2.new(1, 0, 0, SZ.authBtnH),
			radius = 5,
			stroke = COL.strokeBtn
		})
		saveKeyBtn.LayoutOrder = 3
		kit.hover(saveKeyBtn, { BackgroundColor3 = COL.btnHover }, { BackgroundColor3 = COL.btn })

		local bodyServer = bodyFrame()
		bodyServer.Visible = false

		local userInput = kit.textBox(bodyServer, {
			placeholder = "Username",
			size = SZ.authFieldSize,
			dim = UDim2.new(1, 0, 0, SZ.authFieldH)
		})
		userInput.LayoutOrder = 1

		local passInput = kit.textBox(bodyServer, {
			placeholder = "Password",
			size = SZ.authFieldSize,
			dim = UDim2.new(1, 0, 0, SZ.authFieldH)
		})
		passInput.LayoutOrder = 2

		local errLbl = kit.label(bodyServer, {
			color = Color3.fromRGB(255, 90, 90),
			size = SZ.authErrSize,
			dim = UDim2.new(1, 0, 0, SZ.authErrH)
		})
		errLbl.LayoutOrder = 3

		local loginBtn = kit.textButton(bodyServer, {
			text = "LOGIN TO SERVER",
			size = SZ.authBtnSize,
			bg = COL.btn,
			dim = UDim2.new(1, 0, 0, SZ.authBtnH),
			radius = 5,
			stroke = COL.strokeBtn
		})
		loginBtn.LayoutOrder = 4
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
