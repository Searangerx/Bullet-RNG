--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Modules
local Settings = require(ReplicatedStorage.Shared.Settings)

-- ██████╗██╗  ██╗ █████╗ ██████╗ ████████╗███████╗██████╗     ██████╗ ██████╗ ███╗   ██╗████████╗██████╗  ██████╗ ██╗     ██╗     ███████╗██████╗ 
-- ██╔════╝██║  ██║██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██╔══██╗   ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔══██╗██╔═══██╗██║     ██║     ██╔════╝██╔══██╗
-- ██║     ███████║███████║██████╔╝   ██║   █████╗  ██████╔╝   ██║     ██║   ██║██╔██╗ ██║   ██║   ██████╔╝██║   ██║██║     ██║     █████╗  ██████╔╝
-- ██║     ██╔══██║██╔══██║██╔══██╗   ██║   ██╔══╝  ██╔══██╗   ██║     ██║   ██║██║╚██╗██║   ██║   ██╔══██╗██║   ██║██║     ██║     ██╔══╝  ██╔══██╗
-- ╚██████╗██║  ██║██║  ██║██║  ██║   ██║   ███████╗██║  ██║   ╚██████╗╚██████╔╝██║ ╚████║   ██║   ██║  ██║╚██████╔╝███████╗███████╗███████╗██║  ██║
--  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝    ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
--

local CharacterController = {}
CharacterController.__index = CharacterController

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

export type CharacterController = typeof(setmetatable({} :: {
	moveVector: Vector3,
	isRunning: boolean,
	connection: RBXScriptConnection?,
}, {}))

function CharacterController.new(): CharacterController
	local self = setmetatable({}, CharacterController)
	
	self.moveVector = Vector3.new(0, 0, 0)
	self.isRunning = false
	self.connection = nil
	
	return self
end

-- ██╗███╗   ██╗██╗████████╗
-- ██║████╗  ██║██║╚══██╔══╝
-- ██║██╔██╗ ██║██║   ██║   
-- ██║██║╚██╗██║██║   ██║   
-- ██║██║ ╚████║██║   ██║   
-- ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   
--

function CharacterController:Init()
	-- Set up third-person camera (Roblox default)
	if player.Character then
		self:OnCharacterAdded()
	end
	
	player.CharacterAdded:Connect(function()
		self:OnCharacterAdded()
	end)
	
	-- Handle movement input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A or 
		   input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D then
			self:UpdateMovementInput()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			self.isRunning = true
			self:UpdateMovementInput()
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A or 
		   input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D then
			self:UpdateMovementInput()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			self.isRunning = false
			self:UpdateMovementInput()
		end
	end)
	
	-- Start movement update loop
	self.connection = RunService.Heartbeat:Connect(function()
		self:UpdateMovement()
	end)
end

function CharacterController:OnCharacterAdded()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	-- Set movement properties
	humanoid.WalkSpeed = Settings.Character.MovementSpeed
	humanoid.JumpPower = Settings.Character.JumpPower
	humanoid.UseJumpPower = true
end

-- ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
-- ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
-- ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
-- ██║   ██║██╔══██╗██║  ██║██╔══██║   ██║   ██╔══╝  
-- ╚██████╔╝██║  ██║██████╔╝██║  ██║   ██║   ███████╗
--  ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
--

function CharacterController:UpdateMovementInput()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local camera = Workspace.CurrentCamera
	if not camera then return end
	
	-- Counter-Strike style movement: forward/backward and strafe only
	local moveVector = Vector3.new(0, 0, 0)
	
	-- Get camera's horizontal look and right directions (flattened)
	local cameraLook = camera.CFrame.LookVector
	local cameraRight = camera.CFrame.RightVector
	cameraLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
	cameraRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)
	
	-- Normalize
	if cameraLook.Magnitude > 0.1 then
		cameraLook = cameraLook.Unit
	end
	if cameraRight.Magnitude > 0.1 then
		cameraRight = cameraRight.Unit
	end
	
	-- Forward/backward movement
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveVector = moveVector + cameraLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveVector = moveVector - cameraLook
	end
	
	-- Strafe left/right (no forward component, pure lateral)
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveVector = moveVector - cameraRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveVector = moveVector + cameraRight
	end
	
	-- Normalize to prevent faster diagonal movement
	if moveVector.Magnitude > 0 then
		moveVector = moveVector.Unit
	end
	
	self.moveVector = moveVector
end

function CharacterController:UpdateMovement()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local camera = Workspace.CurrentCamera
	if not camera then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end
	
	-- Update movement input
	self:UpdateMovementInput()
	
	-- Set walk speed based on running
	if self.isRunning then
		humanoid.WalkSpeed = Settings.Character.RunSpeed
	else
		humanoid.WalkSpeed = Settings.Character.MovementSpeed
	end
	
	-- Counter-Strike style: Character always faces camera direction (locked rotation)
	-- Get camera look direction (flattened for ground movement)
	local cameraLook = camera.CFrame.LookVector
	cameraLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
	if cameraLook.Magnitude > 0.1 then
		cameraLook = cameraLook.Unit
		
		-- Lock character rotation to camera direction (no smooth lerp, instant)
		local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + cameraLook)
		rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + cameraLook)
	end
	
	-- Move character (forward/backward and strafe relative to camera)
	if self.moveVector.Magnitude > 0 then
		humanoid:Move(self.moveVector)
	else
		humanoid:Move(Vector3.new(0, 0, 0))
	end
end

-- Return
return CharacterController

