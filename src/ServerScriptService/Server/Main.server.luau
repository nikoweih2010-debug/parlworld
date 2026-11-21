-- Einstiegspunkt Server: verbindet alle Dienste (Reihenfolge ist wichtig)
local Players = game:GetService("Players")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)
local CombatService = require(script.Parent.CombatService)
local CaptureService = require(script.Parent.CaptureService)
local CompanionService = require(script.Parent.CompanionService)
local ShopService = require(script.Parent.ShopService)
local ProgressService = require(script.Parent.ProgressService)
local SpawnService = require(script.Parent.SpawnService)

-- Querverweise (vermeidet zirkuläre requires)
CreatureService.DataService = DataService
CombatService.Progress = ProgressService
CaptureService.Progress = ProgressService
CompanionService.Progress = ProgressService
ShopService.Progress = ProgressService

CombatService.Init()
CaptureService.Init()
CompanionService.Init()
ShopService.Init()
ProgressService.Init()
SpawnService.Init()

Net.Handle("GetState", function(player)
	return true, DataService.Snapshot(player)
end)

local function onPlayer(player)
	local data = DataService.OnPlayerAdded(player)
	if not data then return end
	ShopService.CheckPremium(player)
	ShopService.RefreshPremium(player)
	local Formulas = require(game:GetService("ReplicatedStorage").Shared.Formulas)
	local function setupChar(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.MaxHealth = Formulas.PlayerMaxHealth
			hum.Health = Formulas.PlayerMaxHealth
		end
	end
	if player.Character then task.spawn(setupChar, player.Character) end
	player.CharacterAdded:Connect(function(char)
		task.spawn(setupChar, char)
		CombatService.ResetAmmo(player)
		task.wait(0.5)
		CombatService.PushWeaponState(player)
	end)
	if player.Character then CombatService.PushWeaponState(player) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(player)
	DataService.OnPlayerRemoving(player)
end)

-- Nur in Studio: Test-Hook für automatisierte Prüfungen (existiert im Live-Spiel nicht)
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "ParlDebug"
	hook.OnInvoke = function(cmd, a, b, c)
		local p = Players:GetPlayers()[1]
		if cmd == "state" then return DataService.Snapshot(p)
		elseif cmd == "money" then DataService.AddMoney(p, a, false); return DataService.Get(p).money
		elseif cmd == "spawn" then
			local rec = CreatureService.Spawn(a, { level = c or 1, position = b, kind = "wild", team = "wild" })
			return rec and rec.id
		elseif cmd == "damage" then
			local rec = CreatureService.ById[a]
			if rec then CreatureService.Damage(rec, b, { player = p }); return rec.state, rec.hp end
		elseif cmd == "rec" then
			local rec = CreatureService.ById[a]
			return rec and { state = rec.state, hp = rec.hp, target = rec.target and tostring(rec.target) or nil, pos = rec.root.Position }
		elseif cmd == "target" then
			local rec = CreatureService.ById[a]; if rec then rec.target = p end
		elseif cmd == "set" then
			local d = DataService.Get(p); d[a] = b; DataService.Sync(p); return true
		elseif cmd == "trainerwin" then
			DataService.Get(p).trainers.lyra = true; DataService.Sync(p); return true
		elseif cmd == "addpal" then
			return DataService.AddPal(p, a, b or 5, false)
		elseif cmd == "premium" then
			DataService.Get(p).premium = true; ShopService.RefreshPremium(p); return true
		elseif cmd == "summonboss" then
			task.spawn(ProgressService.SummonBoss, p); return true
		elseif cmd == "bossrec" then
			for _, rec in pairs(CreatureService.Records) do
				if rec.kind == "boss" then return { id = rec.id, hp = rec.hp, max = rec.maxHp, phase = rec.phase, state = rec.state } end
			end
			return nil
		elseif cmd == "count" then
			local n = 0 for _ in pairs(CreatureService.Records) do n += 1 end return n
		end
	end
	hook.Parent = game:GetService("ServerStorage")
end

print("[Parlworld] Server bereit – Welt 1 geladen.")
