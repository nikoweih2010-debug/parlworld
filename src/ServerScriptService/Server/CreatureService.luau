--[[
	CreatureService: alle Kreaturen (wild, Trainer, Boss, Team-Begleiter).
	- Server bewegt nur das Root-Teil (AlignPosition/AlignOrientation, Physik-Replikation = flüssig)
	- Animationen laufen clientseitig über Motor6D (Attribute State/AttackId/HitTick)
	- Angriffe: Warnphase (windup) wird an alle Clients gesendet, Schaden erst danach -> ausweichbar
	- KI läuft mit 10 Hz und nur für Kreaturen in der Nähe von Spielern
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Pals = require(Shared.Config.Pals)
local Attacks = require(Shared.Config.Attacks)
local Elements = require(Shared.Config.Elements)
local Worlds = require(Shared.Config.Worlds)
local Spheres = require(Shared.Config.Spheres)
local Formulas = require(Shared.Formulas)
local Builder = require(Shared.CreatureBuilder)
local Net = require(script.Parent.Net)

local CreatureService = {}
CreatureService.Records = {}   -- [model] = rec
CreatureService.ById = {}      -- [id] = rec
-- Eigene Signal-Liste statt BindableEvent: BindableEvents kopieren Tabellen (Identität ginge verloren)
local defeatedListeners = {}
CreatureService.Defeated = {
	Connect = function(_, fn) table.insert(defeatedListeners, fn) end,
}
local function fireDefeated(rec, contributors)
	for _, fn in ipairs(defeatedListeners) do
		task.spawn(fn, rec, contributors)
	end
end

local folder = workspace:WaitForChild("Runtime"):WaitForChild("Creatures")
local nextId = 1
local TICK = 0.1

------------------------------------------------------------------ Boden
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function refreshGround()
	local list = { workspace.Terrain }
	for _, inst in ipairs(CollectionService:GetTagged("Ground")) do table.insert(list, inst) end
	groundParams.FilterDescendantsInstances = list
end
refreshGround()
CollectionService:GetInstanceAddedSignal("Ground"):Connect(refreshGround)
CollectionService:GetInstanceRemovedSignal("Ground"):Connect(refreshGround)

function CreatureService.GroundY(x, z, fromY)
	local top = fromY or 400
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top + 200), 0), groundParams)
	return hit and hit.Position.Y or nil
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

------------------------------------------------------------------ Ziele
local function charRoot(player)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then return hrp, hum end
	return nil
end
CreatureService.CharRoot = charRoot

local function isPlayer(t) return typeof(t) == "Instance" and t:IsA("Player") end

function CreatureService.TargetPos(t)
	if isPlayer(t) then
		local hrp = charRoot(t)
		return hrp and hrp.Position or nil
	end
	if type(t) == "table" and t.model and t.model.Parent and t.state ~= "dead" and t.state ~= "downed" and t.state ~= "capturing" then
		return t.root.Position
	end
	return nil
end
local TargetPos = CreatureService.TargetPos

local function teamOf(t)
	if isPlayer(t) then return "player" end
	return t.team
end

function CreatureService.Hostile(a, b)
	local ta, tb = teamOf(a), teamOf(b)
	if ta == tb then return false end
	if ta == "player" or tb == "player" then return true end
	return false
end
local Hostile = CreatureService.Hostile

-- Alle Ziele, die für rec feindlich sind
local function forEachHostileTarget(rec, fn)
	if rec.team ~= "player" then
		for _, p in ipairs(Players:GetPlayers()) do
			if not rec.targetFilter or rec.targetFilter(p) then
				local hrp = charRoot(p)
				if hrp then fn(p, hrp.Position, 1.5) end
			end
		end
	end
	for _, other in pairs(CreatureService.Records) do
		if other ~= rec and Hostile(rec, other) and other.state ~= "dead" and other.state ~= "downed" and other.state ~= "capturing" then
			if not rec.targetFilter or rec.targetFilter(other) then
				fn(other, other.root.Position, other.radius)
			end
		end
	end
end
CreatureService.ForEachHostileTarget = forEachHostileTarget

------------------------------------------------------------------ Spawnen
local BaseRadius = { gackerling = 1.6, glutwiesel = 1.6, moosbock = 2.4, flauschfunk = 2.2, bachzange = 2.4, frostigel = 1.8, surrfluegel = 2.4, daemmerluchs = 2.3, morvath = 9, noxen = 2.6 }

-- opts: level, position (Boden), kind, team, owner, hpMult, home, zone, yaw
function CreatureService.Spawn(speciesId, opts)
	local def = Pals.Get(speciesId)
	if not def then warn("[CreatureService] Unbekannte Art: " .. tostring(speciesId)); return nil end
	opts = opts or {}
	local level = math.clamp(opts.level or 1, 1, Formulas.MaxLevel)
	local model = Builder.Build(def)
	local root = model.PrimaryPart
	local rootH = model:GetAttribute("RootHeight")
	local scale = def.scale or 1
	local hover = (def.hover or 0) * (scale > 1 and 1.2 or 1)

	local pos = opts.position or Vector3.zero
	local gy = CreatureService.GroundY(pos.X, pos.Z) or pos.Y
	local ground = Vector3.new(pos.X, gy, pos.Z)
	local yaw = opts.yaw or math.random() * math.pi * 2

	local att = Instance.new("Attachment")
	att.Name = "MoveAtt"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e9
	ap.Responsiveness = 28
	ap.Position = ground + Vector3.new(0, rootH + hover, 0)
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e9
	ao.Responsiveness = 22
	ao.CFrame = CFrame.Angles(0, yaw, 0)
	ao.Parent = root

	local maxHp = math.floor(def.hp * Formulas.LevelMult(level) * (opts.hpMult or 1) + 0.5)
	local id = nextId
	nextId += 1
	model.Name = def.id .. "_" .. id
	model:SetAttribute("CreatureId", id)
	model:SetAttribute("Species", def.id)
	model:SetAttribute("Level", level)
	model:SetAttribute("MaxHp", maxHp)
	model:SetAttribute("Hp", maxHp)
	model:SetAttribute("State", "idle")
	model:SetAttribute("Team", opts.team or "wild")
	model:SetAttribute("Kind", opts.kind or "wild")
	model:SetAttribute("HitTick", 0)
	model:SetAttribute("AttackTick", 0)
	if opts.owner then model:SetAttribute("OwnerUserId", opts.owner.UserId) end

	model:PivotTo(CFrame.new(ground + Vector3.new(0, rootH + hover, 0)) * CFrame.Angles(0, yaw, 0))
	-- Bei aktivem Instance Streaming die Kreatur immer als Ganzes zum Client schicken
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = opts.parent or folder
	pcall(function() root:SetNetworkOwner(nil) end)
	CollectionService:AddTag(model, "Creature")

	local ext = model:GetExtentsSize()
	local rec = {
		id = id, model = model, root = root, def = def, level = level, scale = scale,
		maxHp = maxHp, hp = maxHp, state = "idle", kind = opts.kind or "wild", team = opts.team or "wild",
		owner = opts.owner, ap = ap, ao = ao, rootH = rootH, hover = hover,
		pos = ground, yaw = yaw, home = opts.home or ground, zone = opts.zone,
		radius = (BaseRadius[def.model] or 2) * scale,
		size = ext,
		cd = {}, damageBy = {}, busy = false, nextWander = 0, wanderGoal = nil,
		speedMult = 1, cdMult = 1, windupMult = 1, damageMult = 1,
		lastActive = os.clock(), spawnedAt = os.clock(),
	}
	-- Start-Cooldowns leicht versetzt, damit nicht alle sofort angreifen
	for _, aid in ipairs(def.attacks) do rec.cd[aid] = os.clock() + 1 + math.random() * 1.5 end
	CreatureService.Records[model] = rec
	CreatureService.ById[id] = rec
	return rec
end

function CreatureService.FromInstance(inst)
	local m = inst
	while m and m ~= workspace do
		if m:IsA("Model") and CreatureService.Records[m] then return CreatureService.Records[m] end
		m = m.Parent
	end
	return nil
end

function CreatureService.SetState(rec, s)
	if rec.state == s then return end
	rec.state = s
	if rec.model.Parent then rec.model:SetAttribute("State", s) end
end
local SetState = CreatureService.SetState

function CreatureService.Despawn(rec, fade)
	if rec.removed then return end
	rec.removed = true
	CreatureService.Records[rec.model] = nil
	CreatureService.ById[rec.id] = nil
	if rec.onRemoved then task.spawn(rec.onRemoved, rec) end
	if fade and rec.model.Parent then
		rec.model:SetAttribute("State", "vanish")
		Net.BroadcastVFX("vanish", { id = rec.id, pos = rec.root.Position, scale = rec.scale })
		task.delay(0.9, function() if rec.model then rec.model:Destroy() end end)
	else
		rec.model:Destroy()
	end
end

------------------------------------------------------------------ Schaden
local function applyToPlayer(rec, player, dmg, atk)
	local hrp, hum = charRoot(player)
	if not hum then return end
	if player.Character:FindFirstChildOfClass("ForceField") then return end
	dmg = math.max(1, math.floor(dmg + 0.5))
	hum:TakeDamage(dmg)
	Net.VFX:FireClient(player, "hurt", { amount = dmg, from = rec and rec.root.Position or nil, atk = atk and atk.id })
	if atk and atk.slow then
		player:SetAttribute("SlowMult", atk.slow)
		player:SetAttribute("SlowUntil", workspace:GetServerTimeNow() + (atk.slowTime or 2))
	end
end

-- info: { player = Player?, sourceRec = rec?, weak = bool, silent = bool }
function CreatureService.Damage(rec, amount, info)
	info = info or {}
	if rec.removed or rec.state == "dead" or rec.state == "downed" or rec.state == "capturing" or rec.invulnerable then return false end
	amount = math.max(0, amount)
	rec.hp -= amount
	local credit = info.player or (info.sourceRec and info.sourceRec.owner)
	if credit then
		rec.damageBy[credit] = (rec.damageBy[credit] or 0) + amount
	end
	-- provozieren
	local attacker = info.player or info.sourceRec
	if attacker and rec.think == nil and (not rec.target or rec.def.temperament ~= "aggressive" or math.random() < 0.25) then
		if not rec.targetFilter or rec.targetFilter(attacker) then rec.target = attacker end
	end
	rec.lastHurt = os.clock()
	if rec.model.Parent then
		rec.model:SetAttribute("Hp", math.max(0, math.ceil(rec.hp)))
		if not info.silent then rec.model:SetAttribute("HitTick", (rec.model:GetAttribute("HitTick") or 0) + 1) end
	end
	if rec.hp <= 0 then
		CreatureService.Defeat(rec)
	end
	return true
end

function CreatureService.Heal(rec, amount)
	rec.hp = math.min(rec.maxHp, rec.hp + amount)
	rec.model:SetAttribute("Hp", math.ceil(rec.hp))
end

local function applyDamage(rec, target, base, atk)
	if isPlayer(target) then
		applyToPlayer(rec, target, base, atk)
	else
		local mult = Elements.Multiplier(rec.def.element, target.def.element)
		if rec.owner then
			local DataService = CreatureService.DataService
			if DataService then mult *= DataService.BoostMult(rec.owner, "damage") end
		end
		CreatureService.Damage(target, base * mult, { sourceRec = rec })
	end
end

local function attackDamage(rec, atk)
	return atk.damage * rec.def.damageMult * Formulas.DamageLevelMult(rec.level) * rec.damageMult
end

-- Treffer im Radius (horizontal) um center
local function hitRadius(rec, center, radius, dmg, atk, already)
	local hits = {}
	forEachHostileTarget(rec, function(t, pos, r)
		if already and already[t] then return end
		local d = flat(pos - center).Magnitude
		if d <= radius + r and math.abs(pos.Y - center.Y) <= radius + 6 then
			if already then already[t] = true end
			applyDamage(rec, t, dmg, atk)
			table.insert(hits, pos)
		end
	end)
	return hits
end

-- Treffer entlang einer Linie (Segment a->b, halbe Breite w)
local function hitLine(rec, a, b, w, dmg, atk, already)
	local ab = flat(b - a)
	local len = ab.Magnitude
	if len < 0.01 then return end
	local dir = ab / len
	forEachHostileTarget(rec, function(t, pos, r)
		if already and already[t] then return end
		local ap = flat(pos - a)
		local proj = math.clamp(ap:Dot(dir), 0, len)
		local closest = dir * proj
		if (ap - closest).Magnitude <= w + r and math.abs(pos.Y - (a.Y + (b.Y - a.Y) * proj / len)) <= 10 then
			if already then already[t] = true end
			applyDamage(rec, t, dmg, atk)
		end
	end)
end

------------------------------------------------------------------ Projektile
local projectiles = {}
local nextProj = 1
local projParams = RaycastParams.new()
projParams.FilterType = Enum.RaycastFilterType.Include
projParams.FilterDescendantsInstances = { workspace.Terrain }

local function fireProjectile(rec, atk, origin, dir, dmg)
	local pid = nextProj
	nextProj += 1
	local p = {
		id = pid, pos = origin, dir = dir, speed = atk.speed, radius = atk.hitRadius or 2,
		maxDist = atk.range * 1.4, traveled = 0, dmg = dmg, rec = rec, atk = atk,
	}
	projectiles[pid] = p
	return pid
end

RunService.Heartbeat:Connect(function(dt)
	if next(projectiles) == nil then return end
	for pid, p in pairs(projectiles) do
		local step = p.speed * dt
		local nextPos = p.pos + p.dir * step
		local hitPos = nil
		local ray = workspace:Raycast(p.pos, p.dir * step, projParams)
		if ray then hitPos = ray.Position end
		if not hitPos then
			forEachHostileTarget(p.rec, function(t, pos, r)
				if hitPos then return end
				-- Abstand Punkt zu Segment
				local ap = pos - p.pos
				local proj = math.clamp(ap:Dot(p.dir), 0, step)
				if (ap - p.dir * proj).Magnitude <= p.radius + r then
					hitPos = p.pos + p.dir * proj
					applyDamage(p.rec, t, p.dmg, p.atk)
				end
			end)
		end
		p.traveled += step
		p.pos = nextPos
		if hitPos or p.traveled >= p.maxDist then
			projectiles[pid] = nil
			Net.BroadcastVFX("proj_end", { pid = pid, pos = hitPos or p.pos, atk = p.atk.id, hit = hitPos ~= nil })
		end
	end
end)

------------------------------------------------------------------ Angriffe
local function groundPoint(v)
	local gy = CreatureService.GroundY(v.X, v.Z, v.Y + 40) or v.Y
	return Vector3.new(v.X, gy, v.Z)
end

local function faceTowards(rec, pos)
	local d = flat(pos - rec.pos)
	if d.Magnitude > 0.05 then
		rec.yaw = math.atan2(-d.X, -d.Z)
		rec.ao.CFrame = CFrame.Angles(0, rec.yaw, 0)
	end
end

local function setRootTarget(rec)
	rec.ap.Position = rec.pos + Vector3.new(0, rec.rootH + rec.hover + (rec.extraHeight or 0), 0)
end
CreatureService.SetRootTarget = setRootTarget

local function alive(rec)
	return not rec.removed and rec.state ~= "dead" and rec.state ~= "downed" and rec.state ~= "capturing"
end

local function moveDash(rec, toGround, duration)
	local from = rec.pos
	local t0 = os.clock()
	while os.clock() - t0 < duration do
		if not alive(rec) then return end
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		local p = from:Lerp(toGround, a)
		local gy = CreatureService.GroundY(p.X, p.Z, p.Y + 30) or p.Y
		rec.pos = Vector3.new(p.X, gy, p.Z)
		setRootTarget(rec)
		task.wait()
	end
end

function CreatureService.StartAttack(rec, atkId, target)
	local atk = Attacks[atkId]
	if not atk or rec.busy then return end
	local tpos = TargetPos(target)
	if not tpos then return end
	rec.busy = true
	local speedF = rec.def.attackSpeed or 1
	rec.cd[atkId] = os.clock() + atk.cooldown / speedF * rec.cdMult + atk.windup
	SetState(rec, "windup")
	rec.model:SetAttribute("AttackId", atkId)
	rec.model:SetAttribute("AttackTick", (rec.model:GetAttribute("AttackTick") or 0) + 1)
	faceTowards(rec, tpos)

	local windup = atk.windup * rec.windupMult
	local origin = rec.root.Position
	local gTarget = groundPoint(tpos)
	local dir = flat(gTarget - rec.pos)
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(-math.sin(rec.yaw), 0, -math.cos(rec.yaw))
	local dmg = attackDamage(rec, atk)
	local data = {
		id = rec.id, atk = atkId, origin = origin, ground = rec.pos, target = gTarget, dir = dir,
		windup = windup, scale = rec.scale, t0 = workspace:GetServerTimeNow(),
	}

	-- Ziele/Punkte bei Start festlegen (Warnzeichen zeigt genau diese Stellen)
	if atk.kind == "strike" or atk.kind == "dive" or atk.kind == "blink" then
		local pts = {}
		local count = atk.count or 1
		for i = 1, count do
			local off = Vector3.zero
			if (atk.scatter or 0) > 0 and (i > 1 or count > 1) then
				local a = (i / count) * math.pi * 2 + math.random() * 0.8
				local r = (i == 1 and count > 2) and 0 or atk.scatter * (0.5 + math.random() * 0.5)
				off = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
			table.insert(pts, groundPoint(gTarget + off))
		end
		data.points = pts
	elseif atk.kind == "lob" then
		data.points = { gTarget }
	elseif atk.kind == "beam" then
		local dirs = {}
		local count = atk.count or 1
		for i = 1, count do
			local ang = 0
			if count > 1 then ang = math.rad((i - (count + 1) / 2) * (atk.fan or 0)) end
			table.insert(dirs, (CFrame.Angles(0, ang, 0) * dir))
		end
		data.dirs = dirs
		data.length = atk.length * (rec.kind == "boss" and 1 or rec.scale ^ 0.5)
		data.width = atk.width
	elseif atk.kind == "charge" or atk.kind == "lunge" then
		local dist = math.min(atk.dash * (rec.scale ^ 0.5), math.max(4, (gTarget - rec.pos).Magnitude + (atk.kind == "charge" and 6 or 0)))
		data.dashTo = groundPoint(rec.pos + dir * dist)
		data.width = atk.width or atk.radius
	elseif atk.kind == "nova" then
		data.radius = atk.radius * (rec.scale ^ 0.5)
	elseif atk.kind == "cone" then
		data.range = atk.range * (rec.scale ^ 0.5)
		data.angle = atk.angle
	end
	Net.BroadcastVFX("telegraph", data)

	task.spawn(function()
		-- Flieger: beim Sturzflug kurz aufsteigen
		if atk.kind == "dive" then
			rec.extraHeight = 6
			setRootTarget(rec)
		end
		local t0 = os.clock()
		while os.clock() - t0 < windup do
			if not alive(rec) then rec.busy = false; rec.extraHeight = nil; return end
			if atk.kind ~= "charge" and atk.kind ~= "beam" and atk.kind ~= "cone" and atk.kind ~= "lunge" then
				local tp = TargetPos(target)
				if tp then faceTowards(rec, tp) end
			end
			task.wait()
		end
		if not alive(rec) then rec.busy = false; rec.extraHeight = nil; return end
		SetState(rec, "attack")
		local res = { id = rec.id, atk = atkId, t0 = workspace:GetServerTimeNow() }

		if atk.kind == "lunge" then
			moveDash(rec, data.dashTo, 0.22)
			res.pos = rec.pos
			Net.BroadcastVFX("impact", res)
			hitRadius(rec, rec.pos, atk.radius * rec.scale ^ 0.5, dmg, atk)
		elseif atk.kind == "charge" then
			local already = {}
			local from = rec.pos
			res.from = from; res.to = data.dashTo
			Net.BroadcastVFX("impact", res)
			local steps = 6
			for i = 1, steps do
				if not alive(rec) then break end
				local a = from:Lerp(data.dashTo, (i - 1) / steps)
				local b = from:Lerp(data.dashTo, i / steps)
				moveDash(rec, b, 0.06)
				hitLine(rec, a, b, data.width / 2 * rec.scale ^ 0.5, dmg, atk, already)
			end
		elseif atk.kind == "cone" then
			res.pos = rec.pos; res.dir = dir; res.range = data.range; res.angle = atk.angle
			Net.BroadcastVFX("impact", res)
			local cosA = math.cos(math.rad(atk.angle / 2))
			forEachHostileTarget(rec, function(t, pos, r)
				local d = flat(pos - rec.pos)
				if d.Magnitude <= data.range + r and (d.Magnitude < 1 or d.Unit:Dot(dir) >= cosA) then
					applyDamage(rec, t, dmg, atk)
				end
			end)
		elseif atk.kind == "projectile" then
			local count = atk.count or 1
			local tp = TargetPos(target) or gTarget
			local from = rec.root.Position + Vector3.new(0, 0.3 * rec.scale, 0)
			local aim = (tp - from)
			aim = aim.Magnitude > 0.1 and aim.Unit or dir
			res.from = from
			res.shots = {}
			for i = 1, count do
				local ang = count > 1 and math.rad((i - (count + 1) / 2) * (atk.spread / math.max(1, count - 1)) * 2) or 0
				local d = (CFrame.Angles(0, ang, 0) * aim).Unit
				local pid = fireProjectile(rec, atk, from, d, dmg)
				table.insert(res.shots, { pid = pid, dir = d })
			end
			res.speed = atk.speed
			res.range = atk.range * 1.4
			Net.BroadcastVFX("projectiles", res)
		elseif atk.kind == "lob" then
			res.from = rec.root.Position; res.to = data.points[1]; res.flight = atk.flight
			Net.BroadcastVFX("lob", res)
			task.wait(atk.flight)
			Net.BroadcastVFX("impact", { id = rec.id, atk = atkId, pos = data.points[1] })
			hitRadius(rec, data.points[1], atk.radius, dmg, atk)
		elseif atk.kind == "nova" then
			res.pos = rec.pos; res.radius = data.radius
			Net.BroadcastVFX("impact", res)
			hitRadius(rec, rec.pos, data.radius, dmg, atk)
		elseif atk.kind == "strike" then
			res.points = data.points
			Net.BroadcastVFX("impact", res)
			local already = {}
			for _, pt in ipairs(data.points) do hitRadius(rec, pt, atk.radius, dmg, atk, already) end
		elseif atk.kind == "dive" then
			rec.extraHeight = nil
			moveDash(rec, data.points[1], 0.25)
			res.pos = data.points[1]
			Net.BroadcastVFX("impact", res)
			hitRadius(rec, data.points[1], atk.radius, dmg, atk)
		elseif atk.kind == "blink" then
			res.from = rec.pos; res.pos = data.points[1]
			local back = flat(rec.pos - data.points[1])
			back = back.Magnitude > 0.1 and back.Unit or Vector3.new(0, 0, 1)
			rec.pos = groundPoint(data.points[1] + back * 2)
			rec.root.CFrame = CFrame.new(rec.pos + Vector3.new(0, rec.rootH + rec.hover, 0)) * CFrame.Angles(0, rec.yaw, 0)
			setRootTarget(rec)
			Net.BroadcastVFX("impact", res)
			hitRadius(rec, data.points[1], atk.radius, dmg, atk)
		elseif atk.kind == "beam" then
			local function wave(dirs)
				local already = {}
				for _, d in ipairs(dirs) do
					hitLine(rec, rec.pos, rec.pos + d * data.length, data.width / 2, dmg, atk, already)
				end
			end
			res.ground = rec.pos; res.dirs = data.dirs; res.length = data.length; res.width = data.width
			Net.BroadcastVFX("impact", res)
			wave(data.dirs)
			if rec.extraWave then
				-- Boss Phase 2: zweite, versetzte Welle mit eigener Warnung
				local dirs2 = {}
				for _, d in ipairs(data.dirs) do table.insert(dirs2, CFrame.Angles(0, math.rad((atk.fan or 10) / 2), 0) * d) end
				Net.BroadcastVFX("telegraph", { id = rec.id, atk = atkId, ground = rec.pos, dirs = dirs2, length = data.length, width = data.width, windup = 0.8, t0 = workspace:GetServerTimeNow(), origin = rec.root.Position, dir = dir })
				task.wait(0.8)
				if alive(rec) then
					Net.BroadcastVFX("impact", { id = rec.id, atk = atkId, ground = rec.pos, dirs = dirs2, length = data.length, width = data.width })
					wave(dirs2)
				end
			end
		end

		task.wait(0.35)
		rec.extraHeight = nil
		if alive(rec) then
			SetState(rec, rec.target and "chase" or "idle")
			setRootTarget(rec)
		end
		rec.busy = false
	end)
end

------------------------------------------------------------------ Besiegen
function CreatureService.Defeat(rec)
	if rec.state == "dead" or rec.state == "downed" then return end
	rec.busy = false
	rec.hp = 0
	local total = 0
	for _, v in pairs(rec.damageBy) do total += v end
	local contributors = {}
	for p, v in pairs(rec.damageBy) do
		if p.Parent and (total <= 0 or v / total >= 0.08) then table.insert(contributors, p) end
	end
	if rec.onFaint then
		SetState(rec, "dead")
		task.spawn(rec.onFaint, rec)
		return
	end
	local catchable = rec.kind == "wild" and rec.def.catchable ~= false
	if catchable then
		SetState(rec, "downed")
		rec.downedUntil = os.clock() + Spheres.DownedDuration
		rec.model:SetAttribute("Catchable", true)
		rec.model:SetAttribute("DownedUntil", workspace:GetServerTimeNow() + Spheres.DownedDuration)
		rec.extraHeight = nil
		setRootTarget(rec)
	else
		SetState(rec, "dead")
		task.delay(rec.kind == "boss" and 4 or 2.2, function() CreatureService.Despawn(rec, true) end)
	end
	Net.BroadcastVFX("defeat", { id = rec.id, pos = rec.root.Position, scale = rec.scale, catchable = catchable })
	fireDefeated(rec, contributors)
end

-- Nach misslungenem Fang wieder aufstehen
function CreatureService.Recover(rec, fraction, target)
	if rec.removed then return end
	rec.model:SetAttribute("Catchable", false)
	rec.model:SetAttribute("DownedUntil", nil)
	rec.hp = math.max(1, rec.maxHp * fraction)
	rec.model:SetAttribute("Hp", math.ceil(rec.hp))
	rec.damageBy = {}
	rec.target = target
	rec.busy = false
	SetState(rec, "chase")
end

------------------------------------------------------------------ KI
local function pickTarget(rec)
	local best, bestD = nil, math.huge
	local range = rec.def.aggroRange or 0
	if rec.kind == "trainer" or rec.kind == "boss" then range = math.max(range, 90) end
	if range <= 0 then return nil end
	forEachHostileTarget(rec, function(t, pos)
		local d = (pos - rec.root.Position).Magnitude
		if d < range and d < bestD then best, bestD = t, d end
	end)
	return best
end

local function stepMove(rec, goal, speed, dt)
	local d = flat(goal - rec.pos)
	local dist = d.Magnitude
	if dist < 0.2 then return true end
	local step = math.min(dist, speed * dt)
	local np = rec.pos + d.Unit * step
	local gy = CreatureService.GroundY(np.X, np.Z, rec.pos.Y + 30)
	if not gy then return true end
	-- nicht ins tiefe Wasser / von Klippen
	if gy < rec.pos.Y - 14 then return true end
	rec.pos = Vector3.new(np.X, gy, np.Z)
	rec.yaw = math.atan2(-d.X, -d.Z)
	rec.ao.CFrame = CFrame.Angles(0, rec.yaw, 0)
	setRootTarget(rec)
	return dist <= step + 0.2
end
CreatureService.StepMove = stepMove

local function slowMult(rec)
	return rec.speedMult
end

local function defaultThink(rec, dt, now)
	if rec.busy then return end
	local def = rec.def
	local speed = def.speed * slowMult(rec)

	-- Ziel gültig?
	if rec.target then
		local tp = TargetPos(rec.target)
		if not tp or (rec.targetFilter and not rec.targetFilter(rec.target)) then
			rec.target = nil
		elseif rec.kind == "wild" and flat(tp - rec.home).Magnitude > Worlds.LeashRadius then
			rec.target = nil
			rec.returning = true
		end
	end
	if not rec.target and def.temperament == "aggressive" and not rec.returning then
		rec.target = pickTarget(rec)
	end

	if rec.target then
		local tp = TargetPos(rec.target)
		local dist = flat(tp - rec.pos).Magnitude
		-- Angriff wählen
		local ready = {}
		for _, aid in ipairs(def.attacks) do
			local atk = Attacks[aid]
			if (rec.cd[aid] or 0) <= now and dist <= atk.range * (rec.kind == "boss" and 1 or rec.scale ^ 0.5) then table.insert(ready, aid) end
		end
		if #ready > 0 then
			CreatureService.StartAttack(rec, ready[math.random(1, #ready)], rec.target)
			return
		end
		-- Abstand halten: Fernkämpfer bleiben auf mittlerer Distanz
		local minR, maxR = 999, 0
		for _, aid in ipairs(def.attacks) do
			local r = Attacks[aid].range
			minR = math.min(minR, r); maxR = math.max(maxR, r)
		end
		local desired = math.max(rec.radius + 2.5, minR * 0.6)
		SetState(rec, "chase")
		if dist > desired then
			stepMove(rec, tp, speed, dt)
		elseif dist < desired * 0.5 and minR > 20 then
			local away = flat(rec.pos - tp)
			if away.Magnitude > 0.1 then stepMove(rec, rec.pos + away.Unit * 6, speed * 0.7, dt) end
		else
			-- seitlich kreisen
			local side = flat(rec.pos - tp)
			if side.Magnitude > 0.1 then
				local perp = Vector3.new(-side.Z, 0, side.X).Unit * (rec.id % 2 == 0 and 1 or -1)
				stepMove(rec, rec.pos + perp * 4, speed * 0.45, dt)
			end
			faceTowards(rec, tp)
		end
		return
	end

	-- Kein Ziel: zurück nach Hause / umherstreifen
	if rec.returning then
		SetState(rec, "move")
		if stepMove(rec, rec.home, speed * 1.2, dt) or flat(rec.home - rec.pos).Magnitude < 6 then
			rec.returning = false
			CreatureService.Heal(rec, rec.maxHp)
		end
		return
	end
	if rec.kind == "trainer" or rec.kind == "boss" then
		SetState(rec, "idle")
		return
	end
	if not rec.wanderGoal and now >= rec.nextWander then
		local a = math.random() * math.pi * 2
		local r = 4 + math.random() * 14
		rec.wanderGoal = rec.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	if rec.wanderGoal then
		SetState(rec, "move")
		if stepMove(rec, rec.wanderGoal, speed * 0.4, dt) then
			rec.wanderGoal = nil
			rec.nextWander = now + 3 + math.random() * 5
		end
	else
		SetState(rec, "idle")
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	local step = math.min(acc, 0.25)
	acc = 0
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()

	-- Spielerpositionen einmal pro Tick
	local ppos = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = charRoot(p)
		if hrp then table.insert(ppos, { p, hrp.Position }) end
		-- Verlangsamung aufheben
		local su = p:GetAttribute("SlowUntil")
		if su and su < serverNow then p:SetAttribute("SlowUntil", nil); p:SetAttribute("SlowMult", nil) end
	end

	for model, rec in pairs(CreatureService.Records) do
		if not model.Parent then
			CreatureService.Despawn(rec)
			continue
		end
		if rec.state == "downed" then
			if now > (rec.downedUntil or 0) then
				CreatureService.Despawn(rec, true)
			end
			continue
		end
		if rec.state == "dead" or rec.state == "capturing" or rec.ridden then continue end

		-- Nähe zu Spielern (Schlafmodus + Katalog-Entdeckung)
		local nearest = math.huge
		local rp = rec.root.Position
		for _, e in ipairs(ppos) do
			local d = (e[2] - rp).Magnitude
			if d < nearest then nearest = d end
			if d < 60 and rec.kind ~= "companion" and CreatureService.DataService then
				CreatureService.DataService.Discover(e[1], rec.def.id)
			end
		end
		if rec.kind == "wild" and nearest > Worlds.SimulationRadius and not rec.target then
			continue
		end

		local ok, err = pcall(rec.think or defaultThink, rec, step, now)
		if not ok then
			warn("[CreatureService] KI-Fehler (" .. rec.def.id .. "): " .. tostring(err))
			rec.busy = false
		end
	end
end)

function CreatureService.ResetCooldowns(rec)
	for _, aid in ipairs(rec.def.attacks) do rec.cd[aid] = os.clock() + 0.5 end
end

return CreatureService
