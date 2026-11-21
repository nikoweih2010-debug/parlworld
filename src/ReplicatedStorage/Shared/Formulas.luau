-- Gemeinsame Formeln (Server rechnet verbindlich, Client nur zur Anzeige)
local Config = script.Parent:WaitForChild("Config")
local Pals = require(Config.Pals)
local Spheres = require(Config.Spheres)
local Weapons = require(Config.Weapons)

local Formulas = {}

Formulas.LevelStatBonus = 0.15 -- Lebenspunkte pro Level (+15 %): höhere Level brauchen bessere Waffen
Formulas.MaxLevel = 30

function Formulas.LevelMult(level)
	return 1 + Formulas.LevelStatBonus * (math.max(1, level) - 1)
end

-- Angriffsschaden steigt langsamer als Lebenspunkte (fairer für Spieler mit 150 LP)
Formulas.DamageLevelBonus = 0.04
function Formulas.DamageLevelMult(level)
	return 1 + Formulas.DamageLevelBonus * (math.max(1, level) - 1)
end

Formulas.PlayerMaxHealth = 150

function Formulas.MaxHp(speciesId, level)
	local p = Pals.Get(speciesId)
	if not p then return 100 end
	return math.floor(p.hp * Formulas.LevelMult(level) + 0.5)
end

function Formulas.XpForLevel(level)
	return math.floor(30 * level ^ 1.45)
end

-- Fangchance (0..1). luckMult = 2 bei aktivem Luck-Boost
function Formulas.CatchChance(speciesId, level, ballTier, luckMult)
	local p = Pals.Get(speciesId)
	if not p or p.catchable == false then return 0 end
	local ball = Spheres.Get(ballTier) or Spheres.Tiers[1]
	local levelFactor = math.max(0.4, 1 - Spheres.LevelPenaltyPerLevel * (math.max(1, level) - 1))
	local c = p.catchRate * ball.mult * levelFactor * (luckMult or 1)
	return math.clamp(c, Spheres.MinChance, Spheres.MaxChance)
end

function Formulas.WeaponDamage(weaponId, upgradeLevel)
	local w = Weapons.Get(weaponId)
	if not w then return 0 end
	return w.damage * (1 + Weapons.UpgradeBonusPerLevel * (upgradeLevel or 0))
end

function Formulas.Falloff(w, dist)
	if dist <= w.falloffStart then return 1 end
	if dist >= w.range then return 0 end
	local t = (dist - w.falloffStart) / math.max(1, w.range - w.falloffStart)
	return 1 + (w.minFalloff - 1) * t
end

-- DPS-Anzeige für UI-Vergleich
function Formulas.WeaponDps(weaponId, upgradeLevel)
	local w = Weapons.Get(weaponId)
	if not w then return 0 end
	local shotTime = w.magazine / w.fireRate + w.reload
	return Formulas.WeaponDamage(weaponId, upgradeLevel) * w.pellets * w.magazine / shotTime
end

function Formulas.FormatMoney(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then out = out:sub(2) end
	return out .. " G"
end

function Formulas.FormatTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

return Formulas
