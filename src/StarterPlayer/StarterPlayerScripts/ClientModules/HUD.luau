--[[
	HUD (Client): Fadenkreuz, Treffer-Feedback, Munition/Nachladen, Leben, Geld, Boosts,
	Tutorial-Tracker, Team-Panel, Bossleiste, Kreaturen-Labels, Meldungen, Banner, Mobil-Knöpfe.
	Zeigt nur Server-Zustände an – nichts wird lokal "vorgetäuscht".
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pals = require(Shared.Config.Pals)
local Weapons = require(Shared.Config.Weapons)
local Elements = require(Shared.Config.Elements)
local Spheres = require(Shared.Config.Spheres)
local Shop = require(Shared.Config.Shop)
local Progression = require(Shared.Config.Progression)
local Formulas = require(Shared.Formulas)

local UI = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local VFX = require(script.Parent.VFX)

local HUD = {}
local player = Players.LocalPlayer
local T = UI.Theme
local WC -- WeaponController (in Init gesetzt)
local gui
local refs = {}

------------------------------------------------------------------ Aufbau
local function crosshair(parent)
	local holder = UI.new("Frame", { Name = "Crosshair", Size = UDim2.fromOffset(80, 80), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = parent })
	local lines = {}
	for i, d in ipairs({ Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) }) do
		local l = UI.new("Frame", { Size = d.X == 0 and UDim2.fromOffset(2, 9) or UDim2.fromOffset(9, 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = holder }, { UI.stroke(Color3.new(0, 0, 0), 1, 0.5) })
		lines[i] = { frame = l, dir = d }
	end
	UI.new("Frame", { Size = UDim2.fromOffset(3, 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = holder }, { UI.corner(2) })
	-- Hitmarker
	local hm = UI.new("Frame", { Name = "Hitmarker", Size = UDim2.fromOffset(34, 34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = holder, Visible = false })
	local hmLines = {}
	for _, a in ipairs({ 45, 135, 225, 315 }) do
		local r = math.rad(a)
		local l = UI.new("Frame", { Size = UDim2.fromOffset(11, 3), Position = UDim2.new(0.5, math.cos(r) * 11, 0.5, math.sin(r) * 11), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = a, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = hm }, { UI.stroke(Color3.new(0, 0, 0), 1, 0.4) })
		table.insert(hmLines, l)
	end
	refs.cross = holder
	refs.crossLines = lines
	refs.hitmarker = hm
	refs.hmLines = hmLines
end

local function build()
	gui = UI.new("ScreenGui", { Name = "ParlHUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	HUD.Gui = gui

	-- Treffer-Vignette
	refs.hurt = UI.new("CanvasGroup", { Name = "Hurt", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Parent = gui })
	for _, e in ipairs({
		{ UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90 }, { UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), 270 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0 }, { UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180 },
	}) do
		local f = UI.new("Frame", { Size = e[1], Position = e[2], BackgroundColor3 = Color3.fromRGB(230, 20, 20), BorderSizePixel = 0, Parent = refs.hurt })
		UI.new("UIGradient", { Rotation = e[3], Transparency = NumberSequence.new(0.15, 1), Parent = f })
	end
	refs.hurtDir = UI.new("Frame", { Name = "HurtDir", Size = UDim2.fromOffset(260, 260), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	refs.hurtArrow = UI.new("Frame", { Size = UDim2.fromOffset(70, 8), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 60, 50), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = refs.hurtDir }, { UI.corner(4) })

	-- Zielfernrohr
	refs.scope = UI.new("Frame", { Name = "Scope", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local ring = UI.new("Frame", { Size = UDim2.fromScale(0.62, 0.62), SizeConstraint = Enum.SizeConstraint.RelativeYY, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = refs.scope }, { UI.corner(1000), UI.new("UIStroke", { Thickness = 900, Color = Color3.fromRGB(8, 8, 12), Transparency = 0.02 }) })
	UI.new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = ring })
	UI.new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = ring })
	UI.new("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 60, 60), BorderSizePixel = 0, Parent = ring }, { UI.corner(2) })

	crosshair(gui)

	-- Hinweis unter dem Fadenkreuz (Nachladen / Fangchance)
	refs.centerHint = UI.label("", { Size = UDim2.fromOffset(420, 26), Position = UDim2.new(0.5, 0, 0.5, 52), AnchorPoint = Vector2.new(0.5, 0), align = Enum.TextXAlignment.Center, Font = UI.Font, TextSize = 18, strokeT = 0.3, Parent = gui })
	refs.centerSub = UI.label("", { Size = UDim2.fromOffset(460, 20), Position = UDim2.new(0.5, 0, 0.5, 76), AnchorPoint = Vector2.new(0.5, 0), align = Enum.TextXAlignment.Center, TextSize = 14, color = T.dim, strokeT = 0.4, Parent = gui })

	-- Unten links: Leben + Boosts
	local hp = UI.panel({ Name = "Health", Size = UDim2.fromOffset(300, 64), Position = UDim2.new(0, 18, 1, -18), AnchorPoint = Vector2.new(0, 1), Parent = gui })
	UI.label("LEBEN", { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(100, 18), TextSize = 13, color = T.dim, Font = UI.Font, Parent = hp })
	refs.hpText = UI.label("100", { Position = UDim2.new(1, -14, 0, 6), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(120, 18), TextSize = 15, align = Enum.TextXAlignment.Right, Font = UI.Font, Parent = hp })
	local _, fill = UI.bar(hp, { Size = UDim2.new(1, -28, 0, 16), Position = UDim2.fromOffset(14, 32), color = T.good })
	refs.hpFill = fill

	refs.boosts = UI.new("Frame", { Name = "Boosts", Size = UDim2.fromOffset(300, 30), Position = UDim2.new(0, 18, 1, -90), AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Parent = gui }, { UI.list(Enum.FillDirection.Horizontal, 6) })

	-- Unten rechts: Waffe + Munition + Hotbar
	local wp = UI.panel({ Name = "Weapon", Size = UDim2.fromOffset(330, 112), Position = UDim2.new(1, -18, 1, -18), AnchorPoint = Vector2.new(1, 1), Parent = gui })
	refs.wName = UI.label("", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 20), TextSize = 17, Font = UI.Font, Parent = wp })
	refs.wInfo = UI.label("", { Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 16), TextSize = 12, color = T.dim, Parent = wp })
	refs.ammo = UI.label("", { Position = UDim2.new(1, -14, 0, 4), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(140, 40), TextSize = 32, Font = UI.Font, align = Enum.TextXAlignment.Right, rich = true, Parent = wp })
	local rb, rf = UI.bar(wp, { Size = UDim2.new(1, -28, 0, 5), Position = UDim2.fromOffset(14, 50), color = T.gold })
	refs.reloadBar, refs.reloadFill = rb, rf
	refs.hotbar = UI.new("Frame", { Size = UDim2.new(1, -28, 0, 44), Position = UDim2.fromOffset(14, 60), BackgroundTransparency = 1, Parent = wp }, { UI.list(Enum.FillDirection.Horizontal, 6) })
	refs.slots = {}
	for i = 1, 4 do
		local s = UI.button("", { Size = UDim2.fromOffset(70, 44), TextSize = 11, LayoutOrder = i, Parent = refs.hotbar }, function()
			if i == 4 then WC.SelectBall() else WC.SelectSlot(i) end
		end)
		s.TextYAlignment = Enum.TextYAlignment.Bottom
		UI.label(tostring(i), { Size = UDim2.fromOffset(16, 14), Position = UDim2.fromOffset(4, 2), TextSize = 11, color = T.dim, Font = UI.Font, Parent = s })
		UI.new("UIPadding", { PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), Parent = s })
		refs.slots[i] = s
	end

	-- Oben rechts: Geld + Menüköpfe
	local top = UI.panel({ Name = "Top", Size = UDim2.fromOffset(420, 48), Position = UDim2.new(1, -18, 0, 14), AnchorPoint = Vector2.new(1, 0), Parent = gui })
	refs.money = UI.label("0 G", { Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(130, 48), TextSize = 22, Font = UI.Font, color = T.gold, Parent = top })
	local btns = UI.new("Frame", { Size = UDim2.new(0, 270, 1, -12), Position = UDim2.new(1, -8, 0, 6), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = top }, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
	refs.menuButtons = {}
	for i, m in ipairs({ { "Katalog [P]", "catalog" }, { "Ausrüstung [Tab]", "equipment" }, { "Shop [B]", "shop" } }) do
		refs.menuButtons[m[2]] = UI.button(m[1], { Size = UDim2.fromOffset(i == 2 and 104 or 80, 36), TextSize = 12, LayoutOrder = i, Parent = btns, color = i == 3 and Color3.fromRGB(70, 60, 30) or T.panel2 }, function()
			if HUD.OpenMenu then HUD.OpenMenu(m[2]) end
		end)
	end

	-- Oben links: Tutorial / Ziele
	local q = UI.panel({ Name = "Quest", Size = UDim2.fromOffset(340, 104), Position = UDim2.fromOffset(18, 14), Parent = gui })
	refs.questPanel = q
	refs.qTitle = UI.label("", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 20), TextSize = 15, Font = UI.Font, color = T.accent, Parent = q })
	refs.qText = UI.label("", { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 50), TextSize = 13, wrap = true, valign = Enum.TextYAlignment.Top, Parent = q })
	refs.qSkip = UI.button("Tutorial überspringen", { Size = UDim2.fromOffset(150, 20), Position = UDim2.new(1, -10, 1, -6), AnchorPoint = Vector2.new(1, 1), TextSize = 11, Parent = q, color = T.panel }, function()
		ClientState.Request("SkipTutorial")
	end)

	-- Links Mitte: Team
	local tp = UI.panel({ Name = "Team", Size = UDim2.fromOffset(260, 96), Position = UDim2.new(0, 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = gui })
	refs.teamName = UI.label("Kein Team-Pal", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 15, Font = UI.Font, Parent = tp })
	refs.teamSub = UI.label("", { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 16), TextSize = 12, color = T.dim, Parent = tp })
	local _, tf = UI.bar(tp, { Size = UDim2.new(1, -24, 0, 8), Position = UDim2.fromOffset(12, 46), color = T.accent })
	refs.teamFill = tf
	refs.teamKeys = UI.label("Q rufen/zurück  •  C wechseln  •  G reiten", { Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 26), TextSize = 11, color = T.dim, wrap = true, Parent = tp })

	-- Oben Mitte: Bossleiste
	local bb = UI.panel({ Name = "Boss", Size = UDim2.fromOffset(560, 58), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = gui, strokeColor = Color3.fromRGB(150, 255, 90) })
	refs.boss = bb
	refs.bossName = UI.label("", { Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 22), TextSize = 17, Font = UI.Font, align = Enum.TextXAlignment.Center, Parent = bb })
	local _, bf = UI.bar(bb, { Size = UDim2.new(1, -28, 0, 16), Position = UDim2.fromOffset(14, 32), color = Color3.fromRGB(130, 230, 80) })
	refs.bossFill = bf

	-- Meldungen (rechts)
	refs.toasts = UI.new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(380, 400), Position = UDim2.new(1, -18, 0, 76), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui }, { UI.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right) })

	-- Banner + Countdown
	refs.banner = UI.panel({ Name = "Banner", Size = UDim2.fromOffset(640, 110), Position = UDim2.new(0.5, 0, 0.24, 0), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = gui, strokeColor = T.gold, strokeThickness = 2 })
	refs.bTitle = UI.label("", { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 40), TextSize = 34, Font = UI.Font, align = Enum.TextXAlignment.Center, color = T.gold, Parent = refs.banner })
	refs.bText = UI.label("", { Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 0, 44), TextSize = 15, align = Enum.TextXAlignment.Center, wrap = true, Parent = refs.banner })
	refs.count = UI.label("", { Size = UDim2.fromOffset(300, 120), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 90, Font = UI.Font, align = Enum.TextXAlignment.Center, color = T.gold, strokeT = 0.2, Parent = gui })

	-- Steuerungshinweis
	refs.help = UI.label("WASD laufen • Shift sprinten • Maus zielen • LMB schießen • RMB Visier • R nachladen • 1-3 Waffen • 4/F Fangkugel • Q Pal • G reiten • E interagieren", {
		Size = UDim2.fromOffset(760, 18), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), TextSize = 12, color = T.dim, align = Enum.TextXAlignment.Center, strokeT = 0.6, Parent = gui })

	if UI.IsTouch() then HUD.BuildTouch() end
end

------------------------------------------------------------------ Mobile Steuerung
function HUD.BuildTouch()
	refs.help.Visible = false
	local holder = UI.new("Frame", { Name = "Touch", Size = UDim2.fromOffset(330, 300), Position = UDim2.new(1, -16, 1, -140), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = gui })
	local function tb(text, pos, size, color, down, up)
		local b = UI.new("TextButton", { Text = text, Font = UI.Font, TextSize = 14, TextColor3 = T.text, BackgroundColor3 = color or T.panel2, BackgroundTransparency = 0.25, Size = UDim2.fromOffset(size, size), Position = pos, AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = true, Parent = holder }, { UI.corner(size), UI.stroke(T.stroke, 1.5, 0.3) })
		b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then down() end end)
		if up then b.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then up() end end) end
		return b
	end
	tb("FEUER", UDim2.fromOffset(250, 220), 96, Color3.fromRGB(150, 60, 50), function() WC.TriggerDown() end, function() WC.TriggerUp() end)
	tb("ZIEL", UDim2.fromOffset(150, 250), 62, nil, function() WC.SetAim(not WC.Aiming) end)
	tb("R", UDim2.fromOffset(300, 120), 54, nil, function() WC.Reload() end)
	tb("KUGEL", UDim2.fromOffset(210, 120), 58, Color3.fromRGB(60, 110, 160), function() WC.Throw() end)
	tb("PAL", UDim2.fromOffset(120, 160), 54, Color3.fromRGB(50, 120, 90), function() if HUD.Action then HUD.Action("Summon") end end)
	tb("REITEN", UDim2.fromOffset(60, 220), 54, nil, function() if HUD.Action then HUD.Action("Mount") end end)
	tb("WAFFE", UDim2.fromOffset(300, 40), 48, nil, function() WC.CycleSlot(1) end)
end

------------------------------------------------------------------ Feedback
function HUD.Notify(text, kind)
	if not gui then return end
	local col = ({ warn = T.warn, money = T.gold, catch = T.good, premium = T.premium, dialog = Color3.fromRGB(150, 210, 255), reward = T.gold, tutorial = T.accent, discover = Color3.fromRGB(150, 230, 255), level = T.good })[kind] or T.text
	local f = UI.panel({ Size = UDim2.fromOffset(380, 0), Parent = refs.toasts, transparency = 0.12, strokeColor = col })
	f.AutomaticSize = Enum.AutomaticSize.Y
	UI.pad(10).Parent = f
	local l = UI.label(text, { Size = UDim2.new(1, 0, 0, 0), TextSize = 14, wrap = true, color = col, auto = Enum.AutomaticSize.Y, Font = (kind == "dialog" and UI.FontMed or UI.Font), Parent = f })
	local kids = refs.toasts:GetChildren()
	local frames = {}
	for _, c in ipairs(kids) do if c:IsA("Frame") then table.insert(frames, c) end end
	if #frames > 6 then frames[1]:Destroy() end
	if kind == "money" then VFX.Sound("coin", nil, 0.6) end
	task.delay(kind == "dialog" and 7 or 4.5, function()
		if f.Parent then
			UI.tween(f, 0.4, { BackgroundTransparency = 1 })
			UI.tween(l, 0.4, { TextTransparency = 1 })
			Debris:AddItem(f, 0.45)
		end
	end)
end

function HUD.banner(data)
	refs.bTitle.Text = data.title or ""
	refs.bText.Text = data.text or ""
	refs.banner.Visible = true
	refs.banner.Size = UDim2.fromOffset(600, 100)
	UI.tween(refs.banner, 0.3, { Size = UDim2.fromOffset(660, 112) }, Enum.EasingStyle.Back)
	local my = {}
	refs.bannerToken = my
	VFX.Sound(data.victory and "sparkle" or "airBurst", nil, 0.7)
	task.delay(6, function() if refs.bannerToken == my then refs.banner.Visible = false end end)
end

function HUD.countdown(data)
	task.spawn(function()
		HUD.Notify(data.title or "", "reward")
		for i = data.seconds or 3, 1, -1 do
			refs.count.Text = tostring(i)
			refs.count.TextTransparency = 0
			UI.tween(refs.count, 0.9, { TextTransparency = 0.8 })
			task.wait(1)
		end
		refs.count.Text = "LOS!"
		refs.count.TextTransparency = 0
		UI.tween(refs.count, 0.8, { TextTransparency = 1 })
	end)
end

function HUD.hurt(data)
	refs.hurt.GroupTransparency = 0.2
	UI.tween(refs.hurt, 0.55, { GroupTransparency = 1 })
	if data.from then
		local cam = workspace.CurrentCamera
		local rel = cam.CFrame:PointToObjectSpace(data.from)
		local ang = math.deg(math.atan2(rel.X, -rel.Z))
		refs.hurtDir.Rotation = ang
		refs.hurtArrow.BackgroundTransparency = 0.1
		UI.tween(refs.hurtArrow, 0.9, { BackgroundTransparency = 1 })
	end
	VFX.Sound("playerHurt", nil, 0.5)
	if WC then WC.Shake(0.4) end
end

-- Treffer-Bestätigung vom Server
function HUD.OnHit(data)
	local anyWeak, anyKill, any = false, false, false
	for _, h in ipairs(data.hits or {}) do
		if h.dmg and h.dmg > 0 then
			any = true
			anyWeak = anyWeak or h.weak
			anyKill = anyKill or h.kill
			HUD.DamageNumber(h.pos, h.dmg, h.weak, h.kill)
		elseif h.downed then
			HUD.DamageNumber(h.pos, nil, false, false, "Geschwächt – Fangkugel!")
		end
	end
	if not any then return end
	local col = anyKill and Color3.fromRGB(255, 70, 60) or (anyWeak and Color3.fromRGB(255, 215, 60) or Color3.new(1, 1, 1))
	for _, l in ipairs(refs.hmLines) do l.BackgroundColor3 = col; l.BackgroundTransparency = 0 end
	refs.hitmarker.Visible = true
	refs.hitmarker.Size = UDim2.fromOffset(anyKill and 46 or 34, anyKill and 46 or 34)
	local tok = {}
	refs.hmTok = tok
	for _, l in ipairs(refs.hmLines) do UI.tween(l, 0.25, { BackgroundTransparency = 1 }) end
	task.delay(0.26, function() if refs.hmTok == tok then refs.hitmarker.Visible = false end end)
	VFX.Sound(anyWeak and "weakHit" or "hit", nil, 0.7)
end

function HUD.DamageNumber(pos, dmg, weak, kill, text)
	if not pos then return end
	local a = VFX.Part({ size = Vector3.new(0.2, 0.2, 0.2), cf = CFrame.new(pos + Vector3.new(math.random(-10, 10) / 10, 1, 0)), t = 1, life = 1.1 })
	local bb = UI.new("BillboardGui", { Size = UDim2.fromOffset(160, 40), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 300, Parent = a })
	local l = UI.label(text or tostring(dmg), { Size = UDim2.fromScale(1, 1), TextSize = text and 16 or (weak and 30 or 22), Font = UI.Font, align = Enum.TextXAlignment.Center, color = text and T.accent or (kill and Color3.fromRGB(255, 90, 70) or (weak and Color3.fromRGB(255, 215, 60) or Color3.new(1, 1, 1))), strokeT = 0.2, Parent = bb })
	if weak and not text then l.Text = dmg .. "!" end
	UI.tween(bb, 1, { StudsOffset = Vector3.new(0, 3, 0) })
	task.delay(0.5, function() UI.tween(l, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 }) end)
end

------------------------------------------------------------------ Kreaturen-Labels
local labels = {}

local function makeLabel(model)
	local species = model:GetAttribute("Species")
	local def = species and Pals.Get(species)
	local root = model.PrimaryPart
	if not def or not root then return end
	local ext = model:GetExtentsSize()
	local bb = UI.new("BillboardGui", { Name = "ParlLabel", Size = UDim2.fromOffset(190, 62), StudsOffsetWorldSpace = Vector3.new(0, ext.Y * 0.5 + 1.8, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = def.isBoss and 0 or 95, Enabled = false, Parent = root })
	local rar = Elements.Rarities[def.rarity]
	local el = Elements.List[def.element]
	local name = UI.label("", { Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Font = UI.Font, align = Enum.TextXAlignment.Center, strokeT = 0.35, rich = true, Parent = bb })
	local bg, fill = UI.bar(bb, { Size = UDim2.new(0.8, 0, 0, 7), Position = UDim2.new(0.1, 0, 0, 21), color = T.good })
	local st = UI.label("", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 30), TextSize = 12, Font = UI.Font, align = Enum.TextXAlignment.Center, strokeT = 0.35, Parent = bb })
	local sub = UI.label("", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 46), TextSize = 11, align = Enum.TextXAlignment.Center, color = T.dim, strokeT = 0.5, Parent = bb })
	labels[model] = { bb = bb, name = name, fill = fill, st = st, sub = sub, def = def, rar = rar, el = el, root = root, lastHp = nil, lastHit = 0 }
	model:GetAttributeChangedSignal("HitTick"):Connect(function() if labels[model] then labels[model].lastHit = os.clock() end end)
end

local function updateLabels()
	local cam = workspace.CurrentCamera
	local cpos = cam.CFrame.Position
	local d = ClientState.Data
	local luck = ClientState.BoostRemaining("luck") > 0 and Shop.Boosts.luck.multiplier or 1
	for model, L in pairs(labels) do
		if not model.Parent then labels[model] = nil; continue end
		local dist = (L.root.Position - cpos).Magnitude
		local team = model:GetAttribute("Team")
		local state = model:GetAttribute("State")
		local recent = os.clock() - L.lastHit < 6
		local show = not L.def.isBoss and (dist < 45 or recent or (dist < 95 and model:GetAttribute("Catchable"))) and state ~= "vanish" and state ~= "capturing"
		if team == "player" and model:GetAttribute("OwnerUserId") == player.UserId then show = dist < 60 end
		if model:GetAttribute("Rider") == player.UserId then show = false end
		L.bb.Enabled = show
		if show then
			local hp, mx = model:GetAttribute("Hp") or 0, model:GetAttribute("MaxHp") or 1
			local lvl = model:GetAttribute("Level") or 1
			local prefix = ""
			if model:GetAttribute("Elite") then prefix = "[ALPHA] " end
			local owner = model:GetAttribute("OwnerName")
			L.name.Text = string.format('%s<font color="#%s">%s</font> <font color="#%s">%s</font> Lv %d', prefix, L.el.color:ToHex(), L.el.icon, L.rar.color:ToHex(), L.def.name, lvl)
			L.fill.Size = UDim2.fromScale(math.clamp(hp / mx, 0, 1), 1)
			L.fill.BackgroundColor3 = team == "player" and T.accent or (hp / mx < 0.3 and T.danger or T.good)
			if model:GetAttribute("Catchable") and d then
				local ch = Formulas.CatchChance(L.def.id, lvl, d.ballTier, luck)
				local left = math.max(0, (model:GetAttribute("DownedUntil") or 0) - workspace:GetServerTimeNow())
				L.st.Text = string.format("FANGBAR!  %d %%  (%ds)", math.floor(ch * 100 + 0.5), math.ceil(left))
				L.st.TextColor3 = T.gold
			elseif state == "windup" then
				L.st.Text = "! holt aus !"
				L.st.TextColor3 = T.danger
			else
				L.st.Text = ""
			end
			if owner then L.sub.Text = "Team-Pal von " .. owner
			elseif model:GetAttribute("TrainerName") then L.sub.Text = "Pal von " .. model:GetAttribute("TrainerName")
			else L.sub.Text = L.rar.name .. " • " .. L.def.role end
		end
	end
end

------------------------------------------------------------------ Laufende Anzeige
local function refreshStatic()
	local d = ClientState.Data
	if not d then return end
	refs.money.Text = Formulas.FormatMoney(d.money)
	-- Hotbar
	for i = 1, 3 do
		local id = d.slots[i]
		local w = id ~= "" and Weapons.Get(id)
		refs.slots[i].Text = w and w.name or "–"
		local active = WC and WC.Mode == "weapon" and WC.WeaponId == id and id ~= ""
		refs.slots[i].BackgroundColor3 = active and Color3.fromRGB(40, 90, 80) or T.panel2
	end
	local tier = Spheres.Get(d.ballTier)
	refs.slots[4].Text = tier and tier.name or "Fangkugel"
	refs.slots[4].BackgroundColor3 = (WC and WC.Mode == "ball") and Color3.fromRGB(40, 70, 110) or T.panel2
	-- Tutorial
	local step = Progression.Tutorial[d.tutorial.step]
	if d.tutorial.done or not step then
		if not d.bosses.morvath then
			refs.qTitle.Text = "Ziel"
			refs.qText.Text = d.trainers.lyra and "Besiege Morvath im Wurzelkessel hinter den Ruinen (Südwesten), um Welt 2 freizuschalten." or "Fordere Trainerin Lyra am Übungsring heraus (Nordost vom Lager)."
		else
			refs.qTitle.Text = "Welt 1 abgeschlossen!"
			refs.qText.Text = "Welt 2 (Glutsteppe) ist freigeschaltet und folgt in einem Update. Vervollständige deinen Pal-Katalog!"
		end
		refs.qSkip.Visible = false
	else
		refs.qTitle.Text = string.format("Tutorial %d/%d: %s", d.tutorial.step, #Progression.Tutorial, step.title)
		local extra = (step.count and step.count > 1) and string.format("  (%d/%d)", d.tutorial.counter, step.count) or ""
		refs.qText.Text = step.text .. extra
		refs.qSkip.Visible = true
	end
	-- Boosts
	for _, c in ipairs(refs.boosts:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	for _, id in ipairs(Shop.BoostOrder) do
		if d.boosts[id] then
			local b = Shop.Boosts[id]
			local f = UI.panel({ Size = UDim2.fromOffset(96, 28), Parent = refs.boosts, strokeColor = b.color, radius = 8 })
			local l = UI.label("", { Size = UDim2.fromScale(1, 1), TextSize = 12, Font = UI.Font, color = b.color, align = Enum.TextXAlignment.Center, Parent = f, Name = "T" })
			f:SetAttribute("Boost", id)
		end
	end
end

local acc = 0
local function perFrame(dt)
	local d = ClientState.Data
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		refs.hpFill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1), 1)
		refs.hpFill.BackgroundColor3 = hum.Health / hum.MaxHealth < 0.3 and T.danger or T.good
		refs.hpText.Text = math.ceil(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
	end
	-- Waffe
	local w = WC.Weapon()
	local blocked = WC.Blocked
	if WC.Mode == "ball" and d then
		local tier = Spheres.Get(d.ballTier)
		refs.wName.Text = tier.name
		refs.wInfo.Text = string.format("Fangchance ×%.1f  •  unbegrenzt  •  F = Schnellwurf", tier.mult)
		refs.ammo.Text = "-"
		refs.reloadBar.Visible = false
	elseif w then
		local lvl = d and d.weapons[w.id] and d.weapons[w.id].lvl or 0
		refs.wName.Text = w.name .. (lvl > 0 and ("  +" .. lvl) or "")
		refs.wInfo.Text = string.format("%s • %d Schaden%s • %.1f/s • %d m", w.archetype, math.floor(Formulas.WeaponDamage(w.id, lvl) + 0.5), w.pellets > 1 and ("×" .. w.pellets) or "", w.fireRate, w.range)
		local ammo = WC.AmmoOf(w.id)
		local col = ammo == 0 and "#ff5a50" or (ammo <= math.ceil(w.magazine * 0.25) and "#ffaa3c" or "#ffffff")
		refs.ammo.Text = string.format('<font color="%s">%d</font><font size="18" color="#96a8b2"> / %d</font>', col, ammo, w.magazine)
		refs.reloadBar.Visible = WC.Reloading
		if WC.Reloading then
			refs.reloadFill.Size = UDim2.fromScale(math.clamp((os.clock() - WC.ReloadStart) / math.max(0.01, WC.ReloadTime), 0, 1), 1)
		end
	end
	-- Fadenkreuz
	local scoped = WC.Scoped
	refs.scope.Visible = scoped and not blocked
	refs.cross.Visible = not blocked and not scoped
	local gap = 6 + (WC.Spread or 0) * 7
	if WC.Mode == "ball" then gap = 10 end
	for _, L in ipairs(refs.crossLines) do
		L.frame.Position = UDim2.new(0.5, L.dir.X * gap, 0.5, L.dir.Y * gap)
		L.frame.BackgroundColor3 = WC.Mode == "ball" and Color3.fromRGB(120, 200, 255) or Color3.new(1, 1, 1)
	end
	-- Hinweise
	local hint, sub = "", ""
	if WC.Reloading then
		hint = "Nachladen …"
	elseif w and WC.Mode == "weapon" and WC.AmmoOf(w.id) == 0 then
		hint = "LEER – [R] nachladen"
	elseif w and WC.Mode == "weapon" and WC.AmmoOf(w.id) <= math.ceil(w.magazine * 0.25) then
		hint = "Wenig Munition – [R]"
	end
	-- Zielt der Spieler auf eine fangbare Kreatur?
	local cam = workspace.CurrentCamera
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Runtime.Creatures }
	local res = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 120, rp)
	if res and d then
		local m = res.Instance:FindFirstAncestorOfClass("Model")
		while m and m.Parent ~= workspace.Runtime.Creatures do m = m:FindFirstAncestorOfClass("Model") end
		if m and m:GetAttribute("Catchable") then
			local def = Pals.Get(m:GetAttribute("Species"))
			local luck = ClientState.BoostRemaining("luck") > 0 and 2 or 1
			local ch = Formulas.CatchChance(def.id, m:GetAttribute("Level") or 1, d.ballTier, luck)
			hint = string.format("%s fangen: %d %%", def.name, math.floor(ch * 100 + 0.5))
			sub = WC.Mode == "ball" and "Klicken zum Werfen" or "[4] Fangkugel wählen oder [F] werfen"
		end
	end
	refs.centerHint.Text = blocked and "" or hint
	refs.centerSub.Text = blocked and "" or sub

	acc += dt
	if acc >= 0.15 then
		acc = 0
		updateLabels()
		-- Boost-Timer
		for _, f in ipairs(refs.boosts:GetChildren()) do
			local id = f:IsA("Frame") and f:GetAttribute("Boost")
			if id then
				local rem = ClientState.BoostRemaining(id)
				f.T.Text = Shop.Boosts[id].name .. " " .. Formulas.FormatTime(rem)
				f.Visible = rem > 0
			end
		end
		-- Team-Panel
		if d then
			local uid = d.team[d.activeIndex]
			local pal = uid and d.pals[uid]
			local myComp = nil
			for _, m in ipairs(workspace.Runtime.Creatures:GetChildren()) do
				if m:GetAttribute("OwnerUserId") == player.UserId then myComp = m end
			end
			if pal then
				local def = Pals.Get(pal.species)
				refs.teamName.Text = string.format("%s  Lv %d   (%d/%d)", def.name, pal.level, d.activeIndex, #d.team)
				if pal.fainted then
					refs.teamSub.Text = "Erschöpft – " .. pal.fainted .. " s"
				elseif myComp then
					local hp, mx = myComp:GetAttribute("Hp") or 0, myComp:GetAttribute("MaxHp") or 1
					refs.teamSub.Text = string.format("Im Kampf • %d/%d LP%s", hp, mx, def.ride and (" • reitbar (" .. (def.ride.mode == "fly" and "fliegt" or "läuft") .. ")") or "")
					refs.teamFill.Size = UDim2.fromScale(math.clamp(hp / mx, 0, 1), 1)
				else
					refs.teamSub.Text = "Bereit – [Q] rufen" .. (def.ride and " • reitbar" or "")
					refs.teamFill.Size = UDim2.fromScale(1, 1)
				end
			else
				refs.teamName.Text = "Kein Team-Pal"
				refs.teamSub.Text = "Fange Pals und setze sie im Menü [Tab] ins Team."
				refs.teamFill.Size = UDim2.fromScale(0, 1)
			end
		end
		-- Bossleiste
		local bossId = workspace:GetAttribute("BossActive")
		local shown = false
		if bossId then
			for _, m in ipairs(workspace.Runtime.Creatures:GetChildren()) do
				if m:GetAttribute("CreatureId") == bossId and m.PrimaryPart then
					if (m.PrimaryPart.Position - cam.CFrame.Position).Magnitude < 140 then
						shown = true
						local hp, mx = m:GetAttribute("Hp") or 0, m:GetAttribute("MaxHp") or 1
						refs.bossName.Text = string.format("%s  •  Phase %d  •  %d / %d", Pals.Get("morvath").name, m:GetAttribute("Phase") or 1, hp, mx)
						refs.bossFill.Size = UDim2.fromScale(math.clamp(hp / mx, 0, 1), 1)
						refs.bossFill.BackgroundColor3 = (m:GetAttribute("Phase") == 2) and Color3.fromRGB(255, 130, 60) or Color3.fromRGB(130, 230, 80)
					end
				end
			end
		end
		refs.boss.Visible = shown
	end
end

function HUD.Init(weaponController)
	WC = weaponController
	build()
	WC.OnHit = HUD.OnHit
	WC.OnChanged = refreshStatic
	ClientState.Changed:Connect(refreshStatic)
	refreshStatic()
	local folder = workspace.Runtime.Creatures
	for _, m in ipairs(folder:GetChildren()) do task.defer(makeLabel, m) end
	folder.ChildAdded:Connect(function(m) task.defer(makeLabel, m) end)
	RunService.RenderStepped:Connect(perFrame)
end

function HUD.SetMenuOpen(open)
	if refs.help then refs.help.Visible = not open and not UI.IsTouch() end
end

return HUD
