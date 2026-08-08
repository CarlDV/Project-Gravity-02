-- Minimal but real Roblox value-type math, so the shape modules can actually be
-- executed rather than merely parsed. Only what the three new shapes touch.
local M = {}

local V3 = {}
V3.__index = function(v, k)
	if k == "X" then return rawget(v, 1) end
	if k == "Y" then return rawget(v, 2) end
	if k == "Z" then return rawget(v, 3) end
	if k == "Magnitude" then
		local x, y, z = rawget(v, 1), rawget(v, 2), rawget(v, 3)
		return math.sqrt(x * x + y * y + z * z)
	end
	if k == "Unit" then
		local m = v.Magnitude
		if m == 0 then return M.Vector3.new(0, 0, 0) end
		return M.Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return V3[k]
end
function V3.__add(a, b) return M.Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function V3.__sub(a, b) return M.Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function V3.__unm(a) return M.Vector3.new(-a.X, -a.Y, -a.Z) end
function V3.__mul(a, b)
	if type(a) == "number" then return M.Vector3.new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return M.Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return M.Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function V3.__div(a, b)
	if type(b) == "number" then return M.Vector3.new(a.X / b, a.Y / b, a.Z / b) end
	return M.Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
function V3.__eq(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V3.__tostring(a) return ("(%.3f, %.3f, %.3f)"):format(a.X, a.Y, a.Z) end
function V3:Cross(o)
	return M.Vector3.new(
		self.Y * o.Z - self.Z * o.Y,
		self.Z * o.X - self.X * o.Z,
		self.X * o.Y - self.Y * o.X
	)
end
function V3:Dot(o) return self.X * o.X + self.Y * o.Y + self.Z * o.Z end

M.Vector3 = {
	new = function(x, y, z)
		return setmetatable({ x or 0, y or 0, z or 0 }, V3)
	end,
}
M.Vector3.zero = M.Vector3.new(0, 0, 0)
M.Vector3.xAxis = M.Vector3.new(1, 0, 0)
M.Vector3.yAxis = M.Vector3.new(0, 1, 0)

-- CFrame as position + row-major 3x3 rotation.
local CF = {}
CF.__index = function(cf, k)
	if k == "Position" then return rawget(cf, "p") end
	if k == "LookVector" then
		local r = rawget(cf, "r")
		return M.Vector3.new(-r[3], -r[6], -r[9])
	end
	if k == "RightVector" then
		local r = rawget(cf, "r")
		return M.Vector3.new(r[1], r[4], r[7])
	end
	if k == "UpVector" then
		local r = rawget(cf, "r")
		return M.Vector3.new(r[2], r[5], r[8])
	end
	return CF[k]
end

local function mk(p, r)
	return setmetatable({ p = p, r = r }, CF)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
-- LuaJIT is 5.1 (bare unpack); Luau and 5.4 expose table.unpack.
local unpack_compat = table.unpack or unpack

function CF.__mul(a, b)
	if getmetatable(b) == V3 then
		local r = rawget(a, "r")
		return M.Vector3.new(
			r[1] * b.X + r[2] * b.Y + r[3] * b.Z + a.Position.X,
			r[4] * b.X + r[5] * b.Y + r[6] * b.Z + a.Position.Y,
			r[7] * b.X + r[8] * b.Y + r[9] * b.Z + a.Position.Z
		)
	end
	local ar, br = rawget(a, "r"), rawget(b, "r")
	local out = {}
	for i = 0, 2 do
		for j = 1, 3 do
			out[i * 3 + j] = ar[i * 3 + 1] * br[j] + ar[i * 3 + 2] * br[3 + j] + ar[i * 3 + 3] * br[6 + j]
		end
	end
	local bp = b.Position
	local np = M.Vector3.new(
		ar[1] * bp.X + ar[2] * bp.Y + ar[3] * bp.Z + a.Position.X,
		ar[4] * bp.X + ar[5] * bp.Y + ar[6] * bp.Z + a.Position.Y,
		ar[7] * bp.X + ar[8] * bp.Y + ar[9] * bp.Z + a.Position.Z
	)
	return mk(np, out)
end

function CF:Inverse()
	local r = rawget(self, "r")
	-- Rotation is orthonormal here, so the transpose is the inverse.
	local t = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	local p = self.Position
	local np = M.Vector3.new(
		-(t[1] * p.X + t[2] * p.Y + t[3] * p.Z),
		-(t[4] * p.X + t[5] * p.Y + t[6] * p.Z),
		-(t[7] * p.X + t[8] * p.Y + t[9] * p.Z)
	)
	return mk(np, t)
end

M.CFrame = {
	new = function(a, b, c)
		if type(a) == "number" then return mk(M.Vector3.new(a, b, c), { unpack_compat(IDENT) }) end
		return mk(a or M.Vector3.zero, { unpack_compat(IDENT) })
	end,
	fromAxisAngle = function(axis, ang)
		local u = axis.Unit
		local x, y, z = u.X, u.Y, u.Z
		local ca, sa = math.cos(ang), math.sin(ang)
		local t = 1 - ca
		return mk(M.Vector3.zero, {
			t * x * x + ca,     t * x * y - sa * z, t * x * z + sa * y,
			t * x * y + sa * z, t * y * y + ca,     t * y * z - sa * x,
			t * x * z - sa * y, t * y * z + sa * x, t * z * z + ca,
		})
	end,
}
M.CFrame.identity = M.CFrame.new(0, 0, 0)

return M
