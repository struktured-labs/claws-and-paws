--[[
    Claws & Paws - Chess Engine
    Core game logic for the 6x6 cat chess variant
]]

local Constants = require(script.Parent.Constants)

local ChessEngine = {}
ChessEngine.__index = ChessEngine

-- Create a new piece
local function createPiece(pieceType, color)
    return {
        type = pieceType,
        color = color,
        hasMoved = false,
    }
end

-- Create a new game instance
function ChessEngine.new()
    local self = setmetatable({}, ChessEngine)

    self.board = {}
    self.currentTurn = Constants.Color.WHITE
    self.gameState = Constants.GameState.WAITING
    self.moveHistory = {}
    self.capturedPieces = {
        [Constants.Color.WHITE] = {},
        [Constants.Color.BLACK] = {},
    }
    self.halfMoveClock = 0  -- For 50-move rule
    self.positionHistory = {} -- For threefold repetition (hash → count)

    return self
end

-- Generate a simple hash of the current board position + turn
function ChessEngine:getPositionHash()
    local parts = {}
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local piece = self.board[row][col]
            if piece then
                -- Encode: row, col, type, color as a compact string segment
                table.insert(parts, string.format("%d%d%d%d", row, col, piece.type, piece.color))
            end
        end
    end
    -- Include whose turn it is
    table.insert(parts, tostring(self.currentTurn))
    return table.concat(parts, ",")
end

-- Record current position and return how many times it has occurred
function ChessEngine:recordPosition()
    local hash = self:getPositionHash()
    self.positionHistory[hash] = (self.positionHistory[hash] or 0) + 1
    return self.positionHistory[hash]
end

-- Check for insufficient material (automatic draw)
function ChessEngine:hasInsufficientMaterial()
    local whitePieces = {}
    local blackPieces = {}

    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local piece = self.board[row][col]
            if piece then
                if piece.color == Constants.Color.WHITE then
                    table.insert(whitePieces, piece.type)
                else
                    table.insert(blackPieces, piece.type)
                end
            end
        end
    end

    -- King vs King
    if #whitePieces == 1 and #blackPieces == 1 then
        return true
    end

    -- King + minor piece vs King
    local function isKingPlusMinor(pieces)
        if #pieces ~= 2 then return false end
        for _, t in ipairs(pieces) do
            if t == Constants.PieceType.BISHOP or t == Constants.PieceType.KNIGHT then
                return true
            end
        end
        return false
    end

    if (#whitePieces == 1 and isKingPlusMinor(blackPieces))
        or (#blackPieces == 1 and isKingPlusMinor(whitePieces)) then
        return true
    end

    return false
end

-- Initialize board with Fischer Random setup
function ChessEngine:setupBoard(seed)
    -- Clear board
    for row = 1, Constants.BOARD_SIZE do
        self.board[row] = {}
        for col = 1, Constants.BOARD_SIZE do
            self.board[row][col] = nil
        end
    end

    -- Set up pawns (row 2 for white, row 5 for black)
    for col = 1, Constants.BOARD_SIZE do
        self.board[2][col] = createPiece(Constants.PieceType.PAWN, Constants.Color.WHITE)
        self.board[5][col] = createPiece(Constants.PieceType.PAWN, Constants.Color.BLACK)
    end

    -- Generate Fischer Random back rank
    local backRank = self:generateFischerRandom(seed)

    -- Place white pieces (row 1)
    for col, pieceType in ipairs(backRank) do
        self.board[1][col] = createPiece(pieceType, Constants.Color.WHITE)
    end

    -- Place black pieces (row 6) - mirror of white
    for col, pieceType in ipairs(backRank) do
        self.board[6][col] = createPiece(pieceType, Constants.Color.BLACK)
    end

    self.gameState = Constants.GameState.IN_PROGRESS
    self.currentTurn = Constants.Color.WHITE

    -- Record initial position for threefold repetition detection
    self:recordPosition()
end

-- Generate Fischer Random arrangement for 6 pieces
-- Pieces: K, Q, R, B, B, N (1 King, 1 Queen, 1 Rook, 2 Bishops, 1 Knight)
function ChessEngine:generateFischerRandom(seed)
    if seed then
        math.randomseed(seed)
    else
        math.randomseed(os.time())
    end

    local positions = {1, 2, 3, 4, 5, 6}
    local result = {}

    -- Helper to pick and remove random position
    local function pickPosition()
        local idx = math.random(1, #positions)
        local pos = positions[idx]
        table.remove(positions, idx)
        return pos
    end

    -- Place bishops on opposite colors (one odd, one even)
    local oddPositions = {1, 3, 5}
    local evenPositions = {2, 4, 6}

    local bishop1Pos = oddPositions[math.random(1, #oddPositions)]
    local bishop2Pos = evenPositions[math.random(1, #evenPositions)]

    -- Remove bishop positions from available
    for i = #positions, 1, -1 do
        if positions[i] == bishop1Pos or positions[i] == bishop2Pos then
            table.remove(positions, i)
        end
    end

    -- Place remaining pieces randomly
    local kingPos = pickPosition()
    local queenPos = pickPosition()
    local rookPos = pickPosition()
    local knightPos = pickPosition()

    -- Build result array
    for i = 1, 6 do
        if i == bishop1Pos or i == bishop2Pos then
            result[i] = Constants.PieceType.BISHOP
        elseif i == kingPos then
            result[i] = Constants.PieceType.KING
        elseif i == queenPos then
            result[i] = Constants.PieceType.QUEEN
        elseif i == rookPos then
            result[i] = Constants.PieceType.ROOK
        elseif i == knightPos then
            result[i] = Constants.PieceType.KNIGHT
        end
    end

    return result
end

-- Get piece at position
function ChessEngine:getPiece(row, col)
    if row < 1 or row > Constants.BOARD_SIZE or col < 1 or col > Constants.BOARD_SIZE then
        return nil
    end
    return self.board[row][col]
end

-- Check if position is on board
function ChessEngine:isOnBoard(row, col)
    return row >= 1 and row <= Constants.BOARD_SIZE and col >= 1 and col <= Constants.BOARD_SIZE
end

-- Get all valid moves for a piece at position
function ChessEngine:getValidMoves(row, col)
    local piece = self:getPiece(row, col)
    if not piece then
        if Constants.DEBUG then print("🐱 [ENGINE DEBUG] No piece at [" .. row .. "," .. col .. "]") end
        return {}
    end

    local moves = self:getPseudoLegalMoves(row, col)
    if Constants.DEBUG then print("🐱 [ENGINE DEBUG] getPseudoLegalMoves returned " .. #moves .. " moves for piece at [" .. row .. "," .. col .. "]") end
    local validMoves = {}

    -- Filter out moves that leave king in check
    for i, move in ipairs(moves) do
        local isLegal = self:isMoveLegal(row, col, move.row, move.col)
        if Constants.DEBUG then print("🐱 [ENGINE DEBUG] Move " .. i .. " to [" .. move.row .. "," .. move.col .. "] legal: " .. tostring(isLegal)) end
        if isLegal then
            table.insert(validMoves, move)
        end
    end

    if Constants.DEBUG then print("🐱 [ENGINE DEBUG] Returning " .. #validMoves .. " valid moves") end
    return validMoves
end

-- Get pseudo-legal moves (doesn't check for leaving king in check)
function ChessEngine:getPseudoLegalMoves(row, col)
    local piece = self:getPiece(row, col)
    if not piece then
        return {}
    end

    local moves = {}
    local pieceType = piece.type

    if pieceType == Constants.PieceType.PAWN then
        moves = self:getPawnMoves(row, col, piece.color)
    elseif pieceType == Constants.PieceType.KNIGHT then
        moves = self:getKnightMoves(row, col, piece.color)
    elseif pieceType == Constants.PieceType.BISHOP then
        moves = self:getBishopMoves(row, col, piece.color)
    elseif pieceType == Constants.PieceType.ROOK then
        moves = self:getRookMoves(row, col, piece.color)
    elseif pieceType == Constants.PieceType.QUEEN then
        moves = self:getQueenMoves(row, col, piece.color)
    elseif pieceType == Constants.PieceType.KING then
        moves = self:getKingMoves(row, col, piece.color)
    elseif pieceType == Constants.PieceType.ARCHBISHOP then
        -- Bishop + Knight moves
        local bishopMoves = self:getBishopMoves(row, col, piece.color)
        local knightMoves = self:getKnightMoves(row, col, piece.color)
        for _, m in ipairs(bishopMoves) do table.insert(moves, m) end
        for _, m in ipairs(knightMoves) do table.insert(moves, m) end
    elseif pieceType == Constants.PieceType.CHANCELLOR then
        -- Rook + Knight moves
        local rookMoves = self:getRookMoves(row, col, piece.color)
        local knightMoves = self:getKnightMoves(row, col, piece.color)
        for _, m in ipairs(rookMoves) do table.insert(moves, m) end
        for _, m in ipairs(knightMoves) do table.insert(moves, m) end
    elseif pieceType == Constants.PieceType.AMAZON then
        -- Queen + Knight moves
        local queenMoves = self:getQueenMoves(row, col, piece.color)
        local knightMoves = self:getKnightMoves(row, col, piece.color)
        for _, m in ipairs(queenMoves) do table.insert(moves, m) end
        for _, m in ipairs(knightMoves) do table.insert(moves, m) end
    end

    return moves
end

-- Pawn moves
function ChessEngine:getPawnMoves(row, col, color)
    local moves = {}
    local direction = (color == Constants.Color.WHITE) and 1 or -1

    -- Forward move (only 1 square in 6x6 chess - no double move)
    local newRow = row + direction
    if self:isOnBoard(newRow, col) and not self:getPiece(newRow, col) then
        table.insert(moves, {row = newRow, col = col})
    end

    -- Diagonal captures
    for _, dc in ipairs({-1, 1}) do
        local captureCol = col + dc
        if self:isOnBoard(newRow, captureCol) then
            local target = self:getPiece(newRow, captureCol)
            if target and target.color ~= color then
                table.insert(moves, {row = newRow, col = captureCol, capture = true})
            end
        end
    end

    -- Note: No en passant in 6x6 chess variant

    return moves
end

-- Knight moves
function ChessEngine:getKnightMoves(row, col, color)
    local moves = {}
    local offsets = {
        {-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
        {1, -2}, {1, 2}, {2, -1}, {2, 1}
    }

    for _, offset in ipairs(offsets) do
        local newRow, newCol = row + offset[1], col + offset[2]
        if self:isOnBoard(newRow, newCol) then
            local target = self:getPiece(newRow, newCol)
            if not target or target.color ~= color then
                table.insert(moves, {row = newRow, col = newCol, capture = target ~= nil})
            end
        end
    end

    return moves
end

-- Sliding piece moves helper
function ChessEngine:getSlidingMoves(row, col, color, directions)
    local moves = {}

    for _, dir in ipairs(directions) do
        local newRow, newCol = row + dir[1], col + dir[2]
        while self:isOnBoard(newRow, newCol) do
            local target = self:getPiece(newRow, newCol)
            if not target then
                table.insert(moves, {row = newRow, col = newCol})
            elseif target.color ~= color then
                table.insert(moves, {row = newRow, col = newCol, capture = true})
                break
            else
                break
            end
            newRow = newRow + dir[1]
            newCol = newCol + dir[2]
        end
    end

    return moves
end

-- Bishop moves
function ChessEngine:getBishopMoves(row, col, color)
    local directions = {{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}
    return self:getSlidingMoves(row, col, color, directions)
end

-- Rook moves
function ChessEngine:getRookMoves(row, col, color)
    local directions = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
    return self:getSlidingMoves(row, col, color, directions)
end

-- Queen moves
function ChessEngine:getQueenMoves(row, col, color)
    local directions = {
        {-1, -1}, {-1, 0}, {-1, 1},
        {0, -1}, {0, 1},
        {1, -1}, {1, 0}, {1, 1}
    }
    return self:getSlidingMoves(row, col, color, directions)
end

-- King moves
function ChessEngine:getKingMoves(row, col, color)
    local moves = {}
    local offsets = {
        {-1, -1}, {-1, 0}, {-1, 1},
        {0, -1}, {0, 1},
        {1, -1}, {1, 0}, {1, 1}
    }

    for _, offset in ipairs(offsets) do
        local newRow, newCol = row + offset[1], col + offset[2]
        if self:isOnBoard(newRow, newCol) then
            local target = self:getPiece(newRow, newCol)
            if not target or target.color ~= color then
                table.insert(moves, {row = newRow, col = newCol, capture = target ~= nil})
            end
        end
    end

    return moves
end

-- Find king position
function ChessEngine:findKing(color)
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local piece = self:getPiece(row, col)
            if piece and piece.type == Constants.PieceType.KING and piece.color == color then
                return row, col
            end
        end
    end
    return nil, nil
end

-- Check if a square is attacked by the opponent
function ChessEngine:isSquareAttacked(row, col, byColor)
    for r = 1, Constants.BOARD_SIZE do
        for c = 1, Constants.BOARD_SIZE do
            local piece = self:getPiece(r, c)
            if piece and piece.color == byColor then
                local moves = self:getPseudoLegalMoves(r, c)
                for _, move in ipairs(moves) do
                    if move.row == row and move.col == col then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Check if king is in check
function ChessEngine:isInCheck(color)
    local kingRow, kingCol = self:findKing(color)
    if not kingRow then
        return false
    end

    local opponentColor = (color == Constants.Color.WHITE) and Constants.Color.BLACK or Constants.Color.WHITE
    return self:isSquareAttacked(kingRow, kingCol, opponentColor)
end

-- Check if a move is legal (doesn't leave own king in check)
function ChessEngine:isMoveLegal(fromRow, fromCol, toRow, toCol)
    local piece = self:getPiece(fromRow, fromCol)
    if not piece then
        if Constants.DEBUG then print("🐱 [ENGINE DEBUG] isMoveLegal: no piece at [" .. fromRow .. "," .. fromCol .. "]") end
        return false
    end

    -- Make temporary move
    local capturedPiece = self.board[toRow][toCol]
    self.board[toRow][toCol] = piece
    self.board[fromRow][fromCol] = nil

    -- Check if own king is in check
    local inCheck = self:isInCheck(piece.color)
    if Constants.DEBUG then print("🐱 [ENGINE DEBUG] After move [" .. fromRow .. "," .. fromCol .. "]→[" .. toRow .. "," .. toCol .. "], inCheck=" .. tostring(inCheck)) end

    -- Undo move
    self.board[fromRow][fromCol] = piece
    self.board[toRow][toCol] = capturedPiece

    return not inCheck
end

-- Make a move
function ChessEngine:makeMove(fromRow, fromCol, toRow, toCol, promotionPiece)
    -- COUNT PIECES BEFORE MOVE
    local pieceCountBefore = 0
    for r = 1, Constants.BOARD_SIZE do
        for c = 1, Constants.BOARD_SIZE do
            if self.board[r] and self.board[r][c] then
                pieceCountBefore = pieceCountBefore + 1
            end
        end
    end
    if Constants.DEBUG then print(string.format("🐱 [ENGINE] BEFORE move [%d,%d]→[%d,%d]: %d total pieces on board",
        fromRow, fromCol, toRow, toCol, pieceCountBefore)) end

    local piece = self:getPiece(fromRow, fromCol)
    if not piece then
        return false, "No piece at source"
    end

    if piece.color ~= self.currentTurn then
        return false, "Not your turn"
    end

    -- Validate move
    local validMoves = self:getValidMoves(fromRow, fromCol)
    local isValid = false
    for _, move in ipairs(validMoves) do
        if move.row == toRow and move.col == toCol then
            isValid = true
            break
        end
    end

    if not isValid then
        return false, "Invalid move"
    end

    -- Record move
    local moveRecord = {
        from = {row = fromRow, col = fromCol},
        to = {row = toRow, col = toCol},
        piece = piece.type,
        color = piece.color,
        captured = self.board[toRow][toCol],
    }

    -- Handle capture
    local capturedPiece = self.board[toRow][toCol]
    if capturedPiece then
        if Constants.DEBUG then print(string.format("🐱 [ENGINE] Capturing %s at [%d,%d]", capturedPiece.type, toRow, toCol)) end
        table.insert(self.capturedPieces[capturedPiece.color], capturedPiece)
        self.halfMoveClock = 0
    elseif piece.type == Constants.PieceType.PAWN then
        self.halfMoveClock = 0
    else
        self.halfMoveClock = self.halfMoveClock + 1
    end

    -- Make the move
    if Constants.DEBUG then print(string.format("🐱 [ENGINE] Moving piece from [%d,%d] to [%d,%d]", fromRow, fromCol, toRow, toCol)) end
    self.board[toRow][toCol] = piece
    self.board[fromRow][fromCol] = nil
    piece.hasMoved = true

    -- Handle pawn promotion
    local promotionRow = (piece.color == Constants.Color.WHITE) and Constants.BOARD_SIZE or 1
    if piece.type == Constants.PieceType.PAWN and toRow == promotionRow then
        -- Validate promotion piece (only Q/R/B/N allowed)
        local validPromotions = {
            [Constants.PieceType.QUEEN] = true,
            [Constants.PieceType.ROOK] = true,
            [Constants.PieceType.BISHOP] = true,
            [Constants.PieceType.KNIGHT] = true,
        }
        local newType = (promotionPiece and validPromotions[promotionPiece]) and promotionPiece or Constants.PieceType.QUEEN
        piece.type = newType
        moveRecord.promotion = newType
    end

    table.insert(self.moveHistory, moveRecord)

    -- COUNT PIECES AFTER MOVE
    local pieceCountAfter = 0
    for r = 1, Constants.BOARD_SIZE do
        for c = 1, Constants.BOARD_SIZE do
            if self.board[r] and self.board[r][c] then
                pieceCountAfter = pieceCountAfter + 1
            end
        end
    end
    if Constants.DEBUG then print(string.format("🐱 [ENGINE] AFTER move: %d total pieces on board (should be %d)",
        pieceCountAfter, capturedPiece and (pieceCountBefore - 1) or pieceCountBefore)) end

    if capturedPiece and pieceCountAfter ~= (pieceCountBefore - 1) then
        if Constants.DEBUG then warn(string.format("🐱 [ENGINE] ⚠️ PIECE MISMATCH! Expected %d after capture, got %d",
            pieceCountBefore - 1, pieceCountAfter)) end
    elseif not capturedPiece and pieceCountAfter ~= pieceCountBefore then
        if Constants.DEBUG then warn(string.format("🐱 [ENGINE] ⚠️ PIECE MISMATCH! Expected %d after move, got %d",
            pieceCountBefore, pieceCountAfter)) end
    end

    -- Switch turn
    self.currentTurn = (self.currentTurn == Constants.Color.WHITE) and Constants.Color.BLACK or Constants.Color.WHITE

    -- Record position for threefold repetition detection
    self:recordPosition()

    -- Check game end conditions
    self:checkGameEnd()

    return true, moveRecord
end

-- Check for game end conditions
function ChessEngine:checkGameEnd()
    local opponent = self.currentTurn
    local hasLegalMoves = false

    -- Check if opponent has any legal moves
    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local piece = self:getPiece(row, col)
            if piece and piece.color == opponent then
                local moves = self:getValidMoves(row, col)
                if #moves > 0 then
                    hasLegalMoves = true
                    break
                end
            end
        end
        if hasLegalMoves then break end
    end

    if not hasLegalMoves then
        if self:isInCheck(opponent) then
            -- Checkmate
            self.gameState = (opponent == Constants.Color.WHITE)
                and Constants.GameState.BLACK_WIN
                or Constants.GameState.WHITE_WIN
        else
            -- Stalemate
            self.gameState = Constants.GameState.STALEMATE
        end
        return
    end

    -- 50-move rule (25 full moves = 50 half-moves on 6x6)
    if self.halfMoveClock >= 50 then
        self.gameState = Constants.GameState.DRAW
        return
    end

    -- Threefold repetition
    local hash = self:getPositionHash()
    if (self.positionHistory[hash] or 0) >= 3 then
        self.gameState = Constants.GameState.DRAW
        return
    end

    -- Insufficient material
    if self:hasInsufficientMaterial() then
        self.gameState = Constants.GameState.DRAW
    end
end

-- Get all legal moves for current player
function ChessEngine:getAllLegalMoves()
    local moves = {}

    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local piece = self:getPiece(row, col)
            if piece and piece.color == self.currentTurn then
                local pieceMoves = self:getValidMoves(row, col)
                for _, move in ipairs(pieceMoves) do
                    table.insert(moves, {
                        from = {row = row, col = col},
                        to = {row = move.row, col = move.col},
                        capture = move.capture
                    })
                end
            end
        end
    end

    return moves
end

-- Serialize board state for network sync
function ChessEngine:serialize()
    -- CRITICAL FIX: Don't use 2D arrays for network transmission!
    -- Roblox's RemoteFunction can't handle sparse numeric arrays and will drop entire rows.
    -- Instead, use a FLAT ARRAY with explicit row/col coordinates.

    local pieces = {}  -- Flat array: {{row=1,col=1,type=...,color=...}, ...}

    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local piece = self.board[row][col]
            if piece then
                table.insert(pieces, {
                    row = row,
                    col = col,
                    type = piece.type,
                    color = piece.color,
                    hasMoved = piece.hasMoved,
                })
            end
        end
    end

    if Constants.DEBUG then print(string.format("🐱 [ENGINE] serialize(): %d pieces serialized as flat array", #pieces)) end

    -- Extract last move for highlighting
    local lastMove = nil
    if #self.moveHistory > 0 then
        local last = self.moveHistory[#self.moveHistory]
        lastMove = {
            fromRow = last.from.row,
            fromCol = last.from.col,
            toRow = last.to.row,
            toCol = last.to.col,
        }
    end

    local data = {
        pieces = pieces,  -- Flat array instead of 2D board
        currentTurn = self.currentTurn,
        gameState = self.gameState,
        moveHistory = self.moveHistory,
        halfMoveClock = self.halfMoveClock,
        lastMove = lastMove,
    }

    return data
end

-- Deserialize board state (from flat array format)
function ChessEngine:deserialize(data)
    self.currentTurn = data.currentTurn
    self.gameState = data.gameState
    self.moveHistory = data.moveHistory or {}
    self.halfMoveClock = data.halfMoveClock or 0

    -- Clear board
    for row = 1, Constants.BOARD_SIZE do
        self.board[row] = {}
        for col = 1, Constants.BOARD_SIZE do
            self.board[row][col] = nil
        end
    end

    -- Rebuild 2D board from flat array
    if data.pieces then
        for _, pieceData in ipairs(data.pieces) do
            self.board[pieceData.row][pieceData.col] = {
                type = pieceData.type,
                color = pieceData.color,
                hasMoved = pieceData.hasMoved,
            }
        end
    end
end

-- Clone the engine for AI search
function ChessEngine:clone()
    local newEngine = ChessEngine.new()
    newEngine:deserialize(self:serialize())
    return newEngine
end

-- Evaluate board position for AI
function ChessEngine:evaluate()
    local score = 0

    for row = 1, Constants.BOARD_SIZE do
        for col = 1, Constants.BOARD_SIZE do
            local piece = self:getPiece(row, col)
            if piece then
                local value = Constants.PieceValue[piece.type] or 0

                -- Add positional bonuses
                -- Center control bonus
                local centerBonus = 0
                if (row == 3 or row == 4) and (col == 3 or col == 4) then
                    centerBonus = 10
                end

                -- Pawn advancement bonus
                local advanceBonus = 0
                if piece.type == Constants.PieceType.PAWN then
                    if piece.color == Constants.Color.WHITE then
                        advanceBonus = (row - 2) * 10
                    else
                        advanceBonus = (5 - row) * 10
                    end
                end

                local pieceScore = value + centerBonus + advanceBonus

                if piece.color == Constants.Color.WHITE then
                    score = score + pieceScore
                else
                    score = score - pieceScore
                end
            end
        end
    end

    -- Check/checkmate bonuses
    if self:isInCheck(Constants.Color.BLACK) then
        score = score + 50
    end
    if self:isInCheck(Constants.Color.WHITE) then
        score = score - 50
    end

    return score
end

return ChessEngine
