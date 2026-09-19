local M = {}
local NAME = "Reality Shatter"
local TAU = math.pi * 2
local PHI = 0.6180339887498949
local golden = (1 + math.sqrt(5)) / 2
local vertices = {
	{ -1, golden, 0 }, { 1, golden, 0 }, { -1, -golden, 0 }, { 1, -golden, 0 },
	{ 0, -1, golden }, { 0, 1, golden }, { 0, -1, -golden }, { 0, 1, -golden },
	{ golden, 0, -1 }, { golden, 0, 1 }, { -golden, 0, -1 }, { -golden, 0, 1 },
}
local faces = {
	{ 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
	{ 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
	{ 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
	{ 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
}

-- Cache the twenty face bases once. No part scan or mesh rebuild in the hot path.
local inv = 1 / math.sqrt(1 + golden * golden)
for _, v in ipairs(vertices) do
	for axis = 1, 3 do v[axis] = v[axis] * inv end
end
for _, face in ipairs(faces) do
	local a, b, cc = vertices[face[1]], vertices[face[2]], vertices[face[3]]
	local cx, cy, cz = (a[1] + b[1] + cc[1]) / 3, (a[2] + b[2] + cc[2]) / 3, (a[3] + b[3] + cc[3]) / 3
	local nx = math.sqrt(cx * cx + cy * cy + cz * cz)
	local ax, ay, az = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(ax * ax + ay * ay + az * az)
	face.center = { cx, cy, cz }
	face.normal = { cx / nx, cy / nx, cz / nx }
	face.axis = { ax / length, ay / length, az / length }
end

function M.px(t, c, x6, x9)
	x6.pre = x6.pre or {}
	local st = x6.pre[NAME]
	if not st then
		st = { phase = 0, t = t }
		x6.pre[NAME] = st
	end
	st.phase = st.phase + (t - st.t) * math.clamp(c.k13 or 12, 0, 40) * x9.c2
	st.t = t
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local id = d.slot or d.id or 1
	local pick = (id * PHI) % 1
	local u, v, w = (id * 0.8191725133961645) % 1, (id * 0.6710436067037893) % 1, (id * 0.5497004779019703) % 1
	local st = x6.pre and x6.pre[NAME]
	local phase = st and st.phase or 0
	local radius = math.clamp(c.k11 or 90, 20, 300)
	local burst = ((1 - math.cos(phase)) * 0.5) ^ 3
	local distance = math.clamp(c.k12 or 130, 0, 250) / 100
	local x, y, z

	if pick < 0.12 then
		local sy = 1 - 2 * u
		local r = radius * math.clamp(c.k15 or 24, 5, 60) / 100 * (1 + burst * 0.2)
		local ring = math.sqrt(math.max(0, 1 - sy * sy))
		x, y, z = r * ring * math.cos(v * TAU + phase), r * sy, r * ring * math.sin(v * TAU + phase)
	else
		local index = (id - 1) % #faces + 1
		local face = faces[index]
		local a, b, cc = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		local wa, wb, wc
		if c.k17 ~= false and w < 0.7 then
			local root = math.sqrt(u)
			wa, wb, wc = 1 - root, root * (1 - v), root * v
		else
			local edge = math.floor(v * 3)
			if edge == 0 then wa, wb, wc = 1 - u, u, 0
			elseif edge == 1 then wa, wb, wc = 0, 1 - u, u
			else wa, wb, wc = u, 0, 1 - u end
		end
		local center, normal, axis = face.center, face.normal, face.axis
		local lx = a[1] * wa + b[1] * wb + cc[1] * wc - center[1]
		local ly = a[2] * wa + b[2] * wb + cc[2] * wc - center[2]
		local lz = a[3] * wa + b[3] * wb + cc[3] * wc - center[3]
		local angle = burst * math.rad(math.clamp(c.k14 or 160, 0, 720)) * (index % 2 == 0 and 1 or -1)
		local ca, sa = math.cos(angle), math.sin(angle)
		local dot = lx * axis[1] + ly * axis[2] + lz * axis[3]
		local push = burst * distance * (0.85 + 0.15 * math.sin(index * 2.4))
		-- Rodrigues rotation keeps each triangle rigid as it tumbles away and reforms.
		x = radius * (center[1] + normal[1] * push + lx * ca + (axis[2] * lz - axis[3] * ly) * sa + axis[1] * dot * (1 - ca))
		y = radius * (center[2] + normal[2] * push + ly * ca + (axis[3] * lx - axis[1] * lz) * sa + axis[2] * dot * (1 - ca))
		z = radius * (center[3] + normal[3] * push + lz * ca + (axis[1] * ly - axis[2] * lx) * sa + axis[3] * dot * (1 - ca))
	end

	local ca, sa = math.cos(phase * 0.18), math.sin(phase * 0.18)
	local target = cen + Vector3.new(x * ca - z * sa, y + (c.k16 or 120), x * sa + z * ca)
	return (target - p.Position) * (x1.k10 * x9.c1), target
end

function M.cleanup(x6)
	if x6.pre then x6.pre[NAME] = nil end
end

M.Controls = {
	{ Type = "Slider", Name = "Shell Radius", Min = 20, Max = 300, Key = "k11", Default = 90 },
	{ Type = "Slider", Name = "Shatter Distance %", Min = 0, Max = 250, Key = "k12", Default = 130, IntOnly = true },
	{ Type = "Slider", Name = "Shatter Speed", Min = 0, Max = 40, Key = "k13", Default = 12, ExactMax = true },
	{ Type = "Slider", Name = "Shard Tumble", Min = 0, Max = 720, Key = "k14", Default = 160 },
	{ Type = "Slider", Name = "Core Radius %", Min = 5, Max = 60, Key = "k15", Default = 24, IntOnly = true },
	{ Type = "Slider", Name = "Hover Height", Min = -100, Max = 500, Key = "k16", Default = 120 },
	{ Type = "Toggle", Name = "Solid Shards", Key = "k17", Default = true,
		Desc = "Fill the triangular shards. Turn off for a wireframe shell." },
}

return M
