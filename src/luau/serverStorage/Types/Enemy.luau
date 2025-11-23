--!strict

-- Enemy Configuration (from model attributes)
export type EnemyConfig = {
	EnemyType: string,
	EnemySpeed: number,
	EnemyHealth: number,
	EnemySize: number,
	EnemyMass: number,
	SpawnWeight: number,
	LOD0_Distance: number,
	LOD1_Distance: number,
	LOD2_Distance: number,
}

-- Enemy Instance
export type Enemy = {
	model: Model,
	config: EnemyConfig,
	position: Vector3,
	velocity: Vector3,
	health: number,
	size: number,
	mass: number,
	speed: number,
	collisionRadius: number,
	currentLOD: number,
	isAlive: boolean,
	_steeringForce: Vector3?, -- Internal: set by FlockingSystem
	targetOffset: Vector3?, -- Unique offset from center target for this enemy
	targetEndPoint: BasePart?, -- The end point this enemy is moving toward
	_originalColors: {[BasePart]: Color3}?, -- Internal: original colors for damage flash
	_flashRestoreTask: thread?, -- Internal: active flash restoration task
	
	Update: (self: Enemy, dt: number, steeringForce: Vector3) -> nil,
	TakeDamage: (self: Enemy, damage: number) -> nil,
	Die: (self: Enemy) -> nil,
	UpdateLOD: (self: Enemy, distanceToPlayer: number) -> nil,
	GetPosition: (self: Enemy) -> Vector3,
	GetVelocity: (self: Enemy) -> Vector3,
	GetCollisionRadius: (self: Enemy) -> number,
	GetTargetEndPoint: (self: Enemy) -> BasePart?,
}

-- Flocking System
export type FlockingSystem = {
	Update: (self: FlockingSystem, enemies: { Enemy }, dt: number) -> nil,
	CalculateSteering: (self: FlockingSystem, enemy: Enemy, neighbors: { Enemy }) -> Vector3,
	GetNeighbors: (self: FlockingSystem, enemy: Enemy, enemies: { Enemy }, radius: number) -> { Enemy },
}

-- Enemy Spawner
export type EnemySpawner = {
	isSpawning: boolean,
	spawnPoints: { BasePart },
	endPoints: { BasePart },
	currentSpawnIndex: number,
	Start: (self: EnemySpawner) -> nil,
	Stop: (self: EnemySpawner) -> nil,
	SpawnEnemy: (self: EnemySpawner, enemyType: string?) -> Enemy?,
	GetSpawnPosition: (self: EnemySpawner) -> Vector3,
}

-- Enemy Manager
export type EnemyManager = {
	Init: (self: EnemyManager) -> nil,
	Start: (self: EnemyManager) -> nil,
	Stop: (self: EnemyManager) -> nil,
	RegisterEnemyPrefab: (self: EnemyManager, prefab: Model) -> nil,
	GetActiveEnemies: (self: EnemyManager) -> { Enemy },
	GetEnemyCount: (self: EnemyManager) -> number,
}

-- Return
return {}

