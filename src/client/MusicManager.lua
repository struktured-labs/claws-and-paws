--[[
    Claws & Paws - Music Manager
    Handles background music and ambience
]]

local MusicManager = {}

-- Music tracks (replace these IDs with cat-themed music)
local MUSIC_TRACKS = {
    MENU = "rbxassetid://1843463175", -- Calm/menu music (placeholder)
    GAMEPLAY = "rbxassetid://1842458016", -- Upbeat gameplay music (placeholder)
}

local currentTrack = nil

-- Create and play a music track
function MusicManager.playMusic(trackType)
    -- Stop current track if playing
    if currentTrack then
        currentTrack:Stop()
        currentTrack:Destroy()
    end

    -- Create new sound
    local sound = Instance.new("Sound")
    sound.Name = "BackgroundMusic"
    sound.SoundId = MUSIC_TRACKS[trackType] or MUSIC_TRACKS.MENU
    sound.Volume = 0.3 -- Adjust volume (0-1)
    sound.Looped = true
    sound.Parent = workspace

    -- Play it
    sound:Play()
    currentTrack = sound

    return sound
end

-- Stop music
function MusicManager.stopMusic()
    if currentTrack then
        currentTrack:Stop()
        currentTrack:Destroy()
        currentTrack = nil
    end
end

-- Set volume
function MusicManager.setVolume(volume)
    if currentTrack then
        currentTrack.Volume = math.clamp(volume, 0, 1)
    end
end

-- Play menu music on start
task.spawn(function()
    wait(1) -- Wait for game to load
    MusicManager.playMusic("MENU")
end)

return MusicManager
