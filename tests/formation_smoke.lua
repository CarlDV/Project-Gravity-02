-- The six formation controls -- Time Scale, Shape Blend, Formation Preview, Slot
-- Assignment, Target Part Count and Claim Rules -- exercised for real, in both trees.
--
-- No harness can drive the main loop: newEvent() in tests/robloxenv.lua counts
-- connections and drops the callback, so Heartbeat cannot be fired and f3_body is a
-- local. Every decision these features make therefore lives in a named function on x4
-- or x7 and is called directly here; tests/formation_lint.lua covers the wiring that
-- calls them. That split is the same one tests/fidelity_lint.lua documents.
--
-- The first block is the one that matters most: with the shipped defaults every one of
-- these has to be inert, because that is what makes six features landing in one pass
-- safe.
--
--   luajit tests/formation_smoke.lua      (from the repo root)

package.path = "tests/?.lua;" .. package.path
local env = require("robloxenv")
local svc, newInstance = env.svc, env.newInstance

local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print("  FAIL  " .. msg)
	end
end
local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-9)
end
local function slurp(path)
	local f = assert(io.open(path), "cannot open " .. path)
	local s = f:read("a")
	f:close()
	return s
end

local config_chunk = assert(loadfile("config.lua"))

local function mk_x6()
	return {
		b = nil, c = {}, a = setmetatable({}, { __mode = "k" }), o = false, d = false,
		p = 0, f = 0, n = 0, pi_targets = {}, pi_timer = 0, ex_nodes = {}, ex_timer = 0,
		esp_timer = 0, claim_queue = {}, active_array = {}, run_connections = {},
		pre = {}, pre_buffer = table.create(200),
		sculptor_selected = setmetatable({}, { __mode = "k" }),
		sculptor_highlights = setmetatable({}, { __mode = "k" }),
		pc_selected = setmetatable({}, { __mode = "k" }),
		pc_highlights = setmetatable({}, { __mode = "k" }),
		pc_offsets = setmetatable({}, { __mode = "k" }),
		pc_mods = {}, transition_time = 0, transition_dur = 2, f1_connections = {},
	}
end

-- One built System per case, so a test cannot inherit another's population or clock.
local function build(dir)
	local cfg = config_chunk()
	local x1, x2 = cfg.x1, cfg.x2
	x1.S = x2
	local x6 = mk_x6()
	local shapes = {}
	local ANIM = {}
	for _, k in ipairs({ "HOVER", "PRESS", "RELEASE", "TOGGLE", "TINT", "SLIDE", "OPEN",
		"OPEN_POP", "CLOSE", "CLOSE_POP", "ROLL", "FOLD", "UNFOLD", "RESCALE" }) do
		ANIM[k] = TweenInfo.new(0.1)
	end
	local ctx = {
		v1 = svc("UserInputService"), v2 = svc("Players"), v3 = svc("RunService"),
		v4 = svc("Workspace"), v5 = svc("StarterGui"), v6 = svc("TweenService"),
		v7 = svc("ContextActionService"), v8 = env.LocalPlayer, v9 = newInstance("Mouse", nil),
		x1 = x1, x2 = x2, x6 = x6,
		x9 = { c1 = 0.15, c2 = 0.05, c3 = 0.01, c4 = 0.2, c5 = 0.6, c6 = 0.8, c7 = 0.1, c8 = 0.25 },
		favorites = {}, save_favs = function() end, save_settings = function() end,
		get_shape = function(n) return shapes[n] end,
		local_shapes = {}, loaded_shapes = shapes,
		load_module = function(p) return assert(loadfile(p))() end,
		is_mobile = (dir ~= ""), SUB_DIR = dir, reset_config = function() end, ANIM = ANIM,
	}
	local sys = assert(loadfile(dir .. "System.lua"))()(ctx)
	assert(sys.x7, dir .. "System.lua must publish x7 for this suite")
	-- A core, so the distance-keyed sort and the claim radius have something to measure
	-- from. Anchored like the real one (x4.f4 sets it), which also keeps x7.e off it.
	local core = newInstance("BasePart", svc("Workspace"))
	core.Position = Vector3.new(0, 0, 0)
	core.Anchored = true
	x6.b = core
	return sys, ctx, x1, x2, x6, shapes
end

-- Claimed through the real x4.f1, so the records under test are the records the runtime
-- builds. "BasePart" rather than "Part": the stub's IsA is an exact class-name compare,
-- and f1's first test is p:IsA("BasePart").
local function claim(sys, x6, size, pos, name)
	local p = newInstance("BasePart", svc("Workspace"))
	p.Name = name or "Brick"
	p.Size = Vector3.new(size, size, size)
	p.Position = pos or Vector3.new(0, 0, 0)
	local ok = sys.x4.f1(p)
	return p, x6.a[p], ok
end

local function slots_of(x6)
	local out = {}
	for _, p in ipairs(x6.active_array) do
		local d = x6.a[p]
		out[p.Name] = d and d.slot or nil
	end
	return out
end

for _, tree in ipairs({
	{ label = "DESKTOP (root)", dir = "" },
	{ label = "MOBILE (mobilever/)", dir = "mobilever/" },
}) do
	print("\n════════ " .. tree.label .. " ════════")
	local T = tree.dir

	-- ── defaults are inert ────────────────────────────────────────────────────────
	-- The whole reason six features can land in one pass: at the shipped defaults every
	-- one of them has to leave the loop on the path it was already taking.
	do
		local sys, _, x1, _, x6 = build(T)
		local x4, x7 = sys.x4, sys.x7

		-- The published surface, first: the panel reaches these by name through
		-- context.x4, and main.lua's teardown reaches the last one through x6, so a
		-- rename that misses one call site is a control that silently does nothing.
		for _, fn in ipairs({
			"reindex_slots", "reroll_seeds", "enforce_part_cap", "recheck_rules",
			"preview_clear", "preview_step", "preview_run",
		}) do
			check(type(x4[fn]) == "function", T .. "x4." .. fn .. " is published")
		end
		for _, fn in ipairs({ "advance_clock", "blend_w", "rule_reject", "part_size", "reset_scratch" }) do
			check(type(x7[fn]) == "function", T .. "x7." .. fn .. " is published")
		end
		check(type(x6.preview_clear) == "function", T .. "and x6 carries the clear the loader calls")

		local c1 = x7.advance_clock(1 / 60)
		local c2 = x7.advance_clock(1 / 60)
		check(near(c2 - c1, 1 / 60), T .. "default TimeScale advances the clock at real time")

		local p1 = claim(sys, x6, 4, Vector3.new(10, 0, 0), "A")
		local p2 = claim(sys, x6, 8, Vector3.new(40, 0, 0), "B")
		check(x6.n == 2, T .. "two parts claimed")
		check(x4.reindex_slots() == 0, T .. "Claim mode assigns no slots")
		check(x6.a[p1].slot == nil and x6.a[p2].slot == nil,
			T .. "and leaves d.slot nil, which is what shapes saw before slots existed")
		check(x6.a[p1].slot_n == nil, T .. "and d.slot_n with it")
		check(x4.enforce_part_cap() == 0, T .. "TargetParts 0 releases nothing")
		check(x6.n == 2, T .. "and the population is untouched")
		check(x7.rule_reject(p1, true) == false, T .. "no rule rejects a part by default")
		check(x4.recheck_rules() == 0, T .. "and rechecking releases nothing")
		check(x7.blend_w(0, 0, 0.5) == 0, T .. "blend weight 0 is all of shape A")
		check(x6.bl_f2 == nil, T .. "no blend is resolved until a frame runs")
	end

	-- ── time scale ────────────────────────────────────────────────────────────────
	do
		local sys, _, x1 = build(T)
		local x7 = sys.x7

		x1.TimeScale = 0
		local a = x7.advance_clock(1 / 60)
		local b = x7.advance_clock(1 / 60)
		check(a == b, T .. "TimeScale 0 freezes the shape clock")

		x1.TimeScale = -2
		local c = x7.advance_clock(1 / 60)
		check(near(c - b, -2 / 60), T .. "a negative scale runs the clock backwards")

		x1.TimeScale = 0.25
		local d = x7.advance_clock(1 / 60)
		check(near(d - c, 0.25 / 60), T .. "a fractional scale slows it proportionally")

		-- The slider stops at 3; a hand-edited settings file does not.
		x1.TimeScale = 5000
		local e = x7.advance_clock(1 / 60)
		check(near(e - d, 8 / 60), T .. "an absurd scale is clamped to 8")
		x1.TimeScale = -5000
		local f = x7.advance_clock(1 / 60)
		check(near(f - e, -8 / 60), T .. "and to -8 the other way")

		x1.TimeScale = "fast"
		local g = x7.advance_clock(1 / 60)
		check(near(g - f, 1 / 60), T .. "a non-number from a mangled save reads as 1")
		x1.TimeScale = 0 / 0
		local h = x7.advance_clock(1 / 60)
		check(near(h - g, 1 / 60), T .. "and so does NaN, rather than poisoning the clock")
	end

	-- ── slot assignment ──────────────────────────────────────────────────────────
	do
		local sys, _, x1, _, x6 = build(T)
		local x4 = sys.x4
		-- Sizes and distances deliberately disagree, so a sort that reads the wrong key
		-- cannot pass by coincidence.
		claim(sys, x6, 1, Vector3.new(10, 0, 0), "A")
		claim(sys, x6, 5, Vector3.new(50, 0, 0), "B")
		claim(sys, x6, 3, Vector3.new(30, 0, 0), "C")
		claim(sys, x6, 2, Vector3.new(20, 0, 0), "D")
		claim(sys, x6, 4, Vector3.new(40, 0, 0), "E")

		x1.SlotMode = "Size Desc"
		check(x4.reindex_slots() == 5, T .. "Size Desc slots every part")
		local s = slots_of(x6)
		check(s.B == 1 and s.E == 2 and s.C == 3 and s.D == 4 and s.A == 5,
			T .. "Size Desc puts the biggest part in slot 1")
		for _, p in ipairs(x6.active_array) do
			check(x6.a[p].slot_n == 5, T .. "every record carries the live population")
		end

		x1.SlotMode = "Size Asc"
		x4.reindex_slots()
		s = slots_of(x6)
		check(s.A == 1 and s.D == 2 and s.C == 3 and s.E == 4 and s.B == 5,
			T .. "Size Asc puts the smallest in slot 1")

		x1.SlotMode = "Distance"
		x4.reindex_slots()
		s = slots_of(x6)
		check(s.A == 1 and s.D == 2 and s.C == 3 and s.E == 4 and s.B == 5,
			T .. "Distance puts the nearest to the core in slot 1")

		-- The ordering has to be a permutation and it has to be the same permutation on
		-- every call: the stride fires four times a second, and a shuffle that re-rolls
		-- is not a shuffle, it is every part changing place continuously.
		x1.SlotMode = "Shuffle"
		x4.reindex_slots()
		local first = slots_of(x6)
		x4.reindex_slots()
		local again = slots_of(x6)
		local seen, ok_perm = {}, true
		for name, slot in pairs(first) do
			if type(slot) ~= "number" or slot < 1 or slot > 5 or seen[slot] then
				ok_perm = false
			end
			seen[slot] = true
			if again[name] ~= slot then
				ok_perm = false
			end
		end
		check(ok_perm, T .. "Shuffle is a stable permutation of 1..N across calls")

		local moved = false
		x1.SlotSeed = (x1.SlotSeed or 0) + 7
		x4.reindex_slots()
		local reseeded = slots_of(x6)
		for name, slot in pairs(first) do
			if reseeded[name] ~= slot then
				moved = true
			end
		end
		check(moved, T .. "and a new seed lays it out differently")

		-- Back to Claim, which has to *undo* itself rather than leave stale slots behind.
		x1.SlotMode = "Claim"
		x4.reindex_slots()
		local cleared = true
		for _, p in ipairs(x6.active_array) do
			if x6.a[p].slot ~= nil or x6.a[p].slot_n ~= nil then
				cleared = false
			end
		end
		check(cleared, T .. "switching back to Claim clears the slots it wrote")
	end

	-- ── slot ties break on claim id, or parts trade places every stride ──────────
	do
		local sys, _, x1, _, x6 = build(T)
		local _, d1 = claim(sys, x6, 4, Vector3.new(1, 0, 0), "first")
		local _, d2 = claim(sys, x6, 4, Vector3.new(1, 0, 0), "second")
		local _, d3 = claim(sys, x6, 4, Vector3.new(1, 0, 0), "third")
		x1.SlotMode = "Size Desc"
		sys.x4.reindex_slots()
		check(d1.slot == 1 and d2.slot == 2 and d3.slot == 3,
			T .. "identical parts sort by claim id, so the order is stable")
		check(d1.id < d2.id and d2.id < d3.id, T .. "and the claim ids are what they claim to be")
	end

	-- ── target part count ────────────────────────────────────────────────────────
	do
		local names = { "n1", "n2", "n3", "n4", "n5", "n6" }
		local function populated()
			local sys, _, x1, _, x6 = build(T)
			-- size i, distance i*10, claimed oldest-first
			for i, nm in ipairs(names) do
				claim(sys, x6, i, Vector3.new(i * 10, 0, 0), nm)
			end
			return sys, x1, x6
		end
		local function held(x6)
			local out = {}
			for _, p in ipairs(x6.active_array) do
				out[p.Name] = true
			end
			return out
		end

		local cases = {
			{ rule = "Farthest", gone = { "n6", "n5", "n4" } },
			{ rule = "Nearest", gone = { "n1", "n2", "n3" } },
			{ rule = "Newest", gone = { "n6", "n5", "n4" } },
			{ rule = "Oldest", gone = { "n1", "n2", "n3" } },
			{ rule = "Smallest", gone = { "n1", "n2", "n3" } },
			{ rule = "Largest", gone = { "n6", "n5", "n4" } },
		}
		for _, case in ipairs(cases) do
			local sys, x1, x6 = populated()
			x1.TargetParts = 3
			x1.SurplusRule = case.rule
			local released = sys.x4.enforce_part_cap()
			check(released == 3, ("%s%s releases exactly the surplus (%d)"):format(T, case.rule, released))
			check(x6.n == 3 and #x6.active_array == 3,
				T .. case.rule .. " lands the population on the cap")
			local left = held(x6)
			local right = true
			for _, nm in ipairs(case.gone) do
				if left[nm] then
					right = false
				end
			end
			check(right, T .. case.rule .. " releases the parts it says it does")
		end

		-- An unrecognised rule from a mangled save must still be a rule.
		local sys, x1, x6 = populated()
		x1.TargetParts = 4
		x1.SurplusRule = "Whatever"
		check(sys.x4.enforce_part_cap() == 2, T .. "an unknown surplus rule still enforces the cap")
		check(x6.n == 4, T .. "and lands on it")

		-- Raising the ceiling above the population is not a release.
		sys, x1, x6 = populated()
		x1.TargetParts = 99
		check(sys.x4.enforce_part_cap() == 0, T .. "a ceiling above the population releases nothing")
		check(x6.n == 6, T .. "and leaves it alone")

		-- A hand-placed part is not surplus. Ever.
		sys, x1, x6 = populated()
		local pinned = x6.active_array[6]
		x6.a[pinned].pc_mode = "pin"
		x1.TargetParts = 1
		x1.SurplusRule = "Farthest"
		sys.x4.enforce_part_cap()
		local left = held(x6)
		check(left[pinned.Name] == true, T .. "Part Control's parts survive the ceiling")
		check(x6.n == 1, T .. "and the ceiling releases every part it is allowed to")
	end

	-- ── claim rules ──────────────────────────────────────────────────────────────
	do
		local sys, _, x1, _, x6 = build(T)
		local x7 = sys.x7
		local function part(size, pos, name)
			local p = newInstance("BasePart", svc("Workspace"))
			p.Name = name or "Brick"
			p.Size = Vector3.new(size, size, size)
			p.Position = pos or Vector3.new(0, 0, 0)
			return p
		end

		local small = part(1, Vector3.new(5, 0, 0), "Debris")
		local big = part(40, Vector3.new(5, 0, 0), "Wall")
		local crate = part(6, Vector3.new(5, 0, 0), "WoodCrate")
		local broken = part(6, Vector3.new(5, 0, 0), "BrokenCrate")
		local far = part(6, Vector3.new(900, 0, 0), "FarCrate")

		check(x7.part_size(big) == 40, T .. "part size is the longest side")
		local flat = newInstance("BasePart", svc("Workspace"))
		flat.Size = Vector3.new(200, 1, 1)
		check(x7.part_size(flat) == 200, T .. "so a slab reads as big, which is what it looks like")

		x1.RuleMinSize = 2
		check(x7.rule_reject(small, false) == true, T .. "Min Part Size rejects the debris")
		check(x7.rule_reject(crate, false) == false, T .. "and keeps what clears it")
		x1.RuleMinSize = 0

		x1.RuleMaxSize = 10
		check(x7.rule_reject(big, false) == true, T .. "Max Part Size rejects the wall")
		check(x7.rule_reject(crate, false) == false, T .. "and keeps what clears it")
		x1.RuleMaxSize = 0

		-- A part whose size cannot be read is not grounds for rejection: 0 means unknown.
		local sizeless = newInstance("BasePart", svc("Workspace"))
		x1.RuleMinSize = 5
		check(x7.rule_reject(sizeless, false) == false, T .. "an unreadable size is not a rejection")
		x1.RuleMinSize = 0

		x1.RuleName = "crate"
		check(x7.rule_reject(crate, false) == false, T .. "an include entry claims what matches it")
		check(x7.rule_reject(small, false) == true, T .. "and nothing else")
		x1.RuleName = "crate, -broken"
		check(x7.rule_reject(crate, false) == false, T .. "an exclusion beside an include still claims")
		check(x7.rule_reject(broken, false) == true, T .. "and rejects the excluded match")
		x1.RuleName = "-broken"
		check(x7.rule_reject(crate, false) == false, T .. "exclusions alone do not narrow to nothing")
		check(x7.rule_reject(broken, false) == true, T .. "they only exclude")
		x1.RuleName = "  CRATE  "
		check(x7.rule_reject(crate, false) == false, T .. "entries are trimmed and case-insensitive")
		-- A name that is a malformed Lua pattern has to be a substring, not an error.
		local odd = part(6, Vector3.new(5, 0, 0), "Part(1)")
		x1.RuleName = "part(1)"
		local ok_pat, rejected = pcall(x7.rule_reject, odd, false)
		check(ok_pat and rejected == false, T .. "a name with pattern characters is matched literally")
		x1.RuleName = ""

		x1.RuleClaimRadius = 100
		check(x7.rule_reject(far, true) == true, T .. "the claim radius rejects a distant part")
		check(x7.rule_reject(crate, true) == false, T .. "and takes a near one")
		check(x7.rule_reject(far, false) == false,
			T .. "but never evicts one already held, or walking would churn the whole formation")
		x1.RuleClaimRadius = 0
	end

	-- ── rechecking rules against parts already held ──────────────────────────────
	do
		local sys, _, x1, _, x6 = build(T)
		claim(sys, x6, 1, Vector3.new(5, 0, 0), "Debris")
		claim(sys, x6, 6, Vector3.new(5, 0, 0), "Crate")
		local wall = claim(sys, x6, 40, Vector3.new(5, 0, 0), "Wall")
		local far = claim(sys, x6, 6, Vector3.new(900, 0, 0), "FarCrate")
		check(x6.n == 4, T .. "four parts held before the rules change")

		x1.RuleMaxSize = 10
		check(sys.x4.recheck_rules() == 1, T .. "tightening a rule releases the part that now fails it")
		check(x6.a[wall] == nil, T .. "and it is the right one")
		check(x6.n == 3, T .. "and only that one")

		x1.RuleMaxSize = 0
		x1.RuleClaimRadius = 100
		check(sys.x4.recheck_rules() == 0, T .. "the claim radius is not applied to held parts")
		check(x6.a[far] ~= nil, T .. "so a part that has drifted out of it stays held")
	end

	-- ── the scratch list, checked against its own source ─────────────────────────
	-- The list had already drifted between the two trees once. Deriving the field names
	-- from the function body means this test cannot pass while the two disagree, and
	-- cannot rot when a field is added.
	do
		local sys, _, _, _, x6 = build(T)
		local body = slurp(T .. "System.lua"):match("local function reset_scratch%(d%)\n(.-)\n\tend")
		check(body ~= nil and #body > 0, T .. "reset_scratch is findable in the source")
		body = body or ""
		local names, count = {}, 0
		for field in body:gmatch("d%.([%w_]+)") do
			if not names[field] then
				names[field] = true
				count = count + 1
			end
		end
		check(count >= 25, ("%sthe scratch list still covers the fields shapes seed (%d)"):format(T, count))
		local d = {}
		for field in pairs(names) do
			d[field] = "dirty"
		end
		sys.x7.reset_scratch(d)
		local leftover = nil
		for field in pairs(names) do
			if field ~= "integral" and d[field] ~= nil then
				leftover = field
			end
		end
		check(leftover == nil, T .. "reset_scratch clears every field it names (" .. tostring(leftover) .. ")")
		check(typeof(d.integral) == "Vector3" and d.integral.Magnitude == 0,
			T .. "and zeroes the integral rather than dropping it")
		-- The blend's side record is scratch for a whole second shape.
		check(names.bd == true, T .. "and the list includes the blend's own record")
	end

	-- ── blend weight ─────────────────────────────────────────────────────────────
	do
		local x7 = build(T).x7
		check(x7.blend_w(0, 0, 0) == 0 and x7.blend_w(0, 0, 1) == 0, T .. "weight 0 is all A")
		check(x7.blend_w(1, 0, 0) == 1 and x7.blend_w(1, 0, 1) == 1, T .. "weight 1 is all B")
		check(near(x7.blend_w(0.5, 0, 0.9), 0.5), T .. "with no stagger every part shares the weight")
		-- Out of range on both sides, which is the case the corners above do not reach: the
		-- stagger multiplies the weight before subtracting the part's position, so the
		-- middle of the formation goes over 1 and the far end goes under 0. An unclamped
		-- lerp factor is a target outside both shapes.
		check(x7.blend_w(0.8, 1, 0) == 1, T .. "a weight the stagger pushes over 1 is clamped")
		check(x7.blend_w(0.1, 1, 0.9) == 0, T .. "and one it pushes under 0 is too")
		-- With stagger the weight falls off across the formation, and both ends stay in
		-- range: an unclamped lerp factor is a target outside both shapes.
		check(x7.blend_w(0.5, 1, 0) == 1, T .. "stagger 1 fully converts the first slot at half weight")
		check(x7.blend_w(0.5, 1, 1) == 0, T .. "and leaves the last one untouched")
		check(x7.blend_w(0, 1, 0) == 0, T .. "the front has not started at weight 0")
		check(x7.blend_w(1, 1, 1) == 1, T .. "and has crossed the whole formation at weight 1")
		local a, b = x7.blend_w(0.3, 1, 0.4), x7.blend_w(0.6, 1, 0.4)
		check(b > a, T .. "raising the weight raises every part's share")
		local c, e = x7.blend_w(0.5, 1, 0.2), x7.blend_w(0.5, 1, 0.8)
		check(c > e, T .. "and a later slot converts after an earlier one")
	end

	-- ── formation preview ────────────────────────────────────────────────────────
	do
		local sys, _, x1, _, x6 = build(T)
		local x4, x7 = sys.x4, sys.x7
		local cen = Vector3.new(0, 0, 0)
		-- A constant 60 studs/s, so one 1/60 step is exactly one stud and the Euler
		-- integration is checkable rather than merely plausible.
		local function drift()
			return Vector3.new(60, 0, 0), nil
		end

		x1.PreviewCount = 12
		check(x4.preview_step(0, cen, drift, {}, 1 / 60) == 12, T .. "the preview builds the pool it was asked for")
		check(x6.ghosts and #x6.ghosts == 12, T .. "and holds twelve markers")
		check(x6.ghost_folder ~= nil, T .. "in a folder of their own")
		local g1 = x6.ghosts[1]
		check(g1.Anchored == true, T .. "a marker is anchored, which is what keeps the sweep off it")
		check(g1.CanCollide == false, T .. "and cannot be collided with")
		check(g1.Name == "GRV_GHOST", T .. "and is named so the claim filter can see it")

		check(near(x6.ghost_pos[1].X, 1, 1e-6), T .. "one step of a 60 studs/s field moves it one stud")
		x4.preview_step(0, cen, drift, {}, 1 / 60)
		x4.preview_step(0, cen, drift, {}, 1 / 60)
		check(near(x6.ghost_pos[1].X, 3, 1e-6), T .. "and it keeps integrating across frames")

		-- A shape that hands back an exact position is followed, not integrated.
		local function exact()
			return Vector3.new(0, 0, 0), Vector3.new(7, 7, 7)
		end
		x4.preview_step(0, cen, exact, {}, 1 / 60)
		check(near(x6.ghost_pos[1].X, 7) and near(x6.ghost_pos[1].Y, 7),
			T .. "a pure target is taken as the position")

		-- The normal case for a preview is a population of zero, which is exactly what
		-- makes a shape divide by it.
		local function nan()
			return Vector3.new(0 / 0, 0, 0), nil
		end
		x4.preview_step(0, cen, nan, {}, 1 / 60)
		local px = x6.ghost_pos[1].X
		check(px == px, T .. "a NaN from a shape never reaches a marker's Position")

		-- And a shape that throws is a shape that throws, not a dead frame.
		local threw = false
		local ok_err = pcall(function()
			x4.preview_step(0, cen, function()
				threw = true
				error("shape blew up")
			end, {}, 1 / 60)
		end)
		check(ok_err and threw, T .. "a shape erroring on a marker does not propagate")

		-- A shape that returns the wrong *type* is the other half of that: the AI writes
		-- local shape files, so a number where a Vector3 belongs is not a remote
		-- possibility, and the arithmetic sits outside the pcall that guards the call.
		local before = x6.ghost_pos[1].X
		local ok_type = pcall(function()
			x4.preview_step(0, cen, function()
				return 42, "not a position"
			end, {}, 1 / 60)
		end)
		check(ok_type, T .. "a shape returning the wrong type does not propagate either")
		check(near(x6.ghost_pos[1].X, before), T .. "and the marker stays where it was")

		x1.PreviewCount = 6
		check(x4.preview_step(0, cen, drift, {}, 1 / 60) == 6, T .. "lowering the count shrinks the pool")
		check(#x6.ghosts == 6, T .. "and destroys the markers it no longer needs")
		check(x6.ghosts[7] == nil, T .. "leaving no holes behind")

		-- Out of range, because the slider is not the only thing that can write this.
		x1.PreviewCount = 9999
		check(x4.preview_step(0, cen, drift, {}, 1 / 60) == 200, T .. "the pool is capped at 200")
		x1.PreviewCount = 0
		check(x4.preview_step(0, cen, drift, {}, 1 / 60) == 4, T .. "and floored at 4")

		x4.preview_clear()
		check(x6.ghosts == nil and x6.ghost_folder == nil, T .. "clearing drops the pool and its folder")
		check(x4.preview_step(0, cen, nil, {}, 1 / 60) == 0, T .. "with no shape there is nothing to preview")

		-- The name guard, independently of the anchoring: a future feature that claims
		-- anchored parts must not start by claiming the preview.
		local impostor = newInstance("BasePart", svc("Workspace"))
		impostor.Name = "GRV_GHOST"
		impostor.Anchored = false
		impostor.Size = Vector3.new(2, 2, 2)
		check(x7.e(impostor) == true, T .. "a marker is excluded by name as well as by being anchored")
	end

	-- ── the blend, through the copy of it the preview runs ───────────────────────
	-- f3_body's own blend cannot be called from here (no harness can drive the loop), so
	-- this covers the mix arithmetic through preview_run, which mirrors it; the lint pins
	-- the two to the same shape.
	do
		local sys, _, x1, _, x6 = build(T)
		local x4 = sys.x4
		local cen = Vector3.new(0, 0, 0)
		local function a_field()
			return Vector3.new(0, 0, 0), Vector3.new(100, 0, 0)
		end
		local function b_field()
			return Vector3.new(0, 0, 0), Vector3.new(0, 100, 0)
		end
		x1.PreviewCount = 4

		x6.bl_f2, x6.bl_cfg, x6.bl_w, x6.bl_s = b_field, {}, 0.5, 0
		x4.preview_step(0, cen, a_field, {}, 1 / 60)
		local mid = x6.ghost_pos[1]
		check(near(mid.X, 50) and near(mid.Y, 50), T .. "half weight puts a marker between the two shapes")

		x6.bl_w = 1
		x4.preview_step(0, cen, a_field, {}, 1 / 60)
		local allb = x6.ghost_pos[1]
		check(near(allb.X, 0) and near(allb.Y, 100), T .. "full weight is entirely the blend shape")

		x6.bl_w = 0
		x4.preview_step(0, cen, a_field, {}, 1 / 60)
		local alla = x6.ghost_pos[1]
		check(near(alla.X, 100) and near(alla.Y, 0), T .. "zero weight never calls the blend at all")

		-- Stagger reads the slot, so the first and last markers have to disagree.
		x6.bl_w, x6.bl_s = 0.5, 1
		x4.preview_step(0, cen, a_field, {}, 1 / 60)
		check(x6.ghost_pos[1].Y > x6.ghost_pos[4].Y,
			T .. "with stagger the front of the formation converts before the back")
		x6.bl_f2 = nil
		x4.preview_clear()
	end

	-- ── the three population features in the order f3_body runs them ─────────────
	-- The stride does the ceiling first and the reindex second, so the slots describe the
	-- population that is actually left. Run the other way round, every released part
	-- leaves a hole in the numbering and slot_n is a lie.
	do
		local sys, _, x1, _, x6 = build(T)
		local x4 = sys.x4
		for i = 1, 10 do
			claim(sys, x6, i, Vector3.new(i * 10, 0, 0), "p" .. i)
		end
		x1.TargetParts = 4
		x1.SurplusRule = "Smallest"
		x1.SlotMode = "Size Desc"
		x4.enforce_part_cap()
		check(x4.reindex_slots() == 4, T .. "the reindex sees the population the ceiling left")

		local by_slot = {}
		for _, p in ipairs(x6.active_array) do
			by_slot[x6.a[p].slot] = p.Name
		end
		check(by_slot[1] == "p10" and by_slot[4] == "p7",
			T .. "and numbers the survivors biggest-first with no holes")
		for _, p in ipairs(x6.active_array) do
			check(x6.a[p].slot_n == 4, T .. "slot_n is the surviving count, not the original")
		end

		-- And a rule tightening on top of a ceiling: both walk the same array through the
		-- same release path, so the second one has to see what the first one did. The
		-- survivors are sizes 7..10, so a floor of 9 takes two of them.
		x1.RuleMinSize = 9
		check(x4.recheck_rules() == 2, T .. "a rule change releases what it should after a cap")
		check(x6.n == 2, T .. "leaving the parts that pass both")
		check(x4.reindex_slots() == 2, T .. "which reindexes to the pair")

		x1.RuleMinSize = 10
		check(x4.recheck_rules() == 1, T .. "and tightening again takes one more")
		check(x6.n == 1, T .. "leaving one part")
		check(x4.reindex_slots() == 1, T .. "and a single slot")
		local last = x6.active_array[1]
		check(last.Name == "p10", T .. "the only part big enough is the biggest one")
		check(x6.a[last].slot == 1 and x6.a[last].slot_n == 1, T .. "numbered 1 of 1")
	end
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)

