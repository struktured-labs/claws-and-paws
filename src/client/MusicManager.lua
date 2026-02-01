--[[
    Claws & Paws - Music Manager
    Handles background music and ambience
    Supports different moods: playful for easy games, epic for bosses
]]

local MusicManager = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared")).Constants

-- Music tracks organized by mood
-- Using Roblox audio library IDs (royalty-free)
local MUSIC_TRACKS = {
    -- Menu: calm, inviting
    MENU = "rbxassetid://1843463175",

    -- Playful: lighthearted, fun (for easy/casual games)
    GAMEPLAY_PLAYFUL = "rbxassetid://1837849285",

    -- Intense: more serious, focused (for medium/hard games)
    GAMEPLAY_INTENSE = "rbxassetid://1842458016",

    -- Boss: epic, dramatic (reserved for campaign bosses)
    BOSS = "rbxassetid://1846902823",

    -- Victory: triumphant fanfare (uses BOSS track - dramatic/epic)
    VICTORY = "rbxassetid://1846902823",

    -- Defeat: somber (uses INTENSE track - serious/reflective)
    DEFEAT = "rbxassetid://1842458016",
}

-- Map game modes to music tracks
local MODE_MUSIC = {
    AI_Easy = "GAMEPLAY_PLAYFUL",
    AI_Medium = "GAMEPLAY_INTENSE",
    AI_Hard = "GAMEPLAY_INTENSE",
    Casual = "GAMEPLAY_PLAYFUL",
    Ranked = "GAMEPLAY_INTENSE",
}

local currentTrack = nil
local currentTrackType = nil
local baseVolume = 0.3  -- Base music volume (before settings multiplier)
local fadeDuration = 1.0  -- Seconds to fade between tracks

-- Get the effective volume based on settings
local function getEffectiveVolume()
    local ok, SettingsManager = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Shared = require(ReplicatedStorage.Shared)
        -- SettingsManager is client-only, access via script
        return nil
    end)

    -- Try to get settings from the client module
    local masterVol = 0.7
    local musicVol = 0.5

    local success, result = pcall(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        -- Use attribute-based approach for cross-module communication
        if LocalPlayer:GetAttribute("masterVolume") then
            return {
                master = LocalPlayer:GetAttribute("masterVolume"),
                music = LocalPlayer:GetAttribute("musicVolume"),
            }
        end
        return nil
    end)

    if success and result then
        masterVol = result.master or 0.7
        musicVol = result.music or 0.5
    end

    return baseVolume * masterVol * musicVol
end

-- Fade out current track
local function fadeOut(sound, duration, onComplete)
    if not sound or not sound.Parent then
        if onComplete then onComplete() end
        return
    end

    local tweenInfo = TweenInfo.new(duration or fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(sound, tweenInfo, {Volume = 0})

    tween.Completed:Connect(function()
        sound:Stop()
        sound:Destroy()
        if onComplete then onComplete() end
    end)

    tween:Play()
end

-- Fade in a sound
local function fadeIn(sound, targetVolume, duration)
    sound.Volume = 0
    sound:Play()

    local tweenInfo = TweenInfo.new(duration or fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local tween = TweenService:Create(sound, tweenInfo, {Volume = targetVolume})
    tween:Play()
end

-- Track types that should not loop (one-shot)
local ONE_SHOT_TRACKS = { VICTORY = true, DEFEAT = true }

-- Play a music track with crossfade
function MusicManager.playMusic(trackType)
    -- Don't restart the same track (unless it's a one-shot, which may need replaying)
    if currentTrackType == trackType and currentTrack and currentTrack.Parent and not ONE_SHOT_TRACKS[trackType] then
        return currentTrack
    end

    local soundId = MUSIC_TRACKS[trackType]
    if not soundId then
        if Constants.DEBUG then warn("🐱 [MUSIC] Unknown track type: " .. tostring(trackType)) end
        soundId = MUSIC_TRACKS.MENU
    end

    local targetVolume = getEffectiveVolume()
    if Constants.DEBUG then print("🐱 [MUSIC] Playing track: " .. tostring(trackType) .. " (volume: " .. string.format("%.2f", targetVolume) .. ")") end

    -- Create new sound first
    local newSound = Instance.new("Sound")
    newSound.Name = "BackgroundMusic_" .. (trackType or "unknown")
    newSound.SoundId = soundId
    newSound.Looped = not ONE_SHOT_TRACKS[trackType]
    newSound.Parent = workspace

    -- Crossfade: fade out old, fade in new
    if currentTrack and currentTrack.Parent then
        local oldTrack = currentTrack
        currentTrack = newSound
        currentTrackType = trackType

        -- Start fading out old track
        fadeOut(oldTrack, fadeDuration)
        -- Start fading in new track
        fadeIn(newSound, targetVolume, fadeDuration)
    else
        -- No current track, just fade in
        currentTrack = newSound
        currentTrackType = trackType
        fadeIn(newSound, targetVolume, fadeDuration)
    end

    return newSound
end

-- Play music for a specific game mode
function MusicManager.playForGameMode(gameMode)
    local trackType = MODE_MUSIC[gameMode] or "GAMEPLAY_PLAYFUL"
    if Constants.DEBUG then print("🐱 [MUSIC] Game mode: " .. tostring(gameMode) .. " → track: " .. trackType) end
    return MusicManager.playMusic(trackType)
end

-- Play boss music (epic!)
function MusicManager.playBossMusic()
    if Constants.DEBUG then print("🐱 [MUSIC] Playing BOSS music!") end
    return MusicManager.playMusic("BOSS")
end

-- Play menu music
function MusicManager.playMenuMusic()
    return MusicManager.playMusic("MENU")
end

-- Play victory music
function MusicManager.playVictoryMusic()
    return MusicManager.playMusic("VICTORY")
end

-- Play defeat music
function MusicManager.playDefeatMusic()
    return MusicManager.playMusic("DEFEAT")
end

-- Stop music with fade out
function MusicManager.stopMusic()
    if currentTrack and currentTrack.Parent then
        fadeOut(currentTrack, fadeDuration)
        currentTrack = nil
        currentTrackType = nil
    end
end

-- Set volume (applies immediately)
function MusicManager.setVolume(volume)
    baseVolume = math.clamp(volume, 0, 1)
    if currentTrack and currentTrack.Parent then
        currentTrack.Volume = getEffectiveVolume()
    end
end

-- Update volume from settings (called when settings change)
function MusicManager.updateVolumeFromSettings(masterVol, musicVol)
    if currentTrack and currentTrack.Parent then
        currentTrack.Volume = baseVolume * (masterVol or 0.7) * (musicVol or 0.5)
    end
end

-- Get current track type
function MusicManager.getCurrentTrack()
    return currentTrackType
end

-- Play menu music on start
task.spawn(function()
    task.wait(1)
    MusicManager.playMusic("MENU")
end)

return MusicManager
