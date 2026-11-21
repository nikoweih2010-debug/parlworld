--[[
	Angriffs-Definitionen (zentral). Jede Kreatur referenziert genau zwei IDs.
	kind:
	  lunge      Nahkampf-Sprung nach vorne, trifft am Ende im Radius
	  cone       Nahkampf-Hieb in einem Kegel vor der Kreatur
	  projectile gerades Geschoss (count/spread), weicht man durch Seitwärtsbewegung aus
	  lob        Bogenwurf auf markierten Bodenpunkt (Warnkreis)
	  charge     Sturmangriff entlang einer markierten Linie
	  nova       Ring-Druckwelle um die Kreatur (Warnring)
	  strike     verzögerter Einschlag auf markierten Punkten
	  dive       Flieger stürzt auf markierten Punkt
	  blink      Teleport auf markierten Punkt + Schlag
	  beam       Strahl/Welle entlang markierter Linie(n)
	Alle Zeiten in Sekunden, Distanzen in Studs. windup = Warnzeit vor dem Treffer.
]]
local Attacks = {
	-- Gackerling
	peck_dash = { name = "Pickschlag", kind = "lunge", desc = "Kurzer Anlauf und ein schneller Schnabelhieb.",
		damage = 6, range = 9, dash = 6, radius = 4, windup = 0.45, cooldown = 2.2, vfx = "peck",
		color = Color3.fromRGB(255, 200, 90) },
	egg_lob = { name = "Eierbombe", kind = "lob", desc = "Wirft ein Ei im Bogen, das am Boden zerplatzt.",
		damage = 8, range = 40, radius = 5, windup = 0.55, flight = 0.9, cooldown = 4.2, vfx = "egg",
		color = Color3.fromRGB(255, 240, 200) },

	-- Glutwiesel
	ember_pounce = { name = "Funkensprung", kind = "lunge", desc = "Weiter Satz mit Glutspur, landet mit Funkenregen.",
		damage = 12, range = 24, dash = 20, radius = 6, windup = 0.6, cooldown = 4, vfx = "ember_pounce",
		color = Color3.fromRGB(255, 120, 40) },
	ember_spit = { name = "Glutspucke", kind = "projectile", desc = "Drei Fächer-Feuerbälle.",
		damage = 6, range = 60, count = 3, spread = 14, speed = 70, hitRadius = 2.2, windup = 0.4, cooldown = 3, vfx = "ember_spit",
		color = Color3.fromRGB(255, 140, 50) },

	-- Moosbock
	horn_charge = { name = "Moosramme", kind = "charge", desc = "Senkt die Hörner und stürmt eine Linie entlang.",
		damage = 18, range = 32, dash = 30, width = 5, windup = 0.85, cooldown = 5, vfx = "horn_charge",
		color = Color3.fromRGB(120, 210, 90) },
	thorn_ring = { name = "Dornenkranz", kind = "nova", desc = "Lässt einen Ring aus Dornen um sich herum aus dem Boden schießen.",
		damage = 12, range = 13, radius = 14, windup = 1.0, cooldown = 7, vfx = "thorn_ring",
		color = Color3.fromRGB(90, 170, 70) },

	-- Flauschfunk
	static_orb = { name = "Statikknäuel", kind = "projectile", desc = "Langsame, große Blitzkugel.",
		damage = 14, range = 60, count = 1, spread = 0, speed = 32, hitRadius = 3.5, windup = 0.6, cooldown = 3.5, vfx = "static_orb",
		color = Color3.fromRGB(255, 230, 90) },
	thunder_mark = { name = "Donnermal", kind = "strike", desc = "Markiert deinen Standort – kurz darauf schlägt ein Blitz ein.",
		damage = 20, range = 50, radius = 6, count = 1, scatter = 0, windup = 1.1, cooldown = 6, vfx = "thunder",
		color = Color3.fromRGB(255, 245, 140) },

	-- Bachzange
	claw_sweep = { name = "Scherensichel", kind = "cone", desc = "Breiter Scherenhieb nach vorne.",
		damage = 16, range = 10, angle = 120, windup = 0.6, cooldown = 2.8, vfx = "claw",
		color = Color3.fromRGB(120, 200, 255) },
	bubble_burst = { name = "Blasenmörser", kind = "lob", desc = "Schleudert eine Wasserblase, die beim Aufprall platzt.",
		damage = 15, range = 45, radius = 7, windup = 0.7, flight = 1.0, cooldown = 5, vfx = "bubble",
		color = Color3.fromRGB(90, 180, 255) },

	-- Frostigel
	ice_volley = { name = "Stachelsalve", kind = "projectile", desc = "Fünf Eisstacheln im breiten Fächer.",
		damage = 7, range = 65, count = 5, spread = 32, speed = 85, hitRadius = 1.8, windup = 0.5, cooldown = 3.5, vfx = "ice_volley",
		color = Color3.fromRGB(190, 240, 255) },
	frost_nova = { name = "Frostnova", kind = "nova", desc = "Eisige Druckwelle, verlangsamt Getroffene.",
		damage = 14, range = 14, radius = 16, windup = 1.1, cooldown = 8, slow = 0.45, slowTime = 2.5, vfx = "frost_nova",
		color = Color3.fromRGB(170, 235, 255) },

	-- Surrflügel
	wind_blade = { name = "Windsichel", kind = "projectile", desc = "Eine schnelle, breite Sichel aus Wind.",
		damage = 16, range = 80, count = 1, spread = 0, speed = 95, hitRadius = 3.2, windup = 0.5, cooldown = 2.8, vfx = "wind_blade",
		color = Color3.fromRGB(170, 255, 220) },
	dive_strike = { name = "Sturzflug", kind = "dive", desc = "Markiert einen Punkt und stürzt mit Wucht darauf.",
		damage = 26, range = 55, radius = 9, windup = 1.2, cooldown = 7, vfx = "dive",
		color = Color3.fromRGB(140, 255, 210) },

	-- Dämmerluchs
	shadow_blink = { name = "Schattensprung", kind = "blink", desc = "Ein dunkler Kreis erscheint unter dir – dann taucht der Luchs dort auf.",
		damage = 24, range = 45, radius = 7, windup = 0.95, cooldown = 7, vfx = "shadow_blink",
		color = Color3.fromRGB(150, 80, 255) },
	crescent_wave = { name = "Mondsichelwelle", kind = "beam", desc = "Eine lange Welle aus Mondlicht entlang einer Linie.",
		damage = 20, range = 42, length = 42, width = 4, count = 1, fan = 0, windup = 0.8, cooldown = 4.5, vfx = "crescent",
		color = Color3.fromRGB(200, 160, 255) },

	-- Boss: Morvath
	root_quake = { name = "Wurzelbeben", kind = "beam", desc = "Fächer aus Wurzelbahnen bricht aus dem Boden.",
		damage = 28, range = 70, length = 70, width = 5, count = 5, fan = 22, windup = 1.25, cooldown = 6, vfx = "root_quake",
		color = Color3.fromRGB(140, 220, 80) },
	spore_meteor = { name = "Sporenmeteor", kind = "strike", desc = "Riesige Samenbomben regnen auf markierte Kreise.",
		damage = 32, range = 80, radius = 10, count = 3, scatter = 16, windup = 1.6, cooldown = 7.5, vfx = "spore_meteor",
		color = Color3.fromRGB(220, 255, 120) },

	-- Premium: Noxen
	star_rain = { name = "Sternenregen", kind = "strike", desc = "Vier Sternsplitter schlagen um das Ziel ein.",
		damage = 18, range = 60, radius = 6, count = 4, scatter = 9, windup = 1.0, cooldown = 5.5, vfx = "star_rain",
		color = Color3.fromRGB(150, 190, 255) },
	moon_lance = { name = "Mondlanze", kind = "beam", desc = "Bündelt Mondlicht zu einem durchdringenden Strahl.",
		damage = 26, range = 60, length = 60, width = 3, count = 1, fan = 0, windup = 0.7, cooldown = 4, vfx = "moon_lance",
		color = Color3.fromRGB(210, 220, 255) },
}

for id, a in pairs(Attacks) do a.id = id end

Attacks.KindLabel = {
	lunge = "Nahkampf-Sprung", cone = "Nahkampf-Kegel", projectile = "Geschoss", lob = "Bogenwurf (Fläche)",
	charge = "Sturmangriff (Linie)", nova = "Druckwelle (Ring)", strike = "Einschlag (markiert)",
	dive = "Sturzflug (markiert)", blink = "Teleport-Schlag", beam = "Strahl (Linie)",
}

return Attacks
