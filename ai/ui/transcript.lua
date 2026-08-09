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
		layout.Padding = UDim.new(0, 7)
		layout.SortOrder = Enum.SortOrder.LayoutOrder

		-- Keeps the last bubble off the composer and the first off the header.
		local scrollPad = Instance.new("UIPadding", scroll)
		scrollPad.PaddingTop = UDim.new(0, 2)
		scrollPad.PaddingBottom = UDim.new(0, 4)

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
			local isSys = sender == "System"

			local wrap = Instance.new("Frame", scroll)
			wrap.Size = UDim2.new(1, 0, 0, 0)
			wrap.AutomaticSize = Enum.AutomaticSize.Y
			wrap.BackgroundTransparency = 1

			local card = Instance.new("Frame", wrap)
			card.Size = UDim2.new(0, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.XY
			card.Position = isUser and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
			card.AnchorPoint = isUser and Vector2.new(1, 0) or Vector2.new(0, 0)
			card.BackgroundColor3 = isUser and COL.bubbleUser or (isSys and COL.bubbleSys or COL.bubbleAi)
			kit.corner(card, 7)
			-- The AI and system fills sit close to the panel behind them, so a
			-- hairline is what actually separates a bubble from the background.
			kit.stroke(card, isUser and COL.stroke or COL.strokeSoft)

			-- A bubble that reaches the far wall reads as a wall of text, and the
			-- lack of a gutter was most of why the feed looked cramped. Leaving
			-- roughly a fifth of the width empty is what makes the two sides read
			-- as a conversation rather than one column.
			local maxC = Instance.new("UISizeConstraint", card)
			maxC.MaxSize = Vector2.new(isSys and 240 or 214, 9999)

			local pad = Instance.new("UIPadding", card)
			pad.PaddingTop = UDim.new(0, 6)
			pad.PaddingBottom = UDim.new(0, 6)
			pad.PaddingLeft = UDim.new(0, 9)
			pad.PaddingRight = UDim.new(0, 9)

			local list = Instance.new("UIListLayout", card)
			list.Padding = UDim.new(0, 3)
			list.SortOrder = Enum.SortOrder.LayoutOrder

			local tag = kit.label(card, { color = COL.accent, font = Enum.Font.GothamBold, size = 8 })
			tag.Size = UDim2.new(0, 0, 0, 0)
			tag.AutomaticSize = Enum.AutomaticSize.XY
			tag.LayoutOrder = 1
			tag.Visible = false

			local body = kit.label(card, {
				text = text,
				color = isSys and COL.dim or COL.bodyText,
				size = 11
			})
			body.Size = UDim2.new(0, 0, 0, 0)
			body.AutomaticSize = Enum.AutomaticSize.XY
			body.TextWrapped = true
			body.LayoutOrder = 2
			body.LineHeight = 1.12

			feed.toBottom()
			return body, tag
		end

		return feed
	end

	return M
end
