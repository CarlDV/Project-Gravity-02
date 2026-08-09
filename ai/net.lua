-- HTTP transport plus the HTML/URL helpers the web tools share.
return function(env)
	local hs = env.hs
	local req_fn = env.req_fn

	local M = {}

	function M.request(urlPath, method, headers, payload)
		local base = env.require("state").session.endpoint
		local fullUrl = urlPath:find("^https?://") and urlPath or (base .. urlPath)
		local opts = {
			Url = fullUrl,
			Method = method or "GET",
			Headers = headers or {}
		}
		if payload and payload ~= "" and method ~= "GET" and method ~= "HEAD" then
			opts.Body = payload
		end
		if req_fn then
			local ok, res = pcall(req_fn, opts)
			if ok and res then
				return {
					StatusCode = res.StatusCode or res.Status or 200,
					Body = res.Body or res.ResponseData or ""
				}
			end
			return nil, ok and "empty executor response" or tostring(res)
		else
			local ok, res = pcall(function() return hs:RequestAsync(opts) end)
			if ok and res then
				return {
					StatusCode = res.StatusCode,
					Body = res.Body
				}
			end
			return nil, ok and "empty HttpService response" or tostring(res)
		end
	end

	function M.urlEncode(str)
		return (str:gsub("[^%w%-_%.~]", function(c)
			return string.format("%%%02X", string.byte(c))
		end))
	end

	function M.htmlEntities(str)
		return (str
			:gsub("&amp;", "&")
			:gsub("&lt;", "<")
			:gsub("&gt;", ">")
			:gsub("&quot;", '"')
			:gsub("&#x27;", "'")
			:gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end)
		)
	end

	return M
end
