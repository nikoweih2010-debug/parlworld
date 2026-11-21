-- ClientState: letzter Server-Schnappschuss + Request-Hilfe. Der Client ändert nie selbst Zustände.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientState = {}
ClientState.Data = nil
ClientState.ReceivedAt = 0
local changed = Instance.new("BindableEvent")
ClientState.Changed = changed.Event
ClientState.Remotes = Remotes

function ClientState.Request(name, ...)
	local ok, a, b = pcall(function(...) return Remotes.Request:InvokeServer(name, ...) end, ...)
	if not ok then return false, "Verbindungsfehler" end
	return a, b
end

local function apply(snap)
	if type(snap) ~= "table" then return end
	ClientState.Data = snap
	ClientState.ReceivedAt = os.clock()
	changed:Fire(snap)
end

Remotes.StateSync.OnClientEvent:Connect(apply)

task.spawn(function()
	for _ = 1, 20 do
		if ClientState.Data then return end
		local ok, snap = ClientState.Request("GetState")
		if ok and snap then apply(snap); return end
		task.wait(1)
	end
end)

-- Restzeit eines Boosts (Sekunden) unter Berücksichtigung der seit dem Sync vergangenen Zeit
function ClientState.BoostRemaining(id)
	local d = ClientState.Data
	if not d or not d.boosts[id] then return 0 end
	return math.max(0, d.boosts[id] - (os.clock() - ClientState.ReceivedAt))
end

function ClientState.OwnsWeapon(id)
	local d = ClientState.Data
	return d ~= nil and d.weapons[id] ~= nil
end

return ClientState
