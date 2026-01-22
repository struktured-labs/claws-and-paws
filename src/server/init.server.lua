--[[
    Claws & Paws - Server Entry Point
    Handles game state, matchmaking, and authoritative game logic
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = require(ReplicatedStorage.Shared)
local Constants = Shared.Constants
local ChessEngine = Shared.ChessEngine
local ChessAI = Shared.ChessAI
local LogCollector = require(script.LogCollector)

-- Check if ChessAI loaded
if ChessAI then
    print("🐱 [SERVER] ChessAI loaded successfully!")
else
    warn("🐱 [SERVER] ChessAI is nil! AI games won't work.")
end

-- RemoteEvents for client-server communication (create BEFORE LogCollector)
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

-- Initialize logging system (will find existing Remotes folder)
LogCollector.init()

-- Active games storage
local ActiveGames = {}

-- Player matchmaking queue
local MatchmakingQueue = {
    [Constants.GameMode.CASUAL] = {},
    [Constants.GameMode.RANKED] = {},
}

local function createRemote(name, className)
    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = Remotes
    return remote
end

-- Create RemoteEvents
local RequestMatchEvent = createRemote("RequestMatch", "RemoteEvent")
local CancelMatchEvent = createRemote("CancelMatch", "RemoteEvent")
local MakeMoveEvent = createRemote("MakeMove", "RemoteEvent")
local ResignEvent = createRemote("Resign", "RemoteEvent")
local OfferDrawEvent = createRemote("OfferDraw", "RemoteEvent")
local SendGestureEvent = createRemote("SendGesture", "RemoteEvent")
local RequestAIGameEvent = createRemote("RequestAIGame", "RemoteEvent")

-- Create RemoteFunctions
local GetGameStateFunction = createRemote("GetGameState", "RemoteFunction")

-- Game session class
local GameSession = {}
GameSession.__index = GameSession

function GameSession.new(player1, player2, gameMode, isAI)
    local self = setmetatable({}, GameSession)

    self.id = game:GetService("HttpService"):GenerateGUID(false)
    self.player1 = player1  -- White
    self.player2 = player2  -- Black (nil if AI)
    self.isAI = isAI or false
    self.aiDifficulty = gameMode
    self.gameMode = gameMode
    self.engine = ChessEngine.new()
    self.engine:setupBoard()
    self.startTime = os.time()
    self.lastMoveTime = os.time()

    -- Time control
    local timeLimit = Constants.TimeControl[gameMode] or 600
    self.timeRemaining = {
        [Constants.Color.WHITE] = timeLimit,
        [Constants.Color.BLACK] = timeLimit,
    }

    return self
end

function GameSession:getPlayerColor(player)
    if player == self.player1 then
        return Constants.Color.WHITE
    elseif player == self.player2 then
        return Constants.Color.BLACK
    end
    return nil
end

function GameSession:getCurrentPlayer()
    if self.engine.currentTurn == Constants.Color.WHITE then
        return self.player1
    else
        return self.player2
    end
end

function GameSession:broadcastState()
    local state = self.engine:serialize()
    state.timeRemaining = self.timeRemaining
    state.gameId = self.id
    state.playerColor = Constants.Color.WHITE -- Always white for AI games

    -- Debug: Count and LOG pieces being sent
    local pieceCount = 0
    print("🐱 [SERVER] Pieces in state BEFORE broadcast:")
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            if state.board[row] and state.board[row][col] then
                local piece = state.board[row][col]
                print(string.format("🐱 [SERVER]   [%d,%d]: type=%d color=%d", row, col, piece.type, piece.color))
                pieceCount = pieceCount + 1
            end
        end
    end
    print("🐱 [SERVER] Broadcasting state with " .. pieceCount .. " pieces")

    if self.player1 then
        GetGameStateFunction:InvokeClient(self.player1, state)
    end
    if self.player2 and not self.isAI then
        GetGameStateFunction:InvokeClient(self.player2, state)
    end
end

-- Find or create game for player
local function findOrCreateGame(player, gameMode)
    -- Check if player already in a game
    for gameId, session in pairs(ActiveGames) do
        if session.player1 == player or session.player2 == player then
            return session
        end
    end

    -- Check matchmaking queue
    local queue = MatchmakingQueue[gameMode]
    if queue and #queue > 0 then
        local opponent = table.remove(queue, 1)
        if opponent and opponent.Parent then  -- Check player still connected
            local session = GameSession.new(opponent, player, gameMode, false)
            ActiveGames[session.id] = session
            return session
        end
    end

    -- Add to queue
    if queue then
        table.insert(queue, player)
    end

    return nil
end

-- Create AI game
local function createAIGame(player, difficulty)
    local session = GameSession.new(player, nil, difficulty, true)
    ActiveGames[session.id] = session
    return session
end

-- Handle move request
local function handleMove(player, gameId, fromRow, fromCol, toRow, toCol, promotionPiece)
    local session = ActiveGames[gameId]
    if not session then
        return false, "Game not found"
    end

    local playerColor = session:getPlayerColor(player)
    if not playerColor then
        return false, "Not in this game"
    end

    if session.engine.currentTurn ~= playerColor then
        return false, "Not your turn"
    end

    local success, result = session.engine:makeMove(fromRow, fromCol, toRow, toCol, promotionPiece)

    if success then
        session.lastMoveTime = os.time()
        session:broadcastState()

        -- AI response if playing against AI
        if session.isAI and session.engine.gameState == Constants.GameState.IN_PROGRESS then
            task.delay(0.5, function()
                if ChessAI and ChessAI.getBestMove then
                    local aiMove = ChessAI.getBestMove(session.engine, session.aiDifficulty)
                    if aiMove then
                        session.engine:makeMove(
                            aiMove.from.row, aiMove.from.col,
                            aiMove.to.row, aiMove.to.col
                        )
                        session:broadcastState()
                    end
                else
                    warn("🐱 [SERVER] ChessAI not available for AI move!")
                end
            end)
        end
    end

    return success, result
end

-- Connect remote events
RequestMatchEvent.OnServerEvent:Connect(function(player, gameMode)
    local session = findOrCreateGame(player, gameMode)
    if session then
        session:broadcastState()
    end
end)

CancelMatchEvent.OnServerEvent:Connect(function(player, gameMode)
    local queue = MatchmakingQueue[gameMode]
    if queue then
        for i, queuedPlayer in ipairs(queue) do
            if queuedPlayer == player then
                table.remove(queue, i)
                break
            end
        end
    end
end)

RequestAIGameEvent.OnServerEvent:Connect(function(player, difficulty)
    local session = createAIGame(player, difficulty)
    session:broadcastState()
end)

MakeMoveEvent.OnServerEvent:Connect(function(player, gameId, fromRow, fromCol, toRow, toCol, promotionPiece)
    handleMove(player, gameId, fromRow, fromCol, toRow, toCol, promotionPiece)
end)

ResignEvent.OnServerEvent:Connect(function(player, gameId)
    local session = ActiveGames[gameId]
    if not session then return end

    local playerColor = session:getPlayerColor(player)
    if playerColor == Constants.Color.WHITE then
        session.engine.gameState = Constants.GameState.BLACK_WIN
    else
        session.engine.gameState = Constants.GameState.WHITE_WIN
    end

    session:broadcastState()
end)

SendGestureEvent.OnServerEvent:Connect(function(player, gameId, gesture)
    local session = ActiveGames[gameId]
    if not session then return end

    -- Validate gesture
    local validGesture = false
    for _, g in pairs(Constants.CatGesture) do
        if g == gesture then
            validGesture = true
            break
        end
    end

    if not validGesture then return end

    -- Send to opponent
    local opponent = nil
    if player == session.player1 then
        opponent = session.player2
    elseif player == session.player2 then
        opponent = session.player1
    end

    if opponent then
        SendGestureEvent:FireClient(opponent, gesture)
    end
end)

GetGameStateFunction.OnServerInvoke = function(player, gameId)
    local session = ActiveGames[gameId]
    if session then
        local state = session.engine:serialize()
        state.timeRemaining = session.timeRemaining
        state.gameId = session.id
        return state
    end
    return nil
end

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
    -- Remove from matchmaking queues
    for _, queue in pairs(MatchmakingQueue) do
        for i, queuedPlayer in ipairs(queue) do
            if queuedPlayer == player then
                table.remove(queue, i)
                break
            end
        end
    end

    -- Handle active games
    for gameId, session in pairs(ActiveGames) do
        if session.player1 == player or session.player2 == player then
            -- Mark as disconnect win for opponent
            if session.player1 == player then
                session.engine.gameState = Constants.GameState.BLACK_WIN
            else
                session.engine.gameState = Constants.GameState.WHITE_WIN
            end
            session:broadcastState()
        end
    end
end)

print("Claws & Paws server initialized!")
