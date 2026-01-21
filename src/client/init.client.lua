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
print("🐱 [DEBUG] All modules loaded!")

-- Initialize logger first
print("🐱 [DEBUG] Calling Logger.init()...")
Logger.init()
print("🐱 [DEBUG] Logger initialized!")

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
}

-- Board visual settings - Cat-themed!
local BoardConfig = {
    squareSize = 12, -- MUCH BIGGER board (was 8)
    -- Cozy cat cafe vibes: cream and warm brown
    lightColor = Color3.fromRGB(255, 245, 230), -- Cream (like Persian cat fur)
    darkColor = Color3.fromRGB(139, 90, 60),    -- Warm brown (like tabby stripes)
    highlightColor = Color3.fromRGB(255, 200, 100), -- Warm golden glow
    validMoveColor = Color3.fromRGB(180, 255, 180), -- Soft mint (catnip vibes)
    lastMoveColor = Color3.fromRGB(255, 220, 150),  -- Peachy highlight
    checkColor = Color3.fromRGB(255, 120, 120),     -- Salmon pink (danger!)
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
    -- Find the moving piece
    local pieceName = string.format("Piece_%d_%d", fromRow, fromCol)
    local piece = boardFolder:FindFirstChild(pieceName)

    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Get main part for animation
    local mainPart = piece
    if piece:IsA("Model") then
        mainPart = piece.PrimaryPart or piece:FindFirstChildWhichIsA("BasePart")
    end

    if not mainPart then
        if onComplete then onComplete() end
        return
    end

    local fromPos = mainPart.Position
    local toPos = Vector3.new(
        (toCol - 3.5) * BoardConfig.squareSize,
        3.5,
        (toRow - 3.5) * BoardConfig.squareSize
    )

    -- If this is a capture, remove the target piece with animation
    if isCapture then
        local targetPieceName = string.format("Piece_%d_%d", toRow, toCol)
        local targetPiece = boardFolder:FindFirstChild(targetPieceName)
        if targetPiece then
            local targetPart = targetPiece
            if targetPiece:IsA("Model") then
                targetPart = targetPiece.PrimaryPart or targetPiece:FindFirstChildWhichIsA("BasePart")
            end

            if targetPart then
                BattleAnimations.fadeOutCapture(targetPart)
            end
        end

        -- Use pounce animation for captures
        BattleAnimations.pounceCapture(mainPart, fromPos, toPos, onComplete)
    else
        -- Use piece-specific animation for regular moves
        BattleAnimations.smartMove(mainPart, fromPos, toPos, pieceType, onComplete)
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
            clickZone.Size = Vector3.new(BoardConfig.squareSize - 0.5, 50, BoardConfig.squareSize - 0.5) -- Tall column
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

-- Update board visuals from game state
local function updateBoardVisuals(boardFolder, squares, gameState, skipAnimation)
    -- Clear existing pieces and effects
    for _, child in ipairs(boardFolder:GetChildren()) do
        if child.Name:sub(1, 5) == "Piece" then
            child:Destroy()
        end
    end

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

    if not gameState or not gameState.board then
        print("🐱 [DEBUG] No game state or board to render!")
        return
    end

    -- Debug: Count pieces in board state
    local pieceCount = 0
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            if gameState.board[row] and gameState.board[row][col] then
                pieceCount = pieceCount + 1
            end
        end
    end
    print("🐱 [DEBUG] updateBoardVisuals: Found " .. pieceCount .. " pieces in game state")

    -- Place pieces
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local pieceData = gameState.board[row] and gameState.board[row][col]
            if pieceData then
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

                -- Add spawn animation for new pieces (but not initial setup)
                if not skipAnimation and gameState.lastMove then
                    local wasJustMoved = (gameState.lastMove.toRow == row and gameState.lastMove.toCol == col)
                    if not wasJustMoved then
                        -- Add subtle idle breathing animation
                        startIdleAnimation(pieceModel)
                    end
                end
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

-- Handle square click
local function onSquareClicked(row, col, boardFolder, squares)
    if not ClientState.gameState or ClientState.gameState.gameState ~= Constants.GameState.IN_PROGRESS then
        return
    end

    if not ClientState.isMyTurn then
        return
    end

    local pieceData = ClientState.gameState.board[row] and ClientState.gameState.board[row][col]

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
            local targetPiece = ClientState.gameState.board[row] and ClientState.gameState.board[row][col]
            local isCapture = targetPiece ~= nil

            -- Get the moving piece type
            local fromRow = ClientState.selectedSquare.row
            local fromCol = ClientState.selectedSquare.col
            local movingPiece = ClientState.gameState.board[fromRow] and ClientState.gameState.board[fromRow][fromCol]
            local movingPieceType = movingPiece and movingPiece.type

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

                -- Make the move
                Logger.info(string.format("Sending move: [%d,%d] → [%d,%d]",
                    fromRow, fromCol, row, col))

                MakeMoveEvent:FireServer(
                    ClientState.currentGameId,
                    fromRow,
                    fromCol,
                    row,
                    col
                )
            end)

            ClientState.selectedSquare = nil
            ClientState.validMoves = {}
        elseif pieceData and pieceData.color == ClientState.playerColor then
            -- Select new piece
            SoundManager.playSelectSound()
            ClientState.selectedSquare = {row = row, col = col}
            -- Calculate valid moves locally for visual feedback
            local engine = Shared.ChessEngine.new()
            engine:deserialize(ClientState.gameState)
            ClientState.validMoves = engine:getValidMoves(row, col)
        else
            -- Deselect
            ClientState.selectedSquare = nil
            ClientState.validMoves = {}
        end
    else
        -- Select piece if it's ours
        if pieceData and pieceData.color == ClientState.playerColor then
            Logger.info(string.format("Selected piece at [%d,%d], type: %d", row, col, pieceData.type))
            SoundManager.playSelectSound()
            ClientState.selectedSquare = {row = row, col = col}
            -- Calculate valid moves locally for visual feedback
            local engine = Shared.ChessEngine.new()
            engine:deserialize(ClientState.gameState)
            ClientState.validMoves = engine:getValidMoves(row, col)
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

    updateBoardVisuals(boardFolder, squares, ClientState.gameState)
end

-- Create main menu UI
local function createMainMenu()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MainMenu"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "MenuFrame"
    frame.Size = UDim2.new(0, 300, 0, 400)
    frame.Position = UDim2.new(0.5, -150, 0.5, -200)
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
            frame.Visible = false
        end)

        buttonY = buttonY + 50
    end

    return screenGui
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

    return screenGui
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

    print("🐱 [DEBUG] Creating board...")
    local boardFolder, squares = createBoard()
    print("🐱 [DEBUG] Board created! Creating menu...")
    local mainMenu = createMainMenu()
    print("🐱 [DEBUG] Menu created! Creating HUD...")
    local gameHUD = createGameHUD()
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
        ClientState.isMyTurn = gameState.currentTurn == ClientState.playerColor

        -- Update HUD (with nil check)
        if not gameHUD then
            warn("🐱 [ERROR] gameHUD is nil!")
            return
        end
        gameHUD.Enabled = true

        -- Update color indicator
        local colorLabel = gameHUD:FindFirstChild("ColorLabel")
        if colorLabel then
            if ClientState.playerColor == Constants.Color.WHITE then
                colorLabel.Text = "You are: WHITE"
                colorLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
                colorLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
            else
                colorLabel.Text = "You are: BLACK"
                colorLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end

        local turnLabel = gameHUD:FindFirstChild("TurnLabel")
        if turnLabel then
            if gameState.gameState == Constants.GameState.IN_PROGRESS then
                if ClientState.isMyTurn then
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
            elseif gameState.gameState == Constants.GameState.BLACK_WIN then
                local won = ClientState.playerColor == Constants.Color.BLACK
                turnLabel.Text = won and "🎉 YOU WIN! 🎉" or "😿 You Lose..."
                turnLabel.TextColor3 = won and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(200, 100, 100)
            elseif gameState.gameState == Constants.GameState.STALEMATE then
                turnLabel.Text = "😺 Stalemate - Draw!"
                turnLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            elseif gameState.gameState == Constants.GameState.DRAW then
                turnLabel.Text = "😺 Draw!"
                turnLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end

        -- Skip animations on initial game setup
        local skipAnimation = ClientState.gameState == nil
        updateBoardVisuals(boardFolder, squares, gameState, skipAnimation)
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
            print("🐱 [CLICK] Mouse clicked at screen position: " .. input.Position.X .. "," .. input.Position.Y)

            local camera = workspace.CurrentCamera
            local mousePos = UserInputService:GetMouseLocation()
            local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

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

    -- Handle hover effects
    local RunService = game:GetService("RunService")
    RunService.RenderStepped:Connect(function()
        if not ClientState.isMyTurn or not ClientState.gameState then
            -- Clear hover effect
            if ClientState.hoverEffect then
                ClientState.hoverEffect:Destroy()
                ClientState.hoverEffect = nil
            end
            ClientState.hoveredSquare = nil
            return
        end

        local mouse = LocalPlayer:GetMouse()
        local camera = workspace.CurrentCamera
        local mousePos = UserInputService:GetMouseLocation()

        local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Include
        raycastParams.FilterDescendantsInstances = {boardFolder}

        local result = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)

        if result and result.Instance then
            local row = result.Instance:GetAttribute("Row")
            local col = result.Instance:GetAttribute("Col")

            if row and col then
                -- Check if this square has our piece
                local pieceData = ClientState.gameState.board[row] and ClientState.gameState.board[row][col]
                local isOurPiece = pieceData and pieceData.color == ClientState.playerColor

                -- Only show hover on our pieces
                if isOurPiece and (not ClientState.hoveredSquare or ClientState.hoveredSquare.row ~= row or ClientState.hoveredSquare.col ~= col) then
                    ClientState.hoveredSquare = {row = row, col = col}

                    -- Clear old hover effect
                    if ClientState.hoverEffect then
                        ClientState.hoverEffect:Destroy()
                    end

                    -- Add new hover effect
                    local square = squares[row][col]
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
                end
            else
                -- Not hovering over a square
                ClientState.hoveredSquare = nil
                if ClientState.hoverEffect then
                    ClientState.hoverEffect:Destroy()
                    ClientState.hoverEffect = nil
                end
                mouse.Icon = ""
            end
        else
            -- Not hovering over board
            ClientState.hoveredSquare = nil
            if ClientState.hoverEffect then
                ClientState.hoverEffect:Destroy()
                ClientState.hoverEffect = nil
            end
            mouse.Icon = ""
        end
    end)

    print("🐱 Claws & Paws client initialized! Meow!")
end

print("🐱 [DEBUG] About to call initialize()...")
initialize()
print("🐱 [DEBUG] initialize() returned!")
