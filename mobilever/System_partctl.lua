return function(context, x7)
	local v1, v4, v8 = context.v1, context.v4, context.v8
	local x1, x6, x2 = context.x1, context.x6, context.x2
	local get_shape = context.get_shape

	x6.pc_selected = x6.pc_selected or setmetatable({}, { __mode = "k" })
	x6.pc_highlights = x6.pc_highlights or setmetatable({}, { __mode = "k" })
	x6.pc_offsets = x6.pc_offsets or setmetatable({}, { __mode = "k" })
	x6.pc_mods = x6.pc_mods or {}

	local RIDE_PHYSICS = PhysicalProperties.new(0.7, 0.5, 0.3, 1, 1)
	local LIGHT_PHYSICS = PhysicalProperties.new(0.001, 0, 0, 0, 0)
	local HL_COLOR = Color3.fromRGB(255, 170, 0)

	-- The panel shows a live selection count and tints the active mode, so every
	-- path that changes either has to say so. One hook rather than a signal per
	-- field: the UI only ever wants "something changed, re-read x6".
	local function pc_changed()
		if x6.pc_on_change then
			pcall(x6.pc_on_change)
		end
	end

	local function pc_add_highlight(part)
		if x6.pc_highlights[part] then
			return
		end
		local highlight = Instance.new("SelectionBox")
		highlight.Adornee = part
		highlight.Color3 = HL_COLOR
		highlight.LineThickness = 0.05
		highlight.SurfaceTransparency = 0.8
		highlight.SurfaceColor3 = HL_COLOR
		highlight.Parent = part
		x6.pc_highlights[part] = highlight
	end

	local function pc_remove_highlight(part)
		if x6.pc_highlights[part] then
			pcall(function()
				x6.pc_highlights[part]:Destroy()
			end)
			x6.pc_highlights[part] = nil
		end
	end

	-- One owner for the refcount, called from both pc_assign and pc_release. It
	-- used to be inlined in both, so clearing a mode ran it twice for the same
	-- part: pc_assign decremented before dispatching, then pc_release decremented
	-- again, and cleanup fired while other parts were still driving the module.
	local function pc_unref_mod(d)
		local mod = d.pc_mod
		if not mod then
			return
		end
		local n = x6.pc_mods[mod]
		if not n then
			return
		end
		n = n - 1
		if n > 0 then
			x6.pc_mods[mod] = n
			return
		end
		x6.pc_mods[mod] = nil
		-- Held only so the px pre-pass can find the assignment's own config; a
		-- live reference to a config table outlives the last part without this.
		mod.pc_cfg_ref = nil
		if mod.cleanup then
			pcall(mod.cleanup, x6, x1)
		end
	end

	local function pc_release(part)
		local d = x6.a and x6.a[part]
		if not d then
			return
		end
		pc_unref_mod(d)
		if d.pc_ride then
			-- Hand the part back to the same rule f2/apply_disabled_part uses, so a
			-- part whose original state was collidable and PreserveCollisions is on
			-- does not come out of ride mode permanently pass-through.
			pcall(function()
				part.CanCollide = (x1.PreserveCollisions and d.original_can_collide) or false
				part.CustomPhysicalProperties = LIGHT_PHYSICS
			end)
		end
		d.pc_mode = nil
		d.pc_target = nil
		d.pc_shape = nil
		d.pc_mod = nil
		d.pc_cfg = nil
		d.pc_phys = nil
		d.pc_ride = nil
	end
	x6.pc_release = pc_release

	-- Deselecting is not releasing: a pinned part stays pinned when the user taps
	-- elsewhere, which is the whole point of pinning it. pc_clear used to
	-- table.clear(pc_mods) instead, which dropped every refcount without calling
	-- a single cleanup and left the parts with pc_mode still set -- permanently
	-- exempt from the update bucket and the radius cull, driving a module whose
	-- px was no longer being called, and unreachable because the selection they
	-- would have been released through was gone.
	local function pc_clear_highlights()
		if x6.pc_highlights then
			for part, highlight in pairs(x6.pc_highlights) do
				if highlight and highlight.Parent then
					pcall(function()
						highlight:Destroy()
					end)
				end
			end
			table.clear(x6.pc_highlights)
		end
		if x6.pc_selected then
			table.clear(x6.pc_selected)
		end
		if x6.pc_offsets then
			table.clear(x6.pc_offsets)
		end
		x6.pc_dragging = false
		x6.pc_drag_target = nil
		x6.pc_drag_distance = nil
		pc_changed()
	end
	x6.pc_clear = pc_clear_highlights

	-- Walks x6.a rather than the selection, because the parts that most need
	-- releasing are the ones no longer selected. Used by the panel's Release All,
	-- by a shape switch (the module a part is assigned to is torn down with it)
	-- and by teardown.
	local function pc_release_all()
		if not x6.a then
			return 0
		end
		local n = 0
		local arr = x6.active_array
		if arr then
			for i = #arr, 1, -1 do
				local p = arr[i]
				local d = p and x6.a[p]
				if d and d.pc_mode then
					pc_release(p)
					n = n + 1
				end
			end
		end
		-- active_array is the fast path but it is not authoritative: a part can be
		-- in x6.a without having made it into the dense array yet.
		for p, d in pairs(x6.a) do
			if d.pc_mode then
				pc_release(p)
				n = n + 1
			end
		end
		if x6.pc_mods then
			table.clear(x6.pc_mods)
		end
		if n > 0 then
			pc_changed()
		end
		return n
	end
	x6.pc_release_all = pc_release_all

	local function pc_select(part, add_to_selection)
		if not add_to_selection then
			for p, _ in pairs(x6.pc_selected) do
				pc_remove_highlight(p)
			end
			table.clear(x6.pc_selected)
			table.clear(x6.pc_offsets)
		end
		if part and x6.a and x6.a[part] then
			x6.pc_selected[part] = true
			pc_add_highlight(part)
		end
		pc_changed()
	end
	x6.pc_select = pc_select

	local function pc_deselect(part)
		x6.pc_selected[part] = nil
		x6.pc_offsets[part] = nil
		pc_remove_highlight(part)
		pc_changed()
	end
	x6.pc_deselect = pc_deselect

	local function pc_count()
		local n = 0
		if x6.pc_selected then
			for _ in pairs(x6.pc_selected) do
				n = n + 1
			end
		end
		return n
	end
	x6.pc_count = pc_count

	-- The three modes the per-part loop in System.lua can actually dispatch.
	local VALID_MODES = { pin = true, manual = true, shape = true }

	local function pc_assign(mode, opts)
		opts = opts or {}
		-- Anything else is a release. "normal" is the panel's name for "no override"
		-- and used to be storable as a literal pc_mode: the loop has no branch for
		-- it, so the part fell through to the global shape but kept a non-nil
		-- pc_mode, which left it exempt from the update bucket and the radius cull
		-- for good.
		if mode ~= nil and not VALID_MODES[mode] then
			mode = nil
		end
		local mod = nil
		local shape_cfg = nil

		if mode == "shape" then
			if opts.shape == "Sculptor" then
				return 0
			end
			mod = get_shape and get_shape(opts.shape)
			if not mod or not mod.f2 then
				return 0
			end
			shape_cfg = (x2 and x2[opts.shape]) or (context.x2 and context.x2[opts.shape])
			if not shape_cfg and mod.Controls then
				shape_cfg = {}
				for _, ctrl in ipairs(mod.Controls) do
					if ctrl.Key then
						local def = ctrl.Default
						if def == nil then
							def = ctrl.Min or 0
							-- Min is a display bound, Default is already stored units --
							-- the same asymmetry main.lua:204 documents. Dividing both
							-- would disagree with the panel by Div squared.
							if ctrl.Div then
								def = def / ctrl.Div
							end
						end
						shape_cfg[ctrl.Key] = def
					end
				end
			end
			mod.pc_cfg_ref = shape_cfg
		end

		local count = 0
		for part, _ in pairs(x6.pc_selected) do
			local d = x6.a and x6.a[part]
			if d then
				pc_add_highlight(part)
				if mode == nil then
					-- pc_release owns the unref on this path.
					pc_release(part)
				else
					if d.pc_mod and (mode ~= "shape" or d.pc_mod ~= mod) then
						pc_unref_mod(d)
						d.pc_mod = nil
					end
					d.pc_mode = mode
					if mode == "pin" then
						d.pc_target = opts.target or part.Position
						d.pc_shape = nil
						d.pc_mod = nil
						d.pc_cfg = nil
					elseif mode == "manual" then
						d.pc_target = opts.target or d.pc_target or part.Position
						d.pc_shape = nil
						d.pc_mod = nil
						d.pc_cfg = nil
					elseif mode == "shape" then
						d.pc_shape = opts.shape
						d.pc_mod = mod
						d.pc_cfg = shape_cfg
						x6.pc_mods[mod] = (x6.pc_mods[mod] or 0) + 1
					end

					if opts.phys ~= nil then
						-- false clears the override rather than storing a boolean the
						-- System loop would then index.
						d.pc_phys = (opts.phys ~= false) and opts.phys or nil
					end

					if opts.ride ~= nil then
						d.pc_ride = opts.ride and true or false
						if d.pc_ride then
							pcall(function()
								if part.CanCollide ~= true then
									part.CanCollide = true
								end
								local props = d.original_properties or RIDE_PHYSICS
								part.CustomPhysicalProperties = props
							end)
						else
							pcall(function()
								local want = (x1.PreserveCollisions and d.original_can_collide) or false
								if part.CanCollide ~= want then
									part.CanCollide = want
								end
								part.CustomPhysicalProperties = LIGHT_PHYSICS
							end)
						end
					end
				end
				count = count + 1
			end
		end

		if count > 0 then
			pc_changed()
		end
		return count
	end
	x6.pc_assign = pc_assign

	-- Applies a physics override to the current selection without disturbing the
	-- mode. Values are nil to inherit the global setting; an all-nil table is
	-- stored as nil so the System loop's `d.pc_phys and ...` guards short out.
	local function pc_set_phys(phys)
		local live = nil
		if type(phys) == "table" then
			for _, v in pairs(phys) do
				if v ~= nil then
					live = phys
					break
				end
			end
		end
		local count = 0
		for part, _ in pairs(x6.pc_selected) do
			local d = x6.a and x6.a[part]
			if d then
				d.pc_phys = live
				count = count + 1
			end
		end
		if count > 0 then
			pc_changed()
		end
		return count
	end
	x6.pc_set_phys = pc_set_phys

	-- A drag ends by latching the part where it was dropped. It used to promote
	-- to x1.PartCtlMode, which is a *panel* setting and carries two values the
	-- per-part loop cannot honour: "normal" is not a mode at all (the part fell
	-- through to the global shape but kept a non-nil pc_mode, so it stayed exempt
	-- from bucketing and the radius cull for good), and "shape" needs a resolved
	-- module that a drag never attaches.
	local function pc_latch_drag()
		local mode = x1.PartCtlMode
		if mode == "shape" then
			local n = pc_assign("shape", { shape = x1.PartCtlShape, ride = x1.PartCtlRide })
			if n > 0 then
				return
			end
			-- Unresolvable shape: fall through to pin rather than leave the parts
			-- mid-drag with no owner.
		end
		for part, _ in pairs(x6.pc_selected) do
			local d = x6.a and x6.a[part]
			if d and d.pc_target and (not d.pc_mode or d.pc_mode == "manual") then
				d.pc_mode = (mode == "manual") and "manual" or "pin"
			end
		end
		pc_changed()
	end
	x6.pc_latch_drag = pc_latch_drag

	-- Part Control is not a shape, so it cannot gate itself on x1.k6 the way
	-- System_sculptor does (it returns early unless x1.k6 == "Sculptor"). Left
	-- ungated these handlers fired on every left click for every shape, forever:
	-- clicking any held part yanked it into manual mode and pinned it where you
	-- dropped it, and because the core ball is anchored and lives outside x6.a,
	-- every core drag fell through to the else branch and painted a selection
	-- rectangle across the screen. Armed while the panel is open, or permanently
	-- by the toggle.
	--
	-- Only InputBegan is gated. InputChanged and InputEnded are no-ops unless
	-- pc_dragging or pc_box_start is already set, and those can only be set by a
	-- gated InputBegan -- so a gesture that starts armed always finishes, even if
	-- the panel is closed halfway through it.
	local function pc_armed()
		return (x6.pc_active or x1.PartCtlEnabled) and true or false
	end
	x6.pc_armed = pc_armed

	local function get_touch_target(pos)
		local cam = v4 and v4.CurrentCamera
		if not cam then
			return nil
		end
		local ray = cam:ViewportPointToRay(pos.X, pos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local cand = {}
		if x6.a then
			for p, _ in pairs(x6.a) do
				table.insert(cand, p)
			end
		end
		params.FilterDescendantsInstances = cand
		local res = v4:Raycast(ray.Origin, ray.Direction * 1000, params)
		return res and res.Instance or nil
	end

	local function get_touch_world_pos(pos, distance)
		local cam = v4 and v4.CurrentCamera
		if not cam then
			return nil
		end
		local ray = cam:ViewportPointToRay(pos.X, pos.Y)
		return ray.Origin + (ray.Direction * (distance or 50))
	end

	return function()
		if not v1 or not v1.InputBegan or not x6.c then
			return
		end

		table.insert(
			x6.c,
			v1.InputBegan:Connect(function(input, processed)
				if processed or not pc_armed() then
					return
				end

				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					local target = get_touch_target(input.Position)
					local multi = x1.PartCtlMultiSelect == true

					if target and x6.a and x6.a[target] then
						if x6.pc_selected[target] then
							if multi then
								pc_deselect(target)
							else
								x6.pc_dragging = true
								local cam = v4 and v4.CurrentCamera
								x6.pc_drag_distance = cam and (cam.CFrame.Position - target.Position).Magnitude or 50
								x6.pc_drag_target = target.Position
								for part, _ in pairs(x6.pc_selected) do
									x6.pc_offsets[part] = part.Position - target.Position
									local d = x6.a[part]
									if d then
										d.pc_mode = d.pc_mode or "manual"
										d.pc_target = part.Position
									end
								end
							end
						else
							pc_select(target, multi)
							if not multi then
								x6.pc_dragging = true
								local cam = v4 and v4.CurrentCamera
								x6.pc_drag_distance = cam and (cam.CFrame.Position - target.Position).Magnitude or 50
								x6.pc_drag_target = target.Position
								x6.pc_offsets[target] = Vector3.zero
								local d = x6.a[target]
								if d then
									d.pc_mode = d.pc_mode or "manual"
									d.pc_target = target.Position
								end
							end
						end
					end
				end
			end)
		)

		table.insert(
			x6.c,
			v1.InputChanged:Connect(function(input, processed)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
					if x6.pc_dragging then
						local new_pos = get_touch_world_pos(input.Position, x6.pc_drag_distance or 50)
						if new_pos then
							x6.pc_drag_target = new_pos
							for part, _ in pairs(x6.pc_selected) do
								local d = x6.a and x6.a[part]
								if d then
									local off = x6.pc_offsets[part] or Vector3.zero
									d.pc_target = new_pos + off
									d.pc_mode = d.pc_mode or "manual"
								end
							end
						end
					end
				end
			end)
		)

		table.insert(
			x6.c,
			v1.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					if x6.pc_dragging then
						x6.pc_dragging = false
						x6.pc_drag_target = nil
						pc_latch_drag()
					end
				end
			end)
		)
	end
end
