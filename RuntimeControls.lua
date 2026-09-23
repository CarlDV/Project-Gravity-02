-- Native settings effects shared by the desktop/mobile panels and Project UAI.
-- Call apply_settings after changing x1; the values alone do not repaint the
-- interface, restore world visuals, change the FPS cap or update held collisions.
return function(context)
	local x1, x6 = context.x1, context.x6
	local M = { fps_cap = type(setfpscap) == "function" }

	function M.apply_settings(changed)
		assert(not x6.torn_down, "Gravity was unloaded")
		local ui, x4 = context.x5, context.x4
		if changed.FPSCap ~= nil then
			assert(M.fps_cap, "This executor does not support setfpscap")
			setfpscap(x1.FPSCap)
		end
		for key, apply in pairs(ui and ui.performance_effects or {}) do
			if changed[key] ~= nil then apply(x1[key]) end
		end
		if changed.UIScale ~= nil and ui and ui.apply_ui_scale then ui.apply_ui_scale() end
		if changed.ShowHUD ~= nil and ui and ui.g then
			local hud = ui.g:FindFirstChild("StatusHUD")
			if hud then hud.Visible = x1.ShowHUD ~= false end
		end
		if changed.k3 ~= nil and x6.b then
			x6.b.Color = x1.k3
			local visual = x6.b:FindFirstChild("Visual")
			local image = visual and visual:FindFirstChildOfClass("ImageLabel")
			if image then image.ImageColor3 = x1.k3 end
		end
		if (changed.PreserveCollisions ~= nil or changed.Disabled ~= nil) and x6.refresh_collisions then
			x6.refresh_collisions()
		end
		if changed.BlendShape ~= nil then x6.bl_failed = nil end
		if (changed.Paused ~= nil or changed.HideCoreOnPause ~= nil) and x4.refresh_core_visual then x4.refresh_core_visual() end
		if changed.PreviewEnabled == false and x4.preview_clear then x4.preview_clear() end
		if (changed.RuleMinSize ~= nil or changed.RuleMaxSize ~= nil or changed.RuleName ~= nil or changed.k5 ~= nil) and x4.recheck_rules then
			x4.recheck_rules()
		end
		if (changed.TargetParts ~= nil or changed.SurplusRule ~= nil) and x4.enforce_part_cap then x4.enforce_part_cap() end
	end

	function M.refresh()
		local notes, ui = {}, context.x5
		for _, key in ipairs({ "up", "refresh_advanced", "refresh_partctl", "refresh_keybinds" }) do
			if ui and type(ui[key]) == "function" then
				local ok = pcall(ui[key])
				if not ok then notes[#notes + 1] = "Could not refresh " .. key end
			end
		end
		return #notes > 0 and table.concat(notes, "; ") or nil
	end

	function M.reset(persist)
		assert(not x6.torn_down, "Gravity was unloaded")
		context.reset_config()
		assert(not x6.torn_down, "Gravity was unloaded during reset")
		local changed = {}
		for key, value in pairs(x1) do changed[key] = value end
		-- A reset still works on executors that cannot change the frame cap.
		if not M.fps_cap then changed.FPSCap = nil end
		M.apply_settings(changed)
		if context.x8 and context.x8.rebind_all then context.x8.rebind_all() end
		local note = M.refresh()
		if persist ~= false then context.save_settings() end
		return note
	end

	return M
end
