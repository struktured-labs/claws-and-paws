--[[
    Claws & Paws - Battle Animations
    Cat combat animations for captures and moves
    Features dramatic cat fights with sound effects!
]]

local TweenService = game:GetService("TweenService")
local BattleAnimations = {}

-- Track active fight so it can be skipped
local activeFight = nil  -- {cancelled = false, tweens = {}, onComplete = function}

-- Cancel all active tweens for a fight
local function cancelAllTweens(fight)
    if not fight then return end
    fight.cancelled = true
    for _, tween in ipairs(fight.tweens) do
        if tween then
            pcall(function() tween:Cancel() end)
        end
    end
end

-- Create and track a tween within a fight
local function createFightTween(fight, piece, tweenInfo, properties)
    if fight.cancelled then return nil end
    local tween = TweenService:Create(piece, tweenInfo, properties)
    table.insert(fight.tweens, tween)
    return tween
end

-- Play a tracked tween and wait for it
local function playAndWait(fight, tween, timeout)
    if fight.cancelled or not tween then return end
    tween:Play()
    local completed = false
    tween.Completed:Connect(function()
        completed = true
    end)
    local elapsed = 0
    local maxWait = timeout or 5
    while not completed and not fight.cancelled and elapsed < maxWait do
        task.wait(0.03)
        elapsed = elapsed + 0.03
    end
end

-- Get SoundManager safely
local function getSoundManager()
    local success, result = pcall(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        -- SoundManager is loaded as a sibling module
        return require(script.SoundManager)
    end)
    if success then return result end
    return nil
end

-- ============================================================
-- DRAMATIC CAT FIGHT ANIMATION (for captures)
-- ============================================================
function BattleAnimations.catFight(attacker, defender, fromPos, toPos, onComplete)
    if not attacker then
        if onComplete then onComplete() end
        return
    end

    -- Set up fight tracking for skip functionality
    local fight = {
        cancelled = false,
        tweens = {},
        onComplete = onComplete,
    }
    activeFight = fight

    local SoundManager = getSoundManager()

    task.spawn(function()
        -- ==========================================
        -- PHASE 1: Attacker crouches and hisses (0.4s)
        -- ==========================================
        if fight.cancelled then
            if onComplete then onComplete() end
            return
        end

        -- Crouch down (flatten)
        local crouchTween = createFightTween(fight, attacker,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = fromPos + Vector3.new(0, -1, 0)}
        )
        playAndWait(fight, crouchTween)

        -- Hiss sound
        if SoundManager and not fight.cancelled then
            pcall(function() SoundManager.playCheckSound() end) -- Growl = hiss
        end

        -- Brief pause for tension
        if not fight.cancelled then task.wait(0.15) end

        -- ==========================================
        -- PHASE 2: Attacker LEAPS toward defender (0.5s)
        -- ==========================================
        if fight.cancelled then
            attacker.Position = toPos
            if onComplete then onComplete() end
            return
        end

        -- High arc leap
        local leapHeight = 12  -- Much higher than before
        local midpoint = Vector3.new(
            (fromPos.X + toPos.X) / 2,
            math.max(fromPos.Y, toPos.Y) + leapHeight,
            (fromPos.Z + toPos.Z) / 2
        )

        -- Pounce sound
        if SoundManager and not fight.cancelled then
            pcall(function() SoundManager.playCaptureSound() end)
        end

        -- Leap up with spin
        local leapUpTween = createFightTween(fight, attacker,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = midpoint}
        )
        local spinTween = createFightTween(fight, attacker,
            TweenInfo.new(0.6, Enum.EasingStyle.Linear),
            {Orientation = Vector3.new(0, 720, 0)} -- Double spin!
        )
        if leapUpTween then leapUpTween:Play() end
        if spinTween then spinTween:Play() end
        -- Wait for leap up
        if leapUpTween then
            local done = false
            leapUpTween.Completed:Connect(function() done = true end)
            while not done and not fight.cancelled do task.wait(0.03) end
        end

        if fight.cancelled then
            attacker.Position = toPos
            attacker.Orientation = Vector3.new(0, 0, 0)
            if onComplete then onComplete() end
            return
        end

        -- Slam down onto defender
        local slamTween = createFightTween(fight, attacker,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = toPos}
        )
        playAndWait(fight, slamTween)

        -- ==========================================
        -- PHASE 3: Impact! Dust cloud fight (1.0s)
        -- ==========================================
        if fight.cancelled then
            attacker.Position = toPos
            attacker.Orientation = Vector3.new(0, 0, 0)
            if onComplete then onComplete() end
            return
        end

        -- Create dust cloud effect at impact point
        local dustCloud = Instance.new("Part")
        dustCloud.Name = "FightDustCloud"
        dustCloud.Shape = Enum.PartType.Ball
        dustCloud.Size = Vector3.new(8, 8, 8)
        dustCloud.Position = toPos
        dustCloud.Anchored = true
        dustCloud.CanCollide = false
        dustCloud.Transparency = 0.4
        dustCloud.Color = Color3.fromRGB(220, 200, 170) -- Dusty tan
        dustCloud.Material = Enum.Material.SmoothPlastic
        dustCloud.Parent = workspace

        -- Smoke particles inside cloud
        local smoke = Instance.new("ParticleEmitter")
        smoke.Name = "FightSmoke"
        smoke.Color = ColorSequence.new(Color3.fromRGB(200, 180, 150))
        smoke.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 2),
            NumberSequenceKeypoint.new(1, 6),
        })
        smoke.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        smoke.Lifetime = NumberRange.new(0.3, 0.6)
        smoke.Rate = 40
        smoke.Speed = NumberRange.new(3, 8)
        smoke.SpreadAngle = Vector2.new(180, 180)
        smoke.Parent = dustCloud

        -- Hide attacker inside dust cloud
        attacker.Transparency = 0.7

        -- Shake the cloud rapidly to simulate fighting
        local shakeCount = 0
        local maxShakes = 8
        while shakeCount < maxShakes and not fight.cancelled do
            -- Random shake offset
            local shakeOffset = Vector3.new(
                math.random(-20, 20) / 10,
                math.random(0, 10) / 10,
                math.random(-20, 20) / 10
            )
            local shakeTween = createFightTween(fight, dustCloud,
                TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Position = toPos + shakeOffset, Size = Vector3.new(8 + math.random(-2, 2), 8, 8 + math.random(-2, 2))}
            )
            playAndWait(fight, shakeTween)

            -- Cat fight sounds on alternating shakes
            if SoundManager and shakeCount % 2 == 0 and not fight.cancelled then
                pcall(function()
                    if shakeCount % 4 == 0 then
                        SoundManager.playCheckSound() -- Growl
                    else
                        SoundManager.playMoveSound(2) -- Knight pounce sound
                    end
                end)
            end

            shakeCount = shakeCount + 1
        end

        -- ==========================================
        -- PHASE 4: Dust clears, attacker victorious (0.6s)
        -- ==========================================

        -- Fade out dust cloud
        if dustCloud and dustCloud.Parent then
            smoke.Rate = 0  -- Stop emitting
            local fadeCloud = createFightTween(fight, dustCloud,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Transparency = 1, Size = Vector3.new(15, 15, 15)}
            )
            if fadeCloud and not fight.cancelled then
                fadeCloud:Play()
                fadeCloud.Completed:Connect(function()
                    dustCloud:Destroy()
                end)
            else
                dustCloud:Destroy()
            end
        end

        -- Reveal attacker
        attacker.Transparency = 0
        attacker.Position = toPos

        if fight.cancelled then
            attacker.Orientation = Vector3.new(0, 0, 0)
            if onComplete then onComplete() end
            return
        end

        -- Victory bounce!
        local bounceUp = createFightTween(fight, attacker,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = toPos + Vector3.new(0, 4, 0)}
        )
        playAndWait(fight, bounceUp)

        -- Happy meow!
        if SoundManager and not fight.cancelled then
            pcall(function() SoundManager.playHappyMeow() end)
        end

        local bounceLand = createFightTween(fight, attacker,
            TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
            {Position = toPos}
        )
        playAndWait(fight, bounceLand)

        -- Reset orientation
        attacker.Orientation = Vector3.new(0, 0, 0)

        -- Clean up fight state
        activeFight = nil

        if onComplete then onComplete() end
    end)
end

-- Skip the current fight animation
function BattleAnimations.skipFight()
    if activeFight and not activeFight.cancelled then
        print("🐱 [ANIM] Fight skipped!")
        cancelAllTweens(activeFight)
        -- onComplete will be called by the fight coroutine when it detects cancellation
    end
end

-- Check if a fight animation is active
function BattleAnimations.isFightActive()
    return activeFight ~= nil and not activeFight.cancelled
end

-- ============================================================
-- LEGACY: Pounce capture (kept as fallback, used for quick captures)
-- ============================================================
function BattleAnimations.pounceCapture(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local midpoint = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        math.max(fromPos.Y, toPos.Y) + 3,
        (fromPos.Z + toPos.Z) / 2
    )

    local upTween = TweenService:Create(piece, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = midpoint
    })

    local downTween = TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = toPos
    })

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

-- ============================================================
-- MOVEMENT ANIMATIONS (unchanged for regular moves)
-- ============================================================

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

function BattleAnimations.knightHop(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local midHeight = math.max(fromPos.Y, toPos.Y) + 5
    local midpoint = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        midHeight,
        (fromPos.Z + toPos.Z) / 2
    )

    local upTween = TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = midpoint,
        Orientation = Vector3.new(0, 180, 0)
    })

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

function BattleAnimations.kingWalk(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local distance = (toPos - fromPos).Magnitude
    local duration = math.max(0.5, distance / 10)

    local mainTween = TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        Position = toPos
    })

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

function BattleAnimations.queenDash(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local tween = TweenService:Create(piece, tweenInfo, {
        Position = toPos
    })

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

function BattleAnimations.rookSlide(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(piece, tweenInfo, {
        Position = toPos
    })

    tween.Completed:Connect(function()
        if onComplete then onComplete() end
    end)

    tween:Play()
end

function BattleAnimations.bishopGlide(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

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

function BattleAnimations.pawnStep(piece, fromPos, toPos, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

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

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = require(ReplicatedStorage.Shared)
    local Constants = Shared.Constants

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

    piece.Size = Vector3.new(0.5, 0.5, 0.5)
    piece.Transparency = 1
    piece.Position = targetPos + Vector3.new(0, 5, 0)

    local growTween = TweenService:Create(piece, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
        Size = Vector3.new(3, 3, 3),
        Transparency = 0,
        Position = targetPos
    })

    growTween:Play()
end

return BattleAnimations
