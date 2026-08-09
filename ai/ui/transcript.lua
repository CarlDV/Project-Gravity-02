-- Scrolling message feed and its bubbles.
return function(env)
	local kit = env.require("ui/kit")
	local COL = kit.COL

	local M = {}

	function M.new(parent)
		local scroll = Instance.new("ScrollingFrame", parent)
		scroll.Position = UDim2.new(0, 7, 0, 34)
		scroll.Size = UDim2.new(1, -14, 1, -68)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 2
		scroll.ScrollBarImageColor3 = COL.stroke
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

		local layout = Instance.new("UIListLayout", scroll)
		layout.Padding = UDim.new(0, 5)
		layout.SortOrder = Enum.SortOrder.LayoutOrder

		local feed = { frame = scroll }

		function feed.toBottom()
			scroll.CanvasPosition = Vector2.new(0, 9999)
		end

		function feed.clear()
			for _, item in ipairs(scroll:GetChildren()) do
				if item:IsA("Frame") then
					item:Destroy()
				end
			end
		end

		-- Returns the body label and the tag label so callers can stream text into
		-- the bubble and flag which tool is running.
		function feed.addBubble(sender, text)
			local isUser = sender == "You"
			local wrap = Instance.new("Frame", scroll)
			wrap.Size = UDim2.new(1, 0, 0, 0)
			wrap.AutomaticSize = Enum.AutomaticSize.Y
			wrap.BackgroundTransparency = 1

			local card = Instance.new("Frame", wrap)
			card.Size = UDim2.new(0, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.XY
			card.Position = isUser and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
			card.AnchorPoint = isUser and Vector2.new(1, 0) or Vector2.new(0, 0)
			card.BackgroundColor3 = isUser and Color3.fromRGB(35, 35, 42) or Color3.fromRGB(25, 25, 30)
			kit.corner(card, 6)

			local maxC = Instance.new("UISizeConstraint", card)
			maxC.MaxSize = Vector2.new(220, 9999)

			local pad = Instance.new("UIPadding", card)
			pad.PaddingTop = UDim.new(0, 5)
			pad.PaddingBottom = UDim.new(0, 5)
			pad.PaddingLeft = UDim.new(0, 8)
			pad.PaddingRight = UDim.new(0, 8)

			local list = Instance.new("UIListLayout", card)
			list.Padding = UDim.new(0, 2)

			local tag = kit.label(card, { color = Color3.fromRGB(0, 255, 200), font = Enum.Font.GothamMedium })
			tag.Size = UDim2.new(0, 0, 0, 0)
			tag.AutomaticSize = Enum.AutomaticSize.XY
			tag.Visible = false

			local body = kit.label(card, { text = text, color = Color3.fromRGB(240, 240, 240), size = 11 })
			body.Size = UDim2.new(0, 0, 0, 0)
			body.AutomaticSize = Enum.AutomaticSize.XY
			body.TextWrapped = true

			feed.toBottom()
			return body, tag
		end

		return feed
	end

	return M
end
