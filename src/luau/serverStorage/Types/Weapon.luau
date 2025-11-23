--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Re-export shared types
local SharedWeaponTypes = require(ReplicatedStorage.Shared.Types.Weapon)

export type WeaponAttributes = {
	HorizontalSpread: number,
	AmmoCapacity: number,
	ReloadTime: number,
	PenetrationChance: number,
	MaxPenetration: number,
	Damage: number,
	FireRate: number,
	BulletsPerShot: number,
}

export type WeaponData = {
	tool: Tool,
	attributes: WeaponAttributes,
	currentAmmo: number,
	isReloading: boolean,
	lastFireTime: number,
}

-- Weapon class type
export type Weapon = {
	-- Properties
	tool: Tool,
	attributes: WeaponAttributes,
	
	-- Methods
	Fire: (self: Weapon, origin: Vector3, direction: Vector3, player: Player) -> {hits: {{hitPart: BasePart, hitPosition: Vector3, hitEnemy: any?}}},
	GetAttributes: (self: Weapon) -> WeaponAttributes,
}

return {}

