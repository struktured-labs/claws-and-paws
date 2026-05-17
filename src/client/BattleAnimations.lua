--[[
    Claws & Paws - Battle Animations
    Cat combat animations for captures and moves
    Features dramatic cat fights with sound effects!
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared")).Constants
local BattleAnimations = {}

-- ==========================================
-- HELPERS
-- ==========================================

local function getMainPart(piece)
    if not piece then return nil end
    if piece:IsA("Model") then
        return piece.PrimaryPart or piece:FindFirstChildWhichIsA("BasePart")
    end
    return piece:IsA("BasePart") and piece or nil
end

local function flashPart(part, color, duration)
    if not part or not part:IsA("BasePart") then return end
    local origColor, origMat = part.Color, part.Material
    part.Color = color
    part.Material = Enum.Material.Neon
    task.delay(duration, function()
        if part and part.Parent then
            part.Color = origColor
            part.Material = origMat
        end
    end)
end

local function shakePart(part, intensity, duration)
    if not part then return end
    local originalPos = part.Position
    local elapsed = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= duration then
            if part and part.Parent then part.Position = originalPos end
            conn:Disconnect()
            return
        end
        local decay = 1 - (elapsed / duration)
        if part and part.Parent then
            part.Position = originalPos + Vector3.new(
                (math.random() - 0.5) * 2 * intensity * decay,
                (math.random() - 0.5) * intensity * decay * 0.5,
                (math.random() - 0.5) * 2 * intensity * decay
            )
        end
    end)
end

local function spawnCombatText(position, text, color)
    local host = Instance.new("Part")
    host.Size = Vector3.new(0.1, 0.1, 0.1)
    host.Position = position + Vector3.new(0, 5, 0)
    host.Anchored = true
    host.CanCollide = false
    host.Transparency = 1
    host.Parent = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 220, 0, 80)
    billboard.AlwaysOnTop = true
    billboard.Parent = host

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 100)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.FredokaOne
    label.TextScaled = true
    label.TextTransparency = 1
    label.Parent = billboard

    TweenService:Create(label, TweenInfo.new(0.1), {TextTransparency = 0}):Play()
    task.spawn(function()
        task.wait(0.1)
        TweenService:Create(host, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = host.Position + Vector3.new(0, 8, 0)
        }):Play()
        TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1
        }).Completed:Connect(function() host:Destroy() end)
        TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    end)
end

local function spawnImpactRing(position, color)
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(2, 0.2, 2)
    ring.Position = position + Vector3.new(0, 0.5, 0)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Color = color or Color3.fromRGB(255, 200, 50)
    ring.Material = Enum.Material.Neon
    ring.Shape = Enum.PartType.Cylinder
    ring.Orientation = Vector3.new(0, 0, 90)
    ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 16, 16),
        Transparency = 1,
    }):Play()
    task.delay(0.5, function() if ring and ring.Parent then ring:Destroy() end end)
end

-- ==========================================
-- PER-PIECE CAPTURE ANIMATIONS
-- ==========================================

local function knightCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then if onComplete then onComplete() end return end
    flashPart(part, Color3.fromRGB(255, 255, 0), 0.15)
    local peakPos = Vector3.new((fromPos.X+toPos.X)/2, math.max(fromPos.Y,toPos.Y)+14, (fromPos.Z+toPos.Z)/2)
    task.delay(0.1, function()
        local up = TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=peakPos, Orientation=Vector3.new(360,0,0)})
        local down = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position=toPos})
        up.Completed:Connect(function() down:Play() end)
        down.Completed:Connect(function()
            part.Orientation = Vector3.new(0,0,0)
            flashPart(part, Color3.fromRGB(200,255,255), 0.2)
            spawnImpactRing(toPos, Color3.fromRGB(100,200,255))
            shakePart(part, 1.2, 0.4)
            spawnCombatText(toPos, "ZAP!", Color3.fromRGB(100,220,255))
            if onComplete then onComplete() end
        end)
        up:Play()
    end)
end

local function queenCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then if onComplete then onComplete() end return end
    flashPart(part, Color3.fromRGB(255,50,200), 0.1)
    local overshoot = toPos + (toPos-fromPos).Unit * 3
    local pullback  = toPos + (fromPos-toPos).Unit * 2
    local d1 = TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position=overshoot})
    local d2 = TweenService:Create(part, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=pullback})
    local d3 = TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position=toPos})
    d1.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255,150,255), 0.08)
        spawnCombatText(overshoot, "SLASH!", Color3.fromRGB(255,100,255))
        d2:Play()
    end)
    d2.Completed:Connect(function() d3:Play() end)
    d3.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255,255,255), 0.2)
        spawnImpactRing(toPos, Color3.fromRGB(255,50,200))
        shakePart(part, 1.0, 0.35)
        spawnCombatText(toPos, "COMBO!", Color3.fromRGB(255,50,200))
        if onComplete then onComplete() end
    end)
    d1:Play()
end

local function rookCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then if onComplete then onComplete() end return end
    local windupPos = fromPos + (fromPos-toPos).Unit * 2.5
    local overshoot = toPos + (toPos-fromPos).Unit * 2
    local windup = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=windupPos, Size=part.Size*Vector3.new(1.3,0.8,1.3)})
    local charge = TweenService:Create(part, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position=overshoot, Size=part.Size*Vector3.new(0.7,1.3,0.7)})
    local settle = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Position=toPos, Size=part.Size})
    windup.Completed:Connect(function() charge:Play() end)
    charge.Completed:Connect(function()
        spawnImpactRing(overshoot, Color3.fromRGB(255,100,50))
        spawnCombatText(overshoot, "SMASH!", Color3.fromRGB(255,120,50))
        settle:Play()
    end)
    settle.Completed:Connect(function()
        shakePart(part, 1.5, 0.4)
        if onComplete then onComplete() end
    end)
    windup:Play()
end

local function bishopCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then if onComplete then onComplete() end return end
    local ghost = part:Clone()
    ghost.Parent = workspace
    ghost.Anchored = true
    ghost.CanCollide = false
    task.spawn(function()
        for i = 1, 8 do
            if ghost and ghost.Parent then ghost.Transparency = i/8 end
            task.wait(0.05)
        end
        if ghost and ghost.Parent then ghost:Destroy() end
    end)
    local shrink = TweenService:Create(part, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size=part.Size*0.01, Transparency=1, Orientation=Vector3.new(0,540,0)
    })
    shrink.Completed:Connect(function()
        part.Position = toPos
        part.Orientation = Vector3.new(0,0,0)
        local grow = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size=Vector3.new(5,4.5,6), Transparency=0
        })
        grow.Completed:Connect(function()
            spawnImpactRing(toPos, Color3.fromRGB(150,50,255))
            spawnCombatText(toPos, "BLINK!", Color3.fromRGB(180,100,255))
            if onComplete then onComplete() end
        end)
        grow:Play()
    end)
    shrink:Play()
end

local function kingCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then if onComplete then onComplete() end return end
    local windupPos = fromPos + (fromPos-toPos).Unit * 1.5
    local overshoot = toPos + (toPos-fromPos).Unit * 1.5
    local windup = TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position=windupPos})
    local lunge  = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position=overshoot, Orientation=Vector3.new(0,0,30)})
    local settle = TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Position=toPos, Orientation=Vector3.new(0,0,0)})
    windup.Completed:Connect(function() lunge:Play() end)
    lunge.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255,215,0), 0.25)
        spawnImpactRing(overshoot, Color3.fromRGB(255,215,0))
        shakePart(part, 1.0, 0.35)
        spawnCombatText(toPos, "ROYAL STRIKE!", Color3.fromRGB(255,215,0))
        settle:Play()
    end)
    settle.Completed:Connect(function() if onComplete then onComplete() end end)
    windup:Play()
end

local function pawnCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then if onComplete then onComplete() end return end
    local sideOffset = Vector3.new((toPos.Z-fromPos.Z)*0.4, 3, -(toPos.X-fromPos.X)*0.4)
    local mid = Vector3.new((fromPos.X+toPos.X)/2+sideOffset.X, fromPos.Y+3, (fromPos.Z+toPos.Z)/2+sideOffset.Z)
    local hop    = TweenService:Create(part, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=mid, Orientation=Vector3.new(0,45,0)})
    local strike = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position=toPos, Orientation=Vector3.new(0,0,0)})
    hop.Completed:Connect(function() strike:Play() end)
    strike.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255,200,100), 0.15)
        spawnCombatText(toPos, "SWIPE!", Color3.fromRGB(255,200,100))
        if onComplete then onComplete() end
    end)
    hop:Play()
end

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
        if Constants.DEBUG then print("🐱 [ANIM] Fight skipped!") end
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

-- Smart move selector - picks animation based on piece type and whether it's a capture
function BattleAnimations.smartMove(piece, fromPos, toPos, pieceType, isCapture, onComplete)
    if not piece then
        if onComplete then onComplete() end
        return
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = require(ReplicatedStorage.Shared)
    local Constants = Shared.Constants

    if isCapture then
        -- Route to per-piece dramatic capture animations
        if pieceType == Constants.PieceType.KNIGHT then
            knightCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == Constants.PieceType.QUEEN then
            queenCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == Constants.PieceType.ROOK then
            rookCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == Constants.PieceType.BISHOP then
            bishopCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == Constants.PieceType.KING then
            kingCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == Constants.PieceType.PAWN then
            pawnCapture(piece, fromPos, toPos, onComplete)
        else
            BattleAnimations.pounceCapture(piece, fromPos, toPos, onComplete)
        end
    else
        -- Regular move animations
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
