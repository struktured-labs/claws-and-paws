--[[
    Log Collector - Receives client logs and writes to file for debugging
]]

local LogCollector = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Store logs in memory (last 1000 entries)
local logBuffer = {}
local MAX_LOGS = 1000

-- Create remote for client logging
local function setupRemote()
    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not Remotes then
        Remotes = Instance.new("Folder")
        Remotes.Name = "Remotes"
        Remotes.Parent = ReplicatedStorage
    end

    local logEvent = Remotes:FindFirstChild("ClientLog")
    if not logEvent then
        logEvent = Instance.new("RemoteEvent")
        logEvent.Name = "ClientLog"
        logEvent.Parent = Remotes
    end

    return logEvent
end

function LogCollector.init()
    local logEvent = setupRemote()

    logEvent.OnServerEvent:Connect(function(player, logLevel, message, data)
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local logEntry = {
            timestamp = timestamp,
            player = player.Name,
            level = logLevel,
            message = message,
            data = data
        }

        -- Add to buffer
        table.insert(logBuffer, logEntry)
        if #logBuffer > MAX_LOGS then
            table.remove(logBuffer, 1)
        end

        -- Print to Studio console (visible in Output)
        local prefix = ""
        if logLevel == "ERROR" then
            prefix = "❌ [ERROR]"
        elseif logLevel == "WARN" then
            prefix = "⚠️  [WARN]"
        elseif logLevel == "INFO" then
            prefix = "ℹ️  [INFO]"
        elseif logLevel == "DEBUG" then
            prefix = "🔍 [DEBUG]"
        end

        print(string.format("%s [%s] %s: %s",
            prefix, timestamp, player.Name, message))

        if data then
            print("  Data:", HttpService:JSONEncode(data))
        end
    end)

    print("📋 Log Collector initialized - client logs will appear here")
end

-- Get recent logs as JSON (for HTTP endpoint if needed)
function LogCollector.getLogs(count)
    count = count or 100
    local start = math.max(1, #logBuffer - count + 1)
    local logs = {}

    for i = start, #logBuffer do
        table.insert(logs, logBuffer[i])
    end

    return logs
end

return LogCollector
