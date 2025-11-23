--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Types
local T_Weapon = require(script.Parent.Parent.Types.Weapon)

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)

-- Lazy load EnemyManager to avoid circular dependencies
local EnemyManager = nil
local function GetEnemyManager()
	if not EnemyManager then
		EnemyManager = require(script.Parent.Parent.Modules.EnemyManager)
	end
	return EnemyManager
end

-- ██╗    ██╗███████╗ █████╗ ██████╗  ██████╗ ███╗   ██╗
-- ██║    ██║██╔════╝██╔══██╗██╔══██╗██╔═══██╗████╗  ██║
-- ██║ █╗ ██║█████╗  ███████║██████╔╝██║   ██║██╔██╗ ██║
-- ██║███╗██║██╔══╝  ██╔══██║██╔══██╗██║   ██║██║╚██╗██║
-- ╚███╔███╔╝███████╗██║  ██║██║  ██║╚██████╔╝██║ ╚████║
--  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
--

local Weapon = {}
Weapon.__index = Weapon

-- ██████╗ ██╗   ██╗██╗██╗     ██████╗ 
-- ██╔══██╗██║   ██║██║██║     ██╔══██╗
-- ██████╔╝██║   ██║██║██║     ██║  ██║
-- ██╔══██╗██║   ██║██║██║     ██║  ██║
-- ██████╔╝╚██████╔╝██║███████╗██████╔╝
-- ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ 
--

function Weapon.new(tool: Tool): T_Weapon.Weapon
	local self = setmetatable({}, Weapon)
	
	self.tool = tool
	
	-- Get weapon attributes from tool attributes, or use defaults
	local attributes: T_Weapon.WeaponAttributes = {
		HorizontalSpread = tool:GetAttribute("HorizontalSpread") or Settings.Weapon.DefaultHorizontalSpread,
		AmmoCapacity = tool:GetAttribute("AmmoCapacity") or Settings.Weapon.DefaultAmmoCapacity,
		ReloadTime = tool:GetAttribute("ReloadTime") or Settings.Weapon.DefaultReloadTime,
		PenetrationChance = tool:GetAttribute("PenetrationChance") or Settings.Weapon.DefaultPenetrationChance,
		MaxPenetration = tool:GetAttribute("MaxPenetration") or Settings.Weapon.DefaultMaxPenetration,
		Damage = tool:GetAttribute("Damage") or Settings.Weapon.DefaultDamage,
		FireRate = tool:GetAttribute("FireRate") or Settings.Weapon.FireRate,
		BulletsPerShot = tool:GetAttribute("BulletsPerShot") or Settings.Weapon.DefaultBulletsPerShot,
	}
	
	self.attributes = attributes
	
	return self :: T_Weapon.Weapon
end

-- ███████╗██╗██████╗ ███████╗
-- ██╔════╝██║██╔══██╗██╔════╝
-- █████╗  ██║██████╔╝█████╗  
-- ██╔══╝  ██║██╔══██╗██╔══╝  
-- ██║     ██║██║  ██║███████╗
-- ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝
--

function Weapon:Fire(origin: Vector3, direction: Vector3, player: Player): {hits: {{hitPart: BasePart, hitPosition: Vector3, hitEnemy: any?}}}
	-- Ensure direction is flattened (no vertical component) - everything on same plane
	-- Note: Client already applies spread for multiple bullets, so we use the direction as-is
	local spreadDirection = Vector3.new(direction.X, 0, direction.Z)
	if spreadDirection.Magnitude > 0 then
		spreadDirection = spreadDirection.Unit
	else
		-- Fallback if direction is invalid
		spreadDirection = Vector3.new(0, 0, -1)
	end
	
	-- Track all hits for penetration
	local hits = {}
	local penetrationCount = 0
	local maxPenetration = self.attributes.MaxPenetration
	local enemyManager = GetEnemyManager()
	
	-- Create raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local filterList = {player.Character or player}
	raycastParams.FilterDescendantsInstances = filterList
	raycastParams.IgnoreWater = true
	
	-- Step 1: "Drill" phase - Find all potential targets along the ray
	-- We gather a list of everything the bullet *could* hit if it had infinite penetration
	-- We limit this by range and a reasonable upper limit to prevent infinite loops
	local potentialHits = {}
	local currentOrigin = origin
	local currentDirection = spreadDirection
	local totalDistance = 0
	local maxPotentialTargets = maxPenetration + 5 -- Optimization: Don't drill forever
	
	for i = 1, maxPotentialTargets do
		-- Calculate remaining distance
		local remainingDistance = Settings.Weapon.MaxRange - totalDistance
		if remainingDistance <= 0 then break end
		
		-- Perform raycast
		local raycastResult = Workspace:Raycast(currentOrigin, currentDirection * remainingDistance, raycastParams)
		
		if not raycastResult then
			break -- Hit nothing, stop drilling
		end
		
		local hitPart = raycastResult.Instance
		local hitPosition = raycastResult.Position
		local dist = (hitPosition - currentOrigin).Magnitude
		totalDistance = totalDistance + dist
		
		-- Check if it's an enemy
		local enemyModel = hitPart:FindFirstAncestorOfClass("Model")
		local hitEnemy = nil
		if enemyModel then
			hitEnemy = enemyManager:GetEnemyFromModel(enemyModel)
		end
		
		-- Record the potential hit
		table.insert(potentialHits, {
			hitPart = hitPart,
			hitPosition = hitPosition,
			hitEnemy = hitEnemy,
			enemyModel = enemyModel -- Store model for filtering
		})
		
		if hitEnemy then
			-- If it's an enemy, we *might* penetrate it
			-- Add to ignore list so we can see what's behind it
			table.insert(filterList, enemyModel)
			raycastParams.FilterDescendantsInstances = filterList -- CRITICAL: Must re-assign to update params
			
			-- Update origin to hit position for next ray (no offset needed if we filter the model)
			currentOrigin = hitPosition + (currentDirection * 0.05) -- Tiny offset just to be safe against floating point
		else
			-- Hit a wall/obstacle - stops the bullet immediately during drill phase
			-- (Unless we add wall penetration later)
			break 
		end
	end
	
	-- Step 2: Process phase - Roll for penetration and determine actual hits
	for i, hitInfo in ipairs(potentialHits) do
		-- Add to final hits list
		table.insert(hits, hitInfo)
		
		if hitInfo.hitEnemy then
			-- It's an enemy. Check if we penetrate.
			-- If we have reached max penetration count, we stop AFTER this hit.
			-- If penetration roll fails, we stop AFTER this hit.
			
			local shouldPenetrate = math.random() < self.attributes.PenetrationChance
			
			if shouldPenetrate and penetrationCount < maxPenetration then
				-- Penetrated! Continue to next target
				penetrationCount = penetrationCount + 1
			else
				-- Failed to penetrate or max penetration reached
				-- Bullet stops here
				break
			end
		else
			-- Hit a wall/obstacle. Bullet stops here.
			break
		end
	end
	
	return {hits = hits}
end

-- ██╗  ██╗███████╗██████╗ ███████╗
-- ██║  ██║██╔════╝██╔══██╗██╔════╝
-- ███████║█████╗  ██████╔╝███████╗
-- ██╔══██║██╔══╝  ██╔══██╗╚════██║
-- ██║  ██║███████╗██║  ██║███████║
-- ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝
--

function Weapon:GetAttributes(): T_Weapon.WeaponAttributes
	return self.attributes
end

-- Return
return Weapon

