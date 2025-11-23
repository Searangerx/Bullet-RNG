# Enemy Model Attributes Guide

This guide explains what attributes you need to add to your enemy models in Roblox Studio for the spawning and flocking system to work.

## Required Attributes

Add these attributes to the **Zombie_LOD0 model** (the root model) in each enemy folder:
`ReplicatedStorage > Prefabs > Mobs > [EnemyFolder] > Zombie_LOD0`

**Important**: You only need to add attributes to the LOD0 model, NOT to LOD1 or LOD2. The system reads attributes from the LOD0 model and clones the entire model (which includes LOD1 and LOD2 as children).

### Basic Configuration

- **`EnemyType`** (String)
  - Unique identifier for this enemy type (e.g., "Zombie_Basic", "Super_Zombie")
  - Used for spawning specific enemy types

- **`EnemySpeed`** (Number)
  - Base movement speed in studs per second
  - Example: `10` for normal speed, `15` for fast enemies

- **`EnemyHealth`** (Number)
  - Starting health points
  - Example: `100` for normal enemies, `500` for tank enemies

### Size and Physics

- **`EnemySize`** (Number)
  - Size multiplier that affects:
    - Collision radius (Size × 0.5)
    - Separation distance in flocking
    - Visual size of the enemy
  - Example: `1` for normal size, `3` for large enemies
  - **Important**: This directly affects how much space the enemy takes up in the swarm

- **`EnemyMass`** (Number)
  - Mass value for pushing calculations
  - Larger enemies can push smaller ones more easily
  - Example: `1` for normal, `5` for heavy enemies

### Spawning

- **`SpawnWeight`** (Number)
  - Weight for spawn probability when randomly selecting enemies
  - Higher values = more likely to spawn
  - Example: `1` for normal, `0.5` for rare, `2` for common

### LOD (Level of Detail) Distances

These control when the enemy switches between different detail levels based on distance from player:

- **`LOD0_Distance`** (Number)
  - Distance in studs to switch to highest detail (LOD0)
  - Example: `50`

- **`LOD1_Distance`** (Number)
  - Distance in studs to switch to medium detail (LOD1)
  - Example: `100`

- **`LOD2_Distance`** (Number)
  - Distance in studs to switch to lowest detail (LOD2)
  - Example: `200`

## Example Configuration

For a basic zombie:
```
EnemyType: "Zombie_Basic"
EnemySpeed: 10
EnemyHealth: 100
EnemySize: 1
EnemyMass: 1
SpawnWeight: 1
LOD0_Distance: 50
LOD1_Distance: 100
LOD2_Distance: 200
```

For a large super zombie:
```
EnemyType: "Super_Zombie"
EnemySpeed: 8
EnemyHealth: 500
EnemySize: 3
EnemyMass: 5
SpawnWeight: 0.3
LOD0_Distance: 75
LOD1_Distance: 150
LOD2_Distance: 300
```

## Model Structure Requirements

Your enemy models should be structured as:
```
[EnemyFolder] (e.g., Zombie_Basic)
├── Zombie_LOD0 (Model) - Highest detail
├── Zombie_LOD1 (Model) - Medium detail
└── Zombie_LOD2 (Model) - Lowest detail
```

Each LOD model should contain:
- `HumanoidRootPart` (Part) - Used for positioning
- `Collider` (Part) - Collision detection part
- Body parts (Head, Torso, Arms, Legs, etc.)

## Notes

- All attributes are optional and have defaults, but it's recommended to set them explicitly
- `EnemySize` is critical for proper swarm behavior - larger enemies will naturally take up more space
- The system automatically handles size-aware flocking, so enemies of different sizes will work together naturally
- LOD distances should increase with enemy size (larger enemies should switch LODs at greater distances)

