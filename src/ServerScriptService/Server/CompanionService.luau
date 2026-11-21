--[[
	CompanionService: aktives Team, Beschwören/Zurückrufen, Begleiter-KI und Reiten.
	Beim Reiten erhält der Reiter die Netzwerk-Hoheit über das Reittier (flüssige Steuerung),
	der Server prüft Grenzen und räumt bei Tod/Verlassen zuverlässig auf.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Pals = require(Shared.Config.Pals)
local Attacks = require(Shared.Config.Attacks)
local Formulas = require(Shared.Formulas)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)
local CombatService = require(script.Parent.CombatService)

local CompanionService = {}
CompanionService.Progress = nil
local active = {} -- [player] = rec
CompanionService.Active = active

local FAINT_SECONDS = 20
local SUMMON_COOLDOWN = 1.0
local lastSummon = {}

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function ownerRoot(player)
	return CreatureService.CharRoot(player)
end

-- Begleiter-KI
local function think(rec, dt, now)
	local player = rec.owner
	local hrp = ownerRoot(player)
	if not hrp then return end
	local opos = hrp.Position
	local dOwner = flat(opos - rec.pos).Magnitude
	if dOwner > 75 then
		-- zu weit weg: neben den Spieler teleportieren
		local p = opos - hrp.CFrame.LookVector * 5
		local gy = CreatureService.GroundY(p.X, p.Z, p.Y + 20) or p.Y
		rec.pos = Vector3.new(p.X, gy, p.Z)
		rec.root.CFrame = CFrame.new(rec.pos + Vector3.new(0, rec.rootH + rec.hover, 0))
		CreatureService.SetRootTarget(rec)
		rec.target = nil
		return
	end
	if rec.busy then return end

	-- Ziel wählen: Ziel des Spielers > Feinde, die Spieler/Begleiter angreifen
	local t = rec.target
	if t and (not CreatureService.TargetPos(t) or flat(CreatureService.TargetPos(t) - opos).Magnitude > 55) then t = nil end
	if not t then
		local lt = CombatService.LastTarget(player)
		if lt and CreatureService.TargetPos(lt) and lt.team ~= "player" then t = lt end
	end
	if not t then
		local best, bestD = nil, 40
		for _, other in pairs(CreatureService.Records) do
			if other.team ~= "player" and (other.target == player or other.target == rec) and CreatureService.TargetPos(other) then
				local dd = (other.root.Position - opos).Magnitude
				if dd < bestD then best, bestD = other, dd end
			end
		end
		t = best
	end
	rec.target = t

	local speed = rec.def.speed * 1.25
	if t then
		local tp = CreatureService.TargetPos(t)
		local dist = flat(tp - rec.pos).Magnitude
		local ready = {}
		for _, aid in ipairs(rec.def.attacks) do
			if (rec.cd[aid] or 0) <= now and dist <= Attacks[aid].range then table.insert(ready, aid) end
		end
		if #ready > 0 then
			CreatureService.StartAttack(rec, ready[math.random(1, #ready)], t)
			return
		end
		CreatureService.SetState(rec, "chase")
		if dist > rec.radius + t.radius + 2 then CreatureService.StepMove(rec, tp, speed, dt) end
		return
	end

	-- folgen (hinten rechts)
	local right = hrp.CFrame.RightVector
	local goal = opos - hrp.CFrame.LookVector * 4 + right * (3 + rec.radius)
	if flat(goal - rec.pos).Magnitude > 3 then
		CreatureService.SetState(rec, "move")
		CreatureService.StepMove(rec, goal, dOwner > 18 and speed * 1.6 or speed, dt)
	else
		CreatureService.SetState(rec, "idle")
	end
end

local function dismount(player, rec)
	rec = rec or active[player]
	if not rec or not rec.ridden then return end
	rec.ridden = false
	rec.rider = nil
	rec.model:SetAttribute("Rider", nil)
	local seat = rec.seat
	rec.seat = nil
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Sit = false end
	if seat then
		local w = seat:FindFirstChild("SeatWeld")
		if w then w:Destroy() end
		seat:Destroy()
	end
	if rec.model.Parent then
		pcall(function() rec.root:SetNetworkOwner(nil) end)
		local p = rec.root.Position
		local gy = CreatureService.GroundY(p.X, p.Z, p.Y + 5) or (p.Y - rec.rootH)
		rec.pos = Vector3.new(p.X, gy, p.Z)
		local look = rec.root.CFrame.LookVector
		rec.yaw = math.atan2(-look.X, -look.Z)
		rec.ao.CFrame = CFrame.Angles(0, rec.yaw, 0)
		CreatureService.SetRootTarget(rec)
		CreatureService.SetState(rec, "idle")
	end
	-- Spieler etwas neben dem Reittier absetzen
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and rec.model.Parent then
		task.defer(function()
			if hrp.Parent then
				local side = rec.root.CFrame.RightVector * (rec.radius + 2.5)
				local p = rec.root.Position + side
				local gy = CreatureService.GroundY(p.X, p.Z, p.Y + 10) or p.Y
				hrp.CFrame = CFrame.new(Vector3.new(p.X, gy + 3.5, p.Z)) * (hrp.CFrame - hrp.CFrame.Position)
			end
		end)
	end
end
CompanionService.Dismount = dismount

function CompanionService.Recall(player, silent)
	local rec = active[player]
	if not rec then return end
	if rec.ridden then dismount(player, rec) end
	active[player] = nil
	if not rec.removed then
		Net.BroadcastVFX("recall", { id = rec.id, pos = rec.root.Position, owner = player.UserId })
		CreatureService.Despawn(rec, true)
	end
	if not silent then DataService.Sync(player) end
end

local function onFaint(rec)
	local player = rec.owner
	local d = player and DataService.Get(player)
	if d and d.pals[rec.palUid] then
		d.pals[rec.palUid].faintedUntil = os.time() + FAINT_SECONDS
		Net.NotifyPlayer(player, rec.def.name .. " ist erschöpft und braucht " .. FAINT_SECONDS .. " s Pause.", "warn")
	end
	if active[player] == rec then
		if rec.ridden then dismount(player, rec) end
		active[player] = nil
	end
	Net.BroadcastVFX("recall", { id = rec.id, pos = rec.root.Position, owner = player and player.UserId })
	CreatureService.Despawn(rec, true)
	if player then DataService.Sync(player) end
end

function CompanionService.Summon(player)
	local d = DataService.Get(player)
	if not d then return false, "Profil lädt noch" end
	if lastSummon[player] and os.clock() - lastSummon[player] < SUMMON_COOLDOWN then return false, "Kurz warten" end
	lastSummon[player] = os.clock()
	if active[player] then
		CompanionService.Recall(player)
		return true, "recalled"
	end
	if #d.team == 0 then return false, "Dein Team ist leer – fange einen Pal und setze ihn im Ausrüstungsmenü (Tab) ins Team." end
	d.activeIndex = math.clamp(d.activeIndex, 1, #d.team)
	local uid = d.team[d.activeIndex]
	local pal = d.pals[uid]
	if not pal then return false, "Pal nicht gefunden" end
	if pal.faintedUntil and pal.faintedUntil > os.time() then
		return false, Pals.Get(pal.species).name .. " ist noch erschöpft (" .. (pal.faintedUntil - os.time()) .. " s)."
	end
	local hrp = ownerRoot(player)
	if not hrp then return false, "Nicht möglich" end
	local p = hrp.Position + hrp.CFrame.LookVector * 6
	local rec = CreatureService.Spawn(pal.species, {
		level = pal.level, position = p, kind = "companion", team = "player", owner = player,
		yaw = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z),
	})
	if not rec then return false, "Beschwören fehlgeschlagen" end
	rec.think = think
	rec.onFaint = onFaint
	rec.palUid = uid
	rec.model:SetAttribute("PalUid", uid)
	rec.model:SetAttribute("OwnerName", player.DisplayName)
	active[player] = rec
	Net.BroadcastVFX("summon", { id = rec.id, pos = rec.root.Position, owner = player.UserId, from = hrp.Position })
	if CompanionService.Progress then CompanionService.Progress.Event(player, "summon") end
	DataService.Sync(player)
	return true, "summoned"
end

function CompanionService.Cycle(player)
	local d = DataService.Get(player)
	if not d or #d.team == 0 then return false, "Team ist leer" end
	d.activeIndex = (d.activeIndex % #d.team) + 1
	local had = active[player] ~= nil
	if had then
		CompanionService.Recall(player, true)
		lastSummon[player] = 0
		CompanionService.Summon(player)
	end
	DataService.Sync(player)
	return true
end

function CompanionService.Mount(player)
	local rec = active[player]
	if not rec then return false, "Rufe zuerst einen reitbaren Pal (Q)." end
	if rec.ridden then dismount(player, rec); return true, "dismounted" end
	local ride = rec.def.ride
	if not ride then return false, rec.def.name .. " ist nicht reitbar." end
	local hrp, hum = ownerRoot(player)
	if not hrp then return false end
	if (hrp.Position - rec.root.Position).Magnitude > 16 + rec.radius then return false, "Geh näher an " .. rec.def.name .. " heran." end
	if rec.busy then return false, "Warte, bis der Angriff vorbei ist." end
	rec.target = nil
	local seat = Instance.new("Seat")
	seat.Name = "RideSeat"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Massless = true
	seat.CFrame = rec.root.CFrame * CFrame.new(0, ride.seatHeight - rec.rootH - 0.4, 0.2)
	seat.Parent = rec.model
	local w = Instance.new("WeldConstraint")
	w.Part0 = rec.root
	w.Part1 = seat
	w.Parent = seat
	rec.seat = seat
	rec.ridden = true
	rec.rider = player
	CreatureService.SetState(rec, "ridden")
	rec.model:SetAttribute("Rider", player.UserId)
	rec.model:SetAttribute("RideMode", ride.mode)
	rec.model:SetAttribute("RideSpeed", ride.speed)
	seat:Sit(hum)
	pcall(function() rec.root:SetNetworkOwner(player) end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil and rec.ridden and rec.seat == seat then
			dismount(player, rec)
		end
	end)
	if CompanionService.Progress then CompanionService.Progress.Event(player, "mount") end
	return true, "mounted"
end

function CompanionService.Init()
	Net.Handle("Summon", CompanionService.Summon)
	Net.Handle("CycleTeam", CompanionService.Cycle)
	Net.Handle("Mount", CompanionService.Mount)
	Net.Handle("SetActiveIndex", function(player, idx)
		local d = DataService.Get(player)
		if not d or type(idx) ~= "number" or idx < 1 or idx > #d.team then return false end
		d.activeIndex = math.floor(idx)
		if active[player] then
			CompanionService.Recall(player, true)
			lastSummon[player] = 0
			CompanionService.Summon(player)
		end
		DataService.Sync(player)
		return true
	end)
	Net.Handle("SetTeam", function(player, list)
		local d = DataService.Get(player)
		if not d or type(list) ~= "table" then return false, "Ungültig" end
		local team, seen = {}, {}
		for _, uid in ipairs(list) do
			uid = tostring(uid)
			if d.pals[uid] and not seen[uid] then
				seen[uid] = true
				table.insert(team, uid)
			end
			if #team >= DataService.MaxTeam then break end
		end
		local activeRec = active[player]
		d.team = team
		d.activeIndex = math.clamp(d.activeIndex, 1, math.max(1, #team))
		if activeRec and not seen[activeRec.palUid] then CompanionService.Recall(player, true) end
		if activeRec and seen[activeRec.palUid] then
			for i, uid in ipairs(team) do if uid == activeRec.palUid then d.activeIndex = i end end
		end
		DataService.Sync(player)
		if #team > 0 and CompanionService.Progress then CompanionService.Progress.Event(player, "team_set") end
		return true
	end)

	local function cleanup(player)
		if active[player] then CompanionService.Recall(player, true) end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function() cleanup(player) end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterRemoving:Connect(function() cleanup(player) end)
	end
	Players.PlayerRemoving:Connect(function(player)
		cleanup(player)
		lastSummon[player] = nil
	end)

	-- Sicherheitsprüfung für Reittiere (Weltgrenzen, Reiter noch vorhanden)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, rec in pairs(active) do
				if rec.ridden then
					local p = rec.root.Position
					local hrp, hum = ownerRoot(player)
					if not hum or hum.SeatPart ~= rec.seat or math.abs(p.X) > 650 or math.abs(p.Z) > 650 or p.Y > 320 or p.Y < -30 then
						dismount(player, rec)
						if p.Y < -30 or math.abs(p.X) > 650 or math.abs(p.Z) > 650 then
							local gy = CreatureService.GroundY(0, 20) or 16
							rec.pos = Vector3.new(0, gy, 20)
							rec.root.CFrame = CFrame.new(rec.pos + Vector3.new(0, rec.rootH, 0))
							CreatureService.SetRootTarget(rec)
						end
					end
				end
			end
		end
	end)
end

-- XP für den aktiven Begleiter eines Spielers
function CompanionService.GiveXp(player, amount)
	local rec = active[player]
	if not rec or not rec.palUid then return end
	local leveled = DataService.GivePalXp(player, rec.palUid, amount)
	if leveled then
		local d = DataService.Get(player)
		local pal = d and d.pals[rec.palUid]
		if pal then
			local newMax = Formulas.MaxHp(pal.species, pal.level)
			local frac = rec.hp / rec.maxHp
			rec.level = pal.level
			rec.maxHp = newMax
			rec.hp = newMax * frac
			rec.model:SetAttribute("Level", pal.level)
			rec.model:SetAttribute("MaxHp", newMax)
			rec.model:SetAttribute("Hp", math.ceil(rec.hp))
		end
	end
end

return CompanionService
