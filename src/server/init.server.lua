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
local PlayerDataStore = require(script.PlayerDataStore)

-- Initialize player data persistence
PlayerDataStore.init()

-- Check if ChessAI loaded
if ChessAI then
    if Constants.DEBUG then print("🐱 [SERVER] ChessAI loaded successfully!") end
else
    if Constants.DEBUG then warn("🐱 [SERVER] ChessAI is nil! AI games won't work.") end
end

-- RemoteEvents for client-server communication (create BEFORE LogCollector)
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

-- Initialize logging system (will find existing Remotes folder)
LogCollector.init()

-- Active games storage
local ActiveGames = {}

-- Valid game modes for input validation
local VALID_GAME_MODES = {}
for _, mode in pairs(Constants.GameMode) do
    VALID_GAME_MODES[mode] = true
end

-- Valid promotion pieces
local VALID_PROMOTIONS = {
    [Constants.PieceType.QUEEN] = true,
    [Constants.PieceType.ROOK] = true,
    [Constants.PieceType.BISHOP] = true,
    [Constants.PieceType.KNIGHT] = true,
}

-- Input validation helpers
local function isValidCoord(n)
    return type(n) == "number" and n >= 1 and n <= Constants.BOARD_SIZE and n == math.floor(n)
end

local function isValidGameMode(mode)
    return type(mode) == "string" and VALID_GAME_MODES[mode] == true
end

local function isValidPromotionPiece(piece)
    return piece == nil or VALID_PROMOTIONS[piece] == true
end

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
local RequestAIvsAIGameEvent = createRemote("RequestAIvsAIGame", "RemoteEvent")

-- Create RemoteFunctions
local GetGameStateFunction = createRemote("GetGameState", "RemoteFunction")

-- Game session class
local GameSession = {}
GameSession.__index = GameSession

function GameSession.new(player1, player2, gameMode, isAI, isAIvsAI, whiteDifficulty, blackDifficulty)
    local self = setmetatable({}, GameSession)

    self.id = game:GetService("HttpService"):GenerateGUID(false)
    self.player1 = player1  -- White (or spectator for AI vs AI)
    self.player2 = player2  -- Black (nil if AI)
    self.isAI = isAI or false
    self.isAIvsAI = isAIvsAI or false  -- Both sides are AI
    self.aiDifficulty = gameMode  -- Legacy: single AI difficulty
    self.whiteDifficulty = whiteDifficulty or gameMode  -- White AI difficulty
    self.blackDifficulty = blackDifficulty or gameMode  -- Black AI difficulty
    self.gameMode = gameMode
    self.engine = ChessEngine.new()
    self.engine:setupBoard()
    self.startTime = tick()
    self.lastMoveTime = tick()
    self.aiMoveDelay = 1.0  -- Delay between AI moves for watchability

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

-- Update time remaining based on elapsed time since last move
-- Uses tick() for sub-second precision; idempotent (safe to call multiple times)
function GameSession:updateTimeRemaining()
    if self.engine.gameState ~= Constants.GameState.IN_PROGRESS then
        return
    end

    local now = tick()
    local elapsed = now - self.lastMoveTime
    local currentPlayer = self.engine.currentTurn

    -- Deduct time from current player
    self.timeRemaining[currentPlayer] = math.max(0, self.timeRemaining[currentPlayer] - elapsed)

    -- Always advance lastMoveTime so repeated calls don't double-deduct
    self.lastMoveTime = now

    -- Check for timeout
    if self.timeRemaining[currentPlayer] <= 0 then
        if currentPlayer == Constants.Color.WHITE then
            self.engine.gameState = Constants.GameState.BLACK_WIN
        else
            self.engine.gameState = Constants.GameState.WHITE_WIN
        end
        if Constants.DEBUG then print(string.format("🐱 [SERVER] Game ended by timeout! %s ran out of time.",
            currentPlayer == Constants.Color.WHITE and "White" or "Black")) end
    end
end

-- Schedule cleanup of a finished game after a short delay
local function scheduleGameCleanup(gameId, delay)
    task.delay(delay or 5, function()
        if ActiveGames[gameId] then
            local session = ActiveGames[gameId]
            if session.engine.gameState ~= Constants.GameState.IN_PROGRESS
                and session.engine.gameState ~= Constants.GameState.WAITING then
                ActiveGames[gameId] = nil
                if Constants.DEBUG then print(string.format("🐱 [SERVER] Cleaned up finished game %s", gameId)) end
            end
        end
    end)
end

function GameSession:broadcastState()
    -- Update time before broadcasting
    self:updateTimeRemaining()

    local state = self.engine:serialize()
    state.timeRemaining = self.timeRemaining
    state.gameId = self.id
    state.playerColor = Constants.Color.WHITE -- Always white for AI games
    state.isAIvsAI = self.isAIvsAI  -- Let client know if this is AI vs AI
    state.whiteDifficulty = self.whiteDifficulty
    state.blackDifficulty = self.blackDifficulty
    state.lastMoveTime = self.lastMoveTime  -- Send for client-side interpolation

    -- Include check state so client can play warning sounds
    state.inCheck = {
        [Constants.Color.WHITE] = self.engine:isInCheck(Constants.Color.WHITE),
        [Constants.Color.BLACK] = self.engine:isInCheck(Constants.Color.BLACK),
    }

    -- Count pieces in serialized state (flat array format)
    local pieceCount = #state.pieces

    -- CRITICAL BUG CHECK: If we're missing pieces, something is very wrong!
    if pieceCount < 12 then
        if Constants.DEBUG then warn(string.format("🐱 [SERVER] ⚠️ CRITICAL: Only %d pieces in state! Expected at least 12.", pieceCount)) end
    end

    if Constants.DEBUG then print(string.format("🐱 [SERVER] Broadcasting state with %d pieces (flat array)", pieceCount)) end

    if self.player1 then
        GetGameStateFunction:InvokeClient(self.player1, state)
    end
    if self.player2 and not self.isAI and not self.isAIvsAI then
        GetGameStateFunction:InvokeClient(self.player2, state)
    end

    -- Schedule cleanup if game is over
    if self.engine.gameState ~= Constants.GameState.IN_PROGRESS
        and self.engine.gameState ~= Constants.GameState.WAITING then
        scheduleGameCleanup(self.id)
    end
end

-- Start a background task that checks the clock every second and ends the game on timeout
function GameSession:startTimeoutMonitor()
    task.spawn(function()
        while self.engine.gameState == Constants.GameState.IN_PROGRESS do
            task.wait(1)
            self:updateTimeRemaining()
            if self.engine.gameState ~= Constants.GameState.IN_PROGRESS then
                if Constants.DEBUG then print("🐱 [SERVER] Timeout monitor detected game end, broadcasting...") end
                self:broadcastState()
                break
            end
        end
    end)
end

-- Start AI vs AI game loop
function GameSession:startAIvsAILoop()
    if not self.isAIvsAI then return end

    if Constants.DEBUG then print("🐱 [SERVER] Starting AI vs AI game loop") end

    task.spawn(function()
        while self.engine.gameState == Constants.GameState.IN_PROGRESS do
            task.wait(self.aiMoveDelay)

            if self.engine.gameState ~= Constants.GameState.IN_PROGRESS then
                break
            end

            -- Check timeout before AI computation
            self:updateTimeRemaining()
            if self.engine.gameState ~= Constants.GameState.IN_PROGRESS then
                self:broadcastState()
                break
            end

            -- Determine which AI should move
            local currentDifficulty = self.engine.currentTurn == Constants.Color.WHITE
                and self.whiteDifficulty
                or self.blackDifficulty

            local turnName = self.engine.currentTurn == Constants.Color.WHITE and "White" or "Black"
            if Constants.DEBUG then print(string.format("🐱 [SERVER] AI vs AI: %s's turn (difficulty: %s)", turnName, tostring(currentDifficulty))) end

            if ChessAI and ChessAI.getBestMove then
                local aiMove = ChessAI.getBestMove(self.engine, currentDifficulty)
                if aiMove then
                    local success = self.engine:makeMove(
                        aiMove.from.row, aiMove.from.col,
                        aiMove.to.row, aiMove.to.col
                    )
                    if success then
                        if Constants.DEBUG then print(string.format("🐱 [SERVER] AI vs AI: %s moved [%d,%d] → [%d,%d]",
                            turnName, aiMove.from.row, aiMove.from.col, aiMove.to.row, aiMove.to.col)) end
                        self:broadcastState()
                    else
                        if Constants.DEBUG then warn("🐱 [SERVER] AI vs AI: Move failed!") end
                        break
                    end
                else
                    if Constants.DEBUG then warn("🐱 [SERVER] AI vs AI: No valid move found!") end
                    break
                end
            else
                if Constants.DEBUG then warn("🐱 [SERVER] ChessAI not available!") end
                break
            end
        end

        if Constants.DEBUG then print("🐱 [SERVER] AI vs AI game ended with state: " .. tostring(self.engine.gameState)) end
    end)
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
            session:startTimeoutMonitor()
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
    session:startTimeoutMonitor()
    return session
end

-- Handle move request
local function handleMove(player, gameId, fromRow, fromCol, toRow, toCol, promotionPiece)
    -- Validate inputs
    if type(gameId) ~= "string" then
        return false, "Invalid game ID"
    end
    if not isValidCoord(fromRow) or not isValidCoord(fromCol)
        or not isValidCoord(toRow) or not isValidCoord(toCol) then
        return false, "Invalid coordinates"
    end
    if not isValidPromotionPiece(promotionPiece) then
        return false, "Invalid promotion piece"
    end

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
        -- updateTimeRemaining is idempotent (advances lastMoveTime internally)
        session:updateTimeRemaining()
        session:broadcastState()

        -- AI response if playing against AI
        if session.isAI and session.engine.gameState == Constants.GameState.IN_PROGRESS then
            task.delay(0.5, function()
                -- Check timeout before AI computation
                session:updateTimeRemaining()
                if session.engine.gameState ~= Constants.GameState.IN_PROGRESS then
                    session:broadcastState()
                    return
                end
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
                    if Constants.DEBUG then warn("🐱 [SERVER] ChessAI not available for AI move!") end
                end
            end)
        end
    end

    return success, result
end

-- Connect remote events
RequestMatchEvent.OnServerEvent:Connect(function(player, gameMode)
    if not isValidGameMode(gameMode) then return end
    local session = findOrCreateGame(player, gameMode)
    if session then
        session:broadcastState()
    end
end)

CancelMatchEvent.OnServerEvent:Connect(function(player, gameMode)
    if not isValidGameMode(gameMode) then return end
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
    if not isValidGameMode(difficulty) then return end
    local session = createAIGame(player, difficulty)
    session:broadcastState()
end)

-- Create AI vs AI game where player is just a spectator
RequestAIvsAIGameEvent.OnServerEvent:Connect(function(player, whiteDifficulty, blackDifficulty)
    if not isValidGameMode(whiteDifficulty) or not isValidGameMode(blackDifficulty) then return end
    if Constants.DEBUG then print(string.format("🐱 [SERVER] Creating AI vs AI game: White=%s, Black=%s",
        tostring(whiteDifficulty), tostring(blackDifficulty))) end

    -- Create session with player as spectator (player1 but not playing)
    local session = GameSession.new(player, nil, whiteDifficulty, false, true, whiteDifficulty, blackDifficulty)
    ActiveGames[session.id] = session

    -- Start the timeout monitor
    session:startTimeoutMonitor()

    -- Broadcast initial state
    session:broadcastState()

    -- Start the AI vs AI loop
    session:startAIvsAILoop()
end)

MakeMoveEvent.OnServerEvent:Connect(function(player, gameId, fromRow, fromCol, toRow, toCol, promotionPiece)
    handleMove(player, gameId, fromRow, fromCol, toRow, toCol, promotionPiece)
end)

ResignEvent.OnServerEvent:Connect(function(player, gameId)
    if type(gameId) ~= "string" then return end
    local session = ActiveGames[gameId]
    if not session then return end

    local playerColor = session:getPlayerColor(player)
    if not playerColor then return end

    if playerColor == Constants.Color.WHITE then
        session.engine.gameState = Constants.GameState.BLACK_WIN
    else
        session.engine.gameState = Constants.GameState.WHITE_WIN
    end

    session:broadcastState()
    scheduleGameCleanup(gameId)
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
