--[[
	CreatureAnimator (Client): prozedurale Animationen über Motor6D.Transform.
	Zustände kommen vom Server als Attribute (State, AttackId, AttackTick, HitTick).
	Idle, Bewegung, Ausholen (Warnung), Angriff, Treffer-Reaktion, Geschwächt/Besiegt.
	Entfernte Kreaturen werden seltener bzw. gar nicht animiert (Performance).
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pals = require(ReplicatedStorage.Shared.Config.Pals)
local Attacks = require(ReplicatedStorage.Shared.Config.Attacks)

local Animator = {}
local recs = {}

local sin, cos, abs, rad, clamp, exp = math.sin, math.cos, math.abs, math.rad, math.clamp, math.exp
local CFA = CFrame.Angles
local CFN = CFrame.new

local Gaits = {
	gackerling  = { freq = 11, amp = 0.65, bob = 0.25, biped = true },
	glutwiesel  = { freq = 13, amp = 0.75, bob = 0.15 },
	moosbock    = { freq = 7.5, amp = 0.5, bob = 0.18 },
	flauschfunk = { freq = 4, amp = 0.25, bob = 0.0, hover = true },
	bachzange   = { freq = 14, amp = 0.35, bob = 0.06, crab = true },
	frostigel   = { freq = 15, amp = 0.6, bob = 0.1 },
	surrfluegel = { freq = 3, amp = 0.1, bob = 0.0, fly = true },
	daemmerluchs= { freq = 9.5, amp = 0.65, bob = 0.16 },
	morvath     = { freq = 3.2, amp = 0.22, bob = 0.35, boss = true },
	noxen       = { freq = 7, amp = 0.5, bob = 0.15, hover = true },
}

local function collect(model)
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then joints[d.Name] = d end
	end
	return joints
end

local function register(model, attempt)
	if recs[model] or not model:IsA("Model") or not model.Parent then return end
	local species = model:GetAttribute("Species")
	local def = species and Pals.Get(species)
	if not def then return end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root then
		-- Streaming: Teile kommen evtl. später an -> kurz erneut versuchen
		attempt = (attempt or 0) + 1
		if attempt <= 20 then task.delay(0.25, register, model, attempt) end
		return
	end
	local r = {
		model = model, root = root, def = def, joints = collect(model), gait = Gaits[def.model] or Gaits.glutwiesel,
		phase = math.random() * 10, scale = def.scale or 1, speed = 0, lastHit = -10, lastAtk = -10,
		hitTick = model:GetAttribute("HitTick") or 0, atkTick = model:GetAttribute("AttackTick") or 0,
		down = 0, wind = 0, strike = 0, accum = 0,
	}
	recs[model] = r
	-- später eintreffende Gelenke (Streaming/Replikation) nachtragen
	model.DescendantAdded:Connect(function(d)
		if d:IsA("Motor6D") then r.joints[d.Name] = d end
	end)
	model:GetAttributeChangedSignal("HitTick"):Connect(function()
		r.lastHit = os.clock()
		Animator.Flash(model)
	end)
	model:GetAttributeChangedSignal("AttackTick"):Connect(function() r.lastAtk = os.clock() end)
	model.AncestryChanged:Connect(function(_, parent) if not parent then recs[model] = nil end end)
end

-- kurzer weißer Treffer-Blitz
local flashing = {}
function Animator.Flash(model)
	if flashing[model] then return end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.35
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	flashing[model] = h
	task.delay(0.09, function()
		h:Destroy()
		flashing[model] = nil
	end)
end

local function setT(j, cf) if j then j.Transform = cf end end

local function animate(r, now, dt)
	local model = r.model
	local J = r.joints
	local g = r.gait
	local s = r.scale
	local state = model:GetAttribute("State") or "idle"
	local vel = r.root.AssemblyLinearVelocity
	local hs = Vector3.new(vel.X, 0, vel.Z).Magnitude
	r.speed += (hs - r.speed) * clamp(dt * 8, 0, 1)
	local move = clamp(r.speed / math.max(4, r.def.speed * 0.8), 0, 1.6)
	local t = now + r.phase

	local downTarget = (state == "downed" or state == "dead" or state == "capturing" or state == "vanish") and 1 or 0
	r.down += (downTarget - r.down) * clamp(dt * 5, 0, 1)
	local windTarget = (state == "windup") and 1 or 0
	r.wind += (windTarget - r.wind) * clamp(dt * 7, 0, 1)
	local sinceAtk = now - r.lastAtk
	local strike = 0
	if state == "attack" then r.strike = 1 end
	r.strike += (0 - r.strike) * clamp(dt * 5, 0, 1)
	strike = r.strike
	local hit = exp(-(now - r.lastHit) * 12)
	local down, wind = r.down, r.wind
	local atk = Attacks[model:GetAttribute("AttackId") or ""]
	local kind = atk and atk.kind or "lunge"

	-- Körper
	local breathe = sin(t * 2.2) * 0.04 * s
	local bob = g.hover and sin(t * 1.6) * 0.35 * s or abs(sin(t * g.freq * 0.5)) * g.bob * s * move
	local pitch = 0
	local roll = 0
	local yOff = breathe + bob
	-- Ausholen: zurück lehnen/ducken, je nach Angriffsart
	if kind == "charge" or kind == "lunge" then
		pitch += rad(10) * wind; yOff -= 0.25 * s * wind
		pitch -= rad(16) * strike
	elseif kind == "nova" then
		yOff += 0.4 * s * wind + sin(t * 40) * 0.05 * s * wind
		yOff -= 0.5 * s * strike
	elseif kind == "strike" or kind == "dive" then
		pitch -= rad(14) * wind
	else
		pitch -= rad(8) * wind
		pitch += rad(10) * strike
	end
	-- Treffer: zurückzucken + Zittern
	pitch -= rad(12) * hit
	roll += sin(now * 60) * rad(5) * hit
	-- geschwächt: auf die Seite kippen
	roll += rad(78) * down
	-- Zweibeiner watscheln beim Laufen: Körper kippt im Schritt-Takt zur Seite
	if g.biped then
		roll += math.sin(t * g.freq * (0.6 + 0.4 * move)) * rad(9) * math.min(move, 1) * (1 - down)
	end
	yOff -= (model:GetAttribute("RootHeight") or 2) * 0.45 * down
	if g.fly then
		yOff += sin(t * 2) * 0.4 * s * (1 - down)
		pitch += rad(-6) * move
	end
	if g.boss then pitch += sin(t * 0.8) * rad(2) end
	setT(J.Body, CFN(0, yOff, 0) * CFA(pitch, 0, roll))

	-- Kopf
	local lookYaw = sin(t * 0.55) * 0.35 * (1 - move * 0.6) * (1 - wind)
	local hp = sin(t * 0.9) * 0.08 - 0.35 * wind + 0.4 * strike + 0.5 * down
	if kind == "projectile" or kind == "beam" then hp = sin(t * 0.9) * 0.08 - 0.45 * wind + 0.25 * strike end
	setT(J.Head, CFA(hp, lookYaw, sin(t * 60) * 0.06 * hit))

	-- Beine
	local f = g.freq * (0.6 + 0.4 * move)
	local amp = g.amp * move * (1 - down)
	if g.biped then
		setT(J.LegL, CFA(sin(t * f) * amp, 0, 0))
		setT(J.LegR, CFA(sin(t * f + math.pi) * amp, 0, 0))
	elseif g.crab then
		setT(J.LegFL, CFA(0, sin(t * f) * amp, sin(t * f) * amp * 0.5))
		setT(J.LegBR, CFA(0, sin(t * f) * amp, sin(t * f) * amp * 0.5))
		setT(J.LegFR, CFA(0, sin(t * f + math.pi) * amp, sin(t * f + math.pi) * amp * 0.5))
		setT(J.LegBL, CFA(0, sin(t * f + math.pi) * amp, sin(t * f + math.pi) * amp * 0.5))
	else
		local dangle = (g.hover or g.fly) and (sin(t * 2) * 0.15 + 0.2) or 0
		local tuck = (g.hover and move > 0.3) and 0.3 or 0
		setT(J.LegFL, CFA(sin(t * f) * amp + dangle - tuck - 0.3 * wind, 0, 0))
		setT(J.LegBR, CFA(sin(t * f) * amp + dangle + tuck, 0, 0))
		setT(J.LegFR, CFA(sin(t * f + math.pi) * amp + dangle - tuck - 0.3 * wind, 0, 0))
		setT(J.LegBL, CFA(sin(t * f + math.pi) * amp + dangle + tuck, 0, 0))
	end

	-- Schwanz
	setT(J.Tail, CFA(sin(t * 1.3) * 0.08 + 0.2 * wind, sin(t * (1.8 + move * 4)) * (0.3 + move * 0.2), 0))

	-- Flügel
	if J.WingL then
		local flap
		if g.fly then
			flap = sin(t * 24) * 0.55
		elseif g.biped then
			flap = sin(t * 18) * (0.15 * move + 0.5 * wind) + 0.25 * strike
		else
			flap = sin(t * 2) * 0.1
		end
		flap *= (1 - down)
		setT(J.WingL, CFA(0, 0, flap))
		setT(J.WingR, CFA(0, 0, -flap))
		if J.WingL2 then
			local f2 = sin(t * 24 + 1.6) * 0.55 * (1 - down)
			setT(J.WingL2, CFA(0, 0, f2))
			setT(J.WingR2, CFA(0, 0, -f2))
		end
	end

	-- Scheren
	if J.ClawR then
		setT(J.ClawR, CFA(-0.6 * wind + 0.2 * strike + sin(t * 1.5) * 0.05, -0.5 * wind + 0.8 * strike, 0))
		setT(J.ClawL, CFA(sin(t * 1.7) * 0.06 - 0.3 * wind, 0.2 * wind, 0))
	end

	-- Arme (Boss)
	if J.ArmL then
		local sw = sin(t * f) * amp
		local raise = -1.1 * wind + 0.7 * strike
		setT(J.ArmL, CFA(sw + raise, 0, -0.15 * wind))
		setT(J.ArmR, CFA(-sw + raise, 0, 0.15 * wind))
	end

	-- Ohren / Antennen / Stacheln
	local twitch = (sin(t * 0.7) > 0.97) and sin(t * 40) * 0.25 or 0
	setT(J.EarL, CFA(0, 0, twitch - 0.25 * hit))
	setT(J.EarR, CFA(0, 0, -twitch + 0.25 * hit))
	if J.AntennaL then
		local wob = sin(t * 3) * 0.12 + sin(t * 45) * 0.12 * wind
		setT(J.AntennaL, CFA(0, 0, wob))
		setT(J.AntennaR, CFA(0, 0, -wob))
	end
	if J.Spikes then
		setT(J.Spikes, CFN(0, 0.25 * s * wind, 0) * CFA(sin(t * 50) * 0.03 * wind, 0, 0))
	end
end

function Animator.Start(folder)
	for _, m in ipairs(folder:GetChildren()) do register(m) end
	folder.ChildAdded:Connect(function(m)
		task.defer(register, m)
	end)
	local cam = workspace.CurrentCamera
	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		local cpos = cam.CFrame.Position
		for model, r in pairs(recs) do
			if not model.Parent then recs[model] = nil; continue end
			local dist = (r.root.Position - cpos).Magnitude
			if dist > 320 then continue end
			r.accum += dt
			local interval = dist > 140 and 1 / 12 or 0
			if r.accum >= interval then
				local step = r.accum
				r.accum = 0
				animate(r, now, step)
			end
		end
	end)
end

-- Porträt-/Vorschaumodelle: einfache Idle-Pose (für ViewportFrames)
function Animator.Register(model)
	register(model)
end

return Animator
