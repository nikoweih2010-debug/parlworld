--[[
	Waffen (zentral). Der Server prüft Feuerrate, Munition, Reichweite und Besitz.
	damage       Schaden pro Treffer (pro Schrotkugel bei pellets > 1)
	fireRate     Schüsse pro Sekunde
	range        maximale Reichweite in Studs (danach kein Schaden)
	falloffStart ab dieser Distanz sinkt der Schaden linear auf minFalloff
	magazine     Schuss pro Magazin, reload = Nachladezeit (s)
	spread       Streuung in Grad (Hüfte); adsSpread beim Zielen (Rechtsklick)
	weakspot     Multiplikator für Kopftreffer (Teile mit Attribut WeakSpot)
	splash       Flächenschaden-Radius (nur Glutwerfer)
	price        Kaufpreis (nil = nicht kaufbar, z. B. Trainer-Belohnung)
	upgradeCosts Preise für Tuning-Stufen 1..3, je +12 % Schaden
]]
local Weapons = {}

local function def(id, t) t.id = id; Weapons[id] = t end

def("funkenpistole", {
	name = "Funkenpistole", order = 1, archetype = "Pistole",
	desc = "Deine Startwaffe. Zuverlässig, aber schwach. Gut für Gackerlinge.",
	damage = 8, fireRate = 3.2, automatic = false, pellets = 1, range = 140, falloffStart = 70, minFalloff = 0.6,
	magazine = 10, reload = 1.3, spread = 1.6, adsSpread = 0.4, adsFov = 58, recoil = 1.4, weakspot = 1.6,
	price = 0, upgradeCosts = { 120, 300, 650 },
	color = Color3.fromRGB(255, 170, 60), tracer = Color3.fromRGB(255, 210, 120), sound = "pistol",
})

def("dornenstreuer", {
	name = "Dornenstreuer", order = 2, archetype = "Schrotflinte",
	desc = "Verschießt 7 Dornen-Schrotkugeln. Verheerend auf kurze Distanz, nutzlos auf weite.",
	damage = 6, fireRate = 1.1, automatic = false, pellets = 7, range = 45, falloffStart = 14, minFalloff = 0.35,
	magazine = 6, reload = 2.3, spread = 7, adsSpread = 5, adsFov = 64, recoil = 5, weakspot = 1.25,
	price = 650, upgradeCosts = { 300, 700, 1400 },
	color = Color3.fromRGB(120, 200, 90), tracer = Color3.fromRGB(190, 255, 140), sound = "shotgun",
})

def("schwarmwerfer", {
	name = "Schwarmwerfer", order = 3, archetype = "Sturmgewehr",
	desc = "Vollautomatisch mit großem Magazin. Hohe Dauerleistung, aber starke Streuung beim Dauerfeuer.",
	damage = 6, fireRate = 10, automatic = true, pellets = 1, range = 150, falloffStart = 60, minFalloff = 0.55,
	magazine = 32, reload = 2.0, spread = 3.0, adsSpread = 1.2, adsFov = 55, recoil = 0.9, weakspot = 1.5, bloom = 0.25,
	price = 1600, upgradeCosts = { 500, 1100, 2200 },
	color = Color3.fromRGB(90, 170, 255), tracer = Color3.fromRGB(150, 220, 255), sound = "rifle",
})

def("falkenauge", {
	name = "Falkenauge", order = 4, archetype = "Präzisionsgewehr",
	desc = "Schwerer Einzelschuss mit Zielfernrohr. Kopftreffer (Schwachstelle) richten dreifachen Schaden an.",
	damage = 62, fireRate = 0.75, automatic = false, pellets = 1, range = 420, falloffStart = 400, minFalloff = 1,
	magazine = 4, reload = 2.6, spread = 4.5, adsSpread = 0.05, adsFov = 22, recoil = 7, weakspot = 3.0,
	price = 2600, upgradeCosts = { 800, 1600, 3000 },
	color = Color3.fromRGB(200, 160, 255), tracer = Color3.fromRGB(230, 210, 255), sound = "sniper",
})

def("glutwerfer", {
	name = "Glutwerfer", order = 5, archetype = "Granatwerfer",
	desc = "Trainer-Belohnung. Verschießt Glutkapseln mit Flächenschaden – ideal gegen Gruppen und den Boss.",
	damage = 40, fireRate = 0.9, automatic = false, pellets = 1, range = 160, falloffStart = 160, minFalloff = 1,
	magazine = 4, reload = 2.8, spread = 1.0, adsSpread = 0.5, adsFov = 60, recoil = 6, weakspot = 1.0,
	splash = 9, projectileSpeed = 120,
	price = nil, rewardFrom = "Trainerin Lyra", upgradeCosts = { 900, 1800, 3200 },
	color = Color3.fromRGB(255, 110, 60), tracer = Color3.fromRGB(255, 160, 80), sound = "launcher",
})

Weapons.UpgradeBonusPerLevel = 0.12
Weapons.MaxUpgrade = 3
Weapons.StarterWeapon = "funkenpistole"
Weapons.MaxSlots = 3

function Weapons.Get(id)
	local w = Weapons[id]
	if type(w) == "table" and w.id == id then return w end
	return nil
end

function Weapons.List()
	local list = {}
	for id, w in pairs(Weapons) do
		if type(w) == "table" and w.id == id then table.insert(list, w) end
	end
	table.sort(list, function(a, b) return a.order < b.order end)
	return list
end

return Weapons
