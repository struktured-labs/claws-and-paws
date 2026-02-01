--[[
    Claws & Paws - Shared Module Index
]]

local Shared = {}

-- Constants must load first (other modules depend on it)
Shared.Constants = require(script.Constants)
local Constants = Shared.Constants

if Constants.DEBUG then print("🐱 [SHARED] Constants loaded!") end

if Constants.DEBUG then print("🐱 [SHARED] Loading ChessEngine...") end
Shared.ChessEngine = require(script.ChessEngine)
if Constants.DEBUG then print("🐱 [SHARED] ChessEngine loaded!") end

if Constants.DEBUG then print("🐱 [SHARED] Loading ChessAI...") end
local success, result = pcall(function()
    return require(script.ChessAI)
end)
if success then
    Shared.ChessAI = result
    if Constants.DEBUG then print("🐱 [SHARED] ChessAI loaded!") end
else
    if Constants.DEBUG then warn("🐱 [SHARED] ChessAI FAILED to load:", result) end
    Shared.ChessAI = nil
end

if Constants.DEBUG then print("🐱 [SHARED] Loading CampaignData...") end
Shared.CampaignData = require(script.CampaignData)
if Constants.DEBUG then print("🐱 [SHARED] CampaignData loaded!") end

return Shared
