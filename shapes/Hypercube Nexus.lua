local M = {}
local NAME = "Hypercube Nexus"
local TAU = math.pi * 2
local UP = Vector3.new(0, 1, 0)
local vertices, edges = {}, {}

-- A 5D cube has 32 vertices and 80 edges. Generate its real connectivity once.
for index = 0, 31 do
	local vertex = {}
	for axis = 0, 4 do
		local bit = math.floor(index / 2 ^ axis) % 2
		vertex[axis + 1] = bit == 0 and -1 or 1
		if bit == 0 then edges[#edges + 1] = { index + 1, index + 2 ^ axis + 1 } end
	end
	vertices[index + 1] = vertex
end

local function project(v, phase, c)
	local x, y, z, w, q = v[1], v[2], v[3], v[4], v[5]
	local ca, sa = math.cos(phase * 0.83), math.sin(phase * 0.83)
	x, w = x * ca - w * sa, x * sa + w * ca
	ca, sa = math.cos(phase * 0.61), math.sin(phase * 0.61)
	y, q = y * ca - q * sa, y * sa + q * ca
	ca, sa = math.cos(phase * 0.47), math.sin(phase * 0.47)
	z, w = z * ca - w * sa, z * sa + w * ca
	-- Rotation preserves the sqrt(5) vertex norm. Distance >= 3 keeps the first
	-- projection finite; the second distance is twice that and clears its bound too.
	local distance = math.clamp(c.k12 or 4, 3, 8)
	local first = distance / (distance - q)
	x, y, z, w = x * first, y * first, z * first, w * first
	local second = (distance * 2) / (distance * 2 - w)
	local pulse = 1 + math.clamp(c.k14 or 20, 0, 80) / 100 * math.sin(phase * 1.4)
	local scale = math.clamp(c.k11 or 95, 20, 250) * pulse * second
	return Vector3.new(x * scale, y * scale, z * scale)
end

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t, points = {} }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 7, 0, 40) * x9.c2
	st.t = t
	-- Only 32 projections per frame, independent of the number of held parts.
	for i, vertex in ipairs(vertices) do st.points[i] = project(vertex, st.phase, c) end
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local edge = edges[(id - 1) % #edges + 1]
	local a = st and st.points[edge[1]] or project(vertices[edge[1]], phase, c)
	local b = st and st.points[edge[2]] or project(vertices[edge[2]], phase, c)
	local u = (id * 0.6180339887498949) % 1
	local v = (id * 0.7548776662466927) % 1
	local line = b - a
	local along = line.Magnitude > 0.0001 and line.Unit or UP
	local side = along:Cross(UP)
	side = side.Magnitude > 0.0001 and side.Unit or Vector3.new(1, 0, 0)
	local normal = side:Cross(along)
	local radius = math.clamp(c.k16 or 2, 0, 12)
	local angle = v * TAU + u * TAU * math.clamp(c.k17 or 3, 0, 8) - phase
	local offset = a + line * u + side * (radius * math.cos(angle)) + normal * (radius * math.sin(angle))
	local target = cen + offset + Vector3.new(0, c.k15 or 150, 0)
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Nexus Scale", Min = 20, Max = 250, Key = "k11", Default = 95 },
	{ Type = "Slider", Name = "Projection Distance", Min = 30, Max = 80, Key = "k12", Default = 4, Div = 10,
		Desc = "Lower values exaggerate the nested dimensional cages." },
	{ Type = "Slider", Name = "Dimension Speed", Min = 0, Max = 40, Key = "k13", Default = 7, ExactMax = true },
	{ Type = "Slider", Name = "Pulse Depth %", Min = 0, Max = 80, Key = "k14", Default = 20, IntOnly = true },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k15", Default = 150 },
	{ Type = "Slider", Name = "Filament Radius", Min = 0, Max = 12, Key = "k16", Default = 2 },
	{ Type = "Slider", Name = "Filament Twists", Min = 0, Max = 8, Key = "k17", Default = 3, IntOnly = true },
}

return M
