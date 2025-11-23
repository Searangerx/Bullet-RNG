--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Types
local T_Weapon = require(script.Parent.Parent.Types.Weapon)

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)
local EventManager = require(ReplicatedStorage.Shared.Modules.EventManager)
local Weapon = require(script.Parent.Parent.Classes.Weapon)
local EnemyManager = require(script.Parent.EnemyManager)

-- ██╗    ██╗███████╗ █████╗ ██████╗  ██████╗ ███╗   ██╗    ██╗  ██╗ █████╗ ███╗   ██╗██████╗ ██╗     ███████╗██████╗ 
-- ██║    ██║██╔════╝██╔══██╗██╔══██╗██╔═══██╗████╗  ██║    ██║  ██║██╔══██╗████╗  ██║██╔══██╗██║     ██╔════╝██╔══██╗
-- ██║ █╗ ██║█████╗  ███████║██████╔╝██║   ██║██╔██╗ ██║    ███████║███████║██╔██╗ ██║██║  ██║██║     █████╗  ██████╔╝
-- ██║███╗██║██╔══╝  ██╔══██║██╔══██╗██║   ██║██║╚██╗██║    ██╔══██║██╔══██║██║╚██╗██║██║  ██║██║     ██╔══╝  ██╔══██╗
-- ╚███╔███╔╝███████╗██║  ██║██║  ██║╚██████╔╝██║ ╚████║    ██║  ██║██║  ██║██║ ╚████║██████╔╝███████╗███████╗██║  ██║
--  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝
--

local WeaponHandler = {}

-- Track player weapons
WeaponHandler.playerWeapons = {} :: { [Player]: T_Weapon.Weapon }

-- ██╗███╗   ██╗██╗████████╗
-- ██║████╗  ██║██║╚══██╔══╝
-- ██║██╔██╗ ██║██║   ██║   
-- ██║██║╚██╗██║██║   ██║   
-- ██║██║ ╚████║██║   ██║   
-- ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   
--

function WeaponHandler:Init()
	-- Listen for weapon fire events
	EventManager.Instances.RemoteEvent.WeaponFire.OnServerEvent:Connect(function(player: Player, origin: Vector3, direction: Vector3)
		self:HandleWeaponFire(player, origin, direction)
	end)
	
	-- Listen for weapon reload events
	EventManager.Instances.RemoteEvent.WeaponReload.OnServerEvent:Connect(function(player: Player)
		-- Reload is handled client-side, but we can validate here if needed
	end)
	
	-- Track player weapons when they equip tools
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character.ChildAdded:Connect(function(child)
				if child:IsA("Tool") then
					self:RegisterPlayerWeapon(player, child)
				end
			end)
			
			-- Check for existing tools
			for _, child in character:GetChildren() do
				if child:IsA("Tool") then
					self:RegisterPlayerWeapon(player, child)
					break
				end
			end
		end)
	end)
end

-- ███████╗██╗██████╗ ███████╗
-- ██╔════╝██║██╔══██╗██╔════╝
-- █████╗  ██║██████╔╝█████╗  
-- ██╔══╝  ██║██╔══██╗██╔══╝  
-- ██║     ██║██║  ██║███████╗
-- ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝
--

function WeaponHandler:RegisterPlayerWeapon(player: Player, tool: Tool)
	local weapon = Weapon.new(tool)
	self.playerWeapons[player] = weapon
end

function WeaponHandler:HandleWeaponFire(player: Player, origin: Vector3, direction: Vector3)
	-- Get player's weapon
	local weapon = self.playerWeapons[player]
	local tool = nil
	
	if not weapon then
		-- Try to find weapon from character
		local character = player.Character
		if character then
			tool = character:FindFirstChildOfClass("Tool")
			if tool then
				weapon = Weapon.new(tool)
				self.playerWeapons[player] = weapon
			end
		end
	else
		tool = weapon.tool
	end
	
	if not weapon then
		warn("WeaponHandler: No weapon found for player:", player.Name)
		return
	end
	
	-- If origin is from camera (fallback), try to get actual muzzle position from tool
	if tool then
		local flare = tool:FindFirstChild("Flare")
		if flare and flare:IsA("BasePart") then
			-- Use the Flare part's world position as the muzzle
			origin = flare.CFrame.Position
		else
			-- Try MuzzleFlash part (for shotguns)
			local muzzleFlash = tool:FindFirstChild("MuzzleFlash")
			if muzzleFlash and muzzleFlash:IsA("BasePart") then
				origin = muzzleFlash.CFrame.Position
			else
				-- If no Flare or MuzzleFlash found, try Handle as fallback
				local handle = tool:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					origin = handle.CFrame.Position
				end
			end
		end
	end
	
	-- Fire weapon
	local result = weapon:Fire(origin, direction, player)
	
	-- Apply damage to all hit enemies (penetration)
	-- Deduplicate enemies to ensure each enemy only takes damage once per bullet
	local attributes = weapon:GetAttributes()
	local hitEnemies = {} :: {[any]: boolean} -- Track which enemies we've already damaged
	local hitCount = 0
	
	for _, hit in result.hits do
		if hit.hitEnemy and not hitEnemies[hit.hitEnemy] then
			-- This enemy hasn't been damaged yet - apply damage
			hitEnemies[hit.hitEnemy] = true
			hit.hitEnemy:TakeDamage(attributes.Damage)
			hitCount = hitCount + 1
			print("WeaponHandler: Hit enemy #" .. hitCount .. ", dealt " .. attributes.Damage .. " damage. Enemy health: " .. hit.hitEnemy.health)
		end
	end
	
	if hitCount > 0 then
		print("WeaponHandler: Total enemies hit: " .. hitCount .. " (penetration: " .. (hitCount - 1) .. ")")
	elseif #result.hits > 0 then
		print("WeaponHandler: Hit something but not an enemy")
	else
		print("WeaponHandler: Shot missed")
	end
	
	-- Notify client to play effects (use first hit or last hit position)
	local firstHit = result.hits[1]
	if firstHit then
		EventManager.Instances.RemoteEvent.WeaponFire:FireClient(
			player,
			origin,
			direction,
			firstHit.hitPart,
			firstHit.hitPosition
		)
	else
		-- No hits, just send the fire event
		EventManager.Instances.RemoteEvent.WeaponFire:FireClient(
			player,
			origin,
			direction,
			nil,
			nil
		)
	end
end

-- Return
return WeaponHandler

