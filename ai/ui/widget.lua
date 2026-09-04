-- Draggable circular AI button that toggles the chat.
return function(env)
	local kit = env.require("ui/kit")
	local COL = kit.COL
	local SZ = kit.SZ

	local M = {}
	local widget

	function M.ensure(parentGui, onClick)
		if widget and widget.Parent then return widget end
		widget = kit.textButton(parentGui, {
			text = "AI",
			font = Enum.Font.GothamBold,
			size = SZ.widgetSize,
			bg = COL.bg,
			pos = UDim2.new(1, -(SZ.widgetD + SZ.widgetGap), 0.5, -(SZ.widgetD / 2)),
			dim = UDim2.new(0, SZ.widgetD, 0, SZ.widgetD)
		})
		widget.Name = "AI_Circle_Toggle"
		widget.Active = true
		widget.ZIndex = 100
		Instance.new("UICorner", widget).CornerRadius = UDim.new(0.5, 0)
		kit.stroke(widget, COL.stroke, 1)

		-- Handle is the widget itself: it is one round grab target with nothing
		-- inside it to conflict with, so the whole surface should drag.
		local wasDragged = kit.draggable(widget, widget)

		widget.MouseButton1Click:Connect(function()
			-- Release after a drag still fires a click, which would open the chat
			-- every time the widget was moved out of the way.
			if wasDragged() then return end
			onClick()
		end)
		return widget
	end

	function M.setVisible(state)
		if widget then
			widget.Visible = state
		end
	end

	return M
end
