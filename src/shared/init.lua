--[[
    Claws & Paws - Shared Module Index
]]

local Shared = {}

print("🐱 [SHARED] Loading Constants...")
Shared.Constants = require(script.Constants)
print("🐱 [SHARED] Constants loaded!")

print("🐱 [SHARED] Loading ChessEngine...")
Shared.ChessEngine = require(script.ChessEngine)
print("🐱 [SHARED] ChessEngine loaded!")

print("🐱 [SHARED] Loading ChessAI...")
local success, result = pcall(function()
    return require(script.ChessAI)
end)
if success then
    Shared.ChessAI = result
    print("🐱 [SHARED] ChessAI loaded!")
else
    warn("🐱 [SHARED] ChessAI FAILED to load:", result)
    Shared.ChessAI = nil
end

print("🐱 [SHARED] Loading CampaignData...")
Shared.CampaignData = require(script.CampaignData)
print("🐱 [SHARED] CampaignData loaded!")

return Shared
