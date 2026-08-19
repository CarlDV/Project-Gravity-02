local M = {}

function M.px(t, c, x6, x9)
	if not x6.pre["Domain Expansion Infinite Void"] then
		x6.pre["Domain Expansion Infinite Void"] = table.create(200)
	end
	local r = x6.pre["Domain Expansion Infinite Void"]
	
	local last_t = r.last_t
	local phase = r.phase
	table.clear(r)
	
	local current_time = t
	local dt = current_time - (last_t or current_time)
	r.last_t = current_time
	-- Clamped like Spinning Cube:24-28. r lives in x6.pre, which survives a shape
	-- switch, and t keeps advancing while another shape is selected, so returning
	-- after a minute walked the phase a minute forward in a single frame.
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end
	local s = (c.k13 or 10) * x9.c2
	r.phase = (phase or 0) + (dt * s)
	
	local ph = r.phase
	r[1] = { ca = math.cos(ph), sa = math.sin(ph) }
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Domain Expansion Infinite Void"
	local R = (c.k11 or 200)
			if not d.v4 then
				d.v4 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
			end
			local pd = x6.pre and x6.pre[md] and x6.pre[md][1]
			local ca, sa
			if pd then
				ca, sa = pd.ca, pd.sa
			else
				local pr = x6.pre and x6.pre[md]
				local ph = pr and pr.phase or 0
				ca, sa = math.cos(ph), math.sin(ph)
			end
			local rv
			if c.k19 then
				rv = Vector3.new(d.v4.X * ca - d.v4.Z * sa, d.v4.Y, d.v4.X * sa + d.v4.Z * ca)
			else
				if not d.v5 then
					d.v5 = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
				end
				local k, v = d.v5, d.v4
				rv = v * ca + k:Cross(v) * sa + k * (k:Dot(v) * (1 - ca))
			end
			if c.k18 then
				rv = Vector3.new(rv.X, math.abs(rv.Y), rv.Z)
			end
			local target_pos = cen + (rv * R)
			return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

-- x6.pre survives a shape switch (System.lua:152 only runs M.cleanup), so without
-- this r.last_t came back stale from whenever the shape was last active.
function M.cleanup(x6, x1)
	if x6.pre then
		x6.pre["Domain Expansion Infinite Void"] = nil
	end
end

M.Controls = {
	{ Type = "Slider", Name = "Spin Speed", Min = 1, Max = 1000, Key = "k13", Div = 10 },
	{ Type = "Slider", Name = "Domain Radius", Min = 50, Max = 1000, Key = "k11" },
	{ Type = "Toggle", Name = "Cut in Half", Key = "k18", Default = true },
	{ Type = "Toggle", Name = "Stable Flow", Key = "k19", Default = true }
}



return M
