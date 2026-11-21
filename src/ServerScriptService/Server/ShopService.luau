--[[
	ShopService: Gold-Käufe (Waffen, Tuning, Fangkugeln) und Robux-Integration.
	Robux: Nur mit echten IDs aus Config.Shop. Ohne ID wird der Kauf abgelehnt (keine Simulation).
	Boosts: Developer Products über ProcessReceipt (idempotent über PurchaseId).
	Premium-Pal: Game Pass; es existiert immer genau ein Premium-Pal (höchste freigeschaltete Welt).
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Weapons = require(Shared.Config.Weapons)
local Spheres = require(Shared.Config.Spheres)
local Shop = require(Shared.Config.Shop)
local Pals = require(Shared.Config.Pals)
local Worlds = require(Shared.Config.Worlds)
local Formulas = require(Shared.Formulas)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)

local ShopService = {}
ShopService.Progress = nil

local function purchased(player)
	if ShopService.Progress then ShopService.Progress.Event(player, "purchase") end
end

-- Premium ------------------------------------------------------------
function ShopService.RefreshPremium(player)
	local d = DataService.Get(player)
	if not d or not d.premium then return end
	-- höchste freigeschaltete Welt, für die ein Premium-Pal umgesetzt ist
	local species, worldOf = nil, nil
	for w = math.min(d.worldsUnlocked, Worlds.MaxDefined), 1, -1 do
		local id = Shop.Premium.perWorld[w]
		if id and Pals.Get(id) then species, worldOf = id, w; break end
	end
	if not species then return end
	local existing = nil
	for uid, p in pairs(d.pals) do
		if p.premium then
			if existing then d.pals[uid] = nil else existing = p end -- niemals stapeln
		end
	end
	if not existing then
		DataService.AddPal(player, species, 5, true)
		Net.NotifyPlayer(player, "Premium-Pal freigeschaltet: " .. Pals.Get(species).name .. "!", "premium")
	elseif existing.species ~= species then
		local old = Pals.Get(existing.species)
		existing.species = species
		Net.NotifyPlayer(player, "Dein Premium-Pal wurde aufgewertet: " .. (old and old.name or "?") .. " -> " .. Pals.Get(species).name, "premium")
	end
	if d.worldsUnlocked > worldOf then
		Net.NotifyPlayer(player, "Die Premium-Variante für Welt " .. d.worldsUnlocked .. " ist vorbereitet und folgt mit dem Welt-Update.", "info")
	end
	-- Team bereinigen (entfernte Einträge)
	local team = {}
	for _, uid in ipairs(d.team) do if d.pals[uid] then table.insert(team, uid) end end
	d.team = team
	DataService.Sync(player)
end

local function checkPremiumOwnership(player)
	if not Shop.PremiumConfigured() then return end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Shop.Premium.gamePassId)
	end)
	if not ok then
		warn("[ShopService] Game-Pass-Prüfung fehlgeschlagen: " .. tostring(owns))
		return
	end
	local d = DataService.Get(player)
	if d and owns and not d.premium then
		d.premium = true
	end
	if d and owns then ShopService.RefreshPremium(player) end
end
ShopService.CheckPremium = checkPremiumOwnership

-- Boosts --------------------------------------------------------------
local function grantBoost(player, boostId, receiptId)
	local d = DataService.Get(player)
	if not d then return false end
	if receiptId and d.receipts[receiptId] then return true end
	local now = os.time()
	local cur = math.max(now, d.boosts[boostId] or 0)
	d.boosts[boostId] = math.min(cur + Shop.BoostDuration(boostId), now + Shop.MaxBoostStackSeconds)
	if receiptId then
		d.receipts[receiptId] = now
		-- alte Belege begrenzen
		local n = 0
		for _ in pairs(d.receipts) do n += 1 end
		if n > 60 then
			local oldestK, oldestT = nil, math.huge
			for k, t in pairs(d.receipts) do if t < oldestT then oldestK, oldestT = k, t end end
			if oldestK then d.receipts[oldestK] = nil end
		end
	end
	DataService.Sync(player)
	Net.NotifyPlayer(player, Shop.Boosts[boostId].name .. " aktiv für " .. Formulas.FormatTime(d.boosts[boostId] - now) .. "!", "premium")
	return true
end

local function boostByProduct(productId)
	for id, b in pairs(Shop.Boosts) do
		if b.productId == productId then return id end
	end
	return nil
end

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or not DataService.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local boostId = boostByProduct(info.ProductId)
	if not boostId then
		warn("[ShopService] Unbekannte Produkt-ID: " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = grantBoost(player, boostId, tostring(info.PurchaseId))
	if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
	DataService.Save(player, DataService.Get(player))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if wasPurchased and Shop.PremiumConfigured() and passId == Shop.Premium.gamePassId then
		checkPremiumOwnership(player)
	end
end)

-- Handler --------------------------------------------------------------
function ShopService.Init()
	Net.Handle("BuyWeapon", function(player, id)
		local d = DataService.Get(player)
		local w = type(id) == "string" and Weapons.Get(id)
		if not d or not w then return false, "Unbekannte Waffe" end
		if d.weapons[id] then return false, "Bereits im Besitz" end
		if w.price == nil then return false, "Nicht käuflich – " .. (w.rewardFrom and ("Belohnung von " .. w.rewardFrom) or "Belohnung") end
		if not DataService.TrySpend(player, w.price) then return false, "Nicht genug Gold (" .. Formulas.FormatMoney(w.price) .. ")" end
		d.weapons[id] = { lvl = 0 }
		for i = 1, Weapons.MaxSlots do
			if d.slots[i] == "" then d.slots[i] = id; break end
		end
		DataService.Sync(player)
		purchased(player)
		return true, w.name .. " gekauft!"
	end)

	Net.Handle("UpgradeWeapon", function(player, id)
		local d = DataService.Get(player)
		local w = type(id) == "string" and Weapons.Get(id)
		if not d or not w or not d.weapons[id] then return false, "Waffe nicht im Besitz" end
		local lvl = d.weapons[id].lvl or 0
		if lvl >= Weapons.MaxUpgrade then return false, "Maximale Stufe erreicht" end
		local cost = w.upgradeCosts[lvl + 1]
		if not DataService.TrySpend(player, cost) then return false, "Nicht genug Gold (" .. Formulas.FormatMoney(cost) .. ")" end
		d.weapons[id].lvl = lvl + 1
		DataService.Sync(player)
		purchased(player)
		return true, w.name .. " auf Tuning-Stufe " .. (lvl + 1) .. " verbessert (+" .. math.floor(Weapons.UpgradeBonusPerLevel * 100) .. " % Schaden)"
	end)

	Net.Handle("BuyBall", function(player, tier)
		local d = DataService.Get(player)
		if not d or type(tier) ~= "number" then return false, "Ungültig" end
		local t = Spheres.Get(tier)
		if not t then return false, "Unbekannte Stufe" end
		if tier <= d.ballTier then return false, "Bereits freigeschaltet" end
		if tier ~= d.ballTier + 1 then return false, "Schalte zuerst Stufe " .. (d.ballTier + 1) .. " frei" end
		if not DataService.TrySpend(player, t.price) then return false, "Nicht genug Gold (" .. Formulas.FormatMoney(t.price) .. ")" end
		d.ballTier = tier
		DataService.Sync(player)
		purchased(player)
		return true, t.name .. " freigeschaltet! (×" .. t.mult .. " Fangchance)"
	end)

	Net.Handle("BuyBoost", function(player, boostId)
		local b = type(boostId) == "string" and Shop.Boosts[boostId]
		if not b then return false, "Unbekanntes Angebot" end
		if not Shop.IsConfigured(boostId) then
			return false, "Dieses Robux-Angebot ist noch nicht konfiguriert (Developer-Product-ID fehlt). Es wurde nichts gekauft."
		end
		MarketplaceService:PromptProductPurchase(player, b.productId)
		return true, "Roblox-Kaufdialog geöffnet"
	end)

	Net.Handle("BuyPremium", function(player)
		local d = DataService.Get(player)
		if not d then return false end
		if d.premium then return false, "Premium-Pal bereits freigeschaltet" end
		if not Shop.PremiumConfigured() then
			return false, "Das Premium-Angebot ist noch nicht konfiguriert (Game-Pass-ID fehlt). Es wurde nichts gekauft."
		end
		MarketplaceService:PromptGamePassPurchase(player, Shop.Premium.gamePassId)
		return true, "Roblox-Kaufdialog geöffnet"
	end)
end

return ShopService
