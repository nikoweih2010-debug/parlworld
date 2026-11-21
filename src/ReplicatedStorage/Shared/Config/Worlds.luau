--[[
	Welten & Spawn-Zonen (zentral).
	Neue Welt hinzufügen: Eintrag in Worlds.List ergänzen (implemented = true, zones, boss, trainer).
	Welt 2 und 3 sind nur als Vorschau vorbereitet (implemented = false).
]]
local Worlds = {}

Worlds.List = {
	[1] = {
		id = 1, name = "Smaragdinsel", implemented = true,
		desc = "Eine bewaldete Insel mit Startlager, Weiden, Frostkamm und den uralten Wurzelruinen.",
		spawn = Vector3.new(0, 18, 20),
		boss = "morvath", bossArena = Vector3.new(-60, 34, 280),
		trainer = "lyra",
		levelCap = 15,
		zones = {
			{ id = "lagerwiese", name = "Lagerwiese", center = Vector3.new(55, 0, 55), radius = 55, max = 7, respawn = 14,
			  levels = { 1, 3 }, table = { gackerling = 7, glutwiesel = 2 } },
			{ id = "lagerwiese_w", name = "Lagerwiese", center = Vector3.new(-70, 0, -40), radius = 40, max = 4, respawn = 16,
			  levels = { 1, 3 }, table = { gackerling = 6, glutwiesel = 3 } },
			{ id = "ostweide", name = "Ostweide", center = Vector3.new(170, 0, 0), radius = 65, max = 7, respawn = 20,
			  levels = { 3, 6 }, table = { moosbock = 5, flauschfunk = 3, gackerling = 1 } },
			{ id = "bachufer", name = "Bachufer", center = Vector3.new(140, 0, 225), radius = 55, max = 5, respawn = 24,
			  levels = { 5, 8 }, table = { bachzange = 5, flauschfunk = 1 } },
			{ id = "frostkamm", name = "Frostkamm", center = Vector3.new(-190, 0, -215), radius = 55, max = 5, respawn = 26,
			  levels = { 6, 9 }, table = { frostigel = 5, flauschfunk = 1 } },
			{ id = "schattenhain", name = "Schattenhain", center = Vector3.new(-200, 0, 60), radius = 55, max = 5, respawn = 30,
			  levels = { 7, 10 }, table = { daemmerluchs = 2, glutwiesel = 3 } },
			{ id = "windhoehen", name = "Windhöhen", center = Vector3.new(180, 0, -180), radius = 55, max = 4, respawn = 30,
			  levels = { 7, 10 }, table = { surrfluegel = 3, moosbock = 1 } },
		},
		elites = {
			{ species = "moosbock_alpha", position = Vector3.new(240, 0, 70), level = 10, respawn = 240, name = "Alpha-Lichtung" },
			{ species = "daemmerluchs_alpha", position = Vector3.new(-245, 0, 125), level = 12, respawn = 300, name = "Mondsenke" },
		},
	},
	[2] = {
		id = 2, name = "Glutsteppe", implemented = false,
		desc = "Eine Vulkansteppe voller Feuer- und Erd-Pals. Wird nach dem Sieg über Morvath freigeschaltet – Inhalt folgt in einem späteren Update.",
		unlockRequirement = "Besiege Morvath, den Wurzelkoloss (Welt 1)",
	},
	[3] = {
		id = 3, name = "Nebelschlucht", implemented = false,
		desc = "Eine geisterhafte Schlucht in ewigem Zwielicht. Kommt später.",
		unlockRequirement = "Besiege den Boss von Welt 2",
	},
}

Worlds.MaxDefined = 3

-- Performance: Kreaturen weit weg von allen Spielern "schlafen" (keine KI-Updates)
Worlds.SimulationRadius = 230
Worlds.LeashRadius = 80 -- so weit verfolgt eine Kreatur ein Ziel von ihrem Zuhause aus

return Worlds
