--[[
	Viewmodel: First-Person-Hände + Waffenmodelle (nur lokal, eigene Teile).
	Koordinaten: Ursprung = Griff, vorwärts = -Z. Jedes Modell hat ein Teil "Muzzle" und optional "Sight".
]]
local Viewmodel = {}
local M = Enum.Material
local V = Vector3.new
local RGB = Color3.fromRGB

local function mk(model, size, cf, color, mat, shape, opts)
	local p = Instance.new(opts and opts.wedge and "WedgePart" or "Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	if p.Material == M.Metal then
		-- Keep generated microdetail legible; the texture map carries the steel color.
		p.MaterialVariant = "parl_weapon_steel_lite"
		p.Color = p.Color:Lerp(RGB(255, 255, 255), 0.7)
		p.Reflectance = 0.05
	elseif p.Material == M.Wood then
		p.MaterialVariant = "parl_weapon_wood"
	end
	if opts and opts.mesh then
		local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
	end
	if opts and opts.t then p.Transparency = opts.t end
	if opts and opts.name then p.Name = opts.name end
	if opts and opts.refl then p.Reflectance = opts.refl end
	p.Parent = model
	return p
end

local CF = CFrame.new
local ANG = CFrame.Angles
local r = math.rad
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local Builders = {}

Builders.funkenpistole = function(m)
	local body = RGB(60, 62, 70)
	local acc = RGB(255, 150, 50)
	mk(m, V(0.32, 0.36, 1.25), CF(0, 0.18, -0.45), body, M.Metal, nil, { name = "Body" })
	mk(m, V(0.3, 0.75, 0.38), CF(0, -0.22, 0.02) * ANG(r(-12), 0, 0), RGB(80, 52, 36), M.Wood)
	mk(m, V(0.5, 0.16, 0.16), CF(0, 0.22, -1.2) * ANG(0, r(90), 0), RGB(40, 40, 45), M.Metal, CYL)
	mk(m, V(0.36, 0.1, 0.5), CF(0, 0.05, -0.75), acc, M.Neon)
	-- Laufkranz, Mündungsring und dunkle Bohrung geben dem Modell mehr Tiefe.
	mk(m, V(0.58, 0.28, 0.28), CF(0, 0.18, -1.1) * ANG(0, r(90), 0), RGB(82, 86, 94), M.Metal, CYL)
	mk(m, V(0.12, 0.32, 0.32), CF(0, 0.18, -1.42) * ANG(0, r(90), 0), RGB(30, 32, 38), M.Metal, CYL)
	mk(m, V(0.1, 0.18, 0.18), CF(0, 0.18, -1.49) * ANG(0, r(90), 0), RGB(12, 14, 18), M.SmoothPlastic, CYL)
	-- Metallische Seitenplatte, Griffnuten und kleine Befestigungsschrauben.
	mk(m, V(0.025, 0.2, 0.62), CF(0.17, 0.19, -0.48), RGB(100, 106, 116), M.Metal)
	for i = 0, 2 do
		mk(m, V(0.04, 0.035, 0.035), CF(0.19, 0.2, -0.28 - i * 0.18), RGB(205, 190, 150), M.Metal, BALL)
	end
	for i = 0, 3 do
		mk(m, V(0.33, 0.035, 0.025), CF(0.02, -0.22, -0.12 + i * 0.13), RGB(145, 102, 65), M.Wood)
	end
	-- Abzug und Schutzbügel.
	mk(m, V(0.08, 0.24, 0.08), CF(0, -0.02, -0.12) * ANG(r(-18), 0, 0), RGB(36, 38, 43), M.Metal)
	mk(m, V(0.18, 0.045, 0.32), CF(0, -0.16, -0.18), RGB(48, 50, 56), M.Metal)
	for i = 0, 2 do mk(m, V(0.38, 0.06, 0.06), CF(0, 0.3, -0.25 - i * 0.18), acc, M.Neon) end
	mk(m, V(0.08, 0.08, 0.12), CF(0, 0.4, -0.95), RGB(30, 30, 30), M.Metal, nil, { name = "Sight" })
	mk(m, V(0.1, 0.1, 0.1), CF(0, 0.22, -1.48), acc, M.Neon, nil, { name = "Muzzle", t = 1 })
end

Builders.dornenstreuer = function(m)
	local wood, metal, thorn = RGB(110, 72, 44), RGB(70, 74, 70), RGB(110, 200, 80)
	mk(m, V(0.36, 0.42, 1.0), CF(0, 0.12, 0.05), wood, M.Wood)
	mk(m, V(0.34, 0.5, 0.9), CF(0, -0.05, 0.75) * ANG(r(12), 0, 0), wood, M.Wood)
	for _, x in ipairs({ -0.11, 0.11 }) do
		mk(m, V(1.9, 0.2, 0.2), CF(x, 0.25, -1.3) * ANG(0, r(90), 0), metal, M.Metal, CYL)
	end
	mk(m, V(0.42, 0.26, 0.7), CF(0, 0.05, -0.85), RGB(60, 50, 40), M.Wood)
	for i = 0, 3 do
		mk(m, V(0.08, 0.3, 0.2), CF(0.2, 0.32, -0.6 - i * 0.35) * ANG(0, 0, r(-30)), thorn, M.Grass, nil, { wedge = true })
		mk(m, V(0.08, 0.3, 0.2), CF(-0.2, 0.32, -0.6 - i * 0.35) * ANG(0, 0, r(30)), thorn, M.Grass, nil, { wedge = true })
	end
	mk(m, V(0.3, 0.7, 0.3), CF(0, -0.25, 0.15) * ANG(r(-15), 0, 0), RGB(90, 60, 38), M.Wood)
	mk(m, V(0.08, 0.08, 0.12), CF(0, 0.4, -2.0), thorn, M.Neon, nil, { name = "Sight" })
	mk(m, V(0.1, 0.1, 0.1), CF(0, 0.25, -2.3), thorn, M.Neon, nil, { name = "Muzzle", t = 1 })
end

Builders.schwarmwerfer = function(m)
	local shell, dark, acc = RGB(60, 110, 170), RGB(35, 40, 50), RGB(120, 210, 255)
	mk(m, V(0.4, 0.5, 1.7), CF(0, 0.15, -0.55), shell, M.SmoothPlastic)
	mk(m, V(0.3, 0.35, 0.8), CF(0, 0.05, 0.6), dark, M.Metal)
	mk(m, V(0.28, 0.72, 0.36), CF(0, -0.28, 0.1) * ANG(r(-10), 0, 0), dark, M.Metal)
	mk(m, V(0.26, 0.75, 0.38), CF(0, -0.4, -0.65) * ANG(r(10), 0, 0), RGB(45, 50, 60), M.Metal)
	mk(m, V(0.8, 0.26, 0.26), CF(0, 0.22, -1.7) * ANG(0, r(90), 0), dark, M.Metal, CYL)
	mk(m, V(0.12, 0.34, 0.34), CF(0, 0.22, -2.1) * ANG(0, r(90), 0), acc, M.Neon, CYL)
	mk(m, V(0.44, 0.08, 1.2), CF(0, 0.44, -0.55), dark, M.Metal)
	for i = 0, 4 do mk(m, V(0.42, 0.05, 0.08), CF(0, 0.15, -0.1 - i * 0.25), acc, M.Neon) end
	mk(m, V(0.1, 0.18, 0.1), CF(0, 0.56, -0.9), dark, M.Metal, nil, { name = "Sight" })
	mk(m, V(0.1, 0.1, 0.1), CF(0, 0.22, -2.25), acc, M.Neon, nil, { name = "Muzzle", t = 1 })
end

Builders.falkenauge = function(m)
	local body, wood, acc = RGB(55, 45, 75), RGB(85, 60, 50), RGB(200, 160, 255)
	mk(m, V(0.36, 0.44, 1.6), CF(0, 0.12, -0.3), body, M.Metal)
	mk(m, V(0.34, 0.55, 1.1), CF(0, -0.05, 0.95) * ANG(r(8), 0, 0), wood, M.Wood)
	mk(m, V(0.28, 0.7, 0.34), CF(0, -0.3, 0.2) * ANG(r(-14), 0, 0), wood, M.Wood)
	mk(m, V(2.6, 0.18, 0.18), CF(0, 0.2, -2.3) * ANG(0, r(90), 0), RGB(40, 35, 50), M.Metal, CYL)
	mk(m, V(0.3, 0.26, 0.26), CF(0, 0.2, -3.6) * ANG(0, r(90), 0), acc, M.Neon, CYL)
	-- Zielfernrohr
	mk(m, V(1.3, 0.3, 0.3), CF(0, 0.55, -0.35) * ANG(0, r(90), 0), RGB(30, 30, 38), M.Metal, CYL)
	mk(m, V(0.1, 0.34, 0.34), CF(0, 0.55, -1.0) * ANG(0, r(90), 0), acc, M.Glass, CYL, { t = 0.3, refl = 0.4 })
	mk(m, V(0.08, 0.2, 0.1), CF(0, 0.4, -0.35), RGB(30, 30, 38), M.Metal)
	mk(m, V(0.1, 0.1, 0.1), CF(0, 0.55, 0.3), acc, M.Neon, nil, { name = "Sight", t = 1 })
	mk(m, V(0.1, 0.1, 0.1), CF(0, 0.2, -3.75), acc, M.Neon, nil, { name = "Muzzle", t = 1 })
end

Builders.glutwerfer = function(m)
	local metal, glow, dark = RGB(90, 70, 60), RGB(255, 120, 50), RGB(45, 38, 35)
	mk(m, V(1.6, 0.62, 0.62), CF(0, 0.25, -0.9) * ANG(0, r(90), 0), metal, M.CorrodedMetal, CYL)
	mk(m, V(0.2, 0.7, 0.7), CF(0, 0.25, -1.75) * ANG(0, r(90), 0), dark, M.Metal, CYL)
	mk(m, V(0.2, 0.5, 0.5), CF(0, 0.25, -1.8) * ANG(0, r(90), 0), glow, M.Neon, CYL)
	mk(m, V(0.55, 0.75, 0.75), CF(0, 0.15, -0.2) * ANG(0, 0, r(90)), dark, M.Metal, CYL)
	for i = 0, 3 do
		local a = r(i * 90 + 45)
		mk(m, V(0.2, 0.2, 0.2), CF(math.cos(a) * 0.38, 0.15 + math.sin(a) * 0.38, -0.2), glow, M.Neon, BALL)
	end
	mk(m, V(0.3, 0.7, 0.36), CF(0, -0.3, 0.1) * ANG(r(-12), 0, 0), dark, M.Metal)
	mk(m, V(0.32, 0.4, 0.9), CF(0, 0.1, 0.55), metal, M.CorrodedMetal)
	mk(m, V(0.12, 0.2, 0.12), CF(0, 0.62, -0.9), glow, M.Neon, nil, { name = "Sight" })
	mk(m, V(0.1, 0.1, 0.1), CF(0, 0.25, -1.9), glow, M.Neon, nil, { name = "Muzzle", t = 1 })
end

Builders.ball = function(m, tierDef)
	-- Mesh-Vorlage (Shared.ItemMeshes.fangkugel_stufe<N>) bevorzugen
	local folder = game:GetService("ReplicatedStorage").Shared:FindFirstChild("ItemMeshes")
	local tpl = folder and folder:FindFirstChild("fangkugel_stufe" .. tostring(tierDef.tier))
	if tpl then
		local p = tpl:Clone()
		p.Name = "Body"
		p.Size = tpl.Size * 0.95
		p.CFrame = CF(0, 0.15, -0.1)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Parent = m
		mk(m, V(0.1, 0.1, 0.1), CF(0, 0.2, -0.6), RGB(255, 255, 255), M.Neon, nil, { name = "Muzzle", t = 1 })
		return
	end
	local b = mk(m, V(0.9, 0.9, 0.9), CF(0, 0.15, -0.1), tierDef.color, M.SmoothPlastic, BALL, { name = "Body" })
	mk(m, V(0.2, 0.93, 0.93), CF(0, 0.15, -0.1) * ANG(0, 0, r(90)), tierDef.band, M.Neon, CYL)
	mk(m, V(0.25, 0.25, 0.25), CF(0, 0.15, -0.55), RGB(255, 255, 255), M.SmoothPlastic, BALL)
	mk(m, V(0.1, 0.1, 0.1), CF(0, 0.2, -0.6), RGB(255, 255, 255), M.Neon, nil, { name = "Muzzle", t = 1 })
end

-- Arme (Unterarm + Hand), Farbe aus dem Avatar falls vorhanden
local function arms(m, skin, sleeve, pose)
	local function arm(side)
		local p = pose[side]
		mk(m, V(0.5, 0.5, 1.7), p * CF(0, 0, 0.75), sleeve, M.Fabric)
		mk(m, V(0.52, 0.3, 0.45), p * CF(0, 0, 0.0), RGB(70, 60, 40), M.Fabric)
		mk(m, V(0.46, 0.4, 0.55), p * CF(0, 0, -0.35), skin, M.SmoothPlastic, nil, { mesh = true })
	end
	arm("R")
	arm("L")
end

-- Hand liegt am Griff (Pose-Ursprung + 0,0,-0.35), Unterarm führt schräg nach unten/hinten aus dem Bild
local Poses = {
	default = { R = CF(0.06, -0.1, 0.3) * ANG(r(28), 0, 0), L = CF(-0.08, 0.0, -0.95) * ANG(r(22), r(-10), r(-5)) },
	pistol = { R = CF(0.04, -0.12, 0.28) * ANG(r(28), 0, 0), L = CF(-0.16, -0.16, 0.2) * ANG(r(30), r(-28), 0) },
	long = { R = CF(0.06, -0.1, 0.3) * ANG(r(28), 0, 0), L = CF(-0.06, 0.0, -1.1) * ANG(r(22), r(-8), r(-5)) },
	ball = { R = CF(0.04, -0.02, 0.3) * ANG(r(28), 0, 0), L = CF(-0.7, -0.4, 0.2) * ANG(r(35), r(-20), 0) },
}

-- baut das komplette Viewmodel für eine Waffen-ID (oder "ball")
function Viewmodel.Build(weaponId, skin, sleeve, tierDef)
	local m = Instance.new("Model")
	m.Name = "Viewmodel"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = m
	m.PrimaryPart = root
	local b = Builders[weaponId]
	-- Realistische Waffen-Meshes (Shared.ItemMeshes.<waffenId>) bevorzugen; Mündung/Visier an den alten Positionen
	local itemFolder = game:GetService("ReplicatedStorage").Shared:FindFirstChild("ItemMeshes")
	local meshTpl = weaponId ~= "ball" and itemFolder and itemFolder:FindFirstChild(weaponId)
	if meshTpl and Viewmodel.MeshPoints[weaponId] then
		local pts = Viewmodel.MeshPoints[weaponId]
		local p = meshTpl:Clone()
		p.Name = "Body"
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
		mk(m, V(0.1, 0.1, 0.1), CF(pts.muzzle), RGB(255, 255, 255), M.Neon, nil, { name = "Muzzle", t = 1 })
		mk(m, V(0.1, 0.1, 0.1), CF(pts.sight), RGB(255, 255, 255), M.Neon, nil, { name = "Sight", t = 1 })
	elseif weaponId == "ball" then b(m, tierDef) elseif b then b(m) end
	local pose = Poses.default
	if weaponId == "funkenpistole" then pose = Poses.pistol
	elseif weaponId == "falkenauge" or weaponId == "dornenstreuer" or weaponId == "schwarmwerfer" then pose = Poses.long
	elseif weaponId == "ball" then pose = Poses.ball end
	arms(m, skin or RGB(234, 184, 146), sleeve or RGB(64, 92, 70), pose)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	m:ScaleTo(Viewmodel.Scale)
	return m
end

-- Größe im Bild (First-Person-Maßstab)
Viewmodel.Scale = 0.42

-- Höhe der Visierlinie (für Zielen über Kimme), bereits skaliert
-- Mündungs- und Visierpunkte für die Mesh-Waffen (Viewmodel-Raum vor Skalierung)
Viewmodel.MeshPoints = {
	funkenpistole = { muzzle = V(0, 0.28, -1.55), sight = V(0, 0.45, -0.9) },
	dornenstreuer = { muzzle = V(0, 0.3, -2.35), sight = V(0, 0.45, -1.6) },
	schwarmwerfer = { muzzle = V(0, 0.32, -2.3), sight = V(0, 0.72, -0.6) },
	falkenauge = { muzzle = V(0, 0.3, -3.8), sight = V(0, 0.6, 0.2) },
	glutwerfer = { muzzle = V(0, 0.35, -2.0), sight = V(0, 0.82, -0.8) },
}

local rawSight = { funkenpistole = 0.4, dornenstreuer = 0.4, schwarmwerfer = 0.56, falkenauge = 0.55, glutwerfer = 0.62, ball = 0.2 }
-- Mit Mesh-Waffen liegt die Visierlinie etwas höher
local meshSight = { funkenpistole = 0.43, dornenstreuer = 0.42, schwarmwerfer = 0.7, falkenauge = 0.6, glutwerfer = 0.8 }
do
	local folder = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):FindFirstChild("ItemMeshes")
	for id, y in pairs(meshSight) do
		if folder and folder:FindFirstChild(id) then rawSight[id] = y end
	end
end
Viewmodel.SightHeight = {}
for k, v in pairs(rawSight) do Viewmodel.SightHeight[k] = v * Viewmodel.Scale end

return Viewmodel
