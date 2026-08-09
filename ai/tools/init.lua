-- Collects the tool groups into the two shapes the agent loop needs: a name ->
-- handler map and the OpenAI-format definition list. Adding a tool group means
-- adding one entry to GROUPS; nothing else here changes.
local GROUPS = { "web", "roblox", "files", "engine" }

return function(env)
	local handlers, definitions = {}, {}

	for _, group in ipairs(GROUPS) do
		local tools = env.require("tools/" .. group)
		if tools then
			for _, tool in ipairs(tools) do
				handlers[tool.name] = tool.run
				table.insert(definitions, {
					type = "function",
					["function"] = {
						name = tool.name,
						description = tool.description,
						parameters = tool.parameters
					}
				})
			end
		end
	end

	return { handlers = handlers, definitions = definitions }
end
