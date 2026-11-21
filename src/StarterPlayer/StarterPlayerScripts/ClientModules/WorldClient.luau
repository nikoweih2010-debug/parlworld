--[[
	WorldClient: lokale Welt-Darstellung je nach Fortschritt (Trainer-Siegel, Portal-Anzeige,
	Tutorial-Wegweiser) und Client-Aktionen von ProximityPrompts (Shop öffnen).
	Das Siegel ist nur für den eigenen Charakter durchlässig – der Server prüft den Bossstart zusätzlich.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage:WaitForChild("Shared").Config.Worlds)

local ClientState = require(script.Parent.ClientState)

local WorldClient = {}
local player = Players.LocalPlayer

local function apply(d)
	if not d then return end
	local open = d.trainers and d.trainers.lyra == true
	for _, g in ipairs(CollectionService:GetTagged("TrainerGate")) do
		for _, p in ipairs(g:IsA("BasePart") and { g } or g:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = not open
				p.LocalTransparencyModifier = open and 1 or 0
			end
			if p:IsA("ParticleEmitter") then p.Enabled = not open end
		end
		local label = g:FindFirstChild("GateText", true)
		if label and label:IsA("TextLabel") then
			label.Text = open and "" or "Versiegelt – besiege Trainerin Lyra"
		end
	end
	for _, portal in ipairs(CollectionService:GetTagged("WorldPortal")) do
		local w = portal:GetAttribute("World") or 2
		local def = Worlds.List[w]
		local label = portal:FindFirstChild("PortalText", true)
		local unlocked = d.worldsUnlocked >= w
		if label and def then
			label.Text = string.format("WELT %d: %s\n%s", w, string.upper(def.name), unlocked and "Freigeschaltet – erscheint in einem kommenden Update" or ("Gesperrt – " .. (def.unlockRequirement or "")))
			label.TextColor3 = unlocked and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(255, 190, 120)
		end
		local swirl = portal:FindFirstChild("Swirl", true)
		if swirl and swirl:IsA("BasePart") then
			swirl.Color = unlocked and Color3.fromRGB(255, 140, 60) or Color3.fromRGB(80, 80, 95)
		end
	end
	local onSignStep = (not d.tutorial.done) and d.tutorial.step == 1
	for _, s in ipairs(CollectionService:GetTagged("TutorialSign")) do
		local beam = s:FindFirstChild("Beacon", true)
		if beam and beam:IsA("BasePart") then beam.LocalTransparencyModifier = onSignStep and 0 or 1 end
	end
end

function WorldClient.Init(menus)
	ClientState.Changed:Connect(apply)
	if ClientState.Data then apply(ClientState.Data) end
	CollectionService:GetInstanceAddedSignal("TrainerGate"):Connect(function() apply(ClientState.Data) end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Action") == "OpenShop" then menus.Open("shop") end
	end)
end

return WorldClient
