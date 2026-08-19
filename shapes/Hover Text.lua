local M = {}

-- 5x7 bitmap font. One number per row, top row first, bit 4 (0x10) is the
-- leftmost column. Anything not listed here renders as blank space.
local FONT = {
	A = { 0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11 }, B = { 0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E },
	C = { 0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E }, D = { 0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E },
	E = { 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F }, F = { 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10 },
	G = { 0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E }, H = { 0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11 },
	I = { 0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E }, J = { 0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C },
	K = { 0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11 }, L = { 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F },
	M = { 0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11 }, N = { 0x11, 0x19, 0x19, 0x15, 0x13, 0x13, 0x11 },
	O = { 0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E }, P = { 0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10 },
	Q = { 0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D }, R = { 0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11 },
	S = { 0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E }, T = { 0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04 },
	U = { 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E }, V = { 0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04 },
	W = { 0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11 }, X = { 0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11 },
	Y = { 0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04 }, Z = { 0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F },
	["0"] = { 0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E }, ["1"] = { 0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E },
	["2"] = { 0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F }, ["3"] = { 0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E },
	["4"] = { 0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02 }, ["5"] = { 0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E },
	["6"] = { 0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E }, ["7"] = { 0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08 },
	["8"] = { 0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E }, ["9"] = { 0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C },
	["!"] = { 0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04 }, ["?"] = { 0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04 },
	["."] = { 0, 0, 0, 0, 0, 0, 0x04 }, [","] = { 0, 0, 0, 0, 0, 0x04, 0x08 },
	["-"] = { 0, 0, 0, 0x1F, 0, 0, 0 }, [":"] = { 0, 0x04, 0x04, 0, 0x04, 0x04, 0 },
	["'"] = { 0x04, 0x04, 0, 0, 0, 0, 0 }, ["/"] = { 0x01, 0x01, 0x02, 0x04, 0x08, 0x10, 0x10 },
}

local COL_BIT = { 0x10, 0x08, 0x04, 0x02, 0x01 }
local ROWS = 7
local ADVANCE = 6 -- 5 columns of ink plus one blank column between glyphs
local MAX_CHARS = 24 -- keeps even the widest banner inside the k1 cull radius

local UP = Vector3.new(0, 1, 0)
local WORLD_FWD = Vector3.new(0, 0, -1)
local WORLD_RIGHT = Vector3.new(1, 0, 0)
local ANTI_SLEEP = Vector3.new(0, 0.01, 0)
local PHI = 0.6180339887498949
local GOLDEN_ANGLE = 2.399963229728653

local function gcd(a, b)
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

-- Turns a message into a flat list of lit pixels in glyph units (1 unit = one
-- pixel), so the letter-size slider can scale it without a rebuild.
local function build_points(raw)
	local msg = string.upper(tostring(raw or ""))
	if #msg > MAX_CHARS then
		msg = string.sub(msg, 1, MAX_CHARS)
	end

	local px, py = {}, {}
	local n = 0
	local min_x, max_x = math.huge, -math.huge
	for i = 1, #msg do
		local glyph = FONT[string.sub(msg, i, i)]
		if glyph then
			local col0 = (i - 1) * ADVANCE
			for r = 1, ROWS do
				local bits = glyph[r]
				if bits ~= 0 then
					for cbit = 1, 5 do
						if math.floor(bits / COL_BIT[cbit]) % 2 == 1 then
							local x = col0 + cbit - 1
							n = n + 1
							px[n] = x
							py[n] = 4 - r -- top row lands at +3, bottom row at -3
							if x < min_x then min_x = x end
							if x > max_x then max_x = x end
						end
					end
				end
			end
		end
	end

	if n == 0 then
		return nil
	end

	-- Centre on the ink itself rather than the string length, so leading or
	-- trailing spaces do not shove the banner off the anchor.
	local mid = (min_x + max_x) * 0.5
	for i = 1, n do
		px[i] = px[i] - mid
	end

	-- Parts are handed ids from a monotonic counter, so the live set is roughly a
	-- contiguous window. Mapping that window with id % n would land it on a
	-- contiguous block of pixels and drop whole letters whenever there are fewer
	-- parts than pixels. Stepping by ~n*phi instead gives a Weyl sequence:
	-- consecutive ids land far apart, and any window of ids thins every glyph
	-- evenly. Coprime with n so no two parts inside one window collide.
	local step = math.floor(n * PHI + 0.5)
	if step < 1 then
		step = 1
	end
	while n > 1 and gcd(step, n) ~= 1 do
		step = step + 1
		if step >= n then
			step = 1
		end
	end

	return { px = px, py = py, n = n, step = step, key = raw }
end

local function get_points(x6, raw)
	local pts = x6.pre["Hover Text_points"]
	if pts and pts.key == raw then
		return pts
	end
	pts = build_points(raw)
	if not pts then
		-- Empty or all-unknown message. Fall back, but key the cache on what was
		-- actually asked for so we do not rebuild once per part.
		pts = build_points("HELLO")
		pts.key = raw
	end
	x6.pre["Hover Text_points"] = pts
	return pts
end

-- The slab transform: shared by every part, recomputed once per bucket cycle.
--
-- System buckets the sweep (System.lua:180-191, 412) — with k7 = 4 each part's
-- f2 runs on one frame in every four, and neighbouring parts run on different
-- frames. A rigid banner cannot tolerate that: if each part read the hover
-- offset at its own frame the text would shear, half the letters at the top of
-- the bob and half at the bottom. So the basis and the hover offset are stamped
-- once per cycle and every part in that cycle reads the identical values/. The
-- target then steps at ~15 Hz, which the feed-forward velocity term at
-- System.lua:472-481 smooths back out into continuous motion.
local function get_slab(x6, x1, c, t)
	local st = x6.pre["Hover Text"]
	if not st then
		st = {}
		x6.pre["Hover Text"] = st
	end

	local et = x1.k7
	if not et then
		local n = x6.n or 0
		et = n > 5000 and 10 or (n > 2500 and 6 or (n > 1000 and 3 or 1))
	end
	if x1["Force Smooth (Lags)"] then
		et = 1
	end
	if et < 1 then
		et = 1
	end

	local gen = math.floor((x6.f or 0) / et)
	if st.gen == gen then
		return st
	end
	st.gen = gen
	st.t = t

	if c.k19 == false then
		st.fwd, st.right = WORLD_FWD, WORLD_RIGHT
	else
		local cam = workspace.CurrentCamera
		local lv = cam and cam.CFrame.LookVector
		local flat = lv and Vector3.new(lv.X, 0, lv.Z)
		if flat and flat.Magnitude > 0.001 then
			st.fwd = flat.Unit
		elseif not st.fwd then
			st.fwd = WORLD_FWD
		end
		-- fwd is horizontal by construction, so this never degenerates, not even
		-- with the camera pointed straight down.
		st.right = st.fwd:Cross(UP)
	end

	-- Front-to-back and up-and-down on a 1 : 0.7 frequency ratio, so the pair
	-- traces a Lissajous figure instead of a straight diagonal.
	local ph = t * (c.k14 or 0.8)
	st.slab = st.fwd * (math.sin(ph) * (c.k12 or 30)) + UP * (math.sin(ph * 0.7) * (c.k13 or 15))
	return st
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local pts = get_points(x6, c.k18)
	local n = pts.n
	if n == 0 then
		return ANTI_SLEEP, nil
	end

	local st = get_slab(x6, x1, c, t)
	local spacing = c.k11 or 6
	local id = d.id or 1
	local i = (id * pts.step) % n + 1
	local lx = pts.px[i] * spacing
	local ly = pts.py[i] * spacing

	-- Once there are more parts than pixels the extras land on a pixel that is
	-- already taken. Fan them into layers alternating in front of and behind the
	-- slab so the banner reads as extruded rather than z-fighting into one blob.
	--
	-- The layer count comes from the live part count, not from d.id directly:
	-- x6.part_id_counter (System.lua:692) is never reset, so after some churn the
	-- live ids are a window sitting at 40000-odd and floor(id / n) alone would put
	-- every part on layer 500. Only the depth offset depends on x6.n — which pixel
	-- a part owns does not, so legibility never reshuffles as parts come and go.
	local depth_off = 0
	local layers = math.ceil((x6.n or 0) / n)
	if layers > 1 then
		if layers > 12 then
			layers = 12
		end
		local layer = math.floor(id / n) % layers
		if layer > 0 then
			local ring = math.ceil(layer * 0.5)
			depth_off = (layer % 2 == 1 and 1 or -1) * ring * spacing * 0.35
			local swirl = layer * GOLDEN_ANGLE
			local rr = spacing * 0.18 * (ring < 3 and ring or 3)
			lx = lx + math.cos(swirl) * rr
			ly = ly + math.sin(swirl) * rr
		end
	end

	-- Ripple travelling left to right through the letters. Coherent, so it reads
	-- as one wave rather than per-part noise: uses the cycle-stamped time.
	local wave = c.k16 or 0
	if wave > 0 then
		ly = ly + math.sin(st.t * 2 - lx * 0.15) * wave
	end

	local target_pos = cen + (st.right * lx) + (UP * ly) + (st.fwd * depth_off) + st.slab

	-- Shimmer is the one term that is meant to be desynchronised, so it is keyed
	-- off d.id and the live t. Capped against the pixel pitch: any further and
	-- neighbouring pixels swap places and the glyphs stop being readable.
	local shimmer = c.k15 or 0
	if shimmer > 0 then
		local lim = spacing * 0.45
		if shimmer > lim then
			shimmer = lim
		end
		target_pos = target_pos
			+ Vector3.new(
				math.sin(t * 3.0 + id) * shimmer,
				math.cos(t * 2.7 + id * 1.3) * shimmer,
				math.sin(t * 3.3 + id * 0.7) * shimmer
			)
	end

	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

-- Both keys are created from inside f2 and x6.pre survives a shape switch
-- (System.lua:152 only runs M.cleanup), so without this the pixel arrays and the
-- stale cycle stamp were held for the life of the session.
function M.cleanup(x6, x1)
	if not x6.pre then
		return
	end
	x6.pre["Hover Text"] = nil
	x6.pre["Hover Text_points"] = nil
end

M.Controls = {
	{
		Type = "TextBox",
		Name = "Message",
		Key = "k18",
		Default = "HELLO",
		MaxChars = MAX_CHARS,
		Desc = "A-Z, 0-9 and . , - : ' / ! ? — anything else becomes a space.",
	},
	{ Type = "Slider", Name = "Letter Size", Min = 1, Max = 20, Key = "k11", Default = 6 },
	{ Type = "Slider", Name = "Hover Depth", Min = 0, Max = 100, Key = "k12", Default = 30 },
	{ Type = "Slider", Name = "Hover Height", Min = 0, Max = 100, Key = "k13", Default = 15 },
	{ Type = "Slider", Name = "Hover Speed", Min = 1, Max = 50, Key = "k14", Default = 0.8, Div = 10, ExactMax = true },
	{ Type = "Slider", Name = "Shimmer", Min = 0, Max = 10, Key = "k15", Default = 2 },
	{ Type = "Slider", Name = "Wave", Min = 0, Max = 20, Key = "k16", Default = 0 },
	{ Type = "Toggle", Name = "Face Player", Key = "k19", Default = true },
}

return M
