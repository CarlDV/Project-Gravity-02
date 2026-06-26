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
		elseif typeof(v) == "Instance" or typeof(v) == "function" or typeof(v) == "userdata" then
		else
			res[k] = v
		end
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
