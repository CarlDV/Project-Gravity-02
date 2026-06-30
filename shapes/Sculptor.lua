local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local tc = cen - wp
	local md = "Sculptor"

			if x6.sculptor_selected[p] then
				if x6.sculptor_dragging and x6.sculptor_drag_target then

					local target = x6.sculptor_drag_target
					local offset = x6.sculptor_selected[p] or Vector3.zero
					local target_pos = target + offset
					local delta = target_pos - wp
					local dist = delta.Magnitude

					if dist < 0.5 then
						return Vector3.new(0, 0.01, 0)
					else

						local speed = math.clamp(dist * 3, 1, 100)
						return delta.Unit * speed
					end
				else

					return Vector3.new(0, 0.01, 0)
				end
			else

				return Vector3.new(0, 0.01, 0)
			end
end

M.Description = "Allows manual shaping and positioning of parts."

return M
