local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Eldritch Binding"
	local R, H, s, Tendrils = (c.k11 or 100), (c.k12 or 200), (c.k13 or 5) * x9.c2, (c.k14 or 8)
			if not d.v1 then
				local roll = math.random()
				if roll < 0.15 then
					d.v1 = 1
				elseif roll < 0.30 then
					d.v1 = 2
				elseif roll < 0.50 then
					d.v1 = 3
				elseif roll < 0.62 then
					d.v1 = 4
				elseif roll < 0.85 then
					d.v1 = 5
				else
					d.v1 = 6
				end
			end
			if not d.v2 then
				d.v2 = math.random() * math.pi * 2
			end
			if not d.v3 then
				d.v3 = math.random()
			end
			if not d.v4 then
				d.v4 = math.random()
			end

			local phase = t * s
			local tx, ty, tz = 0, 0, 0

			if d.v1 == 1 then

				local star_pts = 5
				local edge_idx = math.floor(d.v2 / (math.pi * 2) * star_pts)
				local a1 = (edge_idx / star_pts) * math.pi * 2 + phase
				local a2 = ((edge_idx + 2) % star_pts / star_pts) * math.pi * 2 + phase
				local lerp_t = d.v3
				local x1p = R * math.cos(a1)
				local z1p = R * math.sin(a1)
				local x2p = R * math.cos(a2)
				local z2p = R * math.sin(a2)
				tx = x1p + (x2p - x1p) * lerp_t
				tz = z1p + (z2p - z1p) * lerp_t
				ty = 10
			elseif d.v1 == 2 then

				local star_pts = 6
				local edge_idx = math.floor(d.v2 / (math.pi * 2) * star_pts)
				local a1 = (edge_idx / star_pts) * math.pi * 2 - phase
				local a2 = ((edge_idx + 2) % star_pts / star_pts) * math.pi * 2 - phase
				local lerp_t = d.v3
				tx = R * math.cos(a1) + (R * math.cos(a2) - R * math.cos(a1)) * lerp_t
				tz = R * math.sin(a1) + (R * math.sin(a2) - R * math.sin(a1)) * lerp_t
				ty = H
			elseif d.v1 == 3 then

				local chain_idx = math.floor(d.v2 / (math.pi * 2) * 10)
				local lower_a = (chain_idx % 5) / 5 * math.pi * 2 + phase
				local upper_a = (chain_idx % 6) / 6 * math.pi * 2 - phase
				local prog = d.v3
				tx = R * math.cos(lower_a) * (1 - prog) + R * math.cos(upper_a) * prog
				tz = R * math.sin(lower_a) * (1 - prog) + R * math.sin(upper_a) * prog
				ty = 10 + prog * (H - 10)

				ty = ty - math.sin(prog * math.pi) * 15
			elseif d.v1 == 4 then

				local node_count = 11
				local node_idx = math.floor(d.v2 / (math.pi * 2) * node_count)
				local is_lower = node_idx < 5
				local node_a
				if is_lower then
					node_a = (node_idx / 5) * math.pi * 2 + phase
					ty = 10
				else
					node_a = ((node_idx - 5) / 6) * math.pi * 2 - phase
					ty = H
				end
				local pulse = math.sin(phase * 3 + node_idx * 2) * 0.5 + 0.5
				local node_r = R + pulse * 15
				tx = node_r * math.cos(node_a) + math.cos(d.v4 * math.pi * 2) * pulse * 8
				tz = node_r * math.sin(node_a) + math.sin(d.v4 * math.pi * 2) * pulse * 8
			elseif d.v1 == 5 then

				local tendril_idx = math.floor(d.v2 / (math.pi * 2) * Tendrils)
				local base_angle = (tendril_idx / Tendrils) * math.pi * 2
				local prog = (d.v3 + phase * 0.5) % 1
				ty = prog * H
				local snake = math.sin(prog * math.pi * 6 + phase * 2 + tendril_idx) * 15
				local tendril_r = 15 + snake + d.v4 * 3
				tx = tendril_r * math.cos(base_angle + prog * math.pi * 2)
				tz = tendril_r * math.sin(base_angle + prog * math.pi * 2)
			else

				local phi = d.v2
				local theta = d.v3 * math.pi
				local breath = math.sin(phase * 0.5) * 0.2 + 1
				local shell_r = R * 1.3 * breath
				tx = shell_r * math.sin(theta) * math.cos(phi + phase * 0.1)
				tz = shell_r * math.sin(theta) * math.sin(phi + phase * 0.1)
				ty = H * 0.5 + shell_r * math.cos(theta)
			end
			return ((cen + Vector3.new(tx, ty, tz)) - wp) * (x1.k10 * x9.c1)
end

M.Controls = {
	{ Type = "Slider", Name = "Sigil Radius", Min = 30, Max = 250, Key = "k11" },
	{ Type = "Slider", Name = "Tower Height", Min = 50, Max = 500, Key = "k12" },
	{ Type = "Slider", Name = "Rotation Speed", Min = 1, Max = 30, Key = "k13" },
	{ Type = "Slider", Name = "Tendril Count", Min = 3, Max = 16, Key = "k14", IntOnly = true }
}

return M