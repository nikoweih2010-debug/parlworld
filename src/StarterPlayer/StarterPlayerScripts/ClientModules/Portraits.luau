-- Portraits: echte Kreaturenmodelle in ViewportFrames (gleicher Bauplan wie im Spiel)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pals = require(Shared.Config.Pals)
local Builder = require(Shared.CreatureBuilder)

local Portraits = {}

-- mode: "face" (Kopf-Nahaufnahme) oder "full" (ganzer Körper)
-- state: "known" | "silhouette"
function Portraits.Make(parent, speciesId, mode, state, bgColor)
	local def = Pals.Get(speciesId)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Portrait"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = bgColor or Color3.fromRGB(30, 42, 52)
	vf.BackgroundTransparency = bgColor and 0 or 1
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(170, 170, 180)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-1, -1.4, -0.8)
	vf.Parent = parent
	if not def or not Builder.HasBlueprint(def.model) then
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Text = "?"; l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(120, 130, 140); l.Font = Enum.Font.GothamBold; l.Parent = vf
		return vf
	end
	local ok, model = pcall(Builder.Build, def, 1)
	if not ok then return vf end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then d:Destroy() end
	end
	model:PivotTo(CFrame.new(0, model:GetAttribute("RootHeight") or 2, 0) * CFrame.Angles(0, math.rad(200), 0))
	model.Parent = vf
	local cf, ext = model:GetBoundingBox()
	local center = cf.Position
	local radius = math.max(ext.X, ext.Y, ext.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	if mode == "face" then
		local head = model:FindFirstChild("J_Head")
		local focus = head and head.Position or center
		focus += Vector3.new(0, radius * 0.06, 0)
		local dir = (CFrame.Angles(0, math.rad(200), 0) * Vector3.new(0.35, 0.15, -1)).Unit
		local dist = radius * (def.isBoss and 0.75 or 1.25)
		cam.CFrame = CFrame.lookAt(focus + dir * dist, focus)
	else
		local dir = (CFrame.Angles(0, math.rad(200), 0) * Vector3.new(0.7, 0.35, -1)).Unit
		cam.CFrame = CFrame.lookAt(center + dir * radius * 2.1, center)
	end
	cam.Parent = vf
	vf.CurrentCamera = cam
	if state == "silhouette" then
		vf.ImageColor3 = Color3.fromRGB(10, 12, 16)
		vf.Ambient = Color3.new(0, 0, 0)
	end
	return vf
end

return Portraits
