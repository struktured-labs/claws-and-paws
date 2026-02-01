--[[
    Unit tests for Claws & Paws ChessEngine
    Run: lua tests/test_chess_engine.lua

    Mocks the Roblox environment so ChessEngine + Constants can run in plain Lua 5.1.
]]

-- Suppress engine debug prints during tests
local _print = print
local VERBOSE = (arg and arg[1] == "-v")
if not VERBOSE then
    print = function() end
end
local function log(...)
    _print(...)
end
warn = warn or function(...) _print("WARN:", ...) end

-- Mock Roblox's `script` and `require` for Constants
local Constants = dofile("src/shared/Constants.lua")

-- Patch require so ChessEngine can load Constants via `require(script.Parent.Constants)`
local _require = require
local scriptMock = { Parent = { Constants = "CONSTANTS_SENTINEL" } }
require = function(mod)
    if mod == "CONSTANTS_SENTINEL" then
        return Constants
    end
    return _require(mod)
end
script = scriptMock

-- Now load ChessEngine
local ChessEngine = dofile("src/shared/ChessEngine.lua")

-- Restore
require = _require

-- Test framework
local passed = 0
local failed = 0
local errors = {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        log("  PASS: " .. name)
    else
        failed = failed + 1
        table.insert(errors, {name = name, err = err})
        log("  FAIL: " .. name .. " - " .. tostring(err))
    end
end

local function assert_eq(a, b, msg)
    if a ~= b then
        error((msg or "assertion failed") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

local function assert_true(val, msg)
    if not val then
        error((msg or "expected true") .. ", got " .. tostring(val), 2)
    end
end

local function assert_false(val, msg)
    if val then
        error((msg or "expected false") .. ", got " .. tostring(val), 2)
    end
end

-- Helper: create engine with a specific board layout (no randomness)
local function newEngine()
    local e = ChessEngine.new()
    -- Clear board
    for row = 1, 6 do
        e.board[row] = {}
        for col = 1, 6 do
            e.board[row][col] = nil
        end
    end
    e.gameState = Constants.GameState.IN_PROGRESS
    e.currentTurn = Constants.Color.WHITE
    return e
end

local function placePiece(engine, row, col, pieceType, color, hasMoved)
    engine.board[row][col] = {
        type = pieceType,
        color = color,
        hasMoved = hasMoved or false,
    }
end

local function hasMove(moves, toRow, toCol)
    for _, m in ipairs(moves) do
        if m.row == toRow and m.col == toCol then
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
log("=== Board Setup ===")
----------------------------------------------------------------------

test("setupBoard creates correct number of pieces", function()
    local e = ChessEngine.new()
    e:setupBoard(42)
    local count = 0
    for r = 1, 6 do
        for c = 1, 6 do
            if e.board[r][c] then count = count + 1 end
        end
    end
    -- 6 pawns + 6 pieces per side = 24
    assert_eq(count, 24, "piece count")
end)

test("setupBoard places pawns on rows 2 and 5", function()
    local e = ChessEngine.new()
    e:setupBoard(42)
    for col = 1, 6 do
        assert_true(e.board[2][col] ~= nil, "white pawn at col " .. col)
        assert_eq(e.board[2][col].type, Constants.PieceType.PAWN, "type at row 2")
        assert_eq(e.board[2][col].color, Constants.Color.WHITE, "color at row 2")

        assert_true(e.board[5][col] ~= nil, "black pawn at col " .. col)
        assert_eq(e.board[5][col].type, Constants.PieceType.PAWN, "type at row 5")
        assert_eq(e.board[5][col].color, Constants.Color.BLACK, "color at row 5")
    end
end)

test("Fischer Random places exactly 1 king, 1 queen, 1 rook, 2 bishops, 1 knight", function()
    local e = ChessEngine.new()
    e:setupBoard(42)
    local counts = {}
    for col = 1, 6 do
        local piece = e.board[1][col]
        assert_true(piece ~= nil, "piece at row 1 col " .. col)
        counts[piece.type] = (counts[piece.type] or 0) + 1
    end
    assert_eq(counts[Constants.PieceType.KING], 1, "kings")
    assert_eq(counts[Constants.PieceType.QUEEN], 1, "queens")
    assert_eq(counts[Constants.PieceType.ROOK], 1, "rooks")
    assert_eq(counts[Constants.PieceType.BISHOP], 2, "bishops")
    assert_eq(counts[Constants.PieceType.KNIGHT], 1, "knights")
end)

test("Fischer Random bishops on opposite colors", function()
    -- Test multiple seeds
    for seed = 1, 20 do
        local e = ChessEngine.new()
        e:setupBoard(seed)
        local bishopCols = {}
        for col = 1, 6 do
            if e.board[1][col].type == Constants.PieceType.BISHOP then
                table.insert(bishopCols, col)
            end
        end
        assert_eq(#bishopCols, 2, "should have 2 bishops")
        -- Opposite colors means one odd, one even column
        local parity1 = bishopCols[1] % 2
        local parity2 = bishopCols[2] % 2
        assert_true(parity1 ~= parity2, "bishops on opposite colors (seed=" .. seed .. ", cols=" .. bishopCols[1] .. "," .. bishopCols[2] .. ")")
    end
end)

----------------------------------------------------------------------
log("\n=== Pawn Moves ===")
----------------------------------------------------------------------

test("white pawn moves forward one square", function()
    local e = newEngine()
    placePiece(e, 2, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(2, 3)
    assert_true(hasMove(moves, 3, 3), "can move to 3,3")
    assert_eq(#moves, 1, "only one move")
end)

test("black pawn moves downward", function()
    local e = newEngine()
    placePiece(e, 5, 3, Constants.PieceType.PAWN, Constants.Color.BLACK)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    e.currentTurn = Constants.Color.BLACK

    local moves = e:getValidMoves(5, 3)
    assert_true(hasMove(moves, 4, 3), "can move to 4,3")
end)

test("pawn blocked by piece in front", function()
    local e = newEngine()
    placePiece(e, 2, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 3, 3, Constants.PieceType.PAWN, Constants.Color.BLACK)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(2, 3)
    assert_eq(#moves, 0, "no moves when blocked")
end)

test("pawn captures diagonally", function()
    local e = newEngine()
    placePiece(e, 2, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 3, 2, Constants.PieceType.PAWN, Constants.Color.BLACK)
    placePiece(e, 3, 4, Constants.PieceType.PAWN, Constants.Color.BLACK)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(2, 3)
    assert_true(hasMove(moves, 3, 2), "can capture left")
    assert_true(hasMove(moves, 3, 4), "can capture right")
    assert_true(hasMove(moves, 3, 3), "can move forward")
    assert_eq(#moves, 3, "3 moves total")
end)

test("pawn cannot capture own piece", function()
    local e = newEngine()
    placePiece(e, 2, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 3, 2, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(2, 3)
    assert_false(hasMove(moves, 3, 2), "cannot capture own piece")
end)

----------------------------------------------------------------------
log("\n=== Knight Moves ===")
----------------------------------------------------------------------

test("knight has correct L-shaped moves from center", function()
    local e = newEngine()
    placePiece(e, 3, 3, Constants.PieceType.KNIGHT, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(3, 3)
    -- All 8 L-shapes: (1,2),(1,4),(2,1),(2,5),(4,1),(4,5),(5,2),(5,4)
    assert_true(hasMove(moves, 1, 2), "1,2")
    assert_true(hasMove(moves, 1, 4), "1,4")
    assert_true(hasMove(moves, 2, 1), "2,1")
    assert_true(hasMove(moves, 2, 5), "2,5")
    assert_true(hasMove(moves, 4, 1), "4,1")
    assert_true(hasMove(moves, 4, 5), "4,5")
    assert_true(hasMove(moves, 5, 2), "5,2")
    assert_true(hasMove(moves, 5, 4), "5,4")
    assert_eq(#moves, 8, "8 moves from center")
end)

test("knight in corner has limited moves", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KNIGHT, Constants.Color.WHITE)
    placePiece(e, 6, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(1, 1)
    -- From (1,1): (2,3) and (3,2) are valid
    assert_true(hasMove(moves, 2, 3), "2,3")
    assert_true(hasMove(moves, 3, 2), "3,2")
    assert_eq(#moves, 2, "2 moves from corner")
end)

----------------------------------------------------------------------
log("\n=== Bishop Moves ===")
----------------------------------------------------------------------

test("bishop moves diagonally", function()
    local e = newEngine()
    placePiece(e, 3, 3, Constants.PieceType.BISHOP, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(3, 3)
    -- Diagonals from (3,3): (1,1),(2,2),(4,4),(5,5) and (2,4),(1,5) and (4,2),(5,1) and (4,4),(5,5)
    assert_true(hasMove(moves, 2, 2), "2,2")
    assert_true(hasMove(moves, 4, 4), "4,4")
    assert_true(hasMove(moves, 2, 4), "2,4")
    assert_true(hasMove(moves, 4, 2), "4,2")
end)

test("bishop blocked by own piece", function()
    local e = newEngine()
    placePiece(e, 3, 3, Constants.PieceType.BISHOP, Constants.Color.WHITE)
    placePiece(e, 4, 4, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(3, 3)
    assert_false(hasMove(moves, 4, 4), "cannot go through own piece")
    assert_false(hasMove(moves, 5, 5), "cannot go beyond own piece")
end)

----------------------------------------------------------------------
log("\n=== Rook Moves ===")
----------------------------------------------------------------------

test("rook moves horizontally and vertically", function()
    local e = newEngine()
    placePiece(e, 3, 3, Constants.PieceType.ROOK, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(3, 3)
    -- Horizontal: (3,1),(3,2),(3,4),(3,5),(3,6) = 5
    -- Vertical: (1,3),(2,3),(4,3),(5,3),(6,3) = 5
    assert_true(hasMove(moves, 3, 1), "left edge")
    assert_true(hasMove(moves, 3, 6), "right edge")
    assert_true(hasMove(moves, 1, 3), "top")
    assert_true(hasMove(moves, 6, 3), "bottom")
    assert_eq(#moves, 10, "10 moves from center")
end)

----------------------------------------------------------------------
log("\n=== King Moves ===")
----------------------------------------------------------------------

test("king moves one square in each direction", function()
    local e = newEngine()
    placePiece(e, 3, 3, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(3, 3)
    assert_true(hasMove(moves, 2, 2), "2,2")
    assert_true(hasMove(moves, 2, 3), "2,3")
    assert_true(hasMove(moves, 2, 4), "2,4")
    assert_true(hasMove(moves, 3, 2), "3,2")
    assert_true(hasMove(moves, 3, 4), "3,4")
    assert_true(hasMove(moves, 4, 2), "4,2")
    assert_true(hasMove(moves, 4, 3), "4,3")
    assert_true(hasMove(moves, 4, 4), "4,4")
    assert_eq(#moves, 8, "8 moves from center")
end)

test("king cannot move into check", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    -- Black rook controls row 2
    placePiece(e, 2, 6, Constants.PieceType.ROOK, Constants.Color.BLACK)

    local moves = e:getValidMoves(1, 1)
    -- King at (1,1), rook at (2,6) attacks entire row 2
    assert_false(hasMove(moves, 2, 1), "cannot move into row 2 (rook)")
    assert_false(hasMove(moves, 2, 2), "cannot move into row 2 (rook)")
    assert_true(hasMove(moves, 1, 2), "can move to 1,2")
end)

----------------------------------------------------------------------
log("\n=== Check Detection ===")
----------------------------------------------------------------------

test("isInCheck detects rook check", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 1, 6, Constants.PieceType.ROOK, Constants.Color.BLACK)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    assert_true(e:isInCheck(Constants.Color.WHITE), "white should be in check")
    assert_false(e:isInCheck(Constants.Color.BLACK), "black should not be in check")
end)

test("isInCheck detects bishop check", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 3, 3, Constants.PieceType.BISHOP, Constants.Color.BLACK)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    assert_true(e:isInCheck(Constants.Color.WHITE), "white in check from bishop")
end)

test("pinned piece cannot move", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 1, 2, Constants.PieceType.BISHOP, Constants.Color.WHITE) -- pinned by rook
    placePiece(e, 1, 6, Constants.PieceType.ROOK, Constants.Color.BLACK)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(1, 2)
    -- Bishop at (1,2) is pinned to king at (1,1) by rook at (1,6)
    -- Moving the bishop would expose king to check along row 1
    assert_eq(#moves, 0, "pinned bishop has no legal moves")
end)

----------------------------------------------------------------------
log("\n=== Checkmate ===")
----------------------------------------------------------------------

test("back rank checkmate detected", function()
    local e = newEngine()
    -- White king on 1,1 trapped by own pawns
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 2, 1, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 2, 2, Constants.PieceType.PAWN, Constants.Color.WHITE)
    -- Black rook delivers check on row 1
    placePiece(e, 1, 6, Constants.PieceType.ROOK, Constants.Color.BLACK)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    -- It's white's turn, king is in check with no escape
    e.currentTurn = Constants.Color.WHITE
    e:checkGameEnd()
    -- checkGameEnd checks if currentTurn player has no moves
    -- Need to make it black's turn so checkGameEnd checks white
    -- Actually checkGameEnd checks opponent = currentTurn, so if it's black's turn,
    -- it checks if BLACK has legal moves. We want to check WHITE has no moves.
    -- Set to black's turn so the check is on "opponent" (which is BLACK from black's perspective... no)
    -- Actually re-reading: checkGameEnd checks `opponent = self.currentTurn`
    -- So if currentTurn is WHITE, it checks if WHITE has legal moves
    -- That means we call it when it's WHITE's turn after BLACK moved
    -- The engine switches turn before calling checkGameEnd
    -- So to simulate "black just moved, now checking if white can move":
    -- currentTurn should be WHITE (the player who needs to move next)

    e:checkGameEnd()
    assert_eq(e.gameState, Constants.GameState.BLACK_WIN, "black should win by checkmate")
end)

test("smothered checkmate", function()
    local e = newEngine()
    -- White king surrounded by own pieces, attacked by knight
    -- Knight at (3,2) attacks (1,1); pawn at (2,1) must NOT be able to capture it
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 1, 2, Constants.PieceType.ROOK, Constants.Color.WHITE)
    placePiece(e, 2, 1, Constants.PieceType.ROOK, Constants.Color.WHITE) -- rook, not pawn (can't capture diag)
    placePiece(e, 2, 2, Constants.PieceType.PAWN, Constants.Color.WHITE)
    -- Knight at (3,2) attacks (1,1). Rook at (2,1) can't capture diagonally.
    -- Rook blocked vertically by pawn at (2,2) doesn't matter since (3,2) is diagonal from (2,1).
    placePiece(e, 3, 2, Constants.PieceType.KNIGHT, Constants.Color.BLACK)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    -- Verify check
    assert_true(e:isInCheck(Constants.Color.WHITE), "white in check")

    e.currentTurn = Constants.Color.WHITE
    e:checkGameEnd()
    assert_eq(e.gameState, Constants.GameState.BLACK_WIN, "smothered mate")
end)

----------------------------------------------------------------------
log("\n=== Stalemate ===")
----------------------------------------------------------------------

test("stalemate detected (lone king, no legal moves)", function()
    local e = newEngine()
    -- White king boxed in corner by black queen and king
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 3, 2, Constants.PieceType.QUEEN, Constants.Color.BLACK)
    placePiece(e, 2, 3, Constants.PieceType.KING, Constants.Color.BLACK)

    -- White to move: king at (1,1)
    -- Adjacent squares: (1,2) attacked by queen, (2,1) attacked by queen, (2,2) attacked by both
    -- Not in check (queen at 3,2 doesn't attack 1,1 directly)
    e.currentTurn = Constants.Color.WHITE

    -- Verify NOT in check
    assert_false(e:isInCheck(Constants.Color.WHITE), "white not in check")

    e:checkGameEnd()
    assert_eq(e.gameState, Constants.GameState.STALEMATE, "should be stalemate")
end)

----------------------------------------------------------------------
log("\n=== Pawn Promotion ===")
----------------------------------------------------------------------

test("pawn promotes to queen by default", function()
    local e = newEngine()
    placePiece(e, 5, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local success = e:makeMove(5, 3, 6, 3)
    assert_true(success, "move should succeed")

    local promoted = e:getPiece(6, 3)
    assert_eq(promoted.type, Constants.PieceType.QUEEN, "should promote to queen")
end)

test("pawn promotes to knight when specified", function()
    local e = newEngine()
    placePiece(e, 5, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local success = e:makeMove(5, 3, 6, 3, Constants.PieceType.KNIGHT)
    assert_true(success, "move should succeed")

    local promoted = e:getPiece(6, 3)
    assert_eq(promoted.type, Constants.PieceType.KNIGHT, "should promote to knight")
end)

test("invalid promotion piece defaults to queen", function()
    local e = newEngine()
    placePiece(e, 5, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    -- Try to promote to KING (invalid)
    local success = e:makeMove(5, 3, 6, 3, Constants.PieceType.KING)
    assert_true(success, "move should succeed")

    local promoted = e:getPiece(6, 3)
    assert_eq(promoted.type, Constants.PieceType.QUEEN, "invalid promotion defaults to queen")
end)

----------------------------------------------------------------------
log("\n=== Move Validation ===")
----------------------------------------------------------------------

test("cannot move opponent's piece", function()
    local e = newEngine()
    placePiece(e, 5, 3, Constants.PieceType.PAWN, Constants.Color.BLACK)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    e.currentTurn = Constants.Color.WHITE

    local success, reason = e:makeMove(5, 3, 4, 3)
    assert_false(success, "cannot move opponent piece")
    assert_eq(reason, "Not your turn", "correct error")
end)

test("cannot move to invalid square", function()
    local e = newEngine()
    placePiece(e, 2, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local success, reason = e:makeMove(2, 3, 4, 3) -- pawn can only move 1 square
    assert_false(success, "invalid pawn move")
    assert_eq(reason, "Invalid move", "correct error")
end)

test("cannot move from empty square", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local success, reason = e:makeMove(3, 3, 4, 3)
    assert_false(success, "no piece at source")
    assert_eq(reason, "No piece at source", "correct error")
end)

----------------------------------------------------------------------
log("\n=== Draw Conditions ===")
----------------------------------------------------------------------

test("50-move rule triggers draw", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    placePiece(e, 1, 6, Constants.PieceType.ROOK, Constants.Color.WHITE)

    e.halfMoveClock = 50
    e:checkGameEnd()
    assert_eq(e.gameState, Constants.GameState.DRAW, "50-move rule draw")
end)

test("insufficient material: K vs K", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    assert_true(e:hasInsufficientMaterial(), "K vs K is insufficient")

    e:checkGameEnd()
    assert_eq(e.gameState, Constants.GameState.DRAW, "should be draw")
end)

test("insufficient material: K+B vs K", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 1, 2, Constants.PieceType.BISHOP, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    assert_true(e:hasInsufficientMaterial(), "K+B vs K is insufficient")
end)

test("insufficient material: K+N vs K", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 1, 2, Constants.PieceType.KNIGHT, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    assert_true(e:hasInsufficientMaterial(), "K+N vs K is insufficient")
end)

test("sufficient material: K+R vs K", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 1, 2, Constants.PieceType.ROOK, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    assert_false(e:hasInsufficientMaterial(), "K+R vs K is sufficient")
end)

test("sufficient material: K+P vs K", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 2, 2, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    assert_false(e:hasInsufficientMaterial(), "K+P vs K is sufficient")
end)

test("threefold repetition triggers draw", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    placePiece(e, 1, 6, Constants.PieceType.ROOK, Constants.Color.WHITE)
    placePiece(e, 6, 1, Constants.PieceType.ROOK, Constants.Color.BLACK)

    -- Simulate position occurring 3 times by recording manually
    local hash = e:getPositionHash()
    e.positionHistory[hash] = 3

    e:checkGameEnd()
    assert_eq(e.gameState, Constants.GameState.DRAW, "threefold repetition draw")
end)

test("position hash changes with different positions", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local hash1 = e:getPositionHash()

    -- Move white king
    e.board[1][2] = e.board[1][1]
    e.board[1][1] = nil

    local hash2 = e:getPositionHash()

    assert_true(hash1 ~= hash2, "different positions = different hashes")
end)

test("position hash changes with turn", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    e.currentTurn = Constants.Color.WHITE
    local hash1 = e:getPositionHash()

    e.currentTurn = Constants.Color.BLACK
    local hash2 = e:getPositionHash()

    assert_true(hash1 ~= hash2, "same position, different turn = different hash")
end)

----------------------------------------------------------------------
log("\n=== Queen Moves ===")
----------------------------------------------------------------------

test("queen combines rook and bishop movement", function()
    local e = newEngine()
    placePiece(e, 3, 3, Constants.PieceType.QUEEN, Constants.Color.WHITE)
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)

    local moves = e:getValidMoves(3, 3)
    -- Should have both rook-like and bishop-like moves
    assert_true(hasMove(moves, 3, 1), "rook-like horizontal")
    assert_true(hasMove(moves, 1, 3), "rook-like vertical")
    assert_true(hasMove(moves, 5, 5), "bishop-like diagonal")
    assert_true(hasMove(moves, 5, 1), "bishop-like diagonal")
end)

----------------------------------------------------------------------
log("\n=== Serialize / Deserialize ===")
----------------------------------------------------------------------

test("serialize and deserialize preserves board state", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    placePiece(e, 3, 3, Constants.PieceType.QUEEN, Constants.Color.WHITE)
    e.currentTurn = Constants.Color.BLACK

    local data = e:serialize()

    local e2 = ChessEngine.new()
    e2:deserialize(data)

    assert_eq(e2.currentTurn, Constants.Color.BLACK, "turn preserved")
    assert_eq(e2.gameState, Constants.GameState.IN_PROGRESS, "state preserved")

    local king = e2:getPiece(1, 1)
    assert_true(king ~= nil, "king exists after deserialize")
    assert_eq(king.type, Constants.PieceType.KING, "king type")
    assert_eq(king.color, Constants.Color.WHITE, "king color")

    local queen = e2:getPiece(3, 3)
    assert_true(queen ~= nil, "queen exists")
    assert_eq(queen.type, Constants.PieceType.QUEEN, "queen type")
end)

test("clone produces independent copy", function()
    local e = newEngine()
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    placePiece(e, 2, 2, Constants.PieceType.PAWN, Constants.Color.WHITE)

    local c = e:clone()

    -- Modify clone
    c.board[2][2] = nil

    -- Original should be unchanged
    assert_true(e:getPiece(2, 2) ~= nil, "original unchanged after clone modification")
    assert_true(c:getPiece(2, 2) == nil, "clone is modified")
end)

----------------------------------------------------------------------
log("\n=== Integration: Full Game Sequence ===")
----------------------------------------------------------------------

test("simple capture game sequence", function()
    local e = newEngine()
    -- Set up a simple position
    placePiece(e, 1, 1, Constants.PieceType.KING, Constants.Color.WHITE)
    placePiece(e, 2, 3, Constants.PieceType.PAWN, Constants.Color.WHITE)
    placePiece(e, 6, 6, Constants.PieceType.KING, Constants.Color.BLACK)
    placePiece(e, 3, 4, Constants.PieceType.PAWN, Constants.Color.BLACK)

    -- White pawn captures black pawn
    e.currentTurn = Constants.Color.WHITE
    local success = e:makeMove(2, 3, 3, 4)
    assert_true(success, "capture should succeed")
    assert_eq(e.currentTurn, Constants.Color.BLACK, "turn switched to black")

    local captured = e:getPiece(3, 4)
    assert_eq(captured.color, Constants.Color.WHITE, "white pawn now at capture square")
    assert_eq(#e.moveHistory, 1, "one move in history")
    assert_true(e.moveHistory[1].captured ~= nil, "capture recorded")
end)

----------------------------------------------------------------------
log("\n=== Last Move Tracking ===")
----------------------------------------------------------------------

test("serialize includes lastMove after a move", function()
    local e = ChessEngine.new()
    e:setupBoard()
    -- Move a pawn
    e:makeMove(2, 1, 3, 1)
    local data = e:serialize()
    assert_true(data.lastMove ~= nil, "lastMove should exist")
    assert_eq(data.lastMove.fromRow, 2, "lastMove fromRow")
    assert_eq(data.lastMove.fromCol, 1, "lastMove fromCol")
    assert_eq(data.lastMove.toRow, 3, "lastMove toRow")
    assert_eq(data.lastMove.toCol, 1, "lastMove toCol")
end)

test("serialize has no lastMove on fresh board", function()
    local e = ChessEngine.new()
    e:setupBoard()
    local data = e:serialize()
    assert_true(data.lastMove == nil, "no lastMove on fresh board")
end)

test("lastMove updates on each move", function()
    local e = ChessEngine.new()
    e:setupBoard()
    e:makeMove(2, 1, 3, 1)
    e:makeMove(5, 1, 4, 1)
    local data = e:serialize()
    assert_eq(data.lastMove.fromRow, 5, "last move was black's")
    assert_eq(data.lastMove.toRow, 4, "moved to row 4")
end)

----------------------------------------------------------------------
log("\n=== Position Hash Consistency ===")
----------------------------------------------------------------------

test("identical positions produce identical hashes", function()
    local e1 = ChessEngine.new()
    e1:setupBoard()
    local e2 = ChessEngine.new()
    e2:setupBoard()
    assert_eq(e1:getPositionHash(), e2:getPositionHash(), "same position = same hash")
end)

test("different positions produce different hashes", function()
    local e1 = ChessEngine.new()
    e1:setupBoard()
    local hash1 = e1:getPositionHash()
    e1:makeMove(2, 1, 3, 1)
    local hash2 = e1:getPositionHash()
    assert_true(hash1 ~= hash2, "position changed = different hash")
end)

test("hash includes turn information", function()
    -- Two positions with same pieces but different turns should differ
    local e = ChessEngine.new()
    e:setupBoard()
    local hashWhite = e:getPositionHash()
    e.currentTurn = Constants.Color.BLACK
    local hashBlack = e:getPositionHash()
    assert_true(hashWhite ~= hashBlack, "different turn = different hash")
    e.currentTurn = Constants.Color.WHITE -- restore
end)

test("initial position is recorded in positionHistory", function()
    local e = ChessEngine.new()
    e:setupBoard()
    local hash = e:getPositionHash()
    assert_eq(e.positionHistory[hash], 1, "initial position should be counted once")
end)

----------------------------------------------------------------------
log("\n=== Campaign Data ===")
----------------------------------------------------------------------

-- Load CampaignData for testing
local CampaignData = dofile("src/shared/CampaignData.lua")

test("CampaignData has 5 bosses", function()
    assert_eq(#CampaignData.BOSSES, 5, "should have 5 bosses")
end)

test("first boss is always unlocked", function()
    assert_true(CampaignData.BOSSES[1].unlocked, "whiskers is unlocked by default")
end)

test("getBoss returns correct boss", function()
    local boss = CampaignData.getBoss("shadow")
    assert_true(boss ~= nil, "shadow exists")
    assert_eq(boss.name, "Shadow", "correct name")
    assert_eq(boss.difficulty, "Hard", "correct difficulty")
end)

test("getBoss returns nil for invalid id", function()
    assert_true(CampaignData.getBoss("nonexistent") == nil, "nil for bad id")
end)

test("getUnlockedBosses with no progress returns first boss", function()
    local unlocked = CampaignData.getUnlockedBosses({})
    assert_eq(#unlocked, 1, "only first boss unlocked")
    assert_eq(unlocked[1].id, "whiskers", "whiskers is first")
end)

test("getUnlockedBosses unlocks next after defeating a boss", function()
    local unlocked = CampaignData.getUnlockedBosses({whiskers = true})
    assert_eq(#unlocked, 2, "two bosses unlocked")
    assert_eq(unlocked[2].id, "mittens", "mittens unlocked after whiskers")
end)

test("getCompletionPercentage calculates correctly", function()
    assert_eq(CampaignData.getCompletionPercentage({}), 0, "0% with no progress")
    assert_eq(CampaignData.getCompletionPercentage({whiskers = true}), 20, "20% with 1/5")
    assert_eq(CampaignData.getCompletionPercentage({
        whiskers = true, mittens = true, shadow = true, duchess = true, lucifer = true
    }), 100, "100% with all defeated")
end)

----------------------------------------------------------------------
-- Results
----------------------------------------------------------------------
log("\n========================================")
log(string.format("Results: %d passed, %d failed, %d total", passed, failed, passed + failed))
if #errors > 0 then
    log("\nFailures:")
    for _, e in ipairs(errors) do
        log("  " .. e.name .. ": " .. e.err)
    end
end
log("========================================")

os.exit(failed > 0 and 1 or 0)
