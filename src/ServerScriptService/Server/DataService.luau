--[[
	DataService: Spielerprofile (Geld, Waffen, Pals, Team, Katalog, Fortschritt, Boosts).
	Speichert per DataStore. Ohne API-Zugriff (z. B. Studio) läuft eine Sitzung ohne Speicherung – mit Hinweis.
	Nur der Server verändert Profile. Clients bekommen Schnappschüsse (StateSync).
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Weapons = require(Config.Weapons)
local Pals = require(Config.Pals)
local Shop = require(Config.Shop)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(script.Parent.Net)

local DataService = {}
DataService.Profiles = {}
DataService.Changed = Instance.new("BindableEvent")

local STORE_NAME = "ParlworldProfiles_v1"
local store = nil
local storeOk = false
do
	local ok, res = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = res; storeOk = true end
end

DataService.MaxPals = 80
DataService.MaxTeam = 3

local function newProfile()
	return {
		v = 1,
		money = 0,
		weapons = { [Weapons.StarterWeapon] = { lvl = 0 } },
		slots = { Weapons.StarterWeapon, "", "" },
		equippedSlot = 1,
		ballTier = 1,
		pals = {},
		nextUid = 1,
		team = {},
		activeIndex = 1,
		dex = {},
		tutorial = { step = 1, counter = 0, done = false },
		trainers = {},
		bosses = {},
		worldsUnlocked = 1,
		boosts = {},
		premium = false,
		receipts = {},
		stats = { defeated = 0, caught = 0 },
	}
end

local function reconcile(data)
	local base = newProfile()
	for k, v in pairs(base) do
		if data[k] == nil then data[k] = v end
	end
	if type(data.slots) ~= "table" then data.slots = base.slots end
	for i = 1, Weapons.MaxSlots do data.slots[i] = data.slots[i] or "" end
	-- Pal-Tabelle: Schlüssel sind Strings (DataStore-JSON)
	local pals = {}
	for _, p in pairs(data.pals) do
		if type(p) == "table" and p.uid and Pals.Get(p.species) then pals[tostring(p.uid)] = p end
	end
	data.pals = pals
	local team = {}
	for _, uid in ipairs(data.team) do
		if pals[tostring(uid)] and #team < DataService.MaxTeam then table.insert(team, tostring(uid)) end
	end
	data.team = team
	return data
end

function DataService.Get(player)
	return DataService.Profiles[player]
end

local pendingSync = {}
function DataService.Sync(player)
	pendingSync[player] = true
end

function DataService.Snapshot(player)
	local d = DataService.Profiles[player]
	if not d then return nil end
	local now = os.time()
	local boosts = {}
	for id, exp in pairs(d.boosts) do
		if exp > now then boosts[id] = exp - now end
	end
	local pals = {}
	for uid, p in pairs(d.pals) do
		pals[uid] = { uid = uid, species = p.species, level = p.level, xp = p.xp, xpNext = Formulas.XpForLevel(p.level), premium = p.premium, fainted = p.faintedUntil and p.faintedUntil > now and (p.faintedUntil - now) or nil }
	end
	return {
		money = d.money, weapons = d.weapons, slots = d.slots, equippedSlot = d.equippedSlot, ballTier = d.ballTier,
		pals = pals, team = d.team, activeIndex = d.activeIndex, dex = d.dex, tutorial = d.tutorial,
		trainers = d.trainers, bosses = d.bosses, worldsUnlocked = d.worldsUnlocked, boosts = boosts,
		premium = d.premium, stats = d.stats, saving = storeOk and not d._noSave,
	}
end

RunService.Heartbeat:Connect(function()
	if next(pendingSync) == nil then return end
	for player in pairs(pendingSync) do
		pendingSync[player] = nil
		if player.Parent and DataService.Profiles[player] then
			Net.StateSync:FireClient(player, DataService.Snapshot(player))
		end
	end
end)

-- Geld ------------------------------------------------------------
function DataService.BoostActive(player, id)
	local d = DataService.Profiles[player]
	return d ~= nil and (d.boosts[id] or 0) > os.time()
end

function DataService.BoostMult(player, id)
	if DataService.BoostActive(player, id) then return Shop.Boosts[id].multiplier end
	return 1
end

-- amount > 0: Belohnung (Geld-Boost wird angewendet, wenn applyBoost)
function DataService.AddMoney(player, amount, applyBoost)
	local d = DataService.Profiles[player]
	if not d then return 0 end
	local a = math.floor(amount * (applyBoost and DataService.BoostMult(player, "money") or 1) + 0.5)
	d.money += a
	DataService.Sync(player)
	return a
end

function DataService.TrySpend(player, amount)
	local d = DataService.Profiles[player]
	if not d or amount < 0 or d.money < amount then return false end
	d.money -= amount
	DataService.Sync(player)
	return true
end

-- Katalog ---------------------------------------------------------
function DataService.Discover(player, species)
	local d = DataService.Profiles[player]
	if not d then return end
	local e = d.dex[species]
	if not e then
		d.dex[species] = { seen = true, caught = 0 }
		DataService.Sync(player)
		local def = Pals.Get(species)
		if def then Net.NotifyPlayer(player, "Neu im Katalog entdeckt: " .. def.name, "discover") end
	end
end

-- Pals ------------------------------------------------------------
function DataService.PalCount(player)
	local d = DataService.Profiles[player]
	local n = 0
	if d then for _ in pairs(d.pals) do n += 1 end end
	return n
end

function DataService.AddPal(player, species, level, isPremium)
	local d = DataService.Profiles[player]
	if not d then return nil end
	local uid = tostring(d.nextUid)
	d.nextUid += 1
	d.pals[uid] = { uid = uid, species = species, level = level or 1, xp = 0, premium = isPremium or nil }
	if not isPremium then
		local e = d.dex[species] or { seen = true, caught = 0 }
		e.seen = true
		e.caught = (e.caught or 0) + 1
		d.dex[species] = e
		d.stats.caught += 1
	end
	if #d.team < DataService.MaxTeam then table.insert(d.team, uid) end
	DataService.Sync(player)
	DataService.Changed:Fire(player, "pals")
	return uid
end

function DataService.GivePalXp(player, uid, amount)
	local d = DataService.Profiles[player]
	local p = d and d.pals[uid]
	if not p then return end
	p.xp += amount
	local leveled = false
	while p.level < Formulas.MaxLevel and p.xp >= Formulas.XpForLevel(p.level) do
		p.xp -= Formulas.XpForLevel(p.level)
		p.level += 1
		leveled = true
	end
	if leveled then
		local def = Pals.Get(p.species)
		Net.NotifyPlayer(player, (def and def.name or "Pal") .. " ist jetzt Level " .. p.level .. "!", "level")
	end
	DataService.Sync(player)
	return leveled
end

-- Laden / Speichern -----------------------------------------------
local function key(player) return "u_" .. player.UserId end

local function load(player)
	local data, noSave = nil, false
	if storeOk then
		local ok, res = false, nil
		for attempt = 1, 3 do
			ok, res = pcall(function() return store:GetAsync(key(player)) end)
			if ok then break end
			task.wait(1)
		end
		if ok then
			data = res
		else
			warn("[DataService] Laden fehlgeschlagen für " .. player.Name .. ": " .. tostring(res))
			noSave = true
		end
	else
		noSave = true
	end
	if type(data) ~= "table" then data = newProfile() end
	data = reconcile(data)
	data._noSave = noSave
	return data
end

local function save(player, data)
	if not storeOk or data._noSave then return end
	local copy = table.clone(data)
	copy._noSave = nil
	-- temporäre Felder nicht speichern
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function() return copy end)
	end)
	if not ok then warn("[DataService] Speichern fehlgeschlagen für " .. player.Name .. ": " .. tostring(err)) end
end
DataService.Save = save

function DataService.OnPlayerAdded(player)
	local data = load(player)
	if not player.Parent then return nil end
	DataService.Profiles[player] = data
	DataService.Sync(player)
	if data._noSave then
		task.delay(4, function()
			Net.NotifyPlayer(player, "Hinweis: Speichern ist in dieser Sitzung deaktiviert (kein DataStore-Zugriff, z. B. Studio ohne API-Freigabe).", "warn")
		end)
	end
	return data
end

function DataService.OnPlayerRemoving(player)
	local data = DataService.Profiles[player]
	if data then save(player, data) end
	DataService.Profiles[player] = nil
	pendingSync[player] = nil
end

task.spawn(function()
	while true do
		task.wait(120)
		for player, data in pairs(DataService.Profiles) do
			task.spawn(save, player, data)
		end
	end
end)

game:BindToClose(function()
	for player, data in pairs(DataService.Profiles) do
		save(player, data)
	end
end)

return DataService
