--[[
	CombatService: Spielerwaffen. Der Client zielt und schickt Ursprung + Richtung(en);
	der Server prüft Besitz, ausgerüsteten Slot, Feuerrate, Munition und Ursprung und
	führt den Raycast selbst aus. Schaden/Treffer entscheidet nur der Server.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Weapons = require(Shared.Config.Weapons)
local Formulas = require(Shared.Formulas)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local CreatureService = require(script.Parent.CreatureService)

local CombatService = {}
local state = {} -- [player] = { ammo = {[id]=n}, reloading = id|nil, token = n, lastFire = t, lastTarget = rec, lastTargetAt = t, dummies = {} }
CombatService.State = state
CombatService.Progress = nil -- wird von Main gesetzt (ProgressService)

local function st(player)
	local s = state[player]
	if not s then
		s = { ammo = {}, token = 0, lastFire = 0, dummies = {} }
		state[player] = s
	end
	return s
end

local function currentWeapon(player)
	local d = DataService.Get(player)
	if not d then return nil end
	local id = d.slots[d.equippedSlot]
	if id and id ~= "" and d.weapons[id] then return Weapons.Get(id), d.weapons[id].lvl or 0 end
	return nil
end

function CombatService.Ammo(player, weaponId)
	local s = st(player)
	local w = Weapons.Get(weaponId)
	if s.ammo[weaponId] == nil and w then s.ammo[weaponId] = w.magazine end
	return s.ammo[weaponId]
end

local function pushWeaponState(player)
	local w = currentWeapon(player)
	if not w then return end
	local s = st(player)
	Net.WeaponState:FireClient(player, { weapon = w.id, ammo = CombatService.Ammo(player, w.id), reloading = s.reloading == w.id })
end
CombatService.PushWeaponState = pushWeaponState

function CombatService.CancelReload(player)
	local s = st(player)
	s.token += 1
	s.reloading = nil
end

local function buildFilter(player)
	local list = { workspace.Runtime.Projectiles }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	for _, rec in pairs(CreatureService.Records) do
		if rec.team == "player" then table.insert(list, rec.model) end
	end
	local fx = workspace:FindFirstChild("ClientFX")
	if fx then table.insert(list, fx) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	params.IgnoreWater = true
	return params
end

local function dummyOf(inst)
	local m = inst
	while m and m ~= workspace do
		if CollectionService:HasTag(m, "Dummy") then return m end
		m = m.Parent
	end
	return nil
end

-- Schaden an Kreatur (gesammelt pro Schuss)
local function hitCreature(player, rec, dmg, weak, hits, pos)
	if rec.team == "player" then return end
	local before = rec.state
	if CreatureService.Damage(rec, dmg, { player = player, weak = weak }) then
		local s = st(player)
		s.lastTarget = rec
		s.lastTargetAt = os.clock()
		table.insert(hits, { pos = pos, dmg = math.floor(dmg + 0.5), weak = weak, kill = before ~= rec.state and (rec.state == "downed" or rec.state == "dead") })
	elseif rec.state == "downed" then
		table.insert(hits, { pos = pos, dmg = 0, downed = true })
	end
end

local function hitDummy(player, dummy, dmg, hits, pos, weak)
	local s = st(player)
	table.insert(hits, { pos = pos, dmg = math.floor(dmg + 0.5), weak = weak, dummy = true })
	Net.BroadcastVFX("dummy_hit", { dummy = dummy })
	if not s.dummies[dummy] then
		s.dummies[dummy] = true
		if CombatService.Progress then CombatService.Progress.Event(player, "dummy_hit") end
	end
end

local function splash(player, w, center, baseDmg, hits)
	local radius = w.splash
	for _, rec in pairs(CreatureService.Records) do
		if rec.team ~= "player" then
			local d = (rec.root.Position - center).Magnitude - rec.radius
			if d <= radius then
				local f = 1 - math.clamp(d / radius, 0, 1) * 0.5
				hitCreature(player, rec, baseDmg * f, false, hits, rec.root.Position)
			end
		end
	end
	for _, dummy in ipairs(CollectionService:GetTagged("Dummy")) do
		local p = dummy:IsA("Model") and dummy:GetPivot().Position or dummy.Position
		if (p - center).Magnitude <= radius + 2 then hitDummy(player, dummy, baseDmg, hits, p, false) end
	end
end

local function onFire(player, weaponId, origin, dirs)
	if typeof(origin) ~= "Vector3" or type(dirs) ~= "table" or type(weaponId) ~= "string" then return end
	local w, lvl = currentWeapon(player)
	if not w or w.id ~= weaponId then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if not hum or hum.Health <= 0 or not head then return end
	if (origin - head.Position).Magnitude > 12 then return end
	local s = st(player)
	local now = os.clock()
	if now - s.lastFire < (1 / w.fireRate) * 0.8 then return end
	if s.reloading then return end
	local ammo = CombatService.Ammo(player, w.id)
	if ammo <= 0 then pushWeaponState(player); return end
	s.lastFire = now
	s.ammo[w.id] = ammo - 1

	local dmgBase = Formulas.WeaponDamage(w.id, lvl) * DataService.BoostMult(player, "damage")
	local params = buildFilter(player)
	local hits = {}
	local ends = {}
	local perCreature = {}
	local n = math.min(#dirs, w.pellets)
	for i = 1, n do
		local dir = dirs[i]
		if typeof(dir) == "Vector3" and dir.Magnitude > 0.5 then
			dir = dir.Unit
			local res = workspace:Raycast(origin, dir * w.range, params)
			local endPos = res and res.Position or (origin + dir * w.range)
			table.insert(ends, endPos)
			if w.splash then
				local dist = (endPos - origin).Magnitude
				task.delay(dist / (w.projectileSpeed or 120), function()
					if not player.Parent then return end
					local sh = {}
					splash(player, w, endPos, dmgBase, sh)
					Net.BroadcastVFX("explosion", { pos = endPos, radius = w.splash, color = w.color })
					if #sh > 0 then Net.HitConfirm:FireClient(player, { weapon = w.id, hits = sh }) end
				end)
			elseif res then
				local dist = (res.Position - origin).Magnitude
				local weak = res.Instance:GetAttribute("WeakSpot") == true
				local dmg = dmgBase * Formulas.Falloff(w, dist) * (weak and w.weakspot or 1)
				local rec = CreatureService.FromInstance(res.Instance)
				if rec then
					local e = perCreature[rec]
					if not e then e = { dmg = 0, weak = false, pos = res.Position }; perCreature[rec] = e end
					e.dmg += dmg
					e.weak = e.weak or weak
				else
					local dummy = dummyOf(res.Instance)
					if dummy then hitDummy(player, dummy, dmg, hits, res.Position, weak) end
				end
			end
		end
	end
	for rec, e in pairs(perCreature) do
		hitCreature(player, rec, e.dmg, e.weak, hits, e.pos)
	end
	Net.BroadcastVFX("shot", { uid = player.UserId, from = origin, ends = ends, weapon = w.id })
	if #hits > 0 then Net.HitConfirm:FireClient(player, { weapon = w.id, hits = hits }) end
	if s.ammo[w.id] <= 0 then pushWeaponState(player) end
end

local function onReload(player)
	local w = currentWeapon(player)
	if not w then return end
	local s = st(player)
	if s.reloading or CombatService.Ammo(player, w.id) >= w.magazine then pushWeaponState(player); return end
	s.token += 1
	local token = s.token
	s.reloading = w.id
	pushWeaponState(player)
	task.delay(w.reload, function()
		if state[player] ~= s or s.token ~= token then return end
		s.reloading = nil
		s.ammo[w.id] = w.magazine
		pushWeaponState(player)
		if CombatService.Progress then CombatService.Progress.Event(player, "reload") end
	end)
end

function CombatService.Init()
	Net.Fire.OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onFire, player, ...)
		if not ok then warn("[CombatService] Fire-Fehler: " .. tostring(err)) end
	end)
	Net.Reload.OnServerEvent:Connect(onReload)

	Net.Handle("EquipSlot", function(player, slot)
		local d = DataService.Get(player)
		if not d or type(slot) ~= "number" or slot < 1 or slot > Weapons.MaxSlots then return false end
		slot = math.floor(slot)
		if d.slots[slot] == "" then return false, "Slot ist leer" end
		if d.equippedSlot ~= slot then CombatService.CancelReload(player) end
		d.equippedSlot = slot
		DataService.Sync(player)
		pushWeaponState(player)
		return true
	end)

	Net.Handle("SetSlot", function(player, slot, weaponId)
		local d = DataService.Get(player)
		if not d or type(slot) ~= "number" or slot < 1 or slot > Weapons.MaxSlots then return false, "Ungültiger Slot" end
		slot = math.floor(slot)
		if weaponId == "" or weaponId == nil then
			local count = 0
			for _, id in ipairs(d.slots) do if id ~= "" then count += 1 end end
			if count <= 1 and d.slots[slot] ~= "" then return false, "Mindestens eine Waffe muss ausgerüstet bleiben" end
			d.slots[slot] = ""
		else
			if type(weaponId) ~= "string" or not d.weapons[weaponId] then return false, "Du besitzt diese Waffe nicht" end
			for i = 1, Weapons.MaxSlots do
				if d.slots[i] == weaponId then d.slots[i] = d.slots[slot] end
			end
			d.slots[slot] = weaponId
		end
		if d.slots[d.equippedSlot] == "" then
			for i = 1, Weapons.MaxSlots do if d.slots[i] ~= "" then d.equippedSlot = i; break end end
		end
		CombatService.CancelReload(player)
		DataService.Sync(player)
		pushWeaponState(player)
		return true
	end)

	Net.Handle("GetWeaponState", function(player)
		pushWeaponState(player)
		return true
	end)

	Players.PlayerRemoving:Connect(function(p) state[p] = nil end)
end

function CombatService.LastTarget(player)
	local s = state[player]
	if s and s.lastTarget and os.clock() - (s.lastTargetAt or 0) < 8 then return s.lastTarget end
	return nil
end

function CombatService.ResetAmmo(player)
	local s = st(player)
	s.ammo = {}
	CombatService.CancelReload(player)
end

return CombatService
