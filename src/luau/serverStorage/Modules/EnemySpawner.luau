--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Types
local T_Enemy = require(script.Parent.Parent.Types.Enemy)

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)
local Enemy = require(script.Parent.Parent.Classes.Enemy)

-- ███████╗███╗   ██╗███████╗███╗   ███╗██╗   ██╗    ███████╗██████╗  █████╗ ██╗    ██╗███╗   ██╗███████╗
-- ██╔════╝████╗  ██║██╔════╝████╗ ████║╚██╗ ██╔╝    ██╔════╝██╔══██╗██╔══██╗██║    ██║████╗  ██║██╔════╝
-- █████╗  ██╔██╗ ██║█████╗  ██╔████╔██║ ╚████╔╝     ███████╗██████╔╝███████║██║ █╗ ██║██╔██╗ ██║███████╗
-- ██╔══╝  ██║╚██╗██║██╔══╝  ██║╚██╔╝██║  ╚██╔╝      ╚════██║██╔═══╝ ██╔══██║██║███╗██║██║╚██╗██║╚════██║
-- ███████╗██║ ╚████║███████╗██║ ╚═╝ ██║   ██║       ███████║██║     ██║  ██║╚███╔███╔╝██║ ╚████║███████║
-- ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝     ╚═╝   ╚═╝       ╚══════╝╚═╝     ╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝
--

local EnemySpawner = {}
EnemySpawner.__index = EnemySpawner

-- ██████╗ ██╗   ██╗██╗██╗     ██████╗ 
-- ██╔══██╗██║   ██║██║██║     ██╔══██╗
-- ██████╔╝██║   ██║██║██║     ██║  ██║
-- ██╔══██╗██║   ██║██║██║     ██║  ██║
-- ██████╔╝╚██████╔╝██║███████╗██████╔╝
-- ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ 
--

function EnemySpawner.new(enemyPrefabs: { Model }, onEnemySpawned: ((T_Enemy.Enemy) -> nil)?, activeEnemiesGetter: (() -> { T_Enemy.Enemy })?): T_Enemy.EnemySpawner
	local self = setmetatable({}, EnemySpawner)
	
	self.enemyPrefabs = enemyPrefabs
	self.isSpawning = false
	self.spawnConnection = nil
	self.lastSpawnTime = 0
	self.onEnemySpawned = onEnemySpawned
	self.activeEnemiesGetter = activeEnemiesGetter -- Function to get active enemies for spawn checking
	
	-- Find all SpawnPoint and EndPoint MetaParts
	local gameFolder = Workspace:FindFirstChild("Game")
	self.spawnPoints = {} :: { BasePart }
	self.endPoints = {} :: { BasePart }
	
	if gameFolder then
		local metaPartsFolder = gameFolder:FindFirstChild("MetaParts")
		if metaPartsFolder then
			-- Find all SpawnPoint parts
			for _, child in metaPartsFolder:GetChildren() do
				if child:IsA("BasePart") and child.Name == "SpawnPoint" then
					table.insert(self.spawnPoints, child)
				elseif child:IsA("BasePart") and child.Name == "EndPoint" then
					table.insert(self.endPoints, child)
				end
			end
		end
	end
	
	-- Sort by position for consistent ordering (optional, but helps with cycling)
	table.sort(self.spawnPoints, function(a, b)
		-- Sort by X, then Z
		if math.abs(a.Position.X - b.Position.X) > 0.1 then
			return a.Position.X < b.Position.X
		end
		return a.Position.Z < b.Position.Z
	end)
	
	table.sort(self.endPoints, function(a, b)
		-- Sort by X, then Z
		if math.abs(a.Position.X - b.Position.X) > 0.1 then
			return a.Position.X < b.Position.X
		end
		return a.Position.Z < b.Position.Z
	end)
	
	-- Current spawn point index (for cycling)
	self.currentSpawnIndex = 1
	
	if #self.spawnPoints == 0 then
		warn("EnemySpawner: No SpawnPoint parts found!")
	end
	if #self.endPoints == 0 then
		warn("EnemySpawner: No EndPoint parts found!")
	end
	-- Only print once during initialization if both are found
	if #self.spawnPoints > 0 and #self.endPoints > 0 then
		print("EnemySpawner: Found", #self.spawnPoints, "SpawnPoint parts and", #self.endPoints, "EndPoint parts")
	end
	
	return self :: T_Enemy.EnemySpawner
end

-- ███████╗████████╗ █████╗ ██████╗ ████████╗
-- ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗╚══██╔══╝
-- ███████╗   ██║   ███████║██████╔╝   ██║   
-- ╚════██║   ██║   ██╔══██║██╔══██╗   ██║   
-- ███████║   ██║   ██║  ██║██║  ██║   ██║   
-- ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   
--

function EnemySpawner:Start()
	if self.isSpawning then return end
	if #self.spawnPoints == 0 or #self.endPoints == 0 then
		warn("EnemySpawner: Cannot start - No SpawnPoint or EndPoint parts found")
		return
	end
	
	self.isSpawning = true
	self.lastSpawnTime = 0
	
	-- Continuous spawning loop
	self.spawnConnection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		local timeSinceLastSpawn = currentTime - self.lastSpawnTime
		local spawnInterval = 1 / Settings.Enemy.SpawnRate
		
		if timeSinceLastSpawn >= spawnInterval then
			self:SpawnEnemy()
			self.lastSpawnTime = currentTime
		end
	end)
end

-- ███████╗████████╗ ██████╗ ██████╗ 
-- ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
-- ███████╗   ██║   ██║   ██║██████╔╝
-- ╚════██║   ██║   ██║   ██║██╔══██╗
-- ███████║   ██║   ╚██████╔╝██║  ██║
-- ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
--

function EnemySpawner:Stop()
	if not self.isSpawning then return end
	
	self.isSpawning = false
	if self.spawnConnection then
		self.spawnConnection:Disconnect()
		self.spawnConnection = nil
	end
end

-- ███████╗██████╗  █████╗ ██╗    ██╗███╗   ██╗
-- ██╔════╝██╔══██╗██╔══██╗██║    ██║████╗  ██║
-- ███████╗██████╔╝███████║██║ █╗ ██║██╔██╗ ██║
-- ╚════██║██╔══██╗██╔══██║██║███╗██║██║╚██╗██║
-- ███████║██║  ██║██║  ██║╚███╔███╔╝██║ ╚████║
-- ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═══╝
--

function EnemySpawner:GetSpawnPosition(): Vector3
	if #self.spawnPoints == 0 then
		return Vector3.new(0, 5, 0)
	end
	
	-- Cycle through spawn points
	local spawnPoint = self.spawnPoints[self.currentSpawnIndex]
	self.currentSpawnIndex = (self.currentSpawnIndex % #self.spawnPoints) + 1
	
	local spawnArea = Settings.Enemy.SpawnAreaSize
	local basePosition = spawnPoint.Position
	local minDistance = Settings.Enemy.MinSpawnDistance or 3 -- Minimum distance from other enemies
	
	-- Try to find a position that's not too close to other enemies
	local maxAttempts = 20
	
	for attempt = 1, maxAttempts do
		-- Random offset within spawn area
		local offsetX = (math.random() - 0.5) * spawnArea.X
		local offsetY = (math.random() - 0.5) * spawnArea.Y
		local offsetZ = (math.random() - 0.5) * spawnArea.Z
		
		local candidatePosition = basePosition + Vector3.new(offsetX, offsetY, offsetZ)
		
		-- Check if this position is too close to existing enemies
		local tooClose = false
		if self.activeEnemiesGetter then
			local activeEnemies = self.activeEnemiesGetter()
			for _, enemy in activeEnemies do
				if enemy.isAlive then
					local enemyPos = enemy:GetPosition()
					local distance = (enemyPos - candidatePosition).Magnitude
					local requiredDistance = minDistance + enemy:GetCollisionRadius()
					if distance < requiredDistance then
						tooClose = true
						break
					end
				end
			end
		end
		
		-- If position is good, use it
		if not tooClose then
			return candidatePosition
		end
	end
	
	-- If all attempts failed, spread out more by using a larger area
	local spreadMultiplier = 1.5
	local offsetX = (math.random() - 0.5) * spawnArea.X * spreadMultiplier
	local offsetY = (math.random() - 0.5) * spawnArea.Y
	local offsetZ = (math.random() - 0.5) * spawnArea.Z * spreadMultiplier
	return basePosition + Vector3.new(offsetX, offsetY, offsetZ)
end

function EnemySpawner:GetEnemyConfig(prefab: Model): T_Enemy.EnemyConfig?
	-- Read configuration from model attributes
	local enemyType = prefab:GetAttribute("EnemyType") or "Unknown"
	local enemySpeed = prefab:GetAttribute("EnemySpeed") or 10
	local enemyHealth = prefab:GetAttribute("EnemyHealth") or 100
	local enemySize = prefab:GetAttribute("EnemySize") or 1
	local enemyMass = prefab:GetAttribute("EnemyMass") or 1
	local spawnWeight = prefab:GetAttribute("SpawnWeight") or 1
	local lod0Distance = prefab:GetAttribute("LOD0_Distance") or 50
	local lod1Distance = prefab:GetAttribute("LOD1_Distance") or 100
	local lod2Distance = prefab:GetAttribute("LOD2_Distance") or 200
	
	return {
		EnemyType = tostring(enemyType),
		EnemySpeed = tonumber(enemySpeed) or 10,
		EnemyHealth = tonumber(enemyHealth) or 100,
		EnemySize = tonumber(enemySize) or 1,
		EnemyMass = tonumber(enemyMass) or 1,
		SpawnWeight = tonumber(spawnWeight) or 1,
		LOD0_Distance = tonumber(lod0Distance) or 50,
		LOD1_Distance = tonumber(lod1Distance) or 100,
		LOD2_Distance = tonumber(lod2Distance) or 200,
	}
end

function EnemySpawner:SelectRandomPrefab(): Model?
	if #self.enemyPrefabs == 0 then return nil end
	
	-- Weighted random selection
	local totalWeight = 0
	for _, prefab in self.enemyPrefabs do
		local config = self:GetEnemyConfig(prefab)
		if config then
			totalWeight = totalWeight + config.SpawnWeight
		end
	end
	
	if totalWeight == 0 then
		-- Fallback to uniform random
		return self.enemyPrefabs[math.random(#self.enemyPrefabs)]
	end
	
	local randomWeight = math.random() * totalWeight
	local currentWeight = 0
	
	for _, prefab in self.enemyPrefabs do
		local config = self:GetEnemyConfig(prefab)
		if config then
			currentWeight = currentWeight + config.SpawnWeight
			if randomWeight <= currentWeight then
				return prefab
			end
		end
	end
	
	-- Fallback
	return self.enemyPrefabs[math.random(#self.enemyPrefabs)]
end

function EnemySpawner:SpawnEnemy(enemyType: string?): T_Enemy.Enemy?
	-- Select prefab
	local prefab: Model?
	if enemyType then
		-- Find specific enemy type
		for _, p in self.enemyPrefabs do
			if p:GetAttribute("EnemyType") == enemyType then
				prefab = p
				break
			end
		end
	else
		-- Random selection
		prefab = self:SelectRandomPrefab()
	end
	
	if not prefab then
		warn("EnemySpawner: No enemy prefab available")
		return nil
	end
	
	-- Clone prefab
	local enemyModel = prefab:Clone()
	
	-- Get configuration
	local config = self:GetEnemyConfig(prefab)
	if not config then
		warn("EnemySpawner: Failed to get enemy config")
		enemyModel:Destroy()
		return nil
	end
	
	-- Get spawn position (this increments currentSpawnIndex)
	-- Store the spawn index BEFORE calling GetSpawnPosition so we can use it for end point assignment
	local spawnIndexBefore = self.currentSpawnIndex
	local spawnPosition = self:GetSpawnPosition()
	enemyModel:PivotTo(CFrame.new(spawnPosition))
	enemyModel.Parent = Workspace
	
	-- Create Enemy instance
	local enemy = Enemy.new(enemyModel, config)
	
	-- Assign an end point to this enemy (use corresponding index or random)
	local targetEndPoint: BasePart? = nil
	if #self.endPoints > 0 then
		-- Option 1: Use corresponding index (spawn point 1 -> end point 1)
		-- Use the spawn index that was used (before it was incremented)
		local endIndex = ((spawnIndexBefore - 1) % #self.endPoints) + 1
		targetEndPoint = self.endPoints[endIndex]
		
		-- Option 2: Random end point (uncomment to use instead)
		-- targetEndPoint = self.endPoints[math.random(#self.endPoints)]
	end
	
	-- Store target end point on enemy
	enemy.targetEndPoint = targetEndPoint
	
	-- Set initial velocity toward assigned end point
	if targetEndPoint then
		local direction = (targetEndPoint.Position - spawnPosition)
		direction = Vector3.new(direction.X, 0, direction.Z) -- Keep horizontal
		if direction.Magnitude > 0 then
			enemy.velocity = direction.Unit * config.EnemySpeed
		else
			enemy.velocity = Vector3.new(0, 0, -config.EnemySpeed) -- Default forward
		end
	else
		enemy.velocity = Vector3.new(0, 0, -config.EnemySpeed) -- Default forward
		warn("EnemySpawner: No end point assigned, using default forward velocity")
	end
	
	-- Notify callback if provided
	if self.onEnemySpawned then
		self.onEnemySpawned(enemy)
	end
	
	return enemy
end

-- Return
return EnemySpawner

