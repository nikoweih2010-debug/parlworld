--[[
	SpawnService: wilde Kreaturen pro Zone (Worlds.List[1].zones) und feste Elite-Spawns.
	Spawnt nur, wenn ein Spieler in der Nähe ist; respektiert Maximalzahl und Respawn-Zeit.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local CreatureService = require(script.Parent.CreatureService)

local SpawnService = {}

local SAFE_CENTER = Vector3.new(0, 0, 0)
local SAFE_RADIUS = 48

local function weightedPick(tbl)
	local total = 0
	for _, w in pairs(tbl) do total += w end
	local r = math.random() * total
	for id, w in pairs(tbl) do
		r -= w
		if r <= 0 then return id end
	end
	for id in pairs(tbl) do return id end
end

local function anyPlayerNear(pos, radius)
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = CreatureService.CharRoot(p)
		if hrp and (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < radius then return true end
	end
	return false
end

local function findSpot(center, radius)
	for _ = 1, 8 do
		local a = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * radius
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if (Vector3.new(p.X, 0, p.Z) - SAFE_CENTER).Magnitude > SAFE_RADIUS then
			local gy = CreatureService.GroundY(p.X, p.Z)
			if gy and gy > 2.5 then return Vector3.new(p.X, gy, p.Z) end
		end
	end
	return nil
end

function SpawnService.Init()
	local world = Worlds.List[1]
	local zones = {}
	for _, z in ipairs(world.zones) do
		table.insert(zones, { cfg = z, alive = 0, nextSpawn = 0 })
	end
	local elites = {}
	for _, e in ipairs(world.elites) do
		table.insert(elites, { cfg = e, rec = nil, respawnAt = 0 })
	end

	task.spawn(function()
		while true do
			task.wait(1.5)
			local now = os.clock()
			for _, z in ipairs(zones) do
				local cfg = z.cfg
				if z.alive < cfg.max and now >= z.nextSpawn and anyPlayerNear(cfg.center, Worlds.SimulationRadius + cfg.radius) then
					local spot = findSpot(cfg.center, cfg.radius)
					if spot then
						local species = weightedPick(cfg.table)
						local lvl = math.random(cfg.levels[1], cfg.levels[2])
						local rec = CreatureService.Spawn(species, { level = lvl, position = spot, kind = "wild", team = "wild", zone = cfg.id })
						if rec then
							z.alive += 1
							rec.onRemoved = function()
								z.alive -= 1
								z.nextSpawn = math.max(z.nextSpawn, os.clock() + cfg.respawn)
							end
						end
						-- beim Füllen schnell, danach Respawn-Takt
						z.nextSpawn = now + (z.alive < math.ceil(cfg.max / 2) and 0.5 or 3)
					end
				end
			end
			for _, e in ipairs(elites) do
				if (not e.rec or e.rec.removed) and now >= e.respawnAt and anyPlayerNear(e.cfg.position, Worlds.SimulationRadius + 40) then
					local gy = CreatureService.GroundY(e.cfg.position.X, e.cfg.position.Z)
					if gy then
						local rec = CreatureService.Spawn(e.cfg.species, { level = e.cfg.level, position = Vector3.new(e.cfg.position.X, gy, e.cfg.position.Z), kind = "wild", team = "wild", zone = "elite" })
						if rec then
							e.rec = rec
							rec.model:SetAttribute("Elite", true)
							rec.onRemoved = function()
								e.respawnAt = os.clock() + e.cfg.respawn
							end
						end
					end
				end
			end
		end
	end)
end

return SpawnService
