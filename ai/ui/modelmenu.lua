-- Model picker: the header button plus its dropdown.
return function(env)
	local v6 = env.v6
	local kit = env.require("ui/kit")
	local st = env.require("state")
	local COL = kit.COL

	local DROP_W = 108
	local ROW_H = 20
	local ROW_STEP = 22

	local M = {}

	function M.new(window, header, onModelChanged)
		local button = kit.textButton(header, {
			text = st.session.model .. " v",
			color = COL.label,
			size = 8,
			bg = COL.raised,
			pos = UDim2.new(0, 60, 0.5, -9),
			dim = UDim2.new(0, 68, 0, 18),
			radius = 4,
			stroke = COL.strokeSoft
		})

		local drop = Instance.new("Frame", window)
		drop.Position = UDim2.new(0, 58, 0, 30)
		drop.Size = UDim2.new(0, DROP_W, 0, 0)
		drop.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
		drop.ClipsDescendants = true
		drop.ZIndex = 30
		drop.Visible = false
		kit.corner(drop, 5)
		kit.stroke(drop, Color3.fromRGB(45, 45, 54))

		local layout = Instance.new("UIListLayout", drop)
		layout.Padding = UDim.new(0, 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder

		local pad = Instance.new("UIPadding", drop)
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.PaddingLeft = UDim.new(0, 3)
		pad.PaddingRight = UDim.new(0, 3)

		local open = false

		local function collapse()
			open = false
			v6:Create(drop, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, DROP_W, 0, 0) }):Play()
			task.delay(0.15, function() if not open then drop.Visible = false end end)
		end

		local function refresh()
			for _, ch in ipairs(drop:GetChildren()) do
				if ch:IsA("TextButton") then ch:Destroy() end
			end
			for _, modelName in ipairs(st.MODELS) do
				local isSel = modelName == st.session.model
				local optBtn = kit.textButton(drop, {
					text = modelName,
					color = isSel and COL.text or Color3.fromRGB(150, 150, 160),
					size = 8,
					bg = isSel and Color3.fromRGB(38, 38, 48) or Color3.fromRGB(25, 25, 30),
					dim = UDim2.new(1, 0, 0, ROW_H),
					radius = 3
				})
				optBtn.BackgroundTransparency = isSel and 0 or 1
				optBtn.ZIndex = 31

				optBtn.MouseEnter:Connect(function()
					if modelName ~= st.session.model then
						v6:Create(optBtn, TweenInfo.new(0.1), { BackgroundTransparency = 0, BackgroundColor3 = COL.btn, TextColor3 = Color3.fromRGB(220, 220, 230) }):Play()
					end
				end)
				optBtn.MouseLeave:Connect(function()
					if modelName ~= st.session.model then
						v6:Create(optBtn, TweenInfo.new(0.1), { BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(150, 150, 160) }):Play()
					end
				end)

				optBtn.MouseButton1Click:Connect(function()
					st.session.model = modelName
					button.Text = modelName .. " v"
					-- Rewrite the system message in place so the running session's
					-- claimed model matches the one now selected.
					if #st.session.history > 0 and st.session.history[1].role == "system" then
						st.session.history[1].content = st.systemContent()
					end
					st.save()
					collapse()
					if onModelChanged then onModelChanged(modelName) end
				end)
			end
		end

		kit.hover(button,
			{ BackgroundColor3 = Color3.fromRGB(32, 32, 38), TextColor3 = Color3.fromRGB(220, 220, 240) },
			{ BackgroundColor3 = COL.raised, TextColor3 = COL.label })

		button.MouseButton1Click:Connect(function()
			if open then
				collapse()
				return
			end
			open = true
			refresh()
			drop.Visible = true
			v6:Create(drop, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, DROP_W, 0, #st.MODELS * ROW_STEP + 6)
			}):Play()
		end)

		return button
	end

	return M
end
