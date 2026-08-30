-- The panel layer, driven for real. The Advanced controls are built during x5.st(), and
-- every one of them hands its callback to UI_elements -- which UI.lua loads through
-- context.load_module. So a harness that wraps that one call gets a handle on every
-- control's callback and can invoke it, which is the only way to prove a control is wired
-- to the runtime rather than merely present in the source.
--
-- This is the layer neither of the other two formation tests can reach:
-- formation_lint.lua reads the source and formation_smoke.lua calls the runtime directly,
-- so between them a control whose callback wrote the wrong key, or reached for a function
-- that no longer exists, would pass both.
--
--   luajit tests/formation_panel.lua      (from the repo root)

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

local config_chunk = assert(loadfile("config.lua"))

-- Records every control as it is built, then hands the real element back so the panel is
-- assembled exactly as it would be in game.
local function wrap_elements(real, seen)
	local M = {}
	for k, v in pairs(real) do
		M[k] = v
	end
	-- The container every Advanced control is parented to, captured so a test can inspect
	-- the panel's own child order rather than taking the source's word for it.
	local function note(p, label, rec)
		seen[label] = rec
		seen.__box = seen.__box or p
	end
	M.s = function(p, label, mn, mx, df, cb, is_int, desc)
		note(p, label, { kind = "slider", cb = cb, min = mn, max = mx, default = df })
		return real.s(p, label, mn, mx, df, cb, is_int, desc)
	end
	M.t = function(p, label, df, cb, desc)
		note(p, label, { kind = "toggle", cb = cb, default = df })
		return real.t(p, label, df, cb, desc)
	end
	M.b = function(p, label, cb)
		note(p, label, { kind = "button", cb = cb })
		return real.b(p, label, cb)
	end
	M.tb = function(p, label, df, cb, desc, max_chars)
		local box = real.tb(p, label, df, cb, desc, max_chars)
		note(p, label, { kind = "textbox", cb = cb, box = box, default = df })
		return box
	end
	return M
end

-- The panel, then the System, in main.lua's order -- which is the order that matters here,
-- because every new callback reaches context.x4 at call time precisely because it does not
-- exist at build time.
local function build(dir)
	local cfg = config_chunk()
	local x1, x2 = cfg.x1, cfg.x2
	x1.S = x2
	local x6 = {
		b = nil, c = {}, a = setmetatable({}, { __mode = "k" }), o = false, d = false,
		p = 0, f = 0, n = 0, pi_targets = {}, pi_timer = 0, ex_nodes = {}, ex_timer = 0,
		esp_timer = 0, claim_queue = {}, active_array = {}, run_connections = {},
		pre = {}, pre_buffer = table.create(200), pc_mods = {},
		sculptor_selected = setmetatable({}, { __mode = "k" }),
		sculptor_highlights = setmetatable({}, { __mode = "k" }),
		pc_selected = setmetatable({}, { __mode = "k" }),
		pc_highlights = setmetatable({}, { __mode = "k" }),
		pc_offsets = setmetatable({}, { __mode = "k" }),
		transition_time = 0, transition_dur = 2, f1_connections = {},
	}
	local ANIM = setmetatable({}, { __index = function() return TweenInfo.new(0.1) end })
	local shapes = {}
	local seen = {}
	local ctx
	ctx = {
		v1 = svc("UserInputService"), v2 = svc("Players"), v3 = svc("RunService"),
		v4 = svc("Workspace"), v5 = svc("StarterGui"), v6 = svc("TweenService"),
		v7 = svc("ContextActionService"), v8 = env.LocalPlayer, v9 = newInstance("Mouse", nil),
		x1 = x1, x2 = x2, x6 = x6,
		x9 = { c1 = 0.15, c2 = 0.05, c3 = 0.01, c4 = 0.2, c5 = 0.6, c6 = 0.8, c7 = 0.1, c8 = 0.25 },
		favorites = {}, save_favs = function() end, save_settings = function() end,
		get_shape = function(n) return shapes[n] end,
		local_shapes = {}, loaded_shapes = shapes,
		is_mobile = (dir ~= ""), SUB_DIR = dir, reset_config = function() end, ANIM = ANIM,
	}
	ctx.load_module = function(path)
		local mod = assert(loadfile(path))()
		if path:find("UI_elements") then
			return function(c)
				return wrap_elements(mod(c), seen)
			end
		end
		return mod
	end
	local x5 = assert(loadfile(dir .. "UI.lua"))()(ctx)
	ctx.x5 = x5
	local sys = assert(loadfile(dir .. "System.lua"))()(ctx)
	ctx.x4, ctx.x8 = sys.x4, sys.x8
	x5.st()
	local core = newInstance("BasePart", svc("Workspace"))
	core.Position = Vector3.new(0, 0, 0)
	core.Anchored = true
	x6.b = core
	return seen, sys, ctx, x1, x2, x6
end

local function claim(sys, size, pos, name)
	local p = newInstance("BasePart", svc("Workspace"))
	p.Name = name
	p.Size = Vector3.new(size, size, size)
	p.Position = pos or Vector3.new(0, 0, 0)
	sys.x4.f1(p)
	return p
end

for _, tree in ipairs({
	{ label = "DESKTOP (root)", dir = "" },
	{ label = "MOBILE (mobilever/)", dir = "mobilever/" },
}) do
	print("\n════════ " .. tree.label .. " ════════")
	local T = tree.dir
	local seen, sys, ctx, x1, x2, x6 = build(T)

	local function ctl(label)
		return seen[label]
	end
	-- The cycling buttons carry their value in the label, so they are found by prefix.
	local function cycle(prefix)
		for label, rec in pairs(seen) do
			if rec.kind == "button" and label:sub(1, #prefix) == prefix then
				return rec, label
			end
		end
	end

	-- Present, and of the right kind. A slider that became a toggle writes a boolean into
	-- a number key, which load_settings then drops on the next launch.
	local expected = {
		{ "Time Scale", "slider", -3, 3 },
		{ "Blend Weight", "slider", 0, 100 },
		{ "Blend Stagger", "slider", 0, 100 },
		{ "Ghost Count", "slider", 4, 200 },
		{ "Target Parts", "slider", 0, 5000 },
		{ "Min Part Size", "slider", 0, 200 },
		{ "Max Part Size", "slider", 0, 500 },
		{ "Claim Radius", "slider", 0, 2000 },
		{ "Shape Blend", "toggle" },
		{ "Formation Preview", "toggle" },
		{ "Deviation Readout", "toggle" },
		{ "Blend Shape", "textbox" },
		{ "Name Filter", "textbox" },
		{ "Ignore Tags", "textbox" },
		{ "Re-roll Layout", "button" },
	}
	for _, row in ipairs(expected) do
		local rec = ctl(row[1])
		check(rec ~= nil, T .. row[1] .. " is built")
		if rec then
			check(rec.kind == row[2], ("%s%s is a %s, not a %s"):format(T, row[1], row[2], rec.kind))
			if row[3] then
				check(rec.min == row[3] and rec.max == row[4],
					("%s%s spans %s..%s"):format(T, row[1], tostring(row[3]), tostring(row[4])))
			end
			check(type(rec.cb) == "function", T .. row[1] .. " carries a callback")
		end
	end
	check(cycle("Slot Order") ~= nil, T .. "Slot Order is a cycling button")
	check(cycle("Surplus Rule") ~= nil, T .. "Surplus Rule is a cycling button")

	-- The panel's own child order, which is what the layout actually lays out.
	-- UIListLayout.SortOrder defaults to Name, and this list mixes classes: sliders,
	-- toggles and text boxes are Frames, headings and descriptions are TextLabels, the
	-- cycling buttons are TextButtons. Sorted by name, "Frame" < "TextButton" <
	-- "TextLabel", so every control floats to the top and every heading sinks into one
	-- block at the bottom -- which is exactly how the panel looked. The fix is an explicit
	-- LayoutOrder in build order, and these are the checks that it happened.
	local box = seen.__box
	check(box ~= nil, T .. "the Advanced container was captured")
	if box then
		local layout, rows = nil, {}
		for _, child in ipairs(box:GetChildren()) do
			local cls = child.ClassName
			if cls == "UIListLayout" then
				layout = child
			elseif cls ~= "UIPadding" then
				rows[#rows + 1] = child
			end
		end
		check(layout ~= nil, T .. "the Advanced list has a UIListLayout")
		check(layout and layout.SortOrder == Enum.SortOrder.LayoutOrder,
			T .. "which is in LayoutOrder mode rather than the Name default")
		check(#rows > 30, ("%sthe panel built its rows (%d)"):format(T, #rows))
		local numbered, first_label, first_frame = true, nil, nil
		for i, child in ipairs(rows) do
			if child.LayoutOrder ~= i then
				numbered = false
			end
			if child.ClassName == "TextLabel" and not first_label then
				first_label = i
			end
			if child.ClassName == "Frame" and not first_frame then
				first_frame = i
			end
		end
		check(numbered, T .. "every row is numbered in the order it was built")
		check(first_label ~= nil and first_frame ~= nil and first_label < first_frame,
			T .. "and the first heading sits above the first control instead of below all of them")
	end

	-- Every default shown is the value the config actually holds. A control built from a
	-- different number is one that writes that number back the first time it is touched.
	check(ctl("Time Scale").default == x1.TimeScale, T .. "Time Scale opens on the saved value")
	check(ctl("Ghost Count").default == x1.PreviewCount, T .. "Ghost Count opens on the saved value")
	check(ctl("Target Parts").default == x1.TargetParts, T .. "Target Parts opens on the saved value")
	check(ctl("Blend Shape").default == x1.BlendShape, T .. "Blend Shape opens on the saved name")

	-- Invoking the callbacks. This is the whole point: a control that writes the wrong key,
	-- or reaches for an x4 function that has been renamed, fails here and nowhere else.
	ctl("Time Scale").cb(-2.5)
	check(x1.TimeScale == -2.5, T .. "the Time Scale slider writes x1.TimeScale")
	ctl("Shape Blend").cb(true)
	check(x1.BlendEnabled == true, T .. "the Shape Blend toggle writes x1.BlendEnabled")
	ctl("Blend Weight").cb(35)
	check(x1.BlendWeight == 35, T .. "Blend Weight writes a number")
	ctl("Ghost Count").cb(24)
	check(x1.PreviewCount == 24, T .. "Ghost Count writes a number")
	ctl("Deviation Readout").cb(true)
	check(x1.PreviewDeviation == true, T .. "the deviation toggle writes a boolean")
	ctl("Target Parts").cb(12)
	check(x1.TargetParts == 12, T .. "Target Parts writes a number")

	-- The blend shape box resolves what was typed, and refuses what it cannot resolve.
	local blend = ctl("Blend Shape")
	blend.cb("black")
	check(x1.BlendShape == "Black Hole", T .. "a prefix resolves to the shape it names")
	check(blend.box.Text == "Black Hole", T .. "and the box is rewritten with the canonical name")
	blend.cb("HALO RING")
	check(x1.BlendShape == "Halo Ring", T .. "matching is case-insensitive")
	blend.cb("   ")
	check(x1.BlendShape == "Halo Ring", T .. "whitespace alone changes nothing")
	blend.cb("no such shape")
	check(x1.BlendShape == "Halo Ring", T .. "an unmatched name is refused")
	check(blend.box.Text == "Halo Ring", T .. "and the box goes back to the name that stuck")
	check(x2[x1.BlendShape] ~= nil, T .. "so the key always holds a registered shape")

	-- The ignore-tag list is a table of strings on both sides of the box.
	ctl("Ignore Tags").cb("Alpha, Beta ,, Gamma  ")
	check(type(x1.k5) == "table" and #x1.k5 == 3, T .. "the tag box writes a list, dropping empties")
	check(x1.k5[1] == "Alpha" and x1.k5[2] == "Beta" and x1.k5[3] == "Gamma",
		T .. "with each entry trimmed")
	ctl("Ignore Tags").cb("")
	check(type(x1.k5) == "table" and #x1.k5 == 0, T .. "and emptying it leaves an empty list, not nil")

	-- The cycling buttons walk their value list and wrap. eb hands the button to the
	-- callback, which is what cycle_btn relabels, so pressing it is calling cb(button).
	local slot_btn = cycle("Slot Order")
	local order = { "Claim", "Size Desc", "Size Asc", "Distance", "Shuffle" }
	x1.SlotMode = "Claim"
	for i = 2, #order do
		slot_btn.cb()
		check(x1.SlotMode == order[i], ("%sSlot Order advances to %s"):format(T, order[i]))
	end
	slot_btn.cb()
	check(x1.SlotMode == "Claim", T .. "and wraps back to the inert mode")
	local rule_btn = cycle("Surplus Rule")
	x1.SurplusRule = "Farthest"
	rule_btn.cb()
	check(x1.SurplusRule == "Nearest", T .. "Surplus Rule advances")
	for _ = 1, 5 do
		rule_btn.cb()
	end
	check(x1.SurplusRule == "Farthest", T .. "and wraps after six values")

	-- Panel to runtime, end to end: the rule sliders are the ones that have to act on the
	-- parts already held, and that path runs from the callback into x4.recheck_rules.
	x1.k5 = {}
	x1.RuleMinSize, x1.RuleMaxSize, x1.RuleName = 0, 0, ""
	claim(sys, 1, Vector3.new(5, 0, 0), "debris")
	claim(sys, 4, Vector3.new(6, 0, 0), "brick")
	claim(sys, 40, Vector3.new(7, 0, 0), "wall")
	check(x6.n == 3, T .. "three parts held before the panel touches a rule")
	ctl("Min Part Size").cb(3)
	check(x1.RuleMinSize == 3, T .. "the Min Part Size slider writes its key")
	check(x6.n == 2, T .. "and releases the part that now fails the rule")
	ctl("Max Part Size").cb(10)
	check(x6.n == 1, T .. "the Max Part Size slider releases through the same path")
	ctl("Name Filter").cb("nothing matches this")
	check(x6.n == 0, T .. "and so does the name filter")
	ctl("Min Part Size").cb(0)
	ctl("Max Part Size").cb(0)
	ctl("Name Filter").cb("")

	-- The claim radius is the one rule that must NOT evict, so its callback is the one
	-- that must not run the recheck.
	claim(sys, 4, Vector3.new(900, 0, 0), "far")
	check(x6.n == 1, T .. "a distant part is held")
	ctl("Claim Radius").cb(100)
	check(x1.RuleClaimRadius == 100, T .. "the Claim Radius slider writes its key")
	check(x6.n == 1, T .. "and leaves the parts already held alone")
	ctl("Claim Radius").cb(0)

	-- Re-roll reaches the runtime and clears the scratch it is supposed to clear.
	local held = x6.active_array[1]
	x6.a[held].v6 = 1.234
	x6.a[held].phase = 9
	local seed_before = x1.SlotSeed
	ctl("Re-roll Layout").cb()
	check(x6.a[held].v6 == nil and x6.a[held].phase == nil,
		T .. "Re-roll Layout clears the per-part scratch through x4.reroll_seeds")
	check(x1.SlotSeed ~= seed_before, T .. "and bumps the seed so Shuffle re-orders")

	-- The preview toggle has to collect its own markers when it goes off, because the loop
	-- that would otherwise do it is not running here -- which is exactly the case the
	-- callback exists for.
	x1.PreviewCount = 8
	sys.x4.preview_step(0, Vector3.new(0, 0, 0), function()
		return Vector3.new(1, 0, 0), nil
	end, {}, 1 / 60)
	check(x6.ghosts ~= nil and #x6.ghosts == 8, T .. "markers exist before the toggle goes off")
	ctl("Formation Preview").cb(false)
	check(x1.PreviewEnabled == false, T .. "the preview toggle writes its key")
	check(x6.ghosts == nil, T .. "and collects the markers on the way")
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)




