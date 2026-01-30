--[[
    Claws & Paws - Sound Effects Manager
    Meows, purrs, hisses, and other cat sounds
]]

local SoundManager = {}

-- Cat sound effects (replace with actual cat sounds)
local SOUNDS = {
    -- Movement sounds
    MEOW_HAPPY = "rbxassetid://6682237952",      -- Happy meow
    MEOW_CURIOUS = "rbxassetid://6682238053",    -- Curious meow
    PURR = "rbxassetid://6682238156",            -- Purring

    -- Combat sounds
    HISS = "rbxassetid://6682238244",            -- Hiss (capture)
    GROWL = "rbxassetid://6682238344",           -- Growl (threatened)
    POUNCE = "rbxassetid://6682238448",          -- Pounce (attack)

    -- UI sounds
    CLICK_SOFT = "rbxassetid://6682238556",      -- Soft click
    WHOOSH = "rbxassetid://6682238655",          -- Whoosh (piece move)

    -- Special events
    TRIUMPH = "rbxassetid://6682238752",         -- Victory meow
    DEFEAT = "rbxassetid://6682238855",          -- Sad meow
}

local soundCache = {}

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
    sound.Volume = volume
    sound.PlaybackSpeed = pitch
    sound:Play()
end

-- Play capture sound (hiss + pounce combo)
function SoundManager.playCaptureSound()
    task.spawn(function()
        local hiss = getSound(SOUNDS.HISS)
        hiss.Volume = 0.5
        hiss:Play()

        task.wait(0.2)

        local pounce = getSound(SOUNDS.POUNCE)
        pounce.Volume = 0.6
        pounce:Play()
    end)
end

-- Play selection sound
function SoundManager.playSelectSound()
    local sound = getSound(SOUNDS.CLICK_SOFT)
    sound.Volume = 0.3
    sound:Play()
end

-- Play dismissive sound (can't move this piece / illegal move)
function SoundManager.playDismissiveSound()
    local sound = getSound(SOUNDS.MEOW_CURIOUS)
    sound.Volume = 0.4
    sound.PlaybackSpeed = 0.7  -- Lower pitch = annoyed "meh" sound
    sound:Play()
end

-- Play check/threat sound
function SoundManager.playCheckSound()
    local sound = getSound(SOUNDS.GROWL)
    sound.Volume = 0.5
    sound:Play()
end

-- Play victory sound
function SoundManager.playVictorySound(winner)
    local sound = getSound(SOUNDS.TRIUMPH)
    sound.Volume = 0.7
    sound:Play()
end

-- Play defeat sound
function SoundManager.playDefeatSound()
    local sound = getSound(SOUNDS.DEFEAT)
    sound.Volume = 0.6
    sound:Play()
end

-- Random happy meow (ambient)
function SoundManager.playHappyMeow()
    local sound = getSound(SOUNDS.MEOW_HAPPY)
    sound.Volume = 0.3
    sound:Play()
end

-- Purr when hovering over piece
function SoundManager.startPurr(piece)
    local sound = getSound(SOUNDS.PURR, piece)
    sound.Volume = 0.2
    sound.Looped = true
    sound:Play()
    return sound
end

function SoundManager.stopPurr(sound)
    if sound then
        sound:Stop()
    end
end

return SoundManager
