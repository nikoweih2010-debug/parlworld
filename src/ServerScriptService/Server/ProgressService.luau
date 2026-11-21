--[[
	ProgressService: Tutorial, Kampf-Belohnungen, Trainerkampf, Bosskampf, Welt-Freischaltung, Portal.
	Alle Fortschritte werden nur hier (serverseitig) gesetzt.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Config.Progression)
local Worlds = require(Shared.Config.Worlds)
local Weapons = require(Shared.Config.Weapons)
local Pals = require(Shared.Config.Pals)
local Formulas = require(Shared.Formulas)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)
local CompanionService = require(script.Parent.CompanionService)
local ShopService = require(script.Parent.ShopService)

local ProgressService = {}

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

------------------------------------------------------------------ Tutorial
local Steps = Progression.Tutorial

local function stateSatisfied(d, step)
	if step.event == "team_set" then return #d.team > 0 end
	if step.event == "trainer_win" then return d.trainers.lyra == true end
	if step.event == "boss_win" then return d.bosses.morvath == true end
	return false
end

local function advance(player, d)
	while not d.tutorial.done do
		local step = Steps[d.tutorial.step]
		if not step then d.tutorial.done = true; break end
		local seen = d.tutorial.seen or {}
		local complete = (d.tutorial.counter >= (step.count or 1)) or stateSatisfied(d, step) or ((step.count or 1) == 1 and seen[step.event])
		if not complete then break end
		if step.reward and step.reward > 0 then DataService.AddMoney(player, step.reward, false) end
		Net.NotifyPlayer(player, "Tutorial erledigt: " .. step.title .. (step.reward and step.reward > 0 and ("  (+" .. step.reward .. " G)") or ""), "tutorial")
		d.tutorial.step += 1
		d.tutorial.counter = 0
		if d.tutorial.step > #Steps then d.tutorial.done = true end
	end
	DataService.Sync(player)
end

function ProgressService.Event(player, ev, n)
	local d = DataService.Get(player)
	if not d then return end
	d.tutorial.seen = d.tutorial.seen or {}
	if d.tutorial.done then return end
	local step = Steps[d.tutorial.step]
	if step and step.event == ev then
		d.tutorial.counter += (n or 1)
	else
		d.tutorial.seen[ev] = true
	end
	advance(player, d)
end

------------------------------------------------------------------ Belohnungen
local function rewardWild(rec, contributors)
	local def = rec.def
	for _, player in ipairs(contributors) do
		local d = DataService.Get(player)
		if d then
			local base = def.reward * (1 + 0.10 * (rec.level - 1))
			local got = DataService.AddMoney(player, base, true)
			d.stats.defeated += 1
			Net.NotifyPlayer(player, def.name .. " besiegt!  +" .. got .. " G" .. (rec.def.catchable ~= false and "  – jetzt Fangkugel werfen!" or ""), "money")
			CompanionService.GiveXp(player, def.xp * (1 + 0.1 * (rec.level - 1)))
			ProgressService.Event(player, "defeat_any")
		end
	end
end

------------------------------------------------------------------ Trainer
local battles = {} -- [trainerId] = { player, idx, rec, def }

local function endBattle(id, msg)
	local b = battles[id]
	if not b then return end
	battles[id] = nil
	if b.rec and not b.rec.removed then CreatureService.Despawn(b.rec, true) end
	if msg and b.player.Parent then Net.NotifyPlayer(b.player, msg, "warn") end
	workspace:SetAttribute("Trainer_" .. id, nil)
end

local function spawnTrainerPal(id)
	local b = battles[id]
	local tdef = Progression.Trainers[id]
	local entry = tdef.team[b.idx]
	local center = tdef.arena
	local pos = center + Vector3.new(0, 0, -12)
	local rec = CreatureService.Spawn(entry.species, { level = entry.level, position = pos, kind = "trainer", team = "trainer", hpMult = entry.hpMult, home = center, yaw = 0 })
	if not rec then endBattle(id, "Fehler beim Trainerkampf."); return end
	local player = b.player
	rec.targetFilter = function(t)
		return t == player or (type(t) == "table" and t.owner == player)
	end
	rec.target = player
	rec.model:SetAttribute("TrainerName", tdef.name)
	b.rec = rec
	Net.BroadcastVFX("summon", { id = rec.id, pos = rec.root.Position })
	Net.NotifyPlayer(player, tdef.name .. " schickt " .. rec.def.name .. " (Lv " .. rec.level .. ") in den Kampf! (" .. b.idx .. "/" .. #tdef.team .. ")", "dialog")
end

function ProgressService.ChallengeTrainer(player, id)
	local tdef = Progression.Trainers[id]
	local d = DataService.Get(player)
	if not tdef or not d then return end
	if d.trainers[id] then
		Net.NotifyPlayer(player, tdef.name .. ": \"Du hast mich schon besiegt! Der Weg zu den Wurzelruinen ist frei.\"", "dialog")
		return
	end
	local b = battles[id]
	if b and b.player.Parent then
		if b.player ~= player then Net.NotifyPlayer(player, "Die Arena ist gerade belegt – warte kurz.", "warn") end
		return
	end
	battles[id] = { player = player, idx = 1 }
	workspace:SetAttribute("Trainer_" .. id, player.UserId)
	Net.NotifyPlayer(player, tdef.name .. ": \"" .. tdef.intro .. "\"", "dialog")
	Net.NotifyPlayer(player, tdef.rewardText, "reward")
	Net.VFX:FireClient(player, "countdown", { seconds = 3, title = "Trainerkampf: " .. tdef.name })
	task.delay(3, function()
		if battles[id] and battles[id].player == player then spawnTrainerPal(id) end
	end)
	-- Überwachung: Tod/Verlassen bricht ab
	task.spawn(function()
		while battles[id] and battles[id].player == player do
			task.wait(0.5)
			local hrp = CreatureService.CharRoot(player)
			if not player.Parent then endBattle(id, nil); break end
			if not hrp then endBattle(id, "Trainerkampf verloren – versuche es erneut!"); break end
			if flat(hrp.Position - tdef.arena).Magnitude > tdef.arenaRadius * 1.9 then endBattle(id, "Du hast die Arena verlassen – Trainerkampf abgebrochen."); break end
		end
	end)
end

local function onTrainerPalDefeated(rec)
	for id, b in pairs(battles) do
		if b.rec == rec then
			local tdef = Progression.Trainers[id]
			if b.idx < #tdef.team then
				b.idx += 1
				b.rec = nil
				task.delay(2.5, function() if battles[id] == b then spawnTrainerPal(id) end end)
			else
				local player = b.player
				battles[id] = nil
				workspace:SetAttribute("Trainer_" .. id, nil)
				local d = DataService.Get(player)
				if d then
					d.trainers[id] = true
					local got = DataService.AddMoney(player, tdef.rewardMoney, true)
					local w = Weapons.Get(tdef.rewardWeapon)
					if w and not d.weapons[w.id] then
						d.weapons[w.id] = { lvl = 0 }
						for i = 1, Weapons.MaxSlots do if d.slots[i] == "" then d.slots[i] = w.id; break end end
					end
					Net.VFX:FireClient(player, "banner", { title = "SIEG!", text = tdef.name .. " besiegt – " .. (w and w.name or "") .. " + " .. got .. " G erhalten. Die Wurzelruinen sind geöffnet!" })
					Net.NotifyPlayer(player, tdef.name .. ": \"Starker Kampf! Nimm meinen " .. (w and w.name or "Preis") .. ". Morvath wartet in den Ruinen – sei vorsichtig.\"", "dialog")
					DataService.Sync(player)
					ProgressService.Event(player, "trainer_win")
				end
			end
			return true
		end
	end
	return false
end

------------------------------------------------------------------ Boss
local boss = nil -- aktueller Boss-Record
local BossCfg = Progression.Boss.morvath
local ARENA_R = 47

local function inArena(pos)
	return flat(pos - Worlds.List[1].bossArena).Magnitude <= ARENA_R
end

function ProgressService.SummonBoss(player)
	local d = DataService.Get(player)
	if not d then return end
	if BossCfg.requiresTrainer and not d.trainers[BossCfg.requiresTrainer] then
		Net.NotifyPlayer(player, "Das Siegel hält noch. Besiege zuerst " .. Progression.Trainers[BossCfg.requiresTrainer].name .. ".", "warn")
		return
	end
	if (boss and not boss.removed) or ProgressService._summoning then
		Net.NotifyPlayer(player, "Morvath ist bereits erwacht – hilf im Kampf!", "warn")
		return
	end
	ProgressService._summoning = true
	local center = Worlds.List[1].bossArena
	Net.BroadcastVFX("boss_intro", { pos = center, text = BossCfg.intro })
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = CreatureService.CharRoot(p)
		if hrp and inArena(hrp.Position) then Net.VFX:FireClient(p, "banner", { title = "MORVATH ERWACHT", text = "Achte auf grüne Wurzelbahnen und markierte Einschlagkreise!", boss = true }) end
	end
	task.wait(2.5)
	local rec = CreatureService.Spawn("morvath", { level = 1, position = center + Vector3.new(0, 0, 18), kind = "boss", team = "boss", home = center, yaw = 0 })
	ProgressService._summoning = false
	if not rec then return end
	boss = rec
	rec.phase = 1
	rec.speedMult = 1
	rec.targetFilter = function(t)
		local p = CreatureService.TargetPos(t)
		return p ~= nil and inArena(p)
	end
	rec.model:SetAttribute("Boss", true)
	rec.model:SetAttribute("Phase", 1)
	workspace:SetAttribute("BossActive", rec.id)
	task.spawn(function()
		local empty = 0
		while not rec.removed do
			task.wait(0.3)
			if rec.state == "dead" then break end
			if rec.phase == 1 and rec.hp <= rec.maxHp * BossCfg.phase2At then
				rec.phase = 2
				rec.cdMult = BossCfg.phase2CooldownMult
				rec.windupMult = 0.85
				rec.extraWave = BossCfg.phase2ExtraWave
				rec.speedMult = 1.35
				rec.model:SetAttribute("Phase", 2)
				CreatureService.ResetCooldowns(rec)
				Net.BroadcastVFX("boss_phase", { id = rec.id, pos = rec.root.Position })
				for _, p in ipairs(Players:GetPlayers()) do
					local hrp = CreatureService.CharRoot(p)
					if hrp and inArena(hrp.Position) then Net.VFX:FireClient(p, "banner", { title = "PHASE 2", text = "Morvath rast! Doppelte Wurzelwellen – Angriffe kommen schneller.", boss = true }) end
				end
			end
			local any = false
			for _, p in ipairs(Players:GetPlayers()) do
				local hrp = CreatureService.CharRoot(p)
				if hrp and inArena(hrp.Position) then any = true end
			end
			empty = any and 0 or empty + 0.3
			if empty > 15 then
				Net.NotifyAll("Morvath versinkt wieder im Wurzelgrund…", "info")
				CreatureService.Despawn(rec, true)
				break
			end
		end
		if boss == rec then workspace:SetAttribute("BossActive", nil) end
	end)
end

local function onBossDefeated(rec, contributors)
	local set = {}
	for _, p in ipairs(contributors) do set[p] = true end
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = CreatureService.CharRoot(p)
		if hrp and inArena(hrp.Position) then set[p] = true end
	end
	for player in pairs(set) do
		local d = DataService.Get(player)
		if d then
			local first = not d.bosses.morvath
			d.bosses.morvath = true
			local got = DataService.AddMoney(player, first and BossCfg.rewardMoney or math.floor(BossCfg.rewardMoney * 0.25), true)
			if first and d.worldsUnlocked < BossCfg.unlocksWorld then
				d.worldsUnlocked = BossCfg.unlocksWorld
			end
			local w2 = Worlds.List[BossCfg.unlocksWorld]
			Net.VFX:FireClient(player, "banner", {
				title = "MORVATH BESIEGT!",
				text = "+" .. got .. " G" .. (first and ("   •   Welt " .. BossCfg.unlocksWorld .. " (" .. w2.name .. ") freigeschaltet – erscheint in einem kommenden Update!") or ""),
				boss = true, victory = true,
			})
			ProgressService.Event(player, "boss_win")
			ShopService.RefreshPremium(player)
			DataService.Sync(player)
		end
	end
	workspace:SetAttribute("BossActive", nil)
end

------------------------------------------------------------------ Portal
function ProgressService.Travel(player, worldId)
	local d = DataService.Get(player)
	local w = Worlds.List[worldId]
	if not d or not w then return end
	if d.worldsUnlocked < worldId then
		Net.NotifyPlayer(player, "Welt " .. worldId .. " (" .. w.name .. ") ist gesperrt: " .. (w.unlockRequirement or ""), "warn")
	elseif not w.implemented then
		Net.VFX:FireClient(player, "banner", { title = w.name .. " – freigeschaltet", text = "Diese Welt ist für dich freigeschaltet und erscheint in einem kommenden Update. Danke fürs Spielen!" })
	else
		Net.NotifyPlayer(player, "Reise nach " .. w.name .. " …", "info")
	end
end

------------------------------------------------------------------ Init
function ProgressService.Init()
	CreatureService.Defeated:Connect(function(rec, contributors)
		if rec.kind == "wild" then
			rewardWild(rec, contributors)
		elseif rec.kind == "trainer" then
			onTrainerPalDefeated(rec)
		elseif rec.kind == "boss" then
			onBossDefeated(rec, contributors)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local action = prompt:GetAttribute("Action")
		if action == "ChallengeTrainer" then
			ProgressService.ChallengeTrainer(player, prompt:GetAttribute("TrainerId") or "lyra")
		elseif action == "SummonBoss" then
			ProgressService.SummonBoss(player)
		elseif action == "Travel" then
			ProgressService.Travel(player, prompt:GetAttribute("World") or 2)
		elseif action == "OpenShop" then
			ProgressService.Event(player, "talk_merchant")
		end
	end)

	Net.Handle("SkipTutorial", function(player)
		local d = DataService.Get(player)
		if not d then return false end
		d.tutorial.done = true
		DataService.Sync(player)
		return true
	end)

	-- Wegweiser-Schritt
	task.spawn(function()
		while true do
			task.wait(0.5)
			local sign = CollectionService:GetTagged("TutorialSign")[1]
			if sign then
				local sp = sign:IsA("Model") and sign:GetPivot().Position or sign.Position
				for _, p in ipairs(Players:GetPlayers()) do
					local d = DataService.Get(p)
					if d and not d.tutorial.done and Steps[d.tutorial.step] and Steps[d.tutorial.step].event == "reach_sign" then
						local hrp = CreatureService.CharRoot(p)
						if hrp and flat(hrp.Position - sp).Magnitude < 12 then ProgressService.Event(p, "reach_sign") end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for id, b in pairs(battles) do
			if b.player == player then endBattle(id, nil) end
		end
	end)
end

return ProgressService
