-- Shared by local imports, both panels and the AI shape writer.
local M = {}

function M.defaults(controls, into)
	local values = into or {}
	for _, control in ipairs(controls or {}) do
		if type(control) == "table" and control.Key and control.Type ~= "Button" then
			local value = control.Default
			if value == nil then
				if control.Type == "Toggle" then
					value = false
				elseif control.Type == "TextBox" then
					value = ""
				else
					value = (control.Min or 0) / (control.Div or 1)
				end
			end
			if values[control.Key] == nil then values[control.Key] = value end
		end
	end
	return values
end

-- Buttons are actions, not saved settings. Never run a callback at build time.
-- The guard also prevents a yielding callback being started twice by a double tap.
function M.activate(control, c, x6, x1)
	if x6.torn_down then return false, "Session has ended" end
	if control.Type ~= "Button" or type(control.Callback) ~= "function" then
		return false, "Button needs a Callback(c, x6, x1) function"
	end
	x6.button_busy = x6.button_busy or setmetatable({}, { __mode = "k" })
	if x6.button_busy[control] then return false, "Action is already running" end
	x6.button_busy[control] = true
	local ok, err = pcall(control.Callback, c, x6, x1)
	x6.button_busy[control] = nil
	return ok, err
end

return M
