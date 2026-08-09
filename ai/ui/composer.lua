-- Prompt box, send/stop button, and the streaming of a reply into the feed.
return function(env)
	local kit = env.require("ui/kit")
	local COL = kit.COL

	local TYPE_STEPS = 30
	local TYPE_DELAY = 0.015

	local M = {}

	function M.new(window, feed, statusLbl)
		local agent = env.require("agent")

		local footer = Instance.new("Frame", window)
		footer.Position = UDim2.new(0, 7, 1, -30)
		footer.Size = UDim2.new(1, -14, 0, 24)
		footer.BackgroundColor3 = COL.field
		kit.corner(footer, 5)
		kit.stroke(footer)

		local inputTxt = Instance.new("TextBox", footer)
		inputTxt.Position = UDim2.new(0, 6, 0, 0)
		inputTxt.Size = UDim2.new(1, -44, 1, 0)
		inputTxt.BackgroundTransparency = 1
		inputTxt.PlaceholderText = "Ask AI or command engine..."
		inputTxt.PlaceholderColor3 = COL.muted
		inputTxt.Text = ""
		inputTxt.TextColor3 = COL.text
		inputTxt.Font = Enum.Font.Gotham
		inputTxt.TextSize = 10
		inputTxt.ClearTextOnFocus = false

		local sendBtn = kit.textButton(footer, {
			text = "GO",
			bg = COL.btn,
			pos = UDim2.new(1, -36, 0.5, -9),
			dim = UDim2.new(0, 32, 0, 18),
			radius = 4
		})
		local sendStroke = kit.stroke(sendBtn, COL.strokeBtn)

		local isBusy = false
		local abort = false

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
			sendBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
			sendStroke.Color = Color3.fromRGB(180, 50, 50)

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

				local len = #resText
				local step = math.max(1, math.floor(len / TYPE_STEPS))
				for idx = 1, len, step do
					if abort then break end
					aiLbl.Text = resText:sub(1, idx)
					feed.toBottom()
					task.wait(TYPE_DELAY)
				end
				if not abort then
					aiLbl.Text = resText
					feed.toBottom()
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
