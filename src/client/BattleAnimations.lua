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
