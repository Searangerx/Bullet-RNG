--!strict

print("init.server.luau: Starting")

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- Singletons
local _EventManager  = require(ReplicatedStorage.Shared.Modules.EventManager)
local _PlayerManager = require(ServerStorage.Modules.PlayerManager)
local _EnemyManager  = require(ServerStorage.Modules.EnemyManager)
local _WeaponHandler = require(ServerStorage.Modules.WeaponHandler)

-- Init
_EventManager:Init()
_PlayerManager:Init()
_EnemyManager:Init()
_WeaponHandler:Init()

-- Start enemy system
_EnemyManager:Start()

-- Return
print("init.server.luau: Complete")
