return function(context, x7)
	local v1, v4, v8, v9 = context.v1, context.v4, context.v8, context.v9
	local x1, x6 = context.x1, context.x6

	return function()
		local function sculptor_clear_highlights()
			for part, highlight in pairs(x6.sculptor_highlights) do
				if highlight and highlight.Parent then
					highlight:Destroy()
				end
			end
			x6.sculptor_highlights = {}
		end

		local function sculptor_add_highlight(part)
			if x6.sculptor_highlights[part] then
				return
			end
			local highlight = Instance.new("SelectionBox")
			highlight.Adornee = part
			highlight.Color3 = Color3.fromRGB(0, 255, 200)
			highlight.LineThickness = 0.05
			highlight.SurfaceTransparency = 0.8
			highlight.SurfaceColor3 = Color3.fromRGB(0, 255, 200)
			highlight.Parent = part
			x6.sculptor_highlights[part] = highlight
		end

		local function sculptor_remove_highlight(part)
			if x6.sculptor_highlights[part] then
				x6.sculptor_highlights[part]:Destroy()
				x6.sculptor_highlights[part] = nil
			end
		end

		local function sculptor_select(part, add_to_selection)
			if not add_to_selection then
				for p, _ in pairs(x6.sculptor_selected) do
					sculptor_remove_highlight(p)
				end
				x6.sculptor_selected = {}
			end
			if part and x6.a[part] then
				x6.sculptor_selected[part] = Vector3.zero
				sculptor_add_highlight(part)
			end
		end

		local function sculptor_deselect(part)
			x6.sculptor_selected[part] = nil
			sculptor_remove_highlight(part)
		end

		local function sculptor_get_mouse_world_pos(distance)
			local cam = v4.CurrentCamera
			if not cam then
				return nil
			end
			local mp = v1:GetMouseLocation()
			local ray = cam:ViewportPointToRay(mp.X, mp.Y)
			return ray.Origin + (ray.Direction * distance)
		end

		local function get_touch_target(input)
			local cam = v4.CurrentCamera
			if not cam then
				return nil
			end
			local ray = cam:ViewportPointToRay(input.Position.X, input.Position.Y)
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { v8.Character }
			local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, rp)
			return result and result.Instance
		end

		table.insert(
			x6.c,
			v1.InputBegan:Connect(function(input, processed)
				if processed or x1.k6 ~= "Sculptor" then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local target
					if input.UserInputType == Enum.UserInputType.Touch then
						target = get_touch_target(input)
					else
						target = v9.Target
					end

					local shift_held = v1:IsKeyDown(Enum.KeyCode.LeftShift)
						or v1:IsKeyDown(Enum.KeyCode.RightShift)
						or (x1.SculptorMultiSelect == true)

					if target and x6.a[target] then
						if x6.sculptor_selected[target] then
							if shift_held then
								sculptor_deselect(target)
							else
								x6.sculptor_dragging = true
								x6.sculptor_drag_start = target.Position
								x6.sculptor_drag_distance = (v4.CurrentCamera.CFrame.Position - target.Position).Magnitude
								x6.sculptor_drag_target = target.Position
								for part, _ in pairs(x6.sculptor_selected) do
									x6.sculptor_selected[part] = part.Position - target.Position
								end
							end
						else
							sculptor_select(target, shift_held)
							if not shift_held then
								x6.sculptor_dragging = true
								x6.sculptor_drag_start = target.Position
								x6.sculptor_drag_distance = (v4.CurrentCamera.CFrame.Position - target.Position).Magnitude
								x6.sculptor_drag_target = target.Position
								x6.sculptor_selected[target] = Vector3.zero
							end
						end
					else
						if not shift_held then
							for p, _ in pairs(x6.sculptor_selected) do
								sculptor_remove_highlight(p)
							end
							x6.sculptor_selected = {}
						end
						x6.sculptor_box_start = v1:GetMouseLocation()
						if not x6.sculptor_box and x6.sg then
							x6.sculptor_box = Instance.new("Frame", x6.sg)
							x6.sculptor_box.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
							x6.sculptor_box.BackgroundTransparency = 0.7
							x6.sculptor_box.BorderSizePixel = 2
							x6.sculptor_box.BorderColor3 = Color3.fromRGB(0, 255, 200)
							x6.sculptor_box.ZIndex = 50
						end
					end
				end
			end)
		)

		table.insert(
			x6.c,
			v1.InputChanged:Connect(function(input, processed)
				if x1.k6 ~= "Sculptor" then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					if x6.sculptor_dragging then
						x6.sculptor_drag_target = sculptor_get_mouse_world_pos(x6.sculptor_drag_distance or 50)
					elseif x6.sculptor_box_start and x6.sculptor_box then
						local current = v1:GetMouseLocation()
						local minX = math.min(x6.sculptor_box_start.X, current.X)
						local minY = math.min(x6.sculptor_box_start.Y, current.Y)
						local maxX = math.max(x6.sculptor_box_start.X, current.X)
						local maxY = math.max(x6.sculptor_box_start.Y, current.Y)
						x6.sculptor_box.Position = UDim2.new(0, minX, 0, minY)
						x6.sculptor_box.Size = UDim2.new(0, maxX - minX, 0, maxY - minY)
						x6.sculptor_box.Visible = true
					end
				end
			end)
		)

		table.insert(
			x6.c,
			v1.InputEnded:Connect(function(input)
				if x1.k6 ~= "Sculptor" then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if x6.sculptor_dragging then
						x6.sculptor_dragging = false
						x6.sculptor_drag_target = nil
					end
					if x6.sculptor_box_start and x6.sculptor_box then
						local current = v1:GetMouseLocation()
						local minX = math.min(x6.sculptor_box_start.X, current.X)
						local minY = math.min(x6.sculptor_box_start.Y, current.Y)
						local maxX = math.max(x6.sculptor_box_start.X, current.X)
						local maxY = math.max(x6.sculptor_box_start.Y, current.Y)

						local cam = v4.CurrentCamera
						if cam then
							for part, _ in pairs(x6.a) do
								local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
								if
									onScreen
									and screenPos.X >= minX
									and screenPos.X <= maxX
									and screenPos.Y >= minY
									and screenPos.Y <= maxY
								then
									x6.sculptor_selected[part] = Vector3.zero
									sculptor_add_highlight(part)
								end
							end
						end

						x6.sculptor_box.Visible = false
						x6.sculptor_box_start = nil
					end
				end
			end)
		)
	end
end
