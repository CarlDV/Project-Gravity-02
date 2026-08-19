-- Cross-checks every Div slider's config.lua default against the Min..Max the
-- panel enforces. UI.lua:1223-1225 multiplies the stored value by Div to get the
-- display value, clamps that to Min..Max, then divides back -- so a stored default
-- that lands outside the display range is silently rewritten the first time the
-- panel is opened, and the shape runs on a number the author never chose.
--
-- controls_lint.lua checks type, not range, so nothing else catches this.
--
--   luajit tests/slider_range_lint.lua

local function stub() return setmetatable({}, { __index = function() return 0 end }) end
Vector3 = { new = stub, zero = stub(), xAxis = stub(), yAxis = stub() }
Color3 = { new = stub, fromRGB = stub }
CFrame = { new = stub, identity = stub(), fromAxisAngle = stub }
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 0 end }) end })
game = { GetService = function() return setmetatable({}, { __index = function() return function() end end }) end }
workspace = {}
if not table.create then table.create = function() return {} end end
if not math.clamp then
	math.clamp = function(x, lo, hi) return x < lo and lo or (x > hi and hi or x) end
end

local x2 = assert(loadfile("config.lua"))().x2

local names = {}
local pf = assert(io.popen("ls shapes"))
for line in pf:lines() do names[#names + 1] = (line:gsub("%.lua$", "")) end
pf:close()

local problems = 0
for _, name in ipairs(names) do
	local fh = assert(io.open("shapes/" .. name .. ".lua"))
	-- The continue -> "do end" rewrite this used to do is gone: current LuaJIT parses
	-- Luau's continue natively, and rewriting it to a no-op changed the semantics of
	-- any loop that used it.
	local src = fh:read("a")
	fh:close()
	local chunk, cerr = load(src, name)
	-- Nil-checked. Without this a shape that fails to compile made pcall(nil) return
	-- false, the whole branch was skipped, and the harness printed "0 out-of-range"
	-- and exited 0 having examined that shape's sliders not at all. controls_lint
	-- reports the same case loudly as PARSE FAIL.
	if not chunk then
		print(("PARSE FAIL  %-22s %s"):format(name, tostring(cerr)))
		problems = problems + 1
	elseif not x2[name] then
		print(("NO x2 BLOCK %-22s"):format(name))
		problems = problems + 1
	else
	local ok, M = pcall(chunk)
	if ok and type(M) == "table" and M.Controls then
		for _, ctl in ipairs(M.Controls) do
			if ctl.Type == "Slider" and ctl.Key and ctl.Min and ctl.Max then
				local stored = x2[name][ctl.Key]
				if type(stored) == "number" then
					local shown = ctl.Div and (stored * ctl.Div) or stored
					local hi = ctl.Max
					-- UI.lua:1220-1222 widens any slider whose name mentions speed.
					if ctl.Name:lower():find("speed") and not ctl.ExactMax then
						hi = hi + 300
					end
					if shown < ctl.Min or shown > hi then
						local clamped = math.clamp(shown, ctl.Min, hi)
						local lands = ctl.Div and (clamped / ctl.Div) or clamped
						print(("RANGE  %-22s %-5s %-26s stored %s shows as %s, outside %s..%s -> panel rewrites it to %s")
							:format(name, ctl.Key, ctl.Name, tostring(stored), tostring(shown),
								tostring(ctl.Min), tostring(hi), tostring(lands)))
						problems = problems + 1
					end
				end
			end
		end
	end
	end
end

print(("\n%d shapes checked, %d problems"):format(#names, problems))
os.exit(problems == 0 and 0 or 1)
