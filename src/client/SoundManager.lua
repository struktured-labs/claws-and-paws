--[[
    Claws & Paws - Sound Effects Manager
    Meows, purrs, hisses, and other cat sounds
]]

local SoundManager = {}

-- Cat sound effects - curated from Roblox audio library
-- Fallback IDs (original placeholders) in comments if replacements fail
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

-- Play piece move sound (different per piece type)
function SoundManager.playMoveSound(pieceType)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = require(ReplicatedStorage.Shared)
    local Constants = Shared.Constants

    local soundId = SOUNDS.MEOW_CURIOUS -- Default
    local volume = 0.4
    local pitch = 1.0

    -- Different sounds/pitches per piece type
    if pieceType == Constants.PieceType.KING then
        soundId = SOUNDS.MEOW_HAPPY -- Deep, regal meow
        volume = 0.6
        pitch = 0.8 -- Lower pitch
    elseif pieceType == Constants.PieceType.QUEEN then
        soundId = SOUNDS.PURR -- Elegant purr
        volume = 0.5
        pitch = 1.2 -- Higher pitch
    elseif pieceType == Constants.PieceType.ROOK then
        soundId = SOUNDS.GROWL -- Heavy, rumbling
        volume = 0.5
        pitch = 0.7 -- Very low
    elseif pieceType == Constants.PieceType.BISHOP then
        soundId = SOUNDS.MEOW_CURIOUS -- Mystical meow
        volume = 0.4
        pitch = 1.3 -- Higher, ethereal
    elseif pieceType == Constants.PieceType.KNIGHT then
        soundId = SOUNDS.POUNCE -- Quick, aggressive
        volume = 0.5
        pitch = 1.1
    elseif pieceType == Constants.PieceType.PAWN then
        soundId = SOUNDS.CLICK_SOFT -- Soft, cute
        volume = 0.3
        pitch = 1.4 -- High pitched (kitten)
    end

    local sound = getSound(soundId)
    sound.Volume = getEffectiveVolume(volume)
    sound.PlaybackSpeed = pitch
    sound:Play()
end

-- Play capture sound (hiss + pounce combo)
function SoundManager.playCaptureSound()
    task.spawn(function()
        local hiss = getSound(SOUNDS.HISS)
        hiss.Volume = getEffectiveVolume(0.5)
        hiss:Play()

        task.wait(0.2)

        local pounce = getSound(SOUNDS.POUNCE)
        pounce.Volume = getEffectiveVolume(0.6)
        pounce:Play()
    end)
end

-- Play selection sound
function SoundManager.playSelectSound()
    local sound = getSound(SOUNDS.CLICK_SOFT)
    sound.Volume = getEffectiveVolume(0.3)
    sound:Play()
end

-- Play dismissive sound (can't move this piece / illegal move)
function SoundManager.playDismissiveSound()
    local sound = getSound(SOUNDS.MEOW_CURIOUS)
    sound.Volume = getEffectiveVolume(0.4)
    sound.PlaybackSpeed = 0.7  -- Lower pitch = annoyed "meh" sound
    sound:Play()
end

-- Play check/threat sound
function SoundManager.playCheckSound()
    local sound = getSound(SOUNDS.GROWL)
    sound.Volume = getEffectiveVolume(0.5)
    sound:Play()
end

-- Play victory sound
function SoundManager.playVictorySound(winner)
    local sound = getSound(SOUNDS.TRIUMPH)
    sound.Volume = getEffectiveVolume(0.7)
    sound:Play()
end

-- Play defeat sound
function SoundManager.playDefeatSound()
    local sound = getSound(SOUNDS.DEFEAT)
    sound.Volume = getEffectiveVolume(0.6)
    sound:Play()
end

-- Random happy meow (ambient)
function SoundManager.playHappyMeow()
    local sound = getSound(SOUNDS.MEOW_HAPPY)
    sound.Volume = getEffectiveVolume(0.3)
    sound:Play()
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

return SoundManager
