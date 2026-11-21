--[[
	Menus (Client): Pal-Katalog, Ausrüstung (Team + Waffen) und Shop (Waffen, Fangkugeln, Robux).
	Alle Änderungen laufen als Anfrage an den Server; die Anzeige folgt ausschließlich dem Server-Zustand.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pals = require(Shared.Config.Pals)
local Attacks = require(Shared.Config.Attacks)
local Elements = require(Shared.Config.Elements)
local Weapons = require(Shared.Config.Weapons)
local Spheres = require(Shared.Config.Spheres)
local Shop = require(Shared.Config.Shop)
local Formulas = require(Shared.Formulas)

local UI = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local Portraits = require(script.Parent.Portraits)

local Menus = {}
local player = Players.LocalPlayer
local T = UI.Theme
local gui, window, content, tabButtons, statusLabel, modal
local current = nil
local WC, HUD
local state = { catalogSel = "gackerling", palSel = nil, shopCat = "weapons" }

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
end

local function setStatus(ok, msg)
	if not statusLabel then return end
	statusLabel.Text = msg or (ok and "Erledigt" or "Nicht möglich")
	statusLabel.TextColor3 = ok and T.good or T.warn
end

local function request(name, ...)
	local ok, msg = ClientState.Request(name, ...)
	setStatus(ok, msg)
	return ok, msg
end

local function rarityText(def)
	local r = Elements.Rarities[def.rarity]
	return r.name, r.color
end

local function scroll(parent, props)
	return UI.new("ScrollingFrame", {
		Size = props.Size, Position = props.Position or UDim2.new(), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollBarImageColor3 = T.stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = parent, Name = props.Name or "Scroll",
	})
end

local function statRow(parent, label, value, order, color)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	UI.label(label, { Size = UDim2.new(0.55, 0, 1, 0), TextSize = 13, color = T.dim, Parent = row })
	UI.label(value, { Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0), TextSize = 13, Font = UI.Font, color = color or T.text, align = Enum.TextXAlignment.Right, Parent = row })
	return row
end

local function attackBlock(parent, atk, order, def, level)
	local f = UI.panel({ Size = UDim2.new(1, 0, 0, 74), color = T.panel2, LayoutOrder = order, Parent = parent, radius = 8 })
	local dmg = atk.damage * (def.damageMult or 1) * Formulas.DamageLevelMult(level or 1)
	UI.label(atk.name, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 18), TextSize = 14, Font = UI.Font, color = atk.color, Parent = f })
	UI.label(string.format("%s • %d Schaden%s • Abklingzeit %.1f s • Warnzeit %.1f s", Attacks.KindLabel[atk.kind] or atk.kind, math.floor(dmg + 0.5), (atk.count and atk.count > 1) and (" ×" .. atk.count) or "", atk.cooldown, atk.windup),
		{ Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, color = T.dim, Parent = f })
	UI.label(atk.desc, { Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 30), TextSize = 12, wrap = true, valign = Enum.TextYAlignment.Top, Parent = f })
end

------------------------------------------------------------------ Katalog
local function catalogStatus(def, d)
	if def.isPremium then
		for _, p in pairs(d.pals) do if p.species == def.id then return "owned" end end
		return "premium"
	end
	local e = d.dex[def.id]
	if e and (e.caught or 0) > 0 then return "caught", e.caught end
	if e and e.seen then return "seen" end
	return "unknown"
end

local function buildCatalog()
	local d = ClientState.Data
	if not d then return end
	local list = Pals.CatalogList(1)
	local caught, seen, total = 0, 0, 0
	for _, def in ipairs(list) do
		if not def.isPremium then
			total += 1
			local s = catalogStatus(def, d)
			if s == "caught" then caught += 1; seen += 1 elseif s == "seen" then seen += 1 end
		end
	end
	UI.label(string.format("Welt 1 – Smaragdinsel   •   Gefangen %d/%d   •   Entdeckt %d/%d", caught, total, seen, total), { Size = UDim2.new(1, 0, 0, 22), TextSize = 15, Font = UI.Font, color = T.accent, Parent = content })
	local grid = scroll(content, { Size = UDim2.new(0.58, -8, 1, -30), Position = UDim2.fromOffset(0, 30) })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(122, 158), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UI.pad(4).Parent = grid
	for i, def in ipairs(list) do
		local st, n = catalogStatus(def, d)
		local rName, rCol = rarityText(def)
		local card = UI.new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = state.catalogSel == def.id and Color3.fromRGB(40, 70, 70) or T.panel2, LayoutOrder = i, Parent = grid }, { UI.corner(10), UI.stroke(st == "unknown" and T.stroke or rCol, 1.5, 0.2) })
		local pf = UI.new("Frame", { Size = UDim2.new(1, -12, 0, 98), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(22, 30, 38), Parent = card }, { UI.corner(8) })
		local vp = Portraits.Make(pf, def.id, "face", (st == "unknown") and "silhouette" or "known")
		UI.corner(8).Parent = vp
		local nl = UI.label(st == "unknown" and "???" or def.name, { Position = UDim2.fromOffset(6, 106), Size = UDim2.new(1, -12, 0, 18), TextSize = 13, Font = UI.Font, align = Enum.TextXAlignment.Center, Parent = card, scaled = true })
		UI.new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8, Parent = nl })
		local badgeText, badgeCol
		if st == "caught" then badgeText, badgeCol = "GEFANGEN ×" .. n, T.good
		elseif st == "seen" then badgeText, badgeCol = "ENTDECKT", Color3.fromRGB(110, 180, 255)
		elseif st == "owned" then badgeText, badgeCol = "PREMIUM • BESITZ", T.premium
		elseif st == "premium" then badgeText, badgeCol = "PREMIUM-ANGEBOT", T.premium
		else badgeText, badgeCol = "UNBEKANNT", T.dim end
		if def.isBoss and st ~= "unknown" then badgeText = st == "caught" and badgeText or "BOSS • nicht fangbar" end
		UI.label(badgeText, { Position = UDim2.fromOffset(6, 126), Size = UDim2.new(1, -12, 0, 14), TextSize = 10, Font = UI.Font, align = Enum.TextXAlignment.Center, color = badgeCol, Parent = card })
		UI.label(st == "unknown" and "" or rName, { Position = UDim2.fromOffset(6, 140), Size = UDim2.new(1, -12, 0, 14), TextSize = 10, align = Enum.TextXAlignment.Center, color = rCol, Parent = card })
		card.Activated:Connect(function()
			state.catalogSel = def.id
			Menus.Refresh()
		end)
	end

	-- Details
	local def = Pals.Get(state.catalogSel) or list[1]
	local st = catalogStatus(def, d)
	local det = UI.panel({ Size = UDim2.new(0.42, 0, 1, -30), Position = UDim2.new(0.58, 0, 0, 30), color = T.panel, Parent = content })
	local sc = scroll(det, { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8) })
	UI.list(Enum.FillDirection.Vertical, 6).Parent = sc
	local pv = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 170), BackgroundColor3 = Color3.fromRGB(22, 30, 38), LayoutOrder = 1, Parent = sc }, { UI.corner(10) })
	Portraits.Make(pv, def.id, "full", st == "unknown" and "silhouette" or "known")
	if st == "unknown" then
		UI.label("???", { TextSize = 22, Font = UI.Font, LayoutOrder = 2, Parent = sc })
		UI.label("Du bist diesem Pal noch nicht begegnet. Erkunde die Insel, um ihn zu entdecken.", { Size = UDim2.new(1, -8, 0, 40), TextSize = 13, wrap = true, color = T.dim, LayoutOrder = 3, Parent = sc })
		return
	end
	local rName, rCol = rarityText(def)
	local el = Elements.List[def.element]
	UI.label(def.name, { TextSize = 22, Font = UI.Font, LayoutOrder = 2, Parent = sc })
	UI.label(string.format('<font color="#%s">%s %s</font>  •  <font color="#%s">%s</font>  •  %s', el.color:ToHex(), el.icon, el.name, rCol:ToHex(), rName, def.role), { TextSize = 13, rich = true, LayoutOrder = 3, Parent = sc })
	local stText = ({ caught = "Gefangen", seen = "Entdeckt – noch nicht gefangen", owned = "Premium – in deinem Besitz", premium = "Nur über das Premium-Angebot im Shop (nicht im Besitz)" })[st] or ""
	UI.label(stText, { TextSize = 13, Font = UI.Font, color = st == "caught" and T.good or (st == "seen" and Color3.fromRGB(110, 180, 255) or T.premium), LayoutOrder = 4, Parent = sc })
	UI.label(def.desc .. "  Wesen: " .. def.personality .. ".", { Size = UDim2.new(1, -8, 0, 52), TextSize = 13, wrap = true, LayoutOrder = 5, Parent = sc })
	local stats = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 6, Parent = sc }, { UI.list(Enum.FillDirection.Vertical, 2) })
	statRow(stats, "Lebenspunkte (Lv 1)", tostring(def.hp), 1)
	statRow(stats, "Tempo", tostring(def.speed), 2)
	statRow(stats, "Angriffstempo", string.format("×%.2f", def.attackSpeed or 1), 3)
	if def.isBoss or def.isPremium then
		statRow(stats, "Fangbar", "Nein", 4, T.warn)
	else
		local ch = Formulas.CatchChance(def.id, 1, d.ballTier, 1)
		statRow(stats, "Basis-Fangrate", math.floor(def.catchRate * 100) .. " %", 4)
		statRow(stats, "Deine Chance (Lv 1, deine Kugel)", math.floor(ch * 100 + 0.5) .. " %", 5, T.accent)
	end
	statRow(stats, "Belohnung", def.reward > 0 and (def.reward .. " G") or "–", 6, T.gold)
	statRow(stats, "Reiten", def.ride and ((def.ride.mode == "fly" and "Fliegen" or "Laufen") .. " • Tempo " .. def.ride.speed) or "Nicht reitbar", 7)
	UI.label("Angriffe", { TextSize = 15, Font = UI.Font, color = T.accent, LayoutOrder = 7, Parent = sc })
	for i, aid in ipairs(def.attacks) do attackBlock(sc, Attacks[aid], 7 + i, def, 1) end
end

------------------------------------------------------------------ Ausrüstung
local function palStats(pal)
	local def = Pals.Get(pal.species)
	return def, Formulas.MaxHp(pal.species, pal.level)
end

local function palCompareColumn(parent, title, pal, order)
	local col = UI.panel({ Size = UDim2.new(0.5, -4, 0, 0), color = T.panel2, LayoutOrder = order, Parent = parent, radius = 8 })
	col.AutomaticSize = Enum.AutomaticSize.Y
	UI.pad(8).Parent = col
	UI.list(Enum.FillDirection.Vertical, 3).Parent = col
	UI.label(title, { TextSize = 11, color = T.dim, Parent = col, LayoutOrder = 0 })
	if not pal then
		UI.label("–", { TextSize = 14, Parent = col, LayoutOrder = 1 })
		return
	end
	local def, hp = palStats(pal)
	local rName, rCol = rarityText(def)
	UI.label(def.name .. "  Lv " .. pal.level, { TextSize = 14, Font = UI.Font, color = rCol, Parent = col, LayoutOrder = 1 })
	statRow(col, "Seltenheit", rName, 2, rCol)
	statRow(col, "Element", Elements.List[def.element].name, 3, Elements.List[def.element].color)
	statRow(col, "Lebenspunkte", tostring(hp), 4)
	statRow(col, "Tempo", tostring(def.speed), 5)
	for i, aid in ipairs(def.attacks) do
		local a = Attacks[aid]
		statRow(col, a.name, math.floor(a.damage * def.damageMult * Formulas.DamageLevelMult(pal.level) + 0.5) .. " Schaden", 5 + i, a.color)
	end
	statRow(col, "Reiten", def.ride and (def.ride.mode == "fly" and "Fliegen" or "Laufen") or "Nein", 9)
	statRow(col, "XP", pal.xp and (math.floor(pal.xp) .. "/" .. (pal.xpNext or "?")) or "–", 10)
end

local function buildEquipment()
	local d = ClientState.Data
	if not d then return end
	-- Team (oben links)
	local teamP = UI.panel({ Size = UDim2.new(0.38, -6, 0, 250), color = T.panel, Parent = content })
	UI.label("Aktives Team (max. 3)", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 15, Font = UI.Font, color = T.accent, Parent = teamP })
	for i = 1, 3 do
		local uid = d.team[i]
		local pal = uid and d.pals[uid]
		local row = UI.panel({ Size = UDim2.new(1, -20, 0, 66), Position = UDim2.fromOffset(10, 32 + (i - 1) * 72), color = (i == d.activeIndex and pal) and Color3.fromRGB(36, 70, 62) or T.panel2, Parent = teamP, radius = 8 })
		if pal then
			local def = Pals.Get(pal.species)
			local pf = UI.new("Frame", { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(22, 30, 38), Parent = row }, { UI.corner(8) })
			Portraits.Make(pf, pal.species, "face")
			UI.label(def.name .. "  Lv " .. pal.level .. (pal.premium and "  ★" or ""), { Position = UDim2.fromOffset(68, 6), Size = UDim2.new(1, -76, 0, 18), TextSize = 14, Font = UI.Font, Parent = row })
			UI.label((i == d.activeIndex and "AKTIV • " or "") .. (pal.fainted and ("erschöpft " .. pal.fainted .. "s") or Elements.Rarities[def.rarity].name), { Position = UDim2.fromOffset(68, 24), Size = UDim2.new(1, -76, 0, 14), TextSize = 11, color = T.dim, Parent = row })
			UI.button("Aktiv", { Size = UDim2.fromOffset(60, 22), Position = UDim2.fromOffset(68, 40), TextSize = 11, Parent = row }, function() request("SetActiveIndex", i) end)
			UI.button("Entfernen", { Size = UDim2.fromOffset(76, 22), Position = UDim2.fromOffset(134, 40), TextSize = 11, Parent = row, color = Color3.fromRGB(70, 40, 40) }, function()
				local t = {}
				for j, u in ipairs(d.team) do if j ~= i then table.insert(t, u) end end
				request("SetTeam", t)
			end)
			UI.button("<", { Size = UDim2.fromOffset(26, 22), Position = UDim2.fromOffset(214, 40), TextSize = 12, Parent = row }, function()
				if i > 1 then
					local t = table.clone(d.team)
					t[i], t[i - 1] = t[i - 1], t[i]
					request("SetTeam", t)
				end
			end)
		else
			UI.label("Freier Platz – wähle rechts einen Pal", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextSize = 13, color = T.dim, Parent = row })
		end
	end

	-- Pal-Liste (Mitte)
	local listP = UI.panel({ Size = UDim2.new(0.3, -6, 1, 0), Position = UDim2.new(0.38, 0, 0, 0), color = T.panel, Parent = content })
	local count = 0
	for _ in pairs(d.pals) do count += 1 end
	UI.label("Gefangene Pals (" .. count .. ")", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 15, Font = UI.Font, color = T.accent, Parent = listP })
	local sc = scroll(listP, { Size = UDim2.new(1, -12, 1, -36), Position = UDim2.fromOffset(6, 32) })
	UI.list(Enum.FillDirection.Vertical, 5).Parent = sc
	local sorted = {}
	for _, p in pairs(d.pals) do table.insert(sorted, p) end
	table.sort(sorted, function(a, b)
		local ra, rb = Elements.Rarities[Pals.Get(a.species).rarity].order, Elements.Rarities[Pals.Get(b.species).rarity].order
		if ra ~= rb then return ra > rb end
		return a.level > b.level
	end)
	if #sorted == 0 then
		UI.label("Noch keine Pals gefangen. Besiege einen Pal und wirf eine Fangkugel!", { Size = UDim2.new(1, -8, 0, 60), TextSize = 13, wrap = true, color = T.dim, Parent = sc })
	end
	for i, pal in ipairs(sorted) do
		local def = Pals.Get(pal.species)
		local inTeam = table.find(d.team, pal.uid) ~= nil
		local rName, rCol = rarityText(def)
		local row = UI.new("TextButton", { Text = "", Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = state.palSel == pal.uid and Color3.fromRGB(40, 70, 70) or T.panel2, AutoButtonColor = true, LayoutOrder = i, Parent = sc }, { UI.corner(8), UI.stroke(rCol, 1, 0.5) })
		local pf = UI.new("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.fromRGB(22, 30, 38), Parent = row }, { UI.corner(8) })
		Portraits.Make(pf, pal.species, "face")
		UI.label(def.name .. "  Lv " .. pal.level .. (pal.premium and "  ★" or ""), { Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -64, 0, 18), TextSize = 13, Font = UI.Font, Parent = row })
		UI.label(rName .. " • " .. Elements.List[def.element].name .. (def.ride and " • reitbar" or ""), { Position = UDim2.fromOffset(58, 22), Size = UDim2.new(1, -64, 0, 14), TextSize = 11, color = rCol, Parent = row })
		local b = UI.button(inTeam and "Im Team" or "Ins Team", { Size = UDim2.fromOffset(70, 18), Position = UDim2.fromOffset(58, 36), TextSize = 10, Parent = row, color = inTeam and T.panel or Color3.fromRGB(40, 90, 70) }, function()
			if inTeam then return end
			if #d.team >= 3 then setStatus(false, "Team ist voll – entferne zuerst einen Pal."); return end
			local t = table.clone(d.team)
			table.insert(t, pal.uid)
			request("SetTeam", t)
		end)
		b.AutoButtonColor = not inTeam
		row.Activated:Connect(function() state.palSel = pal.uid; Menus.Refresh() end)
	end

	-- Vergleich (rechts oben)
	local cmpP = UI.panel({ Size = UDim2.new(0.32, 0, 1, 0), Position = UDim2.new(0.68, 0, 0, 0), color = T.panel, Parent = content })
	UI.label("Vergleich", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 15, Font = UI.Font, color = T.accent, Parent = cmpP })
	local csc = scroll(cmpP, { Size = UDim2.new(1, -12, 1, -36), Position = UDim2.fromOffset(6, 32) })
	UI.list(Enum.FillDirection.Horizontal, 6).Parent = csc
	local activeUid = d.team[d.activeIndex]
	palCompareColumn(csc, "Ausgewählt", state.palSel and d.pals[state.palSel], 1)
	palCompareColumn(csc, "Aktiver Team-Pal", activeUid and d.pals[activeUid], 2)

	-- Waffen (unten links)
	local wP = UI.panel({ Size = UDim2.new(0.38, -6, 1, -258), Position = UDim2.fromOffset(0, 258), color = T.panel, Parent = content })
	UI.label("Waffen-Slots (1-3)", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 15, Font = UI.Font, color = T.accent, Parent = wP })
	local wsc = scroll(wP, { Size = UDim2.new(1, -12, 1, -34), Position = UDim2.fromOffset(6, 30) })
	UI.list(Enum.FillDirection.Vertical, 5).Parent = wsc
	for i, w in ipairs(Weapons.List()) do
		local owned = d.weapons[w.id]
		if owned then
			local lvl = owned.lvl or 0
			local slot = table.find(d.slots, w.id)
			local row = UI.panel({ Size = UDim2.new(1, -8, 0, 58), color = slot and Color3.fromRGB(36, 60, 70) or T.panel2, LayoutOrder = i, Parent = wsc, radius = 8 })
			UI.label(w.name .. (lvl > 0 and (" +" .. lvl) or "") .. (slot and ("  [Slot " .. slot .. (d.equippedSlot == slot and ", ausgerüstet" or "") .. "]") or ""), { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 18), TextSize = 13, Font = UI.Font, color = w.color, Parent = row })
			UI.label(string.format("%d Schaden%s • %.1f/s • %dm • Mag %d • %.1fs • DPS %d", math.floor(Formulas.WeaponDamage(w.id, lvl) + 0.5), w.pellets > 1 and ("×" .. w.pellets) or "", w.fireRate, w.range, w.magazine, w.reload, math.floor(Formulas.WeaponDps(w.id, lvl))),
				{ Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 14), TextSize = 10, color = T.dim, Parent = row })
			for s = 1, 3 do
				UI.button("Slot " .. s, { Size = UDim2.fromOffset(44, 18), Position = UDim2.fromOffset(8 + (s - 1) * 48, 36), TextSize = 10, Parent = row, color = d.slots[s] == w.id and Color3.fromRGB(40, 90, 70) or T.panel }, function()
					request("SetSlot", s, w.id)
				end)
			end
			if slot then
				UI.button("Ablegen", { Size = UDim2.fromOffset(60, 18), Position = UDim2.fromOffset(156, 36), TextSize = 10, Parent = row, color = Color3.fromRGB(70, 40, 40) }, function()
					request("SetSlot", slot, "")
				end)
			end
		end
	end
end

------------------------------------------------------------------ Shop
local function shopCard(parent, order, height)
	local f = UI.panel({ Size = UDim2.new(1, -10, 0, height or 92), color = T.panel2, LayoutOrder = order, Parent = parent, radius = 10 })
	return f
end

local function buildShop()
	local d = ClientState.Data
	if not d then return end
	local cats = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = content }, { UI.list(Enum.FillDirection.Horizontal, 8) })
	for i, c in ipairs({ { "weapons", "Waffen & Tuning" }, { "balls", "Fangkugeln" }, { "robux", "Robux-Angebote" } }) do
		UI.button(c[2], { Name = "Cat_" .. c[1], Size = UDim2.fromOffset(170, 32), LayoutOrder = i, Parent = cats, color = state.shopCat == c[1] and Color3.fromRGB(40, 90, 80) or T.panel2 }, function()
			state.shopCat = c[1]
			Menus.Refresh()
		end)
	end
	UI.label("Guthaben: " .. Formulas.FormatMoney(d.money), { Size = UDim2.fromOffset(240, 32), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), TextSize = 18, Font = UI.Font, color = T.gold, align = Enum.TextXAlignment.Right, Parent = content })
	local sc = scroll(content, { Size = UDim2.new(1, 0, 1, -42), Position = UDim2.fromOffset(0, 42) })
	UI.list(Enum.FillDirection.Vertical, 8).Parent = sc

	if state.shopCat == "weapons" then
		UI.label("Stärkere Waffen kaufen und mit Gold verbessern (Tuning: je +" .. math.floor(Weapons.UpgradeBonusPerLevel * 100) .. " % Schaden, max. Stufe " .. Weapons.MaxUpgrade .. ").", { Size = UDim2.new(1, -10, 0, 20), TextSize = 13, color = T.dim, Parent = sc, LayoutOrder = 0 })
		for i, w in ipairs(Weapons.List()) do
			local owned = d.weapons[w.id]
			local lvl = owned and owned.lvl or 0
			local card = shopCard(sc, i, 96)
			UI.label(w.name .. "  •  " .. w.archetype .. (lvl > 0 and ("  •  Tuning +" .. lvl) or ""), { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -230, 0, 20), TextSize = 16, Font = UI.Font, color = w.color, Parent = card })
			UI.label(w.desc, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -230, 0, 32), TextSize = 12, wrap = true, valign = Enum.TextYAlignment.Top, Parent = card })
			UI.label(string.format("Schaden %d%s • Feuerrate %.1f/s • Reichweite %d • Magazin %d • Nachladen %.1fs • Kopftreffer ×%.1f • DPS %d", math.floor(Formulas.WeaponDamage(w.id, lvl) + 0.5), w.pellets > 1 and (" ×" .. w.pellets) or "", w.fireRate, w.range, w.magazine, w.reload, w.weakspot, math.floor(Formulas.WeaponDps(w.id, lvl))),
				{ Position = UDim2.fromOffset(12, 64), Size = UDim2.new(1, -230, 0, 24), TextSize = 11, color = T.dim, wrap = true, Parent = card })
			if not owned then
				if w.price then
					UI.button("Kaufen  " .. Formulas.FormatMoney(w.price), { Size = UDim2.fromOffset(200, 36), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), Parent = card, color = d.money >= w.price and Color3.fromRGB(40, 100, 70) or T.panel }, function()
						request("BuyWeapon", w.id)
					end)
				else
					UI.label("Belohnung: " .. (w.rewardFrom or "?"), { Size = UDim2.fromOffset(200, 36), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), TextSize = 13, Font = UI.Font, color = T.gold, align = Enum.TextXAlignment.Right, Parent = card })
				end
			else
				UI.label("Im Besitz", { Size = UDim2.fromOffset(200, 20), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0), TextSize = 13, Font = UI.Font, color = T.good, align = Enum.TextXAlignment.Right, Parent = card })
				if lvl < Weapons.MaxUpgrade then
					local cost = w.upgradeCosts[lvl + 1]
					UI.button("Tuning +" .. (lvl + 1) .. "  " .. Formulas.FormatMoney(cost), { Size = UDim2.fromOffset(200, 34), Position = UDim2.new(1, -12, 0, 32), AnchorPoint = Vector2.new(1, 0), Parent = card, color = d.money >= cost and Color3.fromRGB(40, 100, 70) or T.panel }, function()
						request("UpgradeWeapon", w.id)
					end)
				else
					UI.label("Maximal verbessert", { Size = UDim2.fromOffset(200, 20), Position = UDim2.new(1, -12, 0, 36), AnchorPoint = Vector2.new(1, 0), TextSize = 12, color = T.dim, align = Enum.TextXAlignment.Right, Parent = card })
				end
			end
		end
	elseif state.shopCat == "balls" then
		local info = shopCard(sc, 0, 120)
		UI.label("So funktioniert die Fangchance", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 15, Font = UI.Font, color = T.accent, Parent = info })
		UI.label("Chance = Fangrate der Art × Kugel-Multiplikator × Level-Faktor (−2 % pro Level) × Luck-Boost.  Begrenzt auf " .. math.floor(Spheres.MinChance * 100) .. "–" .. math.floor(Spheres.MaxChance * 100) .. " %.  Nur besiegte (geschwächte) Pals können gefangen werden – seltene und Alpha-Pals sind deutlich schwerer. Eine bessere Kugel erhöht die Chance, garantiert den Fang aber nie.", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 86), TextSize = 12, wrap = true, valign = Enum.TextYAlignment.Top, Parent = info })
		local examples = { "gackerling", "moosbock", "flauschfunk", "surrfluegel", "moosbock_alpha" }
		for _, t in ipairs(Spheres.Tiers) do
			local card = shopCard(sc, t.tier, 96)
			local ball = UI.new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(12, 20), BackgroundColor3 = t.color, Parent = card }, { UI.corner(26), UI.stroke(t.band, 4, 0) })
			UI.label(string.format("Stufe %d: %s  •  ×%.1f", t.tier, t.name, t.mult), { Position = UDim2.fromOffset(78, 6), Size = UDim2.new(1, -300, 0, 20), TextSize = 15, Font = UI.Font, Parent = card })
			UI.label(t.desc, { Position = UDim2.fromOffset(78, 26), Size = UDim2.new(1, -300, 0, 18), TextSize = 12, Parent = card })
			local ex = {}
			for _, sid in ipairs(examples) do
				local def = Pals.Get(sid)
				table.insert(ex, def.name .. " " .. math.floor(Formulas.CatchChance(sid, 5, t.tier, 1) * 100 + 0.5) .. "%")
			end
			UI.label("Beispiele (Lv 5): " .. table.concat(ex, " • "), { Position = UDim2.fromOffset(78, 46), Size = UDim2.new(1, -300, 0, 40), TextSize = 11, color = T.dim, wrap = true, valign = Enum.TextYAlignment.Top, Parent = card })
			local pos = UDim2.new(1, -12, 0, 28)
			if t.tier <= d.ballTier then
				UI.label(t.tier == d.ballTier and "AKTIV" or "Freigeschaltet", { Size = UDim2.fromOffset(200, 30), Position = pos, AnchorPoint = Vector2.new(1, 0), TextSize = 15, Font = UI.Font, color = T.good, align = Enum.TextXAlignment.Right, Parent = card })
			elseif t.tier == d.ballTier + 1 then
				UI.button("Freischalten  " .. Formulas.FormatMoney(t.price), { Size = UDim2.fromOffset(200, 36), Position = pos, AnchorPoint = Vector2.new(1, 0), Parent = card, color = d.money >= t.price and Color3.fromRGB(40, 100, 70) or T.panel }, function()
					request("BuyBall", t.tier)
				end)
			else
				UI.label("Erst Stufe " .. (t.tier - 1) .. " • " .. Formulas.FormatMoney(t.price), { Size = UDim2.fromOffset(200, 30), Position = pos, AnchorPoint = Vector2.new(1, 0), TextSize = 13, color = T.dim, align = Enum.TextXAlignment.Right, Parent = card })
			end
		end
	else
		local note = shopCard(sc, 0, 56)
		UI.label("Robux-Käufe laufen über den offiziellen Roblox-Kaufdialog und werden serverseitig geprüft. Boost-Dauer: " .. math.floor(Shop.DefaultBoostDurationSeconds / 60) .. " Minuten Echtzeit pro Kauf (vorläufiger, konfigurierbarer Standard). Mehrere Käufe verlängern die Laufzeit.",
			{ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), TextSize = 12, wrap = true, color = T.dim, Parent = note })
		for i, id in ipairs(Shop.BoostOrder) do
			local b = Shop.Boosts[id]
			local card = shopCard(sc, i, 92)
			UI.stroke(b.color, 1.5, 0.3).Parent = card
			UI.label(b.name .. "   •   " .. b.robux .. " Robux", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -240, 0, 22), TextSize = 17, Font = UI.Font, color = b.color, Parent = card })
			UI.label(b.desc, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -240, 0, 34), TextSize = 12, wrap = true, valign = Enum.TextYAlignment.Top, Parent = card })
			local rem = ClientState.BoostRemaining(id)
			UI.label(rem > 0 and ("Aktiv – noch " .. Formulas.FormatTime(rem)) or ("Dauer: " .. math.floor(Shop.BoostDuration(id) / 60) .. " Min."), { Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -240, 0, 18), TextSize = 12, Font = UI.Font, color = rem > 0 and T.good or T.dim, Parent = card })
			local configured = Shop.IsConfigured(id)
			local btn = UI.button(configured and ("Kaufen – " .. b.robux .. " R$") or "Nicht konfiguriert", { Size = UDim2.fromOffset(210, 38), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = card, color = configured and Color3.fromRGB(40, 100, 70) or Color3.fromRGB(60, 50, 50) }, function()
				request("BuyBoost", id)
			end)
			btn.AutoButtonColor = configured
		end
		-- Premium
		local p = Shop.Premium
		local card = shopCard(sc, 10, 170)
		UI.stroke(T.premium, 2, 0.1).Parent = card
		local pf = UI.new("Frame", { Size = UDim2.fromOffset(150, 150), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(22, 26, 46), Parent = card }, { UI.corner(10) })
		local curWorld = math.min(d.worldsUnlocked, 3)
		local sid = nil
		for w = curWorld, 1, -1 do if p.perWorld[w] and Pals.Get(p.perWorld[w]) then sid = p.perWorld[w]; break end end
		Portraits.Make(pf, sid or "noxen", "full")
		local def = Pals.Get(sid or "noxen")
		UI.label(p.name .. "   •   " .. p.robux .. " Robux", { Position = UDim2.fromOffset(172, 8), Size = UDim2.new(1, -400, 0, 22), TextSize = 17, Font = UI.Font, color = T.premium, Parent = card })
		UI.label("Aktuell: " .. def.name .. " (Welt " .. def.premiumWorld .. ") • " .. Elements.List[def.element].name .. " • Flugreittier • Sternenregen + Mondlanze", { Position = UDim2.fromOffset(172, 32), Size = UDim2.new(1, -400, 0, 18), TextSize = 12, Font = UI.Font, Parent = card })
		UI.label(p.desc, { Position = UDim2.fromOffset(172, 52), Size = UDim2.new(1, -400, 0, 60), TextSize = 12, wrap = true, valign = Enum.TextYAlignment.Top, Parent = card })
		local fut = {}
		for _, c in ipairs(Pals.FutureConcepts) do table.insert(fut, "Welt " .. c.world .. ": " .. c.name) end
		UI.label("Vorbereitete Upgrades (noch nicht spielbar): " .. table.concat(fut, " • "), { Position = UDim2.fromOffset(172, 116), Size = UDim2.new(1, -400, 0, 40), TextSize = 11, wrap = true, color = T.dim, valign = Enum.TextYAlignment.Top, Parent = card })
		local configured = Shop.PremiumConfigured()
		local label = d.premium and "Freigeschaltet" or (configured and ("Kaufen – " .. p.robux .. " R$") or "Nicht konfiguriert")
		local btn = UI.button(label, { Size = UDim2.fromOffset(210, 40), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = card, color = d.premium and Color3.fromRGB(60, 50, 90) or (configured and Color3.fromRGB(90, 60, 140) or Color3.fromRGB(60, 50, 50)) }, function()
			if d.premium then return end
			request("BuyPremium")
		end)
		btn.AutoButtonColor = configured and not d.premium
	end
end

------------------------------------------------------------------ Fenster
local Pages = { catalog = buildCatalog, equipment = buildEquipment, shop = buildShop }
local Titles = { catalog = "Pal-Katalog", equipment = "Ausrüstung", shop = "Shop" }

function Menus.Refresh()
	if not current or not content then return end
	clear(content)
	local ok, err = pcall(Pages[current])
	if not ok then
		warn("[Menus] " .. tostring(err))
		UI.label("Fehler beim Anzeigen – bitte erneut öffnen.", { TextSize = 14, color = T.warn, Parent = content })
	end
	for k, b in pairs(tabButtons) do b.BackgroundColor3 = (k == current) and Color3.fromRGB(40, 90, 80) or T.panel2 end
end

function Menus.Open(name)
	if current == name then Menus.Close(); return end
	current = name
	window.Visible = true
	modal.Visible = true
	statusLabel.Text = ""
	if WC then WC.SetBlocked(true) end
	if HUD then HUD.SetMenuOpen(true) end
	Menus.Refresh()
end

function Menus.Close()
	current = nil
	if window then window.Visible = false end
	if modal then modal.Visible = false end
	if WC then WC.SetBlocked(false) end
	if HUD then HUD.SetMenuOpen(false) end
end

function Menus.IsOpen() return current ~= nil end

function Menus.Init(weaponController, hud)
	WC, HUD = weaponController, hud
	gui = UI.new("ScreenGui", { Name = "ParlMenus", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
	-- Modal-Knopf gibt im First-Person-Modus die Maus frei
	modal = UI.new("TextButton", { Name = "Modal", Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Modal = true, Visible = false, AutoButtonColor = false, Parent = gui })
	window = UI.panel({ Name = "Window", Size = UDim2.new(0.86, 0, 0.84, 0), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), color = T.bg, transparency = 0.04, Parent = gui, Visible = false, strokeColor = T.accent })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(1180, 720), MinSize = Vector2.new(620, 400), Parent = window })
	local header = UI.new("Frame", { Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1, Parent = window }, { UI.list(Enum.FillDirection.Horizontal, 8) })
	tabButtons = {}
	for i, k in ipairs({ "catalog", "equipment", "shop" }) do
		tabButtons[k] = UI.button(Titles[k], { Size = UDim2.fromOffset(150, 38), LayoutOrder = i, TextSize = 16, Parent = header }, function()
			current = k
			Menus.Refresh()
		end)
	end
	UI.button("X", { Size = UDim2.fromOffset(40, 38), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0), TextSize = 18, Parent = window, color = Color3.fromRGB(80, 40, 40) }, Menus.Close)
	statusLabel = UI.label("", { Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 12, 1, -26), TextSize = 13, Font = UI.Font, Parent = window })
	content = UI.new("Frame", { Name = "Content", Size = UDim2.new(1, -24, 1, -90), Position = UDim2.fromOffset(12, 58), BackgroundTransparency = 1, Parent = window })

	ClientState.Changed:Connect(function() if current then Menus.Refresh() end end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp and input.KeyCode ~= Enum.KeyCode.Tab then return end
		local kc = input.KeyCode
		if kc == Enum.KeyCode.Tab or kc == Enum.KeyCode.ButtonSelect then Menus.Open("equipment")
		elseif kc == Enum.KeyCode.P then Menus.Open("catalog")
		elseif kc == Enum.KeyCode.B then Menus.Open("shop")
		elseif kc == Enum.KeyCode.Escape and current then Menus.Close()
		end
	end)
	hud.OpenMenu = Menus.Open
end

return Menus
