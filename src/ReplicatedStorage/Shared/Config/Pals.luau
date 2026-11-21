--[[
	Kreaturen-Kader (zentral). Alle Werte pro Art hier anpassen.
	hp/speed/damageMult gelten für Level 1; pro Level +8 % (siehe Formulas).
	catchRate = Basis-Fangchance (0..1) bei besiegter Kreatur und Fangkugel Stufe 1.
	temperament: passive (flieht, wehrt sich nur), defensive (kämpft wenn angegriffen), aggressive (greift in aggroRange an)
	ride: nil = nicht reitbar | { mode = "ground"/"fly", speed = Studs/s }
	model: Bauplan-Key in Shared.CreatureBuilder; scale = Größenfaktor
]]
local Pals = {}

local function def(id, t) t.id = id; Pals[id] = t; return t end

def("gackerling", {
	name = "Gackerling", element = "Normal", rarity = "Common", role = "Unterstützer", world = 1, order = 1,
	desc = "Ein rundes Küken mit Eichelkappe. Neugierig, tollpatschig und überall auf der Lagerwiese zu finden.",
	personality = "Neugierig",
	hp = 60, speed = 13, damageMult = 1.0, attackSpeed = 1.0, aggroRange = 0, temperament = "passive",
	catchRate = 0.80, reward = 15, xp = 10,
	attacks = { "peck_dash", "egg_lob" },
	ride = nil, model = "gackerling", scale = 1, hover = 0,
})

def("glutwiesel", {
	name = "Glutwiesel", element = "Feuer", rarity = "Common", role = "Angreifer", world = 1, order = 2,
	desc = "Ein flinkes Wiesel, dessen Schweif wie ein Kohlestück glüht. Greift gern zuerst an.",
	personality = "Hitzköpfig",
	hp = 85, speed = 21, damageMult = 1.0, attackSpeed = 1.1, aggroRange = 32, temperament = "aggressive",
	catchRate = 0.62, reward = 30, xp = 18,
	attacks = { "ember_pounce", "ember_spit" },
	ride = nil, model = "glutwiesel", scale = 1, hover = 0,
})

def("moosbock", {
	name = "Moosbock", element = "Pflanze", rarity = "Common", role = "Tank / Reittier", world = 1, order = 3,
	desc = "Ein stämmiger Bock mit Moosfell und Farnhörnern. Gutmütig – bis man ihn reizt.",
	personality = "Gelassen",
	hp = 170, speed = 15, damageMult = 1.0, attackSpeed = 0.9, aggroRange = 0, temperament = "defensive",
	catchRate = 0.55, reward = 42, xp = 26,
	attacks = { "horn_charge", "thorn_ring" },
	ride = { mode = "ground", speed = 34, seatHeight = 4.2 }, model = "moosbock", scale = 1, hover = 0,
})

def("flauschfunk", {
	name = "Flauschfunk", element = "Elektro", rarity = "Uncommon", role = "Kontrolle", world = 1, order = 4,
	desc = "Eine schwebende Wollwolke voller Statik. Ihre Antennen knistern vor jedem Blitz.",
	personality = "Verträumt",
	hp = 115, speed = 12, damageMult = 1.0, attackSpeed = 1.0, aggroRange = 0, temperament = "defensive",
	catchRate = 0.44, reward = 58, xp = 32,
	attacks = { "static_orb", "thunder_mark" },
	ride = nil, model = "flauschfunk", scale = 1, hover = 2.2,
})

def("bachzange", {
	name = "Bachzange", element = "Wasser", rarity = "Uncommon", role = "Brecher", world = 1, order = 5,
	desc = "Ein Flusskrebs mit Kieselpanzer und einer übergroßen Schere. Verteidigt sein Ufer.",
	personality = "Stur",
	hp = 185, speed = 13, damageMult = 1.0, attackSpeed = 0.95, aggroRange = 24, temperament = "aggressive",
	catchRate = 0.40, reward = 62, xp = 34,
	attacks = { "claw_sweep", "bubble_burst" },
	ride = nil, model = "bachzange", scale = 1, hover = 0,
})

def("frostigel", {
	name = "Frostigel", element = "Eis", rarity = "Uncommon", role = "Verteidiger", world = 1, order = 6,
	desc = "Ein Igel mit Eiszapfen statt Stacheln. Rollt sich zusammen und feuert seine Stacheln ab.",
	personality = "Schüchtern",
	hp = 135, speed = 14, damageMult = 1.0, attackSpeed = 1.0, aggroRange = 28, temperament = "aggressive",
	catchRate = 0.40, reward = 64, xp = 34,
	attacks = { "ice_volley", "frost_nova" },
	ride = nil, model = "frostigel", scale = 1, hover = 0,
})

def("surrfluegel", {
	name = "Surrflügel", element = "Wind", rarity = "Rare", role = "Luftjäger / Flugreittier", world = 1, order = 7,
	desc = "Eine große Libellen-Kreatur mit vier gläsernen Flügeln. Jagt aus der Luft.",
	personality = "Wachsam",
	hp = 125, speed = 24, damageMult = 1.0, attackSpeed = 1.15, aggroRange = 45, temperament = "aggressive",
	catchRate = 0.28, reward = 115, xp = 55,
	attacks = { "wind_blade", "dive_strike" },
	ride = { mode = "fly", speed = 46, seatHeight = 2.4 }, model = "surrfluegel", scale = 1, hover = 9,
})

def("daemmerluchs", {
	name = "Dämmerluchs", element = "Dunkel", rarity = "Rare", role = "Assassine / schnelles Reittier", world = 1, order = 8,
	desc = "Ein Luchs mit leuchtenden Mondrunen im Fell. Verschwindet in Schatten und taucht hinter dir auf.",
	personality = "Stolz",
	hp = 175, speed = 24, damageMult = 1.0, attackSpeed = 1.1, aggroRange = 40, temperament = "aggressive",
	catchRate = 0.25, reward = 135, xp = 60,
	attacks = { "shadow_blink", "crescent_wave" },
	ride = { mode = "ground", speed = 46, seatHeight = 4.0 }, model = "daemmerluchs", scale = 1, hover = 0,
})

-- Elite-Varianten (Alpha): größer, zäher, schneller, schwerer zu fangen
def("moosbock_alpha", {
	name = "Alpha-Moosbock", element = "Pflanze", rarity = "Elite", role = "Elite-Tank / Reittier", world = 1, order = 9,
	desc = "Der uralte Leitbock der Ostweide. Sein Geweih trägt blühende Ranken.",
	personality = "Erhaben", baseSpecies = "moosbock",
	hp = 520, speed = 18, damageMult = 1.45, attackSpeed = 1.25, aggroRange = 30, temperament = "aggressive",
	catchRate = 0.14, reward = 320, xp = 150,
	attacks = { "horn_charge", "thorn_ring" },
	ride = { mode = "ground", speed = 40, seatHeight = 6.8 }, model = "moosbock", variant = "alpha", scale = 1.6, hover = 0,
})

def("daemmerluchs_alpha", {
	name = "Alpha-Dämmerluchs", element = "Dunkel", rarity = "Elite", role = "Elite-Assassine / Reittier", world = 1, order = 10,
	desc = "Ein riesiger Luchs mit glühender Mondkrone. Jagt nur in der Dämmerung des Schattenhains.",
	personality = "Unnahbar", baseSpecies = "daemmerluchs",
	hp = 560, speed = 27, damageMult = 1.45, attackSpeed = 1.3, aggroRange = 48, temperament = "aggressive",
	catchRate = 0.10, reward = 460, xp = 190,
	attacks = { "shadow_blink", "crescent_wave" },
	ride = { mode = "ground", speed = 52, seatHeight = 6.2 }, model = "daemmerluchs", variant = "alpha", scale = 1.55, hover = 0,
})

-- Boss Welt 1 (nicht fangbar)
def("morvath", {
	name = "Morvath, der Wurzelkoloss", element = "Pflanze", rarity = "Legendary", role = "Boss", world = 1, order = 11,
	desc = "Ein uralter Koloss aus Wurzeln, Stein und Moos, der in den Ruinen schläft. Sein Sieg öffnet den Weg zur Glutsteppe.",
	personality = "Uralt", isBoss = true, catchable = false,
	hp = 3200, speed = 10, damageMult = 1.0, attackSpeed = 1.0, aggroRange = 70, temperament = "aggressive",
	catchRate = 0, reward = 2000, xp = 500,
	attacks = { "root_quake", "spore_meteor" },
	ride = nil, model = "morvath", scale = 1, hover = 0,
})

-- Premium-Pal Welt 1 (nur über Robux-Angebot, nie wild)
def("noxen", {
	name = "Astralhirsch Noxen", element = "Dunkel", rarity = "Legendary", role = "Premium / Flugreittier", world = 1, order = 12,
	desc = "Ein Nachthirsch, dessen Geweih Sternbilder nachzeichnet. Premium-Begleiter der höchsten freigeschalteten Welt.",
	personality = "Gelassen", isPremium = true, catchable = false, premiumWorld = 1,
	hp = 230, speed = 22, damageMult = 1.15, attackSpeed = 1.1, aggroRange = 0, temperament = "defensive",
	catchRate = 0, reward = 0, xp = 0,
	attacks = { "star_rain", "moon_lance" },
	ride = { mode = "fly", speed = 52, seatHeight = 5.2 }, model = "noxen", scale = 1, hover = 1.5,
})

-- Nur vorbereitete Konzepte (kein Modell, nicht spielbar):
Pals.FutureConcepts = {
	{ id = "aurex", name = "Goldschwinge Aurex", world = 2, element = "Feuer", note = "Premium-Pal Welt 2 – goldener Greifen-Drache (Konzept, nicht umgesetzt)" },
	{ id = "yomira", name = "Geisterfuchs Yomira", world = 3, element = "Dunkel", note = "Premium-Pal Welt 3 – neunschweifiger Nachtfuchs (Konzept, nicht umgesetzt)" },
}

-- Arten, die im Welt-1-Katalog erscheinen (Reihenfolge = order)
function Pals.CatalogList(worldId)
	local list = {}
	for id, p in pairs(Pals) do
		if type(p) == "table" and p.id == id and p.world == worldId then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return a.order < b.order end)
	return list
end

function Pals.Get(id)
	local p = Pals[id]
	if type(p) == "table" and p.id == id then return p end
	return nil
end

return Pals
