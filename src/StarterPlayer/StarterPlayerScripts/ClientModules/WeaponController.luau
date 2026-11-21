--[[
	WeaponController (Client): First-Person-Kamera, manuelles Zielen (kein Auto-Aim/Lock-on),
	Schießen, Zielen über Kimme, Rückstoss, Nachladen, Waffenwechsel, Fangkugel-Wurf.
	Der Client zeigt sofort Feedback; Treffer/Schaden bestätigt ausschließlich der Server.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Spheres = require(Shared.Config.Spheres)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Viewmodel = require(script.Parent.Viewmodel)
local VFX = require(script.Parent.VFX)
local ClientState = require(script.Parent.ClientState)

local WC = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

WC.Mode = "weapon"      -- "weapon" | "ball"
WC.WeaponId = nil
WC.Ammo = {}
WC.Reloading = false
WC.ReloadStart = 0
WC.ReloadTime = 0
WC.Aiming = false
WC.AimBlend = 0
WC.Sprinting = false
WC.Riding = false
WC.Blocked = false     -- Menü offen
WC.Spread = 0
WC.OnHit = nil         -- Callback (HUD)
WC.OnChanged = nil     -- Callback (HUD)
WC.OnThrow = nil

local BASE_FOV = 72
local trigger = false
local lastFire = 0
local lastThrow = 0
local bloom = 0
local recoilPitch, recoilVel = 0, 0
local recoilBack = 0
local recoilYaw = 0      -- kleiner seitlicher Versatz pro Schuss (Kamera)
local shotKick = 0       -- kurzer Waffen-Stoß im Bild (0..1), federt schnell zurück
local kickRoll = 0       -- Kipprichtung des aktuellen Stoßes
local kickScale = 0      -- Stärke abhängig von der Waffe
local shake = 0
local equipT = 0
local throwAnim = 0
local swayX, swayY = 0, 0
local lastCamLook = nil
local vm = nil
local vmKey = nil
local skinColor, sleeveColor = nil, nil

local function changed() if WC.OnChanged then WC.OnChanged() end end

local function weapon()
	return WC.WeaponId and Weapons.Get(WC.WeaponId)
end
WC.Weapon = weapon

local function ammoOf(id)
	local w = Weapons.Get(id)
	if WC.Ammo[id] == nil and w then WC.Ammo[id] = w.magazine end
	return WC.Ammo[id] or 0
end
WC.AmmoOf = ammoOf

local function char()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if c and hum and hum.Health > 0 then return c, hum end
	return nil
end

------------------------------------------------------------------ Viewmodel
local function readColors()
	local c = player.Character
	local hand = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
	skinColor = hand and hand.Color or nil
end

local function rebuildViewmodel()
	local key = WC.Mode == "ball" and ("ball" .. tostring(ClientState.Data and ClientState.Data.ballTier or 1)) or WC.WeaponId
	if key == vmKey and vm and vm.Parent then return end
	if vm then vm:Destroy() end
	vmKey = key
	if not key then vm = nil; return end
	if WC.Mode == "ball" then
		vm = Viewmodel.Build("ball", skinColor, sleeveColor, Spheres.Get(ClientState.Data and ClientState.Data.ballTier or 1))
	else
		vm = Viewmodel.Build(WC.WeaponId, skinColor, sleeveColor)
	end
	vm.Parent = camera
	equipT = 1
end

local function setVmVisible(v)
	if not vm then return end
	for _, p in ipairs(vm:GetDescendants()) do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = v and 0 or 1 end
	end
end

------------------------------------------------------------------ Zielen/Schuss
local function rayParams()
	local list = { camera, VFX.Folder }
	if player.Character then table.insert(list, player.Character) end
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	for _, m in ipairs(workspace.Runtime.Creatures:GetChildren()) do
		if m:GetAttribute("Team") == "player" then table.insert(list, m) end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = list
	rp.IgnoreWater = true
	return rp
end

local function randomCone(dir, deg)
	if deg <= 0 then return dir end
	local cf = CFrame.lookAt(Vector3.zero, dir)
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * math.rad(deg)
	return (cf * CFrame.Angles(math.cos(a) * r, math.sin(a) * r, 0)).LookVector
end

local function currentSpread(w)
	local c, hum = char()
	local moving = hum and hum.MoveDirection.Magnitude > 0.1
	local base = w.spread + (w.adsSpread - w.spread) * WC.AimBlend
	local s = base + bloom + (moving and 0.6 or 0) + (WC.Sprinting and 2.5 or 0)
	if hum and hum.FloorMaterial == Enum.Material.Air and not WC.Riding then s += 2 end
	return s
end

-- Zielpunkt der Kamera (auch in Third-Person beim Reiten korrekt)
local function aimData(range)
	local c = player.Character
	local head = c and c:FindFirstChild("Head")
	local camCF = camera.CFrame
	local rp = rayParams()
	local camRay = workspace:Raycast(camCF.Position, camCF.LookVector * (range + 30), rp)
	local aimPoint = camRay and camRay.Position or (camCF.Position + camCF.LookVector * (range + 30))
	local origin = camCF.Position
	if WC.Riding and head then
		origin = head.Position + Vector3.new(0, 0.6, 0)
	end
	local dir = (aimPoint - origin)
	if dir.Magnitude < 0.1 then dir = camCF.LookVector end
	return origin, dir.Unit, rp
end

local function muzzlePos()
	if vm and not WC.Riding then
		local m = vm:FindFirstChild("Muzzle")
		if m then return m.Position end
	end
	local c = player.Character
	local head = c and c:FindFirstChild("Head")
	return head and head.Position or camera.CFrame.Position
end

local function muzzleFlash(w)
	local pos = muzzlePos()
	local cam = workspace.CurrentCamera
	local dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	local scale = w.pellets > 1 and 1.15 or 0.8
	local flash = VFX.Part({
		shape = Enum.PartType.Ball,
		size = Vector3.new(0.28, 0.28, 0.7) * scale,
		cf = CFrame.lookAt(pos, pos + dir),
		color = Color3.fromRGB(255, 245, 205),
		t = 0.04,
		life = 0.1,
	})
	VFX.Tween(flash, 0.09, { Size = Vector3.new(0.14, 0.14, 1.25) * scale, Transparency = 1 })
	local l = Instance.new("PointLight")
	l.Color = w.color
	l.Range = 14
	l.Brightness = 5
	l.Parent = flash
	VFX.Tween(l, 0.09, { Brightness = 0 })
	VFX.Burst(pos, {
		tex = "rbxasset://textures/particles/explosion01_core_main.dds",
		color = ColorSequence.new(Color3.fromRGB(255, 250, 220), w.color),
		count = 5,
		speed = { 2, 5 },
		size = 0.55 * scale,
		life = { 0.06, 0.14 },
		spread = Vector2.new(22, 22),
	})
	VFX.Burst(pos, {
		tex = "rbxasset://textures/particles/fire_sparks_main.dds",
		color = w.color,
		count = w.pellets > 1 and 12 or 8,
		speed = { 8, 18 },
		size = 0.3,
		life = { 0.08, 0.22 },
		spread = Vector2.new(34, 34),
	})
	return pos
end

function WC.Reload()
	local w = weapon()
	if WC.Mode ~= "weapon" or not w or WC.Reloading then return end
	if ammoOf(w.id) >= w.magazine then return end
	WC.Reloading = true
	WC.ReloadStart = os.clock()
	WC.ReloadTime = w.reload
	Remotes.Reload:FireServer()
	VFX.Sound("reload", nil, 0.8)
	local id = w.id
	task.delay(w.reload + 0.05, function()
		if WC.Reloading and WC.WeaponId == id then
			WC.Reloading = false
			WC.Ammo[id] = w.magazine
			changed()
		end
	end)
	changed()
end

local function fire()
	local w = weapon()
	if not w or WC.Blocked or not char() then return end
	local now = os.clock()
	if now - lastFire < 1 / w.fireRate then return end
	if WC.Reloading then return end
	if ammoOf(w.id) <= 0 then
		lastFire = now
		VFX.Sound("empty", nil, 1)
		WC.Reload()
		return
	end
	lastFire = now
	WC.Ammo[w.id] -= 1
	local origin, dir, rp = aimData(w.range)
	local spread = currentSpread(w)
	local dirs = {}
	local mpos = muzzleFlash(w)
	for i = 1, w.pellets do
		local d = randomCone(dir, spread)
		table.insert(dirs, d)
		local res = workspace:Raycast(origin, d * w.range, rp)
		local endPos = res and res.Position or origin + d * w.range
		if w.splash then
			-- sichtbare Glutkapsel
			local ball = VFX.Part({ shape = Enum.PartType.Ball, size = Vector3.one * 0.7, cf = CFrame.new(mpos), color = w.color, life = 3 })
			VFX.Emitter(ball, { tex = "rbxasset://textures/particles/fire_main.dds", color = w.color, rate = 40, size = 1, speed = { 0, 1 }, life = { 0.1, 0.25 } })
			local dist = (endPos - mpos).Magnitude
			local tt = dist / (w.projectileSpeed or 120)
			local start = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local a = math.clamp((os.clock() - start) / math.max(tt, 0.01), 0, 1)
				if not ball.Parent then conn:Disconnect(); return end
				ball.CFrame = CFrame.new(mpos:Lerp(endPos, a))
				if a >= 1 then conn:Disconnect(); ball:Destroy() end
			end)
		else
			VFX.Tracer(mpos, endPos, w.tracer, w.pellets > 1 and 0.07 or 0.1)
			if res then VFX.ImpactSpark(res.Position, w.tracer) end
		end
	end
	Remotes.Fire:FireServer(w.id, origin, dirs)
	VFX.Sound(w.sound, nil, 1)
	-- Rückstoss
	local k = w.recoil * (WC.Aiming and 0.5 or 1)
	-- Kamera: deutlich weniger Hochreißen als vorher, leichter seitlicher Zufall
	recoilVel += k * 0.42
	recoilYaw += (math.random() - 0.5) * k * 0.25
	recoilBack = math.min(0.12, recoilBack + 0.02 * k)
	-- Viewmodel: kurzer Stoß, der schnell zurückfedert
	shotKick = 1
	kickScale = math.clamp(w.recoil / 4, 0.25, 1) * (WC.Aiming and 0.55 or 1)
	kickRoll = (math.random() < 0.5 and -1 or 1) * (0.5 + math.random() * 0.5)
	bloom = math.min(6, bloom + (w.bloom or 0.15))
	if WC.Ammo[w.id] <= 0 then task.delay(0.2, WC.Reload) end
	changed()
end

function WC.Throw()
	if WC.Blocked or not char() then return end
	local now = os.clock()
	if now - lastThrow < Spheres.ThrowCooldown then return end
	lastThrow = now
	local c = player.Character
	local head = c and c:FindFirstChild("Head")
	if not head then return end
	local _, dir = aimData(Spheres.MaxThrowRange)
	local origin = head.Position + camera.CFrame.LookVector * 1.2
	Remotes.ThrowBall:FireServer(origin, dir)
	throwAnim = 1
	if WC.OnThrow then WC.OnThrow() end
end

function WC.TriggerDown()
	if WC.Blocked then return end
	if WC.Mode == "ball" then WC.Throw(); return end
	trigger = true
	fire()
end
function WC.TriggerUp() trigger = false end

function WC.SetAim(v)
	if WC.Blocked and v then return end
	WC.Aiming = v
end

------------------------------------------------------------------ Waffenwechsel
function WC.SelectSlot(n)
	local d = ClientState.Data
	if not d then return end
	local id = d.slots[n]
	if not id or id == "" then return end
	if WC.Mode == "weapon" and WC.WeaponId == id then return end
	WC.Mode = "weapon"
	WC.WeaponId = id
	WC.Reloading = false
	WC.Aiming = false
	VFX.Sound("swap", nil, 0.8)
	rebuildViewmodel()
	changed()
	task.spawn(ClientState.Request, "EquipSlot", n)
end

function WC.SelectBall()
	if WC.Mode == "ball" then return end
	WC.Mode = "ball"
	WC.Reloading = false
	WC.Aiming = false
	VFX.Sound("swap", nil, 0.8)
	rebuildViewmodel()
	changed()
end

function WC.CycleSlot(delta)
	local d = ClientState.Data
	if not d then return end
	local order = {}
	for i = 1, Weapons.MaxSlots do if d.slots[i] ~= "" then table.insert(order, i) end end
	table.insert(order, 4) -- Fangkugel
	local cur = WC.Mode == "ball" and 4 or d.equippedSlot
	local idx = table.find(order, cur) or 1
	idx = ((idx - 1 + delta) % #order) + 1
	if order[idx] == 4 then WC.SelectBall() else WC.SelectSlot(order[idx]) end
end

function WC.Shake(a) shake = math.max(shake, a) end
VFX.Shake = WC.Shake

function WC.SetRiding(v)
	WC.Riding = v
	setVmVisible(not v)
end

function WC.SetBlocked(v)
	WC.Blocked = v
	if v then trigger = false; WC.Aiming = false end
end

------------------------------------------------------------------ Init
function WC.Init()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.FieldOfView = BASE_FOV

	local function onState(d)
		if not d then return end
		local want = d.slots[d.equippedSlot]
		if WC.Mode == "weapon" and want and want ~= "" and want ~= WC.WeaponId then
			WC.WeaponId = want
			WC.Reloading = false
			rebuildViewmodel()
		end
		if WC.WeaponId and not d.weapons[WC.WeaponId] then WC.WeaponId = want; rebuildViewmodel() end
		if WC.Mode == "ball" then rebuildViewmodel() end
		changed()
	end
	ClientState.Changed:Connect(onState)
	if ClientState.Data then onState(ClientState.Data) end

	Remotes.WeaponState.OnClientEvent:Connect(function(s)
		if type(s) ~= "table" then return end
		WC.Ammo[s.weapon] = s.ammo
		if s.weapon == WC.WeaponId then
			if s.reloading then
				if not WC.Reloading then
					local w = weapon()
					WC.Reloading = true
					WC.ReloadStart = os.clock()
					WC.ReloadTime = w and w.reload or 1
				end
			else
				WC.Reloading = false
			end
		end
		changed()
	end)
	Remotes.HitConfirm.OnClientEvent:Connect(function(data)
		if WC.OnHit then WC.OnHit(data) end
	end)

	player.CharacterAdded:Connect(function(c)
		WC.Ammo = {}
		WC.Reloading = false
		task.wait(0.3)
		readColors()
		vmKey = nil
		rebuildViewmodel()
		player.CameraMode = WC.Riding and Enum.CameraMode.Classic or Enum.CameraMode.LockFirstPerson
	end)
	if player.Character then readColors() end

	-- Eingaben (Tastatur/Maus/Gamepad)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		local kc = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or kc == Enum.KeyCode.ButtonR2 then
			WC.TriggerDown()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or kc == Enum.KeyCode.ButtonL2 then
			WC.SetAim(true)
		elseif kc == Enum.KeyCode.R or kc == Enum.KeyCode.ButtonX then
			WC.Reload()
		elseif kc == Enum.KeyCode.One then WC.SelectSlot(1)
		elseif kc == Enum.KeyCode.Two then WC.SelectSlot(2)
		elseif kc == Enum.KeyCode.Three then WC.SelectSlot(3)
		elseif kc == Enum.KeyCode.Four then WC.SelectBall()
		elseif kc == Enum.KeyCode.F or kc == Enum.KeyCode.ButtonY then WC.Throw()
		elseif kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.ButtonL3 then WC.Sprinting = true
		elseif kc == Enum.KeyCode.ButtonR1 then WC.CycleSlot(1)
		elseif kc == Enum.KeyCode.ButtonL1 then WC.CycleSlot(-1)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kc = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or kc == Enum.KeyCode.ButtonR2 then WC.TriggerUp()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or kc == Enum.KeyCode.ButtonL2 then WC.SetAim(false)
		elseif kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.ButtonL3 then WC.Sprinting = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input, gp)
		if gp or WC.Blocked then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel and not WC.Riding then
			WC.CycleSlot(input.Position.Z > 0 and -1 or 1)
		end
	end)

	-- Pro Frame: Automatikfeuer, Bewegung, Kamera-Effekte, Viewmodel
	RunService:BindToRenderStep("ParlWeapons", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local w = weapon()
		if trigger and w and w.automatic and WC.Mode == "weapon" then fire() end

		-- Laufen/Sprinten/Verlangsamung
		local c, hum = char()
		if hum and not hum.SeatPart then
			local slow = 1
			local su = player:GetAttribute("SlowUntil")
			if su and su > workspace:GetServerTimeNow() then slow = player:GetAttribute("SlowMult") or 1 end
			local sprint = WC.Sprinting and not WC.Aiming and hum.MoveDirection.Magnitude > 0.1
			hum.WalkSpeed = (sprint and 25 or (WC.Aiming and 11 or 16)) * slow
		end

		-- Zielen
		local target = (WC.Aiming and WC.Mode == "weapon" and not WC.Reloading) and 1 or 0
		WC.AimBlend += (target - WC.AimBlend) * math.clamp(dt * 14, 0, 1)
		bloom = math.max(0, bloom - dt * 5)
		if w then WC.Spread = currentSpread(w) end

		-- Rückstoss-Feder (Kamera nach oben, dann zurück)
		recoilPitch += recoilVel * dt * 18
		recoilVel -= recoilVel * math.clamp(dt * 20, 0, 1)
		recoilPitch -= recoilPitch * math.clamp(dt * 9, 0, 1)
		recoilYaw -= recoilYaw * math.clamp(dt * 9, 0, 1)
		recoilBack -= recoilBack * math.clamp(dt * 14, 0, 1)
		shotKick = math.max(0, shotKick - dt * 9)
		shake = math.max(0, shake - dt * 2.5)

		local fovTarget = BASE_FOV
		if w and WC.Mode == "weapon" then fovTarget = BASE_FOV + (w.adsFov - BASE_FOV) * WC.AimBlend end
		if WC.Sprinting and hum and hum.MoveDirection.Magnitude > 0.1 and not WC.Aiming then fovTarget += 6 end
		camera.FieldOfView += (fovTarget - camera.FieldOfView) * math.clamp(dt * 12, 0, 1)

		local camCF = camera.CFrame
		local sx = shake > 0 and (math.random() - 0.5) * shake * 0.04 or 0
		local sy = shake > 0 and (math.random() - 0.5) * shake * 0.04 or 0
		camera.CFrame = camCF * CFrame.Angles(math.rad(recoilPitch) + sx, math.rad(recoilYaw) + sy, 0)

		-- Viewmodel
		if not vm or not vm.Parent then
			if WC.WeaponId or WC.Mode == "ball" then rebuildViewmodel() end
			if not vm then return end
		end
		local showVm = not WC.Riding and hum ~= nil
		local scoped = WC.WeaponId == "falkenauge" and WC.AimBlend > 0.85 and WC.Mode == "weapon"
		WC.Scoped = scoped
		setVmVisible(showVm and not scoped)
		if not showVm then return end

		local look = camCF.LookVector
		if lastCamLook then
			local dYaw = math.atan2(-look.X, -look.Z) - math.atan2(-lastCamLook.X, -lastCamLook.Z)
			if dYaw > math.pi then dYaw -= 2 * math.pi elseif dYaw < -math.pi then dYaw += 2 * math.pi end
			local dPitch = math.asin(math.clamp(look.Y, -1, 1)) - math.asin(math.clamp(lastCamLook.Y, -1, 1))
			swayX = math.clamp(swayX + dYaw * 0.6, -0.12, 0.12)
			swayY = math.clamp(swayY + dPitch * 0.6, -0.1, 0.1)
		end
		lastCamLook = look
		swayX -= swayX * math.clamp(dt * 10, 0, 1)
		swayY -= swayY * math.clamp(dt * 10, 0, 1)

		local t = os.clock()
		local moveAmt = hum and math.clamp(hum.MoveDirection.Magnitude, 0, 1) or 0
		if hum and hum.FloorMaterial == Enum.Material.Air then moveAmt *= 0.2 end
		local bobF = WC.Sprinting and 13 or 9
		local bob = CFrame.new(math.sin(t * bobF * 0.5) * 0.018 * moveAmt, math.abs(math.sin(t * bobF * 0.5)) * 0.022 * moveAmt, 0)
		local idle = CFrame.new(0, math.sin(t * 1.6) * 0.005, 0)

		local sight = Viewmodel.SightHeight[WC.Mode == "ball" and "ball" or WC.WeaponId] or 0.4
		local hip = CFrame.new(0.36, -0.36, -0.72)
		if WC.Sprinting and moveAmt > 0.1 and not WC.Aiming then hip = CFrame.new(0.34, -0.48, -0.55) * CFrame.Angles(math.rad(-12), math.rad(35), math.rad(8)) end
		local ads = CFrame.new(0, -sight, -0.5)
		local off = hip:Lerp(ads, WC.AimBlend)

		-- Nachlade-Animation
		local reloadCF = CFrame.identity
		if WC.Reloading and WC.ReloadTime > 0 then
			local p = math.clamp((os.clock() - WC.ReloadStart) / WC.ReloadTime, 0, 1)
			local s = math.sin(p * math.pi)
			reloadCF = CFrame.new(0, -0.15 * s, 0.05 * s) * CFrame.Angles(math.rad(-25) * s, 0, math.rad(35) * s)
		end
		equipT = math.max(0, equipT - dt * 4)
		local equipCF = CFrame.new(0, -0.35 * equipT * equipT, 0) * CFrame.Angles(math.rad(-30) * equipT, 0, 0)
		throwAnim = math.max(0, throwAnim - dt * 3.5)
		local throwCF = CFrame.new(0, 0.12 * math.sin(throwAnim * math.pi), -0.25 * math.sin(throwAnim * math.pi)) * CFrame.Angles(math.rad(25) * math.sin(throwAnim * math.pi), 0, 0)

		local swayCF = CFrame.Angles(swayY * (1 - WC.AimBlend * 0.7), swayX * (1 - WC.AimBlend * 0.7), swayX * 0.5)
		-- Stoßkurve: schnell raus, weich zurück (Ease-Out)
		local kc = shotKick * shotKick * kickScale
		local recoilCF = CFrame.new(0, 0.015 * kc, recoilBack + 0.07 * kc)
			* CFrame.Angles(math.rad(recoilPitch * 0.8 + 6 * kc), 0, math.rad(3 * kc * kickRoll))
		vm:PivotTo(camera.CFrame * off * bob:Lerp(CFrame.identity, WC.AimBlend * 0.8) * idle * swayCF * recoilCF * reloadCF * equipCF * throwCF)
	end)
end

return WC
