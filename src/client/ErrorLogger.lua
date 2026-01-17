--[[
    Error Logger - Sends Studio errors to server for debugging
]]

local ErrorLogger = {}

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes
task.spawn(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not Remotes then return end

    local LogErrorEvent = Remotes:FindFirstChild("LogError")
    if not LogErrorEvent then
        LogErrorEvent = Instance.new("RemoteEvent")
        LogErrorEvent.Name = "LogError"
        LogErrorEvent.Parent = Remotes
    end

    -- Capture all errors and send to server
    LogService.MessageOut:Connect(function(message, messageType)
        if messageType == Enum.MessageType.MessageError then
            LogErrorEvent:FireServer(message)
        end
    end)
end)

return ErrorLogger
