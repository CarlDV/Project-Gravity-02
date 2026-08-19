local M = {}

local uis = game:GetService("UserInputService")
local plrs = game:GetService("Players")

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local state = x6.pre["Twin Core Beam"]
	if not state then
		local is_touch = uis.TouchEnabled and not uis.KeyboardEnabled
		state = {
			active_beam = false,
			target_point = Vector3.zero,
			holding = false,
			touch_mode = is_touch,
			tap_locked = false,
			last_frame = -1
		}
		x6.pre["Twin Core Beam"] = state

		-- Parked so cleanup can drop them. x6.pre survives a shape switch -- only
		-- M.cleanup runs (System.lua:152) -- so without this the two listeners stay
		-- connected for the session and keep writing into this state table from
		-- input made while a completely different shape is active. On touch that
		-- meant every tap anywhere flipped tap_locked. They also survived
		-- re-execution, since main.lua's teardown asks each shape's cleanup.
		state.conns = {}

		state.conns[#state.conns + 1] = uis.InputBegan:Connect(function(inp, gpe)
			if gpe then return end
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				state.holding = true
			elseif inp.UserInputType == Enum.UserInputType.Touch then
				if state.touch_mode then
					state.tap_locked = not state.tap_locked
				else
					state.holding = true
				end
			end
		end)

		state.conns[#state.conns + 1] = uis.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				state.holding = false
			elseif inp.UserInputType == Enum.UserInputType.Touch and not state.touch_mode then
				state.holding = false
			end
		end)
	end

	if state.last_frame ~= x6.f then
		state.last_frame = x6.f
		local fire_override = x1.IsLaunching or (c.k18 == true)
		local should_fire = state.holding or state.tap_locked or fire_override

		if should_fire then
			local hit_pos = nil
			local local_plr = plrs.LocalPlayer
			local mouse = local_plr and local_plr:GetMouse()
			if mouse and mouse.Hit then
				hit_pos = mouse.Hit.Position
			end
			if not hit_pos or hit_pos.Magnitude > 10000 then
				local cam = workspace.CurrentCamera
				if cam then
					local mouse_loc = uis:GetMouseLocation()
					local ray = cam:ViewportPointToRay(mouse_loc.X, mouse_loc.Y)
					local res = workspace:Raycast(ray.Origin, ray.Direction * 1000)
					hit_pos = res and res.Position or (ray.Origin + ray.Direction * 400)
				end
			end
			if hit_pos then
				state.target_point = hit_pos
				state.active_beam = true
			else
				state.active_beam = false
			end
		else
			state.active_beam = false
		end
	end

	local active_items = x6.active_array
	local total_parts = #active_items
	if total_parts == 0 then
		return Vector3.zero, cen
	end

	local part_idx = d.id or 1
	local is_right = (part_idx % 2 == 0)
	local side_mult = is_right and 1 or -1
	local group_idx = math.floor((part_idx - 1) / 2) + 1
	local half_count = math.max(1, math.floor(total_parts / 2))
	local norm_idx = (group_idx - 1) % half_count

	local dist = c.k11 or 80
	local rad = c.k12 or 15
	local spd = (c.k13 or 150) * 0.015
	local fly_speed = c.k14 or 900
	local beam_spread = c.k15 or 4

	local rot_angle = t * spd
	local offset_vec = Vector3.new(math.cos(rot_angle) * dist * 0.5, math.sin(rot_angle * 0.5) * 4, math.sin(rot_angle) * dist * 0.5) * side_mult
	local orb_center = cen + offset_vec

	local gold_ratio = (1 + math.sqrt(5)) / 2
	local phi = math.acos(math.clamp(1 - 2 * (norm_idx + 0.5) / half_count, -1, 1))
	local theta = 2 * math.pi * norm_idx / gold_ratio + rot_angle * 3

	local sphere_offset = Vector3.new(
		math.sin(phi) * math.cos(theta) * rad,
		math.cos(phi) * rad,
		math.sin(phi) * math.sin(theta) * rad
	)

	local target_pos
	if state.active_beam then
		local dest = state.target_point
		local ray_vec = dest - orb_center
		local ray_dist = ray_vec.Magnitude
		
		if ray_dist > 1 then
			local ray_dir = ray_vec.Unit
			local stream_step = ((t * (fly_speed / 40) + norm_idx * 1.8) % ray_dist)
			
			local perp_u = Vector3.new(-ray_dir.Z, 0, ray_dir.X)
			if perp_u.Magnitude < 0.001 then
				perp_u = Vector3.new(1, 0, 0)
			else
				perp_u = perp_u.Unit
			end
			local perp_v = ray_dir:Cross(perp_u).Unit
			
			local spiral_phase = norm_idx * 0.6 + t * 15
			local wave_spread = beam_spread * math.sin((stream_step / ray_dist) * math.pi)
			local lateral_disp = (perp_u * math.cos(spiral_phase) + perp_v * math.sin(spiral_phase)) * wave_spread
			
			target_pos = orb_center + (ray_dir * stream_step) + lateral_disp
		else
			target_pos = orb_center + sphere_offset
		end
	else
		target_pos = orb_center + sphere_offset
	end

	return (target_pos - p.Position) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	if not x6.pre then
		return
	end
	local state = x6.pre["Twin Core Beam"]
	if state and state.conns then
		for _, conn in ipairs(state.conns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	x6.pre["Twin Core Beam"] = nil
end

M.Controls = {
	{ Type = "Slider", Name = "Orb Separation", Min = 10, Max = 200, Key = "k11", Default = 80 },
	{ Type = "Slider", Name = "Orb Radius", Min = 5, Max = 100, Key = "k12", Default = 15 },
	{ Type = "Slider", Name = "Rotation Speed", Min = 0, Max = 500, Key = "k13", Default = 150 },
	{ Type = "Slider", Name = "Beam Velocity", Min = 100, Max = 3000, Key = "k14", Default = 900 },
	{ Type = "Slider", Name = "Beam Spread", Min = 1, Max = 30, Key = "k15", Default = 4 },
	{ Type = "Toggle", Name = "Always Fire Beam", Key = "k18", Default = false }
}

return M
