local M = {}

function M.sanitize(t)
	local res = {}
	for k, v in pairs(t) do
		if typeof(v) == "Vector3" then
			res[k] = { __type = "Vector3", x = v.X, y = v.Y, z = v.Z }
		elseif typeof(v) == "Color3" then
			res[k] = { __type = "Color3", r = v.R, g = v.G, b = v.B }
		elseif typeof(v) == "number" then
			if v == math.huge then
				res[k] = { __type = "inf" }
			elseif v == -math.huge then
				res[k] = { __type = "-inf" }
			elseif v ~= v then
				res[k] = { __type = "nan" }
			else
				res[k] = v
			end
		elseif typeof(v) == "table" then
			res[k] = M.sanitize(v)
		elseif typeof(v) == "string" or typeof(v) == "boolean" then
			res[k] = v
		end
		-- Anything not named above is dropped, deliberately. This was a denylist of
		-- Instance/function/userdata, which cannot work: Luau's typeof never returns
		-- "userdata" for a Roblox datatype, it returns the concrete name -- "CFrame",
		-- "UDim2", "EnumItem", "NumberSequence". So every one of those fell through
		-- to the else, reached JSONEncode, and threw. main.lua swallows that in a
		-- pcall, so one such value anywhere in x1 or x2 silently stopped settings
		-- from saving for that session and every session after it, with no
		-- diagnostic at all. An allowlist fails safe instead: an unsupported type
		-- loses that one key rather than the whole file.
	end
	return res
end

function M.desanitize(t)
	local res = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			if v.__type == "Vector3" then
				res[k] = Vector3.new(v.x, v.y, v.z)
			elseif v.__type == "Color3" then
				res[k] = Color3.new(v.r, v.g, v.b)
			elseif v.__type == "inf" then
				res[k] = math.huge
			elseif v.__type == "-inf" then
				res[k] = -math.huge
			elseif v.__type == "nan" then
				res[k] = 0/0
			else
				res[k] = M.desanitize(v)
			end
		else
			res[k] = v
		end
	end
	return res
end

return M
