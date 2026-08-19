local M = {}

local plrs = game:GetService("Players")

local UP = Vector3.new(0, 1, 0)
local WORLD_RIGHT = Vector3.new(1, 0, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)

-- R2 low-discrepancy sequence (the plastic number and its square). Part ids are
-- a sliding window sitting wherever x6.part_id_counter (System.lua:692) has got
-- to, never 1..n, so id % n clumps every part onto a handful of slots. Two
-- decorrelated irrational strides spread any id window evenly over the unit
-- square instead, which is what keeps the engine shell from growing bald
-- patches as parts churn.
local R2_A = 0.7548776662466927
local R2_B = 0.5698402909980532
local PHI = 0.6180339887498949

local function root_of(char)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

-- The two in-plane axes for each Axis setting. Circle sweeps u->v; the figure-8
-- uses v as its cross-over offset direction.
local function plane_of(mode)
	if mode == 2 then
		-- Upright, facing the camera: sweeps across and up.
		local cam = workspace.CurrentCamera
		local lv = cam and cam.CFrame.LookVector
		local flat = lv and Vector3.new(lv.X, 0, lv.Z)
		local fwd = (flat and flat.Magnitude > 0.001) and flat.Unit or WORLD_FWD
		return fwd:Cross(UP), UP
	elseif mode == 3 then
		-- Upright, edge-on to the camera.
		local cam = workspace.CurrentCamera
		local lv = cam and cam.CFrame.LookVector
		local flat = lv and Vector3.new(lv.X, 0, lv.Z)
		local fwd = (flat and flat.Magnitude > 0.001) and flat.Unit or WORLD_FWD
		return fwd, UP
	end
	return WORLD_RIGHT, WORLD_FWD
end

-- Advances the flight phase and stamps the frame's shared state.
--
-- px runs once per frame (System.lua:285) but f2 runs per part on its own bucket
-- frame (k7 = one frame in et), so anything f2 reads from here must hold still
-- for a whole cycle or the engine shears in half — the same constraint Hover
-- Text documents at Hover Text.lua:139. Hence the gen gate: phase integrates
-- every frame for smooth speed, but the values f2 reads only republish on a
-- cycle boundary. The target then steps at ~15 Hz, which the feed-forward
-- velocity term at System.lua:472-481 smooths back into continuous motion.
function M.px(t, c, x6, x9, x1)
	local st = x6.pre["Rocket Engine"]
	if not st then
		st = { phase = 0, pub = 0, t = t }
		x6.pre["Rocket Engine"] = st
	end

	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end
	-- Speed follows the house convention: the slider carries Div = 10, so the
	-- stored value is a tenth of what the panel shows, and x9.c2 turns that into
	-- radians per second the same way Celestial Ribbon and Hollow Worm do. Stored
	-- 15 is 0.75 rad/s, about an eight second orbit.
	st.phase = st.phase + dt * (c.k14 or 15) * x9.c2

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
	st.pub = st.phase

	local lp = plrs.LocalPlayer
	local root = lp and root_of(lp.Character)
	st.caster = root and root.Position or nil
	st.u, st.v = plane_of(c.k13 or 1)

	-- Hunt: work through the targets one at a time instead of orbiting whatever
	-- each part was dealt.
	--
	-- With Target Everyone on, System gives each part a different active_c
	-- (System.lua:446), which would split the engine into one thin rocket per
	-- player. Choosing a single quarry here and publishing it for every part keeps
	-- one whole rocket that visits them in turn. The roster is rebuilt each dwell
	-- and sorted by distance from you, so it opens on the nearest and re-sorts as
	-- people move, join or leave.
	if c.k21 ~= true or not st.caster then
		st.hunt = nil
		return
	end

	if not st.hunt_at or t >= st.hunt_at then
		local roster = {}
		if x1 and x1.PI_All then
			for _, pl in ipairs(plrs:GetPlayers()) do
				if pl ~= lp then
					local r = root_of(pl.Character)
					if r then
						roster[#roster + 1] = r
					end
				end
			end
		elseif x1 and x1.Targets then
			for _, pl in ipairs(x1.Targets) do
				local r = pl and pl.Parent and root_of(pl.Character)
				if r then
					roster[#roster + 1] = r
				end
			end
		end

		if #roster == 0 then
			-- hunt_root goes with them, or a dangling reference to a departed player
			-- is held for the rest of the session.
			st.hunt, st.hunt_at, st.hunt_root, st.hunt_i = nil, nil, nil, nil
			return
		end

		local from = st.caster
		table.sort(roster, function(a, b)
			return (a.Position - from).Magnitude < (b.Position - from).Magnitude
		end)

		-- Advance before reading, so the first pass opens on the nearest and each
		-- later one moves along. Wrapping on the current roster length means a
		-- shrinking lobby cannot leave the index stranded past the end.
		st.hunt_i = ((st.hunt_i or 0) % #roster) + 1
		st.hunt_root = roster[st.hunt_i]
		st.hunt = st.hunt_root.Position
		st.hunt_at = t + math.max(0.5, c.k22 or 4)
	elseif st.hunt_root and st.hunt_root.Parent then
		-- Keep tracking the quarry between rebuilds, so the rocket chases a moving
		-- player rather than the spot they stood on when the dwell began.
		st.hunt = st.hunt_root.Position
	else
		-- The quarry died or left mid-dwell. Falling through used to leave st.hunt
		-- holding their last position, so with Hunt · Seconds Each at its maximum the
		-- rocket orbited the spot where they died for up to thirty seconds. Expiring
		-- the dwell now re-rosters on the next call.
		st.hunt, st.hunt_at, st.hunt_root = nil, nil, nil
	end
end

-- Where the engine is on its path, and which way it is pointing.
--
-- Circle orbits cen. Figure-8 is a Gerono lemniscate stretched between the
-- caster and cen: it crosses at the midpoint and loops each end, which is the
-- infinity path from the request. System hands each part its own active_c,
-- round-robin across x1.Targets (System.lua:446), so with two targets selected
-- this draws two figure-8s — one per target, each still anchored on you — for
-- free. With no target selected cen collapses onto the caster, leaving nothing
-- to span, so it falls back to the circle rather than degenerating to a line.
local function flight(st, cen, c)
	local u, v = st.u or WORLD_RIGHT, st.v or WORLD_FWD
	local th = st.pub or 0
	local R = c.k11 or 120

	if (c.k12 or 1) >= 2 and st.caster then
		local span = cen - st.caster
		local len = span.Magnitude
		if len > 1 then
			local along = span / len
			local mid = st.caster + span * 0.5

			-- Which way the two lobes bulge. This used to fall out of the Plane
			-- slider via along:Cross(v), which coupled it to a control meant for the
			-- circle and gave an answer that depended on where the target happened
			-- to be standing -- two horizontal vectors cross to a vertical one, so
			-- the flat plane produced upright lobes. Both axes are now derived from
			-- the span itself and picked explicitly.
			local side = along:Cross(UP)
			if side.Magnitude < 0.001 then
				-- Target directly above or below: no horizontal perpendicular
				-- exists, so seed off a world axis instead.
				side = along:Cross(WORLD_RIGHT)
				if side.Magnitude < 0.001 then
					side = along:Cross(WORLD_FWD)
				end
			end

			if side.Magnitude > 0.001 then
				side = side.Unit
				-- side is horizontal and square to the span; crossing back gives the
				-- upright perpendicular in the vertical plane through the span.
				local perp = (c.k20 or 1) >= 2 and side or side:Cross(along).Unit

				local s, c2 = math.sin(th), math.cos(2 * th)
				local half = len * 0.5
				local pos = mid + along * (half * s) + perp * (R * 0.5 * math.sin(2 * th))
				local tan = along * (half * math.cos(th)) + perp * (R * c2)
				return pos, (tan.Magnitude > 0.001) and tan.Unit or along
			end
		end
	end

	local s, co = math.sin(th), math.cos(th)
	local pos = cen + (u * co + v * s) * R
	local tan = (v * co - u * s)
	return pos, (tan.Magnitude > 0.001) and tan.Unit or u
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local st = x6.pre and x6.pre["Rocket Engine"]
	if not st then
		return ANTI_SLEEP, nil
	end

	-- Hunt overrides the per-part cen so every part flies the same path; see px.
	local pos, tan = flight(st, st.hunt or cen, c)

	-- A stable frame around the flight direction. Cross against whichever world
	-- axis the tangent is least parallel to, so it never collapses at the poles.
	local ref = (math.abs(tan.Y) > 0.9) and WORLD_RIGHT or UP
	local n1 = tan:Cross(ref)
	n1 = (n1.Magnitude > 0.001) and n1.Unit or WORLD_RIGHT
	local n2 = tan:Cross(n1).Unit

	local id = d.id or 1
	local w1 = (id * R2_A) % 1
	local w2 = (id * R2_B) % 1
	local pick = (id * PHI) % 1

	local target_pos
	local share = (c.k17 or 45) / 100
	if pick < share then
		-- Exhaust: a cone of debris trailing back down the tangent. Spread grows
		-- with age so the stream widens as it falls behind, and the phase term
		-- keeps it streaming rather than sitting in a fixed cloud.
		local blen = c.k18 or 60
		local age = ((w1 + (st.pub or 0) * 0.35) % 1) * blen
		local a = w2 * math.pi * 2
		local spread = (c.k19 or 10) * (age / (blen > 0 and blen or 1))
		target_pos = pos - tan * age + (n1 * math.cos(a) + n2 * math.sin(a)) * spread
	else
		-- Engine: a cylindrical shell. Nozzle end tapers so it reads as an engine
		-- bell rather than a plain tube.
		local half = (c.k16 or 18) * 0.5
		local z = (w1 * 2 - 1) * half
		local a = w2 * math.pi * 2
		local taper = 0.55 + 0.45 * (1 - (z + half) / (half * 2))
		local r = (c.k15 or 10) * taper
		target_pos = pos + tan * z + (n1 * math.cos(a) + n2 * math.sin(a)) * r
	end

	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

-- x6.pre survives a shape switch (System.lua:152 only runs M.cleanup), so without
-- this st.hunt_root held a strong reference to another player's HumanoidRootPart
-- for the rest of the session, and st.t came back stale.
function M.cleanup(x6, x1)
	if x6.pre then
		x6.pre["Rocket Engine"] = nil
	end
end

M.Controls = {
	{ Type = "Slider", Name = "Path · Shape (1 Circle, 2 Figure 8)", Min = 1, Max = 2, Key = "k12", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Circle · Plane (1 Flat, 2 Upright, 3 Side)", Min = 1, Max = 3, Key = "k13", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Figure 8 · Lobes (1 Up/Down, 2 Side by Side)", Min = 1, Max = 2, Key = "k20", Default = 1, IntOnly = true },
	{ Type = "Slider", Name = "Path · Radius", Min = 10, Max = 500, Key = "k11", Default = 120 },
	{ Type = "Slider", Name = "Flight Speed", Min = 1, Max = 300, Key = "k14", Div = 10 },
	{ Type = "Slider", Name = "Engine · Radius", Min = 1, Max = 40, Key = "k15", Default = 10 },
	{ Type = "Slider", Name = "Engine · Length", Min = 1, Max = 60, Key = "k16", Default = 18 },
	{ Type = "Slider", Name = "Exhaust · Share %", Min = 0, Max = 90, Key = "k17", Default = 45, IntOnly = true },
	{ Type = "Slider", Name = "Exhaust · Length", Min = 5, Max = 200, Key = "k18", Default = 60 },
	{ Type = "Slider", Name = "Exhaust · Spread", Min = 0, Max = 40, Key = "k19", Default = 10 },
	{ Type = "Toggle", Name = "Hunt Targets", Key = "k21", Default = false },
	{ Type = "Slider", Name = "Hunt · Seconds Each", Min = 1, Max = 30, Key = "k22", Default = 4 },
}

return M
