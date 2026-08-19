local M = {}

local uis = game:GetService("UserInputService")
local plrs = game:GetService("Players")

local UP = Vector3.new(0, 1, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)

local R2_A = 0.7548776662466927
local R2_B = 0.5698402909980532
local PHI = 0.6180339887498949

-- Where the broom is pointed. Mouse.Hit first, since it already accounts for
-- whatever the game does to the cursor; the viewport raycast is the fallback for
-- when it returns nothing usable, and the far-plane point is the last resort so
-- aiming at open sky still gives a direction instead of freezing the broom.
local function aim_point()
	local lp = plrs.LocalPlayer
	local mouse = lp and lp:GetMouse()
	if mouse and mouse.Hit then
		local hit = mouse.Hit.Position
		if hit.Magnitude < 10000 then
			return hit
		end
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local loc = uis:GetMouseLocation()
	local ray = cam:ViewportPointToRay(loc.X, loc.Y)
	-- Claimed parts are all CanCollide = false locally, so respecting collision
	-- skips the broom's own body. Without this the fallback aims at whichever
	-- claimed part happens to be in front of the camera instead of the world.
	local rp = RaycastParams.new()
	rp.RespectCanCollide = true
	local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, rp)
	return res and res.Position or (ray.Origin + ray.Direction * 400)
end

-- Lazily connects input and keeps the connections on the state table so cleanup
-- can drop them. x6.pre survives a shape switch — only M.cleanup runs
-- (System.lua:152) — so a shape that connects without one leaks a listener per
-- switch, and every stale listener keeps writing into an abandoned state table.
local function get_state(x6)
	local st = x6.pre["Big Bad Broom"]
	if st then
		return st
	end

	local touch = uis.TouchEnabled and not uis.KeyboardEnabled
	st = {
		held = false,
		touch = touch,
		sweep = 0,
		last_x = nil,
		conns = {},
		frame = -1,
	}
	x6.pre["Big Bad Broom"] = st

	st.conns[#st.conns + 1] = uis.InputBegan:Connect(function(inp, gpe)
		if gpe then
			return
		end
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			st.held = true
			st.last_x = inp.Position.X
		end
	end)

	st.conns[#st.conns + 1] = uis.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			st.held = false
			st.last_x = nil
		end
	end)

	-- Swipe drives the sweep angle directly rather than through a velocity, so
	-- the head tracks the hand instead of coasting past where it was let go.
	st.conns[#st.conns + 1] = uis.InputChanged:Connect(function(inp, gpe)
		if gpe or not st.held then
			return
		end
		if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local x = inp.Position.X
		if st.last_x then
			st.sweep = st.sweep + (x - st.last_x) * 0.01
			if st.sweep > 3.2 then
				st.sweep = 3.2
			elseif st.sweep < -3.2 then
				st.sweep = -3.2
			end
		end
		st.last_x = x
	end)

	return st
end

function M.px(t, c, x6, x9, x1)
	local st = get_state(x6)

	-- Extension eases rather than snapping, so click-to-pop-out has some weight
	-- to it and does not teleport the head through whatever it is aimed at.
	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end
	local want = st.held and 1 or 0
	local ease = math.clamp(dt * 6, 0, 1)
	st.ext = (st.ext or 0) + (want - (st.ext or 0)) * ease

	local et = x1 and x1.k7
	if not et then
		local n = x6.n or 0
		et = n > 5000 and 10 or (n > 2500 and 6 or (n > 1000 and 3 or 1))
	end
	if x1 and x1["Force Smooth (Lags)"] then
		et = 1
	end
	if et < 1 then
		et = 1
	end

	local gen = math.floor((x6.f or 0) / et)
	if st.gen == gen then
		return
	end
	st.gen = gen

	-- The grip is not stamped here: px never receives cen, and anchoring to the
	-- character root ignores the anchor entirely, so the broom would not follow a
	-- moved centre or a selected target. f2 derives the grip from cen instead.
	st.aim = aim_point()
	st.pub_ext = st.ext
	st.pub_sweep = st.sweep
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local st = x6.pre and x6.pre["Big Bad Broom"]
	if not st or not st.aim then
		return ANTI_SLEEP, nil
	end

	-- Built off cen like every other shape, so the broom follows the anchor when
	-- you drag it and rides a selected target when one is picked. Grip Height
	-- lifts the hand off the centre; at 0 the broom swings straight out of it.
	local grip = cen + UP * (c.k19 or 3)

	-- The handle runs from the grip toward the cursor. Length is fixed by the
	-- slider rather than reaching all the way, so the broom keeps its shape
	-- whether you aim at your feet or the horizon.
	local dir = st.aim - grip
	if dir.Magnitude < 0.001 then
		dir = WORLD_FWD
	else
		dir = dir.Unit
	end

	local axis = math.floor(c.k15 or 1)
	-- The sweep pivots about an axis you pick: vertical pivots in the horizontal
	-- plane (a floor sweep), horizontal tips it up and down, side rolls it.
	local pivot
	local roll = 0
	if axis == 2 then
		pivot = dir:Cross(UP)
		if pivot.Magnitude < 0.001 then
			pivot = Vector3.new(1, 0, 0)
		end
		pivot = pivot.Unit
	elseif axis == 3 then
		-- Roll spins the head around the shaft; the shaft itself does not move.
		-- Pivoting about dir would be rotating a vector about itself, which is the
		-- identity for every angle -- the whole axis did nothing, sweep or not. The
		-- angle is handed to the head basis below instead, which is what actually
		-- carries the roll.
		roll = st.pub_sweep or 0
	else
		pivot = UP
	end
	local shaft = dir
	if pivot then
		shaft = CFrame.fromAxisAngle(pivot, st.pub_sweep or 0) * dir
	end

	local hlen = c.k11 or 60
	local ext = (st.pub_ext or 0) * (c.k14 or 25)
	local tip = grip + shaft * (hlen + ext)

	-- A frame on the head: across the sweep, and the head's own normal.
	local across = shaft:Cross(UP)
	if across.Magnitude < 0.001 then
		across = shaft:Cross(Vector3.new(1, 0, 0))
	end
	across = across.Unit
	local norm = shaft:Cross(across).Unit
	if roll ~= 0 then
		local rot = CFrame.fromAxisAngle(shaft, roll)
		across = rot * across
		norm = rot * norm
	end

	local id = d.id or 1
	local w1 = (id * R2_A) % 1
	local w2 = (id * R2_B) % 1
	local pick = (id * PHI) % 1

	local target_pos
	local share = (c.k13 or 35) / 100
	if pick < share then
		-- Handle: a thin line of parts from grip to head.
		local along = w1 * (hlen + ext)
		local a = w2 * math.pi * 2
		local rad = c.k16 or 2
		target_pos = grip + shaft * along + (across * math.cos(a) + norm * math.sin(a)) * rad
	else
		-- Head: a flat slab of bristles. No PreserveCollisions needed to crush
		-- with it — CanCollide = false (System.lua:720) is a local property and
		-- does not replicate, so other clients still resolve these parts as solid
		-- and press whoever the head is driven into.
		local w = c.k12 or 30
		local depth = (c.k17 or 8)
		local lx = (w1 - 0.5) * w
		local ly = (w2 - 0.5) * depth
		local reach = ((id * 0.3819660112501051) % 1) * (c.k18 or 10)
		target_pos = tip + across * lx + norm * ly + shaft * reach
	end

	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	local st = x6.pre and x6.pre["Big Bad Broom"]
	if not st then
		return
	end
	for _, conn in ipairs(st.conns or {}) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	x6.pre["Big Bad Broom"] = nil
end

M.Controls = {
	{ Type = "Slider", Name = "Handle · Length", Min = 10, Max = 300, Key = "k11", Default = 60 },
	{ Type = "Slider", Name = "Handle · Thickness", Min = 1, Max = 12, Key = "k16", Default = 2 },
	{ Type = "Slider", Name = "Handle · Share %", Min = 5, Max = 80, Key = "k13", Default = 35, IntOnly = true },
	{ Type = "Slider", Name = "Head · Width", Min = 5, Max = 150, Key = "k12", Default = 30 },
	{ Type = "Slider", Name = "Head · Depth", Min = 1, Max = 40, Key = "k17", Default = 8 },
	{ Type = "Slider", Name = "Head · Bristles", Min = 0, Max = 60, Key = "k18", Default = 10 },
	{ Type = "Slider", Name = "Extend On Hold", Min = 0, Max = 150, Key = "k14", Default = 25 },
	{ Type = "Slider", Name = "Sweep Axis (1 Flat, 2 Tip, 3 Roll)", Min = 1, Max = 3, Key = "k15", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Grip Height", Min = -40, Max = 120, Key = "k19", Default = 3 },
}

return M
