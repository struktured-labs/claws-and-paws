--[[
    Client Logger - Sends logs to server for debugging
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = {}

local logEvent = nil

-- Initialize logger
function Logger.init()
    print("🐱 [DEBUG] Logger.init() starting...")
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    print("🐱 [DEBUG] Logger: Got Remotes:", Remotes)
    if Remotes then
        print("🐱 [DEBUG] Logger: Waiting for ClientLog...")
        logEvent = Remotes:WaitForChild("ClientLog", 5)
        print("🐱 [DEBUG] Logger: Got ClientLog:", logEvent)
    end
    print("🐱 [DEBUG] Logger.init() complete!")
end

-- Send log to server
local function sendLog(level, message, data)
    -- Always print locally
    print(string.format("[%s] %s", level, message))
    if data then
        print("  Data:", data)
    end

    -- Send to server if available
    if logEvent then
        pcall(function()
            logEvent:FireServer(level, message, data)
        end)
    end
end

-- Log levels
function Logger.error(message, data)
    sendLog("ERROR", message, data)
end

function Logger.warn(message, data)
    sendLog("WARN", message, data)
end

function Logger.info(message, data)
    sendLog("INFO", message, data)
end

function Logger.debug(message, data)
    sendLog("DEBUG", message, data)
end

-- Wrap errors in pcall and log them
function Logger.try(func, context)
    local success, err = pcall(func)
    if not success then
        Logger.error(string.format("Error in %s: %s", context or "unknown", tostring(err)))
    end
    return success, err
end

return Logger
