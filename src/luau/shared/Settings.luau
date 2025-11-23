--!strict

-- Services
local ReplicatedFirst   = game:GetService("ReplicatedFirst")

-- Data
local VERSION = require(ReplicatedFirst.Shared.VERSION)

-- Main
local Settings = {
	GameVersion = VERSION, -- Version number for playerData tests
}

Settings.Player = {
	CharacterWalkSpeed    = 16,
	CharacterJumpHeight   = 7.2,
	CharacterJumpPower    = 50,
	CharacterUseJumpPower = true, -- false = JumpHeight
	CharacterRespawnTime  = 5,
}

Settings.Audio = {
	MusicVolume   = 0.5,
	EffectsVolume = 0.8,
}

Settings.Enemy = {
	-- Spawner settings
	SpawnRate = 20, -- Enemies per second
	MaxActiveEnemies = 2000, -- Maximum enemies on screen at once
	SpawnAreaSize = Vector3.new(20, 5, 20), -- Spawn area dimensions
	SpawnCooldown = 0.1, -- Minimum time between spawns
	MinSpawnDistance = 3, -- Minimum distance between spawns (prevents overlapping)
	
	-- Flocking settings
	BaseSeparationDistance = 5, -- Base distance enemies try to stay apart (multiplied by enemy size) - increased to prevent clustering
	AlignmentRadius = 10, -- How far enemies look for neighbors to align with (scaled by enemy size)
	CohesionRadius = 15, -- How far enemies look for neighbors to group with (scaled by enemy size)
	SeparationWeight = 5.0, -- Strength of separation force (increased to prevent clustering)
	AlignmentWeight = 0.8, -- Strength of alignment force (slightly reduced)
	CohesionWeight = 0.1, -- Strength of cohesion force (greatly reduced to prevent clustering toward center)
	SeekWeight = 2.5, -- Strength of seek force toward goal (increased to maintain forward movement)
	LateralSpreadWeight = 1.5, -- Strength of lateral spreading force (pushes enemies away from center)
	MaxSteeringForce = 50, -- Maximum force that can be applied per frame
	SpatialGridSize = 20, -- Grid cell size for spatial partitioning (should accommodate largest enemy)
	
	-- Performance settings
	UpdateBatchSize = 100, -- Number of enemies to update per frame (increased for smoother updates)
	FlockingUpdateFrequency = 1, -- Update flocking every N frames (1 = every frame)
	DistanceCullRadius = 500, -- Skip updates for enemies beyond this distance
	LODUpdateFrequency = 10, -- Update LOD every N frames
}

Settings.Weapon = {
	-- Default weapon attributes (can be overridden per weapon)
	DefaultHorizontalSpread = 2, -- Degrees of horizontal spread
	DefaultAmmoCapacity = 12, -- Default magazine size
	DefaultReloadTime = 2.0, -- Seconds to reload
	DefaultPenetrationChance = 0.1, -- 0-1 chance to penetrate through enemies
	DefaultMaxPenetration = 1, -- Maximum number of enemies a bullet can penetrate through
	DefaultDamage = 25, -- Base damage per shot
	DefaultBulletsPerShot = 1, -- Number of bullets/projectiles fired per shot
	
	-- Weapon behavior
	MaxRange = 1000, -- Maximum effective range for raycasting
	FireRate = 0.15, -- Minimum time between shots (seconds)
	AutoReload = true, -- Automatically reload when ammo is empty
}

Settings.Character = {
	-- Doom-like movement settings
	MouseSensitivity = 0.5, -- Mouse look sensitivity
	MovementSpeed = 16, -- Walk speed (overrides Player.CharacterWalkSpeed)
	RunSpeed = 24, -- Run speed when holding shift
	JumpPower = 50, -- Jump power
	GroundCheckDistance = 5, -- Distance to check for ground
}


return Settings
