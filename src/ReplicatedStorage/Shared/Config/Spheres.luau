--[[
	Fangkugel-Stufen (zentral). Kugeln sind unbegrenzt – die Stufe bestimmt den Multiplikator.
	Fangchance = Basis-Fangrate der Art × Kugel-Multiplikator × Level-Faktor × (2× Luck-Boost)
	begrenzt auf [MinChance, MaxChance]. Ein besserer Ball garantiert den Fang NIE.
]]
local Spheres = {
	Tiers = {
		{ tier = 1, name = "Fangkugel",        mult = 1.0, price = 0,    color = Color3.fromRGB(240, 240, 235), band = Color3.fromRGB(80, 190, 255),
		  desc = "Standardkugel. Reicht für gewöhnliche Pals." },
		{ tier = 2, name = "Super-Fangkugel",  mult = 1.5, price = 450,  color = Color3.fromRGB(90, 140, 255),  band = Color3.fromRGB(255, 255, 255),
		  desc = "+50 % Fangchance gegenüber Stufe 1." },
		{ tier = 3, name = "Hyper-Fangkugel",  mult = 2.1, price = 1800, color = Color3.fromRGB(255, 190, 60),  band = Color3.fromRGB(40, 40, 50),
		  desc = "×2,1 Fangchance. Für seltene Pals empfohlen." },
		{ tier = 4, name = "Astral-Fangkugel", mult = 3.0, price = 4800, color = Color3.fromRGB(150, 90, 255),  band = Color3.fromRGB(255, 230, 120),
		  desc = "×3 Fangchance. Die beste Chance auf Alpha-Pals – aber keine Garantie." },
	},
	MinChance = 0.03,
	MaxChance = 0.95,
	LevelPenaltyPerLevel = 0.02, -- pro Level über 1: -2 % relative Chance
	ThrowCooldown = 1.2,
	ThrowSpeed = 95,
	MaxThrowRange = 70,
	DownedDuration = 14,          -- so lange bleibt eine besiegte Kreatur fangbar
	FailRecoverHpFraction = 0.3,  -- nach misslungenem Fang steht sie mit 30 % HP wieder auf
	ShakeTime = 0.55,             -- Zeit pro Wackler (3 Wackler)
}

function Spheres.Get(tier)
	return Spheres.Tiers[tier]
end

return Spheres
