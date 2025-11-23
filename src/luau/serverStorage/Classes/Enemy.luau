--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RaycastParams = RaycastParams

-- Types
local T_Enemy = require(script.Parent.Parent.Types.Enemy)

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)

-- Local vars
local Players = game:GetService("Players")

-- ███████╗███╗   ██╗███████╗███╗   ███╗██╗   ██╗
-- ██╔════╝████╗  ██║██╔════╝████╗ ████║╚██╗ ██╔╝
-- █████╗  ██╔██╗ ██║█████╗  ██╔████╔██║ ╚████╔╝ 
-- ██╔══╝  ██║╚██╗██║██╔══╝  ██║╚██╔╝██║  ╚██╔╝  
-- ███████╗██║ ╚████║███████╗██║ ╚═╝ ██║   ██║   
-- ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝     ╚═╝   ╚═╝   
--

local Enemy = {}
Enemy.__index = Enemy

-- ██████╗ ██╗   ██╗██╗██╗     ██████╗ 
-- ██╔══██╗██║   ██║██║██║     ██╔══██╗
-- ██████╔╝██║   ██║██║██║     ██║  ██║
-- ██╔══██╗██║   ██║██║██║     ██║  ██║
-- ██████╔╝╚██████╔╝██║███████╗██████╔╝
-- ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ 
--

function Enemy.new(model: Model, config: T_Enemy.EnemyConfig): T_Enemy.Enemy
	local self = setmetatable({}, Enemy)
	
	self.model = model
	self.config = config
	self.health = config.EnemyHealth
	self.size = config.EnemySize
	self.mass = config.EnemyMass
	self.speed = config.EnemySpeed
	self.collisionRadius = config.EnemySize * 0.5
	self.currentLOD = 0
	self.isAlive = true
	
	-- Store original colors of all parts for damage flash effect
	-- Optimization: Cache BaseParts to avoid calling GetDescendants repeatedly
	self._originalColors = {}
	self._parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			self._originalColors[part] = part.Color
			table.insert(self._parts, part)
		end
	end
	
	-- Track active flash restoration task to prevent conflicts
	self._flashRestoreTask = nil
	
	-- Get initial position from model
	-- HumanoidRootPart might be nested (e.g., inside Head), so search recursively
	local rootPart = model:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	if not rootPart then
		-- Fallback: try direct child
		rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	if rootPart then
		self.position = rootPart.Position
	else
		self.position = model:GetPivot().Position
	end
	
	-- Initialize velocity (will be set by spawner to move toward end)
	self.velocity = Vector3.new(0, 0, 0)
	self._steeringForce = Vector3.new(0, 0, 0)
	self.targetEndPoint = nil -- Will be set by spawner
	
	-- Assign a unique random target offset for this enemy
	-- This ensures each enemy has a different target point, spreading them out
	local random = Random.new()
	self.targetOffset = Vector3.new(
		(random:NextNumber() - 0.5) * 2, -- -1 to 1
		0,
		(random:NextNumber() - 0.5) * 2  -- -1 to 1
	)
	
	-- Set model size (don't resize HumanoidRootPart if it's nested, as it might break the rig)
	-- Instead, we'll use the Collider part or just let the model use its natural size
	if rootPart and rootPart.Parent == model then
		-- Only resize if it's a direct child
		rootPart.Size = Vector3.new(config.EnemySize, config.EnemySize, config.EnemySize)
	end
	
	-- Get Humanoid if it exists (for movement and health)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Configure humanoid
		humanoid.WalkSpeed = config.EnemySpeed
		humanoid.JumpPower = 0 -- Prevent jumping
		humanoid.Health = config.EnemyHealth
		humanoid.MaxHealth = config.EnemyHealth
		-- Let Humanoid handle physics naturally (PlatformStand = false)
		humanoid.PlatformStand = false
	end
	
	return self :: T_Enemy.Enemy
end

-- ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
-- ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
-- ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
-- ██║   ██║██╔══██╗██║  ██║██╔══██║   ██║   ██╔══╝  
-- ╚██████╔╝██║  ██║██████╔╝██║  ██║   ██║   ███████╗
-- ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
--

function Enemy:Update(dt: number, steeringForce: Vector3)
	if not self.isAlive then return end
	
	-- Smooth velocity changes to prevent stuttering
	-- Use acceleration-based movement instead of direct velocity changes
	local acceleration = steeringForce
	local maxAcceleration = self.speed * 10 -- Limit how fast velocity can change
	
	-- Clamp acceleration to prevent sudden direction changes
	if acceleration.Magnitude > maxAcceleration then
		acceleration = acceleration.Unit * maxAcceleration
	end
	
	-- Apply acceleration to velocity with smoothing
	self.velocity = self.velocity + acceleration * dt
	
	-- Apply velocity damping for smoother movement (reduces jitter)
	local dampingFactor = 0.95 -- Slight damping to smooth out oscillations
	self.velocity = self.velocity * dampingFactor
	
	-- Clamp velocity magnitude to max speed
	local speed = self.velocity.Magnitude
	if speed > self.speed then
		self.velocity = self.velocity.Unit * self.speed
	elseif speed < 0.1 then
		-- If velocity is too small, ensure we have at least a minimum forward velocity
		-- This prevents enemies from getting stuck
		-- Try to maintain direction toward goal if we have one
		if steeringForce.Magnitude > 0 then
			-- Use steering force direction
			self.velocity = steeringForce.Unit * (self.speed * 0.5)
		else
			-- Default forward direction if no steering
			self.velocity = Vector3.new(0, 0, -self.speed * 0.5)
		end
	end
	
	-- Use Humanoid to control movement - let Roblox physics handle ground collision
	local humanoid = self.model:FindFirstChildOfClass("Humanoid")
	local rootPart = self.model:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	if not rootPart then
		rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	
	if humanoid and rootPart then
		-- Update Humanoid walk speed smoothly (only change if significantly different)
		local currentWalkSpeed = humanoid.WalkSpeed
		local targetWalkSpeed = math.min(self.velocity.Magnitude, self.speed)
		
		-- Smooth walk speed changes to prevent stuttering
		if math.abs(currentWalkSpeed - targetWalkSpeed) > 0.5 then
			-- Interpolate walk speed for smoother transitions
			local speedChange = (targetWalkSpeed - currentWalkSpeed) * math.min(dt * 5, 1) -- Smooth interpolation
			humanoid.WalkSpeed = currentWalkSpeed + speedChange
		end
		
		-- Use Humanoid:Move() to control movement direction
		-- This lets Roblox handle physics, ground collision, etc.
		local moveDirection = self.velocity.Unit
		if moveDirection.Magnitude > 0.1 then
			-- Move in the direction of velocity
			humanoid:Move(moveDirection)
		else
			-- Stop moving if no velocity
			humanoid:Move(Vector3.new(0, 0, 0))
		end
		
		-- Update our tracked position from the actual root part position
		-- This keeps our position tracking in sync with where the Humanoid actually is
		self.position = rootPart.Position
		
		-- Let Humanoid handle rotation automatically - don't manually rotate
		-- Manual rotation can conflict with Humanoid movement and cause stuttering
	elseif rootPart then
		-- Fallback if no Humanoid - use direct position setting
		self.position = self.position + self.velocity * dt
		rootPart.Position = self.position
	end
end

-- ████████╗ █████╗ ██╗  ██╗███████╗    ██████╗  █████╗ ███╗   ███╗ █████╗ ██╗      ██████╗ 
-- ╚══██╔══╝██╔══██╗██║ ██╔╝██╔════╝    ██╔══██╗██╔══██╗████╗ ████║██╔══██╗██║     ██╔════╝ 
--    ██║   ███████║█████╔╝ █████╗      ██████╔╝███████║██╔████╔██║███████║██║     ██║  ███╗
--    ██║   ██╔══██║██╔═██╗ ██╔══╝      ██╔══██╗██╔══██║██║╚██╔╝██║██╔══██║██║     ██║   ██║
--    ██║   ██║  ██║██║  ██╗███████╗    ██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║███████╗╚██████╔╝
--    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ 
--

function Enemy:TakeDamage(damage: number)
	if not self.isAlive then return end
	
	self.health = self.health - damage
	
	-- Update Humanoid health if it exists
	local humanoid = self.model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = self.health
	end
	
	-- Flash red on damage - flash all parts of the enemy
	-- Cancel any existing flash restoration task
	if self._flashRestoreTask then
		task.cancel(self._flashRestoreTask)
		self._flashRestoreTask = nil
	end
	
	-- Change all parts to red
	-- Optimization: Use cached parts list
	for _, part in self._parts do
		if part then -- Check if part still exists
			-- Store original color if not already stored (for parts added after creation, though unlikely for optimized enemies)
			if not self._originalColors[part] then
				self._originalColors[part] = part.Color
			end
			part.Color = Color3.fromRGB(255, 0, 0)
		end
	end
	
	-- Restore original colors after delay
	self._flashRestoreTask = task.delay(0.1, function()
		if not self.model or not self.model.Parent then return end
		
		for part, originalColor in pairs(self._originalColors) do
			if part and part.Parent and part:IsA("BasePart") then
				part.Color = originalColor
			end
		end
		
		self._flashRestoreTask = nil
	end)
	
	if self.health <= 0 then
		self:Die()
	end
end

-- ██████╗ ██╗███████╗
-- ██╔══██╗██║██╔════╝
-- ██║  ██║██║█████╗  
-- ██║  ██║██║██╔══╝  
-- ██████╔╝██║██║     
-- ╚═════╝ ╚═╝╚═╝     
--

function Enemy:Die()
	if not self.isAlive then return end
	
	self.isAlive = false
	
	-- Kill Humanoid if it exists
	local humanoid = self.model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
	
	-- Play death animation (fall over)
	local rootPart = self.model:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	if not rootPart then
		rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	if rootPart then
		-- Rotate to fall forward
		local currentCFrame = rootPart.CFrame
		local fallRotation = currentCFrame * CFrame.Angles(math.rad(90), 0, 0)
		
		-- Tween to fallen position
		local TweenService = game:GetService("TweenService")
		local tween = TweenService:Create(
			rootPart,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = fallRotation}
		)
		tween:Play()
		
		-- Despawn after delay
		task.delay(2, function()
			if self.model and self.model.Parent then
				self.model:Destroy()
			end
		end)
	else
		-- If no root part, just destroy immediately
		task.delay(2, function()
			if self.model and self.model.Parent then
				self.model:Destroy()
			end
		end)
	end
end

-- LOD system removed - using single model with Humanoid
-- Keeping method for compatibility but it does nothing
function Enemy:UpdateLOD(distanceToPlayer: number)
	-- No LOD switching needed with single model
	-- This method is kept for compatibility but does nothing
end

-- ██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ 
-- ██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗
-- ███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝
-- ██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗
-- ██║  ██║███████╗███████╗██║     ███████╗██║  ██║
-- ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝
--

function Enemy:GetPosition(): Vector3
	return self.position
end

function Enemy:GetVelocity(): Vector3
	return self.velocity
end

function Enemy:GetCollisionRadius(): number
	return self.collisionRadius
end

function Enemy:GetTargetEndPoint(): BasePart?
	return self.targetEndPoint
end

-- Return
return Enemy

