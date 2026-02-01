--[[
    Claws & Paws - Client Entry Point
    Handles UI, input, and local game rendering
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = require(ReplicatedStorage.Shared)
local Constants = Shared.Constants
if Constants.DEBUG then print("🐱 [DEBUG] Client script starting") end
local Logger = require(script.Logger)
local MusicManager = require(script.MusicManager)
local ParticleEffects = require(script.ParticleEffects)
local SoundManager = require(script.SoundManager)
local BattleAnimations = require(script.BattleAnimations)
local AssetLoader = require(script.AssetLoader)
local TutorialManager = require(script.TutorialManager)
local CameraController = require(script.CameraController)
local SettingsManager = require(script.SettingsManager)
local CampaignUI = require(script.CampaignUI)
if Constants.DEBUG then print("🐱 [DEBUG] All modules loaded") end

Logger.init()
SettingsManager.init()

local LocalPlayer = Players.LocalPlayer

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestMatchEvent = Remotes:WaitForChild("RequestMatch")
local CancelMatchEvent = Remotes:WaitForChild("CancelMatch")
local MakeMoveEvent = Remotes:WaitForChild("MakeMove")
local ResignEvent = Remotes:WaitForChild("Resign")
local SendGestureEvent = Remotes:WaitForChild("SendGesture")
local RequestAIGameEvent = Remotes:WaitForChild("RequestAIGame")
local RequestAIvsAIGameEvent = Remotes:WaitForChild("RequestAIvsAIGame")
local GetGameStateFunction = Remotes:WaitForChild("GetGameState")
if Constants.DEBUG then print("🐱 [DEBUG] All remotes loaded") end

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
    currentBoss = nil,       -- Current campaign boss (nil when not in campaign)
    lastLowTimeWarning = 0,  -- Last time low-time warning played (tick)
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
    if Constants.DEBUG then print(string.format("🐱 [ANIM] Starting animation: [%d,%d] → [%d,%d]", fromRow, fromCol, toRow, toCol)) end

    -- Mark animation as in progress (with safety timeout to prevent stuck board)
    ClientState.animationInProgress = true
    if Constants.DEBUG then print("🐱 [ANIM] Set animationInProgress = true") end

    task.delay(5, function()
        if ClientState.animationInProgress then
            warn("🐱 [ANIM] Safety timeout: clearing stuck animationInProgress flag")
            ClientState.animationInProgress = false
        end
    end)

    -- Find the moving piece
    local pieceName = string.format("Piece_%d_%d", fromRow, fromCol)
    local piece = boardFolder:FindFirstChild(pieceName)

    if not piece then
        if Constants.DEBUG then print("🐱 [ANIM] ERROR: Piece not found: " .. pieceName) end
        ClientState.animationInProgress = false
        if onComplete then onComplete() end
        return
    end

    if Constants.DEBUG then print("🐱 [ANIM] Found piece to animate: " .. pieceName) end

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
        if Constants.DEBUG then print("🐱 [ANIM] Animation complete, cleaning up and setting animationInProgress = false") end

        -- CRITICAL: Destroy the animated piece BEFORE calling onComplete
        -- This prevents duplicate pieces (old animated piece + new piece from updateBoardVisuals)
        if piece and piece.Parent then
            if Constants.DEBUG then print(string.format("🐱 [ANIM] Destroying animated piece: %s", pieceName)) end
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
            if Constants.DEBUG then print(string.format("🐱 [ANIM] Found target piece for fight: %s", targetPieceName)) end
            if targetPiece:IsA("Model") then
                targetPart = targetPiece.PrimaryPart or targetPiece:FindFirstChildWhichIsA("BasePart")
            else
                targetPart = targetPiece
            end
        end

        -- Show "Click to skip" hint
        local skipHint = Instance.new("TextLabel")
        skipHint.Name = "SkipHint"
        skipHint.Size = UDim2.new(0.5, 0, 0, 28)
        skipHint.AnchorPoint = Vector2.new(0.5, 0)
        skipHint.Position = UDim2.new(0.5, 0, 0.85, 0)
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

    -- Apply showCoordinates setting
    if SettingsManager.get("showCoordinates") == false then
        for _, child in ipairs(coordFolder:GetChildren()) do
            child.Transparency = 1
        end
        for _, child in ipairs(boardFolder:GetChildren()) do
            if child:IsA("BillboardGui") then
                child.Enabled = false
            end
        end
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
    if Constants.DEBUG then print("🐱 [UPDATE] ========== updateBoardVisuals called ==========") end

    -- CRITICAL: Don't update board while animation is in progress!
    -- This would destroy the piece being animated
    if ClientState.animationInProgress then
        if Constants.DEBUG then print("🐱 [UPDATE] ⚠️ SKIPPING update - animation in progress!") end
        return
    end

    -- Clear existing pieces and effects
    local destroyedCount = 0
    for _, child in ipairs(boardFolder:GetChildren()) do
        if child.Name:sub(1, 5) == "Piece" then
            if Constants.DEBUG then print("🐱 [UPDATE] Destroying piece: " .. child.Name) end
            child:Destroy()
            destroyedCount = destroyedCount + 1
        end
    end
    if Constants.DEBUG then print("🐱 [UPDATE] Destroyed " .. destroyedCount .. " existing pieces") end

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
    if Constants.DEBUG then print(string.format("🐱 [UPDATE] Received %d pieces in flat array format:", #gameState.pieces)) end
    for _, piece in ipairs(gameState.pieces) do
        if Constants.DEBUG then print(string.format("🐱 [UPDATE]   [%d,%d]: type=%d color=%d", piece.row, piece.col, piece.type, piece.color)) end
    end

    -- Place pieces from flat array
    for _, pieceData in ipairs(gameState.pieces) do
        local row, col = pieceData.row, pieceData.col
        local pieceModel = createPieceModel(pieceData.type, pieceData.color)
        if Constants.DEBUG then print("🐱 [DEBUG] Created piece at [" .. row .. "," .. col .. "]: type=" .. pieceData.type .. " color=" .. pieceData.color) end
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
                if Constants.DEBUG then print("🐱 [DEBUG] Positioned piece at " .. tostring(targetPos)) end

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

    -- Highlight last move (from and to squares) with soft pink
    if gameState and gameState.lastMove then
        local fromR, fromC = gameState.lastMove.fromRow, gameState.lastMove.fromCol
        local toR, toC = gameState.lastMove.toRow, gameState.lastMove.toCol
        if squares[fromR] and squares[fromR][fromC] then
            squares[fromR][fromC].Color = BoardConfig.lastMoveColor
        end
        if squares[toR] and squares[toR][toC] then
            squares[toR][toC].Color = BoardConfig.lastMoveColor
        end
    end

    -- Highlight king square in red if in check
    if gameState and gameState.inCheck then
        for _, piece in ipairs(gameState.pieces or {}) do
            if piece.type == Constants.PieceType.KING then
                local isInCheck = gameState.inCheck[piece.color]
                if isInCheck and squares[piece.row] and squares[piece.row][piece.col] then
                    local sq = squares[piece.row][piece.col]
                    sq.Color = BoardConfig.checkColor
                    -- Add danger glow
                    local dangerLight = Instance.new("SurfaceLight")
                    dangerLight.Name = "CheckGlow"
                    dangerLight.Color = Color3.fromRGB(255, 50, 0)
                    dangerLight.Brightness = 3
                    dangerLight.Range = 15
                    dangerLight.Face = Enum.NormalId.Top
                    dangerLight.Parent = sq
                end
            end
        end
    end

    -- Highlight selected square with sparkles!
    if ClientState.selectedSquare then
        local sq = squares[ClientState.selectedSquare.row][ClientState.selectedSquare.col]
        sq.Color = BoardConfig.highlightColor
        ParticleEffects.createSparkles(sq)
    end

    -- Highlight valid moves with glow (respects showValidMoves setting)
    if SettingsManager.get("showValidMoves") ~= false then
        for _, move in ipairs(ClientState.validMoves) do
            local sq = squares[move.row][move.col]
            if sq then
                sq.Color = BoardConfig.validMoveColor
                ParticleEffects.highlightSquare(sq, Color3.fromRGB(144, 238, 144))
            end
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

        if Constants.DEBUG then print("🐱 [DEBUG] Have " .. #ClientState.validMoves .. " valid moves, checking click at [" .. row .. "," .. col .. "]") end
        if Constants.DEBUG then print("🐱 [DEBUG] Click types: row=" .. type(row) .. " col=" .. type(col)) end
        for i, move in ipairs(ClientState.validMoves) do
            if move and move.row and move.col then
                if Constants.DEBUG then print("🐱 [DEBUG] Comparing with move " .. i .. ": [" .. move.row .. "," .. move.col .. "] (types: " .. type(move.row) .. "," .. type(move.col) .. ") match=" .. tostring(move.row == row and move.col == col)) end
            end
        end
        if Constants.DEBUG then print("🐱 [DEBUG] Result: Valid move: " .. tostring(isValidMove)) end
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
                    -- Play move sound (use movingPieceType, not pieceData which is the target square)
                    SoundManager.playMoveSound(movingPieceType)
                end

                if isPromotion then
                    -- Show promotion popup, then send move with chosen piece
                    showPromotionPopup(function(chosenType)
                        SoundManager.playPromotionSound()
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
            if Constants.DEBUG then print("🐱 [DEBUG] Selected piece, found " .. #ClientState.validMoves .. " valid moves") end
            if ClientState.validMoves and #ClientState.validMoves > 0 then
                for i, move in ipairs(ClientState.validMoves) do
                    if move and move.row and move.col then
                        if Constants.DEBUG then print("🐱 [DEBUG]   Move " .. i .. ": [" .. move.row .. "," .. move.col .. "]") end
                    else
                        if Constants.DEBUG then print("🐱 [DEBUG]   Move " .. i .. ": INVALID MOVE STRUCTURE") end
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

    -- Highlight valid moves (respects showValidMoves setting)
    if SettingsManager.get("showValidMoves") ~= false then
        for _, move in ipairs(ClientState.validMoves) do
            if move and move.row and move.col then
                local sq = squares[move.row][move.col]
                sq.Color = BoardConfig.validMoveColor
                ParticleEffects.highlightSquare(sq)
            end
        end
    end
end

-- Create AI vs AI difficulty selector popup
local function createAIvsAIPopup(mainMenuFrame)
    local popup = Instance.new("Frame")
    popup.Name = "AIvsAIPopup"
    popup.Size = UDim2.new(0.9, 0, 0, 280)
    popup.AnchorPoint = Vector2.new(0.5, 0.5)
    popup.Position = UDim2.new(0.5, 0, 0.5, 0)
    popup.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    popup.BorderSizePixel = 0
    popup.Visible = false
    popup.Parent = mainMenuFrame.Parent

    local popupConstraint = Instance.new("UISizeConstraint")
    popupConstraint.MaxSize = Vector2.new(320, 280)
    popupConstraint.MinSize = Vector2.new(240, 260)
    popupConstraint.Parent = popup

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = popup

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 100)
    stroke.Thickness = 2
    stroke.Parent = popup

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 36)
    title.BackgroundTransparency = 1
    title.Text = "Watch AI vs AI"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 22
    title.TextScaled = true
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
    whiteLabel.Size = UDim2.new(0.9, 0, 0, 22)
    whiteLabel.AnchorPoint = Vector2.new(0.5, 0)
    whiteLabel.Position = UDim2.new(0.5, 0, 0, 42)
    whiteLabel.BackgroundTransparency = 1
    whiteLabel.Text = "White AI:"
    whiteLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    whiteLabel.Font = Enum.Font.GothamBold
    whiteLabel.TextSize = 15
    whiteLabel.TextXAlignment = Enum.TextXAlignment.Left
    whiteLabel.Parent = popup

    local whiteButtons = {}
    for i, diff in ipairs(difficulties) do
        local btn = Instance.new("TextButton")
        btn.Name = "White_" .. diff.mode
        btn.Size = UDim2.new(0.3, -4, 0, 30)
        btn.Position = UDim2.new((i - 1) * 0.33 + 0.02, 0, 0, 68)
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
    blackLabel.Size = UDim2.new(0.9, 0, 0, 22)
    blackLabel.AnchorPoint = Vector2.new(0.5, 0)
    blackLabel.Position = UDim2.new(0.5, 0, 0, 108)
    blackLabel.BackgroundTransparency = 1
    blackLabel.Text = "Black AI:"
    blackLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    blackLabel.Font = Enum.Font.GothamBold
    blackLabel.TextSize = 15
    blackLabel.TextXAlignment = Enum.TextXAlignment.Left
    blackLabel.Parent = popup

    local blackButtons = {}
    for i, diff in ipairs(difficulties) do
        local btn = Instance.new("TextButton")
        btn.Name = "Black_" .. diff.mode
        btn.Size = UDim2.new(0.3, -4, 0, 30)
        btn.Position = UDim2.new((i - 1) * 0.33 + 0.02, 0, 0, 134)
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
    startBtn.Size = UDim2.new(0.7, 0, 0, 38)
    startBtn.AnchorPoint = Vector2.new(0.5, 0)
    startBtn.Position = UDim2.new(0.5, 0, 0, 178)
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
        ClientState.currentBoss = nil -- Not a campaign game
        if Constants.DEBUG then print(string.format("🐱 [CLIENT] Starting AI vs AI: White=%s, Black=%s", selectedWhite, selectedBlack)) end
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
    cancelBtn.Size = UDim2.new(0.35, 0, 0, 28)
    cancelBtn.AnchorPoint = Vector2.new(0.5, 0)
    cancelBtn.Position = UDim2.new(0.5, 0, 0, 224)
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
    frame.Size = UDim2.new(0.85, 0, 0.85, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = screenGui

    -- Constrain to reasonable size on desktop, allow smaller on mobile
    local menuSizeConstraint = Instance.new("UISizeConstraint")
    menuSizeConstraint.MaxSize = Vector2.new(320, 650)
    menuSizeConstraint.MinSize = Vector2.new(220, 350)
    menuSizeConstraint.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "Claws & Paws"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 32
    title.Parent = frame

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 22)
    subtitle.Position = UDim2.new(0, 0, 0, 46)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Cat Chess Battle!"
    subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 14
    subtitle.Parent = frame

    -- Scrollable button area
    local menuScroll = Instance.new("ScrollingFrame")
    menuScroll.Name = "MenuScroll"
    menuScroll.Size = UDim2.new(1, -20, 1, -78)
    menuScroll.Position = UDim2.new(0, 10, 0, 72)
    menuScroll.BackgroundTransparency = 1
    menuScroll.BorderSizePixel = 0
    menuScroll.ScrollBarThickness = 4
    menuScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    menuScroll.Parent = frame

    local menuLayout = Instance.new("UIListLayout")
    menuLayout.Padding = UDim.new(0, 8)
    menuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
    menuLayout.Parent = menuScroll

    menuLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        menuScroll.CanvasSize = UDim2.new(0, 0, 0, menuLayout.AbsoluteContentSize.Y + 10)
    end)

    -- Helper to create a menu button
    local menuOrder = 1
    local function makeMenuButton(text, color, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.95, 0, 0, 38)
        button.BackgroundColor3 = color
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 16
        button.LayoutOrder = menuOrder
        button.Parent = menuScroll

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = button

        button.MouseButton1Click:Connect(callback)
        menuOrder = menuOrder + 1
        return button
    end

    -- Searching for opponent panel (hidden until multiplayer mode selected)
    local pendingMatchMode = nil

    local searchingPanel = Instance.new("Frame")
    searchingPanel.Name = "SearchingLabel"  -- Keep name for existing hide logic
    searchingPanel.Size = UDim2.new(0.8, 0, 0, 100)
    searchingPanel.AnchorPoint = Vector2.new(0.5, 0.5)
    searchingPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
    searchingPanel.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
    searchingPanel.BackgroundTransparency = 0.2
    searchingPanel.Visible = false
    searchingPanel.ZIndex = 5
    searchingPanel.Parent = screenGui

    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 12)
    searchCorner.Parent = searchingPanel

    local searchConstraint = Instance.new("UISizeConstraint")
    searchConstraint.MaxSize = Vector2.new(360, 100)
    searchConstraint.Parent = searchingPanel

    local searchingLabel = Instance.new("TextLabel")
    searchingLabel.Name = "SearchText"
    searchingLabel.Size = UDim2.new(1, 0, 0, 45)
    searchingLabel.BackgroundTransparency = 1
    searchingLabel.Text = "Searching for opponent..."
    searchingLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    searchingLabel.Font = Enum.Font.FredokaOne
    searchingLabel.TextSize = 22
    searchingLabel.Parent = searchingPanel

    local cancelSearchBtn = Instance.new("TextButton")
    cancelSearchBtn.Name = "CancelSearch"
    cancelSearchBtn.Size = UDim2.new(0.5, 0, 0, 36)
    cancelSearchBtn.AnchorPoint = Vector2.new(0.5, 0)
    cancelSearchBtn.Position = UDim2.new(0.5, 0, 0, 50)
    cancelSearchBtn.BackgroundColor3 = Color3.fromRGB(160, 70, 70)
    cancelSearchBtn.Text = "Cancel"
    cancelSearchBtn.TextColor3 = Color3.new(1, 1, 1)
    cancelSearchBtn.Font = Enum.Font.GothamBold
    cancelSearchBtn.TextSize = 16
    cancelSearchBtn.Parent = searchingPanel

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 8)
    cancelCorner.Parent = cancelSearchBtn

    cancelSearchBtn.MouseButton1Click:Connect(function()
        SoundManager.playSelectSound()
        if pendingMatchMode then
            CancelMatchEvent:FireServer(pendingMatchMode)
            pendingMatchMode = nil
        end
        searchingPanel.Visible = false
        frame.Visible = true
        MusicManager.playMenuMusic()
    end)

    -- Game mode buttons
    local buttons = {
        {text = "Play vs AI (Easy)", mode = Constants.GameMode.AI_EASY},
        {text = "Play vs AI (Medium)", mode = Constants.GameMode.AI_MEDIUM},
        {text = "Play vs AI (Hard)", mode = Constants.GameMode.AI_HARD},
        {text = "Play Casual", mode = Constants.GameMode.CASUAL},
        {text = "Play Ranked", mode = Constants.GameMode.RANKED},
    }

    for _, btnData in ipairs(buttons) do
        makeMenuButton(btnData.text, Color3.fromRGB(80, 120, 200), function()
            SoundManager.playSelectSound()
            ClientState.currentBoss = nil
            if btnData.mode:sub(1, 2) == "AI" then
                RequestAIGameEvent:FireServer(btnData.mode)
            else
                RequestMatchEvent:FireServer(btnData.mode)
                pendingMatchMode = btnData.mode
                searchingPanel.Visible = true
            end
            MusicManager.playForGameMode(btnData.mode)
            frame.Visible = false
        end)
    end

    -- Campaign button (special gold styling)
    local campaignBtn = makeMenuButton("Boss Gauntlet", Color3.fromRGB(200, 150, 50), function()
        SoundManager.playSelectSound()
        frame.Visible = false
        CampaignUI.createCampaignMenu(
            function(boss)
                local modeMap = {
                    AI_EASY = Constants.GameMode.AI_EASY,
                    AI_MEDIUM = Constants.GameMode.AI_MEDIUM,
                    AI_HARD = Constants.GameMode.AI_HARD,
                    AI_EXPERT = Constants.GameMode.AI_EXPERT,
                    AI_NIGHTMARE = Constants.GameMode.AI_NIGHTMARE,
                }
                local gameMode = modeMap[boss.aiDifficulty] or Constants.GameMode.AI_MEDIUM
                RequestAIGameEvent:FireServer(gameMode)
                MusicManager.playForGameMode(gameMode)
                ClientState.currentBoss = boss
            end,
            function()
                frame.Visible = true
            end
        )
    end)
    campaignBtn.Font = Enum.Font.FredokaOne
    local campaignStroke = Instance.new("UIStroke")
    campaignStroke.Color = Color3.fromRGB(255, 215, 0)
    campaignStroke.Thickness = 2
    campaignStroke.Parent = campaignBtn

    -- Watch AI vs AI button
    makeMenuButton("Watch AI vs AI", Color3.fromRGB(180, 100, 180), function()
        SoundManager.playSelectSound()
        local aiVsAiPopup = createAIvsAIPopup(frame)
        aiVsAiPopup.Visible = true
    end)

    -- Settings button
    makeMenuButton("Settings", Color3.fromRGB(100, 100, 100), function()
        SoundManager.playSelectSound()
        SettingsManager.createSettingsUI(function()
            SettingsManager.applyToBoardConfig(BoardConfig)
        end)
    end)

    -- How to Play button
    makeMenuButton("How to Play", Color3.fromRGB(100, 100, 100), function()
        SoundManager.playSelectSound()
        TutorialManager.createHelpOverlay()
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
    container.Position = UDim2.new(1, -200, 0, 130)
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

    -- Turn indicator (responsive, centered)
    local turnLabel = Instance.new("TextLabel")
    turnLabel.Name = "TurnLabel"
    turnLabel.Size = UDim2.new(0.8, 0, 0, 50)
    turnLabel.AnchorPoint = Vector2.new(0.5, 0)
    turnLabel.Position = UDim2.new(0.5, 0, 0, 15)
    turnLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    turnLabel.BackgroundTransparency = 0.2
    turnLabel.Text = "Waiting for game..."
    turnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    turnLabel.Font = Enum.Font.FredokaOne
    turnLabel.TextSize = 24
    turnLabel.TextScaled = true
    turnLabel.Parent = screenGui

    local turnSizeConstraint = Instance.new("UISizeConstraint")
    turnSizeConstraint.MaxSize = Vector2.new(400, 50)
    turnSizeConstraint.Parent = turnLabel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = turnLabel

    local turnPadding = Instance.new("UIPadding")
    turnPadding.PaddingLeft = UDim.new(0, 10)
    turnPadding.PaddingRight = UDim.new(0, 10)
    turnPadding.Parent = turnLabel

    -- Add stroke for better visibility
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 100)
    stroke.Thickness = 2
    stroke.Parent = turnLabel

    -- Check warning label (pulsing "CHECK!" text)
    local checkWarning = Instance.new("TextLabel")
    checkWarning.Name = "CheckWarning"
    checkWarning.Size = UDim2.new(0.5, 0, 0, 36)
    checkWarning.AnchorPoint = Vector2.new(0.5, 0)
    checkWarning.Position = UDim2.new(0.5, 0, 0, 68)
    checkWarning.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    checkWarning.BackgroundTransparency = 0.1
    checkWarning.Text = "CHECK!"
    checkWarning.TextColor3 = Color3.fromRGB(255, 255, 100)
    checkWarning.Font = Enum.Font.FredokaOne
    checkWarning.TextSize = 22
    checkWarning.TextScaled = true
    checkWarning.Visible = false
    checkWarning.Parent = screenGui

    local checkWarningConstraint = Instance.new("UISizeConstraint")
    checkWarningConstraint.MaxSize = Vector2.new(200, 36)
    checkWarningConstraint.Parent = checkWarning

    Instance.new("UICorner", checkWarning).CornerRadius = UDim.new(0, 8)
    local checkStroke = Instance.new("UIStroke")
    checkStroke.Color = Color3.fromRGB(255, 60, 60)
    checkStroke.Thickness = 2
    checkStroke.Parent = checkWarning

    -- Capture counter (shows pieces taken by each side)
    local captureLabel = Instance.new("TextLabel")
    captureLabel.Name = "CaptureLabel"
    captureLabel.Size = UDim2.new(0.6, 0, 0, 24)
    captureLabel.AnchorPoint = Vector2.new(0.5, 0)
    captureLabel.Position = UDim2.new(0.5, 0, 0, 108)
    captureLabel.BackgroundTransparency = 1
    captureLabel.Text = ""
    captureLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    captureLabel.Font = Enum.Font.GothamMedium
    captureLabel.TextSize = 14
    captureLabel.Parent = screenGui

    local captureSizeConstraint = Instance.new("UISizeConstraint")
    captureSizeConstraint.MaxSize = Vector2.new(400, 24)
    captureSizeConstraint.Parent = captureLabel

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
    colorLabel.Size = UDim2.new(0, 160, 0, 30)
    colorLabel.AnchorPoint = Vector2.new(0.5, 0)
    colorLabel.Position = UDim2.new(0.5, 0, 0, 94)
    colorLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    colorLabel.BackgroundTransparency = 0.3
    colorLabel.Text = ""
    colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 16
    colorLabel.Parent = screenGui

    local colorCorner = Instance.new("UICorner")
    colorCorner.CornerRadius = UDim.new(0, 8)
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

    -- Resign confirmation state
    local resignConfirmVisible = false
    local resignConfirmFrame = nil

    resignBtn.MouseButton1Click:Connect(function()
        if not ClientState.currentGameId then return end
        if resignConfirmVisible then return end

        -- Show confirmation popup
        resignConfirmVisible = true
        resignConfirmFrame = Instance.new("Frame")
        resignConfirmFrame.Name = "ResignConfirm"
        resignConfirmFrame.Size = UDim2.new(0, 240, 0, 100)
        resignConfirmFrame.AnchorPoint = Vector2.new(1, 1)
        resignConfirmFrame.Position = UDim2.new(1, -120, 1, -70)
        resignConfirmFrame.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
        resignConfirmFrame.BorderSizePixel = 0
        resignConfirmFrame.Parent = screenGui

        local rcCorner = Instance.new("UICorner")
        rcCorner.CornerRadius = UDim.new(0, 8)
        rcCorner.Parent = resignConfirmFrame

        local rcStroke = Instance.new("UIStroke")
        rcStroke.Color = Color3.fromRGB(200, 80, 80)
        rcStroke.Parent = resignConfirmFrame

        local rcLabel = Instance.new("TextLabel")
        rcLabel.Size = UDim2.new(1, 0, 0, 35)
        rcLabel.BackgroundTransparency = 1
        rcLabel.Text = "Really resign?"
        rcLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
        rcLabel.Font = Enum.Font.GothamBold
        rcLabel.TextSize = 16
        rcLabel.Parent = resignConfirmFrame

        local yesBtn = Instance.new("TextButton")
        yesBtn.Size = UDim2.new(0.45, 0, 0, 40)
        yesBtn.Position = UDim2.new(0.025, 0, 0, 45)
        yesBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        yesBtn.Text = "Yes"
        yesBtn.TextColor3 = Color3.new(1, 1, 1)
        yesBtn.Font = Enum.Font.GothamBold
        yesBtn.TextSize = 16
        yesBtn.Parent = resignConfirmFrame
        Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 6)

        local noBtn = Instance.new("TextButton")
        noBtn.Size = UDim2.new(0.45, 0, 0, 40)
        noBtn.Position = UDim2.new(0.525, 0, 0, 45)
        noBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
        noBtn.Text = "No"
        noBtn.TextColor3 = Color3.new(1, 1, 1)
        noBtn.Font = Enum.Font.GothamBold
        noBtn.TextSize = 16
        noBtn.Parent = resignConfirmFrame
        Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 6)

        local function closeConfirm()
            if resignConfirmFrame then
                resignConfirmFrame:Destroy()
                resignConfirmFrame = nil
            end
            resignConfirmVisible = false
        end

        yesBtn.MouseButton1Click:Connect(function()
            ResignEvent:FireServer(ClientState.currentGameId)
            closeConfirm()
        end)

        noBtn.MouseButton1Click:Connect(function()
            closeConfirm()
        end)

        -- Auto-dismiss after 5 seconds
        task.delay(5, function()
            if resignConfirmVisible then
                closeConfirm()
            end
        end)
    end)

    -- Back to Menu button (works during active game, with confirmation)
    local menuBtn = Instance.new("TextButton")
    menuBtn.Name = "MenuButton"
    menuBtn.Size = UDim2.new(0, 80, 0, 40)
    menuBtn.Position = UDim2.new(1, -230, 1, -60)
    menuBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    menuBtn.Text = "Menu"
    menuBtn.TextColor3 = Color3.new(1, 1, 1)
    menuBtn.Font = Enum.Font.GothamBold
    menuBtn.TextSize = 16
    menuBtn.Parent = screenGui

    local menuBtnCorner = Instance.new("UICorner")
    menuBtnCorner.CornerRadius = UDim.new(0, 5)
    menuBtnCorner.Parent = menuBtn

    menuBtn.MouseButton1Click:Connect(function()
        SoundManager.playSelectSound()
        -- If game is active, resign first with confirmation
        if ClientState.currentGameId and ClientState.gameState
            and ClientState.gameState.gameState == Constants.GameState.IN_PROGRESS
            and not ClientState.isAIvsAI then
            -- Show small confirm popup
            local confirmBg = Instance.new("Frame")
            confirmBg.Name = "MenuConfirm"
            confirmBg.Size = UDim2.new(0, 220, 0, 80)
            confirmBg.AnchorPoint = Vector2.new(0.5, 0.5)
            confirmBg.Position = UDim2.new(0.5, 0, 0.5, 0)
            confirmBg.BackgroundColor3 = Color3.fromRGB(50, 45, 60)
            confirmBg.Parent = screenGui

            Instance.new("UICorner", confirmBg).CornerRadius = UDim.new(0, 8)
            Instance.new("UIStroke", confirmBg).Color = Color3.fromRGB(200, 160, 80)

            local confirmLabel = Instance.new("TextLabel")
            confirmLabel.Size = UDim2.new(1, 0, 0, 35)
            confirmLabel.BackgroundTransparency = 1
            confirmLabel.Text = "Leave? (counts as resign)"
            confirmLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            confirmLabel.Font = Enum.Font.GothamBold
            confirmLabel.TextSize = 13
            confirmLabel.Parent = confirmBg

            local yesMenuBtn = Instance.new("TextButton")
            yesMenuBtn.Size = UDim2.new(0, 80, 0, 30)
            yesMenuBtn.Position = UDim2.new(0, 20, 0, 40)
            yesMenuBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
            yesMenuBtn.Text = "Leave"
            yesMenuBtn.TextColor3 = Color3.new(1, 1, 1)
            yesMenuBtn.Font = Enum.Font.GothamBold
            yesMenuBtn.TextSize = 14
            yesMenuBtn.Parent = confirmBg
            Instance.new("UICorner", yesMenuBtn).CornerRadius = UDim.new(0, 5)

            local noMenuBtn = Instance.new("TextButton")
            noMenuBtn.Size = UDim2.new(0, 80, 0, 30)
            noMenuBtn.Position = UDim2.new(1, -100, 0, 40)
            noMenuBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
            noMenuBtn.Text = "Stay"
            noMenuBtn.TextColor3 = Color3.new(1, 1, 1)
            noMenuBtn.Font = Enum.Font.GothamBold
            noMenuBtn.TextSize = 14
            noMenuBtn.Parent = confirmBg
            Instance.new("UICorner", noMenuBtn).CornerRadius = UDim.new(0, 5)

            yesMenuBtn.MouseButton1Click:Connect(function()
                ResignEvent:FireServer(ClientState.currentGameId)
                confirmBg:Destroy()
                -- Return to menu handled by game end flow
            end)

            noMenuBtn.MouseButton1Click:Connect(function()
                confirmBg:Destroy()
            end)

            task.delay(5, function()
                if confirmBg and confirmBg.Parent then
                    confirmBg:Destroy()
                end
            end)
        else
            -- Game is over or AI vs AI - go directly to menu
            local ro = screenGui:FindFirstChild("ResultOverlay")
            if ro then ro.Visible = false end
            ClientState.currentGameId = nil
            ClientState.gameState = nil
            ClientState.selectedSquare = nil
            ClientState.validMoves = {}
            ClientState.playerColor = nil
            ClientState.isMyTurn = false
            ClientState.isAIvsAI = false
            ClientState.currentBoss = nil
            ClientState.localTimeWhite = 600
            ClientState.localTimeBlack = 600
            ClientState.clockRunning = false
            MusicManager.playMenuMusic()
            screenGui.Enabled = false
            local mainMenu = LocalPlayer.PlayerGui:FindFirstChild("MainMenu")
            if mainMenu then mainMenu.Enabled = true end
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

    -- In-game settings button (gear icon, next to camera reset)
    local inGameSettingsBtn = Instance.new("TextButton")
    inGameSettingsBtn.Name = "InGameSettingsButton"
    inGameSettingsBtn.Size = UDim2.new(0, 40, 0, 40)
    inGameSettingsBtn.Position = UDim2.new(1, -110, 1, -110)
    inGameSettingsBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    inGameSettingsBtn.Text = "⚙"
    inGameSettingsBtn.TextColor3 = Color3.new(1, 1, 1)
    inGameSettingsBtn.Font = Enum.Font.GothamBold
    inGameSettingsBtn.TextSize = 22
    inGameSettingsBtn.Parent = screenGui

    Instance.new("UICorner", inGameSettingsBtn).CornerRadius = UDim.new(0, 8)

    inGameSettingsBtn.MouseButton1Click:Connect(function()
        SettingsManager.createSettingsUI(function()
            SettingsManager.applyToBoardConfig(BoardConfig)
            -- Refresh board visuals immediately with new theme
            if ClientState.gameState then
                updateBoardVisuals(boardFolder, squares, ClientState.gameState, true)
            end
        end)
    end)

    -- Move history panel (right side, collapsible)
    local historyPanel = Instance.new("Frame")
    historyPanel.Name = "MoveHistory"
    historyPanel.Size = UDim2.new(0, 140, 0, 160)
    historyPanel.Position = UDim2.new(1, -155, 1, -230)
    historyPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    historyPanel.BackgroundTransparency = 0.1
    historyPanel.BorderSizePixel = 0
    historyPanel.Parent = screenGui

    Instance.new("UICorner", historyPanel).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", historyPanel).Color = Color3.fromRGB(70, 70, 80)

    local historyTitle = Instance.new("TextLabel")
    historyTitle.Size = UDim2.new(1, 0, 0, 22)
    historyTitle.BackgroundTransparency = 1
    historyTitle.Text = "Moves"
    historyTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    historyTitle.Font = Enum.Font.GothamBold
    historyTitle.TextSize = 13
    historyTitle.Parent = historyPanel

    local historyScroll = Instance.new("ScrollingFrame")
    historyScroll.Name = "HistoryScroll"
    historyScroll.Size = UDim2.new(1, -8, 1, -26)
    historyScroll.Position = UDim2.new(0, 4, 0, 22)
    historyScroll.BackgroundTransparency = 1
    historyScroll.BorderSizePixel = 0
    historyScroll.ScrollBarThickness = 3
    historyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    historyScroll.Parent = historyPanel

    local historyLayout = Instance.new("UIListLayout")
    historyLayout.Padding = UDim.new(0, 2)
    historyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    historyLayout.Parent = historyScroll

    historyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        historyScroll.CanvasSize = UDim2.new(0, 0, 0, historyLayout.AbsoluteContentSize.Y + 4)
        -- Auto-scroll to bottom
        historyScroll.CanvasPosition = Vector2.new(0, math.max(0, historyLayout.AbsoluteContentSize.Y - historyScroll.AbsoluteSize.Y))
    end)

    -- Game-over result popup (hidden until game ends)
    local resultOverlay = Instance.new("Frame")
    resultOverlay.Name = "ResultOverlay"
    resultOverlay.Size = UDim2.new(1, 0, 1, 0)
    resultOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    resultOverlay.BackgroundTransparency = 0.4
    resultOverlay.BorderSizePixel = 0
    resultOverlay.Visible = false
    resultOverlay.ZIndex = 10
    resultOverlay.Parent = screenGui

    local resultPopup = Instance.new("Frame")
    resultPopup.Name = "ResultPopup"
    resultPopup.Size = UDim2.new(0.85, 0, 0, 260)
    resultPopup.AnchorPoint = Vector2.new(0.5, 0.5)
    resultPopup.Position = UDim2.new(0.5, 0, 0.5, 0)
    resultPopup.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    resultPopup.BorderSizePixel = 0
    resultPopup.ZIndex = 11
    resultPopup.Parent = resultOverlay

    local rpSizeConstraint = Instance.new("UISizeConstraint")
    rpSizeConstraint.MaxSize = Vector2.new(360, 260)
    rpSizeConstraint.MinSize = Vector2.new(260, 240)
    rpSizeConstraint.Parent = resultPopup

    Instance.new("UICorner", resultPopup).CornerRadius = UDim.new(0, 12)
    local rpStroke = Instance.new("UIStroke")
    rpStroke.Thickness = 2
    rpStroke.Color = Color3.fromRGB(255, 200, 100)
    rpStroke.Parent = resultPopup

    local resultEmoji = Instance.new("TextLabel")
    resultEmoji.Name = "ResultEmoji"
    resultEmoji.Size = UDim2.new(1, 0, 0, 60)
    resultEmoji.Position = UDim2.new(0, 0, 0, 10)
    resultEmoji.BackgroundTransparency = 1
    resultEmoji.Text = ""
    resultEmoji.Font = Enum.Font.FredokaOne
    resultEmoji.TextSize = 48
    resultEmoji.ZIndex = 12
    resultEmoji.Parent = resultPopup

    local resultTitle = Instance.new("TextLabel")
    resultTitle.Name = "ResultTitle"
    resultTitle.Size = UDim2.new(1, -20, 0, 40)
    resultTitle.AnchorPoint = Vector2.new(0.5, 0)
    resultTitle.Position = UDim2.new(0.5, 0, 0, 70)
    resultTitle.BackgroundTransparency = 1
    resultTitle.Text = ""
    resultTitle.Font = Enum.Font.FredokaOne
    resultTitle.TextSize = 28
    resultTitle.TextScaled = true
    resultTitle.ZIndex = 12
    resultTitle.Parent = resultPopup

    local resultTitleConstraint = Instance.new("UITextSizeConstraint")
    resultTitleConstraint.MaxTextSize = 28
    resultTitleConstraint.Parent = resultTitle

    local resultStats = Instance.new("TextLabel")
    resultStats.Name = "ResultStats"
    resultStats.Size = UDim2.new(1, -20, 0, 24)
    resultStats.AnchorPoint = Vector2.new(0.5, 0)
    resultStats.Position = UDim2.new(0.5, 0, 0, 112)
    resultStats.BackgroundTransparency = 1
    resultStats.Text = ""
    resultStats.TextColor3 = Color3.fromRGB(180, 180, 190)
    resultStats.Font = Enum.Font.GothamMedium
    resultStats.TextSize = 14
    resultStats.ZIndex = 12
    resultStats.Parent = resultPopup

    -- Rematch button (same mode)
    local rematchBtn = Instance.new("TextButton")
    rematchBtn.Name = "RematchButton"
    rematchBtn.Size = UDim2.new(0.8, 0, 0, 42)
    rematchBtn.AnchorPoint = Vector2.new(0.5, 0)
    rematchBtn.Position = UDim2.new(0.5, 0, 0, 148)
    rematchBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
    rematchBtn.BorderSizePixel = 0
    rematchBtn.Text = "Rematch"
    rematchBtn.TextColor3 = Color3.new(1, 1, 1)
    rematchBtn.Font = Enum.Font.FredokaOne
    rematchBtn.TextSize = 20
    rematchBtn.ZIndex = 12
    rematchBtn.Parent = resultPopup
    Instance.new("UICorner", rematchBtn).CornerRadius = UDim.new(0, 8)

    -- Back to menu button
    local backToMenuBtn = Instance.new("TextButton")
    backToMenuBtn.Name = "BackToMenuButton"
    backToMenuBtn.Size = UDim2.new(0.8, 0, 0, 34)
    backToMenuBtn.AnchorPoint = Vector2.new(0.5, 0)
    backToMenuBtn.Position = UDim2.new(0.5, 0, 0, 200)
    backToMenuBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
    backToMenuBtn.BorderSizePixel = 0
    backToMenuBtn.Text = "Back to Menu"
    backToMenuBtn.TextColor3 = Color3.new(1, 1, 1)
    backToMenuBtn.Font = Enum.Font.GothamBold
    backToMenuBtn.TextSize = 16
    backToMenuBtn.ZIndex = 12
    backToMenuBtn.Parent = resultPopup
    Instance.new("UICorner", backToMenuBtn).CornerRadius = UDim.new(0, 8)

    -- Helper to reset client state and return to menu
    local function resetToMenu()
        SoundManager.playSelectSound()
        resultOverlay.Visible = false
        ClientState.currentGameId = nil
        ClientState.gameState = nil
        ClientState.selectedSquare = nil
        ClientState.validMoves = {}
        ClientState.playerColor = nil
        ClientState.isMyTurn = false
        ClientState.isAIvsAI = false
        ClientState.currentBoss = nil
        ClientState.localTimeWhite = 600
        ClientState.localTimeBlack = 600
        ClientState.clockRunning = false

        -- Clear move history
        local hScroll = screenGui:FindFirstChild("MoveHistory") and screenGui:FindFirstChild("MoveHistory"):FindFirstChild("HistoryScroll")
        if hScroll then
            for _, child in ipairs(hScroll:GetChildren()) do
                if child:IsA("TextLabel") then child:Destroy() end
            end
        end

        MusicManager.playMenuMusic()
        screenGui.Enabled = false

        local mainMenu = LocalPlayer.PlayerGui:FindFirstChild("MainMenu")
        if mainMenu then
            mainMenu.Enabled = true
            local sl = mainMenu:FindFirstChild("SearchingLabel")
            if sl then sl.Visible = false end
        end
    end

    backToMenuBtn.MouseButton1Click:Connect(resetToMenu)

    rematchBtn.MouseButton1Click:Connect(function()
        SoundManager.playSelectSound()
        resultOverlay.Visible = false

        -- Remember the game mode and boss for rematch
        local lastGameState = ClientState.gameState
        local lastBoss = ClientState.currentBoss
        local lastIsAIvsAI = ClientState.isAIvsAI

        -- Reset state
        ClientState.currentGameId = nil
        ClientState.gameState = nil
        ClientState.selectedSquare = nil
        ClientState.validMoves = {}
        ClientState.playerColor = nil
        ClientState.isMyTurn = false
        ClientState.localTimeWhite = 600
        ClientState.localTimeBlack = 600
        ClientState.clockRunning = false
        ClientState.lastMoveCount = 0
        ClientState.lastCheckWhite = false
        ClientState.lastCheckBlack = false

        -- Clear move history
        local hScroll = screenGui:FindFirstChild("MoveHistory") and screenGui:FindFirstChild("MoveHistory"):FindFirstChild("HistoryScroll")
        if hScroll then
            for _, child in ipairs(hScroll:GetChildren()) do
                if child:IsA("TextLabel") then child:Destroy() end
            end
        end

        -- Re-request the same type of game
        if lastIsAIvsAI and lastGameState then
            local whiteMode = lastGameState.whiteDifficulty or Constants.GameMode.AI_MEDIUM
            local blackMode = lastGameState.blackDifficulty or Constants.GameMode.AI_MEDIUM
            ClientState.isAIvsAI = true
            RequestAIvsAIGameEvent:FireServer(whiteMode, blackMode)
        elseif lastGameState and lastGameState.gameMode then
            ClientState.currentBoss = lastBoss
            if lastGameState.gameMode:sub(1, 2) == "AI" then
                RequestAIGameEvent:FireServer(lastGameState.gameMode)
            else
                RequestMatchEvent:FireServer(lastGameState.gameMode)
            end
            MusicManager.playForGameMode(lastGameState.gameMode)
        else
            -- Fallback: go to menu
            resetToMenu()
        end
    end)

    -- Legacy NewGameButton removed - replaced by result popup buttons

    -- Gesture menu (improved with cat-themed icons and labels)
    local gestureFrame = Instance.new("Frame")
    gestureFrame.Name = "GestureMenu"
    gestureFrame.Size = UDim2.new(0, 280, 0, 48)
    gestureFrame.AnchorPoint = Vector2.new(0.5, 1)
    gestureFrame.Position = UDim2.new(0.5, 0, 1, -15)
    gestureFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    gestureFrame.BackgroundTransparency = 0.3
    gestureFrame.Parent = screenGui

    local gfCorner = Instance.new("UICorner")
    gfCorner.CornerRadius = UDim.new(0, 12)
    gfCorner.Parent = gestureFrame

    local gestureList = Instance.new("UIListLayout")
    gestureList.FillDirection = Enum.FillDirection.Horizontal
    gestureList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gestureList.VerticalAlignment = Enum.VerticalAlignment.Center
    gestureList.Padding = UDim.new(0, 6)
    gestureList.Parent = gestureFrame

    local gestures = {
        {id = "HappyMeow", icon = ":3", tip = "Happy"},
        {id = "AngryHiss", icon = ">:(", tip = "Hiss"},
        {id = "SlyGrin", icon = ";)", tip = "Sly"},
        {id = "PawWave", icon = "o/", tip = "Wave"},
    }

    for _, gesture in ipairs(gestures) do
        local gestureBtn = Instance.new("TextButton")
        gestureBtn.Name = gesture.id
        gestureBtn.Size = UDim2.new(0, 62, 0, 38)
        gestureBtn.BackgroundColor3 = Color3.fromRGB(70, 65, 90)
        gestureBtn.Text = gesture.icon
        gestureBtn.TextColor3 = Color3.new(1, 1, 1)
        gestureBtn.Font = Enum.Font.GothamBold
        gestureBtn.TextSize = 18
        gestureBtn.Parent = gestureFrame

        Instance.new("UICorner", gestureBtn).CornerRadius = UDim.new(0, 8)

        gestureBtn.MouseEnter:Connect(function()
            gestureBtn.BackgroundColor3 = Color3.fromRGB(100, 95, 130)
        end)
        gestureBtn.MouseLeave:Connect(function()
            gestureBtn.BackgroundColor3 = Color3.fromRGB(70, 65, 90)
        end)

        gestureBtn.MouseButton1Click:Connect(function()
            if ClientState.currentGameId then
                SendGestureEvent:FireServer(ClientState.currentGameId, gesture.id)
                -- Flash the button to confirm send
                gestureBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
                task.delay(0.3, function()
                    gestureBtn.BackgroundColor3 = Color3.fromRGB(70, 65, 90)
                end)
            end
        end)
    end

    -- Gesture received display (floating speech bubble)
    local gestureBubble = Instance.new("TextLabel")
    gestureBubble.Name = "GestureBubble"
    gestureBubble.Size = UDim2.new(0, 160, 0, 50)
    gestureBubble.AnchorPoint = Vector2.new(0.5, 1)
    gestureBubble.Position = UDim2.new(0.5, 0, 0, 85)
    gestureBubble.BackgroundColor3 = Color3.fromRGB(60, 55, 80)
    gestureBubble.BackgroundTransparency = 0.1
    gestureBubble.Text = ""
    gestureBubble.TextColor3 = Color3.fromRGB(255, 220, 150)
    gestureBubble.Font = Enum.Font.FredokaOne
    gestureBubble.TextSize = 22
    gestureBubble.Visible = false
    gestureBubble.Parent = screenGui

    Instance.new("UICorner", gestureBubble).CornerRadius = UDim.new(0, 12)
    local bubbleStroke = Instance.new("UIStroke")
    bubbleStroke.Color = Color3.fromRGB(255, 200, 100)
    bubbleStroke.Parent = gestureBubble

    -- Create miniboard on the right side
    local miniboardContainer, updateMiniboard = createMiniboard(screenGui)

    return screenGui, updateMiniboard
end

-- Initialize client
local function initialize()
    if Constants.DEBUG then print("🐱 [DEBUG] initialize() starting...") end

    -- Show loading screen immediately
    local loadingGui = Instance.new("ScreenGui")
    loadingGui.Name = "LoadingScreen"
    loadingGui.ResetOnSpawn = false
    loadingGui.DisplayOrder = 100
    loadingGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local loadingBg = Instance.new("Frame")
    loadingBg.Size = UDim2.new(1, 0, 1, 0)
    loadingBg.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    loadingBg.BorderSizePixel = 0
    loadingBg.Parent = loadingGui

    local loadingTitle = Instance.new("TextLabel")
    loadingTitle.Size = UDim2.new(1, 0, 0, 60)
    loadingTitle.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingTitle.Position = UDim2.new(0.5, 0, 0.4, 0)
    loadingTitle.BackgroundTransparency = 1
    loadingTitle.Text = "Claws & Paws"
    loadingTitle.TextColor3 = Color3.fromRGB(255, 200, 100)
    loadingTitle.Font = Enum.Font.FredokaOne
    loadingTitle.TextSize = 42
    loadingTitle.Parent = loadingBg

    local loadingDots = Instance.new("TextLabel")
    loadingDots.Size = UDim2.new(1, 0, 0, 30)
    loadingDots.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingDots.Position = UDim2.new(0.5, 0, 0.52, 0)
    loadingDots.BackgroundTransparency = 1
    loadingDots.Text = "Setting up the cat arena..."
    loadingDots.TextColor3 = Color3.fromRGB(180, 180, 190)
    loadingDots.Font = Enum.Font.Gotham
    loadingDots.TextSize = 16
    loadingDots.Parent = loadingBg

    -- Hide player character SYNCHRONOUSLY (not async) to ensure it happens first
    if Constants.DEBUG then print("🐱 [DEBUG] Waiting for character...") end
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    if Constants.DEBUG then print("🐱 [DEBUG] Got character:", character.Name) end

    -- Move player to camera position instead of hiding
    -- This way, the camera following the character will be at the right spot
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if hrp then
        if Constants.DEBUG then print("🐱 [DEBUG] Moving character to camera viewing position") end
        -- Position character where we want camera to be, looking at board center
        hrp.CFrame = CFrame.new(Vector3.new(0, 60, -50), Vector3.new(0, 0, 0))
    end

    -- Make character invisible
    if Constants.DEBUG then print("🐱 [DEBUG] Making character invisible...") end
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
    if Constants.DEBUG then print("🐱 [DEBUG] Camera setup done via StarterPlayer") end

    -- Remove spawn location if it exists
    if Constants.DEBUG then print("🐱 [DEBUG] Looking for SpawnLocation...") end
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        if Constants.DEBUG then print("🐱 [DEBUG] Found SpawnLocation, destroying it") end
        spawnLocation:Destroy()
    else
        if Constants.DEBUG then print("🐱 [DEBUG] No SpawnLocation found") end
    end

    -- Remove any default baseplate
    if Constants.DEBUG then print("🐱 [DEBUG] Looking for Baseplate...") end
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        if Constants.DEBUG then print("🐱 [DEBUG] Found Baseplate, making invisible") end
        baseplate.Transparency = 1 -- Make invisible instead of deleting
    end

    -- Set up camera
    CameraController.setupGameCamera()
    CameraController.enableCameraRotation()

    -- Apply theme from settings to board config
    if Constants.DEBUG then print("🐱 [DEBUG] Applying color theme from settings...") end
    SettingsManager.applyToBoardConfig(BoardConfig)

    if Constants.DEBUG then print("🐱 [DEBUG] Creating board...") end
    local boardFolder, squares = createBoard()
    if Constants.DEBUG then print("🐱 [DEBUG] Board created! Creating menu...") end
    local mainMenu = createMainMenu()
    if Constants.DEBUG then print("🐱 [DEBUG] Menu created! Creating HUD...") end
    local gameHUD, updateMiniboard = createGameHUD()
    if Constants.DEBUG then print("🐱 [DEBUG] HUD created!") end

    -- Dismiss loading screen with fade
    local TweenService = game:GetService("TweenService")
    TweenService:Create(loadingBg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    TweenService:Create(loadingTitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    TweenService:Create(loadingDots, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    task.delay(0.6, function()
        loadingGui:Destroy()
    end)

    -- Create help button
    TutorialManager.createHelpButton()

    -- Show tutorial for first-time players
    task.delay(2, function()
        TutorialManager.showInitialTutorial()
    end)

    -- Handle game state updates
    GetGameStateFunction.OnClientInvoke = function(gameState)
        if Constants.DEBUG then print("🐱 [DEBUG] Received game state from server!") end
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
            if currentMoveCount > ClientState.lastMoveCount then
                -- A new move was made
                local lastMove = gameState.moveHistory[currentMoveCount]
                -- Play sound for opponent/AI moves, or all moves in AI vs AI
                local isOpponentMove = lastMove and lastMove.color ~= ClientState.playerColor
                if lastMove and (isOpponentMove or ClientState.isAIvsAI) and ClientState.lastMoveCount > 0 then
                    if lastMove.captured then
                        SoundManager.playCaptureSound()
                    else
                        SoundManager.playMoveSound(lastMove.piece)
                    end
                end
            end
            ClientState.lastMoveCount = currentMoveCount

            -- Check warning sound and visual (only on state transitions)
            local anyInCheck = false
            if gameState.inCheck then
                local whiteInCheck = gameState.inCheck[Constants.Color.WHITE]
                local blackInCheck = gameState.inCheck[Constants.Color.BLACK]
                anyInCheck = whiteInCheck or blackInCheck

                if (whiteInCheck and not ClientState.lastCheckWhite)
                    or (blackInCheck and not ClientState.lastCheckBlack) then
                    SoundManager.playCheckSound()
                end

                ClientState.lastCheckWhite = whiteInCheck or false
                ClientState.lastCheckBlack = blackInCheck or false
            end

            -- Show/hide CHECK! warning label
            local checkLabel = gameHUD and gameHUD:FindFirstChild("CheckWarning")
            if checkLabel then
                checkLabel.Visible = anyInCheck
            end
        else
            -- Hide check warning on game end
            local checkLabel = gameHUD and gameHUD:FindFirstChild("CheckWarning")
            if checkLabel then checkLabel.Visible = false end

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
                    elseif gameState.gameState == Constants.GameState.STALEMATE
                        or gameState.gameState == Constants.GameState.DRAW then
                        SoundManager.playDrawSound()
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

        -- Hide result overlay and searching label if a new game started
        if gameState.gameState == Constants.GameState.IN_PROGRESS then
            local ro = gameHUD:FindFirstChild("ResultOverlay")
            if ro then ro.Visible = false end
            local mainMenu = LocalPlayer.PlayerGui:FindFirstChild("MainMenu")
            if mainMenu then
                local sl = mainMenu:FindFirstChild("SearchingLabel")
                if sl then sl.Visible = false end
            end
        end

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
            else
                -- Game over - determine result
                local won = false
                local isDraw = false
                local resultText = ""
                local emoji = ""

                -- Map end reasons to kid-friendly descriptions
                local endReason = gameState.endReason or ""
                local reasonText = ""

                if gameState.gameState == Constants.GameState.WHITE_WIN then
                    won = ClientState.playerColor == Constants.Color.WHITE
                    if endReason == "checkmate" then
                        resultText = won and "CHECKMATE!" or "Checkmate..."
                        reasonText = won and "You trapped their King!" or "Your King got trapped!"
                    elseif endReason == "timeout" then
                        resultText = won and "YOU WIN!" or "Time's Up!"
                        reasonText = won and "Opponent ran out of time" or "You ran out of time"
                    elseif endReason == "resignation" then
                        resultText = won and "YOU WIN!" or "You Resigned"
                        reasonText = won and "Opponent gave up" or "You surrendered"
                    elseif endReason == "disconnection" then
                        resultText = won and "YOU WIN!" or "Disconnected"
                        reasonText = won and "Opponent left the game" or "Connection lost"
                    else
                        resultText = won and "YOU WIN!" or "You Lose..."
                    end
                    emoji = won and "🎉" or "😿"
                elseif gameState.gameState == Constants.GameState.BLACK_WIN then
                    won = ClientState.playerColor == Constants.Color.BLACK
                    if endReason == "checkmate" then
                        resultText = won and "CHECKMATE!" or "Checkmate..."
                        reasonText = won and "You trapped their King!" or "Your King got trapped!"
                    elseif endReason == "timeout" then
                        resultText = won and "YOU WIN!" or "Time's Up!"
                        reasonText = won and "Opponent ran out of time" or "You ran out of time"
                    elseif endReason == "resignation" then
                        resultText = won and "YOU WIN!" or "You Resigned"
                        reasonText = won and "Opponent gave up" or "You surrendered"
                    elseif endReason == "disconnection" then
                        resultText = won and "YOU WIN!" or "Disconnected"
                        reasonText = won and "Opponent left the game" or "Connection lost"
                    else
                        resultText = won and "YOU WIN!" or "You Lose..."
                    end
                    emoji = won and "🎉" or "😿"
                elseif gameState.gameState == Constants.GameState.STALEMATE then
                    isDraw = true
                    resultText = "Stalemate!"
                    reasonText = "No legal moves but King is safe"
                    emoji = "😺"
                elseif gameState.gameState == Constants.GameState.DRAW then
                    isDraw = true
                    if endReason == "50-move rule" then
                        resultText = "Draw!"
                        reasonText = "50 moves without a capture"
                    elseif endReason == "repetition" then
                        resultText = "Draw!"
                        reasonText = "Same position repeated 3 times"
                    elseif endReason == "insufficient material" then
                        resultText = "Draw!"
                        reasonText = "Not enough pieces to checkmate"
                    else
                        resultText = "Draw!"
                    end
                    emoji = "😺"
                end

                -- Campaign boss mode - show boss quotes
                if ClientState.currentBoss and not ClientState.isAIvsAI then
                    local boss = ClientState.currentBoss
                    if won then
                        resultText = boss.victoryQuote or "YOU WIN!"
                        LocalPlayer:SetAttribute("boss_" .. boss.id, true)
                    elseif not isDraw then
                        resultText = boss.defeatQuote or "You Lose..."
                    end
                end

                -- AI vs AI gets neutral result text
                if ClientState.isAIvsAI then
                    if gameState.gameState == Constants.GameState.WHITE_WIN then
                        resultText = endReason == "checkmate" and "White AI: Checkmate!" or "White AI Wins!"
                    elseif gameState.gameState == Constants.GameState.BLACK_WIN then
                        resultText = endReason == "checkmate" and "Black AI: Checkmate!" or "Black AI Wins!"
                    end
                    emoji = "🤖"
                    won = false
                end

                local moveCount = gameState.moveHistory and #gameState.moveHistory or 0

                -- Update turn label briefly
                turnLabel.Text = emoji .. " " .. resultText
                turnLabel.TextColor3 = won and Color3.fromRGB(255, 215, 0)
                    or isDraw and Color3.fromRGB(200, 200, 200)
                    or Color3.fromRGB(200, 100, 100)

                -- Play music
                if isDraw then
                    MusicManager.playMenuMusic()
                elseif not ClientState.isAIvsAI then
                    if won then MusicManager.playVictoryMusic() else MusicManager.playDefeatMusic() end
                else
                    MusicManager.playMenuMusic()
                end

                -- Show the big result popup after a short delay for drama
                task.delay(0.8, function()
                    local ro = gameHUD:FindFirstChild("ResultOverlay")
                    if not ro then return end

                    local rp = ro:FindFirstChild("ResultPopup")
                    if not rp then return end

                    -- Set content
                    local emojiLabel = rp:FindFirstChild("ResultEmoji")
                    if emojiLabel then emojiLabel.Text = emoji end

                    local titleLabel = rp:FindFirstChild("ResultTitle")
                    if titleLabel then
                        titleLabel.Text = resultText
                        titleLabel.TextColor3 = won and Color3.fromRGB(255, 215, 0)
                            or isDraw and Color3.fromRGB(200, 200, 200)
                            or Color3.fromRGB(200, 100, 100)
                    end

                    local statsLabel = rp:FindFirstChild("ResultStats")
                    if statsLabel then
                        local statsText = ""
                        if reasonText ~= "" then
                            statsText = reasonText
                        end
                        if moveCount > 0 then
                            statsText = statsText .. (statsText ~= "" and " | " or "") .. moveCount .. " moves"
                        end
                        statsLabel.Text = statsText
                    end

                    -- Set popup border color based on result
                    local rpStroke = rp:FindFirstChildOfClass("UIStroke")
                    if rpStroke then
                        rpStroke.Color = won and Color3.fromRGB(255, 215, 0)
                            or isDraw and Color3.fromRGB(150, 150, 160)
                            or Color3.fromRGB(200, 100, 100)
                    end

                    ro.Visible = true
                end)

                -- Hide resign button
                local resignBtnEnd = gameHUD:FindFirstChild("ResignButton")
                if resignBtnEnd then resignBtnEnd.Visible = false end
            end
        end

        -- Update capture counter
        local captureLabel = gameHUD:FindFirstChild("CaptureLabel")
        if captureLabel and gameState.pieces then
            local whitePieces, blackPieces = 0, 0
            for _, piece in ipairs(gameState.pieces) do
                if piece.color == Constants.Color.WHITE then
                    whitePieces = whitePieces + 1
                else
                    blackPieces = blackPieces + 1
                end
            end
            -- Starting pieces: 12 each (K, Q, R, 2B, N, 6P = 12)
            local whiteCaptured = 12 - blackPieces
            local blackCaptured = 12 - whitePieces
            if whiteCaptured > 0 or blackCaptured > 0 then
                captureLabel.Text = string.format("White took %d | Black took %d", whiteCaptured, blackCaptured)
            else
                captureLabel.Text = ""
            end
        end

        -- Update move history panel
        local historyPanel = gameHUD:FindFirstChild("MoveHistory")
        if historyPanel and gameState.moveHistory then
            local historyScroll = historyPanel:FindFirstChild("HistoryScroll")
            if historyScroll then
                local colLetters = {"a", "b", "c", "d", "e", "f"}
                local existingCount = #historyScroll:GetChildren() - 1 -- minus UIListLayout
                local newMoves = #gameState.moveHistory

                -- Only add new moves (don't rebuild entire list)
                for i = existingCount + 1, newMoves do
                    local move = gameState.moveHistory[i]
                    if move then
                        local pieceLetters = {
                            [Constants.PieceType.KING] = "K",
                            [Constants.PieceType.QUEEN] = "Q",
                            [Constants.PieceType.ROOK] = "R",
                            [Constants.PieceType.BISHOP] = "B",
                            [Constants.PieceType.KNIGHT] = "N",
                        }
                        local pieceLetter = pieceLetters[move.piece] or ""
                        local fromStr = (colLetters[move.from and move.from.col] or "?") .. tostring(move.from and move.from.row or "?")
                        local toStr = (colLetters[move.to and move.to.col] or "?") .. tostring(move.to and move.to.row or "?")
                        local captureStr = move.captured and "x" or "-"
                        local moveText = string.format("%d. %s%s%s%s", i, pieceLetter, fromStr, captureStr, toStr)

                        local moveLabel = Instance.new("TextLabel")
                        moveLabel.Size = UDim2.new(1, 0, 0, 16)
                        moveLabel.BackgroundTransparency = 1
                        moveLabel.Text = moveText
                        moveLabel.TextColor3 = (i % 2 == 1) and Color3.fromRGB(220, 220, 220) or Color3.fromRGB(180, 180, 220)
                        moveLabel.Font = Enum.Font.Code
                        moveLabel.TextSize = 11
                        moveLabel.TextXAlignment = Enum.TextXAlignment.Left
                        moveLabel.LayoutOrder = i
                        moveLabel.Parent = historyScroll
                    end
                end
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

    -- Handle gesture received - show floating speech bubble
    SendGestureEvent.OnClientEvent:Connect(function(gesture)
        local gestureTexts = {
            HappyMeow = ":3  Meow!",
            AngryHiss = ">:(  Hssss!",
            SlyGrin = ";)  Heh heh",
            PawWave = "o/  Hey!",
            Surprised = "O.O  Whoa!",
            SadMeow = ":(  Mew...",
            SleepyYawn = "Zzz...",
            FishOffering = "Here, fishy!",
        }

        local bubbleGui = gameHUD and gameHUD:FindFirstChild("GestureBubble")
        if bubbleGui then
            bubbleGui.Text = gestureTexts[gesture] or gesture
            bubbleGui.Visible = true
            SoundManager.playHappyMeow()

            -- Auto-hide after 3 seconds
            task.delay(3, function()
                if bubbleGui and bubbleGui.Parent then
                    bubbleGui.Visible = false
                end
            end)
        end
    end)

    -- Handle clicks
    -- Shared board click handler (works for both mouse and touch)
    local function handleBoardInput(screenX, screenY)
        -- Skip fight animation if one is active
        if BattleAnimations.isFightActive() then
            BattleAnimations.skipFight()
            return
        end

        local camera = workspace.CurrentCamera
        local ray = camera:ScreenPointToRay(screenX, screenY)

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {}

        local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
        if result then
            local row = result.Instance:GetAttribute("Row")
            local col = result.Instance:GetAttribute("Col")

            if row and col then
                onSquareClicked(tonumber(row), tonumber(col), boardFolder, squares)
            else
                -- Try to find board square underneath
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
                    if row2 and col2 then
                        onSquareClicked(tonumber(row2), tonumber(col2), boardFolder, squares)
                    end
                end
            end
        end
    end

    -- Mouse click handler
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = UserInputService:GetMouseLocation()
            handleBoardInput(mousePos.X, mousePos.Y)
        end
    end)

    -- Touch tap handler (for mobile)
    UserInputService.TouchTap:Connect(function(touchPositions, processed)
        if processed then return end
        if #touchPositions > 0 then
            local pos = touchPositions[1]
            handleBoardInput(pos.X, pos.Y)
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

                -- Determine glow color: gold for own pieces, bright green for valid move targets
                local glowColor = Color3.fromRGB(255, 255, 150) -- Gold for own pieces
                local glowBrightness = 2
                if not isOurPiece and ClientState.selectedSquare then
                    -- Hovering over a valid move target
                    glowColor = Color3.fromRGB(180, 255, 180) -- Bright green
                    glowBrightness = 3
                end

                -- Add new hover effect to the ground square
                local hoverGlow = Instance.new("SurfaceLight")
                hoverGlow.Name = "HoverGlow"
                hoverGlow.Color = glowColor
                hoverGlow.Brightness = glowBrightness
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

        -- Low-time warning sound (player's own clock under 10 seconds, once per second)
        if not ClientState.isAIvsAI then
            local myTime = ClientState.playerColor == Constants.Color.WHITE
                and ClientState.localTimeWhite or ClientState.localTimeBlack
            if myTime <= 10 and myTime > 0 and currentTurn == ClientState.playerColor then
                local now = tick()
                if now - ClientState.lastLowTimeWarning >= 1.0 then
                    ClientState.lastLowTimeWarning = now
                    SoundManager.playLowTimeWarning()
                end
            end
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

    if Constants.DEBUG then print("🐱 Claws & Paws client initialized! Meow!") end
end

if Constants.DEBUG then print("🐱 [DEBUG] About to call initialize()...") end
initialize()
if Constants.DEBUG then print("🐱 [DEBUG] initialize() returned!") end
