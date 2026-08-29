local M = {}

local PHI = 0.6180339887498949
local TAU = 6.283185307179586
local HM = 16777216

local function prng(s, n, ch)
	local v = ((s % 1048576) * 73856093 + n * 19349663 + ch * 83492791) % HM
	v = (v * v + v * 22695477 + 12345) % HM
	return v / HM
end

local function orth_basis(dir)
	local u = Vector3.new(-dir.Z, 0, dir.X)
	if u.Magnitude < 1e-4 then
		u = Vector3.new(1, 0, 0)
	else
		u = u.Unit
	end
	return u, dir:Cross(u).Unit
end

local function sphere_pt(idx, total)
	local y = 1 - (idx / math.max(1, total)) * 2
	local rad = math.sqrt(math.max(0, 1 - y * y))
	local theta = TAU * PHI * idx
	return Vector3.new(math.cos(theta) * rad, y, math.sin(theta) * rad)
end

local function get_cursor_world_hit(cam, uis, dist)
	dist = dist or 500
	local ok, res = pcall(function()
		local plrs = game:GetService("Players")
		local plr = plrs and plrs.LocalPlayer
		local mouse = plr and plr:GetMouse()
		if mouse and mouse.Hit then
			local p = mouse.Hit.Position
			if p and p.Magnitude < 10000 then
				return p
			end
		end
		if not cam or not uis then return nil end
		local ml = uis:GetMouseLocation()
		local ray = cam:ViewportPointToRay(ml.X, ml.Y)
		local cast = workspace:Raycast(ray.Origin, ray.Direction * dist)
		return cast and cast.Position or (ray.Origin + ray.Direction * dist)
	end)
	return (ok and res) or nil
end

local function get_touch_world_hit(cam, pos, dist)
	dist = dist or 500
	local ok, res = pcall(function()
		if not cam then return nil end
		local ray = cam:ViewportPointToRay(pos.X, pos.Y)
		local cast = workspace:Raycast(ray.Origin, ray.Direction * dist)
		return cast and cast.Position or (ray.Origin + ray.Direction * dist)
	end)
	return (ok and res) or nil
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local r_orb = math.clamp(c.k11 or 8, 2, 40)
	local v_flight = math.clamp(c.k12 or 250, 40, 1200)
	local r_blast = math.clamp(c.k13 or 80, 15, 400)
	local dur_blast = math.clamp(c.k14 or 0.7, 0.15, 3.0)
	local h_hover = math.clamp(c.k15 or 12, 3, 50)
	local num_arcs = math.clamp(math.floor(c.k16 or 8), 2, 24)
	-- Clamped like every other control here, and to its own slider's bounds. A
	-- negative jaggedness mirrors the noise rather than removing it, and a config
	-- file is not bound by the panel's Min/Max.
	local amp_arc = math.clamp(c.k17 or 12, 0, 50)
	local auto_ret = c.k18 ~= false
	local click_act = c.k19 ~= false
	local neon_on = c.k20 ~= false

	local st = x6.pre and x6.pre["Raigo"]
	if not st then
		st = {
			phase = "HOVER",
			orb_pos = cen + Vector3.new(0, h_hover, 0),
			start_pos = cen + Vector3.new(0, h_hover, 0),
			dest_pos = nil,
			t_launch = 0,
			t_blast = 0,
			t_ret = 0,
			rot = 0,
			seed = 1,
			last_f = -1,
		}
		if x6.pre then
			x6.pre["Raigo"] = st
		end
	end

	-- Read by the input handler, which outlives a toggle change: the connections
	-- are made once and cannot be re-made, so the live value has to reach them
	-- through the state table rather than through the closure.
	st.click_enabled = click_act

	if not st.conns then
		st.conns = {}
		local ok = pcall(function()
			local uis = game:GetService("UserInputService")
			local cam = workspace.CurrentCamera
			st.conns[#st.conns + 1] = uis.InputBegan:Connect(function(inp, gpe)
				if gpe or not st.click_enabled then return end
				local hit = nil
				if inp.UserInputType == Enum.UserInputType.MouseButton1 then
					hit = get_cursor_world_hit(cam, uis, 1000)
				elseif inp.UserInputType == Enum.UserInputType.Touch then
					hit = get_touch_world_hit(cam, inp.Position, 1000)
				end
				if hit and (st.phase == "HOVER" or st.phase == "RETURN") then
					st.phase = "LAUNCH"
					st.start_pos = st.orb_pos
					st.dest_pos = hit
					st.t_launch = t
				end
			end)
		end)
		if not ok then
			st.conns = nil
		end
	end

	-- FORCE LAUNCH is a latch, not a pulse: the button's own label flips on it and
	-- Twin Core Beam and Slingshot read it as a held state. Consuming it here
	-- (x1.IsLaunching = false) fired Raigo once and then desynced the button, which
	-- still read "RESET SYSTEM", and stole the flag from every other reader. Edge
	-- detection belongs in this shape's own state.
	local launching = x1.IsLaunching and true or false
	if launching and not st.last_launch and (st.phase == "HOVER" or st.phase == "RETURN") then
		local cam = workspace.CurrentCamera
		local uis = game:GetService("UserInputService")
		local hit = get_cursor_world_hit(cam, uis, 800)
			or (cen + (cam and cam.CFrame.LookVector or Vector3.new(0, 0, 1)) * 150)
		st.phase = "LAUNCH"
		st.start_pos = st.orb_pos
		st.dest_pos = hit
		st.t_launch = t
	end
	st.last_launch = launching

	local cur_f = x6.f or 0
	if st.last_f ~= cur_f then
		st.last_f = cur_f
		st.seed = st.seed + 1
		st.rot = (st.rot + 0.08) % TAU
	end
	local seed = st.seed
	local rot = st.rot

	local head_pos = cen + Vector3.new(0, h_hover, 0)
	local blast_prog = 0
	local blast_ctr = st.dest_pos or head_pos

	if st.phase == "HOVER" then
		st.orb_pos = st.orb_pos:Lerp(head_pos, 0.15)
	elseif st.phase == "LAUNCH" then
		local dest = st.dest_pos or head_pos
		local total_dist = (dest - st.start_pos).Magnitude
		local flight_time = total_dist / v_flight
		local elapsed = t - st.t_launch
		local alpha = flight_time > 0 and math.clamp(elapsed / flight_time, 0, 1) or 1
		st.orb_pos = st.start_pos:Lerp(dest, alpha)
		if alpha >= 1 or (st.orb_pos - dest).Magnitude < 3 then
			st.phase = "EXPLODE"
			st.t_blast = t
			st.blast_origin = dest
		end
	elseif st.phase == "EXPLODE" then
		blast_ctr = st.blast_origin or st.orb_pos
		local elapsed = t - st.t_blast
		blast_prog = math.clamp(elapsed / dur_blast, 0, 1)
		st.orb_pos = blast_ctr
		if elapsed >= dur_blast then
			if auto_ret then
				st.phase = "RETURN"
				st.t_ret = t
				st.start_pos = blast_ctr
			else
				st.phase = "HOVER"
				st.orb_pos = head_pos
			end
		end
	elseif st.phase == "RETURN" then
		local elapsed = t - st.t_ret
		local ret_dist = (head_pos - st.start_pos).Magnitude
		local ret_time = math.max(0.3, ret_dist / (v_flight * 1.5))
		local alpha = math.clamp(elapsed / ret_time, 0, 1)
		local ease = alpha * alpha * (3 - 2 * alpha)
		st.orb_pos = st.start_pos:Lerp(head_pos, ease)
		if alpha >= 1 or (st.orb_pos - head_pos).Magnitude < 2 then
			st.phase = "HOVER"
			st.orb_pos = head_pos
		end
	end

	local id = d.id or 1
	local total_pts = math.max(1, x6.n or 50)
	local orb_center = st.orb_pos

	local final_pos = nil

	if st.phase == "EXPLODE" then
		local exp_ease = 1 - (1 - blast_prog) * (1 - blast_prog)
		local cur_rad = r_orb + (r_blast - r_orb) * exp_ease
		local frac = (id * PHI) % 1

		if frac < 0.45 then
			local s_pt = sphere_pt(id, math.max(1, math.floor(total_pts * 0.45)))
			local jx = (2 * prng(seed, id, 1) - 1) * (amp_arc * (1 - blast_prog))
			local jy = (2 * prng(seed, id, 2) - 1) * (amp_arc * (1 - blast_prog))
			local jz = (2 * prng(seed, id, 3) - 1) * (amp_arc * (1 - blast_prog))
			final_pos = blast_ctr + s_pt * cur_rad + Vector3.new(jx, jy, jz)
		elseif frac < 0.85 then
			local arc_idx = math.floor((frac - 0.45) / 0.40 * num_arcs)
			local s_dir = sphere_pt(arc_idx * 3 + 1, num_arcs * 3)
			local seg_prog = ((id * 7) % 17) / 16
			local seg_len = cur_rad * 1.25 * seg_prog
			local u, v = orth_basis(s_dir)
			local w = math.sin(math.pi * seg_prog)
			local arc_j1 = (2 * prng(seed, id, 4) - 1) * (amp_arc * 1.5 * w)
			local arc_j2 = (2 * prng(seed, id, 5) - 1) * (amp_arc * 1.5 * w)
			final_pos = blast_ctr + s_dir * seg_len + u * arc_j1 + v * arc_j2
		else
			local spark_dir = sphere_pt(id * 11, total_pts)
			local spark_dist = cur_rad * (0.8 + 0.4 * prng(seed, id, 6))
			final_pos = blast_ctr + spark_dir * spark_dist
		end
	else
		local frac = (id * PHI) % 1
		if frac < 0.55 then
			local s_pt = sphere_pt(id, math.max(1, math.floor(total_pts * 0.55)))
			local c_rot = math.cos(rot)
			local s_rot = math.sin(rot)
			local rx = s_pt.X * c_rot - s_pt.Z * s_rot
			local rz = s_pt.X * s_rot + s_pt.Z * c_rot
			local r_pt = Vector3.new(rx, s_pt.Y, rz)
			local jx = (2 * prng(seed, id, 7) - 1) * (amp_arc * 0.25)
			local jy = (2 * prng(seed, id, 8) - 1) * (amp_arc * 0.25)
			local jz = (2 * prng(seed, id, 9) - 1) * (amp_arc * 0.25)
			final_pos = orb_center + r_pt * r_orb + Vector3.new(jx, jy, jz)
		elseif frac < 0.85 then
			local a_idx = math.floor((frac - 0.55) / 0.30 * num_arcs)
			local theta_base = (a_idx / num_arcs) * TAU + rot * 1.5
			local seg_p = ((id * 5) % 19) / 18
			local phi_ang = (seg_p - 0.5) * math.pi * 0.85
			local r_scale = r_orb * (1 + 0.25 * math.sin(seg_p * math.pi))
			local ax = math.cos(theta_base) * math.cos(phi_ang) * r_scale
			local ay = math.sin(phi_ang) * r_scale
			local az = math.sin(theta_base) * math.cos(phi_ang) * r_scale
			local w = math.sin(seg_p * math.pi)
			local j1 = (2 * prng(seed, id, 10) - 1) * (amp_arc * 0.5 * w)
			local j2 = (2 * prng(seed, id, 11) - 1) * (amp_arc * 0.5 * w)
			final_pos = orb_center + Vector3.new(ax + j1, ay + j2, az + j1)
		else
			local tend_idx = math.floor((frac - 0.85) / 0.15 * num_arcs)
			local t_dir = sphere_pt(tend_idx * 7 + 3, num_arcs * 7)
			local t_prog = ((id * 3) % 13) / 12
			local t_len = r_orb * (1 + 0.8 * t_prog)
			local u, v = orth_basis(t_dir)
			local tj1 = (2 * prng(seed, id, 12) - 1) * (amp_arc * 0.4 * t_prog)
			local tj2 = (2 * prng(seed, id, 13) - 1) * (amp_arc * 0.4 * t_prog)
			final_pos = orb_center + t_dir * t_len + u * tj1 + v * tj2
		end

		if st.phase == "LAUNCH" then
			-- dest and start coincide when the orb is clicked where it already is.
			-- Vector3.zero.Unit is NaN in Roblox, and a NaN offset propagates into
			-- p.Position through the constraint, so the part is gone for good.
			local travel = (st.dest_pos or st.orb_pos) - st.start_pos
			if travel.Magnitude > 1e-3 and frac > 0.65 then
				local vel_dir = travel.Unit
				local trail_len = math.clamp(v_flight * 0.08, 5, 40)
				local trail_drag = (id % 5) / 4 * trail_len
				final_pos = final_pos - vel_dir * trail_drag
			end
		end
	end

	if neon_on then
		local col = x1.k3 or Color3.fromRGB(0, 255, 255)
		if p.Material ~= Enum.Material.Neon then
			p.Material = Enum.Material.Neon
		end
		if p.Color ~= col then
			p.Color = col
		end
	end

	local delta = (final_pos - p.Position) * (x1.k10 * x9.c1)
	return delta, final_pos
end

function M.cleanup(x6, x1)
	if not x6 or not x6.pre then
		return
	end
	local st = x6.pre["Raigo"]
	if st and st.conns then
		for _, conn in ipairs(st.conns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		-- Emptied as well as disconnected: cleanup can run while the same state
		-- table is still reachable (Part Control unrefs a module without dropping
		-- x6.pre), and a second pass would then Disconnect dead connections.
		table.clear(st.conns)
		st.conns = nil
		st.click_enabled = false
	end
	x6.pre["Raigo"] = nil
end

M.Controls = {
	{ Type = "Slider", Name = "Orb Radius", Min = 2, Max = 40, Key = "k11", Default = 8 },
	{ Type = "Slider", Name = "Flight Speed", Min = 40, Max = 1200, Key = "k12", Default = 250 },
	{ Type = "Slider", Name = "Blast Radius", Min = 15, Max = 400, Key = "k13", Default = 80 },
	{ Type = "Slider", Name = "Blast Duration", Min = 2, Max = 30, Key = "k14", Default = 7, Div = 10 },
	{ Type = "Slider", Name = "Hover Height", Min = 3, Max = 50, Key = "k15", Default = 12 },
	{ Type = "Slider", Name = "Arc Count", Min = 2, Max = 24, Key = "k16", Default = 8, IntOnly = true },
	{ Type = "Slider", Name = "Arc Jaggedness", Min = 0, Max = 50, Key = "k17", Default = 12 },
	{ Type = "Toggle", Name = "Auto Recall", Key = "k18", Default = true },
	{ Type = "Toggle", Name = "Click To Fire", Key = "k19", Default = true },
	{ Type = "Toggle", Name = "Neon Glow", Key = "k20", Default = true },
}

return M
