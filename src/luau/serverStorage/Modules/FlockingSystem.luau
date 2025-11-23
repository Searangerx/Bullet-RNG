--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Types
local T_Enemy = require(script.Parent.Parent.Types.Enemy)

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)

-- ███████╗██╗      ██████╗  ██████╗██╗  ██╗██╗███╗   ██╗ ██████╗ 
-- ██╔════╝██║     ██╔═══██╗██╔════╝██║ ██╔╝██║████╗  ██║██╔════╝ 
-- █████╗  ██║     ██║   ██║██║     █████╔╝ ██║██╔██╗ ██║██║  ███╗
-- ██╔══╝  ██║     ██║   ██║██║     ██╔═██╗ ██║██║╚██╗██║██║   ██║
-- ███████╗███████╗╚██████╔╝╚██████╗██║  ██╗██║██║ ╚████║╚██████╔╝
-- ╚══════╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 
--

local FlockingSystem = {}
FlockingSystem.__index = FlockingSystem

-- Spatial grid for performance optimization
-- stored as spatialGrid[x][z] = { [enemy] = true } for fast lookup and removal
local spatialGrid: { [number]: { [number]: { [T_Enemy.Enemy]: boolean } } } = {}
local gridSize = Settings.Enemy.SpatialGridSize

-- ██████╗ ██╗   ██╗██╗██╗     ██████╗ 
-- ██╔══██╗██║   ██║██║██║     ██╔══██╗
-- ██████╔╝██║   ██║██║██║     ██║  ██║
-- ██╔══██╗██║   ██║██║██║     ██║  ██║
-- ██████╔╝╚██████╔╝██║███████╗██████╔╝
-- ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ 
--

function FlockingSystem.new(): T_Enemy.FlockingSystem
	local self = setmetatable({}, FlockingSystem)
	return self :: T_Enemy.FlockingSystem
end

-- ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
-- ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
-- ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
-- ██║   ██║██╔══██╗██║  ██║██╔══██║   ██║   ██╔══╝  
-- ╚██████╔╝██║  ██║██████╔╝██║  ██║   ██║   ███████╗
-- ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
--

function FlockingSystem:GetGridCoordinates(position: Vector3): (number, number)
	local x = math.floor(position.X / gridSize)
	local z = math.floor(position.Z / gridSize)
	return x, z
end

function FlockingSystem:UpdateEnemyGridPosition(enemy: T_Enemy.Enemy)
	if not enemy.isAlive then 
		self:RemoveFromGrid(enemy)
		return 
	end
	
	local position = enemy:GetPosition()
	local newX, newZ = self:GetGridCoordinates(position)
	
	-- Check if grid position changed
	if enemy._lastGridX == newX and enemy._lastGridZ == newZ then
		return -- No change
	end
	
	-- Remove from old cell
	if enemy._lastGridX ~= nil and enemy._lastGridZ ~= nil then
		local oldX, oldZ = enemy._lastGridX, enemy._lastGridZ
		if spatialGrid[oldX] and spatialGrid[oldX][oldZ] then
			spatialGrid[oldX][oldZ][enemy] = nil
			-- Cleanup empty tables if needed (optional optimization)
			if next(spatialGrid[oldX][oldZ]) == nil then
				spatialGrid[oldX][oldZ] = nil
			end
		end
	end
	
	-- Add to new cell
	if not spatialGrid[newX] then
		spatialGrid[newX] = {}
	end
	if not spatialGrid[newX][newZ] then
		spatialGrid[newX][newZ] = {}
	end
	spatialGrid[newX][newZ][enemy] = true
	
	-- Update stored position
	enemy._lastGridX = newX
	enemy._lastGridZ = newZ
end

function FlockingSystem:RemoveFromGrid(enemy: T_Enemy.Enemy)
	if enemy._lastGridX ~= nil and enemy._lastGridZ ~= nil then
		local x, z = enemy._lastGridX, enemy._lastGridZ
		if spatialGrid[x] and spatialGrid[x][z] then
			spatialGrid[x][z][enemy] = nil
		end
		enemy._lastGridX = nil
		enemy._lastGridZ = nil
	end
end

function FlockingSystem:GetNeighbors(enemy: T_Enemy.Enemy, radius: number): { T_Enemy.Enemy }
	local neighbors: { T_Enemy.Enemy } = {}
	local position = enemy:GetPosition()
	local searchRadius = radius * enemy.size -- Scale radius by enemy size
	
	-- Get grid cells to check
	local minX = math.floor((position.X - searchRadius) / gridSize)
	local maxX = math.floor((position.X + searchRadius) / gridSize)
	local minZ = math.floor((position.Z - searchRadius) / gridSize)
	local maxZ = math.floor((position.Z + searchRadius) / gridSize)
	
	-- Check all relevant grid cells
	for x = minX, maxX do
		local row = spatialGrid[x]
		if row then
			for z = minZ, maxZ do
				local cellEnemies = row[z]
				if cellEnemies then
					for otherEnemy, _ in cellEnemies do
						if otherEnemy ~= enemy and otherEnemy.isAlive then
							local offset = otherEnemy:GetPosition() - position
							local distanceSq = offset:Dot(offset)
							
							local combinedRadius = searchRadius + (otherEnemy.size * radius)
							if distanceSq < (combinedRadius * combinedRadius) then
								table.insert(neighbors, otherEnemy)
							end
						end
					end
				end
			end
		end
	end
	
	return neighbors
end

-- Helper for finding enemies near a point (for collision checks)
function FlockingSystem:GetEnemiesInRadius(position: Vector3, radius: number): { T_Enemy.Enemy }
	local found: { T_Enemy.Enemy } = {}
	local minX = math.floor((position.X - radius) / gridSize)
	local maxX = math.floor((position.X + radius) / gridSize)
	local minZ = math.floor((position.Z - radius) / gridSize)
	local maxZ = math.floor((position.Z + radius) / gridSize)
	
	local radiusSq = radius * radius
	
	for x = minX, maxX do
		local row = spatialGrid[x]
		if row then
			for z = minZ, maxZ do
				local cellEnemies = row[z]
				if cellEnemies then
					for enemy, _ in cellEnemies do
						if enemy.isAlive then
							local offset = enemy:GetPosition() - position
							local distSq = offset:Dot(offset)
							local checkRadius = radius + enemy:GetCollisionRadius()
							if distSq < (checkRadius * checkRadius) then
								table.insert(found, enemy)
							end
						end
					end
				end
			end
		end
	end
	return found
end

-- ███████╗████████╗███████╗██████╗ ██████╗ ██╗███╗   ██╗ ██████╗ 
-- ██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██║████╗  ██║██╔════╝ 
-- ███████╗   ██║   █████╗  ██████╔╝██████╔╝██║██╔██╗ ██║██║  ███╗
-- ╚════██║   ██║   ██╔══╝  ██╔══██╗██╔══██╗██║██║╚██╗██║██║   ██║
-- ███████║   ██║   ███████╗██║  ██║██║  ██║██║██║ ╚████║╚██████╔╝
-- ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 
--

function FlockingSystem:CalculateSteering(enemy: T_Enemy.Enemy, neighbors: { T_Enemy.Enemy }): Vector3
	local position = enemy:GetPosition()
	local velocity = enemy:GetVelocity()
	
	-- Size-aware separation distance
	local separationDistance = Settings.Enemy.BaseSeparationDistance * enemy.size
	local alignmentRadius = Settings.Enemy.AlignmentRadius * enemy.size
	local cohesionRadius = Settings.Enemy.CohesionRadius * enemy.size
	
	local separationForce = Vector3.new(0, 0, 0)
	local alignmentForce = Vector3.new(0, 0, 0)
	local cohesionForce = Vector3.new(0, 0, 0)
	local seekForce = Vector3.new(0, 0, 0)
	
	local separationCount = 0
	local alignmentCount = 0
	local cohesionCount = 0
	
	-- Calculate forces from neighbors
	for _, neighbor in neighbors do
		local neighborPos = neighbor:GetPosition()
		local neighborVel = neighbor:GetVelocity()
		local offset = position - neighborPos
		local distance = offset.Magnitude
		
		-- Separation: steer away from nearby neighbors
		-- Larger enemies need more space, so scale separation by combined sizes
		local combinedSize = enemy.size + neighbor.size
		local desiredSeparation = separationDistance * combinedSize
		
		if distance > 0 and distance < desiredSeparation then
			-- Stronger separation when very close, weaker when further
			local strength = (desiredSeparation - distance) / desiredSeparation
			-- Increase strength exponentially when very close to prevent sticking
			strength = strength * strength
			separationForce = separationForce + offset.Unit * strength
			separationCount = separationCount + 1
		end
		
		-- Alignment: steer towards average heading of neighbors
		if distance > 0 and distance < alignmentRadius then
			alignmentForce = alignmentForce + neighborVel
			alignmentCount = alignmentCount + 1
		end
		
		-- Cohesion: steer towards average position of neighbors
		if distance > 0 and distance < cohesionRadius then
			cohesionForce = cohesionForce + neighborPos
			cohesionCount = cohesionCount + 1
		end
	end
	
	-- Average and weight the forces
	if separationCount > 0 then
		separationForce = separationForce / separationCount * Settings.Enemy.SeparationWeight
	end
	
	if alignmentCount > 0 then
		alignmentForce = (alignmentForce / alignmentCount - velocity) * Settings.Enemy.AlignmentWeight
	else
		alignmentForce = Vector3.new(0, 0, 0)
	end
	
	if cohesionCount > 0 then
		cohesionForce = ((cohesionForce / cohesionCount) - position) * Settings.Enemy.CohesionWeight
	else
		cohesionForce = Vector3.new(0, 0, 0)
	end
	
	-- Seek: steer toward target position (goal)
	-- Each enemy has its own target end point
	local targetEndPoint = enemy:GetTargetEndPoint()
	if targetEndPoint then
		local targetPosition = targetEndPoint.Position
		local targetArea = targetEndPoint.Size
		
		-- Use the enemy's unique target offset to spread them across the end zone
		local spreadX = 0
		local spreadZ = 0
		
		if enemy.targetOffset then
			-- Use the enemy's pre-assigned offset (normalized -1 to 1)
			if targetArea then
				-- Scale the offset by the End part's size to fill the entire area
				-- Use full size to spread across the entire end zone
				spreadX = enemy.targetOffset.X * targetArea.X * 0.8 -- Increased from 0.5 to 0.8 for better spread
				spreadZ = enemy.targetOffset.Z * targetArea.Z * 0.8
			else
				-- Default spread if no area specified
				spreadX = enemy.targetOffset.X * 15 -- Increased from 10
				spreadZ = enemy.targetOffset.Z * 15
			end
		end
		
		-- Create offset target position
		local offsetTarget = targetPosition + Vector3.new(spreadX, 0, spreadZ)
		
		local toTarget = (offsetTarget - position)
		toTarget = Vector3.new(toTarget.X, 0, toTarget.Z) -- Keep horizontal
		local distance = toTarget.Magnitude
		if distance > 0 then
			-- Normalize and scale by max speed to get desired velocity
			local desiredVelocity = toTarget.Unit * enemy.speed
			-- Seek force is the difference between desired and current velocity
			seekForce = (desiredVelocity - velocity) * Settings.Enemy.SeekWeight
		else
			-- Already at target, but still apply a small forward force
			seekForce = velocity.Unit * enemy.speed * Settings.Enemy.SeekWeight
		end
		
		-- Add lateral spreading force: push enemies away from the center of their target
		-- This helps prevent clustering by encouraging enemies to spread out laterally
		local lateralSpreadForce = Vector3.new(0, 0, 0)
		if enemy.targetOffset and targetArea then
			-- Calculate current position relative to target center
			local toCenter = position - targetPosition
			toCenter = Vector3.new(toCenter.X, 0, toCenter.Z) -- Keep horizontal
			
			-- Calculate desired lateral offset based on targetOffset
			local desiredLateralOffset = Vector3.new(
				enemy.targetOffset.X * targetArea.X * 0.4,
				0,
				enemy.targetOffset.Z * targetArea.Z * 0.4
			)
			
			-- Calculate how far we are from our desired lateral position
			local currentLateral = Vector3.new(toCenter.X, 0, toCenter.Z)
			local lateralDifference = desiredLateralOffset - currentLateral
			
			-- Only apply lateral force if we're too close to center (within 50% of target area)
			local distanceFromCenter = currentLateral.Magnitude
			local maxLateralDistance = math.max(targetArea.X, targetArea.Z) * 0.5
			
			if distanceFromCenter < maxLateralDistance then
				-- Apply lateral spreading force
				if lateralDifference.Magnitude > 0.1 then
					lateralSpreadForce = lateralDifference.Unit * Settings.Enemy.LateralSpreadWeight
				end
			end
		end
		
		-- Add lateral spread to seek force
		seekForce = seekForce + lateralSpreadForce
	else
		-- No target end point, apply small forward force
		seekForce = velocity.Unit * enemy.speed * Settings.Enemy.SeekWeight * 0.5
	end
	
	-- Combine forces
	local steeringForce = separationForce + alignmentForce + cohesionForce + seekForce
	
	-- Clamp to max steering force
	local forceMagnitude = steeringForce.Magnitude
	if forceMagnitude > Settings.Enemy.MaxSteeringForce then
		steeringForce = steeringForce.Unit * Settings.Enemy.MaxSteeringForce
	end
	
	return steeringForce
end

-- ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
-- ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
-- ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
-- ██║   ██║██╔══██╗██║  ██║██╔══██║   ██║   ██╔══╝  
-- ╚██████╔╝██║  ██║██████╔╝██║  ██║   ██║   ███████╗
-- ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
--

function FlockingSystem:Update(enemies: { T_Enemy.Enemy }, dt: number, allEnemies: { T_Enemy.Enemy }?)
	-- Update grid for ALL enemies (so neighbors are accurate)
	-- Ideally this is called separately or we assume allEnemies is passed if we only want to update steering for a subset
	
	local enemiesToUpdateGrid = allEnemies or enemies
	for _, enemy in enemiesToUpdateGrid do
		self:UpdateEnemyGridPosition(enemy)
	end
	
	-- Calculate steering for the subset 'enemies'
	for _, enemy in enemies do
		if enemy.isAlive then
			-- Get neighbors (using size-aware radii)
			local neighbors = self:GetNeighbors(
				enemy,
				math.max(Settings.Enemy.AlignmentRadius, Settings.Enemy.CohesionRadius)
			)
			
			-- Calculate steering force (includes seek toward target)
			local steeringForce = self:CalculateSteering(enemy, neighbors)
			
			-- Apply steering (will be applied in EnemyManager)
			enemy._steeringForce = steeringForce
		end
	end
end

-- Return
return FlockingSystem

