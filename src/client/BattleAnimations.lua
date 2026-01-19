--[[
    Claws & Paws - Battle Animations
    Cat combat animations for captures and moves
]]

local TweenService = game:GetService("TweenService")
local BattleAnimations = {}

-- Pounce animation when capturing
function BattleAnimations.pounceCapture(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Calculate midpoint for arc
    local midpoint = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        math.max(fromPos.Y, toPos.Y) + 3, -- Jump height
        (fromPos.Z + toPos.Z) / 2
    )

    -- First half: jump up
    local upTween = TweenService:Create(piece, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = midpoint
    })

    -- Second half: pounce down
    local downTween = TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = toPos
    })

    -- Add rotation for extra flair
    local spinTween = TweenService:Create(piece, TweenInfo.new(0.55, Enum.EasingStyle.Linear), {
        Orientation = Vector3.new(0, 360, 0)
    })

    upTween.Completed:Connect(function()
        downTween:Play()
    end)

    downTween.Completed:Connect(function()
        piece.Orientation = Vector3.new(0, 0, 0)
        if onComplete then onComplete() end
    end)

    upTween:Play()
    spinTween:Play()
end

-- Simple slide animation for regular moves
function BattleAnimations.slideMove(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(piece, tweenInfo, {
        Position = toPos
    })

    tween.Completed:Connect(function()
        if onComplete then onComplete() end
    end)

    tween:Play()
end

-- Knight's L-shaped hop animation
function BattleAnimations.knightHop(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Calculate L-path: up, then corner turn, then down
    local midHeight = math.max(fromPos.Y, toPos.Y) + 5
    local midpoint = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        midHeight,
        (fromPos.Z + toPos.Z) / 2
    )

    -- First jump up with rotation
    local upTween = TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = midpoint,
        Orientation = Vector3.new(0, 180, 0)
    })

    -- Then land down
    local downTween = TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = toPos,
        Orientation = Vector3.new(0, 360, 0)
    })

    upTween.Completed:Connect(function()
        downTween:Play()
    end)

    downTween.Completed:Connect(function()
        piece.Orientation = Vector3.new(0, 0, 0)
        if onComplete then onComplete() end
    end)

    upTween:Play()
end

-- King's slow, regal walk
function BattleAnimations.kingWalk(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Slow and steady with slight bob
    local distance = (toPos - fromPos).Magnitude
    local duration = math.max(0.5, distance / 10) -- Slower for king

    local mainTween = TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        Position = toPos
    })

    -- Add gentle bobbing while walking
    local bobHeight = 0.3
    local bobTween = TweenService:Create(piece, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, math.ceil(duration / 0.3), true), {
        Position = piece.Position + Vector3.new(0, bobHeight, 0)
    })

    mainTween.Completed:Connect(function()
        bobTween:Cancel()
        piece.Position = toPos
        if onComplete then onComplete() end
    end)

    mainTween:Play()
    bobTween:Play()
end

-- Queen's fast, confident dash with sparkle trail
function BattleAnimations.queenDash(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Fast and elegant
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local tween = TweenService:Create(piece, tweenInfo, {
        Position = toPos
    })

    -- Add spinning effect for elegance
    local spinTween = TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
        Orientation = Vector3.new(0, 180, 0)
    })

    tween.Completed:Connect(function()
        piece.Orientation = Vector3.new(0, 0, 0)
        if onComplete then onComplete() end
    end)

    tween:Play()
    spinTween:Play()
end

-- Rook's powerful, straight slide
function BattleAnimations.rookSlide(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Powerful linear movement
    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(piece, tweenInfo, {
        Position = toPos
    })

    tween.Completed:Connect(function()
        if onComplete then onComplete() end
    end)

    tween:Play()
end

-- Bishop's diagonal glide with slight rotation
function BattleAnimations.bishopGlide(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Smooth diagonal with gentle rotation
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(piece, tweenInfo, {
        Position = toPos
    })

    local rotateTween = TweenService:Create(piece, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        Orientation = Vector3.new(0, 90, 0)
    })

    tween.Completed:Connect(function()
        piece.Orientation = Vector3.new(0, 0, 0)
        if onComplete then onComplete() end
    end)

    tween:Play()
    rotateTween:Play()
end

-- Pawn's small, cautious step
function BattleAnimations.pawnStep(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Small hop forward
    local midpoint = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        fromPos.Y + 1,
        (fromPos.Z + toPos.Z) / 2
    )

    local upTween = TweenService:Create(piece, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = midpoint
    })

    local downTween = TweenService:Create(piece, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = toPos
    })

    upTween.Completed:Connect(function()
        downTween:Play()
    end)

    downTween.Completed:Connect(function()
        if onComplete then onComplete() end
    end)

    upTween:Play()
end

-- Smart move selector - picks animation based on piece type
function BattleAnimations.smartMove(piece, fromPos, toPos, pieceType, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    -- Load Constants (need to access piece types)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = require(ReplicatedStorage.Shared)
    local Constants = Shared.Constants

    -- Route to appropriate animation based on piece type
    if pieceType == Constants.PieceType.KNIGHT then
        BattleAnimations.knightHop(piece, fromPos, toPos, onComplete)
    elseif pieceType == Constants.PieceType.KING then
        BattleAnimations.kingWalk(piece, fromPos, toPos, onComplete)
    elseif pieceType == Constants.PieceType.QUEEN then
        BattleAnimations.queenDash(piece, fromPos, toPos, onComplete)
    elseif pieceType == Constants.PieceType.ROOK then
        BattleAnimations.rookSlide(piece, fromPos, toPos, onComplete)
    elseif pieceType == Constants.PieceType.BISHOP then
        BattleAnimations.bishopGlide(piece, fromPos, toPos, onComplete)
    elseif pieceType == Constants.PieceType.PAWN then
        BattleAnimations.pawnStep(piece, fromPos, toPos, onComplete)
    else
        -- Default to simple slide for unknown pieces
        BattleAnimations.slideMove(piece, fromPos, toPos, onComplete)
    end
end

-- Victory dance for winning piece
function BattleAnimations.victoryDance(piece)
    if not piece then return end

    local originalPos = piece.Position
    local bobInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local bob = TweenService:Create(piece, bobInfo, {
        Position = originalPos + Vector3.new(0, 1, 0)
    })

    local spinInfo = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
    local spin = TweenService:Create(piece, spinInfo, {
        Orientation = Vector3.new(0, 360, 0)
    })

    bob:Play()
    spin:Play()

    -- Stop after 3 seconds
    task.delay(3, function()
        bob:Cancel()
        spin:Cancel()
        piece.Position = originalPos
        piece.Orientation = Vector3.new(0, 0, 0)
    end)
end

-- Shake animation when in check
function BattleAnimations.checkShake(piece)
    if not piece then return end

    local originalPos = piece.Position

    for i = 1, 6 do
        task.spawn(function()
            local offset = Vector3.new(
                math.random(-1, 1) * 0.2,
                0,
                math.random(-1, 1) * 0.2
            )
            piece.Position = originalPos + offset
            task.wait(0.05)
        end)
        task.wait(0.1)
    end

    task.wait(0.1)
    piece.Position = originalPos
end

-- Fade out animation for captured piece
function BattleAnimations.fadeOutCapture(piece, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(piece, tweenInfo, {
        Transparency = 1,
        Size = piece.Size * 0.5
    })

    tween.Completed:Connect(function()
        piece:Destroy()
        if onComplete then onComplete() end
    end)

    tween:Play()
end

-- Spawn animation for new piece
function BattleAnimations.spawnPiece(piece, targetPos)
    if not piece then return end

    -- Start small and transparent
    piece.Size = Vector3.new(0.5, 0.5, 0.5)
    piece.Transparency = 1
    piece.Position = targetPos + Vector3.new(0, 5, 0)

    -- Animate to full size
    local growTween = TweenService:Create(piece, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
        Size = Vector3.new(3, 3, 3),
        Transparency = 0,
        Position = targetPos
    })

    growTween:Play()
end

return BattleAnimations
