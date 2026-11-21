--[[
	Tutorial, Trainer und Boss-Fortschritt (zentral).
	Tutorial-Schritte werden vom Server anhand echter Ereignisse abgeschlossen (event = Ereignisname).
]]
local Progression = {}

Progression.Tutorial = {
	{ id = "move",    title = "Bewegung",       text = "Laufe mit WASD (Mobil: Joystick) zum leuchtenden Wegweiser am Südtor des Lagers.", event = "reach_sign", reward = 10 },
	{ id = "aim",     title = "Manuelles Zielen", text = "Ziele mit der Maus (Mobil: Wischen) und triff die 3 Zielscheiben am Schießstand. Rechtsklick = Visier.", event = "dummy_hit", count = 3, reward = 15 },
	{ id = "reload",  title = "Nachladen",      text = "Lade deine Waffe mit R nach (Mobil: ↻-Knopf).", event = "reload", reward = 5 },
	{ id = "fight",   title = "Kreaturenkampf", text = "Besiege einen Gackerling auf der Lagerwiese. Achte auf rote Warnzeichen und weiche aus!", event = "defeat_any", reward = 20 },
	{ id = "catch",   title = "Fangen",         text = "Besiegte Pals bleiben kurz geschwächt liegen. Wechsle mit 4 zur Fangkugel (oder drücke F) und wirf sie auf den Pal.", event = "catch_any", reward = 30 },
	{ id = "team",    title = "Team",           text = "Öffne die Ausrüstung (Tab) und setze deinen Pal ins aktive Team.", event = "team_set", reward = 10 },
	{ id = "summon",  title = "Team-Einsatz",   text = "Rufe deinen Team-Pal mit Q. Er kämpft an deiner Seite. Q erneut = zurückrufen, C = nächster Team-Pal.", event = "summon", reward = 10 },
	{ id = "shop",    title = "Geld & Händler", text = "Kreaturen bringen Geld. Sprich mit Händler Bruno im Lager (E) oder öffne den Shop (B) und kaufe ein Upgrade.", event = "purchase", reward = 25 },
	{ id = "ride",    title = "Reiten",         text = "Fange einen reitbaren Pal (z. B. Moosbock auf der Ostweide), rufe ihn und steige mit G auf. G erneut = absteigen.", event = "mount", reward = 40 },
	{ id = "trainer", title = "Trainerkampf",   text = "Fordere Trainerin Lyra am Übungsring (Nordost vom Lager) heraus. Belohnung: Glutwerfer + 400 Gold.", event = "trainer_win", reward = 0 },
	{ id = "boss",    title = "Boss",           text = "Das Siegel hinter den Wurzelruinen (Südwesten) ist offen. Erwecke Morvath am Altar und besiege ihn, um Welt 2 freizuschalten!", event = "boss_win", reward = 0 },
}

Progression.Trainers = {
	lyra = {
		id = "lyra", name = "Trainerin Lyra", world = 1,
		intro = "Du willst gegen mich antreten? Besiege meine zwei Pals – dann gehört dir mein Glutwerfer!",
		rewardText = "Belohnung: Glutwerfer (Granatwerfer, Flächenschaden) + 400 Gold + Zugang zu den Wurzelruinen",
		rewardMoney = 400, rewardWeapon = "glutwerfer",
		team = {
			{ species = "glutwiesel", level = 6, hpMult = 1.3 },
			{ species = "bachzange", level = 7, hpMult = 1.2 },
		},
		arena = Vector3.new(72, 0, -72), arenaRadius = 28,
		requiresTutorialStep = nil,
	},
}

Progression.Boss = {
	morvath = {
		id = "morvath", world = 1, unlocksWorld = 2, requiresTrainer = "lyra",
		rewardMoney = 2000,
		phase2At = 0.5,          -- ab 50 % HP: Phase 2
		phase2CooldownMult = 0.65,
		phase2ExtraWave = true,
		intro = "Die Wurzeln beben… Morvath erwacht!",
	},
}

return Progression
