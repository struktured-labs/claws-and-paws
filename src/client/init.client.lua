--[[
    Claws & Paws - Client Entry Point
    Handles UI, input, and local game rendering
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = require(ReplicatedStorage.Shared)
local Constants = Shared.Constants
local MusicManager = require(script.MusicManager)
local ParticleEffects = require(script.ParticleEffects)
local SoundManager = require(script.SoundManager)
local BattleAnimations = require(script.BattleAnimations)
local AssetLoader = require(script.AssetLoader)
local TutorialManager = require(script.TutorialManager)
local CameraController = require(script.CameraController)

local LocalPlayer = Players.LocalPlayer

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestMatchEvent = Remotes:WaitForChild("RequestMatch")
local CancelMatchEvent = Remotes:WaitForChild("CancelMatch")
local MakeMoveEvent = Remotes:WaitForChild("MakeMove")
local ResignEvent = Remotes:WaitForChild("Resign")
local SendGestureEvent = Remotes:WaitForChild("SendGesture")
local RequestAIGameEvent = Remotes:WaitForChild("RequestAIGame")
local GetGameStateFunction = Remotes:WaitForChild("GetGameState")

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
    squareSize = 8, -- BIGGER board (was 4)
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

-- Create the chess board
local function createBoard()
    local boardFolder = Instance.new("Folder")
    boardFolder.Name = "ChessBoard"
    boardFolder.Parent = workspace

    local squares = {}

    for row = 1, Constants.BOARD_SIZE do
        squares[row] = {}
        for col = 1, Constants.BOARD_SIZE do
            local square = Instance.new("Part")
            square.Name = string.format("Square_%d_%d", row, col)
            square.Size = Vector3.new(BoardConfig.squareSize, 0.5, BoardConfig.squareSize)
            square.Position = Vector3.new(
                (col - 3.5) * BoardConfig.squareSize,
                0.25,
                (row - 3.5) * BoardConfig.squareSize
            )
            square.Anchored = true
            square.CanCollide = true

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

            -- Store row/col for click detection
            square:SetAttribute("Row", row)
            square:SetAttribute("Col", col)

            square.Parent = boardFolder
            squares[row][col] = square
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
local function updateBoardVisuals(boardFolder, squares, gameState)
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
        return
    end

    -- Place pieces
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local pieceData = gameState.board[row] and gameState.board[row][col]
            if pieceData then
                local pieceModel = createPieceModel(pieceData.type, pieceData.color)
                pieceModel.Name = string.format("Piece_%d_%d", row, col)

                local targetPos = Vector3.new(
                    (col - 3.5) * BoardConfig.squareSize,
                    3.5, -- Higher for bigger pieces
                    (row - 3.5) * BoardConfig.squareSize
                )

                -- Handle both Part and Model positioning
                if pieceModel:IsA("Model") then
                    pieceModel:MoveTo(targetPos)
                else
                    pieceModel.Position = targetPos
                end

                pieceModel.Parent = boardFolder
            end
        end
    end

    -- Update square colors
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local square = squares[row][col]
            local baseColor = ((row + col) % 2 == 0) and BoardConfig.lightColor or BoardConfig.darkColor
            square.Color = baseColor
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
        sq.Color = BoardConfig.validMoveColor
        ParticleEffects.highlightSquare(sq, Color3.fromRGB(144, 238, 144))
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

        print(string.format("🎯 Clicked square [%d,%d], Valid move: %s", row, col, tostring(isValidMove)))

        if isValidMove then
            -- Check if this is a capture
            local targetPiece = ClientState.gameState.board[row] and ClientState.gameState.board[row][col]
            local isCapture = targetPiece ~= nil

            if isCapture then
                -- Play capture sound and effect
                SoundManager.playCaptureSound()
                local targetPos = Vector3.new(
                    (col - 3.5) * BoardConfig.squareSize,
                    3.5, -- Higher for bigger pieces
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
            print(string.format("📤 Sending move: [%d,%d] → [%d,%d]",
                ClientState.selectedSquare.row, ClientState.selectedSquare.col, row, col))

            MakeMoveEvent:FireServer(
                ClientState.currentGameId,
                ClientState.selectedSquare.row,
                ClientState.selectedSquare.col,
                row,
                col
            )
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
            print(string.format("✨ Selected piece at [%d,%d], type: %d", row, col, pieceData.type))
            SoundManager.playSelectSound()
            ClientState.selectedSquare = {row = row, col = col}
            -- Calculate valid moves locally for visual feedback
            local engine = Shared.ChessEngine.new()
            engine:deserialize(ClientState.gameState)
            ClientState.validMoves = engine:getValidMoves(row, col)
            print(string.format("📋 Found %d valid moves", #ClientState.validMoves))
        else
            print(string.format("❌ Cannot select square [%d,%d] - not your piece or empty", row, col))
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
    -- Hide player character and move spawn away from board
    task.spawn(function()
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

        -- Move player far away from the board
        if character:FindFirstChild("HumanoidRootPart") then
            character.HumanoidRootPart.CFrame = CFrame.new(0, -100, 0) -- Below the board
        end

        -- Make character invisible
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
    end)

    -- Remove spawn location if it exists
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        spawnLocation:Destroy()
    end

    -- Remove any default baseplate
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        baseplate.Transparency = 1 -- Make invisible instead of deleting
    end

    -- Set up camera
    CameraController.setupGameCamera()
    CameraController.enableCameraRotation()

    local boardFolder, squares = createBoard()
    local mainMenu = createMainMenu()
    local gameHUD = createGameHUD()

    -- Create help button
    TutorialManager.createHelpButton()

    -- Show tutorial after brief delay
    task.delay(2, function()
        TutorialManager.showInitialTutorial()
    end)

    -- Handle game state updates
    GetGameStateFunction.OnClientInvoke = function(gameState)
        ClientState.gameState = gameState
        ClientState.currentGameId = gameState.gameId

        -- Determine player color (white is always player1/first joiner)
        -- For simplicity, assume white for now - server should send this
        ClientState.playerColor = Constants.Color.WHITE
        ClientState.isMyTurn = gameState.currentTurn == ClientState.playerColor

        -- Update HUD
        gameHUD.Enabled = true
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

        updateBoardVisuals(boardFolder, squares, gameState)
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
            local camera = workspace.CurrentCamera
            local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)

            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Include
            raycastParams.FilterDescendantsInstances = {boardFolder}

            local result = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)
            if result and result.Instance then
                local row = result.Instance:GetAttribute("Row")
                local col = result.Instance:GetAttribute("Col")
                if row and col then
                    onSquareClicked(row, col, boardFolder, squares)
                end
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

initialize()
