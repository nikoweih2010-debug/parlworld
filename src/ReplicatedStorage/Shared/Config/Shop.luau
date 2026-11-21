--[[
	Shop & Robux-Angebote (zentral).

	!!! INTEGRATIONSPUNKT ROBUX !!!
	Echte IDs müssen hier eingetragen werden (Creator Dashboard -> Monetarisierung):
	  - Boosts: Developer Products (mehrfach kaufbar) -> productId
	  - Premium-Pal: Game Pass (einmalig) -> gamePassId
	Solange eine ID nil ist, zeigt der Shop "Nicht konfiguriert" und der Server lehnt den Kauf ab.
	Es wird NIE ein Kauf simuliert.
]]
local Shop = {}

-- Vorläufiger Standard: 30 Minuten Echtzeit pro Kauf. Mehrfachkäufe verlängern die Laufzeit.
-- Zentral änderbar – gilt für alle Boosts, sofern ein Boost keine eigene duration setzt.
Shop.DefaultBoostDurationSeconds = 30 * 60
Shop.MaxBoostStackSeconds = 6 * 60 * 60

Shop.Boosts = {
	luck = {
		id = "luck", name = "2× Luck", robux = 300, productId = nil, duration = nil,
		multiplier = 2,
		desc = "Verdoppelt deine Fangchance (vor der Obergrenze von 95 %). Beispiel: 30 % → 60 %.",
		color = Color3.fromRGB(120, 255, 140),
	},
	damage = {
		id = "damage", name = "2× Damage", robux = 300, productId = nil, duration = nil,
		multiplier = 2,
		desc = "Verdoppelt den Schaden deiner Waffen und deiner Team-Pals gegen Kreaturen.",
		color = Color3.fromRGB(255, 110, 90),
	},
	money = {
		id = "money", name = "2× Geld", robux = 300, productId = nil, duration = nil,
		multiplier = 2,
		desc = "Verdoppelt alle Geldbelohnungen aus Kämpfen, Trainer- und Bosssiegen.",
		color = Color3.fromRGB(255, 215, 80),
	},
}
Shop.BoostOrder = { "luck", "damage", "money" }

Shop.Premium = {
	id = "premium_pal", name = "Premium-Pal (Welten-Begleiter)", robux = 1000,
	gamePassId = nil, -- !!! INTEGRATIONSPUNKT: echte Game-Pass-ID eintragen
	desc = "Einmalige Freischaltung. Du erhältst immer genau EINEN Premium-Pal: den der höchsten freigeschalteten Welt. "
		.. "Schaltest du eine neue Welt frei, wird er automatisch zur stärkeren Variante dieser Welt aufgewertet – nie gestapelt.",
	perWorld = { [1] = "noxen", [2] = "aurex", [3] = "yomira" }, -- aurex/yomira nur als Konzept vorbereitet
}

function Shop.BoostDuration(boostId)
	local b = Shop.Boosts[boostId]
	return (b and b.duration) or Shop.DefaultBoostDurationSeconds
end

function Shop.IsConfigured(boostId)
	local b = Shop.Boosts[boostId]
	return b ~= nil and type(b.productId) == "number" and b.productId > 0
end

function Shop.PremiumConfigured()
	return type(Shop.Premium.gamePassId) == "number" and Shop.Premium.gamePassId > 0
end

return Shop
