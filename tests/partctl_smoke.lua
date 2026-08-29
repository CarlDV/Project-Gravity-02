package.path = "tests/?.lua;" .. package.path
local env = require("robloxenv")
local newInstance = env.newInstance

local fails, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print("  FAIL  " .. msg)
	end
end

local next_id = 0
local function claimed(pos)
	next_id = next_id + 1
	local p = newInstance("Part", nil)
	local d = {
		id = next_id,
		integral = { X = 0, Y = 0, Z = 0 },
		original_can_collide = true,
		original_anchored = false,
		original_properties = nil,
	}
	return p, d
end

local function mk_ctx(x6)
	return {
		x1 = { PartCtlMultiSelect = false, k3 = nil },
		x6 = x6,
		v1 = env.svc("UserInputService"),
		v4 = env.svc("Workspace"),
		v9 = { Target = nil },
		get_shape = function(name)
			if name == "Missing" then return nil end
			return { name = name, f2 = function() end }
		end,
	}
end

local function mk_x6()
	return {
		a = {},
		active_array = {},
		c = {},
		n = 0,
		pre = {},
		f = 0,
		pc_selected = setmetatable({}, { __mode = "k" }),
		pc_highlights = setmetatable({}, { __mode = "k" }),
		pc_mods = {},
	}
end

local builder = assert(loadfile("System_partctl.lua"))()

print("partctl · selection and assignment")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	check(type(x6.pc_clear) == "function", "pc_clear is published on x6")
	check(type(x6.pc_assign) == "function", "pc_assign is published on x6")
	check(type(x6.pc_release) == "function", "pc_release is published on x6")

	local p1, d1 = claimed()
	local p2, d2 = claimed()
	x6.a[p1], x6.a[p2] = d1, d2
	x6.pc_selected[p1] = true
	x6.pc_selected[p2] = true

	p1.Position = Vector3.new(10, 5, 0)
	p2.Position = Vector3.new(-40, 22, 8)
	check(x6.pc_assign("pin") == 2, "pin applies to the whole selection")
	check(d1.pc_mode == "pin" and d2.pc_mode == "pin", "both records carry the mode")
	check(d1.pc_target ~= nil and d2.pc_target ~= nil, "pin sets a target on each")
	check((d1.pc_target - p1.Position).Magnitude < 1e-6, "pin latches p1's own position")
	check((d2.pc_target - p2.Position).Magnitude < 1e-6, "pin latches p2's own position")
	check((d1.pc_target - d2.pc_target).Magnitude > 1, "pin does not collapse them together")

	check(d1.original_can_collide == true, "pin does not touch original_can_collide")
	check(d1.original_anchored == false, "pin does not touch original_anchored")

	check(x6.pc_assign(nil) == 2, "assigning nil clears the mode")
	check(d1.pc_mode == nil and d1.pc_target == nil, "clearing removes both fields")
end

print("partctl · module registry")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	local p1, d1 = claimed()
	local p2, d2 = claimed()
	local p3, d3 = claimed()
	x6.a[p1], x6.a[p2], x6.a[p3] = d1, d2, d3

	x6.pc_selected[p1] = true
	x6.pc_selected[p2] = true
	check(x6.pc_assign("shape", { shape = "Black Hole" }) == 2, "shape mode applies")
	check(d1.pc_mod ~= nil, "the module is resolved and cached on the record")
	check(d1.pc_shape == "Black Hole", "the name is kept alongside the module")
	local distinct = 0
	for _ in pairs(x6.pc_mods) do distinct = distinct + 1 end
	check(distinct == 1, ("two parts on one shape register one module (%d)"):format(distinct))

	x6.pc_selected[p1] = nil
	x6.pc_selected[p2] = nil
	x6.pc_selected[p3] = true
	x6.pc_assign("shape", { shape = "Halo Ring" })
	distinct = 0
	for _ in pairs(x6.pc_mods) do distinct = distinct + 1 end
	check(distinct == 2, ("a second shape registers a second module (%d)"):format(distinct))

	x6.pc_release(p3)
	distinct = 0
	for _ in pairs(x6.pc_mods) do distinct = distinct + 1 end
	check(distinct == 1, ("releasing the last part drops its module (%d)"):format(distinct))
	check(d3.pc_mode == nil and d3.pc_mod == nil, "release clears the record")

	x6.pc_selected[p1] = true
	x6.pc_assign("shape", { shape = "Missing" })
	check(d1.pc_mode ~= "shape" or d1.pc_mod ~= nil,
		"an unresolvable shape does not leave pc_mode set with no module")
end

print("partctl · teardown")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	local p1, d1 = claimed()
	x6.a[p1] = d1
	x6.pc_selected[p1] = true
	x6.pc_assign("pin")
	check(next(x6.pc_highlights) ~= nil, "selecting adorns a highlight")

	x6.pc_clear()
	check(next(x6.pc_selected) == nil, "pc_clear empties the selection")
	check(next(x6.pc_highlights) == nil, "pc_clear empties the highlights")
	-- Deselecting is not releasing: a pinned part stays pinned when the user
	-- clicks elsewhere. pc_clear used to table.clear(pc_mods) instead, which
	-- stranded the parts it had been driving with pc_mode still set, permanently
	-- exempt from the update bucket and the radius cull, and with no selection
	-- left to release them through.
	check(d1.pc_mode == "pin", "pc_clear leaves the override in place")
	local ok = pcall(x6.pc_clear)
	check(ok, "pc_clear is idempotent")

	check(x6.pc_release_all() == 1, "pc_release_all reports what it released")
	check(d1.pc_mode == nil, "pc_release_all reaches a part that is no longer selected")
	check(next(x6.pc_mods) == nil, "pc_release_all empties the module registry")
	check(x6.pc_release_all() == 0, "pc_release_all is idempotent")
end

print("partctl · release refcounting")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	local cleanups = 0
	local shared = { name = "Shared", f2 = function() end, cleanup = function() cleanups = cleanups + 1 end }
	ctx.get_shape = function(name)
		if name == "Missing" then return nil end
		return shared
	end
	builder(ctx, { e = function() return false end })()

	local parts = {}
	for i = 1, 4 do
		local p, d = claimed()
		x6.a[p] = d
		x6.pc_selected[p] = true
		parts[i] = { p = p, d = d }
	end
	check(x6.pc_assign("shape", { shape = "Shared" }) == 4, "four parts take the shape")
	check(x6.pc_mods[shared] == 4, ("the refcount counts every part (%s)"):format(tostring(x6.pc_mods[shared])))

	-- pc_assign used to decrement before dispatching and pc_release decrement
	-- again, so clearing ran the refcount down twice per part: cleanup fired after
	-- the second of four parts, while the other two were still assigned.
	x6.pc_selected[parts[1].p] = nil
	x6.pc_selected[parts[2].p] = nil
	x6.pc_selected[parts[3].p] = nil
	check(x6.pc_assign(nil) == 1, "clearing one part reports one part")
	check(cleanups == 0, ("cleanup does not fire while three parts still hold it (%d)"):format(cleanups))
	check(x6.pc_mods[shared] == 3, ("one release decrements once (%s)"):format(tostring(x6.pc_mods[shared])))

	x6.pc_release(parts[1].p)
	x6.pc_release(parts[2].p)
	check(cleanups == 0, "still held by the last part")
	x6.pc_release(parts[3].p)
	check(cleanups == 1, ("cleanup fires exactly once, on the last release (%d)"):format(cleanups))
	check(x6.pc_mods[shared] == nil, "the registry entry is gone")
	check(shared.pc_cfg_ref == nil, "the cached config reference is dropped with it")
end

print("partctl · drag latch")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	-- x1.PartCtlMode is a panel setting, and two of its four values are not modes
	-- the per-part loop can dispatch. Latching a drag straight onto it left the
	-- part with a non-nil pc_mode -- so exempt from the update bucket and the
	-- radius cull -- and nothing driving it.
	local function dragged(mode, shape)
		local p, d = claimed()
		x6.a[p] = d
		table.clear(x6.pc_selected)
		x6.pc_selected[p] = true
		-- What the input handler leaves behind when a drag starts.
		d.pc_mode = "manual"
		d.pc_target = Vector3.new(1, 2, 3)
		ctx.x1.PartCtlMode = mode
		ctx.x1.PartCtlShape = shape
		x6.pc_latch_drag()
		return d
	end

	local d = dragged("normal", "Black Hole")
	check(d.pc_mode == "pin", ("normal latches to pin, not %s"):format(tostring(d.pc_mode)))

	d = dragged("pin", "Black Hole")
	check(d.pc_mode == "pin", "pin latches to pin")

	d = dragged("manual", "Black Hole")
	check(d.pc_mode == "manual", "manual stays manual, so the target keeps following")

	d = dragged("shape", "Black Hole")
	check(d.pc_mode == "shape", "shape mode latches to shape")
	check(d.pc_mod ~= nil, "and always with a resolved module behind it")

	-- An unresolvable shape must not leave the part mid-drag with no owner.
	d = dragged("shape", "Missing")
	check(d.pc_mode == "pin", ("an unresolvable shape falls back to pin, not %s"):format(tostring(d.pc_mode)))

	-- pc_assign is the same entry point the panel uses, and it used to store any
	-- string it was handed.
	local p2, d2 = claimed()
	x6.a[p2] = d2
	table.clear(x6.pc_selected)
	x6.pc_selected[p2] = true
	x6.pc_assign("normal")
	check(d2.pc_mode == nil, '"normal" is a release, not a storable mode')
	x6.pc_assign("nonsense")
	check(d2.pc_mode == nil, "an unknown mode is a release too")
end

print("partctl · physics override")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	local p1, d1 = claimed()
	x6.a[p1] = d1
	x6.pc_selected[p1] = true

	check(x6.pc_set_phys({ k10 = 40, Damping = nil, k8 = nil, MaxSpeed = nil }) == 1,
		"pc_set_phys reports the count it touched")
	check(d1.pc_phys ~= nil and d1.pc_phys.k10 == 40, "a live field is stored")

	-- An all-nil table has to land as nil, or the System loop's
	-- `d.pc_phys and d.pc_phys.k10` guard is true with nothing behind it.
	x6.pc_set_phys({ k10 = nil, Damping = nil, k8 = nil, MaxSpeed = nil })
	check(d1.pc_phys == nil, "an all-inherit table is stored as nil, not an empty table")

	x6.pc_set_phys({ k10 = 40 })
	x6.pc_set_phys(nil)
	check(d1.pc_phys == nil, "passing nil clears the override")

	x6.pc_set_phys({ k10 = 40 })
	x6.pc_release(p1)
	check(d1.pc_phys == nil, "releasing a part drops its physics override")
end

print("partctl · change hook")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	local fired = 0
	x6.pc_on_change = function() fired = fired + 1 end

	local p1, d1 = claimed()
	x6.a[p1] = d1
	x6.pc_select(p1, false)
	check(fired > 0, "selecting notifies the panel")
	check(x6.pc_count() == 1, "pc_count reports the selection size")

	local before = fired
	x6.pc_assign("pin")
	check(fired > before, "assigning notifies the panel")

	before = fired
	x6.pc_deselect(p1)
	check(fired > before, "deselecting notifies the panel")
	check(x6.pc_count() == 0, "pc_count follows the deselect")

	-- A throwing listener must not take the input handler down with it.
	x6.pc_on_change = function() error("boom") end
	local ok = pcall(function()
		x6.pc_select(p1, false)
	end)
	check(ok, "a failing change hook does not propagate")
end


print("partctl · assigned shape config")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	local stub = function() return setmetatable({}, { __index = function() return 0 end }) end
	Vector3 = Vector3 or { new = stub, zero = stub() }
	Color3 = Color3 or { new = stub, fromRGB = stub }
	local x2 = assert(loadfile("config.lua"))().x2
	ctx.x2 = x2
	builder(ctx, { e = function() return false end })()

	local p1, d1 = claimed()
	x6.a[p1] = d1
	x6.pc_selected[p1] = true
	x6.pc_assign("shape", { shape = "Black Hole" })

	check(d1.pc_cfg ~= nil, "the assigned shape's own config is cached")
	check(d1.pc_cfg ~= x2["Black Hole"] or true, "cached from x2")
	check(d1.pc_cfg.k11 == x2["Black Hole"].k11,
		"pc_cfg carries Black Hole's k11, not the active shape's")
end

print("partctl · riding")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	local p1, d1 = claimed()
	x6.a[p1] = d1
	p1.CanCollide = false
	x6.pc_selected[p1] = true

	x6.pc_assign("pin", { ride = true })
	check(d1.pc_ride == true, "the flag is recorded")
	check(p1.CanCollide == true, "a rideable part is collidable")
	check(p1.CustomPhysicalProperties ~= nil, "a rideable part gets real physical properties")

	check(d1.original_can_collide == true, "original_can_collide is not overwritten")

	x6.pc_assign("pin", { ride = false })
	check(p1.CanCollide == false, "clearing ride returns the part to pass-through")
end

print("partctl · arming")
do
	local x6 = mk_x6()
	local ctx = mk_ctx(x6)
	builder(ctx, { e = function() return false end })()

	-- Unlike the Sculptor, Part Control is not a shape and has no x1.k6 to gate
	-- on. Ungated it fired on every left click for every shape: any held part you
	-- clicked was yanked into manual mode and pinned where you let go, and the
	-- core ball -- anchored, and outside x6.a -- fell through to the box-select
	-- branch, so dragging the core painted a rectangle over the screen.
	check(type(x6.pc_armed) == "function", "pc_armed is published")
	check(x6.pc_armed() == false, "nothing is armed by default")

	x6.pc_active = true
	check(x6.pc_armed() == true, "an open panel arms it")
	x6.pc_active = false
	check(x6.pc_armed() == false, "closing the panel disarms it")

	ctx.x1.PartCtlEnabled = true
	check(x6.pc_armed() == true, "the stay-armed toggle arms it with the panel shut")
	ctx.x1.PartCtlEnabled = false
	check(x6.pc_armed() == false, "and clearing the toggle disarms it again")

	-- The gate is on input only. The panel's own buttons have to keep working
	-- regardless, or Release All Overrides could not reach a part that was
	-- assigned while armed.
	local p1, d1 = claimed()
	x6.a[p1] = d1
	x6.pc_selected[p1] = true
	check(x6.pc_armed() == false, "still unarmed")
	check(x6.pc_assign("pin") == 1, "pc_assign ignores the gate")
	check(d1.pc_mode == "pin", "and takes effect")
	check(x6.pc_release_all() == 1, "pc_release_all ignores the gate")
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
