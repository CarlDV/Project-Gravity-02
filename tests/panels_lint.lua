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

-- The rest of the tree's consistency, same principle: a convention that most call
-- sites follow and a few do not is invisible from inside any one of them.
for _, tree in ipairs({
	{ path = "UI.lua", keybound_tutorial = true },
	{ path = "mobilever/UI.lua", keybound_tutorial = false },
}) do
	local path = tree.path
	local src = slurp(path)

	-- Round buttons. Minimize, close, Discord, help and every side panel's close were
	-- hand-built circles with no glyph, no hover and no press -- the only clickable
	-- things in either tree that gave no feedback at all, and minimize and close were
	-- told apart by colour alone.
	check(src:find("local function circle_btn%(") ~= nil, path .. ": round buttons have one owner")
	check(src:find("local function brighten%(") ~= nil,
		path .. ": and one way of deriving their hover tint")
	local circles = 0
	for _ in src:gmatch("circle_btn%(") do circles = circles + 1 end
	check(circles >= 5, ("%s: every round button goes through it (%d found, 1 decl + 4+ uses)")
		:format(path, circles))
	check(src:find("local function side_close%(header, cb%)\n%s*local b = circle_btn%(") ~= nil,
		path .. ": the side-panel close is one of them")

	-- Row hover. There were three behaviours: none on the mode-selector and Part
	-- Control rows, a direct BackgroundColor3 write on the target list, and none on
	-- either dropdown.
	check(src:find("local function row_hover%(") ~= nil, path .. ": row hover has one owner")
	check(src:find("row_hover%(%s*db,") ~= nil, path .. ": the shape dropdown hovers")
	check(src:find("row_hover%(%s*tdb,") ~= nil, path .. ": the target dropdown hovers")
	check(src:find("row_hover%(%s*f,") ~= nil, path .. ": the mode-selector rows hover")
	check(src:find("row_hover%(%s*row,") ~= nil, path .. ": the Part Control shape rows hover")
	check(src:find("row_hover%(%s*reset_btn,") ~= nil, path .. ": and Reset All Settings goes through it too")
	local t_enter = src:match("ib%.MouseEnter:Connect%(function%(%)(.-)end%)")
	local t_leave = src:match("ib%.MouseLeave:Connect%(function%(%)(.-)end%)")
	check(t_enter ~= nil and t_leave ~= nil, path .. ": the target row's hover handlers are findable")
	check(t_enter == nil or t_enter:find("v6:Create") ~= nil,
		path .. ": the target list tweens its hover in rather than setting it outright")
	check(t_leave == nil or t_leave:find("v6:Create") ~= nil,
		path .. ": and tweens it back out the same way")

	-- Ordering. UIListLayout.SortOrder defaults to Name, not LayoutOrder, and three of these
	-- panels put more than one class of child in one list -- Frames for sliders, toggles,
	-- text boxes, key rows and folding sections, TextLabels for headings and hints,
	-- TextButtons for buttons. Sorted by name, "Frame" < "TextButton" < "TextLabel", so
	-- every heading in the Advanced, Keybinds and Part Control panels sorted into one block
	-- at the bottom, away from the controls it was labelling. One helper numbers each list
	-- in build order and puts its layout into LayoutOrder mode.
	check(src:find("local function order_children%(container, layout%)") ~= nil,
		path .. ": list ordering has one owner")
	check(src:find("layout%.SortOrder = Enum%.SortOrder%.LayoutOrder") ~= nil,
		path .. ": which takes the list out of the Name default")
	check(src:find("order_children%(ac, acl%)") ~= nil, path .. ": the Advanced list is numbered")
	local pc_ordered = src:find("order_children%(pcc, pc[c]?l%)")
	check(pc_ordered ~= nil, path .. ": and so is Part Control's")

	-- The Advanced panel was the one panel in either tree without section headers, and
	-- it is the longest. Formation and Preview joined the list with the six formation
	-- controls; tests/formation_lint.lua checks what is *inside* those two, this checks
	-- that both trees group the panel the same way.
	for _, section in ipairs({
		"Tracking", "Physics", "Formation", "Preview", "Interface", "Claiming",
		"Performance", "Core Marker",
	}) do
		check(src:find('eh%(ac, "' .. section .. '"%)') ~= nil,
			("%s: Advanced groups under a %s header"):format(path, section))
	end

	-- x1.FPSCap is saved and applied by main.lua at launch, and only the mobile panel
	-- ever wrote it -- so on desktop the value in the settings file was unreachable.
	check(src:find("x1%.FPSCap%s*=%s*v") ~= nil, path .. ": the FPS cap has a control")
	check(src:find("FPS Cap %(0=Unc%)\", 0, 240") ~= nil,
		path .. ": and the same 0..240 range in both trees, since both write the same key")

	-- The claimed-part count is the one number that answers "is it working".
	check(src:find("PARTS: %%d") ~= nil, path .. ": the HUD carries the part count")

	-- The tutorial predated both tools.
	check(src:find("Part Control:") ~= nil, path .. ": the tutorial covers Part Control")
	check(src:find("Sculptor:") ~= nil, path .. ": and the Sculptor")
	if tree.keybound_tutorial then
		-- Desktop only: every key is rebindable there, and this text named E/Q/P/L
		-- regardless, so it was wrong for anyone who had opened the Keybinds window.
		check(src:find("local function key_label%(") ~= nil,
			path .. ": the tutorial reads the live keybinds")
		check(src:find("'E'") == nil and src:find("'Q'") == nil,
			path .. ": and no longer hardcodes a key name")
	end
end

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
