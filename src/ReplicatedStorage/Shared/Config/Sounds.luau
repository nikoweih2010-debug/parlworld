--[[
	Sound-Zuordnung (zentral). Es werden nur in Roblox eingebaute Sounds (rbxasset://) und
	lizenzierte Pro-Sound-Effects-Assets aus dem Creator Store verwendet.
	Eigene Sounds: einfach die id hier ersetzen.
]]
local B = "rbxasset://sounds/"
local Sounds = {
	pistol   = { id = B .. "impact_explosion_03.mp3", volume = 0.22, speed = 2.6 },
	shotgun  = { id = B .. "impact_explosion_03.mp3", volume = 0.4,  speed = 1.6 },
	rifle    = { id = B .. "impact_explosion_03.mp3", volume = 0.16, speed = 3.0 },
	sniper   = { id = B .. "impact_explosion_03.mp3", volume = 0.5,  speed = 1.1 },
	launcher = { id = B .. "impact_explosion_03.mp3", volume = 0.3,  speed = 0.8 },
	reload   = { id = B .. "action_get_up.mp3",      volume = 0.5,  speed = 1.6 },
	empty    = { id = B .. "action_jump_land.mp3",   volume = 0.4,  speed = 2.4 },
	hit      = { id = B .. "action_jump_land.mp3",   volume = 0.45, speed = 2.0 },
	weakHit  = { id = B .. "action_jump_land.mp3",   volume = 0.6,  speed = 2.8 },
	swap     = { id = B .. "action_footsteps_plastic.mp3", volume = 0.5, speed = 1.8 },
	explosion= { id = B .. "impact_explosion_03.mp3", volume = 0.55, speed = 1.0 },
	splash   = { id = B .. "impact_water.mp3",        volume = 0.6,  speed = 1.0 },
	whoosh   = { id = "rbxassetid://9120696520",      volume = 0.5,  speed = 1.2 }, -- Pro Sound Effects
	airBurst = { id = "rbxassetid://9113069138",      volume = 0.5,  speed = 1.0 }, -- Pro Sound Effects
	sparkle  = { id = "rbxassetid://9125635430",      volume = 0.45, speed = 1.0 }, -- Pro Sound Effects
	playerHurt = { id = B .. "ouch.ogg",              volume = 0.5,  speed = 1.0 },
	throw    = { id = B .. "action_jump.mp3",         volume = 0.5,  speed = 1.4 },
	coin     = { id = "rbxassetid://9125635430",      volume = 0.35, speed = 1.6 },
}
return Sounds
