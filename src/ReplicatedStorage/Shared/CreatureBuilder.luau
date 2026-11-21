--[[
	CreatureBuilder: baut alle Kreaturenmodelle prozedural (gleicher Code für Server-Spawns und UI-Porträts).
	Konvention: Vorwärts = -Z, Boden = Y 0. Jede Kreatur besteht aus Gelenken (Motor6D) mit gruppierten Teilen.
	Gelenk-Namen steuern die Client-Animation (CreatureAnimator): Body, Head, Leg*, Tail*, Wing*, Claw*, Arm*, Ear*, Antenna*, Spikes, Jaw.
	Teile mit Attribut WeakSpot = Schwachstelle (Kopftreffer).
]]
local Builder = {}
Builder.__index = Builder

local rad = math.rad

local function rotCF(rot)
	if not rot then return CFrame.identity end
	return CFrame.Angles(rad(rot.X), rad(rot.Y), rad(rot.Z))
end

function Builder.new(name, scale, rootY)
	local self = setmetatable({}, Builder)
	self.s = scale or 1
	self.model = Instance.new("Model")
	self.model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2) * self.s
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, rootY * self.s, 0)
	root.Parent = self.model
	self.model.PrimaryPart = root
	self.model:SetAttribute("RootHeight", rootY * self.s)
	self.joints = { Root = root }
	self.count = 0
	return self
end

-- Gelenk an Pivot-Position (Modellraum, unskaliert)
function Builder:joint(name, parentName, pivot)
	local s = self.s
	local parent = self.joints[parentName]
	local j = Instance.new("Part")
	j.Name = "J_" .. name
	j.Size = Vector3.new(0.2, 0.2, 0.2)
	j.Transparency = 1
	j.CanCollide = false
	j.CanQuery = false
	j.CanTouch = false
	j.Massless = true
	j.CFrame = CFrame.new(pivot * s)
	j.Parent = self.model
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = parent
	m.Part1 = j
	m.C0 = parent.CFrame:ToObjectSpace(j.CFrame)
	m.C1 = CFrame.identity
	m.Parent = parent
	self.joints[name] = j
	return j
end

-- kind: E Ellipsoid, B Block, S Kugel, CX Zylinder (Längsachse X), CY Zylinder senkrecht, W Keil, CW Eckkeil
function Builder:add(jointName, kind, size, pos, color, material, rot, opts)
	local s = self.s
	opts = opts or {}
	local p
	if kind == "W" then p = Instance.new("WedgePart")
	elseif kind == "CW" then p = Instance.new("CornerWedgePart")
	else p = Instance.new("Part") end
	local sz = size * s
	local cframe = CFrame.new(pos * s) * rotCF(rot)
	if opts.lookAt then cframe = CFrame.lookAt(pos * s, opts.lookAt * s) end
	if kind == "E" then
		p.Size = sz
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif kind == "S" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(sz.X, sz.X, sz.X)
	elseif kind == "CX" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = sz
	elseif kind == "CY" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(sz.Y, sz.X, sz.Z)
		cframe = cframe * CFrame.Angles(0, 0, rad(90))
	else
		p.Size = sz
	end
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if p.Material == Enum.Material.Fabric then
		p.MaterialVariant = "parl_fur_neutral_light"
	elseif p.Material == Enum.Material.Wood then
		p.MaterialVariant = "parl_weapon_wood"
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Massless = true
	p.CastShadow = (sz.Magnitude > 1.6)
	if opts.neon then p.Material = Enum.Material.Neon end
	if opts.t then p.Transparency = opts.t end
	if opts.refl then p.Reflectance = opts.refl end
	if opts.weak then p:SetAttribute("WeakSpot", true) end
	if opts.glow then p:SetAttribute("Glow", true) end
	p.Name = opts.name or ("P" .. self.count)
	self.count += 1
	p.Parent = self.model
	local w = Instance.new("WeldConstraint")
	w.Part0 = self.joints[jointName]
	w.Part1 = p
	w.Parent = p
	return p
end

-- Hilfsfunktion: links/rechts gespiegelt (x und -x, Y/Z-Rotation gespiegelt)
function Builder:mirror(jointL, jointR, kind, size, pos, color, material, rot, opts)
	self:add(jointL, kind, size, pos, color, material, rot, opts)
	local r2 = rot and Vector3.new(rot.X, -rot.Y, -rot.Z) or nil
	self:add(jointR, kind, size, Vector3.new(-pos.X, pos.Y, pos.Z), color, material, r2, opts)
end

-- Auge (schaut nach -Z): Lederhaut, Iris, Pupille, Glanzpunkt
function Builder:eye(joint, pos, size, iris, pupilShape, opts)
	opts = opts or {}
	local yaw = opts.yaw or 0
	local r = Vector3.new(0, yaw, 0)
	local f = CFrame.Angles(0, rad(yaw), 0)
	local function off(d) return pos + (f * Vector3.new(0, 0, -d)) end
	if not opts.noWhite then
		self:add(joint, "E", Vector3.new(size, size * 1.15, size * 0.5), pos, Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, r)
	end
	local irisSize = opts.noWhite and size or size * 0.72
	self:add(joint, "E", Vector3.new(irisSize, irisSize * 1.1, size * 0.3), off(size * 0.14), iris, opts.irisNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic, r)
	local pc = opts.pupil or Color3.fromRGB(15, 12, 20)
	if pupilShape == "slit" then
		self:add(joint, "E", Vector3.new(irisSize * 0.22, irisSize * 0.9, size * 0.3), off(size * 0.2), pc, nil, r)
	elseif pupilShape == "bar" then
		self:add(joint, "E", Vector3.new(irisSize * 0.85, irisSize * 0.25, size * 0.3), off(size * 0.2), pc, nil, r)
	elseif pupilShape ~= "none" then
		self:add(joint, "E", Vector3.new(irisSize * 0.55, irisSize * 0.6, size * 0.3), off(size * 0.2), pc, nil, r)
	end
	self:add(joint, "S", Vector3.new(size * 0.22, 0, 0), off(size * 0.26) + Vector3.new(size * 0.15, size * 0.18, 0), Color3.new(1, 1, 1), Enum.Material.Neon, nil)
end

function Builder:finish(speciesId)
	self.model:SetAttribute("Species", speciesId)
	return self.model
end

----------------------------------------------------------------------
-- Baupläne
----------------------------------------------------------------------
local M = Enum.Material
local V = Vector3.new
local RGB = Color3.fromRGB

local Blueprints = {}

-- Gackerling: rundes Küken mit Eichelkappe und türkisem Fächerschwanz
Blueprints.gackerling = function(b, variant)
	local cream, belly, orange = RGB(255, 231, 188), RGB(255, 247, 226), RGB(255, 150, 45)
	b:joint("Body", "Root", V(0, 1.7, 0))
	b:add("Body", "E", V(2.6, 2.4, 2.6), V(0, 1.7, 0), cream, M.Fabric)
	b:add("Body", "E", V(1.9, 1.7, 1.2), V(0, 1.5, -0.85), belly, M.Fabric)
	-- Brustflaum
	for i = -1, 1 do b:add("Body", "E", V(0.45, 0.35, 0.3), V(i * 0.35, 2.35, -1.05), belly, M.Fabric) end
	b:joint("Head", "Body", V(0, 2.6, -0.2))
	b:add("Head", "E", V(2.05, 1.95, 1.95), V(0, 3.25, -0.35), cream, M.Fabric, nil, { weak = true })
	b:eye("Head", V(0.45, 3.4, -1.2), 0.46, RGB(60, 40, 30), "round", { yaw = -12 })
	b:eye("Head", V(-0.45, 3.4, -1.2), 0.46, RGB(60, 40, 30), "round", { yaw = 12 })
	b:add("Head", "E", V(0.42, 0.22, 0.12), V(0.78, 3.02, -1.08), RGB(255, 150, 160), nil, V(0, -25, 0))
	b:add("Head", "E", V(0.42, 0.22, 0.12), V(-0.78, 3.02, -1.08), RGB(255, 150, 160), nil, V(0, 25, 0))
	b:add("Head", "E", V(0.55, 0.28, 0.6), V(0, 3.12, -1.42), orange, nil, V(-10, 0, 0))
	b:add("Head", "E", V(0.42, 0.18, 0.45), V(0, 2.93, -1.36), RGB(230, 120, 30))
	-- Eichelkappe
	b:add("Head", "E", V(2.15, 0.85, 2.15), V(0, 3.98, -0.32), RGB(139, 92, 52), M.Wood)
	b:add("Head", "E", V(2.2, 0.25, 2.2), V(0, 3.68, -0.32), RGB(112, 72, 40), M.Wood)
	b:add("Head", "CY", V(0.22, 0.55, 0.22), V(0, 4.45, -0.32), RGB(95, 62, 35), M.Wood)
	b:add("Head", "E", V(0.95, 0.08, 0.5), V(0.42, 4.55, -0.22), RGB(110, 190, 70), M.SmoothPlastic, V(0, -25, 20))
	-- Flügel
	b:joint("WingL", "Body", V(1.2, 2.2, 0))
	b:joint("WingR", "Body", V(-1.2, 2.2, 0))
	b:mirror("WingL", "WingR", "E", V(0.4, 1.3, 1.6), V(1.3, 1.85, 0.1), RGB(245, 210, 160), nil, V(0, 0, -12))
	b:mirror("WingL", "WingR", "E", V(0.3, 0.6, 0.9), V(1.42, 1.4, 0.4), RGB(70, 190, 180), nil, V(0, 0, -12))
	-- Schwanzfächer
	b:joint("Tail", "Body", V(0, 2.1, 1.1))
	for i = -1, 1 do
		b:add("Tail", "E", V(0.3, 1.25, 0.55), V(i * 0.42, 2.55, 1.45), i == 0 and RGB(60, 190, 180) or RGB(40, 150, 160), nil, V(-25, 0, -i * 28))
	end
	-- Beine
	b:joint("LegL", "Body", V(0.55, 1.0, 0))
	b:joint("LegR", "Body", V(-0.55, 1.0, 0))
	b:mirror("LegL", "LegR", "CY", V(0.24, 0.85, 0.24), V(0.55, 0.55, 0), orange)
	b:mirror("LegL", "LegR", "E", V(0.75, 0.22, 0.85), V(0.55, 0.12, -0.2), orange)
end

-- Glutwiesel: langes Wiesel mit glimmendem Kohle-Schweif
Blueprints.glutwiesel = function(b, variant)
	local rust, cream, coal = RGB(205, 88, 42), RGB(250, 222, 182), RGB(58, 42, 38)
	b:joint("Body", "Root", V(0, 1.6, 0))
	b:add("Body", "E", V(1.6, 1.5, 3.7), V(0, 1.65, 0), rust, M.Fabric)
	b:add("Body", "E", V(1.25, 1.0, 2.9), V(0, 1.32, -0.2), cream, M.Fabric)
	for i, z in ipairs({ -0.9, 0, 0.9 }) do
		b:add("Body", "E", V(1.0, 0.16, 0.45), V(0, 2.38, z), coal, M.Fabric)
	end
	b:add("Body", "E", V(1.2, 1.25, 1.3), V(0, 2.0, -1.5), rust, M.Fabric)
	b:joint("Head", "Body", V(0, 2.1, -1.8))
	b:add("Head", "E", V(1.45, 1.25, 1.6), V(0, 2.35, -2.35), rust, M.Fabric, nil, { weak = true })
	b:add("Head", "E", V(0.85, 0.62, 0.95), V(0, 2.12, -3.0), cream, M.Fabric)
	b:add("Head", "S", V(0.26, 0, 0), V(0, 2.25, -3.46), coal)
	b:eye("Head", V(0.4, 2.58, -2.9), 0.34, RGB(255, 190, 40), "slit", { yaw = -20, irisNeon = true })
	b:eye("Head", V(-0.4, 2.58, -2.9), 0.34, RGB(255, 190, 40), "slit", { yaw = 20, irisNeon = true })
	b:joint("EarL", "Head", V(0.45, 2.85, -2.2))
	b:joint("EarR", "Head", V(-0.45, 2.85, -2.2))
	b:mirror("EarL", "EarR", "W", V(0.14, 0.65, 0.45), V(0.48, 3.12, -2.2), rust, M.Fabric, V(0, 0, -15))
	b:mirror("EarL", "EarR", "W", V(0.06, 0.45, 0.28), V(0.42, 3.05, -2.25), RGB(255, 120, 40), M.Neon, V(0, 0, -15))
	-- Schnurrhaare
	b:mirror("Head", "Head", "CX", V(0.7, 0.04, 0.04), V(0.6, 2.15, -3.0), cream, nil, V(0, 15, 8))
	local legs = { LegFL = V(0.55, 1.15, -1.15), LegFR = V(-0.55, 1.15, -1.15), LegBL = V(0.55, 1.15, 1.1), LegBR = V(-0.55, 1.15, 1.1) }
	for n, p in pairs(legs) do
		b:joint(n, "Body", p)
		b:add(n, "E", V(0.45, 1.2, 0.55), p - V(0, 0.45, 0), RGB(170, 70, 35), M.Fabric)
		b:add(n, "E", V(0.5, 0.26, 0.65), V(p.X, 0.14, p.Z - 0.12), coal, M.Fabric)
	end
	b:joint("Tail", "Body", V(0, 1.9, 1.7))
	b:add("Tail", "E", V(0.85, 0.85, 1.6), V(0, 2.25, 2.4), rust, M.Fabric, V(-30, 0, 0))
	b:add("Tail", "E", V(1.0, 1.15, 1.2), V(0, 2.85, 3.05), coal, M.Fabric, V(-30, 0, 0))
	local ember = b:add("Tail", "E", V(0.8, 0.95, 0.95), V(0, 3.15, 3.25), RGB(255, 130, 40), M.Neon, V(-30, 0, 0), { glow = true, name = "Ember" })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "EmberFx"
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Rate = 8
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(1, 2.5)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * b.s), NumberSequenceKeypoint.new(1, 0) })
	pe.Color = ColorSequence.new(RGB(255, 180, 60), RGB(255, 70, 20))
	pe.LightEmission = 0.9
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Parent = ember
end

-- Moosbock: stämmiger Bock mit Moosrücken und eingerollten Farnhörnern
Blueprints.moosbock = function(b, variant)
	local fur, light, moss, bark = RGB(122, 104, 84), RGB(205, 190, 160), RGB(88, 150, 58), RGB(105, 78, 48)
	local alpha = variant == "alpha"
	b:joint("Body", "Root", V(0, 3.0, 0))
	b:add("Body", "E", V(2.7, 2.5, 4.3), V(0, 3.0, 0), fur, M.Fabric)
	b:add("Body", "E", V(2.2, 1.6, 3.4), V(0, 2.55, -0.1), light, M.Fabric)
	b:add("Body", "E", V(2.5, 1.1, 3.7), V(0, 4.05, 0.15), moss, M.Grass)
	b:add("Body", "E", V(1.6, 0.8, 1.6), V(0, 4.35, 1.0), RGB(70, 130, 45), M.Grass)
	-- Blüten im Moos
	local flowers = { V(0.6, 4.55, -0.8), V(-0.5, 4.5, 0.4), V(0.2, 4.7, 1.2), V(-0.8, 4.35, -1.3), V(0.9, 4.3, 0.9) }
	for i, fp in ipairs(flowers) do
		local c = alpha and RGB(255, 120, 200) or (i % 2 == 0 and RGB(255, 230, 90) or RGB(255, 255, 255))
		b:add("Body", "S", V(0.32, 0, 0), fp, c, alpha and M.Neon or M.SmoothPlastic)
		b:add("Body", "S", V(0.14, 0, 0), fp + V(0, 0.12, 0), RGB(255, 180, 40))
	end
	b:joint("Head", "Body", V(0, 3.7, -2.0))
	b:add("Head", "E", V(1.2, 1.6, 1.3), V(0, 3.95, -2.25), fur, M.Fabric, V(25, 0, 0))
	b:add("Head", "E", V(1.45, 1.45, 2.0), V(0, 4.35, -2.85), fur, M.Fabric, nil, { weak = true })
	b:add("Head", "E", V(1.05, 0.95, 0.95), V(0, 4.0, -3.65), light, M.Fabric)
	b:add("Head", "E", V(0.5, 0.3, 0.2), V(0, 4.12, -4.1), RGB(50, 40, 35))
	b:add("Head", "W", V(0.6, 0.9, 0.5), V(0, 3.35, -3.5), moss, M.Grass, V(180, 0, 0))
	b:eye("Head", V(0.6, 4.6, -3.25), 0.38, RGB(240, 200, 60), "bar", { yaw = -35 })
	b:eye("Head", V(-0.6, 4.6, -3.25), 0.38, RGB(240, 200, 60), "bar", { yaw = 35 })
	b:mirror("Head", "Head", "E", V(0.25, 0.5, 0.8), V(0.8, 4.75, -2.6), fur, M.Fabric, V(0, 0, -50))
	-- Farnhörner (eingerollt)
	local hornC = alpha and RGB(230, 190, 90) or bark
	for side = -1, 1, 2 do
		local base = V(0.45 * side, 5.0, -2.7)
		local pts = { V(0, 0, 0), V(0.25, 0.55, 0.35), V(0.45, 0.85, 0.95), V(0.55, 0.6, 1.5), V(0.5, 0.1, 1.55), V(0.4, -0.15, 1.15) }
		for i = 1, #pts - 1 do
			local a = base + V(pts[i].X * side, pts[i].Y, pts[i].Z)
			local c = base + V(pts[i + 1].X * side, pts[i + 1].Y, pts[i + 1].Z)
			local mid = (a + c) / 2
			local len = (c - a).Magnitude
			local th = 0.42 - i * 0.05
			b:add("Head", "B", V(th, th, len + 0.1), mid, hornC, M.Wood, nil, { lookAt = c })
		end
		b:add("Head", "E", V(0.6, 0.1, 0.35), base + V(0.6 * side, 0.95, 0.9), moss, M.Grass, V(0, 0, 30 * side))
		b:add("Head", "E", V(0.5, 0.1, 0.3), base + V(0.7 * side, 0.45, 1.5), moss, M.Grass, V(0, 0, -20 * side))
	end
	if alpha then
		b:add("Head", "E", V(1.8, 0.25, 1.4), V(0, 5.25, -2.6), RGB(255, 200, 80), M.Neon, nil, { glow = true })
	end
	local legs = { LegFL = V(0.85, 2.0, -1.35), LegFR = V(-0.85, 2.0, -1.35), LegBL = V(0.85, 2.0, 1.35), LegBR = V(-0.85, 2.0, 1.35) }
	for n, p in pairs(legs) do
		b:joint(n, "Body", p)
		b:add(n, "E", V(0.85, 1.4, 1.0), p, fur, M.Fabric)
		b:add(n, "CY", V(0.5, 1.6, 0.5), V(p.X, 0.85, p.Z), RGB(95, 80, 65), M.Fabric)
		b:add(n, "E", V(0.62, 0.36, 0.72), V(p.X, 0.18, p.Z - 0.05), RGB(45, 38, 34))
	end
	b:joint("Tail", "Body", V(0, 3.5, 2.1))
	b:add("Tail", "E", V(0.8, 0.9, 0.8), V(0, 3.75, 2.35), moss, M.Grass)
end

-- Flauschfunk: schwebende Statik-Wollwolke mit Blitzableiter-Antennen
Blueprints.flauschfunk = function(b, variant)
	local wool, face, volt = RGB(252, 248, 232), RGB(42, 46, 78), RGB(255, 225, 70)
	b:joint("Body", "Root", V(0, 2.0, 0))
	b:add("Body", "S", V(2.7, 0, 0), V(0, 2.1, 0.1), wool, M.Fabric)
	local puffs = { V(1.15, 2.3, 0.3), V(-1.15, 2.3, 0.3), V(0, 3.15, 0.2), V(0.7, 2.9, 0.9), V(-0.7, 2.9, 0.9), V(0, 2.0, 1.25), V(0.85, 1.55, 0.6), V(-0.85, 1.55, 0.6), V(0.6, 3.0, -0.4), V(-0.6, 3.0, -0.4) }
	for i, p in ipairs(puffs) do
		b:add("Body", "S", V(1.5 + (i % 3) * 0.2, 0, 0), p, i % 4 == 0 and RGB(255, 244, 205) or wool, M.Fabric)
	end
	-- Blitz-Zickzack auf der Wolle
	b:add("Body", "B", V(0.18, 0.7, 0.1), V(0.95, 2.55, 0.95), volt, M.Neon, V(0, -40, 25), { glow = true })
	b:add("Body", "B", V(0.18, 0.7, 0.1), V(1.15, 2.05, 0.95), volt, M.Neon, V(0, -40, -25), { glow = true })
	b:joint("Head", "Body", V(0, 2.0, -1.0))
	b:add("Head", "E", V(1.5, 1.4, 0.7), V(0, 1.95, -1.3), face, M.SmoothPlastic, nil, { weak = true })
	b:add("Head", "S", V(1.1, 0, 0), V(0, 2.65, -1.1), wool, M.Fabric)
	b:eye("Head", V(0.33, 2.05, -1.62), 0.3, volt, "none", { noWhite = true, irisNeon = true })
	b:eye("Head", V(-0.33, 2.05, -1.62), 0.3, volt, "none", { noWhite = true, irisNeon = true })
	b:add("Head", "E", V(0.35, 0.12, 0.08), V(0, 1.6, -1.66), RGB(255, 160, 190))
	b:joint("EarL", "Head", V(0.75, 2.2, -1.1))
	b:joint("EarR", "Head", V(-0.75, 2.2, -1.1))
	b:mirror("EarL", "EarR", "E", V(0.9, 0.35, 0.5), V(1.05, 2.1, -1.1), face, nil, V(0, 0, -20))
	b:joint("AntennaL", "Body", V(0.5, 3.6, -0.2))
	b:joint("AntennaR", "Body", V(-0.5, 3.6, -0.2))
	b:mirror("AntennaL", "AntennaR", "CY", V(0.12, 1.3, 0.12), V(0.65, 4.2, -0.2), RGB(70, 70, 90), M.Metal, V(0, 0, -15))
	b:mirror("AntennaL", "AntennaR", "S", V(0.42, 0, 0), V(0.82, 4.85, -0.2), volt, M.Neon, nil, { glow = true })
	local legs = { LegFL = V(0.55, 1.0, -0.4), LegFR = V(-0.55, 1.0, -0.4), LegBL = V(0.55, 1.0, 0.6), LegBR = V(-0.55, 1.0, 0.6) }
	for n, p in pairs(legs) do
		b:joint(n, "Body", p)
		b:add(n, "E", V(0.38, 0.75, 0.38), p - V(0, 0.3, 0), face)
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "StaticFx"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 4
	pe.Lifetime = NumberRange.new(0.15, 0.35)
	pe.Speed = NumberRange.new(2, 5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.35 * b.s, 0)
	pe.Color = ColorSequence.new(volt)
	pe.LightEmission = 1
	pe.Parent = b.model.PrimaryPart
end

-- Bachzange: Flusskrebs mit Kieselpanzer und einer Riesenschere
Blueprints.bachzange = function(b, variant)
	local shell, under, claw, pebble = RGB(58, 118, 148), RGB(190, 215, 220), RGB(232, 118, 78), RGB(150, 150, 140)
	b:joint("Body", "Root", V(0, 1.6, 0))
	b:add("Body", "E", V(3.3, 1.7, 3.1), V(0, 1.75, 0), shell, M.Slate)
	b:add("Body", "E", V(2.9, 1.0, 2.8), V(0, 1.2, 0), under, M.SmoothPlastic)
	b:add("Body", "E", V(2.5, 0.5, 2.3), V(0, 2.55, 0.1), RGB(70, 135, 160), M.Slate)
	for i, p in ipairs({ V(0.8, 2.6, 0.5), V(-0.6, 2.65, -0.3), V(0.2, 2.75, 0.9), V(-1.0, 2.4, 0.8), V(1.1, 2.4, -0.6) }) do
		b:add("Body", "E", V(0.55, 0.3, 0.5), p, pebble, M.Pebble)
	end
	b:add("Body", "E", V(0.8, 0.25, 0.6), V(-0.3, 2.8, 0.3), RGB(80, 150, 70), M.Grass)
	-- Schwanzsegmente
	b:joint("Tail", "Body", V(0, 1.4, 1.5))
	b:add("Tail", "E", V(1.8, 0.9, 1.1), V(0, 1.45, 1.9), shell, M.Slate)
	b:add("Tail", "E", V(1.4, 0.7, 0.9), V(0, 1.25, 2.55), shell, M.Slate)
	b:add("Tail", "E", V(1.9, 0.25, 0.9), V(0, 1.05, 3.1), claw, M.SmoothPlastic)
	-- Kopf mit Stielaugen
	b:joint("Head", "Body", V(0, 2.0, -1.4))
	b:add("Head", "E", V(1.6, 0.9, 0.9), V(0, 1.75, -1.55), shell, M.Slate, nil, { weak = true })
	b:mirror("Head", "Head", "CY", V(0.16, 0.9, 0.16), V(0.45, 2.55, -1.55), shell, nil, V(0, 0, -12))
	b:eye("Head", V(0.55, 3.05, -1.6), 0.4, RGB(20, 20, 25), "none", { noWhite = true })
	b:eye("Head", V(-0.55, 3.05, -1.6), 0.4, RGB(20, 20, 25), "none", { noWhite = true })
	b:mirror("Head", "Head", "CX", V(2.2, 0.06, 0.06), V(0.6, 1.9, -2.6), claw, nil, V(0, 60, 15))
	-- große Schere rechts
	b:joint("ClawR", "Body", V(-1.5, 1.7, -1.0))
	b:add("ClawR", "E", V(0.7, 0.7, 1.6), V(-1.85, 1.75, -1.6), claw)
	b:add("ClawR", "E", V(1.4, 1.2, 1.9), V(-2.1, 1.95, -2.9), claw, M.SmoothPlastic)
	b:add("ClawR", "W", V(0.6, 0.6, 1.6), V(-2.25, 2.35, -4.4), claw, nil, V(0, 0, 0))
	b:add("ClawR", "W", V(0.55, 0.5, 1.4), V(-2.0, 1.55, -4.3), RGB(200, 95, 60), nil, V(0, 0, 180))
	b:add("ClawR", "S", V(0.3, 0, 0), V(-2.5, 2.4, -3.3), RGB(255, 255, 255))
	-- kleine Schere links
	b:joint("ClawL", "Body", V(1.5, 1.6, -1.0))
	b:add("ClawL", "E", V(0.5, 0.5, 1.2), V(1.75, 1.55, -1.5), claw)
	b:add("ClawL", "E", V(0.8, 0.7, 1.1), V(1.9, 1.6, -2.3), claw)
	b:add("ClawL", "W", V(0.35, 0.35, 0.8), V(1.95, 1.8, -3.1), claw)
	-- Beine
	local legs = { LegFL = V(1.3, 1.3, -0.3), LegFR = V(-1.3, 1.3, -0.3), LegBL = V(1.3, 1.3, 0.8), LegBR = V(-1.3, 1.3, 0.8) }
	for n, p in pairs(legs) do
		b:joint(n, "Body", p)
		local side = p.X > 0 and 1 or -1
		b:add(n, "B", V(1.4, 0.22, 0.22), p + V(0.6 * side, 0.15, 0), claw, nil, V(0, 0, 25 * side))
		b:add(n, "B", V(0.22, 1.2, 0.22), p + V(1.25 * side, -0.55, 0), claw, nil, V(0, 0, -15 * side))
	end
end

-- Frostigel: runder Igel mit Eiszapfen-Stacheln
Blueprints.frostigel = function(b, variant)
	local fur, face, ice = RGB(160, 128, 100), RGB(242, 228, 210), RGB(170, 228, 255)
	b:joint("Body", "Root", V(0, 1.4, 0))
	b:add("Body", "E", V(2.7, 2.2, 3.0), V(0, 1.45, 0.1), fur, M.Fabric)
	b:add("Body", "E", V(2.0, 1.2, 1.8), V(0, 1.05, -0.4), face, M.Fabric)
	b:joint("Head", "Body", V(0, 1.5, -1.1))
	b:add("Head", "E", V(1.55, 1.35, 1.2), V(0, 1.4, -1.45), face, M.Fabric, nil, { weak = true })
	b:add("Head", "E", V(0.55, 0.45, 0.7), V(0, 1.25, -2.05), face, M.Fabric)
	b:add("Head", "S", V(0.3, 0, 0), V(0, 1.35, -2.42), RGB(70, 140, 220), M.SmoothPlastic, nil, { refl = 0.2 })
	b:eye("Head", V(0.36, 1.65, -1.95), 0.3, RGB(25, 25, 35), "none", { noWhite = true, yaw = -15 })
	b:eye("Head", V(-0.36, 1.65, -1.95), 0.3, RGB(25, 25, 35), "none", { noWhite = true, yaw = 15 })
	b:mirror("Head", "Head", "E", V(0.3, 0.15, 0.08), V(0.55, 1.3, -1.98), RGB(255, 170, 190), nil, V(0, -30, 0))
	b:mirror("Head", "Head", "E", V(0.35, 0.4, 0.2), V(0.6, 2.05, -1.35), fur, M.Fabric)
	-- Eisstacheln (eigenes Gelenk zum Aufstellen)
	b:joint("Spikes", "Body", V(0, 1.6, 0.2))
	local n = 0
	for ring = 1, 3 do
		local elev = 20 + ring * 22
		local cnt = 9 - ring * 2 + 2
		for k = 0, cnt - 1 do
			local az = -100 + (200 / math.max(1, cnt - 1)) * k
			local dir = CFrame.Angles(0, rad(az), 0) * CFrame.Angles(rad(elev), 0, 0)
			local d = dir.LookVector * -1
			local base = V(0, 1.55, 0.25) + V(d.X * 1.2, math.abs(d.Y) * 0.95 + 0.1, d.Z * 1.35)
			local tipDir = (base - V(0, 1.0, 0.1)).Unit
			local len = 1.2 + (ring == 2 and 0.3 or 0)
			local mid = base + tipDir * (len * 0.4)
			b:add("Spikes", "E", V(0.36, 0.36, len), mid, ice, M.Ice, nil, { t = 0.12, lookAt = mid + tipDir })
			n += 1
		end
	end
	b:add("Spikes", "E", V(0.4, 0.4, 1.0), V(0, 2.9, 0.2), RGB(220, 245, 255), M.Ice, V(-60, 0, 0))
	local legs = { LegFL = V(0.7, 0.6, -0.6), LegFR = V(-0.7, 0.6, -0.6), LegBL = V(0.7, 0.6, 0.8), LegBR = V(-0.7, 0.6, 0.8) }
	for nm, p in pairs(legs) do
		b:joint(nm, "Body", p)
		b:add(nm, "E", V(0.45, 0.6, 0.55), p - V(0, 0.25, 0), RGB(120, 95, 75), M.Fabric)
	end
end

-- Surrflügel: große Libellen-Kreatur mit vier Glasflügeln
Blueprints.surrfluegel = function(b, variant)
	local jade, dark, wing, glow = RGB(36, 168, 138), RGB(25, 50, 55), RGB(205, 255, 240), RGB(120, 255, 210)
	b:joint("Body", "Root", V(0, 1.6, 0))
	b:add("Body", "E", V(1.5, 1.4, 1.9), V(0, 1.6, -0.3), jade, M.SmoothPlastic, nil, { refl = 0.15 })
	b:add("Body", "E", V(0.9, 0.5, 1.4), V(0, 2.2, -0.2), RGB(60, 200, 160), M.SmoothPlastic, nil, { refl = 0.2 })
	local segs = { { 0.95, 1.0 }, { 0.8, 1.7 }, { 0.7, 2.4 }, { 0.6, 3.1 }, { 0.5, 3.75 }, { 0.4, 4.3 } }
	b:joint("Tail", "Body", V(0, 1.6, 0.6))
	for i, sg in ipairs(segs) do
		b:add("Tail", "E", V(sg[1], sg[1], 0.8), V(0, 1.6 + i * 0.04, sg[2]), i % 2 == 0 and dark or jade, M.SmoothPlastic, nil, { refl = 0.1 })
	end
	b:add("Tail", "E", V(0.3, 0.3, 0.9), V(0, 1.9, 4.85), glow, M.Neon, V(-20, 0, 0), { glow = true })
	b:add("Tail", "E", V(0.3, 0.3, 0.9), V(0, 1.35, 4.85), glow, M.Neon, V(20, 0, 0), { glow = true })
	b:joint("Head", "Body", V(0, 1.7, -1.2))
	b:add("Head", "E", V(1.1, 1.0, 0.9), V(0, 1.7, -1.55), jade, M.SmoothPlastic, nil, { weak = true })
	b:mirror("Head", "Head", "E", V(0.85, 0.95, 0.85), V(0.45, 1.9, -1.75), RGB(40, 230, 200), M.Glass, nil, { t = 0.05, refl = 0.3, weak = true })
	b:mirror("Head", "Head", "S", V(0.2, 0, 0), V(0.55, 2.1, -2.12), RGB(255, 255, 255), M.Neon)
	b:mirror("Head", "Head", "W", V(0.12, 0.35, 0.4), V(0.18, 1.25, -2.0), dark, nil, V(0, 0, 180))
	-- Flügel
	local wings = { WingL = V(0.6, 2.15, -0.6), WingR = V(-0.6, 2.15, -0.6), WingL2 = V(0.6, 2.1, 0.15), WingR2 = V(-0.6, 2.1, 0.15) }
	for nm, p in pairs(wings) do
		b:joint(nm, "Body", p)
		local side = p.X > 0 and 1 or -1
		local back = nm:sub(-1) == "2"
		local yaw = back and -10 * side or 10 * side
		b:add(nm, "E", V(3.6, 0.08, back and 0.95 or 1.05), p + V(1.9 * side, 0.05, back and 0.1 or -0.05), wing, M.Glass, V(0, yaw, 0), { t = 0.45, refl = 0.2 })
		b:add(nm, "B", V(3.3, 0.06, 0.06), p + V(1.8 * side, 0.1, back and 0.1 or -0.05), glow, M.Neon, V(0, yaw, 0))
		b:add(nm, "E", V(0.5, 0.07, 0.4), p + V(3.2 * side, 0.1, back and 0.15 or -0.1), RGB(30, 90, 80), M.SmoothPlastic, V(0, yaw, 0))
	end
	for i = 1, 3 do
		b:mirror("Body", "Body", "B", V(0.12, 0.9, 0.12), V(0.45, 1.0, -0.8 + i * 0.35), dark, nil, V(10, 0, -25))
	end
end

-- Dämmerluchs: Luchs mit Mondrunen, Pinselohren und Stummelschwanz
Blueprints.daemmerluchs = function(b, variant)
	local fur, belly, rune = RGB(52, 46, 84), RGB(125, 112, 165), RGB(175, 115, 255)
	local alpha = variant == "alpha"
	b:joint("Body", "Root", V(0, 2.6, 0))
	b:add("Body", "E", V(2.0, 2.0, 4.1), V(0, 2.65, 0), fur, M.Fabric)
	b:add("Body", "E", V(1.5, 1.2, 3.3), V(0, 2.2, -0.1), belly, M.Fabric)
	b:add("Body", "E", V(1.8, 1.9, 1.6), V(0, 2.95, -1.45), fur, M.Fabric)
	for side = -1, 1, 2 do
		b:add("Body", "E", V(0.08, 0.25, 1.3), V(1.0 * side, 2.9, 0.3), rune, M.Neon, V(0, 0, 0), { glow = true })
		b:add("Body", "E", V(0.08, 0.6, 0.18), V(1.0 * side, 2.7, -0.2), rune, M.Neon, nil, { glow = true })
		b:add("Body", "E", V(0.08, 0.5, 0.18), V(0.98 * side, 2.75, 0.85), rune, M.Neon, nil, { glow = true })
	end
	b:joint("Head", "Body", V(0, 3.3, -1.9))
	b:add("Head", "E", V(1.75, 1.6, 1.6), V(0, 3.6, -2.45), fur, M.Fabric, nil, { weak = true })
	b:add("Head", "E", V(0.95, 0.72, 0.75), V(0, 3.32, -3.12), belly, M.Fabric)
	b:add("Head", "E", V(0.32, 0.2, 0.15), V(0, 3.52, -3.5), RGB(30, 25, 40))
	b:mirror("Head", "Head", "E", V(0.65, 0.95, 0.9), V(0.8, 3.25, -2.35), belly, M.Fabric, V(0, 0, 20))
	b:eye("Head", V(0.42, 3.78, -3.08), 0.36, rune, "slit", { yaw = -18, irisNeon = true, pupil = RGB(10, 5, 25) })
	b:eye("Head", V(-0.42, 3.78, -3.08), 0.36, rune, "slit", { yaw = 18, irisNeon = true, pupil = RGB(10, 5, 25) })
	b:add("Head", "E", V(0.5, 0.12, 0.08), V(0, 4.15, -3.2), RGB(235, 225, 255), M.Neon, V(0, 0, 0), { glow = true })
	b:joint("EarL", "Head", V(0.55, 4.2, -2.4))
	b:joint("EarR", "Head", V(-0.55, 4.2, -2.4))
	b:mirror("EarL", "EarR", "W", V(0.16, 1.0, 0.6), V(0.6, 4.6, -2.4), fur, M.Fabric, V(0, 0, -10))
	b:mirror("EarL", "EarR", "CY", V(0.06, 0.6, 0.06), V(0.66, 5.3, -2.4), rune, M.Neon, V(0, 0, -10))
	if alpha then
		for i = -2, 2 do
			b:add("Head", "W", V(0.2, 0.9 - math.abs(i) * 0.15, 0.35), V(i * 0.3, 4.65, -2.6 + math.abs(i) * 0.1), RGB(220, 180, 255), M.Neon, V(0, 0, -i * 12), { glow = true })
		end
	end
	local legs = { LegFL = V(0.65, 1.8, -1.4), LegFR = V(-0.65, 1.8, -1.4), LegBL = V(0.65, 1.8, 1.3), LegBR = V(-0.65, 1.8, 1.3) }
	for n, p in pairs(legs) do
		b:joint(n, "Body", p)
		b:add(n, "E", V(0.7, 1.9, 0.8), p - V(0, 0.4, 0), fur, M.Fabric)
		b:add(n, "E", V(0.72, 0.38, 0.85), V(p.X, 0.2, p.Z - 0.1), belly, M.Fabric)
	end
	b:joint("Tail", "Body", V(0, 3.0, 2.0))
	b:add("Tail", "E", V(0.6, 0.6, 1.1), V(0, 3.2, 2.4), fur, M.Fabric, V(-30, 0, 0))
	b:add("Tail", "E", V(0.45, 0.45, 0.45), V(0, 3.5, 2.85), rune, M.Neon, nil, { glow = true })
end

-- Morvath: Boss – Koloss aus Wurzeln, Stein und Moos mit Hirschschädel und glühendem Kern
Blueprints.morvath = function(b, variant)
	local stone, moss, bark, bone, core = RGB(84, 84, 78), RGB(78, 128, 52), RGB(92, 66, 42), RGB(222, 212, 182), RGB(150, 255, 90)
	b:joint("Body", "Root", V(0, 12, 0))
	b:add("Body", "E", V(12, 10, 14), V(0, 13, 0.5), stone, M.Slate)
	b:add("Body", "E", V(9, 3.2, 10), V(0, 17.6, 1.8), moss, M.Grass)
	b:add("Body", "E", V(5.5, 2.6, 5), V(0, 19, 3.5), RGB(66, 112, 44), M.Grass)
	for i, p in ipairs({ V(4.5, 15.5, -1), V(-4.5, 15.5, -1), V(5, 14, 3.5), V(-5, 14, 3.5), V(0, 15, 7) }) do
		b:add("Body", "E", V(4, 3, 4.5), p, RGB(110, 108, 100), M.Slate, V(0, i * 37, (i % 2 == 0) and 15 or -15))
	end
	b:add("Body", "E", V(9, 7, 6), V(0, 11, -5.2), stone, M.Slate)
	-- Kern (Schwachstelle)
	b:add("Body", "S", V(3.2, 0, 0), V(0, 12, -7.6), core, M.Neon, nil, { weak = true, glow = true, name = "Core" })
	for i = -2, 2 do
		b:add("Body", "CY", V(0.6, 7.5, 0.6), V(i * 1.6, 12, -7.3 + math.abs(i) * 0.7), bark, M.Wood, V(0, 0, -i * 6))
	end
	-- Moos-Behang & Pilze
	for i, p in ipairs({ V(4, 19, -2), V(-4, 19.3, -1), V(2, 20.5, 4), V(-3, 20, 5), V(5, 17, 4) }) do
		b:add("Body", "E", V(1.4, 0.4, 1.4), p, RGB(230, 90, 70), M.SmoothPlastic)
		b:add("Body", "CY", V(0.4, 0.8, 0.4), p - V(0, 0.5, 0), RGB(240, 230, 210))
	end
	for i, p in ipairs({ V(5.5, 16, -4), V(-5.5, 16, -4), V(6, 18, 2), V(-6, 18, 2) }) do
		b:add("Body", "E", V(1.2, 3.2, 1.2), p, core, M.Neon, V(0, 0, p.X > 0 and -25 or 25), { glow = true })
	end
	-- Kopf
	b:joint("Head", "Body", V(0, 16, -7))
	b:add("Head", "E", V(4.6, 4.2, 5.8), V(0, 17.2, -9.8), bone, M.Limestone, nil, { weak = true })
	b:add("Head", "E", V(3.2, 2.6, 3.4), V(0, 16.2, -12.3), bone, M.Limestone)
	b:add("Head", "E", V(3.6, 1.2, 4), V(0, 15.0, -11.6), RGB(60, 55, 50), M.Slate)
	b:eye("Head", V(1.25, 17.9, -12.2), 1.0, core, "none", { noWhite = true, irisNeon = true, yaw = -25 })
	b:eye("Head", V(-1.25, 17.9, -12.2), 1.0, core, "none", { noWhite = true, irisNeon = true, yaw = 25 })
	b:mirror("Head", "Head", "E", V(1.6, 1.0, 1.3), V(1.3, 17.7, -11.9), RGB(30, 30, 28), nil, V(0, -20, 0))
	-- Ast-Geweih
	for side = -1, 1, 2 do
		local segs = {
			{ V(1.6, 19, -9.5), V(3.8, 23, -8.5), 1.1 }, { V(3.8, 23, -8.5), V(5.5, 27, -7.5), 0.85 }, { V(5.5, 27, -7.5), V(6.2, 30, -6 ), 0.6 },
			{ V(3.8, 23, -8.5), V(6.8, 24.5, -10), 0.6 }, { V(5.5, 27, -7.5), V(8.2, 28, -9), 0.5 }, { V(2.6, 21, -9), V(2.6, 24.5, -11.2), 0.55 },
		}
		for _, sg in ipairs(segs) do
			local a = V(sg[1].X * side, sg[1].Y, sg[1].Z)
			local c = V(sg[2].X * side, sg[2].Y, sg[2].Z)
			local mid = (a + c) / 2
			b:add("Head", "B", V(sg[3], sg[3], (c - a).Magnitude + 0.3), mid, bark, M.Wood, nil, { lookAt = c })
		end
		for _, lp in ipairs({ V(6.2, 30.2, -6), V(8.2, 28.2, -9), V(6.8, 24.8, -10), V(2.6, 24.8, -11.2) }) do
			b:add("Head", "E", V(2.0, 1.4, 2.0), V(lp.X * side, lp.Y, lp.Z), RGB(96, 170, 64), M.Grass)
			b:add("Head", "S", V(0.5, 0, 0), V(lp.X * side, lp.Y + 0.6, lp.Z), core, M.Neon, nil, { glow = true })
		end
	end
	-- Arme
	for _, side in ipairs({ 1, -1 }) do
		local nm = side == 1 and "ArmL" or "ArmR"
		b:joint(nm, "Body", V(6.2 * side, 15, -4))
		b:add(nm, "E", V(4, 6, 4), V(7.2 * side, 13.5, -4.5), stone, M.Slate)
		b:add(nm, "E", V(3.2, 7, 3.2), V(7.8 * side, 8, -5.5), bark, M.Wood, V(-10, 0, 0))
		b:add(nm, "E", V(4.2, 3.2, 4.6), V(8 * side, 3.6, -6.5), stone, M.Slate)
		for k = -1, 1 do
			local p = b:add(nm, "B", V(0.7, 0.7, 3), V((8 + k * 1.3) * side, 1.6, -8.4), bark, M.Wood, V(30, 0, 0))
		end
		b:add(nm, "E", V(3.6, 1.6, 3.6), V(7.4 * side, 16.3, -4.2), moss, M.Grass)
	end
	-- Hinterbeine (Wurzelstümpfe)
	for _, side in ipairs({ 1, -1 }) do
		local nm = side == 1 and "LegBL" or "LegBR"
		b:joint(nm, "Body", V(4.5 * side, 9, 5))
		b:add(nm, "E", V(4, 6, 4.4), V(4.8 * side, 7.5, 5.4), stone, M.Slate)
		b:add(nm, "CY", V(3.4, 5, 3.4), V(5 * side, 2.6, 5.8), bark, M.Wood)
		for k = 0, 3 do
			local a = rad(k * 90 + 45)
			b:add(nm, "B", V(0.8, 0.8, 3.2), V(5 * side + math.cos(a) * 2, 0.5, 5.8 + math.sin(a) * 2), bark, M.Wood, V(0, -math.deg(a) + 90, 0))
		end
	end
	-- Wurzelschweif
	b:joint("Tail", "Body", V(0, 12, 7))
	b:add("Tail", "E", V(3, 3, 6), V(0, 10.5, 9.5), bark, M.Wood, V(30, 0, 0))
	b:add("Tail", "E", V(2, 2, 5), V(0, 7.5, 12.5), bark, M.Wood, V(40, 0, 0))
	local light = Instance.new("PointLight")
	light.Color = core
	light.Range = 12 * b.s
	light.Brightness = 0.8
	light.Parent = b.model:FindFirstChild("Core")
end

-- Noxen: Premium-Nachthirsch mit Sternbild-Geweih und Polarlicht-Mähne
Blueprints.noxen = function(b, variant)
	local night, light, star, aurora, gold = RGB(28, 34, 72), RGB(70, 80, 140), RGB(190, 215, 255), RGB(130, 110, 255), RGB(240, 200, 90)
	b:joint("Body", "Root", V(0, 4.2, 0))
	b:add("Body", "E", V(2.2, 2.4, 4.3), V(0, 4.3, 0), night, M.Fabric)
	b:add("Body", "E", V(1.7, 1.4, 3.4), V(0, 3.75, -0.1), light, M.Fabric)
	local speck = { V(0.9, 5.0, -0.8), V(-0.8, 4.8, 0.4), V(0.5, 5.4, 1.1), V(-0.4, 5.3, -1.4), V(1.05, 4.4, 1.3), V(-1.05, 4.2, -0.3), V(0.2, 5.5, 0.1), V(-0.7, 5.1, 1.6) }
	for _, p in ipairs(speck) do b:add("Body", "S", V(0.16, 0, 0), p, star, M.Neon, nil, { glow = true }) end
	b:add("Body", "E", V(1.3, 2.6, 1.3), V(0, 5.5, -1.85), night, M.Fabric, V(-30, 0, 0))
	b:add("Body", "E", V(0.25, 2.4, 0.6), V(0, 5.9, -1.4), aurora, M.Neon, V(-30, 0, 0), { glow = true })
	b:add("Body", "E", V(0.2, 1.8, 0.5), V(0, 5.6, -0.9), RGB(90, 230, 220), M.Neon, V(-40, 0, 0), { glow = true })
	b:joint("Head", "Body", V(0, 6.4, -2.5))
	b:add("Head", "E", V(1.25, 1.25, 2.1), V(0, 6.75, -3.0), night, M.Fabric, nil, { weak = true })
	b:add("Head", "E", V(0.85, 0.8, 0.9), V(0, 6.5, -3.9), light, M.Fabric)
	b:eye("Head", V(0.5, 7.0, -3.35), 0.36, star, "none", { noWhite = true, irisNeon = true, yaw = -40 })
	b:eye("Head", V(-0.5, 7.0, -3.35), 0.36, star, "none", { noWhite = true, irisNeon = true, yaw = 40 })
	b:add("Head", "S", V(0.3, 0, 0), V(0, 7.35, -3.55), gold, M.Neon, nil, { glow = true })
	b:mirror("Head", "Head", "E", V(0.2, 0.7, 0.4), V(0.6, 7.3, -2.6), night, M.Fabric, V(0, 0, -40))
	-- Sternbild-Geweih
	for side = -1, 1, 2 do
		local pts = { V(0.35, 7.3, -2.9), V(0.9, 8.6, -2.6), V(1.6, 9.6, -2.1), V(2.4, 10.2, -1.9), V(1.2, 10.4, -2.9), V(2.0, 8.9, -1.4) }
		local links = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 3, 5 }, { 2, 6 } }
		for _, l in ipairs(links) do
			local a = V(pts[l[1]].X * side, pts[l[1]].Y, pts[l[1]].Z)
			local c = V(pts[l[2]].X * side, pts[l[2]].Y, pts[l[2]].Z)
			local mid = (a + c) / 2
			b:add("Head", "B", V(0.12, 0.12, (c - a).Magnitude), mid, star, M.Neon, nil, { glow = true, lookAt = c })
		end
		for i = 2, #pts do
			b:add("Head", "S", V(i == 4 and 0.45 or 0.3, 0, 0), V(pts[i].X * side, pts[i].Y, pts[i].Z), RGB(240, 248, 255), M.Neon, nil, { glow = true })
		end
	end
	local legs = { LegFL = V(0.6, 3.3, -1.5), LegFR = V(-0.6, 3.3, -1.5), LegBL = V(0.6, 3.3, 1.4), LegBR = V(-0.6, 3.3, 1.4) }
	for n, p in pairs(legs) do
		b:joint(n, "Body", p)
		b:add(n, "E", V(0.6, 2.0, 0.75), p - V(0, 0.5, 0), night, M.Fabric)
		b:add(n, "CY", V(0.32, 1.9, 0.32), V(p.X, 1.2, p.Z), light, M.Fabric)
		b:add(n, "E", V(0.42, 0.35, 0.5), V(p.X, 0.2, p.Z), gold, M.Metal, nil, { refl = 0.2 })
	end
	b:joint("Tail", "Body", V(0, 4.9, 2.1))
	b:add("Tail", "E", V(0.5, 0.6, 1.6), V(0, 5.0, 2.8), aurora, M.Neon, V(25, 0, 0), { glow = true })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "StarDust"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 5
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(0.2, 1)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.3 * b.s, 0)
	pe.Color = ColorSequence.new(star, aurora)
	pe.LightEmission = 1
	pe.Parent = b.model.PrimaryPart
end

local RootHeights = {
	gackerling = 1.7, glutwiesel = 1.6, moosbock = 3.0, flauschfunk = 2.0, bachzange = 1.6, frostigel = 1.4,
	surrfluegel = 1.6, daemmerluchs = 2.6, morvath = 12, noxen = 4.2,
}

----------------------------------------------------------------------
-- Mesh-Modelle (z. B. aus Meshy): Vorlagen in Shared.CreatureMeshes.<key>
-- Jede Vorlage enthält MeshParts im Modellraum (Boden = Y 0, vorne = -Z, Größe bei Scale 1).
-- MeshRigs ordnet jedes Teil einem Animationsgelenk zu. Fehlt die Vorlage, wird der
-- prozedurale Bauplan verwendet (Fallback).
----------------------------------------------------------------------
local MeshRigs = {
	gackerling = {
		joints = {
			{ "Body", "Root", V(0, 1.9, 0) },
			{ "Head", "Body", V(0, 2.55, -0.6) },
			{ "WingL", "Body", V(1.0, 2.35, -0.49) },  -- +X-Flügel
			{ "WingR", "Body", V(-1.0, 2.35, -0.49) }, -- -X-Flügel
			{ "LegL", "Body", V(0.59, 1.0, -0.6) },   -- Hüfte über dem +X-Fuß (Laufanimation)
			{ "LegR", "Body", V(-0.6, 1.0, -0.6) },   -- Hüfte über dem -X-Fuß
		},
		-- Namen stammen aus der KI-Segmentierung (vor der 180°-Drehung benannt): "left wing" liegt jetzt bei +X
		parts = { head = "Head", body = "Body", ["left wing"] = "WingL", ["right wing"] = "WingR", feet = "Body", foot_px = "LegL", foot_nx = "LegR" },
		weak = { head = true },
	},
}

local function meshTemplate(key)
	local folder = script.Parent:FindFirstChild("CreatureMeshes")
	local tpl = folder and folder:FindFirstChild(key)
	if tpl and MeshRigs[key] then return tpl end
	return nil
end

local function buildFromMesh(b, key, tpl)
	local rig = MeshRigs[key]
	local s = b.s
	for _, j in ipairs(rig.joints) do b:joint(j[1], j[2], j[3]) end
	for _, src in ipairs(tpl:GetChildren()) do
		if src:IsA("BasePart") then
			local jointName = rig.parts[src.Name] or "Body"
			local p = src:Clone()
			p.Size = src.Size * s
			p.CFrame = CFrame.new(src.Position * s) * (src.CFrame - src.CFrame.Position)
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = true
			p.Massless = true
			p.CastShadow = true
			if rig.weak and rig.weak[src.Name] then p:SetAttribute("WeakSpot", true) end
			p.Parent = b.model
			local w = Instance.new("WeldConstraint")
			w.Part0 = b.joints[jointName]
			w.Part1 = p
			w.Parent = p
			b.count += 1
		end
	end
	b.model:SetAttribute("MeshModel", true)
end

-- Öffentliche API ----------------------------------------------------
-- Baut ein Modell für eine Art (Pal-Config-Eintrag) und gibt es zurück (noch ohne Parent).
function Builder.Build(palDef, overrideScale)
	local key = palDef.model
	local bp = Blueprints[key]
	local tpl = meshTemplate(key)
	if not bp and not tpl then error("CreatureBuilder: kein Bauplan für " .. tostring(key)) end
	local scale = overrideScale or palDef.scale or 1
	local b = Builder.new(palDef.id, scale, RootHeights[key] or 2)
	if tpl then
		buildFromMesh(b, key, tpl)
	else
		bp(b, palDef.variant)
	end
	local model = b:finish(palDef.id)
	model:SetAttribute("ModelKey", key)
	return model
end

function Builder.HasBlueprint(key)
	return Blueprints[key] ~= nil or meshTemplate(key) ~= nil
end

return Builder
