--[[
    Claws & Paws - Asset Loader
    Loads 3D cat models with fallback to placeholders
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local Shared = require(ReplicatedStorage.Shared)
local Constants = Shared.Constants

local AssetLoader = {}

-- Cat model asset IDs (replace with real IDs from Roblox Toolbox)
-- To find models: Open Studio → Toolbox → Search "cat model" → Right-click → Copy Asset ID
local CAT_MODEL_IDS = {
    -- Main pieces
    [Constants.PieceType.KING] = nil,      -- Lion model (replace with asset ID)
    [Constants.PieceType.QUEEN] = nil,     -- Persian cat model
    [Constants.PieceType.ROOK] = nil,      -- Maine Coon model
    [Constants.PieceType.BISHOP] = nil,    -- Sphinx cat model
    [Constants.PieceType.KNIGHT] = nil,    -- Caracal model
    [Constants.PieceType.PAWN] = nil,      -- Alley cat/tabby model

    -- Hybrid pieces (future)
    [Constants.PieceType.ARCHBISHOP] = nil, -- Serval model
    [Constants.PieceType.CHANCELLOR] = nil, -- Cheetah model
    [Constants.PieceType.AMAZON] = nil,    -- Jaguar model
}

-- Cache for loaded models (to avoid repeated InsertService calls)
local modelCache = {}

-- Try to load a cat model from asset ID
local function loadModelFromAsset(assetId)
    -- Check cache first
    if modelCache[assetId] then
        return modelCache[assetId]:Clone()
    end

    -- Try to load from InsertService
    local success, result = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)

    if success and result then
        local model = result:GetChildren()[1]
        if model then
            -- Cache the template
            modelCache[assetId] = model
            return model:Clone()
        end
    end

    return nil
end

-- Try to load cat model from ReplicatedStorage (pre-imported)
local function loadModelFromStorage(pieceType)
    local catModels = ReplicatedStorage:FindFirstChild("CatModels")
    if not catModels then
        return nil
    end

    local breedName = Constants.CatBreed[pieceType]
    if not breedName then
        return nil
    end

    local template = catModels:FindFirstChild(breedName)
    if template then
        return template:Clone()
    end

    return nil
end

-- Create placeholder sphere with emoji (current system)
local function createPlaceholder(pieceType, color)
    local piece = Instance.new("Part")
    piece.Shape = Enum.PartType.Ball
    piece.Size = Vector3.new(6, 6, 6) -- Bigger for bigger board (was 3x3x3)
    piece.Anchored = true
    piece.CanCollide = false
    piece.Material = Enum.Material.SmoothPlastic

    -- Cat-themed colors
    if color == Constants.Color.WHITE then
        piece.Color = Color3.fromRGB(255, 240, 220)
        piece.Reflectance = 0.2
    else
        piece.Color = Color3.fromRGB(80, 60, 50)
        piece.Reflectance = 0.15
    end

    -- Add emoji label (bigger for bigger pieces)
    local label = Instance.new("BillboardGui")
    label.Size = UDim2.new(0, 240, 0, 120) -- Double size
    label.StudsOffset = Vector3.new(0, 5, 0) -- Higher offset for bigger pieces
    label.AlwaysOnTop = true
    label.Parent = piece

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Font = Enum.Font.FredokaOne
    textLabel.TextScaled = true
    textLabel.Parent = label

    local symbols = {
        [Constants.PieceType.KING] = "🦁",
        [Constants.PieceType.QUEEN] = "👑🐱",
        [Constants.PieceType.ROOK] = "🏰🐱",
        [Constants.PieceType.BISHOP] = "🔮🐱",
        [Constants.PieceType.KNIGHT] = "⚡🐱",
        [Constants.PieceType.PAWN] = "🐾",
    }
    textLabel.Text = symbols[pieceType] or "🐱"

    return piece
end

-- Prepare a model for use as a chess piece
local function prepareModel(model, color)
    -- Ensure it's a Model or BasePart
    if not (model:IsA("Model") or model:IsA("BasePart")) then
        return nil
    end

    -- Set basic properties
    if model:IsA("Model") then
        model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
    end

    -- Make it anchored and non-colliding
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end

    -- Color-tint for teams (optional, subtle)
    if color == Constants.Color.WHITE then
        -- Slight cream tint for white team
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Color = part.Color:Lerp(Color3.fromRGB(255, 250, 240), 0.3)
            end
        end
    else
        -- Slight brown tint for black team
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Color = part.Color:Lerp(Color3.fromRGB(60, 40, 30), 0.3)
            end
        end
    end

    return model
end

-- Main function: Load cat piece model
function AssetLoader.loadPiece(pieceType, color)
    local model = nil

    -- Strategy 1: Try asset ID (from Toolbox)
    local assetId = CAT_MODEL_IDS[pieceType]
    if assetId then
        model = loadModelFromAsset(assetId)
    end

    -- Strategy 2: Try ReplicatedStorage (pre-imported)
    if not model then
        model = loadModelFromStorage(pieceType)
    end

    -- Strategy 3: Fallback to placeholder
    if not model then
        return createPlaceholder(pieceType, color)
    end

    -- Prepare and return
    return prepareModel(model, color) or createPlaceholder(pieceType, color)
end

-- Check if real models are available (for debugging)
function AssetLoader.hasRealModels()
    for pieceType, assetId in pairs(CAT_MODEL_IDS) do
        if assetId then
            return true
        end
    end

    local catModels = ReplicatedStorage:FindFirstChild("CatModels")
    if catModels and #catModels:GetChildren() > 0 then
        return true
    end

    return false
end

-- Print status (for debugging)
function AssetLoader.printStatus()
    print("🐱 Asset Loader Status:")
    print("  Using real 3D models:", AssetLoader.hasRealModels())

    local assetCount = 0
    for _, assetId in pairs(CAT_MODEL_IDS) do
        if assetId then
            assetCount = assetCount + 1
        end
    end
    print("  Asset IDs configured:", assetCount .. "/9")

    local catModels = ReplicatedStorage:FindFirstChild("CatModels")
    if catModels then
        print("  Pre-imported models:", #catModels:GetChildren())
    else
        print("  Pre-imported models: 0 (no CatModels folder)")
    end
end

return AssetLoader
