--[[
    Claws & Paws - Chess AI
    Minimax with alpha-beta pruning for cat opponents
]]

local Constants = require(script.Parent.Constants)

local ChessAI = {}

-- Minimax with alpha-beta pruning
function ChessAI.minimax(engine, depth, alpha, beta, maximizingPlayer)
    if depth == 0 or engine.gameState ~= Constants.GameState.IN_PROGRESS then
        return engine:evaluate(), nil
    end

    local moves = engine:getAllLegalMoves()

    if #moves == 0 then
        if engine:isInCheck(engine.currentTurn) then
            -- Checkmate
            return maximizingPlayer and -100000 or 100000, nil
        else
            -- Stalemate
            return 0, nil
        end
    end

    local bestMove = nil

    if maximizingPlayer then
        local maxEval = -math.huge
        for _, move in ipairs(moves) do
            local clonedEngine = engine:clone()
            clonedEngine:makeMove(move.from.row, move.from.col, move.to.row, move.to.col)

            local eval = ChessAI.minimax(clonedEngine, depth - 1, alpha, beta, false)
            if eval > maxEval then
                maxEval = eval
                bestMove = move
            end
            alpha = math.max(alpha, eval)
            if beta <= alpha then
                break
            end
        end
        return maxEval, bestMove
    else
        local minEval = math.huge
        for _, move in ipairs(moves) do
            local clonedEngine = engine:clone()
            clonedEngine:makeMove(move.from.row, move.from.col, move.to.row, move.to.col)

            local eval = ChessAI.minimax(clonedEngine, depth - 1, alpha, beta, true)
            if eval < minEval then
                minEval = eval
                bestMove = move
            end
            beta = math.min(beta, eval)
            if beta <= alpha then
                break
            end
        end
        return minEval, bestMove
    end
end

-- Get best move for current position
function ChessAI.getBestMove(engine, difficulty)
    local depth = Constants.AIDepth[difficulty] or 3
    local isMaximizing = engine.currentTurn == Constants.Color.WHITE

    local _, bestMove = ChessAI.minimax(engine, depth, -math.huge, math.huge, isMaximizing)

    return bestMove
end

-- Get a random move (for very easy AI or randomness)
function ChessAI.getRandomMove(engine)
    local moves = engine:getAllLegalMoves()
    if #moves == 0 then
        return nil
    end
    return moves[math.random(1, #moves)]
end

-- Get move with some randomness (for medium difficulty)
function ChessAI.getMoveWithRandomness(engine, difficulty, randomFactor)
    randomFactor = randomFactor or 0.2

    if math.random() < randomFactor then
        return ChessAI.getRandomMove(engine)
    else
        return ChessAI.getBestMove(engine, difficulty)
    end
end

-- Move ordering for better alpha-beta pruning
function ChessAI.orderMoves(engine, moves)
    -- Score moves for ordering
    local scoredMoves = {}

    for _, move in ipairs(moves) do
        local score = 0
        local targetPiece = engine:getPiece(move.to.row, move.to.col)

        -- Capturing a higher value piece is good
        if targetPiece then
            local targetValue = Constants.PieceValue[targetPiece.type] or 0
            local attackerPiece = engine:getPiece(move.from.row, move.from.col)
            local attackerValue = Constants.PieceValue[attackerPiece.type] or 0

            -- MVV-LVA (Most Valuable Victim - Least Valuable Attacker)
            score = targetValue * 10 - attackerValue
        end

        -- Center control bonus
        if (move.to.row == 3 or move.to.row == 4) and (move.to.col == 3 or move.to.col == 4) then
            score = score + 20
        end

        table.insert(scoredMoves, {move = move, score = score})
    end

    -- Sort by score descending
    table.sort(scoredMoves, function(a, b)
        return a.score > b.score
    end)

    -- Extract ordered moves
    local orderedMoves = {}
    for _, scored in ipairs(scoredMoves) do
        table.insert(orderedMoves, scored.move)
    end

    return orderedMoves
end

-- AI Personality dialogue responses
ChessAI.Personalities = {
    Lion = {
        name = "King Leo",
        greetings = {
            "Welcome, challenger. Let us see if you have the heart of a lion.",
            "Another brave soul approaches my throne.",
            "The jungle shall determine the victor today.",
        },
        captures = {
            "Your soldier has fallen. The pride grows stronger.",
            "A wise move would have prevented this loss.",
            "Even the mightiest fall before the king.",
        },
        check = {
            "Your king trembles before my power!",
            "The hunt is nearly complete.",
            "Do you feel the walls closing in?",
        },
        captured = {
            "A temporary setback. Lions do not fear adversity.",
            "You have earned that piece. Use it wisely.",
            "The battle rages on.",
        },
        victory = {
            "The king of beasts reigns supreme!",
            "Your challenge was valiant, but the throne remains mine.",
            "Return when you have trained further.",
        },
        defeat = {
            "You have bested the king today. A rare honor.",
            "My crown... take it. You have earned it.",
            "A true warrior stands before me.",
        },
    },
    Persian = {
        name = "Queen Persiana",
        greetings = {
            "How delightful, a new plaything.",
            "I do hope you provide more entertainment than the last one.",
            "Shall we dance, little mouse?",
        },
        captures = {
            "Mmm, that piece looks better in my collection.",
            "Did you not see that coming? How... unfortunate.",
            "Your army grows thinner, darling.",
        },
        check = {
            "Your king is looking rather cornered, wouldn't you say?",
            "Check! Do try to keep up.",
            "The end draws near. How exciting!",
        },
        captured = {
            "A small price for the greater game.",
            "Clever. I shall remember that trick.",
            "You're more cunning than you appear.",
        },
        victory = {
            "As expected. A queen always wins.",
            "That was... adequate entertainment.",
            "Come back when you've learned proper strategy.",
        },
        defeat = {
            "Impossible! How did you...?",
            "Perhaps I underestimated you. It won't happen again.",
            "Well played. I demand a rematch.",
        },
    },
    Sphinx = {
        name = "Oracle Sphinx",
        greetings = {
            "The ancient spirits whisper of your arrival.",
            "Do you seek wisdom? Or merely victory?",
            "The sands of time flow. Let us see where they lead.",
        },
        captures = {
            "The spirits foretold this sacrifice.",
            "Your piece returns to the cosmic void.",
            "Balance must be maintained.",
        },
        check = {
            "Your path narrows. The visions do not lie.",
            "The threads of fate tighten around your king.",
            "Can you see what I see?",
        },
        captured = {
            "An offering to the chaos of chance.",
            "Even the wise must sometimes yield.",
            "The pattern shifts... interesting.",
        },
        victory = {
            "The prophecy is fulfilled.",
            "Your destiny was written in the stars.",
            "Return when the cosmos align differently.",
        },
        defeat = {
            "The visions... they did not show this outcome.",
            "Perhaps chaos has chosen you as its champion.",
            "A new prophecy must be written.",
        },
    },
    Caracal = {
        name = "Sir Pounce",
        greetings = {
            "Haha! Fresh prey!",
            "You ready to get DESTROYED?!",
            "Let's gooooo! I've been waiting for a challenger!",
        },
        captures = {
            "YOINK! That's mine now!",
            "Too slow! Way too slow!",
            "Did you even try to defend that?!",
        },
        check = {
            "CHECK! Your king's shaking in his boots!",
            "Ooooh, you're in trouble now!",
            "Run little king, run! Haha!",
        },
        captured = {
            "Okay okay, you got lucky!",
            "Pff, I wasn't using that piece anyway.",
            "Nice one! But I'm still gonna win!",
        },
        victory = {
            "GG EZ! Better luck next time!",
            "That's what happens when you face the master!",
            "Want a rematch? I'll go easy on you! ...Maybe.",
        },
        defeat = {
            "WHAT?! No way! I demand a rematch!",
            "You cheated! ...Okay fine, you didn't. GG.",
            "Ugh, fine. You win THIS time.",
        },
    },
}

-- Get random dialogue for personality and event
function ChessAI.getDialogue(personality, event)
    local personaData = ChessAI.Personalities[personality]
    if not personaData then
        return "..."
    end

    local dialogues = personaData[event]
    if not dialogues or #dialogues == 0 then
        return "..."
    end

    return dialogues[math.random(1, #dialogues)]
end

return ChessAI
