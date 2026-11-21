-- Netzwerk-Hilfen: zentrale Remotes + validierter Request-Dispatcher mit Rate-Limit
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}
Net.Remotes = Remotes
Net.Fire = Remotes.Fire
Net.Reload = Remotes.Reload
Net.ThrowBall = Remotes.ThrowBall
Net.VFX = Remotes.VFX
Net.Notify = Remotes.Notify
Net.HitConfirm = Remotes.HitConfirm
Net.StateSync = Remotes.StateSync
Net.WeaponState = Remotes.WeaponState
Net.Request = Remotes.Request

local handlers = {}
local lastCall = {}

function Net.Handle(name, fn)
	handlers[name] = fn
end

function Net.NotifyPlayer(player, text, kind)
	if player and player.Parent then
		Net.Notify:FireClient(player, text, kind or "info")
	end
end

function Net.NotifyAll(text, kind)
	Net.Notify:FireAllClients(text, kind or "info")
end

function Net.BroadcastVFX(kind, data)
	Net.VFX:FireAllClients(kind, data)
end

Net.Request.OnServerInvoke = function(player, name, ...)
	if type(name) ~= "string" then return false, "Ungültige Anfrage" end
	local fn = handlers[name]
	if not fn then return false, "Unbekannte Aktion: " .. name end
	local key = player.UserId
	local now = os.clock()
	local lc = lastCall[key]
	if lc and now - lc < 0.08 then return false, "Zu schnell – bitte kurz warten" end
	lastCall[key] = now
	local ok, a, b = pcall(fn, player, ...)
	if not ok then
		warn("[Net] Fehler in Aktion " .. name .. ": " .. tostring(a))
		return false, "Serverfehler – Aktion abgebrochen"
	end
	return a, b
end

game:GetService("Players").PlayerRemoving:Connect(function(p) lastCall[p.UserId] = nil end)

return Net
