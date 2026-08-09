-- File tools: plain script saving plus custom shape read/write with hot reload.
return function(env)
	local context = env.context
	local AUTH_DIR = env.require("state").AUTH_DIR

	-- Returns nil when the name is empty after sanitising and no fallback is given,
	-- so callers can report that rather than writing a bare '.lua'.
	local function shapePaths(rawArg, fallback)
		local rawName = tostring(rawArg or ""):gsub("[/\\]", ""):match("^%s*(.-)%s*$")
		if rawName == "" then rawName = fallback or "" end
		if rawName == "" then return nil end
		if not rawName:lower():match("%.lua$") then rawName = rawName .. ".lua" end
		local cleanName = rawName:gsub("%.lua$", ""):gsub("%.txt$", "")
		return rawName, cleanName
	end

	return {
		{
			name = "save_script",
			description = "Save general Luau script to workspace file.",
			parameters = {
				type = "object",
				properties = {
					code = { type = "string", description = "Luau source code to save." },
					name = { type = "string", description = "File name (e.g. 'my_script.lua')." }
				},
				required = { "code", "name" }
			},
			run = function(args)
				if type(writefile) ~= "function" then return "writefile unavailable" end
				local code = tostring(args.code or "")
				if code == "" then return "Code empty" end
				local name = tostring(args.name or "script"):gsub("[/\\]", "_"):gsub("[^%w%-_%. ]", ""):match("^%s*(.-)%s*$")
				if name == "" then name = "script" end
				if not name:lower():match("%.lua$") then name = name .. ".lua" end
				local path = name
				if type(makefolder) == "function" then
					local okFolder = pcall(function() return type(isfolder) == "function" and isfolder(AUTH_DIR) end)
					if not okFolder then pcall(makefolder, AUTH_DIR) end
					path = AUTH_DIR .. "/" .. name
				end
				local ok, err = pcall(writefile, path, code)
				return ok and ("Saved to: " .. path) or ("Save failed: " .. tostring(err))
			end
		},
		{
			name = "save_custom_shape",
			description = "Save or overwrite a custom shape module in 'GravityShapes/'.",
			parameters = {
				type = "object",
				properties = {
					code = { type = "string", description = "The complete custom shape module code implementing M.f2 and M.Controls." },
					name = { type = "string", description = "The shape name (e.g. 'Spiral Galaxy')." }
				},
				required = { "code", "name" }
			},
			run = function(args)
				if type(writefile) ~= "function" then return "writefile unavailable" end
				local code = tostring(args.code or "")
				if code == "" then return "Code empty" end
				local rawName, shapeCleanName = shapePaths(args.name, "CustomShape")

				if type(makefolder) == "function" then
					pcall(function()
						if type(isfolder) == "function" and not isfolder("GravityShapes") then
							makefolder("GravityShapes")
						end
					end)
				end

				local path = "GravityShapes/" .. rawName
				local ok, err = pcall(writefile, path, code)
				if not ok then
					return "Save failed: " .. tostring(err)
				end

				local local_shapes = context.local_shapes
				local loaded_shapes = context.loaded_shapes
				local x2 = context.x2

				if local_shapes then
					local_shapes[shapeCleanName] = path
				end
				if loaded_shapes then
					loaded_shapes[shapeCleanName] = nil
				end

				if x2 then
					if not x2[shapeCleanName] then
						x2[shapeCleanName] = {}
					end
					local loadFn = loadstring or (getgenv and getgenv().loadstring)
					if loadFn then
						local func = loadFn(code)
						if func then
							local s, shape_mod = pcall(func)
							if s and type(shape_mod) == "table" and shape_mod.Controls then
								for _, ctrl in ipairs(shape_mod.Controls) do
									if type(ctrl) == "table" and ctrl.Key then
										local default_val = ctrl.Default
										if default_val == nil then default_val = ctrl.Min or 0 end
										if ctrl.Div then default_val = default_val / ctrl.Div end
										x2[shapeCleanName][ctrl.Key] = default_val
									end
								end
							end
						end
					end
				end

				return "Custom shape '" .. shapeCleanName .. "' saved and hot-reloaded into GravityShapes successfully."
			end
		},
		{
			name = "read_custom_shape",
			description = "Read the Luau source code of an existing shape module from 'GravityShapes/'.",
			parameters = {
				type = "object",
				properties = {
					name = { type = "string", description = "The shape module name (e.g. 'Black Hole', 'Celestial Ribbon')." }
				},
				required = { "name" }
			},
			run = function(args)
				if type(readfile) ~= "function" then return "readfile unavailable" end
				local _, shapeCleanName = shapePaths(args.name)
				if not shapeCleanName then return "Shape name empty" end

				local path = "GravityShapes/" .. shapeCleanName .. ".lua"
				local local_shapes = context.local_shapes
				if local_shapes and local_shapes[shapeCleanName] then
					path = local_shapes[shapeCleanName]
				end

				local ok, code = pcall(readfile, path)
				if ok and code then
					return code
				end
				return "Failed to read shape file '" .. path .. "': " .. tostring(code)
			end
		}
	}
end
