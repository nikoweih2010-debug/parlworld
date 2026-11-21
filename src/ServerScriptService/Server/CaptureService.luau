--[[
	CaptureService: Fangkugel-Würfe. Der Server simuliert die Flugbahn, prüft Treffer,
	würfelt die Fangchance (Formulas.CatchChance) und vergibt den Pal.
	Fangen ist nur bei besiegten (geschwächten) wilden Kreaturen möglich.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Spheres = require(Shared.Config.Spheres)
local Shop = require(Shared.Config.Shop)
local Formulas = require(Shared.Formulas)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)

local CaptureService = {}
CaptureService.Progress = nil

local lastThrow = {}
local lastHint = {}
local nextBall = 1
local GRAVITY = 70

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function refresh()
	local list = { workspace.Terrain }
	for _, i in ipairs(CollectionService:GetTagged("Ground")) do table.insert(list, i) end
	local world = workspace:FindFirstChild("World")
	if world then
		for _, n in ipairs({ "Rocks", "BaseCamp", "AncientRuins" }) do
			local f = world:FindFirstChild(n)
			if f then table.insert(list, f) end
		end
	end
	groundParams.FilterDescendantsInstances = list
end
refresh()
CollectionService:GetInstanceAddedSignal("Ground"):Connect(refresh)

local function hint(player, text)
	local t = lastHint[player]
	if t and os.clock() - t < 2.5 then return end
	lastHint[player] = os.clock()
	Net.NotifyPlayer(player, text, "warn")
end

local function tryCapture(player, rec, bid, tier)
	local d = DataService.Get(player)
	if not d then return end
	if DataService.PalCount(player) >= DataService.MaxPals then
		Net.NotifyPlayer(player, "Dein Pal-Speicher ist voll (" .. DataService.MaxPals .. ").", "warn")
		return "bounce"
	end
	local luck = DataService.BoostMult(player, "luck")
	local chance = Formulas.CatchChance(rec.def.id, rec.level, tier, luck)
	local success = math.random() < chance
	local shakes = success and 3 or math.clamp(1 + math.floor(chance * 3 + math.random()), 1, 3)
	CreatureService.SetState(rec, "capturing")
	rec.model:SetAttribute("Catchable", false)
	local pos = rec.root.Position
	Net.BroadcastVFX("capture_start", { bid = bid, id = rec.id, pos = pos, tier = tier, shakes = shakes, success = success })

	task.spawn(function()
		task.wait(0.45 + shakes * Spheres.ShakeTime)
		if rec.removed then return end
		if not player.Parent then
			-- Spieler hat das Spiel verlassen: Kreatur bleibt geschwächt liegen
			CreatureService.SetState(rec, "downed")
			rec.model:SetAttribute("Catchable", true)
			Net.BroadcastVFX("capture_result", { bid = bid, id = rec.id, pos = pos, success = false, silent = true })
			return
		end
		Net.BroadcastVFX("capture_result", { bid = bid, id = rec.id, pos = pos, success = success, tier = tier })
		local pct = math.floor(chance * 100 + 0.5)
		if success then
			local uid = DataService.AddPal(player, rec.def.id, rec.level, false)
			CreatureService.Despawn(rec, false)
			Net.NotifyPlayer(player, "Gefangen: " .. rec.def.name .. " (Lv " .. rec.level .. ")!  Chance war " .. pct .. " %", "catch")
			if CaptureService.Progress then CaptureService.Progress.Event(player, "catch_any") end
		else
			CreatureService.Recover(rec, Spheres.FailRecoverHpFraction, player)
			Net.NotifyPlayer(player, rec.def.name .. " ist ausgebrochen! (Chance war " .. pct .. " %) – schwäche es erneut.", "warn")
		end
	end)
	return "capture"
end

local function simulate(player, origin, vel, tier)
	local bid = nextBall
	nextBall += 1
	Net.BroadcastVFX("ball", { bid = bid, uid = player.UserId, from = origin, vel = vel, g = GRAVITY, tier = tier, t0 = workspace:GetServerTimeNow() })
	local pos = origin
	local t = 0
	local result, endPos = "miss", nil
	while t < 3 do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		local np = origin + vel * t + Vector3.new(0, -0.5 * GRAVITY * t * t, 0)
		-- Kreaturentreffer
		local hitRec = nil
		for _, rec in pairs(CreatureService.Records) do
			if rec.team ~= "player" and not rec.removed then
				local c = rec.root.Position
				local seg = np - pos
				local len = seg.Magnitude
				local proj = len > 0 and math.clamp((c - pos):Dot(seg / len), 0, len) or 0
				local closest = pos + (len > 0 and seg / len * proj or Vector3.zero)
				if (c - closest).Magnitude <= rec.radius + 1.2 then hitRec = rec; endPos = closest; break end
			end
		end
		if hitRec then
			if hitRec.state == "downed" and hitRec.model:GetAttribute("Catchable") then
				result = tryCapture(player, hitRec, bid, tier)
			elseif hitRec.state == "capturing" then
				result = "bounce"
			elseif hitRec.kind ~= "wild" or hitRec.def.catchable == false then
				result = "bounce"
				hint(player, hitRec.def.name .. " kann nicht gefangen werden.")
			else
				result = "bounce"
				hint(player, "Noch zu stark! Besiege " .. hitRec.def.name .. " zuerst – nur geschwächte Pals lassen sich fangen.")
			end
			break
		end
		local ray = workspace:Raycast(pos, np - pos, groundParams)
		if ray then endPos = ray.Position; result = "miss"; break end
		pos = np
	end
	if result ~= "capture" then
		Net.BroadcastVFX("ball_end", { bid = bid, pos = endPos or pos, result = result })
	end
end

function CaptureService.Init()
	Net.ThrowBall.OnServerEvent:Connect(function(player, origin, dir)
		if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or dir.Magnitude < 0.5 then return end
		local d = DataService.Get(player)
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not d or not head or not hum or hum.Health <= 0 then return end
		if (origin - head.Position).Magnitude > 10 then return end
		local now = os.clock()
		if lastThrow[player] and now - lastThrow[player] < Spheres.ThrowCooldown * 0.9 then return end
		lastThrow[player] = now
		local vel = dir.Unit * Spheres.ThrowSpeed + Vector3.new(0, 10, 0)
		task.spawn(simulate, player, origin, vel, d.ballTier)
	end)

	-- Anzeige-Hilfe: aktuelle Fangchance für eine Kreatur (Client zeigt sie an; Server-Wert ist verbindlich)
	Net.Handle("CatchChance", function(player, creatureId)
		local rec = CreatureService.ById[creatureId]
		local d = DataService.Get(player)
		if not rec or not d then return false end
		return true, Formulas.CatchChance(rec.def.id, rec.level, d.ballTier, DataService.BoostMult(player, "luck"))
	end)

	Players.PlayerRemoving:Connect(function(p) lastThrow[p] = nil; lastHint[p] = nil end)
end

return CaptureService
