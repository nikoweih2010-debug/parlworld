--[[
	RideController (Client): Steuerung von Reittieren. Der Server übergibt beim Aufsteigen die
	Netzwerk-Hoheit; der Client setzt Ziel-Position/-Ausrichtung der Align-Constraints.
	Bodenreittiere folgen dem Gelände, Flugreittiere steigen (Leertaste) und sinken (Strg).
	Beim Reiten wird eine Third-Person-Kamera verwendet (bessere Übersicht).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local UI = require(script.Parent.UIKit)

local Ride = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local WC
local controls = nil
local riding = nil -- { model, root, ap, ao, mode, speed, rootH, hover, alt, yaw }
local upHeld, downHeld = false, false
local touchGui = nil

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function refreshGround()
	local list = { workspace.Terrain }
	for _, i in ipairs(CollectionService:GetTagged("Ground")) do table.insert(list, i) end
	groundParams.FilterDescendantsInstances = list
end

local function groundY(x, z, fromY)
	local hit = workspace:Raycast(Vector3.new(x, fromY + 60, z), Vector3.new(0, -400, 0), groundParams)
	return hit and hit.Position.Y or nil
end

local function getControls()
	if controls then return controls end
	local ok, pm = pcall(function() return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) end)
	if ok and pm then controls = pm:GetControls() end
	return controls
end

local function sinkJump(_, inputState)
	if inputState == Enum.UserInputState.Begin then upHeld = true elseif inputState == Enum.UserInputState.End then upHeld = false end
	return Enum.ContextActionResult.Sink
end

local function buildTouch()
	if not UI.IsTouch() or touchGui then return end
	touchGui = UI.new("ScreenGui", { Name = "RideTouch", ResetOnSpawn = false, Parent = player.PlayerGui })
	local function b(text, y, setter)
		local btn = UI.new("TextButton", { Text = text, Size = UDim2.fromOffset(60, 60), Position = UDim2.new(1, -90, 0.5, y), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = UI.Theme.panel2, BackgroundTransparency = 0.25, TextColor3 = UI.Theme.text, Font = UI.Font, TextSize = 22, Parent = touchGui }, { UI.corner(30) })
		btn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then setter(true) end end)
		btn.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then setter(false) end end)
	end
	b("HOCH", -40, function(v) upHeld = v end)
	b("TIEF", 30, function(v) downHeld = v end)
end

local function startRide(model, seat)
	local root = model.PrimaryPart
	local att = root and root:FindFirstChild("MoveAtt")
	local ap = root and root:FindFirstChildOfClass("AlignPosition")
	local ao = root and root:FindFirstChildOfClass("AlignOrientation")
	if not (root and att and ap and ao) then return end
	refreshGround()
	local look = root.CFrame.LookVector
	riding = {
		model = model, root = root, ap = ap, ao = ao,
		mode = model:GetAttribute("RideMode") or "ground",
		speed = model:GetAttribute("RideSpeed") or 30,
		rootH = model:GetAttribute("RootHeight") or 2,
		pos = root.Position,
		yaw = math.atan2(-look.X, -look.Z),
		alt = 0,
	}
	local gy = groundY(root.Position.X, root.Position.Z, root.Position.Y) or (root.Position.Y - riding.rootH)
	riding.alt = root.Position.Y - gy
	WC.SetRiding(true)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 10
	player.CameraMaxZoomDistance = 26
	ContextActionService:BindActionAtPriority("ParlRideUp", sinkJump, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	if riding.mode == "fly" then buildTouch() end
end

local function stopRide()
	if not riding then return end
	riding = nil
	upHeld, downHeld = false, false
	ContextActionService:UnbindAction("ParlRideUp")
	if touchGui then touchGui:Destroy(); touchGui = nil end
	WC.SetRiding(false)
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end

local function onSeat(seat)
	if seat and seat.Name == "RideSeat" then
		local model = seat.Parent
		if model and model:GetAttribute("Rider") == player.UserId then startRide(model, seat) end
	else
		stopRide()
	end
end

local function hookCharacter(c)
	local hum = c:WaitForChild("Humanoid", 10)
	if not hum then return end
	stopRide()
	hum:GetPropertyChangedSignal("SeatPart"):Connect(function() onSeat(hum.SeatPart) end)
	hum.Died:Connect(stopRide)
end

function Ride.IsRiding() return riding ~= nil end

function Ride.Init(weaponController)
	WC = weaponController
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then task.spawn(hookCharacter, player.Character) end
	UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.LeftControl or i.KeyCode == Enum.KeyCode.ButtonB then downHeld = true end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.KeyCode == Enum.KeyCode.LeftControl or i.KeyCode == Enum.KeyCode.ButtonB then downHeld = false end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not riding then return end
		local r = riding
		if not r.model.Parent or r.model:GetAttribute("Rider") ~= player.UserId then stopRide(); return end
		-- Humanoid.MoveDirection ist bereits kamerarelativ (Tastatur, Gamepad, Touch-Joystick)
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local md = hum and hum.MoveDirection or Vector3.zero
		local wish = Vector3.new(md.X, 0, md.Z)
		if wish.Magnitude > 1 then wish = wish.Unit end
		local camRight = camera.CFrame.RightVector
		local mv = Vector3.new(wish:Dot(Vector3.new(camRight.X, 0, camRight.Z)), 0, 0)
		local boost = WC.Sprinting and 1.35 or 1
		local step = wish * r.speed * boost * dt
		local np = r.pos + step
		-- Weltgrenze (Insel)
		local flat = Vector3.new(np.X, 0, np.Z)
		if flat.Magnitude > 560 then np = Vector3.new(flat.Unit.X * 560, np.Y, flat.Unit.Z * 560) end
		local gy = groundY(np.X, np.Z, r.pos.Y) or (r.pos.Y - r.rootH)
		if r.mode == "fly" then
			local v = (upHeld and 1 or 0) - (downHeld and 1 or 0)
			r.alt = math.clamp(r.alt + v * 22 * dt, r.rootH + 0.5, 95)
			np = Vector3.new(np.X, gy + r.alt, np.Z)
		else
			np = Vector3.new(np.X, gy + r.rootH, np.Z)
			-- zu steile Hindernisse nicht erklimmen
			if gy + r.rootH - r.pos.Y > 6 then np = r.pos end
		end
		r.pos = np
		if wish.Magnitude > 0.05 then
			local targetYaw = math.atan2(-wish.X, -wish.Z)
			local d = (targetYaw - r.yaw + math.pi) % (2 * math.pi) - math.pi
			r.yaw += d * math.clamp(dt * 8, 0, 1)
		end
		r.ap.Position = r.pos
		local bank = r.mode == "fly" and math.clamp(-mv.X * 0.25, -0.3, 0.3) or 0
		r.ao.CFrame = CFrame.Angles(0, r.yaw, 0) * CFrame.Angles(0, 0, bank)
	end)
end

return Ride
