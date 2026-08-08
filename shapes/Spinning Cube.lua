local M = {}

local FACE_KEEP = 1

-- One spin phase for the whole cube, stamped once per bucket cycle.
--
-- Integrating the phase per part (the previous approach) looks correct because
-- each part's dt chain telescopes to the same total -- but only for parts that
-- were present when the spin started. A part claimed later begins at phase 0
-- mid-rotation and stays behind the rest forever, so the cube shears. Reading a
-- stamped shared phase instead means a part joins at whatever angle the cube is
-- already at. Stamping per bucket cycle rather than per frame keeps every part
-- on one angle even though k7 only runs each part on one frame in et; sampling
-- live would hand each bucket a different angle and shear the cube again.
function M.px(t, c, x6, x9, x1)
	local st = x6.pre["Spinning Cube"]
	if not st then
		st = { phase = 0, pub = 0, t = t }
		x6.pre["Spinning Cube"] = st
	end

	local dt = t - (st.t or t)
	st.t = t
	if dt <= 0 then
		dt = 1 / 60
	elseif dt > 0.25 then
		dt = 0.25
	end
	st.phase = st.phase + dt * ((c.k12 or 200) * 0.05)

	local et = x1 and x1.k7
	if not et then
		local n = x6.n or 0
		et = n > 5000 and 10 or (n > 2500 and 6 or (n > 1000 and 3 or 1))
	end
	if x1 and x1["Force Smooth (Lags)"] then
		et = 1
	end
	if et < 1 then
		et = 1
	end

	local gen = math.floor((x6.f or 0) / et)
	if st.gen == gen then
		return
	end
	st.gen = gen
	st.pub = st.phase
end

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	if not d.f then
		d.f = math.random(1, 6)
		d.u = math.random() * 2 - 1
		d.v = math.random() * 2 - 1
	end

	local f, u, v = d.f, d.u, d.v

	-- Cut In Half folds the far half onto the near one across the local x = 0
	-- plane. u is the x coordinate on every side face, so mirroring it moves a
	-- part to the kept side and the -x face collapses onto +x.
	--
	-- Deleting the -x face and returning cen for it, as this used to, is not a
	-- half: it opens one hole in six and stacks every part from that face into a
	-- blob at the centre, visible through the hole. Folding keeps the parts on
	-- the surface, so the cut face reads as open and the kept half doubles in
	-- density instead of losing a sixth of the cube to a clump.
	if c.k13 == true then
		if f == 2 then
			f = FACE_KEEP
		elseif f > 2 and u < 0 then
			u = -u
		end
	end

	local lx, ly, lz = 0, 0, 0
	if f == 1 then lx, ly, lz = 1, u, v
	elseif f == 2 then lx, ly, lz = -1, u, v
	elseif f == 3 then lx, ly, lz = u, 1, v
	elseif f == 4 then lx, ly, lz = u, -1, v
	elseif f == 5 then lx, ly, lz = u, v, 1
	else lx, ly, lz = u, v, -1
	end

	local rad = c.k11 or 40
	lx, ly, lz = lx * rad, ly * rad, lz * rad

	local st = x6.pre and x6.pre["Spinning Cube"]
	local a = st and st.pub or 0
	local ca, sa = math.cos(a), math.sin(a)
	local rx, ry, rz = lx, ly, lz

	local rotY = (c.k14 == true)
	local rotX = (c.k15 == true)

	if not rotY and not rotX then
		rotX = true
	end

	if rotY then
		local nx = rx * ca + rz * sa
		local nz = -rx * sa + rz * ca
		rx, rz = nx, nz
	end

	if rotX then
		local ny = ry * ca - rz * sa
		local nz = ry * sa + rz * ca
		ry, rz = ny, nz
	end

	local target_pos = cen + Vector3.new(rx, ry, rz)
	return (target_pos - wp) * (x1.k10 * x9.c1), target_pos
end

function M.cleanup(x6, x1)
	if x6.pre then
		x6.pre["Spinning Cube"] = nil
	end
end

M.Controls = {
	{ Type = "Slider", Name = "Radius", Min = 5, Max = 300, Key = "k11" },
	{ Type = "Slider", Name = "Spin Speed", Min = 0, Max = 400, Key = "k12" },
	{ Type = "Toggle", Name = "Cut In Half", Key = "k13" },
	{ Type = "Toggle", Name = "Rotate Y Axis", Key = "k14" },
	{ Type = "Toggle", Name = "Rotate X Axis", Key = "k15" }
}

return M
