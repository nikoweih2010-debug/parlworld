-- Elemente & Seltenheiten (zentral). Wirkt nur auf Pal-gegen-Pal-Schaden.
local Elements = {}

Elements.List = {
	Normal  = { name = "Normal",  color = Color3.fromRGB(214, 206, 186), icon = "◆" },
	Feuer   = { name = "Feuer",   color = Color3.fromRGB(255, 120, 60),  icon = "◆" },
	Pflanze = { name = "Pflanze", color = Color3.fromRGB(110, 200, 90),  icon = "◆" },
	Elektro = { name = "Elektro", color = Color3.fromRGB(255, 220, 70),  icon = "◆" },
	Wasser  = { name = "Wasser",  color = Color3.fromRGB(70, 160, 255),  icon = "◆" },
	Eis     = { name = "Eis",     color = Color3.fromRGB(160, 230, 255), icon = "◆" },
	Wind    = { name = "Wind",    color = Color3.fromRGB(150, 240, 200), icon = "◆" },
	Dunkel  = { name = "Dunkel",  color = Color3.fromRGB(170, 110, 255), icon = "◆" },
	Erde    = { name = "Erde",    color = Color3.fromRGB(190, 140, 90),  icon = "◆" },
}

-- attacker -> { defender = multiplier }
Elements.Chart = {
	Feuer   = { Pflanze = 1.25, Eis = 1.25, Wasser = 0.8, Erde = 0.8 },
	Wasser  = { Feuer = 1.25, Erde = 1.25, Pflanze = 0.8, Elektro = 0.8 },
	Pflanze = { Wasser = 1.25, Erde = 1.25, Feuer = 0.8, Wind = 0.8 },
	Elektro = { Wasser = 1.25, Wind = 1.25, Erde = 0.8 },
	Eis     = { Pflanze = 1.25, Wind = 1.25, Feuer = 0.8 },
	Wind    = { Pflanze = 1.25, Erde = 1.25, Elektro = 0.8 },
	Dunkel  = { Normal = 1.25, Dunkel = 0.8 },
	Erde    = { Elektro = 1.25, Feuer = 1.25, Wind = 0.8 },
	Normal  = {},
}

function Elements.Multiplier(attacker, defender)
	local row = Elements.Chart[attacker]
	return (row and row[defender]) or 1
end

Elements.Rarities = {
	Common    = { name = "Gewöhnlich",   order = 1, color = Color3.fromRGB(170, 190, 170) },
	Uncommon  = { name = "Ungewöhnlich", order = 2, color = Color3.fromRGB(90, 170, 255) },
	Rare      = { name = "Selten",       order = 3, color = Color3.fromRGB(190, 110, 255) },
	Elite     = { name = "Elite (Alpha)",order = 4, color = Color3.fromRGB(255, 150, 50) },
	Legendary = { name = "Legendär",     order = 5, color = Color3.fromRGB(255, 215, 80) },
}

return Elements
