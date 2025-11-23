--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

-- Types
local T_Weapon = require(ReplicatedStorage.Shared.Types.Weapon)

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)
local EventManager = require(ReplicatedStorage.Shared.Modules.EventManager)

-- ClientStorage modules
-- Note: SoundHandler must be initialized before WeaponController uses it
local SoundHandler = require(script.Parent.SoundHandler)
local ParticleManager = require(script.Parent.ParticleManager)

-- ██╗    ██╗███████╗ █████╗ ██████╗  ██████╗ ███╗   ██╗    ██████╗ ██████╗ ███╗   ██╗████████╗██████╗  ██████╗ ██╗     ██╗     ███████╗██████╗ 
-- ██║    ██║██╔════╝██╔══██╗██╔══██╗██╔═══██╗████╗  ██║   ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔══██╗██╔═══██╗██║     ██║     ██╔════╝██╔══██╗
-- ██║ █╗ ██║█████╗  ███████║██████╔╝██║   ██║██╔██╗ ██║   ██║     ██║   ██║██╔██╗ ██║   ██║   ██████╔╝██║   ██║██║     ██║     █████╗  ██████╔╝
-- ██║███╗██║██╔══╝  ██╔══██║██╔══██╗██║   ██║██║╚██╗██║   ██║     ██║   ██║██║╚██╗██║   ██║   ██╔══██╗██║   ██║██║     ██║     ██╔══╝  ██╔══██╗
-- ╚███╔███╔╝███████╗██║  ██║██║  ██║╚██████╔╝██║ ╚████║   ╚██████╗╚██████╔╝██║ ╚████║   ██║   ██║  ██║╚██████╔╝███████╗███████╗███████╗██║  ██║
--  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝    ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
--

local WeaponController = {}
WeaponController.__index = WeaponController

-- Local player
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- ██████╗ ██╗   ██╗██╗██╗     ██████╗ 
-- ██╔══██╗██║   ██║██║██║     ██╔══██╗
-- ██████╔╝██║   ██║██║██║     ██║  ██║
-- ██╔══██╗██║   ██║██║██║     ██║  ██║
-- ██████╔╝╚██████╔╝██║███████╗██████╔╝
-- ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ 
--

export type WeaponController = typeof(setmetatable({} :: {
	currentWeapon: Tool?,
	weaponData: T_Weapon.WeaponData?,
	isReloading: boolean,
	lastFireTime: number,
	isHoldingFire: boolean,
	fireConnection: RBXScriptConnection?,
	mouseButton1Connection: RBXScriptConnection?,
	mouseButton1UpConnection: RBXScriptConnection?,
	reloadConnection: RBXScriptConnection?,
	slotSwitchConnection: RBXScriptConnection?,
	-- Weapon slots (slot number -> Tool)
	weaponSlots: {[number]: Tool},
	currentSlot: number?,
	-- Animation tracks
	holdAnimationTrack: AnimationTrack?,
	shootAnimationTrack: AnimationTrack?,
	reloadAnimationTrack: AnimationTrack?,
	humanoid: Humanoid?,
}, {}))

function WeaponController.new(): WeaponController
	local self = setmetatable({}, WeaponController)
	
	self.currentWeapon = nil :: Tool?
	self.weaponData = nil :: T_Weapon.WeaponData?
	self.isReloading = false
	self.lastFireTime = 0
	self.isHoldingFire = false
	self.fireConnection = nil
	
	-- Input connections
	self.mouseButton1Connection = nil
	self.mouseButton1UpConnection = nil
	self.reloadConnection = nil
	self.slotSwitchConnection = nil
	
	-- Weapon slots
	self.weaponSlots = {}
	self.currentSlot = nil
	
	-- Animation tracks
	self.holdAnimationTrack = nil
	self.shootAnimationTrack = nil
	self.reloadAnimationTrack = nil
	self.humanoid = nil
	
	return self
end

-- ██╗███╗   ██╗██╗████████╗
-- ██║████╗  ██║██║╚══██╔══╝
-- ██║██╔██╗ ██║██║   ██║   
-- ██║██║╚██╗██║██║   ██║   
-- ██║██║ ╚████║██║   ██║   
-- ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   
--

function WeaponController:Init()
	-- Wait for character
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	
	-- Set up weapon equipping
	player.CharacterAdded:Connect(function()
		self:OnCharacterAdded()
	end)
	
	if player.Character then
		self:OnCharacterAdded()
	end
	
	-- Listen for weapon fire events from server
	EventManager.Instances.RemoteEvent.WeaponFire.OnClientEvent:Connect(function(...)
		-- Server validation passed, play effects
		self:PlayFireEffects(...)
	end)
	
	-- Set up slot switching input
	self:SetupSlotSwitching()
end

function WeaponController:OnCharacterAdded()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	-- Wait for backpack
	local backpack = player:WaitForChild("Backpack")
	
	-- Watch for tools being added to backpack
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			-- Assign weapon to slot based on weapon name
			self:AssignWeaponToSlot(child)
			
			-- Auto-equip if no weapon is currently equipped
			if not self.currentWeapon and humanoid then
				humanoid:EquipTool(child)
			end
		end
	end)
	
	-- Watch for tools being removed from backpack (unequipped)
	backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			-- Remove from slot tracking
			for slot, weapon in pairs(self.weaponSlots) do
				if weapon == child then
					self.weaponSlots[slot] = nil
					if self.currentSlot == slot then
						self.currentSlot = nil
					end
					break
				end
			end
		end
	end)
	
	-- Watch for tools being equipped (moved to character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			self:EquipWeapon(child)
		end
	end)
	
	-- Watch for tools being unequipped (moved back to backpack)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and self.currentWeapon == child then
			self:UnequipWeapon()
		end
	end)
	
	-- Check if player already has a tool equipped
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			self:EquipWeapon(child)
			break
		end
	end
	
	-- Assign existing weapons in backpack to slots
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") then
			self:AssignWeaponToSlot(child)
		end
	end
	
	-- Auto-equip first available weapon if none equipped
	if not self.currentWeapon then
		-- Try slot 1 first, then slot 2
		if self.weaponSlots[1] and humanoid then
			humanoid:EquipTool(self.weaponSlots[1])
		elseif self.weaponSlots[2] and humanoid then
			humanoid:EquipTool(self.weaponSlots[2])
		end
	end
end

-- ███████╗ ██████╗ ██╗   ██╗██╗██████╗ ███████╗███╗   ██╗████████╗
-- ██╔════╝██╔═══██╗██║   ██║██║██╔══██╗██╔════╝████╗  ██║╚══██╔══╝
-- █████╗  ██║   ██║██║   ██║██║██████╔╝█████╗  ██╔██╗ ██║   ██║   
-- ██╔══╝  ██║   ██║╚██╗ ██╔╝██║██╔══██╗██╔══╝  ██║╚██╗██║   ██║   
-- ███████╗╚██████╔╝ ╚████╔╝ ██║██║  ██║███████╗██║ ╚████║   ██║   
-- ╚══════╝ ╚═════╝   ╚═════╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   
--

-- ██████╗ ██╗      █████╗ ██╗   ██╗███████╗██████╗ 
-- ██╔══██╗██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗
-- ██████╔╝██║     ███████║ ╚████╔╝ █████╗  ██████╔╝
-- ██╔═══╝ ██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗
-- ██║     ███████╗██║  ██║   ██║   ███████╗██║  ██║
-- ╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
--

-- Load animations from the tool's Animations folder
function WeaponController:LoadWeaponAnimations(tool: Tool): (AnimationTrack?, AnimationTrack?, AnimationTrack?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil, nil
	end
	
	self.humanoid = humanoid
	
	-- Find the Animations folder in the tool
	local animationsFolder = tool:FindFirstChild("Animations")
	if not animationsFolder then
		warn("WeaponController: No Animations folder found in tool:", tool.Name)
		return nil, nil, nil
	end
	
	-- Find individual animation objects
	local holdAnimObj = animationsFolder:FindFirstChild("Hold")
	local shootAnimObj = animationsFolder:FindFirstChild("Shoot")
	local reloadAnimObj = animationsFolder:FindFirstChild("Reload")
	
	-- Validate that they are Animation objects
	if holdAnimObj and not holdAnimObj:IsA("Animation") then
		warn("WeaponController: Hold is not an Animation object in tool:", tool.Name)
		holdAnimObj = nil
	end
	if shootAnimObj and not shootAnimObj:IsA("Animation") then
		warn("WeaponController: Shoot is not an Animation object in tool:", tool.Name)
		shootAnimObj = nil
	end
	if reloadAnimObj and not reloadAnimObj:IsA("Animation") then
		warn("WeaponController: Reload is not an Animation object in tool:", tool.Name)
		reloadAnimObj = nil
	end
	
	-- Preload animations if they exist
	local animsToPreload = {}
	if holdAnimObj then table.insert(animsToPreload, holdAnimObj) end
	if shootAnimObj then table.insert(animsToPreload, shootAnimObj) end
	if reloadAnimObj then table.insert(animsToPreload, reloadAnimObj) end
	
	if #animsToPreload > 0 then
		ContentProvider:PreloadAsync(animsToPreload)
	end
	
	-- Load animation tracks
	local holdTrack = holdAnimObj and humanoid:LoadAnimation(holdAnimObj) or nil
	local shootTrack = shootAnimObj and humanoid:LoadAnimation(shootAnimObj) or nil
	local reloadTrack = reloadAnimObj and humanoid:LoadAnimation(reloadAnimObj) or nil
	
	-- Configure hold animation to loop
	if holdTrack then
		holdTrack.Looped = true
		holdTrack.Priority = Enum.AnimationPriority.Action
	end
	
	-- Configure shoot animation
	if shootTrack then
		shootTrack.Looped = false
		shootTrack.Priority = Enum.AnimationPriority.Action
	end
	
	-- Configure reload animation
	if reloadTrack then
		reloadTrack.Looped = false
		reloadTrack.Priority = Enum.AnimationPriority.Action
	end
	
	return holdTrack, shootTrack, reloadTrack
end

-- Stop all weapon animations
function WeaponController:StopAllAnimations()
	if self.holdAnimationTrack then
		self.holdAnimationTrack:Stop()
	end
	if self.shootAnimationTrack then
		self.shootAnimationTrack:Stop()
	end
	if self.reloadAnimationTrack then
		self.reloadAnimationTrack:Stop()
	end
end

-- Get sound from the tool's SoundEffects folder
function WeaponController:GetWeaponSound(tool: Tool, soundName: string): Sound?
	local soundEffectsFolder = tool:FindFirstChild("SoundEffects")
	if not soundEffectsFolder then
		return nil
	end
	
	local sound = soundEffectsFolder:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		return sound
	end
	
	return nil
end

function WeaponController:EquipWeapon(tool: Tool)
	-- Unequip previous weapon
	if self.currentWeapon then
		self:UnequipWeapon()
	end
	
	self.currentWeapon = tool
	
	-- Update current slot based on which slot this weapon is in
	for slot, weapon in pairs(self.weaponSlots) do
		if weapon == tool then
			self.currentSlot = slot
			break
		end
	end
	
	-- Get weapon attributes
	local attributes: T_Weapon.WeaponAttributes = {
		HorizontalSpread = tool:GetAttribute("HorizontalSpread") or Settings.Weapon.DefaultHorizontalSpread,
		AmmoCapacity = tool:GetAttribute("AmmoCapacity") or Settings.Weapon.DefaultAmmoCapacity,
		ReloadTime = tool:GetAttribute("ReloadTime") or Settings.Weapon.DefaultReloadTime,
		PenetrationChance = tool:GetAttribute("PenetrationChance") or Settings.Weapon.DefaultPenetrationChance,
		Damage = tool:GetAttribute("Damage") or Settings.Weapon.DefaultDamage,
		FireRate = tool:GetAttribute("FireRate") or Settings.Weapon.FireRate,
		BulletsPerShot = tool:GetAttribute("BulletsPerShot") or Settings.Weapon.DefaultBulletsPerShot,
	}
	
	-- Initialize weapon data
	self.weaponData = {
		tool = tool,
		attributes = attributes,
		currentAmmo = attributes.AmmoCapacity,
		isReloading = false,
		lastFireTime = 0,
	}
	
	-- Play equip sound
	local equipSound = self:GetWeaponSound(tool, "Equip")
	if equipSound and SoundHandler.TriggerSound then
		SoundHandler:TriggerSound(equipSound, {})
	end
	
	-- Set up input connections
	self:SetupInputs()
	
	-- Load and play weapon animations from the tool's Animations folder
	local holdTrack, shootTrack, reloadTrack = self:LoadWeaponAnimations(tool)
	
	if holdTrack then
		self.holdAnimationTrack = holdTrack
		holdTrack:Play()
	end
	
	if shootTrack then
		self.shootAnimationTrack = shootTrack
	end
	
	if reloadTrack then
		self.reloadAnimationTrack = reloadTrack
	end
end

function WeaponController:UnequipWeapon()
	if not self.currentWeapon then return end
	
	-- Disconnect inputs
	if self.mouseButton1Connection then
		self.mouseButton1Connection:Disconnect()
		self.mouseButton1Connection = nil
	end
	if self.mouseButton1UpConnection then
		self.mouseButton1UpConnection:Disconnect()
		self.mouseButton1UpConnection = nil
	end
	if self.reloadConnection then
		self.reloadConnection:Disconnect()
		self.reloadConnection = nil
	end
	if self.slotSwitchConnection then
		self.slotSwitchConnection:Disconnect()
		self.slotSwitchConnection = nil
	end
	
	-- Stop continuous firing
	self.isHoldingFire = false
	self:StopContinuousFire()
	
	-- Note: Unequip sound removed - no longer in SoundEffects folder structure
	
	-- Stop all animations
	self:StopAllAnimations()
	
	self.currentWeapon = nil
	self.weaponData = nil
	self.holdAnimationTrack = nil
	self.shootAnimationTrack = nil
	self.reloadAnimationTrack = nil
	self.humanoid = nil
end

-- ███████╗██╗   ██╗██████╗ ███████╗
-- ██╔════╝██║   ██║██╔══██╗██╔════╝
-- █████╗  ██║   ██║██████╔╝█████╗  
-- ██╔══╝  ██║   ██║██╔══██╗██╔══╝  
-- ██║     ╚██████╔╝██████╔╝███████╗
-- ╚═╝      ╚═════╝ ╚═════╝ ╚══════╝
--

function WeaponController:SetupInputs()
	if not self.currentWeapon or not self.weaponData then return end
	
	-- Fire input - support both click and hold
	self.mouseButton1Connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isHoldingFire = true
			-- Fire immediately on click
			self:Fire()
			-- Start continuous firing loop
			self:StartContinuousFire()
		end
	end)
	
	-- Stop firing when mouse button is released
	self.mouseButton1UpConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isHoldingFire = false
			self:StopContinuousFire()
		end
	end)
	
	-- Reload input
	self.reloadConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.R then
			self:Reload()
		end
	end)
end

-- Set up slot switching input (number keys 1-9)
function WeaponController:SetupSlotSwitching()
	if self.slotSwitchConnection then
		self.slotSwitchConnection:Disconnect()
	end
	
	self.slotSwitchConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		-- Check for number keys 1-9
		local keyCode = input.KeyCode
		local slot = nil
		
		if keyCode == Enum.KeyCode.One then
			slot = 1
		elseif keyCode == Enum.KeyCode.Two then
			slot = 2
		elseif keyCode == Enum.KeyCode.Three then
			slot = 3
		elseif keyCode == Enum.KeyCode.Four then
			slot = 4
		elseif keyCode == Enum.KeyCode.Five then
			slot = 5
		elseif keyCode == Enum.KeyCode.Six then
			slot = 6
		elseif keyCode == Enum.KeyCode.Seven then
			slot = 7
		elseif keyCode == Enum.KeyCode.Eight then
			slot = 8
		elseif keyCode == Enum.KeyCode.Nine then
			slot = 9
		end
		
		if slot then
			self:SwitchToSlot(slot)
		end
	end)
end

-- Assign weapon to appropriate slot based on weapon name
function WeaponController:AssignWeaponToSlot(weapon: Tool)
	local weaponName = weapon.Name
	
	-- Assign pistol/handgun to slot 1
	if weaponName == "Handgun" or weaponName:find("Pistol") or weaponName:find("handgun") or weaponName:find("pistol") then
		self.weaponSlots[1] = weapon
	-- Assign shotgun to slot 2
	elseif weaponName:find("Shotgun") or weaponName:find("shotgun") or weaponName == "Nova Shotgun" then
		self.weaponSlots[2] = weapon
	end
end

-- Switch to a specific weapon slot
function WeaponController:SwitchToSlot(slot: number)
	local weapon = self.weaponSlots[slot]
	if not weapon then
		return -- No weapon in this slot
	end
	
	-- Don't switch if already on this slot
	if self.currentSlot == slot and self.currentWeapon == weapon then
		return
	end
	
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	-- Unequip current weapon
	if self.currentWeapon then
		humanoid:UnequipTools()
	end
	
	-- Equip weapon from slot
	humanoid:EquipTool(weapon)
end

-- ███████╗██╗██████╗ ███████╗
-- ██╔════╝██║██╔══██╗██╔════╝
-- █████╗  ██║██████╔╝█████╗  
-- ██╔══╝  ██║██╔══██╗██╔══╝  
-- ██║     ██║██║  ██║███████╗
-- ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝
--

function WeaponController:Fire()
	if not self.currentWeapon or not self.weaponData then return end
	if self.isReloading then return end
	
	-- Check fire rate
	local currentTime = tick()
	if currentTime - self.weaponData.lastFireTime < self.weaponData.attributes.FireRate then
		return
	end
	
	-- Check ammo
	if self.weaponData.currentAmmo <= 0 then
		if Settings.Weapon.AutoReload then
			-- Don't stop continuous fire - let reload handle it
			self:Reload()
		else
			-- Only stop if auto-reload is disabled
			self.isHoldingFire = false
			self:StopContinuousFire()
		end
		return
	end
	
	-- Get camera direction
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local cameraCFrame = camera.CFrame
	
	-- Get muzzle position from Flare or MuzzleFlash part (gun tip)
	local origin = cameraCFrame.Position -- Fallback to camera position
	local flare = self.currentWeapon:FindFirstChild("Flare")
	if flare and flare:IsA("BasePart") then
		-- Use the Flare part's world position as the muzzle
		origin = flare.CFrame.Position
	else
		-- Try MuzzleFlash part (for shotguns)
		local muzzleFlash = self.currentWeapon:FindFirstChild("MuzzleFlash")
		if muzzleFlash and muzzleFlash:IsA("BasePart") then
			origin = muzzleFlash.CFrame.Position
		else
			-- If no Flare or MuzzleFlash found, try Handle as fallback
			local handle = self.currentWeapon:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				origin = handle.CFrame.Position
			end
		end
	end
	
	-- Get camera look direction and flatten it (remove vertical component)
	-- Everything happens on the same horizontal plane
	local cameraLook = cameraCFrame.LookVector
	local baseDirection = Vector3.new(cameraLook.X, 0, cameraLook.Z)
	if baseDirection.Magnitude > 0 then
		baseDirection = baseDirection.Unit
	else
		-- Fallback if camera is looking straight up/down
		baseDirection = cameraCFrame.RightVector
		baseDirection = Vector3.new(baseDirection.X, 0, baseDirection.Z).Unit
	end
	
	-- Play shoot animation
	if self.shootAnimationTrack then
		self.shootAnimationTrack:Play()
	end
	
	-- Play shoot sound once per shot (not per bullet)
	-- Try "Shoot" first, then "Fire" as fallback for compatibility
	local shootSound = self:GetWeaponSound(self.currentWeapon, "Shoot")
	if not shootSound then
		shootSound = self:GetWeaponSound(self.currentWeapon, "Fire")
	end
	if shootSound and SoundHandler.TriggerSound then
		SoundHandler:TriggerSound(shootSound, {})
	end
	
	-- Play muzzle flash once per shot
	self:PlayMuzzleFlash()
	
	-- Fire multiple bullets if BulletsPerShot > 1
	local bulletsPerShot = self.weaponData.attributes.BulletsPerShot
	local spreadRadians = math.rad(self.weaponData.attributes.HorizontalSpread)
	local random = Random.new()
	
	for i = 1, bulletsPerShot do
		-- Calculate spread for this bullet
		local spreadAngle = (random:NextNumber() - 0.5) * 2 * spreadRadians -- -spreadRadians to spreadRadians
		
		-- Create a rotation around the up axis (Y) for horizontal spread
		local spreadRotation = CFrame.Angles(0, spreadAngle, 0)
		local direction = (spreadRotation * CFrame.lookAt(Vector3.new(0, 0, 0), baseDirection)).LookVector
		
		-- Ensure direction is flat
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude > 0 then
			direction = direction.Unit
		else
			direction = baseDirection
		end
		
		-- Create immediate bullet trail (will be updated when server responds)
		local estimatedEnd = origin + (direction * Settings.Weapon.MaxRange)
		self:CreateBulletTrail(origin, direction, estimatedEnd)
		
		-- Fire to server (each bullet is a separate fire event)
		EventManager.Instances.RemoteEvent.WeaponFire:FireServer(origin, direction)
	end
	
	-- Update ammo (only consume 1 ammo per shot, regardless of bullets per shot)
	self.weaponData.currentAmmo = self.weaponData.currentAmmo - 1
	self.weaponData.lastFireTime = currentTime
	
	-- Auto-reload if empty (handled in the ammo check above)
	-- Don't stop continuous fire here - let it continue after reload
end

-- ███████╗████████╗ ██████╗ ██████╗  █████╗ ██╗   ██╗███████╗
-- ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝██╔════╝
-- ███████╗   ██║   ██║   ██║██████╔╝███████║ ╚████╔╝ ███████╗
-- ╚════██║   ██║   ██║   ██║██╔══██╗██╔══██║  ╚██╔╝  ╚════██║
-- ███████║   ██║   ╚██████╔╝██║  ██║██║  ██║   ██║   ███████║
-- ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
--

function WeaponController:StartContinuousFire()
	-- Don't start if already firing or reloading
	if self.fireConnection or self.isReloading then
		return
	end
	
	-- Stop any existing fire loop
	self:StopContinuousFire()
	
	-- Start continuous fire loop
	self.fireConnection = RunService.Heartbeat:Connect(function()
		if self.isHoldingFire and not self.isReloading then
			-- Fire will check fire rate and ammo internally
			self:Fire()
		elseif not self.isHoldingFire then
			-- Only stop if player released the button (not if reloading)
			self:StopContinuousFire()
		end
		-- If reloading, keep the connection alive so we can resume after reload
	end)
end

function WeaponController:StopContinuousFire()
	if self.fireConnection then
		self.fireConnection:Disconnect()
		self.fireConnection = nil
	end
end

function WeaponController:PlayFireEffects(origin: Vector3, direction: Vector3, hitPart: BasePart?, hitPosition: Vector3?)
	if not self.currentWeapon or not self.weaponData then return end
	
	-- Note: Sound and muzzle flash are played once in Fire() before the bullet loop
	-- This function only handles updating bullet trails with actual hit positions
	
	-- Create bullet trail with actual hit position (if hit, otherwise use max range)
	-- Note: A trail was already created in Fire(), but this one uses the actual hit position
	if hitPosition then
		self:CreateBulletTrail(origin, direction, hitPosition)
	end
end

-- ██████╗ ███████╗██╗      ██████╗  █████╗ ██████╗ 
-- ██╔══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗
-- ██████╔╝█████╗  ██║     ██║   ██║███████║██║  ██║
-- ██╔══██╗██╔══╝  ██║     ██║   ██║██╔══██║██║  ██║
-- ██║  ██║███████╗███████╗╚██████╔╝██║  ██║██████╔╝
-- ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ 
--

function WeaponController:Reload()
	if not self.currentWeapon or not self.weaponData then return end
	if self.isReloading then return end
	if self.weaponData.currentAmmo >= self.weaponData.attributes.AmmoCapacity then return end
	
	self.isReloading = true
	self.weaponData.isReloading = true
	
	-- Stop hold animation during reload
	if self.holdAnimationTrack then
		self.holdAnimationTrack:Stop()
	end
	
	-- Play reload animation with speed adjustment
	if self.reloadAnimationTrack then
		-- Calculate speed multiplier based on reload time
		-- Get the actual animation length
		local animationLength = self.reloadAnimationTrack.Length
		local reloadTime = self.weaponData.attributes.ReloadTime
		
		-- Calculate speed multiplier to match reload time
		-- If animation is 2 seconds and reload time is 1 second, speed should be 2x
		local speedMultiplier = animationLength / reloadTime
		
		-- Clamp speed to reasonable values (0.1x to 3x)
		speedMultiplier = math.clamp(speedMultiplier, 0.1, 3.0)
		
		self.reloadAnimationTrack:AdjustSpeed(speedMultiplier)
		self.reloadAnimationTrack:Play()
	end
	
	-- Play reload sound
	local reloadSound = self:GetWeaponSound(self.currentWeapon, "Reload")
	if reloadSound and SoundHandler.TriggerSound then
		SoundHandler:TriggerSound(reloadSound, {})
	end
	
	-- Notify server
	EventManager.Instances.RemoteEvent.WeaponReload:FireServer()
	
	-- Wait for reload time
	task.wait(self.weaponData.attributes.ReloadTime)
	
	-- Stop reload animation
	if self.reloadAnimationTrack then
		self.reloadAnimationTrack:Stop()
	end
	
	-- Resume hold animation
	if self.holdAnimationTrack then
		self.holdAnimationTrack:Play()
	end
	
	-- Refill ammo
	self.weaponData.currentAmmo = self.weaponData.attributes.AmmoCapacity
	self.isReloading = false
	self.weaponData.isReloading = false
	
	-- If player is still holding fire button, resume continuous firing
	if self.isHoldingFire then
		self:StartContinuousFire()
	end
end

function WeaponController:PlayMuzzleFlash()
	if not self.currentWeapon then return end
	
	-- Try pistol-style muzzle flash (Flare > MuzzleFlash > Img)
	local flare = self.currentWeapon:FindFirstChild("Flare")
	if flare then
		local muzzleFlash = flare:FindFirstChild("MuzzleFlash")
		if muzzleFlash then
			local img = muzzleFlash:FindFirstChild("Img")
			if img and img:IsA("ImageLabel") then
				-- Show muzzle flash
				img.Visible = true
				task.delay(0.05, function()
					if img and img.Parent then
						img.Visible = false
					end
				end)
				return
			end
			
			-- Play flash script if it exists
			local script = muzzleFlash:FindFirstChild("Script")
			if script and script:IsA("Script") then
				-- Script will handle its own effects
				return
			end
		end
	end
	
	-- Try shotgun-style muzzle flash (direct MuzzleFlash part with particle emitters)
	local muzzleFlash = self.currentWeapon:FindFirstChild("MuzzleFlash")
	if muzzleFlash and muzzleFlash:IsA("BasePart") then
		-- Particle emitters will handle their own effects automatically
		-- No additional code needed - they fire when the weapon fires
		return
	end
end

-- ██████╗ ██╗   ██╗██╗     ██╗     ████████╗    ████████╗██████╗  █████╗ ██╗██╗     ██╗
-- ██╔══██╗██║   ██║██║     ██║     ╚══██╔══╝    ╚══██╔══╝██╔══██╗██╔══██╗██║██║     ██║
-- ██████╔╝██║   ██║██║     ██║        ██║          ██║   ██████╔╝███████║██║██║     ██║
-- ██╔══██╗██║   ██║██║     ██║        ██║          ██║   ██╔══██╗██╔══██║██║██║     ██║
-- ██████╔╝╚██████╔╝███████╗███████╗   ██║          ██║   ██║  ██║██║  ██║██║███████╗███████╗
-- ╚═════╝  ╚═════╝ ╚══════╝╚══════╝   ╚═╝          ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝
--

function WeaponController:CreateBulletTrail(startPosition: Vector3, direction: Vector3, endPosition: Vector3?)
	-- Calculate end position if not provided
	if not endPosition then
		endPosition = startPosition + (direction * Settings.Weapon.MaxRange)
	end
	
	-- Create a folder in Workspace to hold the trail (or use existing)
	local trailsFolder = Workspace:FindFirstChild("BulletTrails")
	if not trailsFolder then
		trailsFolder = Instance.new("Folder")
		trailsFolder.Name = "BulletTrails"
		trailsFolder.Parent = Workspace
	end
	
	-- Create a part to hold the attachments (Beam needs attachments parented to a BasePart)
	local trailPart = Instance.new("Part")
	trailPart.Name = "BulletTrail"
	trailPart.Anchored = true
	trailPart.CanCollide = false
	trailPart.Transparency = 1
	trailPart.Size = Vector3.new(0.1, 0.1, 0.1)
	trailPart.Position = startPosition
	trailPart.Parent = trailsFolder
	
	-- Create attachments for the beam
	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, 0, 0)
	attachment0.Parent = trailPart
	
	local attachment1 = Instance.new("Attachment")
	-- Calculate relative position from start to end
	local relativePosition = endPosition - startPosition
	attachment1.Position = relativePosition
	attachment1.Parent = trailPart
	
	-- Create the beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)), -- Yellow at start
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 0))   -- Orange at end
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),    -- Opaque at start
		NumberSequenceKeypoint.new(0.5, 0.3), -- Slightly transparent in middle
		NumberSequenceKeypoint.new(1, 1)      -- Fully transparent at end
	})
	beam.Width0 = 0.15
	beam.Width1 = 0.05
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.Brightness = 2
	beam.FaceCamera = true
	beam.Parent = trailPart
	
	-- Fade out and destroy after a short time
	task.spawn(function()
		-- Fade out over 0.15 seconds
		local fadeTime = 0.15
		local startTime = tick()
		
		while tick() - startTime < fadeTime do
			local progress = (tick() - startTime) / fadeTime
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, progress),
				NumberSequenceKeypoint.new(0.5, math.min(progress + 0.3, 1)),
				NumberSequenceKeypoint.new(1, 1)
			})
			task.wait()
		end
		
		-- Clean up
		trailPart:Destroy()
	end)
end

-- Return
return WeaponController

