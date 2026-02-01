--[[
    Claws & Paws - Sound Effects Manager
    Meows, purrs, hisses, and other cat sounds
]]

local SoundManager = {}

-- Cat sound effects - curated from Roblox audio library
local SOUNDS = {
    -- Movement sounds
    MEOW_HAPPY = "rbxassetid://138078642",       -- Kitty Meow (verified, 2k+ favs)
    MEOW_CURIOUS = "rbxassetid://6378165274",    -- Meow Sound Effect (different variant)
    PURR = "rbxassetid://5901308988",            -- Looped Purr (verified)

    -- Combat sounds
    HISS = "rbxassetid://7128655475",            -- Cat Hiss (fallback: 4559380742)
    GROWL = "rbxassetid://516484997",            -- Cat Growl
    POUNCE = "rbxassetid://8319607685",          -- Battle Cats Attack Sound

    -- UI sounds
    CLICK_SOFT = "rbxassetid://9083627113",      -- Button Click Sound (fallback: 5852470908)
    WHOOSH = "rbxassetid://12222200",            -- swoosh.wav (Roblox built-in)

    -- Special events
    TRIUMPH = "rbxassetid://12222253",           -- victory.wav (Roblox built-in, verified)
    DEFEAT = "rbxassetid://190705984",           -- Sad Trombone
}

local soundCache = {}

-- Cache LocalPlayer reference to avoid repeated lookups
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Get effective volume for SFX (baseVol * masterVolume * sfxVolume)
local function getEffectiveVolume(baseVol)
    local masterVol = 0.7
    local sfxVol = 0.5

    if LocalPlayer then
        masterVol = LocalPlayer:GetAttribute("masterVolume") or 0.7
        sfxVol = LocalPlayer:GetAttribute("sfxVolume") or 0.5
    end

    return baseVol * masterVol * sfxVol
end

-- Create or get cached sound
local function getSound(soundId, parent)
    if soundCache[soundId] then
        return soundCache[soundId]
    end

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Parent = parent or workspace
    soundCache[soundId] = sound
    return sound
end

-- Play a cached sound with explicit volume and pitch (prevents pitch corruption)
local function playSound(soundId, volume, pitch)
    local sound = getSound(soundId)
    sound.Volume = getEffectiveVolume(volume)
    sound.PlaybackSpeed = pitch or 1.0
    sound:Play()
end

-- Play piece move sound (different per piece type)
function SoundManager.playMoveSound(pieceType)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = require(ReplicatedStorage.Shared)
    local Constants = Shared.Constants

    local soundId = SOUNDS.MEOW_CURIOUS
    local volume = 0.4
    local pitch = 1.0

    if pieceType == Constants.PieceType.KING then
        soundId = SOUNDS.MEOW_HAPPY
        volume = 0.6
        pitch = 0.8
    elseif pieceType == Constants.PieceType.QUEEN then
        soundId = SOUNDS.PURR
        volume = 0.5
        pitch = 1.2
    elseif pieceType == Constants.PieceType.ROOK then
        soundId = SOUNDS.GROWL
        volume = 0.5
        pitch = 0.7
    elseif pieceType == Constants.PieceType.BISHOP then
        soundId = SOUNDS.MEOW_CURIOUS
        volume = 0.4
        pitch = 1.3
    elseif pieceType == Constants.PieceType.KNIGHT then
        soundId = SOUNDS.POUNCE
        volume = 0.5
        pitch = 1.1
    elseif pieceType == Constants.PieceType.PAWN then
        soundId = SOUNDS.CLICK_SOFT
        volume = 0.3
        pitch = 1.4
    end

    playSound(soundId, volume, pitch)
end

-- Play capture sound (hiss + pounce combo)
function SoundManager.playCaptureSound()
    task.spawn(function()
        playSound(SOUNDS.HISS, 0.5, 1.0)
        task.wait(0.2)
        playSound(SOUNDS.POUNCE, 0.6, 1.0)
    end)
end

-- Play selection sound
function SoundManager.playSelectSound()
    playSound(SOUNDS.CLICK_SOFT, 0.3, 1.0)
end

-- Play dismissive sound (can't move this piece / illegal move)
function SoundManager.playDismissiveSound()
    playSound(SOUNDS.MEOW_CURIOUS, 0.4, 0.7)
end

-- Play check/threat sound
function SoundManager.playCheckSound()
    playSound(SOUNDS.GROWL, 0.5, 1.0)
end

-- Play victory sound
function SoundManager.playVictorySound()
    playSound(SOUNDS.TRIUMPH, 0.7, 1.0)
end

-- Play defeat sound
function SoundManager.playDefeatSound()
    playSound(SOUNDS.DEFEAT, 0.6, 1.0)
end

-- Random happy meow (ambient)
function SoundManager.playHappyMeow()
    playSound(SOUNDS.MEOW_HAPPY, 0.3, 1.0)
end

-- Purr when hovering over piece (dedicated instance, not cached)
function SoundManager.startPurr()
    local sound = Instance.new("Sound")
    sound.SoundId = SOUNDS.PURR
    sound.Volume = getEffectiveVolume(0.2)
    sound.Looped = true
    sound.Parent = workspace
    sound:Play()
    return sound
end

function SoundManager.stopPurr(sound)
    if sound then
        sound:Stop()
        sound:Destroy()
    end
end

-- Play draw/stalemate sound (neutral outcome)
function SoundManager.playDrawSound()
    playSound(SOUNDS.MEOW_CURIOUS, 0.5, 0.9)
end

-- Play pawn promotion celebration
function SoundManager.playPromotionSound()
    task.spawn(function()
        playSound(SOUNDS.TRIUMPH, 0.5, 1.3)
        task.wait(0.3)
        playSound(SOUNDS.MEOW_HAPPY, 0.4, 1.2)
    end)
end

-- Play low-time warning tick (clock running low)
function SoundManager.playLowTimeWarning()
    playSound(SOUNDS.CLICK_SOFT, 0.6, 2.0)
end

return SoundManager
