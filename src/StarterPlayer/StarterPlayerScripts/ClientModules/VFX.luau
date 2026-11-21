--[[
	VFX (Client): alle visuellen Effekte. Server sendet Ereignisse, der Client stellt sie dar.
	Jede Attacke hat eigene Form/Farbe/Bewegung. Warnzeichen: farbige Füllung + rote Kontur,
	die sich während der Ausholzeit füllt (Timing ablesbar). Alle temporären Teile werden
	zuverlässig per Debris/Timeout entfernt.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attacks = require(Shared.Config.Attacks)
local Spheres = require(Shared.Config.Spheres)
local Sounds = require(Shared.Config.Sounds)
local Weapons = require(Shared.Config.Weapons)

local VFX = {}
local player = Players.LocalPlayer
local fx = workspace:FindFirstChild("ClientFX") or Instance.new("Folder")
fx.Name = "ClientFX"
fx.Parent = workspace
VFX.Folder = fx

local RED = Color3.fromRGB(255, 55, 55)
local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	core = "rbxasset://textures/particles/explosion01_core_main.dds",
	shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	square = "rbxasset://textures/particles/SquareParticle.png",
	fsparks = "rbxasset://textures/particles/fire_sparks_main.dds",
}

local function rad(d) return math.rad(d) end
local function now() return workspace:GetServerTimeNow() end

------------------------------------------------------------------ Grundbausteine
local function part(props)
	local p = Instance.new(props.class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = props.material or Enum.Material.Neon
	p.Color = props.color or Color3.new(1, 1, 1)
	p.Transparency = props.t or 0
	if props.shape then p.Shape = props.shape end
	p.Size = props.size or Vector3.one
	p.CFrame = props.cf or CFrame.new()
	if props.mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = props.mesh
		m.Parent = p
	end
	p.Parent = props.parent or fx
	if props.life then Debris:AddItem(p, props.life) end
	return p
end
VFX.Part = part

local function tween(inst, t, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
VFX.Tween = tween

local function emitter(parent, o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or TEX.spark
	e.Color = typeof(o.color) == "ColorSequence" and o.color or ColorSequence.new(o.color or Color3.new(1, 1, 1))
	e.LightEmission = o.light or 0.8
	e.Lifetime = NumberRange.new(o.life and o.life[1] or 0.4, o.life and o.life[2] or 0.8)
	e.Speed = NumberRange.new(o.speed and o.speed[1] or 5, o.speed and o.speed[2] or 12)
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.Size = typeof(o.size) == "NumberSequence" and o.size or NumberSequence.new(o.size or 1, 0)
	e.Transparency = o.trans or NumberSequence.new(0, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.Rate = o.rate or 0
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.LockedToPart = o.locked or false
	e.Parent = parent
	return e
end
VFX.Emitter = emitter

local function burst(pos, o)
	local a = part({ size = Vector3.new(0.2, 0.2, 0.2), cf = CFrame.new(pos), t = 1, life = 3 })
	local e = emitter(a, o)
	e:Emit(o.count or 20)
	return a
end
VFX.Burst = burst

local function light(pos, color, range, t, brightness)
	local a = part({ size = Vector3.new(0.2, 0.2, 0.2), cf = CFrame.new(pos), t = 1, life = t + 0.1 })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 3
	l.Parent = a
	tween(l, t, { Brightness = 0 })
end

local soundCache = {}
function VFX.Sound(key, pos, vol, speed)
	local s = Sounds[key]
	if not s then return end
	local snd = Instance.new("Sound")
	snd.SoundId = s.id
	snd.Volume = (vol or 1) * s.volume
	snd.PlaybackSpeed = (speed or 1) * s.speed * (0.94 + math.random() * 0.12)
	if pos then
		local a = part({ size = Vector3.new(0.2, 0.2, 0.2), cf = CFrame.new(pos), t = 1, life = 4 })
		snd.RollOffMaxDistance = 220
		snd.RollOffMinDistance = 12
		snd.Parent = a
	else
		snd.Parent = SoundService
		Debris:AddItem(snd, 4)
	end
	snd:Play()
end

local function flatCF(pos)
	return CFrame.new(pos) * CFrame.Angles(0, 0, rad(90))
end

-- gefüllte Scheibe (flacher Zylinder)
local function disc(pos, radius, color, t, h, life)
	return part({ shape = Enum.PartType.Cylinder, size = Vector3.new(h or 0.12, radius * 2, radius * 2), cf = flatCF(pos + Vector3.new(0, 0.12, 0)), color = color, t = t or 0.5, life = life })
end

-- Kreiskontur aus Segmenten
local function ringOutline(pos, radius, color, life, thick)
	local model = Instance.new("Model")
	local n = math.clamp(math.floor(radius * 1.6), 14, 36)
	local seg = 2 * math.pi * radius / n * 1.08
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = pos + Vector3.new(math.cos(a) * radius, 0.2, math.sin(a) * radius)
		part({ size = Vector3.new(thick or 0.35, 0.15, seg), cf = CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), color = color, t = 0.05, parent = model })
	end
	model.Parent = fx
	if life then Debris:AddItem(model, life) end
	return model
end

-- Rechteck auf dem Boden (Linien-Warnung)
local function rect(from, dir, length, width, color, t, life)
	local mid = from + dir * (length / 2) + Vector3.new(0, 0.15, 0)
	return part({ size = Vector3.new(width, 0.12, length), cf = CFrame.lookAt(mid, mid + dir), color = color, t = t or 0.55, life = life })
end

local function rectOutline(from, dir, length, width, color, life)
	local model = Instance.new("Model")
	local right = Vector3.new(-dir.Z, 0, dir.X)
	for _, s in ipairs({ -1, 1 }) do
		local a = from + right * (width / 2) * s + dir * (length / 2) + Vector3.new(0, 0.2, 0)
		part({ size = Vector3.new(0.3, 0.15, length), cf = CFrame.lookAt(a, a + dir), color = color, t = 0.05, parent = model })
	end
	local e = from + dir * length + Vector3.new(0, 0.2, 0)
	part({ size = Vector3.new(width, 0.15, 0.3), cf = CFrame.lookAt(e, e + dir), color = color, t = 0.05, parent = model })
	model.Parent = fx
	if life then Debris:AddItem(model, life) end
	return model
end

local function shockwave(pos, r0, r1, color, t)
	local d = disc(pos, r0, color, 0.3, 0.3, t + 0.1)
	tween(d, t, { Size = Vector3.new(0.3, r1 * 2, r1 * 2), Transparency = 1 })
end
VFX.Shockwave = shockwave

local function creatureModel(id)
	for _, m in ipairs(workspace.Runtime.Creatures:GetChildren()) do
		if m:GetAttribute("CreatureId") == id then return m end
	end
	return nil
end
VFX.CreatureModel = creatureModel

local function setModelLocalTransparency(model, v)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = v end
	end
end

local function fadeModel(model, from, to, t)
	if not model then return end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / t, 0, 1)
		if not model.Parent then conn:Disconnect(); return end
		setModelLocalTransparency(model, from + (to - from) * a)
		if a >= 1 then conn:Disconnect() end
	end)
end

-- bewegt ein Teil entlang einer Funktion f(alpha)->CFrame über Dauer t
local function animatePath(p, t, f, onDone)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / t, 0, 1)
		if not p.Parent then conn:Disconnect(); return end
		p.CFrame = f(a)
		if a >= 1 then
			conn:Disconnect()
			if onDone then onDone() end
		end
	end)
end

local function trail(p, color, width, life)
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, width / 2, 0); a0.Parent = p
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -width / 2, 0); a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = ColorSequence.new(color)
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.Lifetime = life or 0.25
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Parent = p
	return tr
end

------------------------------------------------------------------ Warnzeichen (Telegraph)
local function chargeGlow(model, color, dur)
	if not model or not model.PrimaryPart then return end
	local e = emitter(model.PrimaryPart, { color = color, size = 0.6, speed = { 2, 5 }, life = { 0.3, 0.5 }, rate = 30, light = 1 })
	Debris:AddItem(e, dur)
end

-- Füllanimation: innere Scheibe wächst bis zum Einschlag
local function fillingDisc(pos, radius, color, windup)
	local base = disc(pos, radius, color, 0.72, 0.1, windup + 0.05)
	local inner = disc(pos, 0.2, color, 0.35, 0.14, windup + 0.05)
	tween(inner, windup, { Size = Vector3.new(0.14, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	ringOutline(pos, radius, RED, windup + 0.05, 0.4)
	return base
end

local function fillingRect(from, dir, length, width, color, windup)
	rect(from, dir, length, width, color, 0.72, windup + 0.05)
	local inner = rect(from, dir, 0.2, width, color, 0.35, windup + 0.05)
	local mid0 = from + Vector3.new(0, 0.2, 0)
	animatePath(inner, windup, function(a)
		local l = math.max(0.2, length * a)
		inner.Size = Vector3.new(width, 0.14, l)
		local m = mid0 + dir * (l / 2)
		return CFrame.lookAt(m, m + dir)
	end)
	rectOutline(from, dir, length, width, RED, windup + 0.05)
end

function VFX.telegraph(data)
	local atk = Attacks[data.atk]
	if not atk then return end
	local model = creatureModel(data.id)
	local windup = math.max(0.1, data.windup - math.max(0, now() - (data.t0 or now())))
	local col = atk.color
	local ground = data.ground
	chargeGlow(model, col, windup)
	local k = atk.kind
	if k == "lunge" then
		local r = atk.radius * (data.scale or 1) ^ 0.5
		local d = (data.dashTo - ground)
		if d.Magnitude > 1 then fillingRect(ground, Vector3.new(d.X, 0, d.Z).Unit, d.Magnitude, r * 0.8, col, windup) end
		fillingDisc(data.dashTo, r, col, windup)
	elseif k == "charge" then
		local d = (data.dashTo - ground)
		local dir = Vector3.new(d.X, 0, d.Z)
		if dir.Magnitude > 0.5 then fillingRect(ground, dir.Unit, dir.Magnitude + 3, (data.width or 5) * (data.scale or 1) ^ 0.5, col, windup) end
	elseif k == "cone" then
		local range = data.range or atk.range
		local half = (data.angle or atk.angle) / 2
		for i = -3, 3 do
			local dir = CFrame.Angles(0, rad(half * i / 3), 0) * data.dir
			rect(ground, dir, range, 1.2, col, 0.55, windup + 0.05)
		end
		for _, s in ipairs({ -1, 1 }) do
			local dir = CFrame.Angles(0, rad(half * s), 0) * data.dir
			rect(ground, dir, range, 0.35, RED, 0.05, windup + 0.05)
		end
	elseif k == "projectile" then
		local origin = data.origin
		local tgt = data.target + Vector3.new(0, 2, 0)
		local dir = (tgt - origin)
		local len = math.min(dir.Magnitude, atk.range)
		local mid = origin + dir.Unit * len / 2
		local line = part({ size = Vector3.new(0.12, 0.12, len), cf = CFrame.lookAt(mid, tgt), color = RED, t = 0.5, life = windup + 0.05 })
		tween(line, windup, { Transparency = 0.1, Size = Vector3.new(0.25, 0.25, len) })
		local orb = part({ shape = Enum.PartType.Ball, size = Vector3.new(0.3, 0.3, 0.3), cf = CFrame.new(origin + dir.Unit * 1.5), color = col, t = 0.1, life = windup + 0.05 })
		tween(orb, windup, { Size = Vector3.one * (atk.vfx == "static_orb" and 2.6 or 1.4) })
	elseif k == "lob" or k == "strike" or k == "dive" or k == "blink" then
		local r = atk.radius
		for _, pt in ipairs(data.points or {}) do
			fillingDisc(pt, r, col, windup)
			if k == "blink" then
				burst(pt + Vector3.new(0, 0.5, 0), { color = Color3.fromRGB(60, 20, 90), tex = TEX.smoke, count = 12, speed = { 1, 3 }, size = 3, life = { 0.6, 1 }, light = 0 })
			end
		end
		-- Meteore/Sterne fallen exakt zum Einschlag
		if atk.vfx == "spore_meteor" or atk.vfx == "star_rain" or atk.vfx == "thunder" then
			for _, pt in ipairs(data.points or {}) do
				task.delay(math.max(0, windup - 0.4), function()
					local big = atk.vfx == "spore_meteor"
					if atk.vfx == "thunder" then return end
					local m = part({ shape = big and nil or Enum.PartType.Ball, mesh = big and Enum.MeshType.Sphere or nil, size = big and Vector3.new(4, 5.5, 4) or Vector3.one * 1.4,
						color = big and Color3.fromRGB(120, 150, 60) or Color3.fromRGB(200, 220, 255), material = big and Enum.Material.Grass or Enum.Material.Neon, life = 0.5 })
					trail(m, big and Color3.fromRGB(200, 255, 120) or Color3.fromRGB(160, 200, 255), big and 3 or 1.2, 0.3)
					local top = pt + Vector3.new(big and 14 or 6, 60, 0)
					animatePath(m, 0.4, function(a) return CFrame.new(top:Lerp(pt, a * a)) * CFrame.Angles(a * 6, a * 3, 0) end)
				end)
			end
		end
	elseif k == "nova" then
		fillingDisc(ground, data.radius or atk.radius, col, windup)
	elseif k == "beam" then
		for _, dir in ipairs(data.dirs or { data.dir }) do
			fillingRect(ground, dir, data.length or atk.length, data.width or atk.width, col, windup)
		end
	end
end

------------------------------------------------------------------ Einschläge je Attacke
local Impact = {}

Impact.peck = function(d, atk)
	burst(d.pos + Vector3.new(0, 1.5, 0), { color = Color3.fromRGB(255, 235, 170), count = 18, speed = { 6, 14 }, size = 0.8 })
	burst(d.pos + Vector3.new(0, 1.5, 0), { tex = TEX.square, color = Color3.fromRGB(255, 250, 230), count = 8, speed = { 4, 8 }, size = 0.4, accel = Vector3.new(0, -20, 0), life = { 0.6, 1 }, light = 0 })
	shockwave(d.pos, 1, 5, atk.color, 0.25)
	VFX.Sound("hit", d.pos, 0.8, 1.5)
end

Impact.egg = function(d, atk)
	local splat = disc(d.pos, 0.5, Color3.fromRGB(255, 210, 60), 0.15, 0.1, 2.4)
	splat.Material = Enum.Material.SmoothPlastic
	tween(splat, 0.15, { Size = Vector3.new(0.1, atk.radius * 1.6, atk.radius * 1.6) })
	task.delay(1.6, function() tween(splat, 0.7, { Transparency = 1 }) end)
	burst(d.pos + Vector3.new(0, 1, 0), { tex = TEX.square, color = Color3.fromRGB(255, 250, 240), count = 16, speed = { 8, 16 }, size = 0.6, accel = Vector3.new(0, -40, 0), light = 0 })
	burst(d.pos + Vector3.new(0, 1, 0), { color = Color3.fromRGB(255, 220, 80), count = 14, speed = { 5, 12 }, size = 1 })
	VFX.Sound("splash", d.pos, 0.6, 1.6)
end

Impact.ember_pounce = function(d, atk)
	burst(d.pos + Vector3.new(0, 1, 0), { tex = TEX.fire, color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)), count = 30, speed = { 6, 16 }, size = 2.5, life = { 0.3, 0.7 } })
	burst(d.pos + Vector3.new(0, 1, 0), { tex = TEX.fsparks, color = Color3.fromRGB(255, 160, 60), count = 24, speed = { 10, 24 }, size = 0.6, accel = Vector3.new(0, -30, 0) })
	shockwave(d.pos, 1, atk.radius * 1.2, atk.color, 0.35)
	light(d.pos + Vector3.new(0, 2, 0), atk.color, 18, 0.4)
	VFX.Sound("explosion", d.pos, 0.5, 1.8)
end

Impact.horn_charge = function(d, atk)
	local from, to = d.from, d.to
	if not from or not to then return end
	local dir = (to - from)
	for i = 0, 6 do
		local p = from:Lerp(to, i / 6)
		task.delay(i * 0.05, function()
			burst(p + Vector3.new(0, 0.6, 0), { tex = TEX.smoke, color = Color3.fromRGB(150, 130, 100), count = 6, speed = { 2, 5 }, size = 3, life = { 0.6, 1.1 }, light = 0 })
			burst(p + Vector3.new(0, 1, 0), { tex = TEX.square, color = Color3.fromRGB(110, 200, 80), count = 4, speed = { 4, 8 }, size = 0.5, accel = Vector3.new(0, -15, 0), light = 0.3 })
		end)
	end
	task.delay(0.35, function() shockwave(to, 1, 7, atk.color, 0.3) end)
	VFX.Sound("whoosh", from, 0.7, 0.8)
end

Impact.thorn_ring = function(d, atk)
	local r = d.radius or atk.radius
	local n = math.floor(r * 1.4)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + math.random() * 0.2
		for ring = 0, 1 do
			local rr = r * (0.55 + ring * 0.4)
			local p = d.pos + Vector3.new(math.cos(a + ring * 0.2) * rr, 0, math.sin(a + ring * 0.2) * rr)
			local h = 2.5 + math.random() * 1.5
			local sp = part({ class = "WedgePart", size = Vector3.new(0.6, 0.1, 0.9), cf = CFrame.new(p) * CFrame.Angles(0, -a, 0), color = Color3.fromRGB(70, 140, 50), material = Enum.Material.Grass, life = 1.3 })
			tween(sp, 0.12, { Size = Vector3.new(0.6, h, 0.9), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, -a, 0) }, Enum.EasingStyle.Back)
			task.delay(0.8, function() if sp.Parent then tween(sp, 0.4, { Size = Vector3.new(0.6, 0.1, 0.9), CFrame = CFrame.new(p) * CFrame.Angles(0, -a, 0), Transparency = 1 }) end end)
		end
	end
	burst(d.pos + Vector3.new(0, 1, 0), { tex = TEX.square, color = Color3.fromRGB(140, 220, 90), count = 30, speed = { 10, 18 }, size = 0.6, spread = Vector2.new(80, 80), light = 0.2 })
	shockwave(d.pos, 1, r, atk.color, 0.3)
	VFX.Sound("airBurst", d.pos, 0.7, 0.8)
end

Impact.thunder = function(d, atk)
	for _, pt in ipairs(d.points or {}) do
		local top = pt + Vector3.new(math.random(-4, 4), 55, math.random(-4, 4))
		local prev = top
		for i = 1, 7 do
			local tgt = top:Lerp(pt, i / 7) + (i < 7 and Vector3.new(math.random(-25, 25) / 10, 0, math.random(-25, 25) / 10) or Vector3.zero)
			local mid = (prev + tgt) / 2
			local seg = part({ size = Vector3.new(0.6, 0.6, (tgt - prev).Magnitude), cf = CFrame.lookAt(mid, tgt), color = Color3.fromRGB(255, 250, 200), life = 0.35 })
			tween(seg, 0.3, { Transparency = 1, Size = Vector3.new(0.1, 0.1, seg.Size.Z) })
			prev = tgt
		end
		light(pt + Vector3.new(0, 4, 0), Color3.fromRGB(255, 240, 150), 40, 0.35, 8)
		burst(pt + Vector3.new(0, 0.5, 0), { color = Color3.fromRGB(255, 240, 120), count = 30, speed = { 10, 22 }, size = 0.8, spread = Vector2.new(70, 70) })
		local scorch = disc(pt, atk.radius * 0.8, Color3.fromRGB(40, 35, 30), 0.3, 0.08, 2.5)
		scorch.Material = Enum.Material.SmoothPlastic
		task.delay(1.4, function() tween(scorch, 1, { Transparency = 1 }) end)
		shockwave(pt, 1, atk.radius, atk.color, 0.25)
		VFX.Sound("explosion", pt, 0.6, 2.2)
	end
end

Impact.claw = function(d, atk)
	local dir = d.dir or Vector3.new(0, 0, -1)
	local range = d.range or atk.range
	for i = 0, 2 do
		task.delay(i * 0.04, function()
			local ang = rad(-atk.angle / 2 + (atk.angle / 2) * i)
			local dd = CFrame.Angles(0, ang, 0) * dir
			local p = d.pos + dd * range * 0.6 + Vector3.new(0, 1.4, 0)
			local s = part({ mesh = Enum.MeshType.Sphere, size = Vector3.new(range * 0.9, 0.25, 1.2), cf = CFrame.lookAt(p, p + Vector3.new(-dd.Z, 0, dd.X)), color = Color3.fromRGB(180, 230, 255), t = 0.1, life = 0.3 })
			tween(s, 0.25, { Transparency = 1, Size = Vector3.new(range * 1.1, 0.1, 0.3) })
		end)
	end
	burst(d.pos + dir * range * 0.6 + Vector3.new(0, 1.5, 0), { color = Color3.fromRGB(120, 200, 255), tex = TEX.square, count = 20, speed = { 6, 14 }, size = 0.5, accel = Vector3.new(0, -30, 0), light = 0.3 })
	VFX.Sound("whoosh", d.pos, 0.6, 1.6)
end

Impact.bubble = function(d, atk)
	burst(d.pos + Vector3.new(0, 1, 0), { tex = TEX.square, color = Color3.fromRGB(140, 210, 255), count = 40, speed = { 10, 22 }, size = 0.7, spread = Vector2.new(50, 50), accel = Vector3.new(0, -45, 0), light = 0.4 })
	burst(d.pos + Vector3.new(0, 1, 0), { color = Color3.fromRGB(220, 245, 255), count = 16, speed = { 3, 8 }, size = 1.4 })
	shockwave(d.pos, 1, atk.radius * 1.1, atk.color, 0.4)
	VFX.Sound("splash", d.pos, 0.9)
end

Impact.frost_nova = function(d, atk)
	local r = d.radius or atk.radius
	shockwave(d.pos, 1, r, Color3.fromRGB(190, 240, 255), 0.4)
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		local p = d.pos + Vector3.new(math.cos(a) * r * 0.85, 0, math.sin(a) * r * 0.85)
		local c = part({ size = Vector3.new(0.8, 0.2, 0.8), cf = CFrame.new(p) * CFrame.Angles(rad(math.random(-20, 20)), a, rad(math.random(-20, 20))), color = Color3.fromRGB(190, 240, 255), material = Enum.Material.Ice, t = 0.1, life = 1.6 })
		tween(c, 0.15, { Size = Vector3.new(0.8, 2.8, 0.8), CFrame = c.CFrame * CFrame.new(0, 1.3, 0) }, Enum.EasingStyle.Back)
		task.delay(1, function() if c.Parent then tween(c, 0.5, { Transparency = 1 }) end end)
	end
	burst(d.pos + Vector3.new(0, 1, 0), { color = Color3.fromRGB(235, 250, 255), count = 40, speed = { 12, 20 }, size = 0.7, spread = Vector2.new(85, 85), drag = 3 })
	light(d.pos + Vector3.new(0, 2, 0), Color3.fromRGB(170, 230, 255), 25, 0.5)
	VFX.Sound("airBurst", d.pos, 0.8, 1.3)
end

Impact.dive = function(d, atk)
	burst(d.pos + Vector3.new(0, 1, 0), { tex = TEX.vortex, color = Color3.fromRGB(160, 255, 220), count = 8, speed = { 1, 3 }, size = NumberSequence.new(2, 9), life = { 0.4, 0.6 } })
	burst(d.pos + Vector3.new(0, 0.5, 0), { tex = TEX.smoke, color = Color3.fromRGB(200, 200, 190), count = 14, speed = { 10, 18 }, size = 3, spread = Vector2.new(85, 85), light = 0, life = { 0.5, 0.9 } })
	shockwave(d.pos, 1, atk.radius * 1.2, atk.color, 0.35)
	VFX.Sound("whoosh", d.pos, 1, 0.7)
end

Impact.shadow_blink = function(d, atk)
	if d.from then
		burst(d.from + Vector3.new(0, 2, 0), { tex = TEX.smoke, color = Color3.fromRGB(70, 30, 110), count = 18, speed = { 1, 4 }, size = 4, light = 0, life = { 0.5, 0.9 } })
	end
	local p = d.pos + Vector3.new(0, 2, 0)
	for _, a in ipairs({ 45, -45 }) do
		local s = part({ mesh = Enum.MeshType.Sphere, size = Vector3.new(0.3, 9, 1.0), cf = CFrame.new(p) * CFrame.Angles(0, 0, rad(a)), color = Color3.fromRGB(190, 130, 255), t = 0, life = 0.35 })
		tween(s, 0.3, { Transparency = 1, Size = Vector3.new(0.1, 11, 0.4) })
	end
	burst(p, { color = Color3.fromRGB(170, 110, 255), count = 26, speed = { 8, 16 }, size = 0.8 })
	shockwave(d.pos, 1, atk.radius, atk.color, 0.3)
	VFX.Sound("whoosh", d.pos, 0.8, 1.3)
end

local function beamWave(d, atk, style)
	for _, dir in ipairs(d.dirs or {}) do
		local from = d.ground
		local len = d.length or atk.length
		if style == "crescent" then
			local w = part({ mesh = Enum.MeshType.Sphere, size = Vector3.new(d.width * 1.8, 2.2, 1.2), color = Color3.fromRGB(215, 180, 255), t = 0.05, life = 0.5 })
			trail(w, Color3.fromRGB(190, 140, 255), 2, 0.25)
			animatePath(w, 0.3, function(a)
				local p = from + dir * len * a + Vector3.new(0, 1.4, 0)
				return CFrame.lookAt(p, p + dir)
			end, function() if w.Parent then tween(w, 0.15, { Transparency = 1 }) end end)
		elseif style == "lance" then
			local mid = from + dir * len / 2 + Vector3.new(0, 1.6, 0)
			local b = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(len, d.width, d.width), cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, rad(90), 0), color = Color3.fromRGB(220, 230, 255), t = 0, life = 0.5 })
			tween(b, 0.45, { Transparency = 1, Size = Vector3.new(len, 0.3, 0.3) })
			light(mid, Color3.fromRGB(190, 210, 255), 30, 0.4)
			for i = 1, 6 do burst(from + dir * len * (i / 6) + Vector3.new(0, 1.6, 0), { color = Color3.fromRGB(200, 220, 255), count = 5, speed = { 2, 6 }, size = 0.6 }) end
		elseif style == "roots" then
			local n = math.floor(len / 3.2)
			for i = 1, n do
				task.delay(i * 0.025, function()
					local p = from + dir * (i * 3.2) + Vector3.new(math.random(-8, 8) / 10, 0, math.random(-8, 8) / 10)
					local h = 3.5 + math.random() * 2.5
					local r = part({ class = "WedgePart", size = Vector3.new(1.4, 0.1, 1.6), cf = CFrame.lookAt(p, p + dir), color = Color3.fromRGB(110, 78, 48), material = Enum.Material.Wood, life = 1.4 })
					tween(r, 0.1, { Size = Vector3.new(1.4, h, 1.6), CFrame = CFrame.lookAt(p + Vector3.new(0, h / 2, 0), p + Vector3.new(0, h / 2, 0) + dir) }, Enum.EasingStyle.Back)
					local tip = part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.7, cf = CFrame.new(p + Vector3.new(0, h, 0)), color = Color3.fromRGB(150, 255, 90), life = 1.2 })
					task.delay(0.9, function()
						if r.Parent then tween(r, 0.4, { Size = Vector3.new(1.4, 0.1, 1.6), CFrame = CFrame.lookAt(p, p + dir), Transparency = 1 }) end
						if tip.Parent then tween(tip, 0.3, { Transparency = 1 }) end
					end)
					if i % 3 == 0 then burst(p + Vector3.new(0, 0.5, 0), { tex = TEX.smoke, color = Color3.fromRGB(120, 100, 70), count = 3, speed = { 2, 5 }, size = 3, light = 0 }) end
				end)
			end
		end
	end
end

Impact.crescent = function(d, atk) beamWave(d, atk, "crescent"); VFX.Sound("whoosh", d.ground, 0.7, 1.5) end
Impact.moon_lance = function(d, atk) beamWave(d, atk, "lance"); VFX.Sound("sparkle", d.ground, 0.8, 0.8) end
Impact.root_quake = function(d, atk) beamWave(d, atk, "roots"); VFX.Sound("explosion", d.ground, 0.8, 0.6) end

Impact.spore_meteor = function(d, atk)
	for _, pt in ipairs(d.points or {}) do
		burst(pt + Vector3.new(0, 1.5, 0), { tex = TEX.smoke, color = Color3.fromRGB(190, 240, 110), count = 26, speed = { 8, 18 }, size = 5, light = 0.3, life = { 0.8, 1.4 }, drag = 2 })
		burst(pt + Vector3.new(0, 1.5, 0), { color = Color3.fromRGB(230, 255, 140), count = 30, speed = { 12, 26 }, size = 0.9, accel = Vector3.new(0, -10, 0) })
		shockwave(pt, 2, atk.radius * 1.2, atk.color, 0.4)
		light(pt + Vector3.new(0, 3, 0), Color3.fromRGB(180, 255, 100), 35, 0.6)
		VFX.Sound("explosion", pt, 0.9, 0.9)
	end
end

Impact.star_rain = function(d, atk)
	for _, pt in ipairs(d.points or {}) do
		burst(pt + Vector3.new(0, 1, 0), { color = Color3.fromRGB(190, 215, 255), count = 22, speed = { 8, 16 }, size = 1 })
		shockwave(pt, 1, atk.radius, atk.color, 0.3)
		light(pt + Vector3.new(0, 2, 0), Color3.fromRGB(170, 200, 255), 20, 0.4)
	end
	VFX.Sound("sparkle", d.points and d.points[1], 0.8, 1.2)
end

function VFX.impact(data)
	local atk = Attacks[data.atk]
	if not atk then return end
	local f = Impact[atk.vfx]
	if f then f(data, atk) end
	-- Nova/Lunge ohne eigenen Stil: Druckwelle
	if not f and data.pos then shockwave(data.pos, 1, (atk.radius or 6), atk.color, 0.3) end
	-- Kamera-Wackeln, wenn nah
	local p = data.pos or data.ground or (data.points and data.points[1])
	if p and VFX.Shake then
		local dist = (workspace.CurrentCamera.CFrame.Position - p).Magnitude
		local big = (data.atk == "root_quake" or data.atk == "spore_meteor") and 1.6 or 0.6
		if dist < 40 then VFX.Shake(big * (1 - dist / 40)) end
	end
end

------------------------------------------------------------------ Projektile
local projectiles = {}

local function projectileVisual(atk, dir)
	local v = atk.vfx
	local p
	if v == "ember_spit" then
		p = part({ shape = Enum.PartType.Ball, size = Vector3.one * 1.1, color = Color3.fromRGB(255, 140, 40) })
		emitter(p, { tex = TEX.fire, color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)), rate = 40, size = 1.4, speed = { 0, 1 }, life = { 0.15, 0.3 } })
		trail(p, Color3.fromRGB(255, 120, 40), 0.8, 0.2)
	elseif v == "static_orb" then
		p = part({ shape = Enum.PartType.Ball, size = Vector3.one * 2.6, color = Color3.fromRGB(255, 235, 110), t = 0.15 })
		emitter(p, { color = Color3.fromRGB(255, 250, 160), rate = 25, size = 0.6, speed = { 3, 7 }, life = { 0.1, 0.25 } })
		local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 230, 100); l.Range = 14; l.Brightness = 2; l.Parent = p
	elseif v == "ice_volley" then
		p = part({ mesh = Enum.MeshType.Sphere, size = Vector3.new(0.45, 0.45, 2.2), color = Color3.fromRGB(200, 245, 255), material = Enum.Material.Ice, t = 0.1 })
		trail(p, Color3.fromRGB(190, 240, 255), 0.4, 0.2)
	elseif v == "wind_blade" then
		p = part({ mesh = Enum.MeshType.Sphere, size = Vector3.new(6, 0.35, 1.4), color = Color3.fromRGB(180, 255, 225), t = 0.15 })
		trail(p, Color3.fromRGB(150, 255, 210), 1.2, 0.25)
	else
		p = part({ shape = Enum.PartType.Ball, size = Vector3.one, color = atk.color })
	end
	return p
end

function VFX.projectiles(data)
	local atk = Attacks[data.atk]
	if not atk then return end
	for _, s in ipairs(data.shots) do
		local vis = projectileVisual(atk, s.dir)
		projectiles[s.pid] = { part = vis, from = data.from, dir = s.dir, speed = data.speed, t0 = data.t0, maxT = data.range / data.speed, spin = atk.vfx == "wind_blade" }
	end
	local key = atk.vfx == "ember_spit" and "whoosh" or (atk.vfx == "static_orb" and "sparkle" or "whoosh")
	VFX.Sound(key, data.from, 0.5, 1.4)
end

local function endProjectile(data)
	local p = projectiles[data.pid]
	projectiles[data.pid] = nil
	local atk = Attacks[data.atk]
	if p then p.part:Destroy() end
	if not atk then return end
	local pos = data.pos
	if atk.vfx == "ember_spit" then
		burst(pos, { tex = TEX.fire, color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)), count = 10, speed = { 3, 8 }, size = 1.8, life = { 0.2, 0.4 } })
	elseif atk.vfx == "static_orb" then
		burst(pos, { color = Color3.fromRGB(255, 240, 120), count = 30, speed = { 10, 20 }, size = 0.7 })
		shockwave(pos - Vector3.new(0, 1, 0), 1, 6, atk.color, 0.25)
		light(pos, Color3.fromRGB(255, 240, 120), 18, 0.3)
	elseif atk.vfx == "ice_volley" then
		burst(pos, { tex = TEX.square, color = Color3.fromRGB(220, 250, 255), count = 10, speed = { 6, 12 }, size = 0.35, accel = Vector3.new(0, -30, 0), light = 0.4 })
	elseif atk.vfx == "wind_blade" then
		burst(pos, { tex = TEX.vortex, color = Color3.fromRGB(170, 255, 220), count = 3, speed = { 0, 1 }, size = NumberSequence.new(1, 5), life = { 0.25, 0.35 } })
	end
	if data.hit then VFX.Sound("hit", pos, 0.6, 1.2) end
end
VFX.proj_end = endProjectile

------------------------------------------------------------------ Bogenwürfe (Ei, Blase)
function VFX.lob(data)
	local atk = Attacks[data.atk]
	if not atk then return end
	local p
	if atk.vfx == "egg" then
		p = part({ mesh = Enum.MeshType.Sphere, size = Vector3.new(1.1, 1.4, 1.1), color = Color3.fromRGB(255, 248, 230), material = Enum.Material.SmoothPlastic, life = atk.flight + 0.2 })
	else
		p = part({ shape = Enum.PartType.Ball, size = Vector3.one * 2.4, color = Color3.fromRGB(140, 200, 255), material = Enum.Material.Glass, t = 0.35, life = atk.flight + 0.2 })
		local hl = part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.5, color = Color3.new(1, 1, 1), life = atk.flight + 0.2 })
		local w = Instance.new("WeldConstraint"); w.Part0 = p; w.Part1 = hl; w.Parent = p
		hl.Anchored = false
		hl.CFrame = p.CFrame * CFrame.new(0.5, 0.6, -0.6)
		hl.Parent = p
	end
	local from, to = data.from, data.to
	local h = math.max(8, (to - from).Magnitude * 0.35)
	local elapsed = math.max(0, now() - (data.t0 or now()))
	local dur = math.max(0.1, atk.flight - elapsed)
	animatePath(p, dur, function(a)
		local pos = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * h, 0)
		return CFrame.new(pos) * CFrame.Angles(a * 8, a * 5, 0)
	end, function() p:Destroy() end)
end

------------------------------------------------------------------ Spielerwaffen
function VFX.Tracer(from, to, color, width)
	local len = (to - from).Magnitude
	if len < 0.5 then return end
	local mid = from:Lerp(to, 0.5)
	local t = part({ size = Vector3.new(width or 0.12, width or 0.12, len), cf = CFrame.lookAt(mid, to), color = color, t = 0.2, life = 0.12 })
	tween(t, 0.1, { Transparency = 1, Size = Vector3.new(0.02, 0.02, len) })
end

function VFX.ImpactSpark(pos, color)
	burst(pos, { color = color or Color3.fromRGB(255, 220, 150), count = 6, speed = { 4, 10 }, size = 0.35, life = { 0.1, 0.25 } })
end

function VFX.shot(data)
	if data.uid == player.UserId then return end
	local w = Weapons.Get(data.weapon)
	for _, e in ipairs(data.ends or {}) do
		VFX.Tracer(data.from, e, w and w.tracer or Color3.new(1, 1, 1), 0.1)
	end
	VFX.Sound(w and w.sound or "pistol", data.from, 0.7)
end

function VFX.explosion(data)
	burst(data.pos, { tex = TEX.core, color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 80, 30)), count = 14, speed = { 4, 10 }, size = NumberSequence.new(3, 7), life = { 0.25, 0.45 } })
	burst(data.pos, { tex = TEX.smoke, color = Color3.fromRGB(90, 80, 75), count = 10, speed = { 4, 9 }, size = 5, light = 0, life = { 0.8, 1.4 } })
	shockwave(data.pos - Vector3.new(0, 1, 0), 1, data.radius, Color3.fromRGB(255, 140, 60), 0.3)
	light(data.pos, Color3.fromRGB(255, 160, 80), 30, 0.4, 6)
	VFX.Sound("explosion", data.pos, 0.9)
	if VFX.Shake then
		local dist = (workspace.CurrentCamera.CFrame.Position - data.pos).Magnitude
		if dist < 30 then VFX.Shake(0.5 * (1 - dist / 30)) end
	end
end

function VFX.dummy_hit(data)
	local d = data.dummy
	if not d then return end
	local target = d:IsA("Model") and (d:FindFirstChild("Target") or d.PrimaryPart) or d
	if target and target:IsA("BasePart") then
		local old = target.Color
		target.Color = Color3.new(1, 1, 1)
		task.delay(0.08, function() if target.Parent then target.Color = old end end)
	end
end

------------------------------------------------------------------ Fangkugel
local balls = {}

local function makeBall(tier)
	local t = Spheres.Get(tier) or Spheres.Tiers[1]
	local b = part({ shape = Enum.PartType.Ball, size = Vector3.one * 1.3, color = t.color, material = Enum.Material.SmoothPlastic, life = 8 })
	local band = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 1.36, 1.36), color = t.band, life = 8 })
	band.Anchored = false
	band.CFrame = b.CFrame * CFrame.Angles(0, 0, rad(90))
	local w = Instance.new("WeldConstraint"); w.Part0 = b; w.Part1 = band; w.Parent = b
	band.Parent = b
	local btn = part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.35, color = Color3.new(1, 1, 1), life = 8 })
	btn.Anchored = false
	btn.CFrame = b.CFrame * CFrame.new(0, 0, -0.62)
	local w2 = Instance.new("WeldConstraint"); w2.Part0 = b; w2.Part1 = btn; w2.Parent = b
	btn.Parent = b
	trail(b, t.band, 0.6, 0.2)
	return b
end
VFX.MakeBall = makeBall

function VFX.ball(data)
	local b = makeBall(data.tier)
	local rec = { part = b, from = data.from, vel = data.vel, g = data.g, t0 = data.t0, alive = true }
	balls[data.bid] = rec
	VFX.Sound("throw", data.from, 0.7)
end

function VFX.ball_end(data)
	local r = balls[data.bid]
	balls[data.bid] = nil
	if not r then return end
	r.alive = false
	local b = r.part
	b.CFrame = CFrame.new(data.pos + Vector3.new(0, 0.6, 0))
	if data.result == "bounce" then
		burst(data.pos, { color = Color3.new(1, 1, 1), count = 8, speed = { 4, 8 }, size = 0.5 })
		VFX.Sound("empty", data.pos, 1, 0.8)
	end
	tween(b, 0.5, { CFrame = b.CFrame * CFrame.new(0, 1.2, 0), Transparency = 1 })
	for _, c in ipairs(b:GetDescendants()) do if c:IsA("BasePart") then tween(c, 0.5, { Transparency = 1 }) end end
	Debris:AddItem(b, 0.6)
end

function VFX.capture_start(data)
	local r = balls[data.bid]
	balls[data.bid] = nil
	local b = r and r.part or makeBall(data.tier)
	if r then r.alive = false end
	local model = creatureModel(data.id)
	local pos = data.pos
	local ground = pos - Vector3.new(0, (model and model:GetAttribute("RootHeight") or 2) - 0.7, 0)
	-- Lichtstrahl + Kreatur wird eingesogen
	local beam = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(8, 3, 3), cf = CFrame.new(pos) * CFrame.Angles(0, 0, rad(90)), color = Color3.fromRGB(180, 230, 255), t = 0.4, life = 0.6 })
	tween(beam, 0.5, { Size = Vector3.new(8, 0.2, 0.2), Transparency = 1 })
	burst(pos, { color = Color3.fromRGB(200, 240, 255), count = 30, speed = { -12, -6 }, size = 0.6 })
	if model then fadeModel(model, 0, 1, 0.35) end
	b.CFrame = CFrame.new(pos)
	tween(b, 0.4, { CFrame = CFrame.new(ground) }, Enum.EasingStyle.Bounce)
	VFX.Sound("sparkle", pos, 0.8)
	-- Wackeln
	task.delay(0.45, function()
		for i = 1, data.shakes do
			if not b.Parent then return end
			local base = CFrame.new(ground)
			tween(b, Spheres.ShakeTime * 0.25, { CFrame = base * CFrame.Angles(0, 0, rad(28)) })
			task.wait(Spheres.ShakeTime * 0.3)
			tween(b, Spheres.ShakeTime * 0.25, { CFrame = base * CFrame.Angles(0, 0, rad(-28)) })
			task.wait(Spheres.ShakeTime * 0.3)
			tween(b, Spheres.ShakeTime * 0.2, { CFrame = base })
			task.wait(Spheres.ShakeTime * 0.4)
			VFX.Sound("empty", ground, 0.6, 1.2)
		end
	end)
	b:SetAttribute("CaptureId", data.bid)
	VFX._captureBalls = VFX._captureBalls or {}
	VFX._captureBalls[data.bid] = { ball = b, model = model, ground = ground }
end

function VFX.capture_result(data)
	local c = VFX._captureBalls and VFX._captureBalls[data.bid]
	if VFX._captureBalls then VFX._captureBalls[data.bid] = nil end
	local pos = c and c.ground or data.pos
	if data.success then
		burst(pos + Vector3.new(0, 1, 0), { color = Color3.fromRGB(255, 230, 120), count = 40, speed = { 8, 18 }, size = 1 })
		burst(pos + Vector3.new(0, 1, 0), { tex = TEX.glow, color = Color3.fromRGB(255, 255, 200), count = 3, speed = { 0, 1 }, size = NumberSequence.new(1, 6), life = { 0.4, 0.5 } })
		light(pos, Color3.fromRGB(255, 240, 150), 20, 0.8)
		VFX.Sound("sparkle", pos, 1, 1.3)
		if c and c.ball.Parent then
			task.delay(0.6, function()
				if c.ball.Parent then
					for _, p in ipairs(c.ball:GetDescendants()) do if p:IsA("BasePart") then tween(p, 0.4, { Transparency = 1 }) end end
					tween(c.ball, 0.4, { Transparency = 1, CFrame = c.ball.CFrame * CFrame.new(0, 2, 0) })
					Debris:AddItem(c.ball, 0.5)
				end
			end)
		end
	else
		if c then
			if c.ball.Parent then
				burst(pos + Vector3.new(0, 0.6, 0), { color = Color3.fromRGB(255, 120, 100), count = 25, speed = { 8, 16 }, size = 0.7 })
				c.ball:Destroy()
			end
			if c.model then fadeModel(c.model, 1, 0, 0.25) end
		end
		if not data.silent then VFX.Sound("hit", pos, 1, 0.7) end
	end
end

------------------------------------------------------------------ Beschwören / Verschwinden
function VFX.summon(data)
	local model = creatureModel(data.id)
	if model then
		setModelLocalTransparency(model, 1)
		fadeModel(model, 1, 0, 0.45)
	end
	if data.from then
		local mid = (data.from + data.pos) / 2
		local b = part({ size = Vector3.new(0.4, 0.4, (data.pos - data.from).Magnitude), cf = CFrame.lookAt(mid, data.pos), color = Color3.fromRGB(150, 230, 255), t = 0.2, life = 0.4 })
		tween(b, 0.35, { Transparency = 1 })
	end
	burst(data.pos, { color = Color3.fromRGB(150, 230, 255), count = 30, speed = { 6, 14 }, size = 0.9 })
	shockwave(data.pos - Vector3.new(0, 1.5, 0), 1, 6, Color3.fromRGB(150, 230, 255), 0.4)
	VFX.Sound("sparkle", data.pos, 0.7, 1.4)
end

function VFX.recall(data)
	local model = creatureModel(data.id)
	if model then fadeModel(model, 0, 1, 0.3) end
	local col = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(14, 3, 3), cf = CFrame.new(data.pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, rad(90)), color = Color3.fromRGB(150, 230, 255), t = 0.4, life = 0.5 })
	tween(col, 0.45, { Size = Vector3.new(14, 0.2, 0.2), Transparency = 1 })
	burst(data.pos, { color = Color3.fromRGB(150, 230, 255), count = 20, speed = { 3, 8 }, size = 0.7, accel = Vector3.new(0, 20, 0) })
end

function VFX.vanish(data)
	local model = creatureModel(data.id)
	if model then fadeModel(model, 0, 1, 0.8) end
	burst(data.pos, { tex = TEX.smoke, color = Color3.fromRGB(220, 220, 230), count = 14, speed = { 1, 4 }, size = 3 * (data.scale or 1), light = 0, life = { 0.6, 1.1 } })
end

function VFX.defeat(data)
	burst(data.pos, { color = data.catchable and Color3.fromRGB(255, 240, 160) or Color3.fromRGB(255, 255, 255), count = 24, speed = { 5, 12 }, size = 0.8 * (data.scale or 1) })
	VFX.Sound("hit", data.pos, 1, 0.6)
end

------------------------------------------------------------------ Boss
function VFX.boss_intro(data)
	local pos = data.pos
	for i = 1, 3 do
		task.delay(i * 0.6, function()
			shockwave(pos, 2, 30 + i * 10, Color3.fromRGB(150, 255, 90), 0.8)
			burst(pos + Vector3.new(0, 1, 0), { tex = TEX.smoke, color = Color3.fromRGB(110, 90, 60), count = 30, speed = { 10, 25 }, size = 6, spread = Vector2.new(85, 85), light = 0, life = { 1, 1.8 } })
			if VFX.Shake then VFX.Shake(1.2) end
		end)
	end
	light(pos + Vector3.new(0, 10, 0), Color3.fromRGB(150, 255, 90), 80, 2.5, 4)
	VFX.Sound("explosion", pos, 1, 0.5)
end

function VFX.boss_phase(data)
	shockwave(data.pos - Vector3.new(0, 10, 0), 4, 45, Color3.fromRGB(255, 120, 60), 0.7)
	burst(data.pos, { color = Color3.fromRGB(255, 160, 80), count = 60, speed = { 15, 30 }, size = 1.5 })
	light(data.pos, Color3.fromRGB(255, 140, 60), 70, 1.2, 5)
	if VFX.Shake then VFX.Shake(1.5) end
	VFX.Sound("explosion", data.pos, 1, 0.4)
end

------------------------------------------------------------------ Update-Schleife (nur solange etwas fliegt)
RunService.RenderStepped:Connect(function()
	if next(projectiles) == nil and next(balls) == nil then return end
	local t = now()
	for pid, p in pairs(projectiles) do
		local e = t - p.t0
		if e > p.maxT + 0.5 or not p.part.Parent then
			p.part:Destroy()
			projectiles[pid] = nil
		else
			local pos = p.from + p.dir * p.speed * math.max(0, e)
			local cf = CFrame.lookAt(pos, pos + p.dir)
			if p.spin then cf = cf * CFrame.Angles(0, 0, 0) * CFrame.Angles(0, e * 25, 0) end
			p.part.CFrame = cf
		end
	end
	for bid, r in pairs(balls) do
		local e = math.max(0, t - r.t0)
		if e > 3.2 or not r.part.Parent then
			if r.part.Parent then r.part:Destroy() end
			balls[bid] = nil
		else
			local pos = r.from + r.vel * e + Vector3.new(0, -0.5 * r.g * e * e, 0)
			r.part.CFrame = CFrame.new(pos) * CFrame.Angles(e * 12, 0, 0)
		end
	end
end)

return VFX
