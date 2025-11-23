--!strict

-- Weapon attribute configuration
export type WeaponAttributes = {
	HorizontalSpread: number, -- Degrees of horizontal spread
	AmmoCapacity: number, -- Magazine size
	ReloadTime: number, -- Seconds to reload
	PenetrationChance: number, -- 0-1 chance to penetrate through enemies
	MaxPenetration: number, -- Maximum number of enemies a bullet can penetrate through
	Damage: number, -- Base damage per shot
	FireRate: number, -- Minimum time between shots (seconds)
	BulletsPerShot: number, -- Number of bullets/projectiles fired per shot (default: 1)
}

-- Weapon instance data
export type WeaponData = {
	tool: Tool,
	attributes: WeaponAttributes,
	currentAmmo: number,
	isReloading: boolean,
	lastFireTime: number,
}

return {}

