-- Einstiegspunkt Client: startet alle Client-Module und verteilt Server-Ereignisse
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script.Parent:WaitForChild("ClientModules")
local ClientState = require(Modules.ClientState)
local Animator = require(Modules.CreatureAnimator)
local VFX = require(Modules.VFX)
local WC = require(Modules.WeaponController)
local HUD = require(Modules.HUD)
local Menus = require(Modules.Menus)
local Ride = require(Modules.RideController)
local WorldClient = require(Modules.WorldClient)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local runtime = workspace:WaitForChild("Runtime")

Animator.Start(runtime:WaitForChild("Creatures"))
WC.Init()
HUD.Init(WC)
Menus.Init(WC, HUD)
Ride.Init(WC)
WorldClient.Init(Menus)

-- Server-Effekte verteilen
local HudEvents = { hurt = true, banner = true, countdown = true }
Remotes.VFX.OnClientEvent:Connect(function(kind, data)
	local ok, err = pcall(function()
		if HudEvents[kind] then
			HUD[kind](data)
		elseif VFX[kind] then
			VFX[kind](data)
		end
	end)
	if not ok then warn("[VFX] " .. tostring(kind) .. ": " .. tostring(err)) end
end)
Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	HUD.Notify(text, kind)
end)

-- Team-/Reit-Aktionen
local function action(name)
	local ok, msg = ClientState.Request(name)
	if not ok and msg then HUD.Notify(msg, "warn") end
end
HUD.Action = action

UserInputService.InputBegan:Connect(function(input, gp)
	if gp or Menus.IsOpen() then return end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.Q or kc == Enum.KeyCode.DPadUp then action("Summon")
	elseif kc == Enum.KeyCode.C or kc == Enum.KeyCode.DPadRight then action("CycleTeam")
	elseif kc == Enum.KeyCode.G or kc == Enum.KeyCode.DPadDown then action("Mount")
	end
end)

HUD.Notify("Willkommen auf der Smaragdinsel! Folge dem Tutorial oben links.", "tutorial")
