--[[
    Claws & Paws - Player Data Persistence
    Saves and loads player settings and campaign progress via DataStoreService
    Data is stored as player attributes for cross-module access
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = require(ReplicatedStorage.Shared)
local Constants = Shared.Constants

local PlayerDataStore = {}

-- DataStore references (wrapped in pcall for unpublished places)
local settingsStore, progressStore
do
    local ok1, store1 = pcall(function() return DataStoreService:GetDataStore("PlayerSettings_v1") end)
    local ok2, store2 = pcall(function() return DataStoreService:GetDataStore("CampaignProgress_v1") end)
    settingsStore = ok1 and store1 or nil
    progressStore = ok2 and store2 or nil
    if not settingsStore then
        warn("PlayerDataStore: DataStore unavailable (place may not be published). Settings won't persist.")
    end
end

-- Track pending saves per player to debounce
local pendingSaves = {}

-- Keys we persist for settings
local SETTINGS_KEYS = {
    "masterVolume",
    "musicVolume",
    "sfxVolume",
    "colorTheme",
    "showCoordinates",
    "showValidMoves",
    "showPieceLabels",
}

-- Default values
local SETTINGS_DEFAULTS = {
    masterVolume = 0.7,
    musicVolume = 0.5,
    sfxVolume = 0.8,
    colorTheme = "Forest Floor",
    showCoordinates = true,
    showValidMoves = true,
    showPieceLabels = true,
}

-- Load player data from DataStore and apply as attributes
function PlayerDataStore.loadPlayerData(player)
    local userId = tostring(player.UserId)

    -- Load settings
    local settingsSuccess, settingsData = pcall(function()
        return settingsStore:GetAsync(userId)
    end)

    if settingsSuccess and settingsData then
        for _, key in ipairs(SETTINGS_KEYS) do
            local value = settingsData[key]
            if value ~= nil then
                player:SetAttribute(key, value)
            else
                player:SetAttribute(key, SETTINGS_DEFAULTS[key])
            end
        end
    else
        -- Apply defaults
        for key, default in pairs(SETTINGS_DEFAULTS) do
            player:SetAttribute(key, default)
        end
    end

    -- Load campaign progress
    local progressSuccess, progressData = pcall(function()
        return progressStore:GetAsync(userId)
    end)

    if progressSuccess and progressData then
        for bossId, defeated in pairs(progressData) do
            if defeated then
                player:SetAttribute("boss_" .. bossId, true)
            end
        end
    end

    -- Load tutorial state
    local tutorialKey = "tutorial_" .. userId
    local tutSuccess, tutSeen = pcall(function()
        return settingsStore:GetAsync(tutorialKey)
    end)
    if tutSuccess and tutSeen then
        player:SetAttribute("hasSeenTutorial", true)
    end
end

-- Save player settings to DataStore
function PlayerDataStore.saveSettings(player)
    local userId = tostring(player.UserId)
    local data = {}

    for _, key in ipairs(SETTINGS_KEYS) do
        local value = player:GetAttribute(key)
        if value ~= nil then
            data[key] = value
        end
    end

    local success, err = pcall(function()
        settingsStore:SetAsync(userId, data)
    end)

    if not success then
        warn("Failed to save settings for " .. player.Name .. ": " .. tostring(err))
    end
end

-- Save campaign progress to DataStore
function PlayerDataStore.saveCampaignProgress(player)
    local userId = tostring(player.UserId)
    local data = {}

    -- Collect all boss_* attributes
    local CampaignData = Shared.CampaignData
    for _, boss in ipairs(CampaignData.BOSSES) do
        if player:GetAttribute("boss_" .. boss.id) then
            data[boss.id] = true
        end
    end

    local success, err = pcall(function()
        progressStore:SetAsync(userId, data)
    end)

    if not success then
        warn("Failed to save campaign progress for " .. player.Name .. ": " .. tostring(err))
    end
end

-- Save tutorial state
function PlayerDataStore.saveTutorialState(player)
    local userId = tostring(player.UserId)
    if player:GetAttribute("hasSeenTutorial") then
        pcall(function()
            settingsStore:SetAsync("tutorial_" .. userId, true)
        end)
    end
end

-- Debounced save (waits 3 seconds after last change before saving)
function PlayerDataStore.scheduleSave(player, saveType)
    local key = player.UserId .. "_" .. saveType
    if pendingSaves[key] then return end -- Already scheduled

    pendingSaves[key] = true
    task.delay(3, function()
        pendingSaves[key] = nil
        if not player or not player.Parent then return end -- Player left

        if saveType == "settings" then
            PlayerDataStore.saveSettings(player)
        elseif saveType == "campaign" then
            PlayerDataStore.saveCampaignProgress(player)
        elseif saveType == "tutorial" then
            PlayerDataStore.saveTutorialState(player)
        end
    end)
end

-- Watch for attribute changes and auto-save
function PlayerDataStore.watchAttributes(player)
    player.AttributeChanged:Connect(function(attributeName)
        -- Settings attributes
        for _, key in ipairs(SETTINGS_KEYS) do
            if attributeName == key then
                PlayerDataStore.scheduleSave(player, "settings")
                return
            end
        end

        -- Campaign boss attributes
        if attributeName:sub(1, 5) == "boss_" then
            PlayerDataStore.scheduleSave(player, "campaign")
            return
        end

        -- Tutorial state
        if attributeName == "hasSeenTutorial" then
            PlayerDataStore.scheduleSave(player, "tutorial")
            return
        end
    end)
end

-- Save all data for a player (called on leave)
function PlayerDataStore.saveAllData(player)
    PlayerDataStore.saveSettings(player)
    PlayerDataStore.saveCampaignProgress(player)
    PlayerDataStore.saveTutorialState(player)
end

-- Initialize: set up player join/leave hooks
function PlayerDataStore.init()
    Players.PlayerAdded:Connect(function(player)
        PlayerDataStore.loadPlayerData(player)
        PlayerDataStore.watchAttributes(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        PlayerDataStore.saveAllData(player)
    end)

    -- Handle players already in game (Studio testing)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            PlayerDataStore.loadPlayerData(player)
            PlayerDataStore.watchAttributes(player)
        end)
    end

    -- Save all on server shutdown
    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            PlayerDataStore.saveAllData(player)
        end
    end)
end

return PlayerDataStore
