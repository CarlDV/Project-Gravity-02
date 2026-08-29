-- Engine tools: targeting, state readout, per-shape controls, engine properties.
return function(env)
	local context = env.context
	local v2, v8 = env.v2, env.v8
	local x1 = context.x1
	local get_shape = context.get_shape

	local function x2()
		return context.x2
	end

	-- adjust_gravity's parameters are otherwise 18 near-identical if-blocks. Order
	-- matters: it is the order the change summary is reported in.
	local ENGINE_FIELDS = {
		{ arg = "speed", field = "MaxSpeed", kind = "number" },
		{ arg = "damping", field = "Damping", kind = "number" },
		{ arg = "disabled", field = "Disabled", kind = "bool", apply = function(val)
			-- route through System so the parts get their collision back and stop
			-- being driven, exactly as the UI toggle and the hotkey do
			if context.x4 and context.x4.apply_disabled then
				context.x4.apply_disabled(val)
			else
				x1.Disabled = val
			end
			return x1.Disabled
		end },
		{ arg = "target_all", field = "PI_All", kind = "bool", clears = "AnchorSelf" },
		{ arg = "anchor_self", field = "AnchorSelf", kind = "bool", clears = "PI_All" },
		{ arg = "predictive_tracking", field = "PredictiveTracking", kind = "bool" },
		{ arg = "prediction_factor", field = "PredictionFactor", kind = "number" },
		{ arg = "ki", field = "Ki", kind = "number" },
		{ arg = "angular_damping", field = "AngularDamping", kind = "number" },
		{ arg = "vertical_stiffness", field = "VerticalStiffness", kind = "number" },
		{ arg = "aggressive_claim", field = "AggressiveClaim", kind = "bool" },
		{ arg = "void_protection", field = "VoidProtection", kind = "bool" },
		{ arg = "anti_fling", field = "AntiFling", kind = "bool" },
		{ arg = "force_smooth", field = "Force Smooth (Lags)", kind = "bool" },
		{ arg = "max_fidelity", field = "MaxFidelity", kind = "bool" },
		{ arg = "realistic_liftoff", field = "Realistic Liftoff", kind = "bool" },
		{ arg = "paused", field = "Paused", kind = "bool", apply = function(val)
			-- Same reason as disabled: whether the core ball is visible depends on
			-- Paused now, and only System knows how to repaint it.
			x1.Paused = val
			if context.x4 and context.x4.refresh_core_visual then
				context.x4.refresh_core_visual()
			end
			return x1.Paused
		end },
		{ arg = "hide_core_on_pause", field = "HideCoreOnPause", kind = "bool", apply = function(val)
			x1.HideCoreOnPause = val
			if context.x4 and context.x4.refresh_core_visual then
				context.x4.refresh_core_visual()
			end
			return x1.HideCoreOnPause
		end },
		{ arg = "force_launch", field = "IsLaunching", kind = "bool" }
	}

	local ENGINE_PROPS = {
		shape = { type = "string", description = "Shape preset name e.g. 'Celestial Ribbon', 'Black Hole'" },
		speed = { type = "number", description = "Max speed limit" },
		damping = { type = "number", description = "Damping value" },
		disabled = { type = "boolean", description = "Disable physics engine" },
		target_all = { type = "boolean", description = "Target all players" },
		anchor_self = { type = "boolean", description = "Anchor to self" },
		predictive_tracking = { type = "boolean", description = "Enable predictive tracking" },
		prediction_factor = { type = "number", description = "Prediction factor value" },
		ki = { type = "number", description = "Integral gain (Ki)" },
		angular_damping = { type = "number", description = "Angular damping" },
		vertical_stiffness = { type = "number", description = "Vertical stiffness" },
		aggressive_claim = { type = "boolean", description = "Aggressive claiming mode" },
		void_protection = { type = "boolean", description = "Void protection" },
		anti_fling = { type = "boolean", description = "Anti-fling mode" },
		force_smooth = { type = "boolean", description = "Force smooth mode" },
		max_fidelity = { type = "boolean", description = "Force smooth plus never skipping or culling a part" },
		realistic_liftoff = { type = "boolean", description = "Realistic liftoff" },
		paused = { type = "boolean", description = "Pause physics engine" },
		hide_core_on_pause = { type = "boolean", description = "Hide the core marker while paused" },
		force_launch = { type = "boolean", description = "Trigger force launch" }
	}

	return {
		{
			name = "set_target",
			description = "Set, add, remove or clear target players for Project Gravity.",
			parameters = {
				type = "object",
				properties = {
					player = { type = "string", description = "Player username or display name" },
					action = { type = "string", description = "Action: 'add', 'remove', or 'clear'" }
				},
				required = {}
			},
			run = function(args)
				local plName = args.player and tostring(args.player):lower() or nil
				local action = args.action and tostring(args.action):lower() or "add"
				if action == "clear" then
					table.clear(x1.Targets)
					x1.TgtActive = false
					return "Cleared all targets"
				end
				if not plName or plName == "" then return "Player name missing" end
				local foundPl = nil
				for _, pl in ipairs(v2:GetPlayers()) do
					if pl ~= v8 and (pl.Name:lower():find(plName, 1, true) or pl.DisplayName:lower():find(plName, 1, true)) then
						foundPl = pl
						break
					end
				end
				if not foundPl then return "Player not found: " .. plName end
				if action == "remove" then
					local idx = table.find(x1.Targets, foundPl)
					if idx then table.remove(x1.Targets, idx) end
					x1.TgtActive = (#x1.Targets > 0)
					return "Removed target: " .. foundPl.DisplayName
				end
				if not table.find(x1.Targets, foundPl) then
					table.insert(x1.Targets, foundPl)
				end
				x1.AnchorSelf = false
				x1.PI_All = false
				x1.TgtActive = true
				return "Target set: " .. foundPl.DisplayName .. " (@" .. foundPl.Name .. ")"
			end
		},
		{
			name = "get_gravity_state",
			description = "Get complete current status of Project Gravity engine, active shape, targets, and control parameters.",
			parameters = { type = "object", properties = {}, required = {} },
			run = function()
				local activeTgts = {}
				for _, pl in ipairs(x1.Targets or {}) do
					table.insert(activeTgts, pl.DisplayName .. " (@" .. pl.Name .. ")")
				end
				local activeTgtStr = #activeTgts > 0 and table.concat(activeTgts, ", ") or (x1.PI_All and "ALL PLAYERS" or (x1.AnchorSelf and "SELF" or "NONE"))
				local currentShape = tostring(x1.k6 or "None")
				local ctrlState = {}
				local presets = x2()
				if presets and presets[currentShape] then
					for k, v in pairs(presets[currentShape]) do
						table.insert(ctrlState, tostring(k) .. "=" .. tostring(v))
					end
				end
				return string.format(
					"Current Shape: %s\nDisabled: %s | Paused: %s | MaxSpeed: %s | Damping: %s\nTargeting: %s\nAggressiveClaim: %s | VoidProtection: %s | AntiFling: %s\nControls: %s",
					currentShape, tostring(x1.Disabled), tostring(x1.Paused), tostring(x1.MaxSpeed), tostring(x1.Damping),
					activeTgtStr, tostring(x1.AggressiveClaim), tostring(x1.VoidProtection), tostring(x1.AntiFling),
					#ctrlState > 0 and table.concat(ctrlState, ", ") or "None"
				)
			end
		},
		{
			name = "control_shape",
			description = "Adjust specific control keys (e.g. k11, k12) of the active or specified shape preset.",
			parameters = {
				type = "object",
				properties = {
					shape = { type = "string", description = "Shape preset name (optional, defaults to active shape)" },
					key = { type = "string", description = "Control key (e.g. 'k11', 'k12')" },
					val = { type = "number", description = "New value for the control key" }
				},
				required = { "key", "val" }
			},
			run = function(args)
				local presets = x2()
				local shapeName = args.shape and tostring(args.shape) or x1.k6
				if not shapeName or not presets[shapeName] then
					return "Shape not found: " .. tostring(shapeName)
				end
				local key = args.key and tostring(args.key)
				local val = tonumber(args.val)
				if key and presets[shapeName][key] == nil then
					return string.format("Shape '%s' has no control key '%s'", shapeName, key)
				end
				if key and val and type(presets[shapeName][key]) == "number" then
					presets[shapeName][key] = val
					return string.format("Updated shape '%s' key '%s' to %s", shapeName, key, tostring(val))
				end
				return "Shape parameter key is not numeric or value is missing"
			end
		},
		{
			name = "adjust_gravity",
			description = "Modify Project Gravity engine properties dynamically.",
			parameters = { type = "object", properties = ENGINE_PROPS, required = {} },
			run = function(args)
				local changes = {}

				local shapeName = args.shape and tostring(args.shape) or nil
				if shapeName and get_shape and get_shape(shapeName) then
					x1.k6 = shapeName
					table.insert(changes, "shape=" .. shapeName)
				end

				for _, spec in ipairs(ENGINE_FIELDS) do
					local raw = args[spec.arg]
					if spec.kind == "number" then
						local num = tonumber(raw)
						if num then
							x1[spec.field] = num
							table.insert(changes, spec.arg .. "=" .. tostring(num))
						end
					elseif raw ~= nil then
						local val = (raw == true)
						if spec.apply then
							val = spec.apply(val)
						else
							x1[spec.field] = val
							if val and spec.clears then x1[spec.clears] = false end
						end
						table.insert(changes, spec.arg .. "=" .. tostring(val))
					end
				end

				return #changes > 0 and ("Updated engine: " .. table.concat(changes, ", ")) or "No parameters modified"
			end
		}
	}
end
