--[[
    Claws & Paws - Asset Loader
    Loads 3D cat models with fallback to placeholders
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local Shared = require(ReplicatedStorage.Shared)
local Constants = Shared.Constants

local AssetLoader = {}

-- Configuration: Change piece style here
AssetLoader.pieceStyle = Constants.PieceStyle.CAT_SIMPLE -- Options: CAT_3D, CAT_SIMPLE, CHESS_CLASSIC, CHESS_MINIMAL

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

-- Create placeholder cat model with basic shapes (improved system)
local function createPlaceholder(pieceType, color)
    local model = Instance.new("Model")
    model.Name = "CatPlaceholder"

    -- Main body (slightly elongated sphere)
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Shape = Enum.PartType.Ball
    body.Size = Vector3.new(5, 4.5, 6) -- Slightly elongated for cat shape
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.SmoothPlastic
    body.Position = Vector3.new(0, 0, 0)

    -- Breed-specific colors with variation
    local breedColors = {
        [Constants.PieceType.KING] = {     -- Lion - golden
            white = Color3.fromRGB(255, 220, 150),
            black = Color3.fromRGB(180, 140, 80)
        },
        [Constants.PieceType.QUEEN] = {    -- Persian - fluffy white/dark
            white = Color3.fromRGB(255, 250, 245),
            black = Color3.fromRGB(60, 55, 60)
        },
        [Constants.PieceType.ROOK] = {     -- Maine Coon - brown/gray
            white = Color3.fromRGB(200, 180, 160),
            black = Color3.fromRGB(90, 80, 70)
        },
        [Constants.PieceType.BISHOP] = {   -- Sphinx - pinkish
            white = Color3.fromRGB(255, 220, 210),
            black = Color3.fromRGB(140, 120, 110)
        },
        [Constants.PieceType.KNIGHT] = {   -- Caracal - sandy
            white = Color3.fromRGB(255, 200, 150),
            black = Color3.fromRGB(160, 120, 80)
        },
        [Constants.PieceType.PAWN] = {     -- Alley cat - mixed
            white = Color3.fromRGB(240, 230, 220),
            black = Color3.fromRGB(70, 60, 50)
        },
    }

    local colorSet = breedColors[pieceType] or breedColors[Constants.PieceType.PAWN]
    body.Color = color == Constants.Color.WHITE and colorSet.white or colorSet.black
    body.Reflectance = 0.15
    body.Parent = model

    -- Head (smaller sphere on top)
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(3, 3, 3)
    head.Anchored = true
    head.CanCollide = false
    head.Material = Enum.Material.SmoothPlastic
    head.Color = body.Color
    head.Reflectance = body.Reflectance
    head.Position = Vector3.new(0, 3, 1.5)
    head.Parent = model

    -- Left ear (wedge/pyramid)
    local leftEar = Instance.new("WedgePart")
    leftEar.Name = "LeftEar"
    leftEar.Size = Vector3.new(0.8, 1.5, 0.8)
    leftEar.Anchored = true
    leftEar.CanCollide = false
    leftEar.Material = Enum.Material.SmoothPlastic
    leftEar.Color = body.Color
    leftEar.Position = Vector3.new(-1, 4.2, 1.5)
    leftEar.Orientation = Vector3.new(0, 0, 0)
    leftEar.Parent = model

    -- Right ear
    local rightEar = leftEar:Clone()
    rightEar.Name = "RightEar"
    rightEar.Position = Vector3.new(1, 4.2, 1.5)
    rightEar.Parent = model

    -- Tail (curved cylinder)
    local tail = Instance.new("Part")
    tail.Name = "Tail"
    tail.Shape = Enum.PartType.Cylinder
    tail.Size = Vector3.new(3, 0.6, 0.6)
    tail.Anchored = true
    tail.CanCollide = false
    tail.Material = Enum.Material.SmoothPlastic
    tail.Color = body.Color
    tail.Position = Vector3.new(0, 1, -3.5)
    tail.Orientation = Vector3.new(0, 0, 90) -- Horizontal cylinder
    tail.Parent = model

    -- Nose (tiny pink sphere)
    local nose = Instance.new("Part")
    nose.Name = "Nose"
    nose.Shape = Enum.PartType.Ball
    nose.Size = Vector3.new(0.4, 0.4, 0.4)
    nose.Anchored = true
    nose.CanCollide = false
    nose.Material = Enum.Material.Neon
    nose.Color = Color3.fromRGB(255, 150, 180) -- Pink
    nose.Position = Vector3.new(0, 3, 3)
    nose.Parent = model

    -- Eyes (glowing spheres)
    local leftEye = Instance.new("Part")
    leftEye.Name = "LeftEye"
    leftEye.Shape = Enum.PartType.Ball
    leftEye.Size = Vector3.new(0.6, 0.6, 0.6)
    leftEye.Anchored = true
    leftEye.CanCollide = false
    leftEye.Material = Enum.Material.Neon
    leftEye.Color = color == Constants.Color.WHITE and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 200, 100)
    leftEye.Position = Vector3.new(-0.8, 3.5, 2.5)
    leftEye.Parent = model

    local rightEye = leftEye:Clone()
    rightEye.Name = "RightEye"
    rightEye.Position = Vector3.new(0.8, 3.5, 2.5)
    rightEye.Parent = model

    -- Add emoji label for piece type
    local label = Instance.new("BillboardGui")
    label.Size = UDim2.new(0, 240, 0, 120)
    label.StudsOffset = Vector3.new(0, 6, 0)
    label.AlwaysOnTop = true
    label.Parent = head

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
        [Constants.PieceType.KING] = "👑",
        [Constants.PieceType.QUEEN] = "💎",
        [Constants.PieceType.ROOK] = "🏰",
        [Constants.PieceType.BISHOP] = "🔮",
        [Constants.PieceType.KNIGHT] = "⚡",
        [Constants.PieceType.PAWN] = "🐾",
    }
    textLabel.Text = symbols[pieceType] or "🐱"

    -- Set primary part for positioning
    model.PrimaryPart = body

    return model
end

-- Create traditional chess piece (classic style)
local function createChessPiece(pieceType, color)
    local part = Instance.new("Part")
    part.Name = "ChessPiece"
    part.Size = Vector3.new(4, 6, 4)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Marble

    -- Team colors: white = light gray, black = dark gray
    if color == Constants.Color.WHITE then
        part.Color = Color3.fromRGB(230, 230, 230)
    else
        part.Color = Color3.fromRGB(40, 40, 40)
    end

    -- Add mesh for chess piece shape
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.Scale = Vector3.new(1.5, 1.5, 1.5)

    -- Chess piece mesh IDs (Roblox built-in meshes)
    local chessMeshes = {
        [Constants.PieceType.KING] = "rbxasset://fonts/king.mesh",
        [Constants.PieceType.QUEEN] = "rbxasset://fonts/queen.mesh",
        [Constants.PieceType.ROOK] = "rbxasset://fonts/rook.mesh",
        [Constants.PieceType.BISHOP] = "rbxasset://fonts/bishop.mesh",
        [Constants.PieceType.KNIGHT] = "rbxasset://fonts/knight.mesh",
        [Constants.PieceType.PAWN] = "rbxasset://fonts/pawn.mesh",
    }

    mesh.MeshId = chessMeshes[pieceType] or chessMeshes[Constants.PieceType.PAWN]
    mesh.Parent = part

    -- Add text label with symbol
    local label = Instance.new("BillboardGui")
    label.Size = UDim2.new(0, 200, 0, 100)
    label.StudsOffset = Vector3.new(0, 5, 0)
    label.AlwaysOnTop = true
    label.Parent = part

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = color == Constants.Color.WHITE and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
    textLabel.TextStrokeTransparency = 0.5
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 48
    textLabel.Parent = label

    -- Chess symbols
    local symbols = {
        [Constants.PieceType.KING] = "♔",
        [Constants.PieceType.QUEEN] = "♕",
        [Constants.PieceType.ROOK] = "♖",
        [Constants.PieceType.BISHOP] = "♗",
        [Constants.PieceType.KNIGHT] = "♘",
        [Constants.PieceType.PAWN] = "♙",
    }
    textLabel.Text = symbols[pieceType] or "♟"

    return part
end

-- Create minimal chess piece (simple geometric)
local function createMinimalPiece(pieceType, color)
    local part = Instance.new("Part")
    part.Name = "MinimalPiece"
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon

    -- Team colors: vibrant
    if color == Constants.Color.WHITE then
        part.Color = Color3.fromRGB(255, 255, 255)
    else
        part.Color = Color3.fromRGB(50, 50, 50)
    end

    -- Different shapes per piece type
    local shapes = {
        [Constants.PieceType.KING] = {shape = Enum.PartType.Ball, size = Vector3.new(5, 7, 5)},
        [Constants.PieceType.QUEEN] = {shape = Enum.PartType.Ball, size = Vector3.new(4.5, 6, 4.5)},
        [Constants.PieceType.ROOK] = {shape = Enum.PartType.Block, size = Vector3.new(4, 5, 4)},
        [Constants.PieceType.BISHOP] = {shape = Enum.PartType.Ball, size = Vector3.new(4, 5, 4)},
        [Constants.PieceType.KNIGHT] = {shape = Enum.PartType.Block, size = Vector3.new(4, 5, 3)},
        [Constants.PieceType.PAWN] = {shape = Enum.PartType.Ball, size = Vector3.new(3, 4, 3)},
    }

    local shapeData = shapes[pieceType] or shapes[Constants.PieceType.PAWN]
    part.Shape = shapeData.shape
    part.Size = shapeData.size

    -- Add simple icon
    local label = Instance.new("BillboardGui")
    label.Size = UDim2.new(0, 150, 0, 80)
    label.StudsOffset = Vector3.new(0, 4, 0)
    label.AlwaysOnTop = true
    label.Parent = part

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = color == Constants.Color.WHITE and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 36
    textLabel.Parent = label

    local letters = {
        [Constants.PieceType.KING] = "K",
        [Constants.PieceType.QUEEN] = "Q",
        [Constants.PieceType.ROOK] = "R",
        [Constants.PieceType.BISHOP] = "B",
        [Constants.PieceType.KNIGHT] = "N",
        [Constants.PieceType.PAWN] = "P",
    }
    textLabel.Text = letters[pieceType] or "?"

    return part
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

-- Main function: Load piece model based on style configuration
function AssetLoader.loadPiece(pieceType, color)
    -- Check piece style setting
    if AssetLoader.pieceStyle == Constants.PieceStyle.CHESS_CLASSIC then
        return createChessPiece(pieceType, color)
    elseif AssetLoader.pieceStyle == Constants.PieceStyle.CHESS_MINIMAL then
        return createMinimalPiece(pieceType, color)
    elseif AssetLoader.pieceStyle == Constants.PieceStyle.CAT_SIMPLE then
        return createPlaceholder(pieceType, color)
    end

    -- CAT_3D style: Try to load real 3D models
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

    -- Strategy 3: Fallback to cat placeholder
    if not model then
        return createPlaceholder(pieceType, color)
    end

    -- Prepare and return
    return prepareModel(model, color) or createPlaceholder(pieceType, color)
end

-- Set piece style (call this to change style at runtime)
function AssetLoader.setPieceStyle(style)
    AssetLoader.pieceStyle = style
end

-- Get current piece style
function AssetLoader.getPieceStyle()
    return AssetLoader.pieceStyle
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
