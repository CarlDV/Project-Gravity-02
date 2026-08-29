return function(context)
	local v1, v2, v3, v4, v5, v6, v7, v8, v9 = context.v1, context.v2, context.v3, context.v4, context.v5, context.v6, context.v7, context.v8, context.v9
	local x1, x2, x6, x9 = context.x1, context.x2, context.x6, context.x9
	local x5 = context.x5
	local get_shape = context.get_shape
	local load_module = context.load_module
	local SUB_DIR = context.SUB_DIR or ""

	local x4, x8 = {}, {}
	local x7 = {}
	local ANTI_SLEEP = Vector3.new(0, 0.01, 0)
	local ZERO_VECTOR = Vector3.zero
	local LIGHT_PHYSICS = PhysicalProperties.new(0.001, 0, 0, 0, 0)

	function x7.n(t, x, d)
		-- prefer the in-panel toast so notifications match the rest of the UI;
		-- fall back to the Roblox notification when the panel is not up yet
		local ui = context.x5
		if ui and ui.toast and ui.toast(t, x, nil, d) then
			return
		end
		pcall(function()
			v5:SetCore("SendNotification", { Title = t, Text = x, Duration = d or 3 })
		end)
	end

	-- The panel needs somewhere to send a rejected-keybind message, and x7 is
	-- local to this module. main.lua:577 calls this unguarded on the startup
	-- Testing notice, so leaving it off the mobile tree took the whole script
	-- down on any device whose saved shape was still in testing.
	x8.notify = x7.n

	local EXCLUDED_NAMES = {
		Baseplate = true,
		HumanoidRootPart = true,
		Terrain = true,
		Handle = true,
		Head = true,
		Torso = true,
		["Left Arm"] = true,
		["Right Arm"] = true,
		["Left Leg"] = true,
		["Right Leg"] = true,
		UpperTorso = true,
		LowerTorso = true,
		LeftUpperArm = true,
		LeftLowerArm = true,
		LeftHand = true,
		RightUpperArm = true,
		RightLowerArm = true,
		RightHand = true,
		LeftUpperLeg = true,
		LeftLowerLeg = true,
		LeftFoot = true,
		RightUpperLeg = true,
		RightLowerLeg = true,
		RightFoot = true,
	}

	-- Character models, rebuilt at most once a second. Membership is checked as a
	-- plain hash read during the ancestor walk below, which short-circuits before
	-- the two FindFirstChildOfClass calls: a player character is by far the most
	-- common reason a part is excluded, so the common case now costs one Lua table
	-- read instead of an IsA plus up to two engine-side child searches per level.
	local char_set, char_set_t = {}, 0
	local function characters()
		local now = time()
		if now - char_set_t > 1 then
			char_set_t = now
			table.clear(char_set)
			for _, pl in ipairs(v2:GetPlayers()) do
				local ch = pl.Character
				if ch then
					char_set[ch] = true
				end
			end
		end
		return char_set
	end

	function x7.e(p)
		if not p:IsA("BasePart") then
			return true
		end
		if p.Anchored then
			return true
		end
		if EXCLUDED_NAMES[p.Name] then
			return true
		end
		-- p.Parent used to be re-read from the engine once per tag in k5, and
		-- again to seed the ancestor walk. One read up front covers all of it.
		local parent = p.Parent
		for _, t in ipairs(x1.k5) do
			if p:FindFirstChild(t) or (parent and parent:FindFirstChild(t)) then
				return true
			end
		end
		local chars = characters()
		-- The walk starts at the parent, not at p: p is always a BasePart here,
		-- so testing it against Model/Accessory/Tool was three guaranteed-false
		-- engine calls per candidate part.
		local target = parent
		while target and target ~= v4 and target ~= game do
			-- ordered cheapest-to-dearest: Lua table read, then a bare IsA, then
			-- the child searches. The Accessory/Tool test used to sit after the
			-- Model test, so accessories paid for two child searches first.
			if chars[target] then
				return true
			end
			if target:IsA("Accessory") or target:IsA("Tool") then
				return true
			end
			if
				target:IsA("Model")
				and (target:FindFirstChildOfClass("Humanoid") or target:FindFirstChildOfClass("AnimationController"))
			then
				return true
			end
			target = target.Parent
		end
		return false
	end

	-- Both the core tracker and the multi-target sweep want the same thing from a
	-- character, and both used to inline it twice per call.
	local function root_of(char)
		if not char then
			return nil
		end
		return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
	end

	local function get_predicted_pos(root, factor)
		local pos = root.Position
		local vel = root.AssemblyLinearVelocity
		-- squared compare first: Magnitude's sqrt is only worth paying when the
		-- velocity actually needs clamping. .Unit would then sqrt the same number
		-- a second time, so scale by the root we already have instead.
		local vel_sq = vel:Dot(vel)
		if vel_sq > 62500 then
			vel = vel * (250 / math.sqrt(vel_sq))
		end
		local y_vel = math.clamp(vel.Y, -50, 15)
		vel = Vector3.new(vel.X, y_vel, vel.Z)
		return pos + (vel * (factor / 1000))
	end

	local no_damp = { ["Slingshot"] = true, ["Point Impact"] = true, ["Light Light no Mi"] = true }

	-- NetworkOwnerV3 values that mean somebody else is simulating the part. One
	-- hash lookup instead of a four-way comparison chain, per part per frame.
	local NO3_SKIP = { [-1] = true, [1] = true, [2] = true, [3] = true }

	-- Most shapes are pure functions of the part and the clock, but one that owns
	-- an instance -- Platform's anchored pad -- needs somewhere to give it back, or
	-- it outlives the shape that made it. Read straight out of loaded_shapes rather
	-- than through get_shape: this runs on the disable and stop paths, and
	-- get_shape would happily block on an HTTP fetch for a shape that never loaded.
	-- A shape with no cleanup costs one nil check.
	local function cleanup_shape(name)
		local cache = context.loaded_shapes
		local mod = name and cache and cache[name]
		if mod and mod.cleanup then
			pcall(mod.cleanup, x6, x1)
		end
	end

	-- Forward-declared: f3_body's drop branch restores a part whose Parent went away,
	-- and the definition lives further down next to x4.f2. Without this the name
	-- resolved to a nil global inside f3_body and the pcall around it swallowed the
	-- failure, so the restore silently did nothing.
	local f2_restore

	-- The hot loop lives in its own function so the per-frame pcall does not have
	-- to allocate a fresh closure sixty times a second.
	local function f3_body(real_dt)
			local c = x6.b.Position
			x6.f = x6.f + 1
			if x6.last_shape ~= x1.k6 then
				cleanup_shape(x6.last_shape)
				x6.last_shape = x1.k6
				-- Part Control assignments are torn down with the switch: a part
				-- assigned to a shape holds that module and its x6.pre state, both of
				-- which the switch invalidates. Releasing first also clears pc_mode,
				-- which the per-part reset below does not reach.
				if x6.pc_release_all then
					pcall(x6.pc_release_all)
				end
				for _, d in pairs(x6.a) do
					d.v1 = nil
					d.v2 = nil
					d.v3 = nil
					d.v4 = nil
					d.v5 = nil
					d.v6 = nil
					d.v7 = nil
					d.v8 = nil
					d.v9 = nil
					d.nx = nil
					d.ny = nil
					d.nz = nil
					d.phase = nil
					d.phase2 = nil
					d.radial_phase = nil
					d.last_t = nil
					d.sys_last_t = nil
					d.last_target_pos = nil
					d.hit_wall = nil
					d.hover_anchor = nil
					d.cursed_hover_mode = nil
					-- room_slot is the field ROOM Ope Ope no Mi actually parks; the two
					-- names below are left over from an earlier version of that shape and
					-- are written by nothing, so the list was clearing the dead names and
					-- missing the live one.
					d.room_slot = nil
					d.room_target = nil
					d.room_orbit_phase = nil
					d.pika_direction = nil
					d.pika_redirect_at = nil
					d.light_direction = nil
					d.light_redirect_at = nil
					d.integral = Vector3.zero
				end
			end
			local dt = x6.n > 5000 and 10 or (x6.n > 2500 and 6 or (x6.n > 1000 and 3 or 1))
			local et, ft = x1.k7 or dt, time()
			if x1.k6 == "Light Light no Mi" then
				et = 1
			end
			-- Max Fidelity is Force Smooth plus "never skip a part": same dt/et/alpha
			-- collapse, and always_process on top. Folding it into force_smooth here
			-- is what makes it a genuine superset -- written as its own separate
			-- condition it collapsed the timestep but left do_damping on, so the
			-- stronger-sounding toggle was not actually the stronger one.
			local max_fid = x1.MaxFidelity and true or false
			local force_smooth = x1["Force Smooth (Lags)"] or max_fid
			if force_smooth then
				dt = 1
				et = 1
			end
			local i = 0
			local update_bucket = x6.f % et
			if ft > x6.pi_timer then
				x6.pi_timer = ft + 1
				local pi = x6.pi_targets
				table.clear(pi)
				local target_set = x6.pi_set
				if not target_set then
					target_set = {}
					x6.pi_set = target_set
				else
					table.clear(target_set)
				end
				if x1.PI_All then
					for _, pl in ipairs(v2:GetPlayers()) do
						if pl ~= v8 and pl.Character and root_of(pl.Character) then
							pi[#pi + 1] = pl
							target_set[pl] = true
						end
					end
				else
					if x1.Targets and #x1.Targets > 0 then
						for _, tgt in ipairs(x1.Targets) do
							if tgt and tgt.Parent and tgt.Character and root_of(tgt.Character) then
								pi[#pi + 1] = tgt
								target_set[tgt] = true
							end
						end
					end
				end

				for _, pl in ipairs(v2:GetPlayers()) do
					-- pl.Character was read twice and the Head lookup was thrown
					-- away and re-fetched as a property; two engine crossings per
					-- player per second for values we already had in hand.
					local char = pl.Character
					local head = char and char:FindFirstChild("Head")
					if head then
						local is_tgt = target_set[pl] == true
						local marker = head:FindFirstChild("GravityTargetMarker")

						-- Built bottom-up and parented last. Instance.new(class,
						-- parent) attaches before the properties are assigned, so
						-- every set after it schedules a layout/render pass the
						-- engine then throws away; assembling off-tree and
						-- parenting once costs a single pass for the whole marker.
						if is_tgt and not marker then
							local txt = Instance.new("TextLabel")
							txt.BackgroundTransparency = 1
							txt.Size = UDim2.new(1, 0, 1, 0)
							txt.Text = "▼"
							txt.TextColor3 = Color3.fromRGB(255, 60, 60)
							txt.TextScaled = true
							txt.Font = Enum.Font.GothamBlack

							local str = Instance.new("UIStroke")
							str.Color = Color3.fromRGB(0, 0, 0)
							str.Thickness = 2
							str.Parent = txt

							local bg = Instance.new("BillboardGui")
							bg.Name = "GravityTargetMarker"
							bg.Size = UDim2.new(1.5, 0, 1.5, 0)
							bg.StudsOffset = Vector3.new(0, 2.5, 0)
							bg.AlwaysOnTop = true
							txt.Parent = bg
							bg.Parent = head
						elseif not is_tgt and marker then
							marker:Destroy()
						end
					end
				end
			end
			local shape_name = x1.k6
			local cur_shape_mod = get_shape(shape_name)
			local cur_shape_cfg = x1.S[shape_name] or {}
			if cur_shape_mod and cur_shape_mod.px then
				cur_shape_mod.px(ft, cur_shape_cfg, x6, x9, x1)
			end
			local pc_mods = x6.pc_mods
			if pc_mods then
				for mod, _ in pairs(pc_mods) do
					if mod.px then
						pcall(mod.px, ft, mod.pc_cfg_ref or cur_shape_cfg, x6, x9, x1)
					end
				end
			end
			if x1.k6 ~= shape_name then
				shape_name = x1.k6
				cur_shape_mod = get_shape(shape_name)
				cur_shape_cfg = x1.S[shape_name] or {}
			end
			local cur_no_damp = no_damp[shape_name]

			local target_positions = x6.target_positions
			if not target_positions then
				target_positions = {}
				x6.target_positions = target_positions
			else
				table.clear(target_positions)
			end
			local valid_targets = 0
			-- v4 is already the (cloneref'd) Workspace service, so reaching it as
			-- an upvalue is a register read where `workspace` is an _ENV hash
			-- lookup. Same instance, three fewer global lookups per frame.
			local fallen_height = v4.FallenPartsDestroyHeight + 50
			if #x6.pi_targets > 0 then
				local predictive = x1.PredictiveTracking
				local pfactor = x1.PredictionFactor or 150
				local void_off = x1.VoidProtection == false
				for _, tgt in ipairs(x6.pi_targets) do
					local root = tgt and root_of(tgt.Character)
					if root then
						local pos = root.Position
						if void_off or (pos.Y > fallen_height) then
							if predictive then
								pos = get_predicted_pos(root, pfactor)
							end
							valid_targets = valid_targets + 1
							target_positions[valid_targets] = pos
						end
					end
				end
			end
			local k1 = x1.k1
			local c7 = x9.c7
			local k1_sq = k1 * k1
			local c7_sq = c7 * c7
			local ki = x1.Ki or 0
			local damping = x1.Damping or 0
			local max_speed = x1.MaxSpeed
			local vert_stiff = x1.VerticalStiffness or 1
			local vert_mult = vert_stiff ~= 1 and Vector3.new(1, vert_stiff, 1) or nil
			local dt_mult = real_dt * 60 * dt

			local smoothing = (shape_name == "Point Impact" and 1) or x1.k8
			if x1.DramaMode and shape_name == "Point Impact" then
				smoothing = 1
			end
			local sm_alpha = smoothing >= 1 and 1 or (1 - math.exp(-dt_mult * -math.log(math.max(0.001, 1 - smoothing))))
			-- force_smooth already folds in max_fid (line 224).
			if force_smooth then
				sm_alpha = 1
			end

			local ang_damp_mult = 1
			if x1.AngularDamping and x1.AngularDamping > 0 then
				local damp_rate = -60 * math.log(math.max(0.001, 1 - math.clamp(x1.AngularDamping, 0, 0.99)))
				ang_damp_mult = math.exp(-damp_rate * real_dt * dt)
			end

			local trans_ease = 1
			local in_transition = false
			if x6.transition_time and x6.transition_time > 0 then
				in_transition = true
				local alpha = math.clamp((ft - x6.transition_time) / x6.transition_dur, 0, 1)
				if alpha < 1 then
					trans_ease = alpha * alpha * (3 - 2 * alpha)
				else
					x6.transition_time = 0
					in_transition = false
				end
			end
			
			if x6.f % 60 == 0 or x6.water_level == nil then
				local water_part = v4:FindFirstChild("WaterLevel")
				if water_part and water_part:IsA("BasePart") then
					x6.water_level = water_part.Position.Y + (water_part.Size.Y / 2) + 5
				else
					x6.water_level = false
				end
			end
			local water_level = x6.water_level ~= false and x6.water_level or nil
			local ghp = gethiddenproperty
			local workspace_gravity = v4.Gravity or 196.2
			local shape_f2 = cur_shape_mod and cur_shape_mod.f2
			local is_drop_shape = cur_shape_mod and cur_shape_mod.Drop
			local is_self_bounded_shape = shape_name == "ROOM Ope Ope no Mi" or shape_name == "Light Light no Mi"
			local aggressive_root = nil
			if x1.AggressiveClaim and v8.Character then
				aggressive_root = root_of(v8.Character)
			end

			-- Everything below is constant for the whole sweep. Reading it once
			-- here instead of once per part removes a few thousand hash lookups
			-- and string comparisons per frame at high part counts.
			local aggressive_claim = x1.AggressiveClaim and true or false
			local realistic_liftoff = x1["Realistic Liftoff"] and true or false
			local is_point_impact = shape_name == "Point Impact"
			local is_light_shape = shape_name == "Light Light no Mi"
			local is_cursed_red = shape_name == "Cursed Technique Red"
			local always_process = (is_drop_shape or is_self_bounded_shape or max_fid) and true or false
			local base_limit = is_light_shape and 1000 or ((max_speed and not cur_no_damp) and max_speed or 3300)
			local check_no3 = (not is_drop_shape) and (not aggressive_claim) and ghp ~= nil
			local do_damping = damping > 0 and not cur_no_damp and not force_smooth
			local integral_on = ki > 0

			-- The sweep reached both of these through x6 on every single
			-- iteration: at 5000 parts that was ~20k extra hash lookups a frame,
			-- 1.2M a second, for two fields that cannot change mid-sweep. Nothing
			-- outside main.lua's teardown ever reassigns them (shapes and the
			-- sculptor only read), so holding them as locals is safe.
			local arr = x6.active_array
			local data = x6.a
			-- gethiddenproperty is one of the pricier executor calls and this was
			-- refreshing every 0.15s per part no matter the load: ~33k pcall+read
			-- pairs a second at 5000 parts. Widening it with the same part-count
			-- stride the sweep already uses cuts that ~4x, capped at 0.6s so an
			-- ownership change is still picked up quickly.
			local no3_interval = 0.15 * (dt > 4 and 4 or dt)

			for k = #arr, 1, -1 do
				local p = arr[k]
				local d = data[p]

				if not d or not p.Parent then
					if d then
						-- d holds the only copy of this part's original CanCollide,
						-- Anchored and CustomPhysicalProperties. Dropping it without
						-- restoring is unrecoverable: plenty of games pool parts by
						-- setting Parent = nil and putting them back later, and the
						-- DescendantAdded hook then re-queues the part, at which point
						-- x4.f1 re-snapshots the *forced* values -- CanCollide false and
						-- LIGHT_PHYSICS -- as if they were the originals. That part can
						-- never be restored again by any release path, including
						-- teardown. Deliberately not guarded on p.Parent -- this branch
						-- fires *because* Parent is nil, and an unparented part still
						-- accepts property writes, which is the whole point. The pcall
						-- covers the other case, where the part was fully destroyed and
						-- there is nothing left to write to.
						pcall(f2_restore, p, d, false)
						if d.at and d.at.Parent then d.at:Destroy() end
						if d.lv and d.lv.Parent then d.lv:Destroy() end
						if d.av and d.av.Parent then d.av:Destroy() end
						data[p] = nil
					end
					local last = #arr
					if k ~= last then
						arr[k] = arr[last]
					end
					arr[last] = nil
					x6.n = math.max(0, x6.n - 1)
					continue
				end
				i = i + 1
				if d.pc_mode == nil and i % et ~= update_bucket then
					continue
				end
				if check_no3 then
					if d.no3_val == nil or ft - (d.no3_tick or 0) > no3_interval then
						d.no3_tick = ft
						local success, no3_val = pcall(ghp, p, 'NetworkOwnerV3')
						d.no3_val = success and no3_val or 0
					end
					if NO3_SKIP[d.no3_val] then
						continue
					end
				end
				local active_c = c
				if valid_targets > 0 then
					active_c = target_positions[(d.id % valid_targets) + 1]
				end
				local p_pos = p.Position
				local tc = active_c - p_pos
				local distance_sq = tc:Dot(tc)
				if distance_sq > k1_sq and not (always_process or d.pc_mode) then
					-- Skipping the part leaves its LinearVelocity alone, and with MaxForce
					-- at k4 the constraint keeps applying it: anything that overshoots the
					-- radius coasts outward for good, and it can never come back because
					-- this same test culls it before the shape runs again. Park it once on
					-- the way out instead. The flag keeps that from becoming a physics
					-- property write per out-of-range part per frame, and clearing d.vl
					-- means a part that does drift back in starts from a standstill rather
					-- than resuming the velocity that threw it out.
					if not d.parked and d.lv then
						d.parked = true
						d.vl = ZERO_VECTOR
						d.lv.VectorVelocity = ZERO_VECTOR
					end
					continue
				end
				if d.parked then
					d.parked = nil
				end
				if distance_sq > c7_sq or always_process or d.pc_mode or is_cursed_red then
					local target_pos_delta = ANTI_SLEEP
					local pure_target_pos = nil
					local pc = d.pc_mode
					if pc == "pin" or pc == "manual" then
						local tgt = d.pc_target or p_pos
						local gain = (d.pc_phys and d.pc_phys.k10) or x1.k10
						pure_target_pos = tgt
						target_pos_delta = (tgt - p_pos) * (gain * x9.c1)
					elseif pc == "shape" and d.pc_mod and d.pc_mod.f2 then
						target_pos_delta, pure_target_pos =
							d.pc_mod.f2(p, active_c, d, ft, d.pc_cfg or cur_shape_cfg, x1, x6, x9)
					elseif shape_f2 then
						target_pos_delta, pure_target_pos = shape_f2(p, active_c, d, ft, cur_shape_cfg, x1, x6, x9)
					end
					
					if d.unclaim then
						x4.f2(p, true, k)
						continue
					end
					if vert_mult then
						target_pos_delta = target_pos_delta * vert_mult
					end
					if integral_on and d.integral then
						local ig = d.integral + (target_pos_delta * dt_mult)
						local ig_sq = ig:Dot(ig)
						if ig_sq > 10000 then
							ig = ig * (100 / math.sqrt(ig_sq))
						end
						d.integral = ig
						target_pos_delta = target_pos_delta + (ig * ki)
					end
					local tv = target_pos_delta
					local liftoff_limit = nil

					if realistic_liftoff and d.claim_t then
						local age = ft - d.claim_t
						if age < 4 then
							local p_factor = math.clamp(age / 4, 0, 1)
							local g_bias = Vector3.new(0, -workspace_gravity, 0) * (1 - p_factor)
							local kick = Vector3.new(0, 60, 0) * math.clamp(1 - (age / 0.8), 0, 1)
							tv = tv + g_bias + kick
							liftoff_limit = 8 + ((max_speed or 3300) - 8) * (p_factor ^ 4)
						end
					end
					
					if pure_target_pos then
						if d.last_target_pos and d.sys_last_t then
							local actual_dt = ft - d.sys_last_t
							if actual_dt > 0.001 then
								-- This differentiates a target that shapes only restamp once per
								-- bucket cycle, so it means something only while the target moves
								-- continuously. A control change that re-seats parts onto
								-- different targets teleports it instead: Hover Text's message box
								-- reshuffles the whole part-id -> pixel map, so every part's
								-- target jumps most of the banner width in one step, and dividing
								-- that by a ~0.066s cycle injects thousands of studs/s. Parts
								-- thrown past k1 then fail the distance test above and are parked
								-- out of range, so the banner never recovers. Capping the term at
								-- the part's own speed limit keeps the smoothing for real motion
								-- and turns a re-seat into a fast glide instead of a fling.
								local tvel = (pure_target_pos - d.last_target_pos) / actual_dt
								local tvel_sq = tvel:Dot(tvel)
								if tvel_sq > base_limit * base_limit then
									tvel = tvel * (base_limit / math.sqrt(tvel_sq))
								end
								tv = tv + tvel
							end
						end
						d.last_target_pos = pure_target_pos
						d.sys_last_t = ft
					else
						d.last_target_pos = nil
						d.sys_last_t = nil
					end
					
					if do_damping or (d.pc_phys and d.pc_phys.Damping) then
						local cur_damp = (d.pc_phys and d.pc_phys.Damping) or damping
						tv = tv - (p.AssemblyLinearVelocity * cur_damp)
					end

					-- Mirrors the global sm_alpha derivation above, including its
					-- `>= 1 means snap` case: without that branch a per-part
					-- smoothing of 1 fell into math.log(math.max(0.001, 0)) and
					-- produced a finite alpha instead of following the target exactly.
					local cur_sm = sm_alpha
					local pc_sm = d.pc_phys and d.pc_phys.k8
					if pc_sm then
						if pc_sm >= 1 or force_smooth then
							cur_sm = 1
						else
							cur_sm = 1 - math.exp(-dt_mult * -math.log(math.max(0.001, 1 - pc_sm)))
						end
					end
					local vl = d.vl and d.vl:Lerp(tv, cur_sm) or tv
					if in_transition and d.trans_vl then
						if trans_ease < 1 then
							vl = d.trans_vl:Lerp(vl, trans_ease)
						else
							d.trans_vl = nil
						end
					end

					if is_point_impact then
						local impact_delta = active_c - p_pos
						local id_sq = impact_delta:Dot(impact_delta)
						-- one sqrt instead of Magnitude's plus Unit's
						vl = id_sq > 0 and (impact_delta * (10000 / math.sqrt(id_sq))) or ZERO_VECTOR
					else
						-- An explicit per-part cap is a cap. The 15300 floor exists so a
						-- shape that hands back an exact position is not fought by the
						-- global speed limit, but pin and manual always hand one back, so
						-- applying it unconditionally made the per-part Max Speed slider
						-- do nothing in the two modes it is most useful in.
						local pc_limit = d.pc_phys and d.pc_phys.MaxSpeed
						local limit = pc_limit or base_limit
						if pure_target_pos and not pc_limit then limit = math.max(limit, 15300) end
						if liftoff_limit then limit = math.min(limit, liftoff_limit) end
						local vl_sq = vl:Dot(vl)
						if vl_sq > limit * limit then
							vl = vl * (limit / math.sqrt(vl_sq))
						end

						if water_level then
							local current_y = p_pos.Y
							if current_y < water_level then
								local depth = water_level - current_y
								vl = Vector3.new(vl.X, math.max(vl.Y, 0) + (depth * 5), vl.Z)
							end
						end
					end

					d.vl = vl
					d.lv.VectorVelocity = vl

					if ang_damp_mult ~= 1 then
						p.AssemblyAngularVelocity = p.AssemblyAngularVelocity * ang_damp_mult
					end

					if aggressive_claim and not is_point_impact and p.ReceiveAge > 0 then
						local base_pos = aggressive_root and aggressive_root.Position or active_c
						if not d.claim_offset then
							d.claim_offset = Vector3.new(math.sin(d.id) * 20, 15 + (d.id % 15), math.cos(d.id) * 20)
						end
						p.CFrame = CFrame.new(base_pos + d.claim_offset)
						d.lv.VectorVelocity = ZERO_VECTOR
					end
				end
			end
	end

	local function f3(real_dt)
		real_dt = real_dt or (1 / 60)
		if not x6.b or x1.Disabled then
			return
		end
		if x1.Paused then
			-- ANTI_SLEEP is a constant, so the old code wrote the same value to
			-- every constraint 60 times a second: 300k physics property writes a
			-- second at 5000 parts, all of them no-ops. 20 Hz is enough to keep
			-- assemblies from sleeping, and at 0.01 studs/s nothing drifts
			-- visibly between nudges. f3_body does not run while paused, so this
			-- needs its own counter rather than x6.f.
			x6.pause_tick = (x6.pause_tick or 0) + 1
			if x6.pause_tick % 3 ~= 0 then
				return
			end
			-- walking the dense array beats iterating the weak part table
			local arr = x6.active_array
			local data = x6.a
			for i = #arr, 1, -1 do
				local d = data[arr[i]]
				if d and d.lv then
					d.lv.VectorVelocity = ANTI_SLEEP
				end
			end
			return
		end
		pcall(f3_body, real_dt)
	end

	function x4.ProcessQueue()
		local queue = x6.claim_queue
		-- Luau's # is a binary search, not a stored field, and the old loop paid
		-- for it four times per item (the while test, the read, the clear, and
		-- once inside every table.insert). Carrying the length in a local drops
		-- all of them. This runs every frame during the initial workspace sweep,
		-- when the queue is thousands of entries deep, so it is the difference
		-- between a smooth start and a stutter.
		local n = #queue
		if n == 0 then
			return
		end
		local start = os.clock()
		local processed = 0
		local claimed = 0
		while n > 0 do
			if processed >= 100 or claimed >= 8 or os.clock() - start > 0.001 then
				break
			end
			local instance = queue[n]
			queue[n] = nil
			n = n - 1
			processed = processed + 1
			if instance and instance:IsDescendantOf(v4) then
				for _, child in ipairs(instance:GetChildren()) do
					n = n + 1
					queue[n] = child
				end
				if instance:IsA("BasePart") then
					if x4.f1(instance) then
						claimed = claimed + 1
					end
				end
			end
		end
	end

	local function f4(real_dt)
		real_dt = real_dt or (1/60)
		if not x6.b or x1.Disabled then
			return
		end
		-- One root lookup, one copy of the "move the core onto it" code. The
		-- fall-through rules are unchanged: a selected-but-unreachable target
		-- parks the core, an unreachable self-anchor falls back to dragging.
		local track = nil
		if x1.TgtActive and x1.Targets and #x1.Targets > 0 then
			local tgt = x1.Targets[1]
			local root = root_of(tgt and tgt.Character)
			if not (root and ((x1.VoidProtection == false) or (root.Position.Y > v4.FallenPartsDestroyHeight + 50))) then
				return
			end
			track = root
		elseif x1.AnchorSelf then
			track = root_of(v8.Character)
		end
		if track then
			local pos = track.Position
			if x1.PredictiveTracking then
				pos = get_predicted_pos(track, x1.PredictionFactor or 150)
			end
			x6.b.Position = pos
			x6.b.AssemblyLinearVelocity = ZERO_VECTOR
			return
		end
		if x6.d then
			local c = v4.CurrentCamera
			if not c then
				return
			end
			x6.p = x6.p or (x6.b.Position - c.CFrame.Position).Magnitude
			local mp = v1:GetMouseLocation()
			local r = c:ViewportPointToRay(mp.X, mp.Y)
			local tp = r.Origin + (r.Direction * x6.p)
			local alpha = x9.c8 >= 1 and 1 or (1 - math.exp(-60 * real_dt * -math.log(math.max(0.001, 1 - x9.c8))))
			x6.b.Position = x6.b.Position:Lerp(tp, alpha)
			x6.b.AssemblyLinearVelocity = ZERO_VECTOR
		end
	end

	function x4.f1(p)
		if not p:IsA("BasePart") or x7.e(p) or x6.a[p] then
			return false
		end
		local old_attachment = p:FindFirstChild("GRV_ATT")
		local old_linear_velocity = p:FindFirstChild("GRV_LV")
		local old_angular_velocity = p:FindFirstChild("GRV_AV")
		if old_attachment then old_attachment:Destroy() end
		if old_linear_velocity then old_linear_velocity:Destroy() end
		if old_angular_velocity then old_angular_velocity:Destroy() end
		local original_can_collide = p.CanCollide
		local original_anchored = p.Anchored
		local original_properties = p.CustomPhysicalProperties
		-- A part claimed while the script is disabled has to land in the same state
		-- as the ones already held, or it would hang frozen in mid-air with its
		-- collision stripped until the next enable. x4.apply_disabled re-applies
		-- all three of these to every part when the flag flips.
		if not (x1.PreserveCollisions or x1.Disabled) then
			p.CanCollide = false
		end
		p.Anchored = false
		if not x1.Disabled then
			p.CustomPhysicalProperties = LIGHT_PHYSICS
		end
		-- Parent last: every property set on an already-parented instance costs a
		-- replication/physics update the engine then has to throw away.
		local a = Instance.new("Attachment")
		a.Name = "GRV_ATT"

		local lv = Instance.new("LinearVelocity")
		lv.Name = "GRV_LV"
		lv.MaxForce = x1.Disabled and 0 or x1.k4
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Attachment0 = a

		local av = Instance.new("AngularVelocity")
		av.Name = "GRV_AV"
		av.MaxTorque = x1.Disabled and 0 or math.huge
		av.RelativeTo = Enum.ActuatorRelativeTo.World
		av.AngularVelocity = Vector3.zero
		av.Attachment0 = a

		a.Parent = p
		lv.Parent = p
		av.Parent = p

		x6.part_id_counter = (x6.part_id_counter or 0) + 1
		x6.a[p] = {
			at = a,
			lv = lv,
			av = av,
			integral = Vector3.zero,
			claim_t = time(),
			id = x6.part_id_counter,
			original_can_collide = original_can_collide,
			original_anchored = original_anchored,
			original_properties = original_properties,
		}
		table.insert(x6.active_array, p)
		x6.n = x6.n + 1
		return true
	end

	-- Hoisted out of x4.f2 so releasing a few thousand parts does not allocate a
	-- few thousand closures on the way out.
	function f2_restore(p, d, drop_release)
		if d then
			p.CanCollide = d.original_can_collide
			p.Anchored = d.original_anchored
			p.CustomPhysicalProperties = d.original_properties
		end
		if drop_release then
			p.AssemblyLinearVelocity = ZERO_VECTOR
			p.AssemblyAngularVelocity = ZERO_VECTOR
		end
	end

	function x4.f2(p, drop_release, active_index)
		local d = x6.a[p]
		pcall(f2_restore, p, d, drop_release)
		if d then
			if d.at and d.at.Parent then
				d.at:Destroy()
			end
			if d.lv and d.lv.Parent then
				d.lv:Destroy()
			end
			if d.av and d.av.Parent then
				d.av:Destroy()
			end
			x6.a[p] = nil
		end
		local idx = active_index
		if not idx or x6.active_array[idx] ~= p then
			idx = table.find(x6.active_array, p)
		end
		if idx then
			local arr = x6.active_array
			local last = #arr
			if idx ~= last then
				arr[idx] = arr[last]
			end
			-- the element being dropped is always the last one by this point, so
			-- table.remove's shift machinery and return value are pure overhead.
			-- Releasing a few thousand parts at once is where it showed up as a
			-- visible hitch; this matches what the sweep loop already does.
			arr[last] = nil
			x6.n = math.max(0, x6.n - 1)
		end
	end

	function x4.f3()
		pcall(function()
			settings().Physics.AllowSleep = false
		end)

		-- These used to be six fresh anonymous closures allocated every half
		-- second, plus one more per remote player, purely so pcall had something
		-- to call. Naming them once turns that per-tick allocation into upvalue
		-- reads and lets pcall take its arguments directly.
		local function suppress_player(p)
			p.MaximumSimulationRadius = 0
			if sethiddenproperty then
				sethiddenproperty(p, "SimulationRadius", 0)
			end
		end
		local function wake_self()
			if sethiddenproperty then
				sethiddenproperty(v8, "NetworkIsSleeping", false)
			end
		end
		local function make_scriptable()
			if setscriptable then
				setscriptable(v8, "SimulationRadius", true)
				setscriptable(v8, "MaximumSimulationRadius", true)
			end
		end
		local function raise_max_radius()
			v8.MaximumSimulationRadius = 9e9
		end
		local function raise_sim_radius()
			if sethiddenproperty then
				sethiddenproperty(v8, "SimulationRadius", 9e9)
				sethiddenproperty(v8, "MaximumSimulationRadius", 9e9)
			elseif setsimulationradius then
				setsimulationradius(9e9)
			end
		end
		local function focus_replication()
			v8.ReplicationFocus = x6.b or nil
		end

		local last_upd = 0
		table.insert(
			x6.c,
			v3.Heartbeat:Connect(function()
				local now = time()
				if now - last_upd > 0.5 then
					last_upd = now
					-- Only while the engine is actually running. This writes to *other*
					-- players, and x4.f5 does not drain x6.c (it cannot -- the hotkey
					-- listeners live there too, so draining it would make the script
					-- unrestartable), so without this gate "Stop" left every other
					-- player pinned at SimulationRadius 0 for the rest of the session.
					if x6.o then
						for _, p in ipairs(v2:GetPlayers()) do
							if p ~= v8 then
								pcall(suppress_player, p)
							end
						end
					end
					pcall(wake_self)
					pcall(make_scriptable)
					pcall(raise_max_radius)
					pcall(raise_sim_radius)
					pcall(focus_replication)
				end
			end)
		)
		-- Targets hold live Player objects and nothing ever pruned them. A player who
		-- leaves stays in the list: the HUD keeps reading DisplayName off a destroyed
		-- instance and reports ACTIVE forever, and f3_body tracks Targets[1] -- whose
		-- root is now nil -- so it returns before the AnchorSelf and mouse-drag
		-- fallbacks and the core parks with no explanation. Worse on rejoin, since
		-- Roblox issues a *new* Player object: table.find misses, the row draws
		-- unselected, and clicking it appends alongside the phantom, so the panel
		-- reads "Multi-Target (2)" for one person.
		table.insert(
			x6.c,
			v2.PlayerRemoving:Connect(function(pl)
				local tg = x1.Targets
				if type(tg) ~= "table" then
					return
				end
				local idx = table.find(tg, pl)
				while idx do
					table.remove(tg, idx)
					idx = table.find(tg, pl)
				end
				x1.TgtActive = #tg > 0
				local ui = context.x5
				if ui and ui.up then
					pcall(ui.up)
				end
			end)
		)
		local anti_fling_cache = setmetatable({}, {__mode = "k"})
		-- The DescendantAdded hook lives here, keyed weakly by character, instead
		-- of in x6.c. x6.c is a strong list only emptied on full teardown, so
		-- every respawn added an entry whose closure pinned that character's part
		-- array -- which is exactly why the weak cache above could never actually
		-- collect anything. A long session leaked one connection and one array
		-- per respawn. Held weakly, both go away with the character (Destroy
		-- severs the signal on its own).
		local anti_fling_conns = setmetatable({}, {__mode = "k"})
		local function connect_parts(char, parts)
			return char.DescendantAdded:Connect(function(desc)
				if desc:IsA("BasePart") then
					parts[#parts + 1] = desc
				end
			end)
		end
		local af_tick = 0
		table.insert(
			x6.c,
			v3.Stepped:Connect(function()
				if not x6.o or not x1.AntiFling or x1.PreserveCollisions then
					return
				end
				-- 20 Hz is plenty. The server is what re-enables collisions, and it
				-- does not do it every frame, so sweeping every frame was paying
				-- roughly twenty thousand property reads a second for nothing.
				af_tick = af_tick + 1
				if af_tick % 3 ~= 0 then
					return
				end
				for _, p in ipairs(v2:GetPlayers()) do
					-- p.Character was re-read five times per player per tick, each
					-- one an engine crossing. Now read once.
					local char = p ~= v8 and p.Character or nil
					if char then
						local parts = anti_fling_cache[char]
						if not parts then
							parts = {}
							for _, part in ipairs(char:GetDescendants()) do
								if part:IsA("BasePart") then
									parts[#parts + 1] = part
								end
							end
							anti_fling_cache[char] = parts
							local ok, conn = pcall(connect_parts, char, parts)
							if ok then
								anti_fling_conns[char] = conn
							end
						end
						for i = #parts, 1, -1 do
							local part = parts[i]
							if part and part.Parent then
								if part.CanCollide then
									part.CanCollide = false
								end
							else
								table.remove(parts, i)
							end
						end
					end
				end
			end)
		)
	end

	-- Whether the core ball is shown, in one place. Three call sites used to
	-- decide it independently (creation, apply_disabled, and nothing at all for
	-- pause), which is why adding a second reason to hide it needed a single
	-- owner. Hidden means invisible, not inert: the part stays anchored where it
	-- is and a tap still finds it, so dragging the core around while it is hidden
	-- keeps working exactly as it already did while Disabled.
	local function refresh_core_visual()
		if not x6.b then
			return
		end
		local hidden = x1.Disabled or (x1.HideCoreOnPause and x1.Paused) or false
		x6.b.Transparency = hidden and 1 or x9.c7
		local visual = x6.b:FindFirstChild("Visual")
		if visual then
			visual.Enabled = not hidden
		end
	end
	x4.refresh_core_visual = refresh_core_visual

	function x4.f4(pos)
		if x6.b then
			v6:Create(x6.b, TweenInfo.new(x9.c7), { Position = pos }):Play()
			return
		end
		local f = Instance.new("Folder", v4)
		f.Name = "AS"
		x6.b = Instance.new("Part", f)
		x6.b.Size = x1.k2
		x6.b.Shape = "Ball"
		x6.b.Color = x1.k3
		x6.b.Anchored = true
		x6.b.CanCollide = false
		x6.b.Material = "Neon"
		x6.b.Position = pos
		local bg = Instance.new("BillboardGui", x6.b)
		bg.Name = "Visual"
		bg.Adornee = x6.b
		bg.Size = UDim2.new(0, 20, 0, 20)
		bg.AlwaysOnTop = true
		local img = Instance.new("ImageLabel", bg)
		img.BackgroundTransparency = 1
		img.Size = UDim2.new(1, 0, 1, 0)
		img.Image = "rbxassetid://3570695787"
		img.ImageColor3 = x1.k3
		-- Disabled survives a restart through the settings file, so the core has to
		-- come up already hidden in that case rather than showing a visible marker
		-- for something that is not driving anything. After the BillboardGui exists,
		-- so the one call covers both the part and the sprite.
		refresh_core_visual()
		v6
			:Create(
				x6.b,
				TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Size = x1.k2 * 1.2 }
			)
			:Play()
		table.clear(x6.claim_queue)
		for _, child in ipairs(v4:GetChildren()) do
			if child ~= f then
				table.insert(x6.claim_queue, child)
			end
		end

		x6.run_connections = x6.run_connections or {}
		table.insert(
			x6.run_connections,
			v4.DescendantAdded:Connect(function(v)
				if v:IsA("BasePart") then
					table.insert(x6.claim_queue, v)
				end
			end)
		)
		x6.o = true
		x7.n("Sys", "Started", 3)
		-- Refresh the panel if it is open; do not resurrect it if the user closed it.
		-- x5.st() rebuilds from scratch whenever x5.g is nil, and the panel's X button
		-- nils it (UI.lua sg.Destroying) -- so pressing Recenter after closing the
		-- panel used to rebuild the whole thing, and every rebuild strands another
		-- five service-level connections in x6.c that only full teardown clears.
		if x5.g then
			x5.st()
		end
		table.insert(
			x6.run_connections,
			v3.Heartbeat:Connect(function(real_dt)
				f3(real_dt)
				f4(real_dt)
				x4.ProcessQueue()
			end)
		)
	end

	-- Release every claimed part but leave the core where it is. The action dock
	-- has always called this; it just never existed until now.
	function x4.clean_physics()
		-- The old loop took the array length three times per part (the while
		-- test, the index, and the argument), and # is a binary search in Luau.
		-- A plain descending index removes ~15k probes on a 5000 part release.
		-- f2 always drops the element at the index it is handed, which is the
		-- current last, so walking downward stays in step with the shrinking array.
		local arr = x6.active_array
		local released = #arr
		for k = released, 1, -1 do
			x4.f2(arr[k], true, k)
		end
		table.clear(x6.claim_queue)
		x7.n("Sys", released .. " parts released", 2)
	end

	-- Disabling is clean_physics without giving up the claim: the constraints stay
	-- on the part so enabling picks up instantly, but nothing drives it and it gets
	-- its collision back, so it falls and lands like a released part in the
	-- meantime. Enabling reverses both halves. Hoisted out of the loop below so a
	-- 5000 part toggle does not allocate a closure per part for pcall.
	local function apply_disabled_part(p, d, disabled)
		if d.lv then
			d.lv.MaxForce = disabled and 0 or x1.k4
		end
		if d.av then
			d.av.MaxTorque = disabled and 0 or math.huge
		end
		p.CanCollide = (disabled or x1.PreserveCollisions or d.pc_ride) and d.original_can_collide or false
		-- LIGHT_PHYSICS is what lets the constraints throw a part around; at 0.001
		-- density a disabled part would be shoved across the map by the first thing
		-- that touched it instead of resting where it landed. Anchored is left alone
		-- because x7.e refuses to claim an anchored part in the first place.
		-- Not an `and/or` chain: original_properties is nil on any part that never
		-- overrode its material defaults, and nil is falsy, so that would hand every
		-- such part LIGHT_PHYSICS back on the disable branch.
		if disabled then
			p.CustomPhysicalProperties = d.original_properties
		elseif d.pc_ride then
			p.CustomPhysicalProperties = d.original_properties or PhysicalProperties.new(0.7, 0.5, 0.3, 1, 1)
		else
			p.CustomPhysicalProperties = LIGHT_PHYSICS
			-- Parts fall while disabled, so every cached smoothing term now
			-- describes a position they have long since left. d.last_target_pos in
			-- particular is differentiated against the live target, and dividing a
			-- whole fall's worth of displacement by one frame injects thousands of
			-- studs/s -- the same re-seat fling f3_body's target-velocity clamp
			-- exists to stop. Clearing them makes enabling a fresh lift-off.
			d.vl = nil
			d.trans_vl = nil
			d.last_target_pos = nil
			d.sys_last_t = nil
			d.parked = nil
			d.integral = Vector3.zero
			-- The cached terms above are Lua-side; these are the live properties the
			-- engine is still holding. f3 returns early while disabled, so nothing
			-- overwrites them, and MaxForce goes back to x1.k4 (math.huge) here --
			-- before the sweep next reaches this part, which is only once every
			-- x1.k7 frames. Left armed, the part is driven at its pre-disable
			-- velocity at infinite force for those frames: exactly the fling the
			-- comment above is about.
			if d.lv then
				d.lv.VectorVelocity = ZERO_VECTOR
			end
			if d.av then
				d.av.AngularVelocity = ZERO_VECTOR
			end
		end
	end

	-- The one entry point for the flag: the L hotkey, the UI toggle, the mobile
	-- action dock and the AI tool all come through here, so none of them can leave
	-- the parts half-switched. The core visuals are handled whether or not the
	-- panel is open.
	function x4.apply_disabled(disabled)
		disabled = disabled and true or false
		x1.Disabled = disabled
		if disabled then
			-- A shape-owned instance is part of the shape running. Platform's pad in
			-- particular would otherwise be left as a solid slab hanging in the air
			-- with nothing updating it. px rebuilds it on the first enabled frame.
			cleanup_shape(x1.k6)
		end
		if x6.b then
			refresh_core_visual()
		end
		-- the dense array again, rather than iterating the weak part table
		local arr = x6.active_array
		local data = x6.a
		for k = #arr, 1, -1 do
			local p = arr[k]
			local d = p and data[p]
			if d then
				pcall(apply_disabled_part, p, d, disabled)
			end
		end
	end

	function x4.f5()
		-- Before the core folder goes, so a shape-owned instance living inside it is
		-- released deliberately rather than only incidentally.
		cleanup_shape(x1.k6)
		if x6.b then
			x6.b.Parent:Destroy()
			x6.b = nil
		end
		-- same descending walk as clean_physics: three length probes per part
		-- became none, which is what made stopping with a large claim hitch.
		local arr = x6.active_array
		for k = #arr, 1, -1 do
			x4.f2(arr[k], false, k)
		end
		for _, connection in ipairs(x6.run_connections or {}) do
			connection:Disconnect()
		end
		table.clear(x6.run_connections or {})
		table.clear(x6.claim_queue)
		x6.o = false
		-- Target markers are BillboardGuis parented onto other players' heads, and the
		-- only code that removed one lived inside f3_body's once-a-second block --
		-- which stops running the moment the engine stops. So stopping, pausing or
		-- disabling left the red marker floating over whoever was targeted.
		for _, pl in ipairs(v2:GetPlayers()) do
			local ch = pl.Character
			local head = ch and ch:FindFirstChild("Head")
			local marker = head and head:FindFirstChild("GravityTargetMarker")
			if marker then
				pcall(function()
					marker:Destroy()
				end)
			end
		end
		-- Sculptor selections are per-run: the SelectionBoxes are parented to world
		-- parts, so leaving them adorned after "Stop" leaves cyan boxes in the map.
		if x6.sculptor_clear then
			pcall(x6.sculptor_clear)
		end
		if x6.pc_clear then
			pcall(x6.pc_clear)
		end
		if x6.sculptor_selected then
			table.clear(x6.sculptor_selected)
		end
		if x6.pc_selected then
			table.clear(x6.pc_selected)
		end
		x6.pc_active = false
		-- Same as f4: refresh an open panel, never rebuild a closed one.
		if x5.g then
			x5.st()
		end
		x7.n("Sys", "Stopped", 2)
	end

	function x8.h(n, s, o)
		if s ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if n == "C" then
			x4.f4(v9.Hit.p)
			return Enum.ContextActionResult.Sink
		elseif n == "R" then
			x4.f5()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end

	-- Same helper the desktop tree uses. x1.Keybinds is shared through
	-- GravitySettings_Auto.json, so this tree hardcoding E/Q/P/L meant a rebind made
	-- on desktop silently did not apply here -- and the ready toast below announced a
	-- key that was no longer bound.
	local function key_from_name(name)
		if type(name) ~= "string" or name == "" then
			return nil
		end
		local ok, code = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok and typeof(code) == "EnumItem" and code ~= Enum.KeyCode.Unknown then
			return code
		end
		return nil
	end

	local function bind(action, fn, key_name, fallback)
		local code = key_from_name(key_name) or fallback
		if not code then
			return
		end
		-- pcall like the desktop tree: x8.i runs inside main.lua's init pcall, so a
		-- throw out of BindAction took the whole script down.
		pcall(function()
			v7:BindAction(action, fn, false, code)
		end)
	end

	-- Touch does not drive Mouse.Target, so acquiring the core by finger needs a real
	-- raycast -- the same thing System_sculptor in this tree already does. Accepting
	-- Touch while still testing v9.Target made core dragging unreliable on the only
	-- devices that load this file.
	local function pick_at(input)
		local cam = v4.CurrentCamera
		if not cam or not input or not input.Position then
			return nil
		end
		local ray = cam:ViewportPointToRay(input.Position.X, input.Position.Y)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { v8.Character }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, rp)
		return hit and hit.Instance
	end

	function x8.i()
		local kb = x1.Keybinds or {}
		bind("C", x8.h, kb.Recenter, Enum.KeyCode.E)
		bind("R", x8.h, kb.Reset, Enum.KeyCode.Q)
		bind("P", function(_, s)
			if s == Enum.UserInputState.Begin then
				x1.Paused = not x1.Paused
				-- Hide Core While Paused is toggled here as well as in the panel,
				-- so this is the call site that actually matters.
				refresh_core_visual()
				x7.n("Sys", x1.Paused and "Paused" or "Resumed", 2)
			end
		end, kb.Pause, Enum.KeyCode.P)
		bind("Disable", function(_, st)
			if st == Enum.UserInputState.Begin then
				x4.apply_disabled(not x1.Disabled)
				x7.n("Sys", "Script " .. (x1.Disabled and "Disabled" or "Enabled"), 2)
				-- Repaint, or the panel's Disable toggle keeps the state it was built
				-- with and its next click is a no-op.
				local ui = context.x5
				if ui and ui.up then
					pcall(ui.up)
				end
			end
		end, kb.Disable, Enum.KeyCode.L)
		table.insert(
			x6.c,
			v1.InputBegan:Connect(function(i, p)
				if p or not x6.b then
					return
				end
				local touch = i.UserInputType == Enum.UserInputType.Touch
				if touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
					local target = touch and pick_at(i) or v9.Target
					if target == x6.b then
						x6.d = true
						x6.p = (v4.CurrentCamera and (x6.b.Position - v4.CurrentCamera.CFrame.Position).Magnitude) or 50
					end
				end
			end)
		)
		table.insert(
			x6.c,
			v1.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					x6.d = false
				end
			end)
		)

		local sculptor_builder = load_module(SUB_DIR .. "System_sculptor.lua")
		if sculptor_builder then
			local binder = sculptor_builder(context, x7)
			if binder then
				binder()
			end
		end

		local partctl_builder = load_module(SUB_DIR .. "System_partctl.lua")
		if partctl_builder then
			local binder = partctl_builder(context, x7)
			if binder then
				binder()
			end
		end

		-- Announce the key that is actually bound, not a literal. The dock is the
		-- real entry point on touch, so say that when there is no key at all.
		local recenter = kb.Recenter
		if type(recenter) == "string" and recenter ~= "" then
			x7.n("Rdy", "Press '" .. recenter .. "' or tap PLC", 5)
		else
			x7.n("Rdy", "Tap PLC to place the core", 5)
		end
	end

	return { x4 = x4, x8 = x8 }
end
