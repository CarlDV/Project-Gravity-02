-- The "AI chat is free" gate. status.txt (local copy first, then the repo) flips
-- this, which both skips the auth wall and shows the one-off notice.
return function(env)
	local net = env.require("net")

	local raw
	if type(readfile) == "function" and type(isfile) == "function" then
		local ok_f, val_f = pcall(isfile, "status.txt")
		if ok_f and val_f then
			local ok_r, val_r = pcall(readfile, "status.txt")
			if ok_r and val_r then raw = val_r end
		end
	end
	if not raw then
		local ok_net, res_net = pcall(net.request, "https://raw.githubusercontent.com/CarlDV/Project-Gravity-02/main/status.txt", "GET")
		if ok_net and res_net and res_net.StatusCode == 200 then
			raw = res_net.Body
		end
	end

	local active = false
	if type(raw) == "string" then
		local clean = raw:match("^%s*(.-)%s*$")
		if clean and clean:lower() == "true" then
			active = true
		end
	end

	local M = { active = active }

	function M.notify()
		if not active then return end
		local v6, v8 = env.v6, env.v8
		task.spawn(function()
			local pg = (gethui and gethui()) or (syn and syn.protect_gui and game:GetService("CoreGui")) or (v8 and v8:FindFirstChild("PlayerGui"))
			if not pg then return end
			local sg = Instance.new("ScreenGui")
			sg.Name = "G_Notif_" .. math.random(100, 999)
			sg.DisplayOrder = 9999
			if syn and syn.protect_gui and pg == game:GetService("CoreGui") then
				syn.protect_gui(sg)
			end
			sg.Parent = pg

			local card = Instance.new("CanvasGroup", sg)
			card.Size = UDim2.new(0, 210, 0, 42)
			card.Position = UDim2.new(0.5, -105, 0, -50)
			card.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
			card.GroupTransparency = 1
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

			local stroke = Instance.new("UIStroke", card)
			stroke.Color = Color3.fromRGB(45, 45, 52)
			stroke.Thickness = 1

			local titleLbl = Instance.new("TextLabel", card)
			titleLbl.Position = UDim2.new(0, 10, 0, 6)
			titleLbl.Size = UDim2.new(1, -20, 0, 14)
			titleLbl.BackgroundTransparency = 1
			titleLbl.Text = "PROJECT GRAVITY"
			titleLbl.TextColor3 = Color3.fromRGB(0, 230, 180)
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.TextSize = 9
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left

			local msgLbl = Instance.new("TextLabel", card)
			msgLbl.Position = UDim2.new(0, 10, 0, 20)
			msgLbl.Size = UDim2.new(1, -20, 0, 16)
			msgLbl.BackgroundTransparency = 1
			msgLbl.Text = "AI Chat is free until further notice."
			msgLbl.TextColor3 = Color3.fromRGB(220, 220, 230)
			msgLbl.Font = Enum.Font.GothamMedium
			msgLbl.TextSize = 10
			msgLbl.TextXAlignment = Enum.TextXAlignment.Left

			v6:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, -105, 0, 16),
				GroupTransparency = 0
			}):Play()

			task.wait(4)

			local tw = v6:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -105, 0, -50),
				GroupTransparency = 1
			})
			tw.Completed:Connect(function()
				sg:Destroy()
			end)
			tw:Play()
		end)
	end

	return M
end
