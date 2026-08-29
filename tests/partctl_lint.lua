local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print("  FAIL  " .. msg)
	end
end
local function slurp(path)
	local f = assert(io.open(path), "cannot open " .. path)
	local s = f:read("a")
	f:close()
	return s
end

for _, path in ipairs({ "System.lua", "mobilever/System.lua" }) do
	local src = slurp(path)

	check(src:find("d%.pc_mode%s*==%s*nil%s+and%s+i%s*%%%s*et%s*~=%s*update_bucket") ~= nil,
		path .. ": the bucket skip exempts controlled parts")

	local cull = src:find("distance_sq%s*>%s*k1_sq[^\n]*pc_mode")
	local dead = src:find("distance_sq%s*>%s*c7_sq[^\n]*pc_mode")
	check(cull ~= nil, path .. ": the radius cull exempts controlled parts")
	check(dead ~= nil, path .. ": the deadzone exempts controlled parts")

	check(src:find('pc%s*==%s*"pin"') or src:find('pc%s*==%s*"manual"'),
		path .. ": the dispatch branches on pin/manual")
	check(src:find("shape_f2%(p,%s*active_c,%s*d,%s*ft") ~= nil,
		path .. ": the normal path still calls shape_f2 unchanged")

	check(src:find("x6%.pc_mods") ~= nil, path .. ": the loop walks the assigned-module registry")
	check(src:find("mod%.px") ~= nil or src:find("m%.px") ~= nil,
		path .. ": it calls px on each assigned module")

	check(src:find("p%.CanCollide%s*=%s*%(disabled%s+or%s+x1%.PreserveCollisions[^\n]*pc_ride") ~= nil,
		path .. ": the disable path honours pc_ride")
	check(src:find("pc_ride") ~= nil, path .. ": pc_ride is read in the runtime")

	-- A shape switch tears down the module a part is assigned to and the x6.pre
	-- state behind it, so the assignments have to go with it. Without this the
	-- parts kept pc_mode set and stayed exempt from bucketing and the cull while
	-- driving a module whose px was no longer being called.
	check(src:find("pc_release_all") ~= nil, path .. ": the shape switch releases assignments")
	local switch = src:find("x6%.last_shape%s*~=%s*x1%.k6")
	local rel = src:find("pcall%(x6%.pc_release_all%)")
	check(switch ~= nil and rel ~= nil and rel > switch and rel - switch < 600,
		path .. ": pc_release_all is called from the shape-switch block")

	-- The per-part smoothing override has to reproduce the global path's
	-- "1 means snap" case; math.log(math.max(0.001, 0)) is finite, not infinite.
	check(src:find("pc_sm%s*>=%s*1") ~= nil,
		path .. ": a per-part smoothing of 1 snaps instead of falling into the log")
end

for _, path in ipairs({ "System_partctl.lua", "mobilever/System_partctl.lua" }) do
	local src = slurp(path)

	check(src:find("x6%.pc_release_all%s*=%s*pc_release_all") ~= nil,
		path .. ": publishes pc_release_all")
	check(src:find("x6%.pc_count%s*=%s*pc_count") ~= nil, path .. ": publishes pc_count")
	check(src:find("x6%.pc_set_phys%s*=%s*pc_set_phys") ~= nil, path .. ": publishes pc_set_phys")
	check(src:find("x6%.pc_on_change") ~= nil, path .. ": notifies the panel on change")

	-- Deselecting is not releasing. pc_clear used to table.clear(pc_mods), which
	-- dropped every refcount without running a single cleanup and left the parts
	-- it had been driving stranded with pc_mode still set and no selection to
	-- release them through.
	local clear_body = src:match("local function pc_clear_highlights%(%)(.-)\n\tend")
	check(clear_body ~= nil, path .. ": pc_clear_highlights is still a named local")
	check(clear_body == nil or clear_body:find("pc_mods") == nil,
		path .. ": pc_clear does not touch the module registry")

	-- One owner for the refcount. Inlined in both pc_assign and pc_release, the
	-- nil-mode path decremented twice for the same part and fired cleanup while
	-- other parts were still driving the module.
	check(src:find("local function pc_unref_mod") ~= nil, path .. ": the refcount has one owner")
	local n = 0
	for _ in src:gmatch("x6%.pc_mods%[[%w_]+%]%s*=%s*x6%.pc_mods") do n = n + 1 end
	check(n == 0, ("%s: no open-coded refcount decrement left (%d)"):format(path, n))

	-- x1.PartCtlMode is a panel setting that carries two values the per-part loop
	-- cannot honour: "normal" is not a mode, and "shape" needs a resolved module a
	-- drag never attaches. Latching a drag straight to it left parts permanently
	-- exempt from the update bucket with nothing driving them.
	check(src:find('d%.pc_mode%s*=%s*x1%.PartCtlMode') == nil,
		path .. ": a drag does not latch pc_mode straight from x1.PartCtlMode")
	check(src:find("local function pc_latch_drag") ~= nil, path .. ": the drag latch is its own function")

	-- Part Control is not a shape, so it has no `x1.k6 == "Sculptor"` to gate on
	-- the way System_sculptor does. Ungated, these handlers fired on every left
	-- click for every shape: clicking any held part yanked it into manual mode and
	-- pinned it where you dropped it, and since the core ball is anchored and
	-- lives outside x6.a, every core drag fell through to the else branch and
	-- painted a selection rectangle over the screen.
	check(src:find("local function pc_armed") ~= nil, path .. ": the handlers have an arming gate")
	check(src:find("x6%.pc_active%s+or%s+x1%.PartCtlEnabled") ~= nil,
		path .. ": armed by the panel being open, or by the toggle")
	check(src:find("if%s+processed%s+or%s+not%s+pc_armed%(%)%s+then") ~= nil,
		path .. ": InputBegan returns early when unarmed")

	-- Only InputBegan is gated: the other two are no-ops without pc_dragging or
	-- pc_box_start, which only a gated InputBegan can set. Gating them too would
	-- strand an in-flight drag if the panel closed halfway through it.
	local changed = src:match("v1%.InputChanged:Connect%(function%(input, processed%)(.-)\n\t\t\t end")
		or src:match("v1%.InputChanged:Connect%(function%(input, processed%)(.-)end%)\n\t\t%)")
	check(changed == nil or changed:find("pc_armed") == nil,
		path .. ": InputChanged is not gated, so a live drag still tracks")
	local ended = src:match("v1%.InputEnded:Connect%(function%(input%)(.-)end%)\n\t\t%)")
	check(ended == nil or ended:find("pc_armed") == nil,
		path .. ": InputEnded is not gated, so a live drag always finishes")
end

do
	local cfg = assert(loadfile("config.lua"))
	local stub = function() return setmetatable({}, { __index = function() return 0 end }) end
	Vector3 = { new = stub, zero = stub() }
	Color3 = { new = stub, fromRGB = stub }
	local x1 = cfg().x1
	check(x1.PartCtlEnabled == false, "config.lua: Part Control is not armed by default")
	check(type(x1.PartCtlEnabled) == "boolean", "PartCtlEnabled is a boolean")
end

for _, path in ipairs({ "UI.lua", "mobilever/UI.lua" }) do
	local src = slurp(path)
	check(src:find("pc_assign") ~= nil, path .. ": the panel calls pc_assign")
	check(src:find("pc_clear") ~= nil, path .. ": the panel can clear the selection")
	check(src:find("Part Control") ~= nil, path .. ": the panel is labelled")
	check(src:find("pc_count") ~= nil, path .. ": the panel reads the live selection count")
	check(src:find("pc_release_all") ~= nil, path .. ": the panel can release every override")
	check(src:find("x6%.pc_on_change%s*=") ~= nil, path .. ": the panel registers for change events")
	check(src:find("pc_set_phys") ~= nil, path .. ": the panel can set the physics override")

	-- The count was read once, at build time, inside a function that rebuilt the
	-- whole panel; nothing called it again until the window was reopened.
	check(src:find("pcc:ClearAllChildren") == nil,
		path .. ": the panel body is refreshed in place, not rebuilt")

	-- Opening and closing the panel is what arms and disarms the click handlers,
	-- so every path that changes the panel's visibility has to say so.
	check(src:find("x6%.pc_active%s*=") ~= nil, path .. ": the panel arms the handlers")
	check(src:find("PartCtlEnabled%s*=%s*v") ~= nil, path .. ": the stay-armed toggle is wired")
	local sets = 0
	for _ in src:gmatch("x6%.pc_active%s*=") do sets = sets + 1 end
	-- Construction (reset), the close button, and the panel button.
	check(sets == 3, ("%s: every visibility path sets pc_active (%d/3)"):format(path, sets))
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
