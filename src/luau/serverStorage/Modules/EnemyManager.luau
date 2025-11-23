--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Types
local T_Enemy = require(script.Parent.Parent.Types.Enemy)

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)
local EnemySpawner = require(script.Parent.EnemySpawner)
local FlockingSystem = require(script.Parent.FlockingSystem)

-- ███████╗███╗   ██╗███████╗███╗   ███╗██╗   ██╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗ 
-- ██╔════╝████╗  ██║██╔════╝████╗ ████║╚██╗ ██╔╝    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
-- █████╗  ██╔██╗ ██║█████╗  ██╔████╔██║ ╚████╔╝     ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
-- ██╔══╝  ██║╚██╗██║██╔══╝  ██║╚██╔╝██║  ╚██╔╝      ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
-- ███████╗██║ ╚████║███████╗██║ ╚═╝ ██║   ██║       ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
-- ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝     ╚═╝   ╚═╝       ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
--

local EnemyManager = {}

-- Initialize singleton properties
EnemyManager.activeEnemies = {} :: { T_Enemy.Enemy }
EnemyManager.enemyPrefabs = {} :: { Model }
EnemyManager.isRunning = false
EnemyManager.updateConnection = nil
EnemyManager.flockingSystem = FlockingSystem.new()
EnemyManager.spawner = nil :: T_Enemy.EnemySpawner?
EnemyManager.frameCount = 0
EnemyManager.lastStatusUpdate = 0 -- Time of last status update

-- ██╗███╗   ██╗██╗████████╗
-- ██║████╗  ██║██║╚══██╔══╝
-- ██║██╔██╗ ██║██║   ██║   
-- ██║██║╚██╗██║██║   ██║   
-- ██║██║ ╚████║██║   ██║   
-- ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   
--

function EnemyManager:Init()
	-- Initialize arrays
	self.activeEnemies = {} :: { T_Enemy.Enemy }
	self.enemyLookup = {} :: { [Model]: T_Enemy.Enemy } -- Optimization: O(1) lookup
	self.enemyPrefabs = {} :: { Model }
	self.isRunning = false
	self.frameCount = 0
	self.lastStatusUpdate = tick()
	
	-- End points are now handled per-enemy, no need to store a single end part
	
	-- Find all enemy prefabs in ReplicatedStorage
	local prefabsFolder = ReplicatedStorage:FindFirstChild("Prefabs")
	if prefabsFolder then
		local mobsFolder = prefabsFolder:FindFirstChild("Mobs")
		if mobsFolder then
			-- Register each enemy type folder
			for _, enemyFolder in mobsFolder:GetChildren() do
				if enemyFolder:IsA("Folder") then
					-- Find the LOD0 model (prefer models with "LOD0" in the name, otherwise use first Model)
					local lod0Model: Model? = nil
					
					-- First, try to find a model with "LOD0" in the name
					for _, child in enemyFolder:GetChildren() do
						if child:IsA("Model") and string.find(child.Name:lower(), "lod0") then
							lod0Model = child
							break
						end
					end
					
					-- If no LOD0 model found, use the first Model in the folder
					if not lod0Model then
						lod0Model = enemyFolder:FindFirstChildOfClass("Model")
					end
					
					if lod0Model then
						table.insert(self.enemyPrefabs, lod0Model)
						print("EnemyManager: Registered enemy prefab:", enemyFolder.Name, "->", lod0Model.Name)
					else
						warn("EnemyManager: No model found in enemy folder:", enemyFolder.Name)
					end
				end
			end
		end
	end
	
	-- Create spawner with callback to register spawned enemies
	if #self.enemyPrefabs > 0 then
		self.spawner = EnemySpawner.new(
			self.enemyPrefabs, 
			function(enemy)
				self:RegisterSpawnedEnemy(enemy)
			end,
			function()
				return self.activeEnemies
			end
		)
	else
		warn("EnemyManager: No enemy prefabs found!")
	end
end

-- ███████╗████████╗ █████╗ ██████╗ ████████╗
-- ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗╚══██╔══╝
-- ███████╗   ██║   ███████║██████╔╝   ██║   
-- ╚════██║   ██║   ██╔══██║██╔══██╗   ██║   
-- ███████║   ██║   ██║  ██║██║  ██║   ██║   
-- ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   
--

function EnemyManager:Start()
	if self.isRunning then return end
	if not self.spawner then
		warn("EnemyManager: Cannot start - spawner not initialized")
		return
	end
	
	self.isRunning = true
	self.spawner:Start()
	
	-- Main update loop
	self.updateConnection = RunService.Heartbeat:Connect(function(dt)
		self:Update(dt)
	end)
end

-- ███████╗████████╗ ██████╗ ██████╗ 
-- ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
-- ███████╗   ██║   ██║   ██║██████╔╝
-- ╚════██║   ██║   ██║   ██║██╔══██╗
-- ███████║   ██║   ╚██████╔╝██║  ██║
-- ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
--

function EnemyManager:Stop()
	if not self.isRunning then return end
	
	self.isRunning = false
	if self.spawner then
		self.spawner:Stop()
	end
	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end
end

-- ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
-- ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
-- ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
-- ██║   ██║██╔══██╗██║  ██║██╔══██║   ██║   ██╔══╝  
-- ╚██████╔╝██║  ██║██████╔╝██║  ██║   ██║   ███████╗
-- ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
--

function EnemyManager:CheckPlayerCollisions()
	local players = Players:GetPlayers()
	
	for _, player in players do
		local character = player.Character
		if not character then continue end
		
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoidRootPart then continue end
		
		local playerPosition = humanoidRootPart.Position
		local playerRadius = 2 -- Approximate player collision radius
		
		-- Optimization: Use spatial grid to only check nearby enemies
		-- Search radius = max enemy size + player radius
		local searchRadius = 5 + playerRadius -- Assumes max enemy size is around 5
		local nearbyEnemies = self.flockingSystem:GetEnemiesInRadius(playerPosition, searchRadius)
		
		for _, enemy in nearbyEnemies do
			-- Precise check
			local distance = (enemy:GetPosition() - playerPosition).Magnitude
			local collisionDistance = playerRadius + enemy:GetCollisionRadius()
			
			if distance < collisionDistance then
				-- Enemy touches player - enemy dies, player takes damage
				enemy:Die()
				-- TODO: Deal damage to player (implement when player health system is ready)
			end
		end
	end
end

function EnemyManager:CheckEndZoneCollisions()
	-- Check each enemy against its assigned end point
	for i = #self.activeEnemies, 1, -1 do
		local enemy = self.activeEnemies[i]
		if not enemy.isAlive then continue end
		
		local targetEndPoint = enemy:GetTargetEndPoint()
		if not targetEndPoint then continue end
		
		local endPosition = targetEndPoint.Position
		local endRadius = math.max(targetEndPoint.Size.X, targetEndPoint.Size.Z) * 0.5 + 5 -- Use part size + buffer
		
		local enemyPosition = enemy:GetPosition()
		local distance = (enemyPosition - endPosition).Magnitude
		
		if distance < endRadius then
			-- Enemy reached its target end point - enemy dies
			enemy:Die()
		end
	end
end

-- UpdateLODs function removed - using single model with Humanoid, no LOD switching needed

function EnemyManager:CleanupDeadEnemies()
	for i = #self.activeEnemies, 1, -1 do
		local enemy = self.activeEnemies[i]
		if not enemy.isAlive or not enemy.model.Parent then
			if enemy.model then
				self.enemyLookup[enemy.model] = nil
			end
			table.remove(self.activeEnemies, i)
		end
	end
end

function EnemyManager:Update(dt: number)
	-- Clean up dead enemies
	self:CleanupDeadEnemies()
	
	-- Spawn new enemies (handled by spawner, but check limit)
	if self.spawner and #self.activeEnemies < Settings.Enemy.MaxActiveEnemies then
		-- Spawner handles its own timing
	elseif self.spawner then
		-- At max capacity, temporarily stop spawning
		self.spawner:Stop()
	elseif #self.activeEnemies < Settings.Enemy.MaxActiveEnemies then
		-- Resume spawning if under limit
		if self.spawner then
			self.spawner:Start()
		end
	end
	
	-- Update flocking (Time-sliced steering, but full grid update)
	-- Calculate steering for a batch of enemies each frame
	local batchSize = Settings.Enemy.UpdateBatchSize
	local totalEnemies = #self.activeEnemies
	if totalEnemies > 0 then
		local numBatches = math.ceil(totalEnemies / batchSize)
		local currentBatchIndex = self.frameCount % numBatches
		local startIndex = currentBatchIndex * batchSize + 1
		local endIndex = math.min(startIndex + batchSize - 1, totalEnemies)
		
		local flockingBatch = {}
		for i = startIndex, endIndex do
			table.insert(flockingBatch, self.activeEnemies[i])
		end
		
		-- Update grid for ALL (incremental is fast), calculate steering for BATCH
		self.flockingSystem:Update(flockingBatch, dt, self.activeEnemies)
	end
	
	-- Update movement for ALL enemies every frame (smooth movement)
	for _, enemy in self.activeEnemies do
		if enemy.isAlive then
			-- Use the most recently calculated steering force
			-- We do NOT clear it, so the enemy continues steering in that direction until next update
			local steeringForce = enemy._steeringForce or Vector3.new(0, 0, 0)
			
			-- Update enemy physics/movement
			enemy:Update(dt, steeringForce)
		end
	end
	
	-- Check collisions
	self:CheckPlayerCollisions()
	self:CheckEndZoneCollisions()
	
	-- Periodic status update (every 10 seconds)
	local currentTime = tick()
	if currentTime - self.lastStatusUpdate >= 10 then
		print("EnemyManager: Active enemies:", #self.activeEnemies)
		self.lastStatusUpdate = currentTime
	end
	
	-- LOD updates removed (using single model with Humanoid)
	-- self:UpdateLODs() -- No longer needed
	
	-- Increment frame counter
	self.frameCount = self.frameCount + 1
end

-- ██████╗ ███████╗ ██████╗ ██╗███████╗██████╗ ███████╗████████╗██████╗ 
-- ██╔══██╗██╔════╝██╔════╝ ██║██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔══██╗
-- ██████╔╝█████╗  ██║  ███╗██║█████╗  ██████╔╝███████╗   ██║   ██████╔╝
-- ██╔══██╗██╔══╝  ██║   ██║██║██╔══╝  ██╔══██╗╚════██║   ██║   ██╔══██╗
-- ██║  ██║███████╗╚██████╔╝██║███████╗██║  ██║███████║   ██║   ██║  ██║
-- ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝
--

function EnemyManager:RegisterEnemyPrefab(prefab: Model)
	table.insert(self.enemyPrefabs, prefab)
	if self.spawner then
		-- Recreate spawner with updated prefabs
		local wasSpawning = self.spawner.isSpawning
		self.spawner:Stop()
		self.spawner = EnemySpawner.new(
			self.enemyPrefabs, 
			function(enemy)
				self:RegisterSpawnedEnemy(enemy)
			end,
			function()
				return self.activeEnemies
			end
		)
		if wasSpawning then
			self.spawner:Start()
		end
	end
end

function EnemyManager:GetActiveEnemies(): { T_Enemy.Enemy }
	return self.activeEnemies
end

function EnemyManager:GetEnemyCount(): number
	return #self.activeEnemies
end

-- Hook into spawner to track spawned enemies
-- We need to modify EnemySpawner to call a callback, or we can check for new enemies
-- For now, let's add a method to register spawned enemies
function EnemyManager:RegisterSpawnedEnemy(enemy: T_Enemy.Enemy)
	table.insert(self.activeEnemies, enemy)
	self.enemyLookup[enemy.model] = enemy
	-- Removed frequent print - status updates now happen every 10 seconds in Update()
end

function EnemyManager:GetEnemyFromModel(model: Model): T_Enemy.Enemy?
	-- Optimization: O(1) lookup instead of O(N) linear search
	return self.enemyLookup[model]
end

-- Return
return EnemyManager

