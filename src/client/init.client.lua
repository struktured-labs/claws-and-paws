--[[
    Claws & Paws - Client Entry Point
    Handles UI, input, and local game rendering
]]

print("🐱 [DEBUG] Client script starting...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

print("🐱 [DEBUG] Requiring Shared...")
local Shared = require(ReplicatedStorage.Shared)
print("🐱 [DEBUG] Shared loaded!")
local Constants = Shared.Constants
print("🐱 [DEBUG] Constants loaded!")
print("🐱 [DEBUG] Requiring Logger...")
local Logger = require(script.Logger)
print("🐱 [DEBUG] Requiring MusicManager...")
local MusicManager = require(script.MusicManager)
print("🐱 [DEBUG] Requiring ParticleEffects...")
local ParticleEffects = require(script.ParticleEffects)
print("🐱 [DEBUG] Requiring SoundManager...")
local SoundManager = require(script.SoundManager)
print("🐱 [DEBUG] Requiring BattleAnimations...")
local BattleAnimations = require(script.BattleAnimations)
print("🐱 [DEBUG] Requiring AssetLoader...")
local AssetLoader = require(script.AssetLoader)
print("🐱 [DEBUG] Requiring TutorialManager...")
local TutorialManager = require(script.TutorialManager)
print("🐱 [DEBUG] Requiring CameraController...")
local CameraController = require(script.CameraController)
print("🐱 [DEBUG] Requiring SettingsManager...")
local SettingsManager = require(script.SettingsManager)
print("🐱 [DEBUG] All modules loaded!")

-- Initialize logger first
print("🐱 [DEBUG] Calling Logger.init()...")
Logger.init()
print("🐱 [DEBUG] Logger initialized!")

-- Initialize settings
print("🐱 [DEBUG] Initializing SettingsManager...")
SettingsManager.init()
print("🐱 [DEBUG] Settings initialized!")

local LocalPlayer = Players.LocalPlayer

-- Wait for remotes (no timeout - wait forever for server to create them)
print("🐱 [DEBUG] Waiting for Remotes folder...")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")  -- Wait indefinitely
print("🐱 [DEBUG] Remotes folder found!")

-- Debug: List all children in Remotes folder
print("🐱 [DEBUG] Children in Remotes folder:")
for _, child in ipairs(Remotes:GetChildren()) do
	print("🐱 [DEBUG]   - " .. child.Name .. " (" .. child.ClassName .. ")")
end
print("🐱 [DEBUG] Total children: " .. #Remotes:GetChildren())

print("🐱 [DEBUG] Got Remotes! Waiting for events...")
local RequestMatchEvent = Remotes:WaitForChild("RequestMatch")
print("🐱 [DEBUG] Got RequestMatch")
local CancelMatchEvent = Remotes:WaitForChild("CancelMatch")
print("🐱 [DEBUG] Got CancelMatch")
local MakeMoveEvent = Remotes:WaitForChild("MakeMove")
print("🐱 [DEBUG] Got MakeMove")
local ResignEvent = Remotes:WaitForChild("Resign")
print("🐱 [DEBUG] Got Resign")
local SendGestureEvent = Remotes:WaitForChild("SendGesture")
print("🐱 [DEBUG] Got SendGesture")
local RequestAIGameEvent = Remotes:WaitForChild("RequestAIGame")
print("🐱 [DEBUG] Got RequestAIGame")
local RequestAIvsAIGameEvent = Remotes:WaitForChild("RequestAIvsAIGame")
print("🐱 [DEBUG] Got RequestAIvsAIGame")
local GetGameStateFunction = Remotes:WaitForChild("GetGameState")
print("🐱 [DEBUG] Got GetGameState - all remotes loaded!")

-- Client state
local ClientState = {
    currentGameId = nil,
    gameState = nil,
    selectedSquare = nil,
    validMoves = {},
    playerColor = nil,
    isMyTurn = false,
    hoveredSquare = nil,
    hoverEffect = nil,
    cursorProjection = nil, -- Visual indicator showing where raycast hits
    animationInProgress = false, -- Track if animation is running
    isAIvsAI = false, -- Track if we're spectating AI vs AI
    -- Chess clock state for local interpolation
    localTimeWhite = 600,
    localTimeBlack = 600,
    lastClockUpdate = 0,
    clockRunning = false,
    -- Audio tracking state
    lastMoveCount = 0,       -- Track moveHistory length to detect new moves
    lastCheckWhite = false,  -- Previous check state for white
    lastCheckBlack = false,  -- Previous check state for black
    currentPurrSound = nil,  -- Active purr sound instance
}

-- Board visual settings - Cat-themed!
-- Colors will be loaded from settings
local BoardConfig = {
    squareSize = 20, -- HUGE board for better visibility (was 12)
    lightColor = Color3.fromRGB(255, 248, 231), -- Will be updated from settings
    darkColor = Color3.fromRGB(230, 145, 56),   -- Will be updated from settings
    highlightColor = Color3.fromRGB(255, 215, 0), -- Gold highlight
    validMoveColor = Color3.fromRGB(144, 238, 144), -- Light green (clear valid moves)
    lastMoveColor = Color3.fromRGB(255, 182, 193),  -- Light pink
    checkColor = Color3.fromRGB(255, 69, 0),        -- Red-orange (danger!)
}

-- Piece model references (to be replaced with actual assets)
local PieceModels = {}

-- Idle breathing animation for pieces
local function startIdleAnimation(pieceModel)
    local mainPart = pieceModel
    local isModel = pieceModel:IsA("Model")

    if isModel then
        mainPart = pieceModel.PrimaryPart or pieceModel:FindFirstChildWhichIsA("BasePart")
    end

    if not mainPart or not mainPart:IsA("BasePart") then
        return
    end

    local originalPos = mainPart.Position
    local breatheHeight = 0.2
    local breatheTime = 2

    -- Create continuous bobbing animation (breathing)
    local TweenService = game:GetService("TweenService")
    local breatheInfo = TweenInfo.new(
        breatheTime,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut,
        -1, -- Repeat infinitely
        true -- Reverse
    )

    local breatheTween = TweenService:Create(mainPart, breatheInfo, {
        Position = originalPos + Vector3.new(0, breatheHeight, 0)
    })

    breatheTween:Play()

    -- If this is a model with parts, animate tail and ears too!
    if isModel then
        local tail = pieceModel:FindFirstChild("Tail")
        if tail then
            local tailOriginalOrientation = tail.Orientation
            local tailWagInfo = TweenInfo.new(
                0.5,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true
            )
            local tailWag = TweenService:Create(tail, tailWagInfo, {
                Orientation = tailOriginalOrientation + Vector3.new(0, 15, 0)
            })
            tailWag:Play()
        end

        -- Ear twitch (randomized)
        local leftEar = pieceModel:FindFirstChild("LeftEar")
        local rightEar = pieceModel:FindFirstChild("RightEar")
        if leftEar and rightEar then
            task.spawn(function()
                while pieceModel.Parent do
                    task.wait(math.random(2, 5))
                    -- Random ear twitch
                    local earToTwitch = math.random(1, 2) == 1 and leftEar or rightEar
                    local originalOrientation = earToTwitch.Orientation
                    local twitchTween = TweenService:Create(earToTwitch, TweenInfo.new(0.1), {
                        Orientation = originalOrientation + Vector3.new(0, 0, 20)
                    })
                    local returnTween = TweenService:Create(earToTwitch, TweenInfo.new(0.1), {
                        Orientation = originalOrientation
                    })
                    twitchTween.Completed:Connect(function()
                        returnTween:Play()
                    end)
                    twitchTween:Play()
                end
            end)
        end
    end

    -- Store tween so we can cancel it later if needed
    mainPart:SetAttribute("IdleTween", true)
end

-- Animate a move with proper battle animations
local function animateMove(boardFolder, fromRow, fromCol, toRow, toCol, isCapture, pieceType, onComplete)
    print(string.format("🐱 [ANIM] Starting animation: [%d,%d] → [%d,%d]", fromRow, fromCol, toRow, toCol))

    -- Mark animation as in progress
    ClientState.animationInProgress = true
    print("🐱 [ANIM] Set animationInProgress = true")

    -- Find the moving piece
    local pieceName = string.format("Piece_%d_%d", fromRow, fromCol)
    local piece = boardFolder:FindFirstChild(pieceName)

    if not piece then
        print("🐱 [ANIM] ERROR: Piece not found: " .. pieceName)
        ClientState.animationInProgress = false
        if onComplete then onComplete() end
        return
    end

    print("🐱 [ANIM] Found piece to animate: " .. pieceName)

    -- Get main part for animation
    local mainPart = piece
    if piece:IsA("Model") then
        mainPart = piece.PrimaryPart or piece:FindFirstChildWhichIsA("BasePart")
    end

    if not mainPart then
        ClientState.animationInProgress = false
        if onComplete then onComplete() end
        return
    end

    -- Wrap onComplete to clean up animated piece and clear animation flag
    local wrappedComplete = function()
        print("🐱 [ANIM] Animation complete, cleaning up and setting animationInProgress = false")

        -- CRITICAL: Destroy the animated piece BEFORE calling onComplete
        -- This prevents duplicate pieces (old animated piece + new piece from updateBoardVisuals)
        if piece and piece.Parent then
            print(string.format("🐱 [ANIM] Destroying animated piece: %s", pieceName))
            piece:Destroy()
        end

        ClientState.animationInProgress = false
        if onComplete then onComplete() end
    end

    local fromPos = mainPart.Position
    local toPos = Vector3.new(
        (toCol - 3.5) * BoardConfig.squareSize,
        3.5,
        (toRow - 3.5) * BoardConfig.squareSize
    )

    -- If this is a capture, play dramatic cat fight animation
    if isCapture then
        local targetPieceName = string.format("Piece_%d_%d", toRow, toCol)
        local targetPiece = boardFolder:FindFirstChild(targetPieceName)
        local targetPart = nil
        if targetPiece then
            print(string.format("🐱 [ANIM] Found target piece for fight: %s", targetPieceName))
            if targetPiece:IsA("Model") then
                targetPart = targetPiece.PrimaryPart or targetPiece:FindFirstChildWhichIsA("BasePart")
            else
                targetPart = targetPiece
            end
        end

        -- Show "Click to skip" hint
        local skipHint = Instance.new("TextLabel")
        skipHint.Name = "SkipHint"
        skipHint.Size = UDim2.new(0, 200, 0, 30)
        skipHint.Position = UDim2.new(0.5, -100, 0.85, 0)
        skipHint.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        skipHint.BackgroundTransparency = 0.3
        skipHint.Text = "Click to skip animation"
        skipHint.TextColor3 = Color3.fromRGB(200, 200, 200)
        skipHint.Font = Enum.Font.GothamBold
        skipHint.TextSize = 14
        skipHint.Parent = LocalPlayer.PlayerGui:FindFirstChild("GameHUD") or LocalPlayer.PlayerGui

        local skipCorner = Instance.new("UICorner")
        skipCorner.CornerRadius = UDim.new(0, 6)
        skipCorner.Parent = skipHint

        -- Use the dramatic catFight animation
        BattleAnimations.catFight(mainPart, targetPart, fromPos, toPos, function()
            -- Clean up skip hint
            if skipHint and skipHint.Parent then
                skipHint:Destroy()
            end
            -- Destroy defender after fight
            if targetPiece and targetPiece.Parent then
                targetPiece:Destroy()
            end
            -- Clean up any lingering dust clouds
            for _, child in ipairs(workspace:GetChildren()) do
                if child.Name == "FightDustCloud" then
                    child:Destroy()
                end
            end
            wrappedComplete()
        end)
    else
        -- Use piece-specific animation for regular moves
        BattleAnimations.smartMove(mainPart, fromPos, toPos, pieceType, wrappedComplete)
    end
end

-- Create the chess board
local function createBoard()
    local boardFolder = Instance.new("Folder")
    boardFolder.Name = "ChessBoard"
    boardFolder.Parent = workspace

    local squares = {}

    for row = 1, Constants.BOARD_SIZE do
        squares[row] = {}
        for col = 1, Constants.BOARD_SIZE do
            -- Create the visual square (low and flat)
            local square = Instance.new("Part")
            square.Name = string.format("Square_%d_%d", row, col)
            square.Size = Vector3.new(BoardConfig.squareSize, 0.5, BoardConfig.squareSize)
            square.Position = Vector3.new(
                (col - 3.5) * BoardConfig.squareSize,
                0.25,
                (row - 3.5) * BoardConfig.squareSize
            )
            square.Anchored = true
            square.CanCollide = false -- Don't block movement

            -- Checkerboard pattern with cat-themed polish
            if (row + col) % 2 == 0 then
                square.Color = BoardConfig.lightColor
                square.Material = Enum.Material.SmoothPlastic
            else
                square.Color = BoardConfig.darkColor
                square.Material = Enum.Material.Wood -- Scratching post vibes!
            end

            -- Add subtle shine for that Nintendo polish
            square.Reflectance = 0.1

            square.Parent = boardFolder
            squares[row][col] = square

            -- Create an INVISIBLE TALL CLICKABLE COLUMN above each square
            -- This makes clicking WAY easier - raycast hits this first!
            local clickZone = Instance.new("Part")
            clickZone.Name = string.format("ClickZone_%d_%d", row, col)
            clickZone.Size = Vector3.new(BoardConfig.squareSize, 50, BoardConfig.squareSize) -- Tall column, full square coverage
            clickZone.Position = Vector3.new(
                (col - 3.5) * BoardConfig.squareSize,
                25, -- Centered at height 25 (extends from 0 to 50)
                (row - 3.5) * BoardConfig.squareSize
            )
            clickZone.Anchored = true
            clickZone.CanCollide = false
            clickZone.Transparency = 1 -- Completely invisible
            clickZone.Material = Enum.Material.SmoothPlastic

            -- Store row/col for click detection on the CLICK ZONE
            clickZone:SetAttribute("Row", row)
            clickZone:SetAttribute("Col", col)

            clickZone.Parent = boardFolder
        end
    end

    -- Add decorative border
    local boardSize = Constants.BOARD_SIZE * BoardConfig.squareSize
    local borderThickness = 2 -- Thicker border for bigger board
    local borderColor = Color3.fromRGB(101, 67, 33) -- Dark wood

    local borderParts = {
        {name = "North", size = Vector3.new(boardSize + borderThickness * 2, 0.5, borderThickness),
         pos = Vector3.new(0, 0.25, -(boardSize/2 + borderThickness/2))},
        {name = "South", size = Vector3.new(boardSize + borderThickness * 2, 0.5, borderThickness),
         pos = Vector3.new(0, 0.25, boardSize/2 + borderThickness/2)},
        {name = "East", size = Vector3.new(borderThickness, 0.5, boardSize),
         pos = Vector3.new(boardSize/2 + borderThickness/2, 0.25, 0)},
        {name = "West", size = Vector3.new(borderThickness, 0.5, boardSize),
         pos = Vector3.new(-(boardSize/2 + borderThickness/2), 0.25, 0)},
    }

    for _, borderData in ipairs(borderParts) do
        local border = Instance.new("Part")
        border.Name = "Border_" .. borderData.name
        border.Size = borderData.size
        border.Position = borderData.pos
        border.Color = borderColor
        border.Material = Enum.Material.Wood
        border.Anchored = true
        border.CanCollide = false
        border.Parent = boardFolder
    end

    -- Add chess coordinates (A-F columns, 1-6 rows)
    local coordFolder = Instance.new("Folder")
    coordFolder.Name = "Coordinates"
    coordFolder.Parent = boardFolder

    -- Column labels (A-F) along the bottom
    local colLabels = {"A", "B", "C", "D", "E", "F"}
    for col = 1, Constants.BOARD_SIZE do
        local label = Instance.new("TextLabel")
        label.Name = "ColLabel_" .. col
        label.Size = UDim2.new(0, 30, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = colLabels[col]
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 16

        -- Create BillboardGui for 3D positioning
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ColBillboard_" .. col
        billboard.Size = UDim2.new(0, 30, 0, 20)
        billboard.StudsOffset = Vector3.new(0, 0.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = boardFolder

        -- Position at bottom of board
        local anchor = Instance.new("Part")
        anchor.Name = "ColAnchor_" .. col
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Position = Vector3.new(
            (col - 3.5) * BoardConfig.squareSize,
            0.3,
            (Constants.BOARD_SIZE - 3.5 + 0.7) * BoardConfig.squareSize
        )
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.Parent = coordFolder

        billboard.Adornee = anchor
        label.Parent = billboard
    end

    -- Row labels (1-6) along the left side
    for row = 1, Constants.BOARD_SIZE do
        local label = Instance.new("TextLabel")
        label.Name = "RowLabel_" .. row
        label.Size = UDim2.new(0, 20, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = tostring(row)
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 16

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "RowBillboard_" .. row
        billboard.Size = UDim2.new(0, 20, 0, 20)
        billboard.StudsOffset = Vector3.new(0, 0.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = boardFolder

        local anchor = Instance.new("Part")
        anchor.Name = "RowAnchor_" .. row
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Position = Vector3.new(
            (-3.5 - 0.7) * BoardConfig.squareSize,
            0.3,
            (row - 3.5) * BoardConfig.squareSize
        )
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.Parent = coordFolder

        billboard.Adornee = anchor
        label.Parent = billboard
    end

    return boardFolder, squares
end

-- Create a piece model using AssetLoader (tries 3D models, falls back to placeholders)
local function createPieceModel(pieceType, color)
    -- Load from AssetLoader (handles 3D models + fallback)
    local piece = AssetLoader.loadPiece(pieceType, color)

    -- Add paw print trail effect to the main part
    local mainPart = piece
    if piece:IsA("Model") then
        mainPart = piece.PrimaryPart or piece:FindFirstChildWhichIsA("BasePart")
    end

    if mainPart and mainPart:IsA("BasePart") then
        ParticleEffects.createPawPrints(mainPart)
    end

    return piece
end

-- Piece type letter mapping for floating labels
local PIECE_LETTERS = {
    [Constants.PieceType.KING] = "K",
    [Constants.PieceType.QUEEN] = "Q",
    [Constants.PieceType.ROOK] = "R",
    [Constants.PieceType.BISHOP] = "B",
    [Constants.PieceType.KNIGHT] = "N",
    [Constants.PieceType.PAWN] = "P",
    [Constants.PieceType.ARCHBISHOP] = "A",
    [Constants.PieceType.CHANCELLOR] = "C",
    [Constants.PieceType.AMAZON] = "Z",
}

-- Add a floating BillboardGui label above a piece showing its type letter
local function addPieceLabel(pieceModel, pieceType, pieceColor)
    if not SettingsManager.get("showPieceLabels") then return end

    local letter = PIECE_LETTERS[pieceType] or "?"

    -- Find the part to adorn
    local adornPart = pieceModel
    if pieceModel:IsA("Model") then
        adornPart = pieceModel.PrimaryPart or pieceModel:FindFirstChildWhichIsA("BasePart")
    end
    if not adornPart or not adornPart:IsA("BasePart") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PieceLabel"
    billboard.Size = UDim2.new(0, 40, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 5, 0) -- Float above the piece
    billboard.AlwaysOnTop = true
    billboard.Adornee = adornPart
    billboard.Parent = pieceModel -- Parented to piece so it auto-cleans up

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = letter
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.Parent = billboard

    -- Team-colored text with contrasting stroke
    if pieceColor == Constants.Color.WHITE then
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    else
        label.TextColor3 = Color3.fromRGB(50, 50, 50)
        label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
    end
    label.TextStrokeTransparency = 0.3
end

-- Update board visuals from game state
local function updateBoardVisuals(boardFolder, squares, gameState, skipAnimation)
    print("🐱 [UPDATE] ========== updateBoardVisuals called ==========")

    -- CRITICAL: Don't update board while animation is in progress!
    -- This would destroy the piece being animated
    if ClientState.animationInProgress then
        print("🐱 [UPDATE] ⚠️ SKIPPING update - animation in progress!")
        return
    end

    -- Clear existing pieces and effects
    local destroyedCount = 0
    for _, child in ipairs(boardFolder:GetChildren()) do
        if child.Name:sub(1, 5) == "Piece" then
            print("🐱 [UPDATE] Destroying piece: " .. child.Name)
            child:Destroy()
            destroyedCount = destroyedCount + 1
        end
    end
    print("🐱 [UPDATE] Destroyed " .. destroyedCount .. " existing pieces")

    -- Clear all glows and sparkles from squares
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local square = squares[row][col]
            for _, child in ipairs(square:GetChildren()) do
                if child:IsA("SurfaceLight") or child:IsA("Sparkles") then
                    child:Destroy()
                end
            end
        end
    end

    if not gameState or not gameState.pieces then
        warn("🐱 [UPDATE] ⚠️ No game state or pieces to render!")
        return
    end

    -- Debug: Count and LIST all pieces in flat array state
    print(string.format("🐱 [UPDATE] Received %d pieces in flat array format:", #gameState.pieces))
    for _, piece in ipairs(gameState.pieces) do
        print(string.format("🐱 [UPDATE]   [%d,%d]: type=%d color=%d", piece.row, piece.col, piece.type, piece.color))
    end

    -- Place pieces from flat array
    for _, pieceData in ipairs(gameState.pieces) do
        local row, col = pieceData.row, pieceData.col
        local pieceModel = createPieceModel(pieceData.type, pieceData.color)
        print("🐱 [DEBUG] Created piece at [" .. row .. "," .. col .. "]: type=" .. pieceData.type .. " color=" .. pieceData.color)
        pieceModel.Name = string.format("Piece_%d_%d", row, col)

                -- IMPORTANT: Parent FIRST, then position
                pieceModel.Parent = boardFolder

                local targetPos = Vector3.new(
                    (col - 3.5) * BoardConfig.squareSize,
                    3.5, -- Higher for bigger pieces
                    (row - 3.5) * BoardConfig.squareSize
                )

                -- Position after parenting (critical for Models!)
                if pieceModel:IsA("Model") then
                    -- MoveTo() only works correctly after parenting
                    pieceModel:MoveTo(targetPos)

                    -- Rotate pieces to face each other
                    -- Black pieces (rows 5-6) face white (180 degrees)
                    -- White pieces (rows 1-2) face black (0 degrees)
                    if pieceData.color == Constants.Color.BLACK then
                        pieceModel:SetPrimaryPartCFrame(pieceModel.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(180), 0))
                    end
                else
                    pieceModel.Position = targetPos
                    -- Rotate single parts too
                    if pieceData.color == Constants.Color.BLACK then
                        pieceModel.CFrame = pieceModel.CFrame * CFrame.Angles(0, math.rad(180), 0)
                    end
                end
                print("🐱 [DEBUG] Positioned piece at " .. tostring(targetPos))

                -- Add floating piece type label
                addPieceLabel(pieceModel, pieceData.type, pieceData.color)

                -- Add spawn animation for new pieces (but not initial setup)
                if not skipAnimation and gameState.lastMove then
                    local wasJustMoved = (gameState.lastMove.toRow == row and gameState.lastMove.toCol == col)
                    if not wasJustMoved then
                        -- Add subtle idle breathing animation
                        startIdleAnimation(pieceModel)
                    end
                end
    end

    -- Update square colors
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local square = squares[row][col]
            local baseColor = ((row + col) % 2 == 0) and BoardConfig.lightColor or BoardConfig.darkColor
            square.Color = baseColor

            -- Reset click zones to invisible
            local clickZoneName = string.format("ClickZone_%d_%d", row, col)
            local clickZone = boardFolder:FindFirstChild(clickZoneName)
            if clickZone then
                clickZone.Transparency = 1 -- Invisible
            end
        end
    end

    -- Highlight selected square with sparkles!
    if ClientState.selectedSquare then
        local sq = squares[ClientState.selectedSquare.row][ClientState.selectedSquare.col]
        sq.Color = BoardConfig.highlightColor
        ParticleEffects.createSparkles(sq)
    end

    -- Highlight valid moves with glow
    for _, move in ipairs(ClientState.validMoves) do
        local sq = squares[move.row][move.col]
        if sq then
            sq.Color = BoardConfig.validMoveColor
            ParticleEffects.highlightSquare(sq, Color3.fromRGB(144, 238, 144))
        end
    end
end

-- Helper: Find piece at position in flat array
local function getPieceAt(gameState, row, col)
    if not gameState or not gameState.pieces then return nil end
    for _, piece in ipairs(gameState.pieces) do
        if piece.row == row and piece.col == col then
            return piece
        end
    end
    return nil
end

-- Handle square click
local function onSquareClicked(row, col, boardFolder, squares)
    if not ClientState.gameState or ClientState.gameState.gameState ~= Constants.GameState.IN_PROGRESS then
        return
    end

    if not ClientState.isMyTurn then
        return
    end

    local pieceData = getPieceAt(ClientState.gameState, row, col)

    if ClientState.selectedSquare then
        -- Check if this is a valid move
        local isValidMove = false
        for _, move in ipairs(ClientState.validMoves) do
            if move.row == row and move.col == col then
                isValidMove = true
                break
            end
        end

        print("🐱 [DEBUG] Have " .. #ClientState.validMoves .. " valid moves, checking click at [" .. row .. "," .. col .. "]")
        print("🐱 [DEBUG] Click types: row=" .. type(row) .. " col=" .. type(col))
        for i, move in ipairs(ClientState.validMoves) do
            if move and move.row and move.col then
                print("🐱 [DEBUG] Comparing with move " .. i .. ": [" .. move.row .. "," .. move.col .. "] (types: " .. type(move.row) .. "," .. type(move.col) .. ") match=" .. tostring(move.row == row and move.col == col))
            end
        end
        print("🐱 [DEBUG] Result: Valid move: " .. tostring(isValidMove))
        Logger.debug(string.format("Clicked square [%d,%d], Valid move: %s", row, col, tostring(isValidMove)))

        if isValidMove then
            -- Check if this is a capture
            local targetPiece = getPieceAt(ClientState.gameState, row, col)
            local isCapture = targetPiece ~= nil

            -- Get the moving piece type
            local fromRow = ClientState.selectedSquare.row
            local fromCol = ClientState.selectedSquare.col
            local movingPiece = getPieceAt(ClientState.gameState, fromRow, fromCol)
            local movingPieceType = movingPiece and movingPiece.type

            -- Helper to send the move to server (with optional promotion piece)
            local function sendMove(promotionPiece)
                Logger.info(string.format("Sending move: [%d,%d] → [%d,%d]",
                    fromRow, fromCol, row, col))

                MakeMoveEvent:FireServer(
                    ClientState.currentGameId,
                    fromRow,
                    fromCol,
                    row,
                    col,
                    promotionPiece
                )
            end

            -- Check if this is a pawn promotion
            local isPromotion = false
            if movingPieceType == Constants.PieceType.PAWN then
                local promotionRow = (ClientState.playerColor == Constants.Color.WHITE) and Constants.BOARD_SIZE or 1
                if row == promotionRow then
                    isPromotion = true
                end
            end

            -- Animate the move first
            animateMove(boardFolder, fromRow, fromCol, row, col, isCapture, movingPieceType, function()
                -- Animation complete - now update server
                if isCapture then
                    -- Play capture sound and effect
                    SoundManager.playCaptureSound()
                    local targetPos = Vector3.new(
                        (col - 3.5) * BoardConfig.squareSize,
                        3.5,
                        (row - 3.5) * BoardConfig.squareSize
                    )
                    ParticleEffects.captureExplosion(targetPos, targetPiece.color == Constants.Color.WHITE
                        and Color3.fromRGB(255, 240, 220)
                        or Color3.fromRGB(80, 60, 50))
                else
                    -- Play move sound
                    SoundManager.playMoveSound(pieceData and pieceData.type)
                end

                if isPromotion then
                    -- Show promotion popup, then send move with chosen piece
                    showPromotionPopup(function(chosenType)
                        sendMove(chosenType)
                    end)
                else
                    sendMove(nil)
                end
            end)

            ClientState.selectedSquare = nil
            ClientState.validMoves = {}
        elseif pieceData and pieceData.color == ClientState.playerColor then
            -- Select new piece - but check if it can move first
            local engine = Shared.ChessEngine.new()
            engine:deserialize(ClientState.gameState)
            local validMoves = engine:getValidMoves(row, col)

            if #validMoves == 0 then
                -- Piece has no valid moves
                SoundManager.playDismissiveSound()
                return
            end

            SoundManager.playSelectSound()
            ClientState.selectedSquare = {row = row, col = col}
            ClientState.validMoves = validMoves
        else
            -- Invalid click (not a valid move, not our piece) - play dismissive sound
            SoundManager.playDismissiveSound()
            ClientState.selectedSquare = nil
            ClientState.validMoves = {}
        end
    else
        -- Select piece if it's ours
        if pieceData and pieceData.color == ClientState.playerColor then
            -- Calculate valid moves BEFORE selecting
            local engine = Shared.ChessEngine.new()
            engine:deserialize(ClientState.gameState)
            local validMoves = engine:getValidMoves(row, col)

            if #validMoves == 0 then
                -- Piece has no valid moves! Play dismissive cat sound
                Logger.debug(string.format("Piece at [%d,%d] has no valid moves - cannot select", row, col))
                SoundManager.playDismissiveSound()  -- Cute "meh" cat noise
                return
            end

            Logger.info(string.format("Selected piece at [%d,%d], type: %d", row, col, pieceData.type))
            SoundManager.playSelectSound()
            ClientState.selectedSquare = {row = row, col = col}
            ClientState.validMoves = validMoves
            print("🐱 [DEBUG] Selected piece, found " .. #ClientState.validMoves .. " valid moves")
            if ClientState.validMoves and #ClientState.validMoves > 0 then
                for i, move in ipairs(ClientState.validMoves) do
                    if move and move.row and move.col then
                        print("🐱 [DEBUG]   Move " .. i .. ": [" .. move.row .. "," .. move.col .. "]")
                    else
                        print("🐱 [DEBUG]   Move " .. i .. ": INVALID MOVE STRUCTURE")
                    end
                end
            end
            Logger.debug(string.format("Found %d valid moves", #ClientState.validMoves))
        else
            Logger.debug(string.format("Cannot select square [%d,%d] - not your piece or empty", row, col))
        end
    end

    -- Don't call updateBoardVisuals here! It would destroy pieces mid-animation.
    -- The server will broadcast updated state after processing the move, which will call updateBoardVisuals.
    -- For selection/deselection, we only need to update highlights (which updateBoardVisuals does),
    -- but we should update them WITHOUT destroying/recreating all pieces.

    -- Instead, just update highlights on squares
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local square = squares[row][col]
            -- Remove old effects
            for _, child in ipairs(square:GetChildren()) do
                if child:IsA("SurfaceLight") or child:IsA("Sparkles") then
                    child:Destroy()
                end
            end
            -- Reset to base color
            local baseColor = ((row + col) % 2 == 0) and BoardConfig.lightColor or BoardConfig.darkColor
            square.Color = baseColor
        end
    end

    -- Highlight selected square
    if ClientState.selectedSquare then
        local sq = squares[ClientState.selectedSquare.row][ClientState.selectedSquare.col]
        sq.Color = BoardConfig.highlightColor
        ParticleEffects.createSparkles(sq)
    end

    -- Highlight valid moves
    for _, move in ipairs(ClientState.validMoves) do
        if move and move.row and move.col then
            local sq = squares[move.row][move.col]
            sq.Color = BoardConfig.validMoveColor
            ParticleEffects.highlightSquare(sq)
        end
    end
end

-- Create AI vs AI difficulty selector popup
local function createAIvsAIPopup(mainMenuFrame)
    local popup = Instance.new("Frame")
    popup.Name = "AIvsAIPopup"
    popup.Size = UDim2.new(0, 320, 0, 280)
    popup.Position = UDim2.new(0.5, -160, 0.5, -140)
    popup.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    popup.BorderSizePixel = 0
    popup.Visible = false
    popup.Parent = mainMenuFrame.Parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = popup

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 100)
    stroke.Thickness = 2
    stroke.Parent = popup

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "🤖 Watch AI vs AI 🤖"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 24
    title.Parent = popup

    -- Difficulty options
    local difficulties = {
        {text = "Easy", mode = Constants.GameMode.AI_EASY},
        {text = "Medium", mode = Constants.GameMode.AI_MEDIUM},
        {text = "Hard", mode = Constants.GameMode.AI_HARD},
    }

    -- Selected difficulties
    local selectedWhite = Constants.GameMode.AI_MEDIUM
    local selectedBlack = Constants.GameMode.AI_MEDIUM

    -- White AI selector
    local whiteLabel = Instance.new("TextLabel")
    whiteLabel.Name = "WhiteLabel"
    whiteLabel.Size = UDim2.new(0, 280, 0, 25)
    whiteLabel.Position = UDim2.new(0.5, -140, 0, 45)
    whiteLabel.BackgroundTransparency = 1
    whiteLabel.Text = "White AI Difficulty:"
    whiteLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    whiteLabel.Font = Enum.Font.GothamBold
    whiteLabel.TextSize = 16
    whiteLabel.TextXAlignment = Enum.TextXAlignment.Left
    whiteLabel.Parent = popup

    local whiteButtons = {}
    for i, diff in ipairs(difficulties) do
        local btn = Instance.new("TextButton")
        btn.Name = "White_" .. diff.mode
        btn.Size = UDim2.new(0, 85, 0, 32)
        btn.Position = UDim2.new(0, 15 + (i - 1) * 95, 0, 75)
        btn.BackgroundColor3 = diff.mode == selectedWhite
            and Color3.fromRGB(100, 180, 100)
            or Color3.fromRGB(80, 80, 100)
        btn.BorderSizePixel = 0
        btn.Text = diff.text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Parent = popup

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = btn

        whiteButtons[diff.mode] = btn

        btn.MouseButton1Click:Connect(function()
            selectedWhite = diff.mode
            for mode, b in pairs(whiteButtons) do
                b.BackgroundColor3 = mode == selectedWhite
                    and Color3.fromRGB(100, 180, 100)
                    or Color3.fromRGB(80, 80, 100)
            end
            SoundManager.playSelectSound()
        end)
    end

    -- Black AI selector
    local blackLabel = Instance.new("TextLabel")
    blackLabel.Name = "BlackLabel"
    blackLabel.Size = UDim2.new(0, 280, 0, 25)
    blackLabel.Position = UDim2.new(0.5, -140, 0, 120)
    blackLabel.BackgroundTransparency = 1
    blackLabel.Text = "Black AI Difficulty:"
    blackLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    blackLabel.Font = Enum.Font.GothamBold
    blackLabel.TextSize = 16
    blackLabel.TextXAlignment = Enum.TextXAlignment.Left
    blackLabel.Parent = popup

    local blackButtons = {}
    for i, diff in ipairs(difficulties) do
        local btn = Instance.new("TextButton")
        btn.Name = "Black_" .. diff.mode
        btn.Size = UDim2.new(0, 85, 0, 32)
        btn.Position = UDim2.new(0, 15 + (i - 1) * 95, 0, 150)
        btn.BackgroundColor3 = diff.mode == selectedBlack
            and Color3.fromRGB(60, 60, 60)
            or Color3.fromRGB(80, 80, 100)
        btn.BorderSizePixel = 0
        btn.Text = diff.text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Parent = popup

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = btn

        blackButtons[diff.mode] = btn

        btn.MouseButton1Click:Connect(function()
            selectedBlack = diff.mode
            for mode, b in pairs(blackButtons) do
                b.BackgroundColor3 = mode == selectedBlack
                    and Color3.fromRGB(60, 60, 60)
                    or Color3.fromRGB(80, 80, 100)
            end
            SoundManager.playSelectSound()
        end)
    end

    -- Start button
    local startBtn = Instance.new("TextButton")
    startBtn.Name = "StartButton"
    startBtn.Size = UDim2.new(0, 200, 0, 40)
    startBtn.Position = UDim2.new(0.5, -100, 0, 195)
    startBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
    startBtn.BorderSizePixel = 0
    startBtn.Text = "▶️ Start Match"
    startBtn.TextColor3 = Color3.new(1, 1, 1)
    startBtn.Font = Enum.Font.FredokaOne
    startBtn.TextSize = 20
    startBtn.Parent = popup

    local startCorner = Instance.new("UICorner")
    startCorner.CornerRadius = UDim.new(0, 8)
    startCorner.Parent = startBtn

    startBtn.MouseButton1Click:Connect(function()
        print(string.format("🐱 [CLIENT] Starting AI vs AI: White=%s, Black=%s", selectedWhite, selectedBlack))
        RequestAIvsAIGameEvent:FireServer(selectedWhite, selectedBlack)
        -- Play music based on the harder AI difficulty
        local harderDifficulty = selectedWhite
        if selectedBlack == Constants.GameMode.AI_HARD or selectedWhite == Constants.GameMode.AI_HARD then
            harderDifficulty = Constants.GameMode.AI_HARD
        elseif selectedBlack == Constants.GameMode.AI_MEDIUM or selectedWhite == Constants.GameMode.AI_MEDIUM then
            harderDifficulty = Constants.GameMode.AI_MEDIUM
        end
        MusicManager.playForGameMode(harderDifficulty)
        popup.Visible = false
        mainMenuFrame.Visible = false
    end)

    -- Cancel button
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Name = "CancelButton"
    cancelBtn.Size = UDim2.new(0, 80, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, -40, 0, 240)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 80)
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = Color3.new(1, 1, 1)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 14
    cancelBtn.Parent = popup

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 5)
    cancelCorner.Parent = cancelBtn

    cancelBtn.MouseButton1Click:Connect(function()
        popup.Visible = false
    end)

    return popup
end

-- Create main menu UI
local function createMainMenu()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MainMenu"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "MenuFrame"
    frame.Size = UDim2.new(0, 300, 0, 510) -- Increased to fit AI vs AI button
    frame.Position = UDim2.new(0.5, -150, 0.5, -255)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 60)
    title.BackgroundTransparency = 1
    title.Text = "🐾 Claws & Paws"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 36
    title.Parent = frame

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 30)
    subtitle.Position = UDim2.new(0, 0, 0, 55)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Cat Chess Battle! 🐱♟️"
    subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 16
    subtitle.Parent = frame

    local buttonY = 100
    local buttons = {
        {text = "Play vs AI (Easy)", mode = Constants.GameMode.AI_EASY},
        {text = "Play vs AI (Medium)", mode = Constants.GameMode.AI_MEDIUM},
        {text = "Play vs AI (Hard)", mode = Constants.GameMode.AI_HARD},
        {text = "Play Casual", mode = Constants.GameMode.CASUAL},
        {text = "Play Ranked", mode = Constants.GameMode.RANKED},
    }

    for _, btnData in ipairs(buttons) do
        local button = Instance.new("TextButton")
        button.Name = btnData.mode
        button.Size = UDim2.new(0, 250, 0, 40)
        button.Position = UDim2.new(0.5, -125, 0, buttonY)
        button.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
        button.BorderSizePixel = 0
        button.Text = btnData.text
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 18
        button.Parent = frame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = button

        button.MouseButton1Click:Connect(function()
            if btnData.mode:sub(1, 2) == "AI" then
                RequestAIGameEvent:FireServer(btnData.mode)
            else
                RequestMatchEvent:FireServer(btnData.mode)
            end
            -- Switch music based on game mode
            MusicManager.playForGameMode(btnData.mode)
            frame.Visible = false
        end)

        buttonY = buttonY + 50
    end

    -- Watch AI vs AI button (special styling)
    local aiVsAiBtn = Instance.new("TextButton")
    aiVsAiBtn.Name = "AIvsAIButton"
    aiVsAiBtn.Size = UDim2.new(0, 250, 0, 40)
    aiVsAiBtn.Position = UDim2.new(0.5, -125, 0, buttonY)
    aiVsAiBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 180)  -- Purple for AI vs AI
    aiVsAiBtn.BorderSizePixel = 0
    aiVsAiBtn.Text = "🤖 Watch AI vs AI"
    aiVsAiBtn.TextColor3 = Color3.new(1, 1, 1)
    aiVsAiBtn.Font = Enum.Font.GothamBold
    aiVsAiBtn.TextSize = 18
    aiVsAiBtn.Parent = frame

    local aiVsAiCorner = Instance.new("UICorner")
    aiVsAiCorner.CornerRadius = UDim.new(0, 5)
    aiVsAiCorner.Parent = aiVsAiBtn

    -- Create the AI vs AI popup (hidden by default)
    local aiVsAiPopup = createAIvsAIPopup(frame)

    aiVsAiBtn.MouseButton1Click:Connect(function()
        aiVsAiPopup.Visible = true
        SoundManager.playSelectSound()
    end)

    buttonY = buttonY + 50

    -- Settings button
    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Name = "SettingsButton"
    settingsBtn.Size = UDim2.new(0, 250, 0, 40)
    settingsBtn.Position = UDim2.new(0.5, -125, 0, buttonY + 10)
    settingsBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    settingsBtn.BorderSizePixel = 0
    settingsBtn.Text = "⚙️ Settings"
    settingsBtn.TextColor3 = Color3.new(1, 1, 1)
    settingsBtn.Font = Enum.Font.GothamBold
    settingsBtn.TextSize = 18
    settingsBtn.Parent = frame

    local settingsBtnCorner = Instance.new("UICorner")
    settingsBtnCorner.CornerRadius = UDim.new(0, 5)
    settingsBtnCorner.Parent = settingsBtn

    settingsBtn.MouseButton1Click:Connect(function()
        SettingsManager.createSettingsUI(function()
            -- Callback when settings close - reapply theme
            SettingsManager.applyToBoardConfig(BoardConfig)
            -- Board colors will be updated when board is recreated or on next game
        end)
    end)

    return screenGui
end

-- Format time as MM:SS
local function formatTime(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

-- Get piece letter for miniboard display (Roblox doesn't render Unicode chess symbols)
local function getPieceSymbol(pieceType, color)
    local letters = {
        [Constants.PieceType.KING] = "K",
        [Constants.PieceType.QUEEN] = "Q",
        [Constants.PieceType.ROOK] = "R",
        [Constants.PieceType.BISHOP] = "B",
        [Constants.PieceType.KNIGHT] = "N",
        [Constants.PieceType.PAWN] = "P",
        [Constants.PieceType.ARCHBISHOP] = "A",
        [Constants.PieceType.CHANCELLOR] = "C",
        [Constants.PieceType.AMAZON] = "Z",
    }
    return letters[pieceType] or "?"
end

-- Create 2D miniboard component
local function createMiniboard(parent)
    local MINI_SQUARE_SIZE = 28
    local BOARD_SIZE = Constants.BOARD_SIZE

    -- Container frame
    local container = Instance.new("Frame")
    container.Name = "MiniboardContainer"
    container.Size = UDim2.new(0, MINI_SQUARE_SIZE * BOARD_SIZE + 20, 0, MINI_SQUARE_SIZE * BOARD_SIZE + 50)
    container.Position = UDim2.new(1, -200, 0.5, -100)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    container.BackgroundTransparency = 0.1
    container.Parent = parent

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 10)
    containerCorner.Parent = container

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromRGB(80, 80, 90)
    containerStroke.Thickness = 2
    containerStroke.Parent = container

    -- Title with toggle button
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 25)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = container

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -30, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "🗺️ Mini Map"
    title.TextColor3 = Color3.fromRGB(200, 200, 200)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = titleBar

    -- Toggle button (minimize/maximize)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.Size = UDim2.new(0, 25, 0, 25)
    toggleBtn.Position = UDim2.new(1, -28, 0, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "−"
    toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 18
    toggleBtn.Parent = titleBar

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 4)
    toggleCorner.Parent = toggleBtn

    -- Board frame
    local boardFrame = Instance.new("Frame")
    boardFrame.Name = "BoardFrame"
    boardFrame.Size = UDim2.new(0, MINI_SQUARE_SIZE * BOARD_SIZE, 0, MINI_SQUARE_SIZE * BOARD_SIZE)
    boardFrame.Position = UDim2.new(0.5, -(MINI_SQUARE_SIZE * BOARD_SIZE) / 2, 0, 30)
    boardFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    boardFrame.Parent = container

    local boardCorner = Instance.new("UICorner")
    boardCorner.CornerRadius = UDim.new(0, 4)
    boardCorner.Parent = boardFrame

    -- Create grid of squares
    local squares = {}
    local lightColor = Color3.fromRGB(240, 217, 181)  -- Classic chess light
    local darkColor = Color3.fromRGB(181, 136, 99)    -- Classic chess dark

    for row = 1, BOARD_SIZE do
        squares[row] = {}
        for col = 1, BOARD_SIZE do
            local square = Instance.new("Frame")
            square.Name = string.format("MiniSquare_%d_%d", row, col)
            -- Flip the display so white is at bottom (row 1 at bottom)
            local displayRow = BOARD_SIZE - row + 1
            square.Size = UDim2.new(0, MINI_SQUARE_SIZE, 0, MINI_SQUARE_SIZE)
            square.Position = UDim2.new(0, (col - 1) * MINI_SQUARE_SIZE, 0, (displayRow - 1) * MINI_SQUARE_SIZE)
            square.BackgroundColor3 = ((row + col) % 2 == 0) and lightColor or darkColor
            square.BorderSizePixel = 0
            square.Parent = boardFrame

            -- Piece label
            local pieceLabel = Instance.new("TextLabel")
            pieceLabel.Name = "PieceLabel"
            pieceLabel.Size = UDim2.new(1, 0, 1, 0)
            pieceLabel.BackgroundTransparency = 1
            pieceLabel.Text = ""
            pieceLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
            pieceLabel.Font = Enum.Font.GothamBold
            pieceLabel.TextSize = 20
            pieceLabel.Parent = square

            squares[row][col] = {frame = square, label = pieceLabel}
        end
    end

    -- Column labels (A-F)
    local colLabels = {"A", "B", "C", "D", "E", "F"}
    for col = 1, BOARD_SIZE do
        local label = Instance.new("TextLabel")
        label.Name = "ColLabel_" .. col
        label.Size = UDim2.new(0, MINI_SQUARE_SIZE, 0, 15)
        label.Position = UDim2.new(0, (col - 1) * MINI_SQUARE_SIZE, 1, 2)
        label.BackgroundTransparency = 1
        label.Text = colLabels[col]
        label.TextColor3 = Color3.fromRGB(150, 150, 150)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.Parent = boardFrame
    end

    -- Row labels (1-6)
    for row = 1, BOARD_SIZE do
        local label = Instance.new("TextLabel")
        label.Name = "RowLabel_" .. row
        local displayRow = BOARD_SIZE - row + 1
        label.Size = UDim2.new(0, 12, 0, MINI_SQUARE_SIZE)
        label.Position = UDim2.new(1, 2, 0, (displayRow - 1) * MINI_SQUARE_SIZE)
        label.BackgroundTransparency = 1
        label.Text = tostring(row)
        label.TextColor3 = Color3.fromRGB(150, 150, 150)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.Parent = boardFrame
    end

    -- Toggle functionality
    local isMinimized = false
    toggleBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            boardFrame.Visible = false
            container.Size = UDim2.new(0, MINI_SQUARE_SIZE * BOARD_SIZE + 20, 0, 30)
            toggleBtn.Text = "+"
        else
            boardFrame.Visible = true
            container.Size = UDim2.new(0, MINI_SQUARE_SIZE * BOARD_SIZE + 20, 0, MINI_SQUARE_SIZE * BOARD_SIZE + 50)
            toggleBtn.Text = "−"
        end
        SoundManager.playSelectSound()
    end)

    -- Update function
    local function updateMiniboard(gameState)
        -- Reset all squares (clear text and restore original colors)
        for row = 1, BOARD_SIZE do
            for col = 1, BOARD_SIZE do
                squares[row][col].label.Text = ""
                -- Restore original checkerboard color
                squares[row][col].frame.BackgroundColor3 = ((row + col) % 2 == 0) and lightColor or darkColor
            end
        end

        if not gameState or not gameState.pieces then return end

        -- Place pieces
        for _, piece in ipairs(gameState.pieces) do
            local row, col = piece.row, piece.col
            if squares[row] and squares[row][col] then
                local symbol = getPieceSymbol(piece.type, piece.color)
                squares[row][col].label.Text = symbol
                -- Color the text based on piece color for better visibility
                if piece.color == Constants.Color.WHITE then
                    squares[row][col].label.TextColor3 = Color3.fromRGB(255, 255, 255)
                    squares[row][col].label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    squares[row][col].label.TextStrokeTransparency = 0.5
                else
                    squares[row][col].label.TextColor3 = Color3.fromRGB(30, 30, 30)
                    squares[row][col].label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
                    squares[row][col].label.TextStrokeTransparency = 0.7
                end
            end
        end

        -- Highlight last move if available
        if gameState.lastMove then
            local fromRow, fromCol = gameState.lastMove.fromRow, gameState.lastMove.fromCol
            local toRow, toCol = gameState.lastMove.toRow, gameState.lastMove.toCol

            if squares[fromRow] and squares[fromRow][fromCol] then
                squares[fromRow][fromCol].frame.BackgroundColor3 = Color3.fromRGB(255, 255, 150) -- Yellow highlight
            end
            if squares[toRow] and squares[toRow][toCol] then
                squares[toRow][toCol].frame.BackgroundColor3 = Color3.fromRGB(255, 255, 100) -- Brighter yellow
            end
        end
    end

    return container, updateMiniboard
end

-- Show promotion choice popup and return the chosen piece type via callback
local promotionGui = nil  -- persistent ScreenGui for promotion popup
local function showPromotionPopup(callback)
    -- Create the ScreenGui once
    if not promotionGui then
        promotionGui = Instance.new("ScreenGui")
        promotionGui.Name = "PromotionPopup"
        promotionGui.ResetOnSpawn = false
        promotionGui.DisplayOrder = 100 -- above other UI
        promotionGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Clear previous children
    for _, child in ipairs(promotionGui:GetChildren()) do
        child:Destroy()
    end
    promotionGui.Enabled = true

    -- Dimmed background overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = promotionGui

    -- Popup frame
    local popup = Instance.new("Frame")
    popup.Name = "PromotionFrame"
    popup.Size = UDim2.new(0, 300, 0, 160)
    popup.Position = UDim2.new(0.5, -150, 0.5, -80)
    popup.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    popup.BorderSizePixel = 0
    popup.Parent = promotionGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = popup

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 100)
    stroke.Thickness = 2
    stroke.Parent = popup

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "Promote Pawn To:"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 22
    title.Parent = popup

    -- Promotion options
    local options = {
        {label = "Q", name = "Queen", type = Constants.PieceType.QUEEN},
        {label = "R", name = "Rook", type = Constants.PieceType.ROOK},
        {label = "B", name = "Bishop", type = Constants.PieceType.BISHOP},
        {label = "N", name = "Knight", type = Constants.PieceType.KNIGHT},
    }

    for i, opt in ipairs(options) do
        local btn = Instance.new("TextButton")
        btn.Name = opt.name
        btn.Size = UDim2.new(0, 60, 0, 70)
        btn.Position = UDim2.new(0, 15 + (i - 1) * 70, 0, 50)
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        btn.Text = opt.label .. "\n" .. opt.name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.Parent = popup

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            promotionGui.Enabled = false
            callback(opt.type)
        end)

        -- Hover effect
        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        end)
    end
end

-- Create game HUD
local function createGameHUD()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GameHUD"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Turn indicator (bigger and more prominent)
    local turnLabel = Instance.new("TextLabel")
    turnLabel.Name = "TurnLabel"
    turnLabel.Size = UDim2.new(0, 400, 0, 70)
    turnLabel.Position = UDim2.new(0.5, -200, 0, 20)
    turnLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    turnLabel.BackgroundTransparency = 0.2
    turnLabel.Text = "⏳ Waiting for game..."
    turnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    turnLabel.Font = Enum.Font.FredokaOne
    turnLabel.TextSize = 32
    turnLabel.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = turnLabel

    -- Add stroke for better visibility
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 100)
    stroke.Thickness = 3
    stroke.Parent = turnLabel

    -- Chess Clock Container (left side of screen)
    local clockContainer = Instance.new("Frame")
    clockContainer.Name = "ChessClockContainer"
    clockContainer.Size = UDim2.new(0, 120, 0, 160)
    clockContainer.Position = UDim2.new(0, 20, 0.5, -80)
    clockContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    clockContainer.BackgroundTransparency = 0.1
    clockContainer.Parent = screenGui

    local clockCorner = Instance.new("UICorner")
    clockCorner.CornerRadius = UDim.new(0, 10)
    clockCorner.Parent = clockContainer

    local clockStroke = Instance.new("UIStroke")
    clockStroke.Color = Color3.fromRGB(80, 80, 90)
    clockStroke.Thickness = 2
    clockStroke.Parent = clockContainer

    -- Clock title
    local clockTitle = Instance.new("TextLabel")
    clockTitle.Name = "ClockTitle"
    clockTitle.Size = UDim2.new(1, 0, 0, 25)
    clockTitle.BackgroundTransparency = 1
    clockTitle.Text = "⏱️ Clock"
    clockTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    clockTitle.Font = Enum.Font.GothamBold
    clockTitle.TextSize = 14
    clockTitle.Parent = clockContainer

    -- Black player clock (top - opponent from white's perspective)
    local blackClockFrame = Instance.new("Frame")
    blackClockFrame.Name = "BlackClockFrame"
    blackClockFrame.Size = UDim2.new(1, -16, 0, 55)
    blackClockFrame.Position = UDim2.new(0, 8, 0, 28)
    blackClockFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    blackClockFrame.Parent = clockContainer

    local blackClockCorner = Instance.new("UICorner")
    blackClockCorner.CornerRadius = UDim.new(0, 6)
    blackClockCorner.Parent = blackClockFrame

    local blackLabel = Instance.new("TextLabel")
    blackLabel.Name = "Label"
    blackLabel.Size = UDim2.new(1, 0, 0, 18)
    blackLabel.BackgroundTransparency = 1
    blackLabel.Text = "⬛ Black"
    blackLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    blackLabel.Font = Enum.Font.GothamBold
    blackLabel.TextSize = 12
    blackLabel.Parent = blackClockFrame

    local blackTimeLabel = Instance.new("TextLabel")
    blackTimeLabel.Name = "TimeLabel"
    blackTimeLabel.Size = UDim2.new(1, 0, 0, 35)
    blackTimeLabel.Position = UDim2.new(0, 0, 0, 18)
    blackTimeLabel.BackgroundTransparency = 1
    blackTimeLabel.Text = "10:00"
    blackTimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    blackTimeLabel.Font = Enum.Font.Code
    blackTimeLabel.TextSize = 28
    blackTimeLabel.Parent = blackClockFrame

    -- White player clock (bottom - you from white's perspective)
    local whiteClockFrame = Instance.new("Frame")
    whiteClockFrame.Name = "WhiteClockFrame"
    whiteClockFrame.Size = UDim2.new(1, -16, 0, 55)
    whiteClockFrame.Position = UDim2.new(0, 8, 0, 95)
    whiteClockFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    whiteClockFrame.Parent = clockContainer

    local whiteClockCorner = Instance.new("UICorner")
    whiteClockCorner.CornerRadius = UDim.new(0, 6)
    whiteClockCorner.Parent = whiteClockFrame

    local whiteLabel = Instance.new("TextLabel")
    whiteLabel.Name = "Label"
    whiteLabel.Size = UDim2.new(1, 0, 0, 18)
    whiteLabel.BackgroundTransparency = 1
    whiteLabel.Text = "⬜ White"
    whiteLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    whiteLabel.Font = Enum.Font.GothamBold
    whiteLabel.TextSize = 12
    whiteLabel.Parent = whiteClockFrame

    local whiteTimeLabel = Instance.new("TextLabel")
    whiteTimeLabel.Name = "TimeLabel"
    whiteTimeLabel.Size = UDim2.new(1, 0, 0, 35)
    whiteTimeLabel.Position = UDim2.new(0, 0, 0, 18)
    whiteTimeLabel.BackgroundTransparency = 1
    whiteTimeLabel.Text = "10:00"
    whiteTimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    whiteTimeLabel.Font = Enum.Font.Code
    whiteTimeLabel.TextSize = 28
    whiteTimeLabel.Parent = whiteClockFrame

    -- Player color indicator (shows if you're white or black)
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Name = "ColorLabel"
    colorLabel.Size = UDim2.new(0, 200, 0, 50)
    colorLabel.Position = UDim2.new(0.5, -100, 0, 100)
    colorLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    colorLabel.BackgroundTransparency = 0.3
    colorLabel.Text = "You are: ?"
    colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 24
    colorLabel.Parent = screenGui

    local colorCorner = Instance.new("UICorner")
    colorCorner.CornerRadius = UDim.new(0, 10)
    colorCorner.Parent = colorLabel

    -- Resign button
    local resignBtn = Instance.new("TextButton")
    resignBtn.Name = "ResignButton"
    resignBtn.Size = UDim2.new(0, 100, 0, 40)
    resignBtn.Position = UDim2.new(1, -120, 1, -60)
    resignBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    resignBtn.Text = "Resign"
    resignBtn.TextColor3 = Color3.new(1, 1, 1)
    resignBtn.Font = Enum.Font.GothamBold
    resignBtn.TextSize = 18
    resignBtn.Parent = screenGui

    local resignCorner = Instance.new("UICorner")
    resignCorner.CornerRadius = UDim.new(0, 5)
    resignCorner.Parent = resignBtn

    resignBtn.MouseButton1Click:Connect(function()
        if ClientState.currentGameId then
            ResignEvent:FireServer(ClientState.currentGameId)
        end
    end)

    -- Reset Camera button
    local resetCamBtn = Instance.new("TextButton")
    resetCamBtn.Name = "ResetCameraButton"
    resetCamBtn.Size = UDim2.new(0, 40, 0, 40)
    resetCamBtn.Position = UDim2.new(1, -60, 1, -110)
    resetCamBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    resetCamBtn.Text = "📷"
    resetCamBtn.TextColor3 = Color3.new(1, 1, 1)
    resetCamBtn.Font = Enum.Font.GothamBold
    resetCamBtn.TextSize = 24
    resetCamBtn.Parent = screenGui

    local resetCamCorner = Instance.new("UICorner")
    resetCamCorner.CornerRadius = UDim.new(0, 8)
    resetCamCorner.Parent = resetCamBtn

    resetCamBtn.MouseButton1Click:Connect(function()
        CameraController.resetCamera()
        SoundManager.playSelectSound()
    end)

    -- New Game button (hidden until game ends)
    local newGameBtn = Instance.new("TextButton")
    newGameBtn.Name = "NewGameButton"
    newGameBtn.Size = UDim2.new(0, 180, 0, 50)
    newGameBtn.Position = UDim2.new(0.5, -90, 0.5, 50)
    newGameBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
    newGameBtn.Text = "🎮 New Game"
    newGameBtn.TextColor3 = Color3.new(1, 1, 1)
    newGameBtn.Font = Enum.Font.FredokaOne
    newGameBtn.TextSize = 24
    newGameBtn.Visible = false -- Hidden until game ends
    newGameBtn.Parent = screenGui

    local newGameCorner = Instance.new("UICorner")
    newGameCorner.CornerRadius = UDim.new(0, 10)
    newGameCorner.Parent = newGameBtn

    newGameBtn.MouseButton1Click:Connect(function()
        -- Reset client state
        ClientState.currentGameId = nil
        ClientState.gameState = nil
        ClientState.selectedSquare = nil
        ClientState.validMoves = {}
        ClientState.playerColor = nil
        ClientState.isMyTurn = false
        ClientState.isAIvsAI = false
        -- Reset clock state
        ClientState.localTimeWhite = 600
        ClientState.localTimeBlack = 600
        ClientState.clockRunning = false

        -- Switch back to menu music
        MusicManager.playMenuMusic()

        -- Hide game HUD and show main menu
        screenGui.Enabled = false
        newGameBtn.Visible = false

        -- Show main menu
        local mainMenu = LocalPlayer.PlayerGui:FindFirstChild("MainMenu")
        if mainMenu then
            mainMenu.Enabled = true
        end
    end)

    -- Gesture menu
    local gestureFrame = Instance.new("Frame")
    gestureFrame.Name = "GestureMenu"
    gestureFrame.Size = UDim2.new(0, 300, 0, 50)
    gestureFrame.Position = UDim2.new(0.5, -150, 1, -70)
    gestureFrame.BackgroundTransparency = 1
    gestureFrame.Parent = screenGui

    local gestures = {"HappyMeow", "AngryHiss", "SlyGrin", "PawWave"}
    local gestureEmojis = {
        HappyMeow = ":3",
        AngryHiss = ">:(",
        SlyGrin = ";)",
        PawWave = "o/",
    }

    for i, gesture in ipairs(gestures) do
        local gestureBtn = Instance.new("TextButton")
        gestureBtn.Name = gesture
        gestureBtn.Size = UDim2.new(0, 60, 0, 40)
        gestureBtn.Position = UDim2.new(0, (i - 1) * 70, 0, 0)
        gestureBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
        gestureBtn.Text = gestureEmojis[gesture]
        gestureBtn.TextColor3 = Color3.new(1, 1, 1)
        gestureBtn.Font = Enum.Font.GothamBold
        gestureBtn.TextSize = 20
        gestureBtn.Parent = gestureFrame

        local gCorner = Instance.new("UICorner")
        gCorner.CornerRadius = UDim.new(0, 5)
        gCorner.Parent = gestureBtn

        gestureBtn.MouseButton1Click:Connect(function()
            if ClientState.currentGameId then
                SendGestureEvent:FireServer(ClientState.currentGameId, gesture)
            end
        end)
    end

    -- Create miniboard on the right side
    local miniboardContainer, updateMiniboard = createMiniboard(screenGui)

    return screenGui, updateMiniboard
end

-- Initialize client
local function initialize()
    print("🐱 [DEBUG] initialize() starting...")

    -- Hide player character SYNCHRONOUSLY (not async) to ensure it happens first
    print("🐱 [DEBUG] Waiting for character...")
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    print("🐱 [DEBUG] Got character:", character.Name)

    -- Move player to camera position instead of hiding
    -- This way, the camera following the character will be at the right spot
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if hrp then
        print("🐱 [DEBUG] Moving character to camera viewing position")
        -- Position character where we want camera to be, looking at board center
        hrp.CFrame = CFrame.new(Vector3.new(0, 60, -50), Vector3.new(0, 0, 0))
    end

    -- Make character invisible
    print("🐱 [DEBUG] Making character invisible...")
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            part.Transparency = 1
        elseif part:IsA("Accessory") then
            part:Destroy()
        end
    end

    -- Disable character movement
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end

    -- Camera setup handled by StarterPlayer properties and CameraController
    print("🐱 [DEBUG] Camera setup done via StarterPlayer")

    -- Remove spawn location if it exists
    print("🐱 [DEBUG] Looking for SpawnLocation...")
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        print("🐱 [DEBUG] Found SpawnLocation, destroying it")
        spawnLocation:Destroy()
    else
        print("🐱 [DEBUG] No SpawnLocation found")
    end

    -- Remove any default baseplate
    print("🐱 [DEBUG] Looking for Baseplate...")
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        print("🐱 [DEBUG] Found Baseplate, making invisible")
        baseplate.Transparency = 1 -- Make invisible instead of deleting
    end

    -- Set up camera
    CameraController.setupGameCamera()
    CameraController.enableCameraRotation()

    -- Apply theme from settings to board config
    print("🐱 [DEBUG] Applying color theme from settings...")
    SettingsManager.applyToBoardConfig(BoardConfig)

    print("🐱 [DEBUG] Creating board...")
    local boardFolder, squares = createBoard()
    print("🐱 [DEBUG] Board created! Creating menu...")
    local mainMenu = createMainMenu()
    print("🐱 [DEBUG] Menu created! Creating HUD...")
    local gameHUD, updateMiniboard = createGameHUD()
    print("🐱 [DEBUG] HUD created!")

    -- Create help button
    TutorialManager.createHelpButton()

    -- TEMPORARILY DISABLED for debugging
    -- Show tutorial after brief delay
    -- task.delay(2, function()
    --     TutorialManager.showInitialTutorial()
    -- end)
    print("🐱 [DEBUG] Tutorial disabled for testing")

    -- Handle game state updates
    GetGameStateFunction.OnClientInvoke = function(gameState)
        print("🐱 [DEBUG] Received game state from server!")
        ClientState.gameState = gameState
        ClientState.currentGameId = gameState.gameId

        -- Determine player color (white is always player1/first joiner)
        -- Determine player color (server should include this in state)
        -- For AI games, player is always white
        if not ClientState.playerColor then
            ClientState.playerColor = gameState.playerColor or Constants.Color.WHITE
        end

        -- Track if this is AI vs AI mode
        ClientState.isAIvsAI = gameState.isAIvsAI or false

        -- In AI vs AI mode, it's never your turn (you're just watching)
        if ClientState.isAIvsAI then
            ClientState.isMyTurn = false
        else
            ClientState.isMyTurn = gameState.currentTurn == ClientState.playerColor
        end

        -- Play sounds for opponent/AI moves and check warnings
        if gameState.gameState == Constants.GameState.IN_PROGRESS then
            -- Detect new moves by comparing moveHistory length
            local currentMoveCount = gameState.moveHistory and #gameState.moveHistory or 0
            if currentMoveCount > ClientState.lastMoveCount and ClientState.lastMoveCount > 0 then
                -- A new move was made - check if it was NOT our move
                local lastMove = gameState.moveHistory[currentMoveCount]
                if lastMove and lastMove.color ~= ClientState.playerColor then
                    if lastMove.captured then
                        SoundManager.playCaptureSound()
                    else
                        SoundManager.playMoveSound(lastMove.piece)
                    end
                end
            end
            ClientState.lastMoveCount = currentMoveCount

            -- Check warning sound (only on state transitions)
            if gameState.inCheck then
                local whiteInCheck = gameState.inCheck[Constants.Color.WHITE]
                local blackInCheck = gameState.inCheck[Constants.Color.BLACK]

                if (whiteInCheck and not ClientState.lastCheckWhite)
                    or (blackInCheck and not ClientState.lastCheckBlack) then
                    SoundManager.playCheckSound()
                end

                ClientState.lastCheckWhite = whiteInCheck or false
                ClientState.lastCheckBlack = blackInCheck or false
            end
        else
            -- Game ended - play victory/defeat SFX (music is handled below in HUD section)
            if ClientState.lastMoveCount > 0 then
                local won = false
                if gameState.gameState == Constants.GameState.WHITE_WIN then
                    won = ClientState.playerColor == Constants.Color.WHITE
                elseif gameState.gameState == Constants.GameState.BLACK_WIN then
                    won = ClientState.playerColor == Constants.Color.BLACK
                end

                if not ClientState.isAIvsAI then
                    if gameState.gameState == Constants.GameState.WHITE_WIN
                        or gameState.gameState == Constants.GameState.BLACK_WIN then
                        if won then
                            SoundManager.playVictorySound()
                        else
                            SoundManager.playDefeatSound()
                        end
                    end
                end

                -- Reset tracking for next game
                ClientState.lastMoveCount = 0
                ClientState.lastCheckWhite = false
                ClientState.lastCheckBlack = false
            end
        end

        -- Update HUD (with nil check)
        if not gameHUD then
            warn("🐱 [ERROR] gameHUD is nil!")
            return
        end
        gameHUD.Enabled = true

        -- Update color indicator
        local colorLabel = gameHUD:FindFirstChild("ColorLabel")
        if colorLabel then
            if gameState.isAIvsAI then
                -- AI vs AI mode - show spectator status
                colorLabel.Text = "👀 Spectating"
                colorLabel.BackgroundColor3 = Color3.fromRGB(80, 60, 100)
                colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            elseif ClientState.playerColor == Constants.Color.WHITE then
                colorLabel.Text = "You are: WHITE"
                colorLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
                colorLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
            else
                colorLabel.Text = "You are: BLACK"
                colorLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end

        -- Hide resign button in AI vs AI mode (you're just watching)
        local resignBtn = gameHUD:FindFirstChild("ResignButton")
        if resignBtn then
            resignBtn.Visible = not gameState.isAIvsAI
        end

        -- Update chess clock state from server
        if gameState.timeRemaining then
            ClientState.localTimeWhite = gameState.timeRemaining[Constants.Color.WHITE] or 600
            ClientState.localTimeBlack = gameState.timeRemaining[Constants.Color.BLACK] or 600
            ClientState.lastClockUpdate = tick()
            ClientState.clockRunning = gameState.gameState == Constants.GameState.IN_PROGRESS
        end

        local turnLabel = gameHUD:FindFirstChild("TurnLabel")
        if turnLabel then
            if gameState.gameState == Constants.GameState.IN_PROGRESS then
                -- Check if this is AI vs AI mode
                if gameState.isAIvsAI then
                    local turnName = gameState.currentTurn == Constants.Color.WHITE and "White" or "Black"
                    turnLabel.Text = "🤖 " .. turnName .. " AI thinking..."
                    turnLabel.TextColor3 = Color3.fromRGB(180, 100, 180) -- Purple for AI vs AI
                    local stroke = turnLabel:FindFirstChild("UIStroke")
                    if stroke then
                        stroke.Color = Color3.fromRGB(180, 100, 180)
                    end
                elseif ClientState.isMyTurn then
                    turnLabel.Text = "✨ YOUR TURN - Click your piece!"
                    turnLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green
                    local stroke = turnLabel:FindFirstChild("UIStroke")
                    if stroke then
                        stroke.Color = Color3.fromRGB(100, 255, 100)
                    end
                else
                    turnLabel.Text = "⏳ Opponent's Turn..."
                    turnLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Orange
                    local stroke = turnLabel:FindFirstChild("UIStroke")
                    if stroke then
                        stroke.Color = Color3.fromRGB(255, 200, 100)
                    end
                end
            elseif gameState.gameState == Constants.GameState.WHITE_WIN then
                local won = ClientState.playerColor == Constants.Color.WHITE
                turnLabel.Text = won and "🎉 YOU WIN! 🎉" or "😿 You Lose..."
                turnLabel.TextColor3 = won and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(200, 100, 100)
                -- Play victory/defeat music
                if not ClientState.isAIvsAI then
                    if won then MusicManager.playVictoryMusic() else MusicManager.playDefeatMusic() end
                end
                -- Show New Game button
                local newGameBtn = gameHUD:FindFirstChild("NewGameButton")
                if newGameBtn then newGameBtn.Visible = true end
            elseif gameState.gameState == Constants.GameState.BLACK_WIN then
                local won = ClientState.playerColor == Constants.Color.BLACK
                turnLabel.Text = won and "🎉 YOU WIN! 🎉" or "😿 You Lose..."
                turnLabel.TextColor3 = won and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(200, 100, 100)
                -- Play victory/defeat music
                if not ClientState.isAIvsAI then
                    if won then MusicManager.playVictoryMusic() else MusicManager.playDefeatMusic() end
                end
                -- Show New Game button
                local newGameBtn = gameHUD:FindFirstChild("NewGameButton")
                if newGameBtn then newGameBtn.Visible = true end
            elseif gameState.gameState == Constants.GameState.STALEMATE then
                turnLabel.Text = "😺 Stalemate - Draw!"
                turnLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                MusicManager.playMenuMusic()
                -- Show New Game button
                local newGameBtn = gameHUD:FindFirstChild("NewGameButton")
                if newGameBtn then newGameBtn.Visible = true end
            elseif gameState.gameState == Constants.GameState.DRAW then
                turnLabel.Text = "😺 Draw!"
                turnLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                MusicManager.playMenuMusic()
                -- Show New Game button
                local newGameBtn = gameHUD:FindFirstChild("NewGameButton")
                if newGameBtn then newGameBtn.Visible = true end
            end
        end

        -- Skip animations on initial game setup
        local skipAnimation = ClientState.gameState == nil
        updateBoardVisuals(boardFolder, squares, gameState, skipAnimation)

        -- Update miniboard
        if updateMiniboard then
            updateMiniboard(gameState)
        end
    end

    -- Handle gesture received
    SendGestureEvent.OnClientEvent:Connect(function(gesture)
        -- Show gesture notification
        print("Opponent gesture:", gesture)
        -- TODO: Show visual gesture notification
    end)

    -- Handle clicks
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Skip fight animation if one is active
            if BattleAnimations.isFightActive() then
                print("🐱 [CLICK] Skipping fight animation!")
                BattleAnimations.skipFight()
                return
            end

            print("🐱 [CLICK] Mouse clicked at screen position: " .. input.Position.X .. "," .. input.Position.Y)

            local camera = workspace.CurrentCamera
            local mousePos = UserInputService:GetMouseLocation()
            local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)

            print("🐱 [CLICK] Ray origin: " .. tostring(ray.Origin))
            print("🐱 [CLICK] Ray direction: " .. tostring(ray.Direction))

            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            raycastParams.FilterDescendantsInstances = {}

            -- First, try to hit ANYTHING to see what's in the way
            local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

            if result then
                print("🐱 [CLICK] Hit something: " .. result.Instance.Name .. " in " .. (result.Instance.Parent and result.Instance.Parent.Name or "nil"))
                print("🐱 [CLICK] Hit position: " .. tostring(result.Position))
                print("🐱 [CLICK] Distance: " .. (result.Position - ray.Origin).Magnitude)

                -- Check if it's a board square
                local row = result.Instance:GetAttribute("Row")
                local col = result.Instance:GetAttribute("Col")

                if row and col then
                    print("🐱 [CLICK] ✓ Found board square with Row=" .. row .. ", Col=" .. col)
                    onSquareClicked(tonumber(row), tonumber(col), boardFolder, squares)
                else
                    print("🐱 [CLICK] ✗ Not a board square (no Row/Col attributes)")
                    -- Try to find the board square underneath
                    local ignoreList = {result.Instance}
                    local current = result.Instance
                    while current and current ~= workspace do
                        table.insert(ignoreList, current)
                        current = current.Parent
                    end

                    local params2 = RaycastParams.new()
                    params2.FilterType = Enum.RaycastFilterType.Exclude
                    params2.FilterDescendantsInstances = ignoreList

                    local result2 = workspace:Raycast(ray.Origin, ray.Direction * 1000, params2)
                    if result2 then
                        local row2 = result2.Instance:GetAttribute("Row")
                        local col2 = result2.Instance:GetAttribute("Col")
                        print("🐱 [CLICK] Second raycast hit: " .. result2.Instance.Name)
                        if row2 and col2 then
                            print("🐱 [CLICK] ✓ Found board square underneath: Row=" .. row2 .. ", Col=" .. col2)
                            onSquareClicked(tonumber(row2), tonumber(col2), boardFolder, squares)
                        end
                    end
                end
            else
                print("🐱 [CLICK] ✗ Raycast hit nothing!")
            end
        end
    end)

    -- Handle hover effects using click zones (same as click detection)
    local RunService = game:GetService("RunService")

    -- Cache for hover valid moves (recompute only when hovered square changes)
    local hoverCacheRow = nil
    local hoverCacheCol = nil
    local hoverCacheHasValidMoves = false

    RunService.RenderStepped:Connect(function()
        if not ClientState.isMyTurn or not ClientState.gameState then
            -- Clear hover effect
            if ClientState.hoverEffect then
                ClientState.hoverEffect:Destroy()
                ClientState.hoverEffect = nil
            end
            -- Clear cursor projection
            if ClientState.cursorProjection then
                ClientState.cursorProjection:Destroy()
                ClientState.cursorProjection = nil
            end
            -- Stop purring
            if ClientState.currentPurrSound then
                SoundManager.stopPurr(ClientState.currentPurrSound)
                ClientState.currentPurrSound = nil
            end
            ClientState.hoveredSquare = nil
            hoverCacheRow = nil
            hoverCacheCol = nil
            local mouse = LocalPlayer:GetMouse()
            mouse.Icon = ""
            return
        end

        local mouse = LocalPlayer:GetMouse()
        local camera = workspace.CurrentCamera
        local mousePos = UserInputService:GetMouseLocation()

        local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)

        -- Raycast to hit ANYTHING (including click zones)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {}

        local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

        local row, col = nil, nil

        if result and result.Instance then
            -- Check if we hit a click zone or board square
            row = result.Instance:GetAttribute("Row")
            col = result.Instance:GetAttribute("Col")

            -- If we didn't hit a square, try again ignoring what we hit (probably a piece)
            if not row or not col then
                local ignoreList = {result.Instance}
                local current = result.Instance
                while current and current ~= workspace do
                    table.insert(ignoreList, current)
                    current = current.Parent
                end

                local params2 = RaycastParams.new()
                params2.FilterType = Enum.RaycastFilterType.Exclude
                params2.FilterDescendantsInstances = ignoreList

                local result2 = workspace:Raycast(ray.Origin, ray.Direction * 1000, params2)
                if result2 then
                    row = result2.Instance:GetAttribute("Row")
                    col = result2.Instance:GetAttribute("Col")
                end
            end
        end

        -- Now process the row/col we found (if any)
        if row and col then
            row = tonumber(row)
            col = tonumber(col)

            -- Update cursor projection to show where raycast is hitting
            local square = squares[row][col]
            if not ClientState.cursorProjection or
               ClientState.cursorProjection.Parent == nil or
               ClientState.hoveredSquare == nil or
               ClientState.hoveredSquare.row ~= row or
               ClientState.hoveredSquare.col ~= col then

                -- Clear old projection
                if ClientState.cursorProjection then
                    ClientState.cursorProjection:Destroy()
                end

                -- Create subtle cursor projection on the square
                local projection = Instance.new("Part")
                projection.Name = "CursorProjection"
                projection.Size = Vector3.new(BoardConfig.squareSize - 1, 0.1, BoardConfig.squareSize - 1)
                projection.Position = square.Position + Vector3.new(0, 0.4, 0) -- Slightly above square
                projection.Anchored = true
                projection.CanCollide = false
                projection.Transparency = 0.5
                projection.Color = Color3.fromRGB(0, 255, 255) -- Cyan - stands out from everything!
                projection.Material = Enum.Material.Neon
                projection.Parent = boardFolder
                ClientState.cursorProjection = projection
            end

            -- Update hovered square for cursor projection
            ClientState.hoveredSquare = {row = row, col = col}

            -- Check if this square has our piece
            local pieceData = getPieceAt(ClientState.gameState, row, col)
            local isOurPiece = pieceData and pieceData.color == ClientState.playerColor

            -- Determine if we should show PointingHand cursor:
            -- 1) Own piece with valid moves
            -- 2) Valid move target when a piece is selected
            local showPointingHand = false

            if isOurPiece then
                -- Cache: only recompute valid moves when hovered square changes
                if hoverCacheRow ~= row or hoverCacheCol ~= col then
                    hoverCacheRow = row
                    hoverCacheCol = col
                    local engine = Shared.ChessEngine.new()
                    engine:deserialize(ClientState.gameState)
                    local moves = engine:getValidMoves(row, col)
                    hoverCacheHasValidMoves = #moves > 0
                end
                showPointingHand = hoverCacheHasValidMoves
            elseif ClientState.selectedSquare then
                -- Check if this square is a valid move target for the selected piece
                for _, move in ipairs(ClientState.validMoves) do
                    if move.row == row and move.col == col then
                        showPointingHand = true
                        break
                    end
                end
                -- Reset hover cache since we're not on our own piece
                hoverCacheRow = nil
                hoverCacheCol = nil
            else
                hoverCacheRow = nil
                hoverCacheCol = nil
            end

            if showPointingHand then
                -- Clear old hover effect
                if ClientState.hoverEffect then
                    ClientState.hoverEffect:Destroy()
                end

                -- Add new hover effect to the ground square
                local hoverGlow = Instance.new("SurfaceLight")
                hoverGlow.Name = "HoverGlow"
                hoverGlow.Color = Color3.fromRGB(255, 255, 150)
                hoverGlow.Brightness = 2
                hoverGlow.Range = 10
                hoverGlow.Face = Enum.NormalId.Top
                hoverGlow.Parent = square
                ClientState.hoverEffect = hoverGlow

                -- Change mouse icon
                mouse.Icon = "rbxasset://SystemCursors/PointingHand"

                -- Start purring if hovering over own piece with valid moves
                if isOurPiece and not ClientState.currentPurrSound then
                    ClientState.currentPurrSound = SoundManager.startPurr()
                end
            else
                -- Hovering over a square but not clickable - clear hover glow but keep cursor projection
                if ClientState.hoverEffect then
                    ClientState.hoverEffect:Destroy()
                    ClientState.hoverEffect = nil
                end
                mouse.Icon = ""

                -- Stop purring when not on own moveable piece
                if ClientState.currentPurrSound then
                    SoundManager.stopPurr(ClientState.currentPurrSound)
                    ClientState.currentPurrSound = nil
                end
            end
        else
            -- Not hovering over any square - clear everything
            ClientState.hoveredSquare = nil
            hoverCacheRow = nil
            hoverCacheCol = nil
            if ClientState.hoverEffect then
                ClientState.hoverEffect:Destroy()
                ClientState.hoverEffect = nil
            end
            if ClientState.cursorProjection then
                ClientState.cursorProjection:Destroy()
                ClientState.cursorProjection = nil
            end
            if ClientState.currentPurrSound then
                SoundManager.stopPurr(ClientState.currentPurrSound)
                ClientState.currentPurrSound = nil
            end
            mouse.Icon = ""
        end
    end)

    -- Chess clock update loop (runs every frame for smooth countdown)
    RunService.Heartbeat:Connect(function(deltaTime)
        if not ClientState.clockRunning or not ClientState.gameState then
            return
        end

        -- Only tick down if game is in progress
        if ClientState.gameState.gameState ~= Constants.GameState.IN_PROGRESS then
            ClientState.clockRunning = false
            return
        end

        -- Tick down the active player's clock
        local currentTurn = ClientState.gameState.currentTurn
        if currentTurn == Constants.Color.WHITE then
            ClientState.localTimeWhite = math.max(0, ClientState.localTimeWhite - deltaTime)
        else
            ClientState.localTimeBlack = math.max(0, ClientState.localTimeBlack - deltaTime)
        end

        -- Update clock display
        local clockContainer = gameHUD:FindFirstChild("ChessClockContainer")
        if clockContainer then
            local whiteClockFrame = clockContainer:FindFirstChild("WhiteClockFrame")
            local blackClockFrame = clockContainer:FindFirstChild("BlackClockFrame")

            if whiteClockFrame and blackClockFrame then
                local whiteTimeLabel = whiteClockFrame:FindFirstChild("TimeLabel")
                local blackTimeLabel = blackClockFrame:FindFirstChild("TimeLabel")

                if whiteTimeLabel then
                    whiteTimeLabel.Text = formatTime(ClientState.localTimeWhite)
                    -- Flash red if low on time (< 30 seconds)
                    if ClientState.localTimeWhite <= 30 then
                        -- Pulse effect for urgency
                        local pulse = math.sin(tick() * 4) * 0.5 + 0.5
                        whiteTimeLabel.TextColor3 = Color3.fromRGB(255, 100 + pulse * 50, 100)
                    else
                        whiteTimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    end
                end

                if blackTimeLabel then
                    blackTimeLabel.Text = formatTime(ClientState.localTimeBlack)
                    if ClientState.localTimeBlack <= 30 then
                        local pulse = math.sin(tick() * 4) * 0.5 + 0.5
                        blackTimeLabel.TextColor3 = Color3.fromRGB(255, 100 + pulse * 50, 100)
                    else
                        blackTimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    end
                end

                -- Highlight active player's clock
                local isWhiteTurn = currentTurn == Constants.Color.WHITE
                if isWhiteTurn then
                    whiteClockFrame.BackgroundColor3 = Color3.fromRGB(80, 120, 80) -- Green highlight
                    blackClockFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)  -- Dim
                else
                    blackClockFrame.BackgroundColor3 = Color3.fromRGB(80, 120, 80) -- Green highlight
                    whiteClockFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 55)  -- Dim
                end
            end
        end
    end)

    print("🐱 Claws & Paws client initialized! Meow!")
end

print("🐱 [DEBUG] About to call initialize()...")
initialize()
print("🐱 [DEBUG] initialize() returned!")
