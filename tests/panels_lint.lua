-- The side panels -- Advanced, Keybinds and Part Control -- are the same kind of
-- window, and each one used to carry its own geometry. Part Control was the panel
-- that drifted furthest: 300x470 with a 50px header next to Keybinds' 300x440 with
-- a 44px one, a grey text "x" where every other window has a red circle, no bottom
-- padding, its own button heights, a visible scrollbar on the one list that had
-- one, and on mobile a 280x420 body with a 40px header in a tree whose main panel
-- is 180x250 with a 26px one. None of that is visible from inside the block that
-- writes it, which is why it is pinned here instead.
--
--   luajit tests/panels_lint.lua      (from the repo root)

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

-- The Part Control block, so a check meant for it cannot be satisfied by a match
-- somewhere else in an 80 KB file. Runs from the panel's construction to the hook
-- it publishes at the end.
local function partctl_block(src)
	local from = src:find('pcm%.Name = "PartControl"')
	local to = src:find("x6%.pc_on_change = refresh_partctl")
	if not from or not to or to < from then
		return nil
	end
	return src:sub(from, to)
end

for _, tree in ipairs({
	{ path = "UI.lua", panels = { "am", "km", "pcm" }, header = 44 },
	{ path = "mobilever/UI.lua", panels = { "am", "pcm" }, header = 26 },
}) do
	local path = tree.path
	local src = slurp(path)
	local pc = partctl_block(src)
	check(pc ~= nil, path .. ": the Part Control block is still findable")
	pc = pc or ""

	-- One geometry, declared once. A literal size on any side panel is the drift
	-- itself: it is how three windows that open in the same slot ended up three
	-- different shapes.
	check(src:find("local SIDE_W = ") ~= nil, path .. ": declares a shared side-panel width")
	check(src:find("local SIDE_H = ") ~= nil, path .. ": declares a shared side-panel height")
	check(src:find("local SIDE_HEADER_H = " .. tree.header) ~= nil,
		("%s: the shared side-panel header is %d"):format(path, tree.header))

	for _, panel in ipairs(tree.panels) do
		check(src:find(panel .. "%.Size = UDim2%.new%(0, SIDE_W, 0, SIDE_H%)") ~= nil,
			("%s: %s is sized from the shared constants"):format(path, panel))
		check(src:find(panel .. "%.Position = UDim2%.new%(0[%.%d]*, [%-%w /%.]-SIDE_") ~= nil,
			("%s: %s is positioned from the shared constants"):format(path, panel))
		-- Every side panel goes in the registry, which is what makes opening one
		-- close the others and what lets the collapse-to-pill sweep find all of
		-- them. Part Control was the one the sweep missed, so minimizing left it
		-- floating with its handlers still armed.
		check(src:find("register_side_panel%(" .. panel .. "[,%)]") ~= nil,
			("%s: %s is in the side-panel registry"):format(path, panel))
	end

	check(src:find("pch%.Size = UDim2%.new%(1, 0, 0, SIDE_HEADER_H%)") ~= nil,
		path .. ": the Part Control header is the shared height")
	check(src:find("pcc%.Position = UDim2%.new%(0, 0, 0, SIDE_HEADER_H") ~= nil,
		path .. ": the Part Control content sits under the shared header")

	-- The registry is only useful if the sweep and the panel buttons go through it.
	check(src:find("for win in pairs%(side_panels%) do") ~= nil,
		path .. ": the collapse sweep walks the registry rather than naming panels")
	check(src:find("open_side_panel%(pcm, opening%)") ~= nil,
		path .. ": the Part Control button opens through the registry")
	check(src:find("open_side_panel%(am, ") ~= nil,
		path .. ": the Advanced button opens through the registry")

	-- Closing the panel is what disarms the click handlers, and it now has three
	-- routes: its own button, another panel opening over it, and the collapse. All
	-- three run the on_close, so the disarm cannot be written per route.
	check(src:find("register_side_panel%(pcm, function%(%)") ~= nil,
		path .. ": Part Control registers an on_close so every close disarms it")

	-- One close button, built once. The grey text "x" is the specific thing that
	-- made this panel look like it came from somewhere else.
	check(src:find("local function side_close%(header, cb%)") ~= nil,
		path .. ": the red circular close button has one owner")
	check(pc:find('"×"') == nil, path .. ": Part Control no longer draws its own text close")
	check(pc:find("side_close%(pch, function%(%)") ~= nil,
		path .. ": Part Control closes with the shared button")

	-- Padding and scrollbars: the two remaining places this panel was the odd one
	-- out. Every other scroller in both trees is thickness 0.
	check(pc:find("pcp%.PaddingBottom") ~= nil,
		path .. ": the Part Control content pads its bottom edge")
	check(pc:find("pcslist%.ScrollBarThickness = 0") ~= nil,
		path .. ": the shape list hides its scrollbar like every other list")

	-- The mode rows are a radio group, painted rather than labelled: eb tweens
	-- BackgroundColor3 and TextColor3, so an eb button cannot hold a selected tint,
	-- and the bullet-in-the-text workaround is what that produced.
	check(pc:find("mode_paint%[id%] = paint") ~= nil,
		path .. ": the mode rows paint their selected state")
	check(pc:find("● ") == nil, path .. ": the mode rows are not labelled with bullets")
	check(pc:find("Color3%.fromRGB%(40, 40, 180%)") ~= nil,
		path .. ": the selected row uses the same tint as the mode selector's rows")

	-- Both long sections fold, which is what keeps a panel with fifty shapes and
	-- four sliders reachable on a phone without dragging past a nested scroller.
	check(pc:find("local function collapsible%(title, open, value_fn%)") ~= nil,
		path .. ": the panel has a collapsible section helper")
	check(pc:find('collapsible%("Target Shape", false') ~= nil,
		path .. ": the shape picker starts folded")
	check(pc:find('collapsible%("Physics Override", false') ~= nil,
		path .. ": the physics sliders start folded")
	-- Folded state has to stay readable, so the head carries the value and both
	-- heads are refreshed by the same hook the count is.
	check(pc:find("refresh_shape_head%(%)") ~= nil, path .. ": the shape head is refreshed")
	check(pc:find("refresh_phys_head%(%)") ~= nil, path .. ": the physics head is refreshed")

	-- With nothing selected every action in the panel is a no-op. It used to give
	-- no sign of that at all.
	check(pc:find("HINT_EMPTY") ~= nil, path .. ": the panel says when it has no selection")
	check(pc:find("will apply to the next selection") ~= nil,
		path .. ": picking a mode with nothing selected says what it did")
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
