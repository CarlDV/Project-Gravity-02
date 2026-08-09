-- Web tools: search and page fetch.
return function(env)
	local net = env.require("net")

	return {
		{
			name = "web_search",
			description = "Search DDG for live web content and facts.",
			parameters = {
				type = "object",
				properties = { query = { type = "string" }, max = { type = "integer" } },
				required = { "query" }
			},
			run = function(args)
				local q = tostring(args.query or "")
				if q == "" then return "Query parameter missing" end
				local max = tonumber(args.max) or 5
				local body = string.format("q=%s&b=&l=us-en", net.urlEncode(q))
				local res = net.request("https://html.duckduckgo.com/html/", "POST", {
					["Content-Type"] = "application/x-www-form-urlencoded",
					["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
					["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
				}, body)
				if not res or res.StatusCode ~= 200 then return "Search request failed" end
				local records = {}
				for href, title in res.Body:gmatch('<a[^>]+class="result__a"[^>]*href="([^"]*)"[^>]*>(.-)</a>') do
					if #records >= max then break end
					local link = href:match("[?&]uddg=([^&]+)")
					link = link and link:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end) or href
					if not link:find("^https://duckduckgo%.com") then
						table.insert(records, { title = net.htmlEntities(title), url = link })
					end
				end
				local idx = 1
				for snippet in res.Body:gmatch('<a[^>]+class="result__snippet"[^>]*>(.-)</a>') do
					if records[idx] then
						records[idx].snippet = net.htmlEntities(snippet):match("^%s*(.-)%s*$")
						idx += 1
					end
				end
				if #records == 0 then return "No results found" end
				local lines = {}
				for i, item in ipairs(records) do
					table.insert(lines, string.format("%d. %s\n   URL: %s\n   Snippet: %s", i, item.title, item.url, item.snippet or "N/A"))
				end
				return table.concat(lines, "\n\n")
			end
		},
		{
			name = "fetch_page",
			description = "Fetch raw page text from a URL.",
			parameters = {
				type = "object",
				properties = { url = { type = "string" } },
				required = { "url" }
			},
			run = function(args)
				local target = tostring(args.url or "")
				if target == "" then return "URL missing" end
				local res = net.request(target, "GET", {
					["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
				})
				if not res or res.StatusCode ~= 200 then return "Fetch failed" end
				local txt = res.Body:gsub("<script[^>]*>.-</script>", " "):gsub("<style[^>]*>.-</style>", " "):gsub("<[^>]+>", " ")
				txt = net.htmlEntities(txt):gsub("[ \t]+", " "):gsub("\n[ \t]+", "\n"):gsub("\n\n+", "\n\n"):match("^%s*(.-)%s*$") or ""
				if #txt > 3500 then txt = txt:sub(1, 3500) .. "\n...[truncated]" end
				return #txt > 0 and txt or "Empty response"
			end
		}
	}
end
