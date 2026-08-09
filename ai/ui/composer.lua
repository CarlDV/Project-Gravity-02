-- Prompt box, send/stop button, and the streaming of a reply into the feed.
return function(env)
	local kit = env.require("ui/kit")
	local COL = kit.COL
	local v6 = env.v6

	local TYPE_STEPS = 30
	local TYPE_DELAY = 0.015
	-- Replies at or under this many characters appear at once: a two-word answer
	-- does not need an animation.
	local TYPE_INSTANT = 40
	-- Hard ceiling on the reveal, in seconds. The text has already arrived, so
	-- any longer than this is the UI making the model look slower than it was.
	local TYPE_MAX = 0.35

	local M = {}

	function M.new(window, feed, statusLbl)
		local agent = env.require("agent")

		local footer = Instance.new("Frame", window)
		footer.Position = UDim2.new(0, 8, 1, -32)
		footer.Size = UDim2.new(1, -16, 0, 26)
		footer.BackgroundColor3 = COL.field
		kit.corner(footer, 6)
		local footerStroke = kit.stroke(footer)

		local inputTxt = Instance.new("TextBox", footer)
		inputTxt.Position = UDim2.new(0, 9, 0, 0)
		inputTxt.Size = UDim2.new(1, -50, 1, 0)
		inputTxt.BackgroundTransparency = 1
		inputTxt.PlaceholderText = "Ask AI or command engine..."
		inputTxt.PlaceholderColor3 = COL.muted
		inputTxt.Text = ""
		inputTxt.TextColor3 = COL.text
		inputTxt.Font = Enum.Font.Gotham
		inputTxt.TextSize = 10
		inputTxt.ClearTextOnFocus = false
		inputTxt.TextXAlignment = Enum.TextXAlignment.Left
		inputTxt.ClipsDescendants = true

		-- The prompt box gave no sign it had focus, so on a dark panel it was easy
		-- to type into nothing. The border picks up the accent instead.
		inputTxt.Focused:Connect(function()
			v6:Create(footerStroke, TweenInfo.new(0.15), { Color = COL.accentDim }):Play()
		end)
		inputTxt.FocusLost:Connect(function()
			v6:Create(footerStroke, TweenInfo.new(0.15), { Color = COL.strokeSoft }):Play()
		end)

		local sendBtn = kit.textButton(footer, {
			text = "GO",
			bg = COL.btn,
			font = Enum.Font.GothamBold,
			pos = UDim2.new(1, -38, 0.5, -9),
			dim = UDim2.new(0, 32, 0, 18),
			radius = 4
		})
		local sendStroke = kit.stroke(sendBtn, COL.strokeBtn)

		local isBusy = false
		local abort = false

		-- kit.hover tweens to fixed colours, which would repaint the red STOP
		-- state as the idle button on mouse-over. The hover has to know which
		-- state the button is in.
		sendBtn.MouseEnter:Connect(function()
			v6:Create(sendBtn, TweenInfo.new(0.15), {
				BackgroundColor3 = isBusy and COL.dangerStroke or COL.btnHover
			}):Play()
		end)
		sendBtn.MouseLeave:Connect(function()
			v6:Create(sendBtn, TweenInfo.new(0.15), {
				BackgroundColor3 = isBusy and COL.dangerBg or COL.btn
			}):Play()
		end)

		local function setIdle()
			isBusy = false
			sendBtn.Text = "GO"
			sendBtn.BackgroundColor3 = COL.btn
			sendStroke.Color = COL.strokeBtn
			statusLbl.Text = "ready"
		end

		local function send()
			if isBusy then
				abort = true
				setIdle()
				return
			end

			local prompt = inputTxt.Text:match("^%s*(.-)%s*$")
			if prompt == "" then return end

			inputTxt.Text = ""
			isBusy = true
			abort = false
			sendBtn.Text = "STOP"
			sendBtn.BackgroundColor3 = COL.dangerBg
			sendStroke.Color = COL.dangerStroke

			feed.addBubble("You", prompt)
			local aiLbl, tagLbl = feed.addBubble("AI", ".")

			task.spawn(function()
				local dots = 0
				while isBusy do
					dots = (dots % 3) + 1
					aiLbl.Text = string.rep(".", dots)
					task.wait(0.3)
				end
			end)

			task.spawn(function()
				local okRun, reply = pcall(agent.run, prompt, function(state)
					if not abort then
						statusLbl.Text = state:lower()
					end
				end, function(kind, val)
					if abort then return end
					if kind == "call" then
						tagLbl.Text = "[" .. tostring(val) .. "]"
						tagLbl.Visible = true
					elseif kind == "think" then
						tagLbl.Text = "[ thinking ]"
						tagLbl.Visible = true
					end
				end, function()
					return abort
				end)

				setIdle()
				tagLbl.Visible = false

				if abort then
					aiLbl.Text = "Generation stopped by user."
					feed.toBottom()
					return
				end

				local resText = okRun and tostring(reply or "Task complete.") or ("Error: " .. tostring(reply))
				resText = kit.stripMarkdown(resText)
				if resText:match("^%s*$") then
					resText = "Task complete."
				end

				-- The reply is already in hand by this point, so the reveal is pure
				-- theatre and must not become the slowest part of a turn. It is
				-- capped in wall time rather than step count: short answers land
				-- almost instantly, long ones still finish inside TYPE_MAX.
				local len = #resText
				if len <= TYPE_INSTANT then
					aiLbl.Text = resText
					feed.toBottom()
				else
					local steps = math.min(TYPE_STEPS, math.ceil(TYPE_MAX / TYPE_DELAY))
					local step = math.max(1, math.ceil(len / steps))
					for idx = step, len, step do
						if abort then break end
						aiLbl.Text = resText:sub(1, idx)
						feed.toBottom()
						task.wait(TYPE_DELAY)
					end
					if not abort then
						aiLbl.Text = resText
						feed.toBottom()
					end
				end
			end)
		end

		sendBtn.MouseButton1Click:Connect(send)
		inputTxt.FocusLost:Connect(function(enterPressed)
			if enterPressed then send() end
		end)

		return footer
	end

	return M
end
