local M = {}

function M.f2(p, cen, d, t, c, x1, x6, x9)
	local wp = p.Position
	local dist = wp - cen
	local mag = dist.Magnitude
	
	local power = c.k11 or 1500
	local radius = c.k12 or 80
	
	if not d.v6 then
		d.v6 = math.random() * math.pi * 2
		d.nx = math.random() * 1000
		d.ny = math.random() * 1000
		d.nz = math.random() * 1000
	end
	
	d.nx = d.nx or math.random() * 1000
	d.ny = d.ny or math.random() * 1000
	d.nz = d.nz or math.random() * 1000
	
	local dir
	if mag < 0.1 then
		dir = Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5).Unit
	else
		dir = dist.Unit
	end
	
	if mag > radius * 0.95 then
		local hover_y = math.sin(t * 1.0 + d.v6) * 3
		local hover_x = math.sin(t * 0.5 + d.nx) * 1.5
		local hover_z = math.cos(t * 0.6 + d.nz) * 1.5
		
		local anchor_force = Vector3.zero
		if mag > radius * 1.05 then
			anchor_force = -dir * (mag - radius) * 5
		end
		
		return Vector3.new(hover_x, hover_y, hover_z) + anchor_force
	end
	
	if not d.red_fx_time or (t - d.red_fx_time) > 1 then
		d.red_fx_time = t
		task.spawn(function()
			pcall(function()
				local att = Instance.new("Attachment")
				att.Parent = p
				
				local emit = Instance.new("ParticleEmitter")
				emit.Color = ColorSequence.new(Color3.fromRGB(255, 30, 30))
				emit.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0)})
				emit.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
				emit.Lifetime = NumberRange.new(0.3, 0.6)
				emit.Speed = NumberRange.new(10, 30)
				emit.SpreadAngle = Vector2.new(180, 180)
				emit.ZOffset = 1
				emit.Parent = att
				
				emit:Emit(15)
				
				local trail = Instance.new("Trail")
				trail.Color = ColorSequence.new(Color3.fromRGB(255, 50, 50))
				trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
				trail.Lifetime = 0.4
				trail.MinLength = 0.1
				
				local att0 = Instance.new("Attachment", p)
				att0.Position = Vector3.new(0, 0.5, 0)
				local att1 = Instance.new("Attachment", p)
				att1.Position = Vector3.new(0, -0.5, 0)
				
				trail.Attachment0 = att0
				trail.Attachment1 = att1
				trail.Parent = p
				
				task.wait(1.5)
				att:Destroy()
				att0:Destroy()
				att1:Destroy()
				trail:Destroy()
			end)
		end)
	end
	
	return dir * power
end

M.Controls = {
	{ Type = "Slider", Name = "Repulsion Power", Min = 100, Max = 5000, Key = "k11" },
	{ Type = "Slider", Name = "Blast Radius", Min = 10, Max = 500, Key = "k12" }
}



return M
