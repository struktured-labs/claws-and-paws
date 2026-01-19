--[[
    Claws & Paws - Game Constants
    Central configuration for the cat chess game
]]

local Constants = {}

-- Board Configuration
Constants.BOARD_SIZE = 6
Constants.SQUARE_COUNT = Constants.BOARD_SIZE * Constants.BOARD_SIZE

-- Piece Types
Constants.PieceType = {
    NONE = 0,
    PAWN = 1,
    KNIGHT = 2,
    BISHOP = 3,
    ROOK = 4,
    QUEEN = 5,
    KING = 6,
    -- Hybrid pieces (unlockable)
    ARCHBISHOP = 7,   -- Bishop + Knight
    CHANCELLOR = 8,   -- Rook + Knight
    AMAZON = 9,       -- Queen + Knight
}

-- Colors/Teams
Constants.Color = {
    WHITE = 1,
    BLACK = 2,
}

-- Cat Breeds per Piece
Constants.CatBreed = {
    [Constants.PieceType.KING] = "Lion",
    [Constants.PieceType.QUEEN] = "Persian",
    [Constants.PieceType.ROOK] = "MaineCoon",
    [Constants.PieceType.BISHOP] = "Sphinx",
    [Constants.PieceType.KNIGHT] = "Caracal",
    [Constants.PieceType.PAWN] = "AlleyCat",
    -- Hybrids
    [Constants.PieceType.ARCHBISHOP] = "Serval",
    [Constants.PieceType.CHANCELLOR] = "Cheetah",
    [Constants.PieceType.AMAZON] = "Jaguar",
}

-- Starting piece counts (per player)
Constants.StartingPieces = {
    [Constants.PieceType.KING] = 1,
    [Constants.PieceType.QUEEN] = 1,
    [Constants.PieceType.ROOK] = 1,
    [Constants.PieceType.BISHOP] = 2,
    [Constants.PieceType.KNIGHT] = 1,
    [Constants.PieceType.PAWN] = 6,
}

-- Piece values for AI evaluation
Constants.PieceValue = {
    [Constants.PieceType.PAWN] = 100,
    [Constants.PieceType.KNIGHT] = 320,
    [Constants.PieceType.BISHOP] = 330,
    [Constants.PieceType.ROOK] = 500,
    [Constants.PieceType.QUEEN] = 900,
    [Constants.PieceType.KING] = 20000,
    -- Hybrids
    [Constants.PieceType.ARCHBISHOP] = 650,   -- Bishop + Knight
    [Constants.PieceType.CHANCELLOR] = 820,   -- Rook + Knight
    [Constants.PieceType.AMAZON] = 1220,      -- Queen + Knight
}

-- Game Modes
Constants.GameMode = {
    CASUAL = "Casual",
    RANKED = "Ranked",
    AI_EASY = "AI_Easy",
    AI_MEDIUM = "AI_Medium",
    AI_HARD = "AI_Hard",
    PUZZLE = "Puzzle",
    SPEED_1MIN = "Speed1",
    SPEED_3MIN = "Speed3",
    SPEED_5MIN = "Speed5",
}

-- Time controls (in seconds)
Constants.TimeControl = {
    [Constants.GameMode.SPEED_1MIN] = 60,
    [Constants.GameMode.SPEED_3MIN] = 180,
    [Constants.GameMode.SPEED_5MIN] = 300,
    [Constants.GameMode.CASUAL] = 600,      -- 10 minutes
    [Constants.GameMode.RANKED] = 600,
}

-- AI Difficulty (minimax depth)
Constants.AIDepth = {
    [Constants.GameMode.AI_EASY] = 1,
    [Constants.GameMode.AI_MEDIUM] = 3,
    [Constants.GameMode.AI_HARD] = 5,
}

-- Cat Gestures (emote menu)
Constants.CatGesture = {
    HAPPY_MEOW = "HappyMeow",
    ANGRY_HISS = "AngryHiss",
    SURPRISED = "Surprised",
    SLY_GRIN = "SlyGrin",
    SAD_MEOW = "SadMeow",
    PAW_WAVE = "PawWave",
    SLEEPY_YAWN = "SleepyYawn",
    FISH_OFFERING = "FishOffering",
}

-- Power-ups (Blue Shell equivalents)
Constants.PowerUp = {
    CATNIP_BOMB = "CatnipBomb",         -- Skip opponent's piece for 1 turn
    SUMMON_ALLEY = "SummonAlley",       -- Extra pawn on back rank
    LASER_POINTER = "LaserPointer",     -- Force piece to move
    CARDBOARD_BOX = "CardboardBox",     -- Invisibility for 2 turns
    ZOOMIES = "Zoomies",                -- +1 movement range
}

-- Board themes
Constants.BoardTheme = {
    CAT_CAFE = "CatCafe",
    CARDBOARD_KINGDOM = "CardboardKingdom",
    FISH_MARKET = "FishMarket",
    YARN_FACTORY = "YarnFactory",
    MOONLIT_ROOFTOP = "MoonlitRooftop",
    ANCIENT_EGYPT = "AncientEgypt",
}

-- Visual Style Options
Constants.PieceStyle = {
    CAT_3D = "Cat3D",           -- 3D cat models (default)
    CAT_SIMPLE = "CatSimple",   -- Simplified cat shapes (current placeholders)
    CHESS_CLASSIC = "ChessClassic", -- Traditional chess piece symbols
    CHESS_MINIMAL = "ChessMinimal", -- Minimalist chess pieces
}

Constants.BoardView = {
    PERSPECTIVE_3D = "Perspective3D", -- Default 3D angled view
    TOP_DOWN_2D = "TopDown2D",        -- Flat 2D top-down view
    SIDE_VIEW = "SideView",           -- Side perspective
}

-- Game states
Constants.GameState = {
    WAITING = "Waiting",
    IN_PROGRESS = "InProgress",
    WHITE_WIN = "WhiteWin",
    BLACK_WIN = "BlackWin",
    DRAW = "Draw",
    STALEMATE = "Stalemate",
}

-- Match result reasons
Constants.GameEndReason = {
    CHECKMATE = "Checkmate",
    RESIGNATION = "Resignation",
    TIMEOUT = "Timeout",
    STALEMATE = "Stalemate",
    INSUFFICIENT_MATERIAL = "InsufficientMaterial",
    FIFTY_MOVE = "FiftyMoveRule",
    THREEFOLD_REPETITION = "ThreefoldRepetition",
    AGREEMENT = "DrawAgreement",
    DISCONNECT = "Disconnect",
}

-- Test sync from Linux to Studio!
print("🐱 Claws & Paws loaded! Meow! 🐾")

return Constants
