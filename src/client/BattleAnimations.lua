--[[
    Claws & Paws - Battle Animations
    Elaborate cat combat animations with personality and flair
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local BattleAnimations = {}

-- Helper: get main animatable part from piece (Part or Model)
local function getMainPart(piece)
    if not piece then return nil end
    if piece:IsA("Model") then
        return piece.PrimaryPart or piece:FindFirstChildWhichIsA("BasePart")
    end
    return piece:IsA("BasePart") and piece or nil
end

-- Helper: flash a part a color and back
local function flashPart(part, color, duration)
    if not part or not part:IsA("BasePart") then return end
    local originalColor = part.Color
    local originalMat = part.Material
    part.Color = color
    part.Material = Enum.Material.Neon
    task.delay(duration, function()
        if part and part.Parent then
            part.Color = originalColor
            part.Material = originalMat
        end
    end)
end

-- Helper: shake a part in place
local function shakePart(part, intensity, duration)
    if not part then return end
    local originalPos = part.Position
    local elapsed = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= duration then
            part.Position = originalPos
            conn:Disconnect()
            return
        end
        local decay = 1 - (elapsed / duration)
        part.Position = originalPos + Vector3.new(
            (math.random() - 0.5) * 2 * intensity * decay,
            (math.random() - 0.5) * intensity * decay * 0.5,
            (math.random() - 0.5) * 2 * intensity * decay
        )
    end)
end

-- Helper: create a floating combat text label above a position
local function spawnCombatText(position, text, color)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Position = position + Vector3.new(0, 5, 0)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 80)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 100)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.FredokaOne
    label.TextScaled = true
    label.Parent = billboard

    -- Pop in, float up, fade out
    label.TextTransparency = 1
    TweenService:Create(label, TweenInfo.new(0.1), {TextTransparency = 0}):Play()

    task.spawn(function()
        task.wait(0.1)
        local floatTween = TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = part.Position + Vector3.new(0, 8, 0)
        })
        local fadeTween = TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1
        })
        floatTween:Play()
        fadeTween:Play()
        floatTween.Completed:Connect(function()
            part:Destroy()
        end)
    end)
end

-- Helper: impact ring shockwave on landing
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

    task.delay(0.5, function() ring:Destroy() end)
end

-- ==========================================
-- CAPTURE ANIMATIONS (piece-specific)
-- ==========================================

-- Default pounce: dramatic arc with wind-up, spin, and ground shake
function BattleAnimations.pounceCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    -- Wind-up: lean back before jumping
    local windupPos = fromPos + (fromPos - toPos).Unit * 1.5
    local peakPos = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        math.max(fromPos.Y, toPos.Y) + 10,
        (fromPos.Z + toPos.Z) / 2
    )

    local windupTween = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = windupPos,
        Size = part.Size * 0.85,
    })
    local stretchTween = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = peakPos,
        Size = part.Size * Vector3.new(0.7, 1.4, 0.7),
    })
    local downTween = TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = toPos,
        Size = part.Size,
    })
    local spinTween = TweenService:Create(part, TweenInfo.new(0.54, Enum.EasingStyle.Linear), {
        Orientation = Vector3.new(0, 720, 0)
    })

    windupTween.Completed:Connect(function()
        stretchTween:Play()
        spinTween:Play()
    end)
    stretchTween.Completed:Connect(function()
        downTween:Play()
    end)
    downTween.Completed:Connect(function()
        part.Orientation = Vector3.new(0, 0, 0)
        -- Landing impact
        spawnImpactRing(toPos, Color3.fromRGB(255, 150, 50))
        shakePart(part, 0.8, 0.3)
        spawnCombatText(toPos, "POUNCE!", Color3.fromRGB(255, 200, 50))
        if onComplete then onComplete() end
    end)

    windupTween:Play()
end

-- Knight: dramatic lightning leap — high arc with pre-flash and thundercrack on land
function BattleAnimations.knightCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    -- Flash yellow before leaping
    flashPart(part, Color3.fromRGB(255, 255, 0), 0.15)

    local peakPos = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        math.max(fromPos.Y, toPos.Y) + 14,
        (fromPos.Z + toPos.Z) / 2
    )

    task.delay(0.1, function()
        local upTween = TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = peakPos,
            Orientation = Vector3.new(360, 0, 0),
        })
        local downTween = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = toPos,
        })

        upTween.Completed:Connect(function() downTween:Play() end)
        downTween.Completed:Connect(function()
            part.Orientation = Vector3.new(0, 0, 0)
            flashPart(part, Color3.fromRGB(200, 255, 255), 0.2)
            spawnImpactRing(toPos, Color3.fromRGB(100, 200, 255))
            shakePart(part, 1.2, 0.4)
            spawnCombatText(toPos, "ZAP!", Color3.fromRGB(100, 220, 255))
            if onComplete then onComplete() end
        end)

        upTween:Play()
    end)
end

-- Queen: three-hit combo dash — blurs across the board in a triple strike
function BattleAnimations.queenCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    flashPart(part, Color3.fromRGB(255, 50, 200), 0.1)

    -- Three-step combo: dash past, come back, final strike
    local overshoot = toPos + (toPos - fromPos).Unit * 3
    local pullback  = toPos + (fromPos - toPos).Unit * 2

    local dash1 = TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = overshoot})
    local dash2 = TweenService:Create(part, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = pullback})
    local dash3 = TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = toPos})

    dash1.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255, 150, 255), 0.08)
        spawnCombatText(overshoot, "SLASH!", Color3.fromRGB(255, 100, 255))
        dash2:Play()
    end)
    dash2.Completed:Connect(function() dash3:Play() end)
    dash3.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255, 255, 255), 0.2)
        spawnImpactRing(toPos, Color3.fromRGB(255, 50, 200))
        shakePart(part, 1.0, 0.35)
        spawnCombatText(toPos, "COMBO!", Color3.fromRGB(255, 50, 200))
        if onComplete then onComplete() end
    end)

    dash1:Play()
end

-- Rook: charging ram — telegraphed buildup then an unstoppable straight charge
function BattleAnimations.rookCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    -- Windup: rock back
    local windupPos = fromPos + (fromPos - toPos).Unit * 2.5
    local overshoot = toPos + (toPos - fromPos).Unit * 2

    local windup = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = windupPos,
        Size = part.Size * Vector3.new(1.3, 0.8, 1.3),
    })
    local charge = TweenService:Create(part, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Position = overshoot,
        Size = part.Size * Vector3.new(0.7, 1.3, 0.7),
    })
    local settle = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
        Position = toPos,
        Size = part.Size,
    })

    windup.Completed:Connect(function() charge:Play() end)
    charge.Completed:Connect(function()
        spawnImpactRing(overshoot, Color3.fromRGB(255, 100, 50))
        spawnCombatText(overshoot, "SMASH!", Color3.fromRGB(255, 120, 50))
        settle:Play()
    end)
    settle.Completed:Connect(function()
        shakePart(part, 1.5, 0.4)
        if onComplete then onComplete() end
    end)

    windup:Play()
end

-- Bishop: mystic blink — teleports with ghosting trail and reality-warp effect
function BattleAnimations.bishopCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    -- Leave ghost at origin
    local ghost = part:Clone()
    ghost.Parent = workspace
    ghost.Anchored = true
    ghost.CanCollide = false

    -- Ghost fade out
    task.spawn(function()
        for i = 1, 8 do
            if ghost and ghost.Parent then
                ghost.Transparency = i / 8
            end
            task.wait(0.05)
        end
        if ghost and ghost.Parent then ghost:Destroy() end
    end)

    -- Spin-shrink out
    local shrinkOut = TweenService:Create(part, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = part.Size * 0.01,
        Transparency = 1,
        Orientation = Vector3.new(0, 540, 0),
    })

    shrinkOut.Completed:Connect(function()
        part.Position = toPos
        part.Orientation = Vector3.new(0, 0, 0)

        -- Burst-grow in at target
        local growIn = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = part.Size * (1 / 0.01),
            Transparency = 0,
        })
        growIn.Completed:Connect(function()
            local correctSize = Vector3.new(5, 4.5, 6)
            part.Size = correctSize
            part.Transparency = 0
            spawnImpactRing(toPos, Color3.fromRGB(150, 50, 255))
            spawnCombatText(toPos, "BLINK!", Color3.fromRGB(180, 100, 255))
            if onComplete then onComplete() end
        end)
        growIn:Play()
    end)

    shrinkOut:Play()
end

-- King: desperate lunge — slow wind-up then a powerful, committed strike
function BattleAnimations.kingCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    -- Regal wind-up (slow)
    local windupPos = fromPos + (fromPos - toPos).Unit * 1.5
    local overshoot = toPos + (toPos - fromPos).Unit * 1.5

    local windup = TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        Position = windupPos,
    })
    local lunge = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Position = overshoot,
        Orientation = Vector3.new(0, 0, 30),
    })
    local settle = TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Position = toPos,
        Orientation = Vector3.new(0, 0, 0),
    })

    windup.Completed:Connect(function() lunge:Play() end)
    lunge.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255, 215, 0), 0.25)
        spawnImpactRing(overshoot, Color3.fromRGB(255, 215, 0))
        shakePart(part, 1.0, 0.35)
        spawnCombatText(toPos, "ROYAL STRIKE!", Color3.fromRGB(255, 215, 0))
        settle:Play()
    end)
    settle.Completed:Connect(function()
        if onComplete then onComplete() end
    end)

    windup:Play()
end

-- Pawn: sneaky ambush swipe — quick sideways pounce with tiny claw swipe effect
function BattleAnimations.pawnCapture(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    -- Arc slightly to the side before striking
    local sideOffset = Vector3.new(
        (toPos.Z - fromPos.Z) * 0.4,
        3,
        -(toPos.X - fromPos.X) * 0.4
    )
    local midpoint = Vector3.new(
        (fromPos.X + toPos.X) / 2 + sideOffset.X,
        fromPos.Y + 3,
        (fromPos.Z + toPos.Z) / 2 + sideOffset.Z
    )

    local hop = TweenService:Create(part, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = midpoint,
        Orientation = Vector3.new(0, 45, 0),
    })
    local strike = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = toPos,
        Orientation = Vector3.new(0, 0, 0),
    })

    hop.Completed:Connect(function() strike:Play() end)
    strike.Completed:Connect(function()
        flashPart(part, Color3.fromRGB(255, 200, 100), 0.15)
        spawnCombatText(toPos, "SWIPE!", Color3.fromRGB(255, 200, 100))
        if onComplete then onComplete() end
    end)

    hop:Play()
end

-- ==========================================
-- MOVE ANIMATIONS (non-capture)
-- ==========================================

function BattleAnimations.slideMove(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end
    TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = toPos
    }).Completed:Connect(function()
        if onComplete then onComplete() end
    end)
    TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = toPos}):Play()
end

function BattleAnimations.knightHop(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    local peakPos = Vector3.new(
        (fromPos.X + toPos.X) / 2,
        math.max(fromPos.Y, toPos.Y) + 8,
        (fromPos.Z + toPos.Z) / 2
    )

    local up = TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = peakPos,
        Orientation = Vector3.new(0, 180, 0),
    })
    local down = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = toPos,
        Orientation = Vector3.new(0, 360, 0),
    })

    up.Completed:Connect(function() down:Play() end)
    down.Completed:Connect(function()
        part.Orientation = Vector3.new(0, 0, 0)
        spawnImpactRing(toPos, Color3.fromRGB(180, 255, 180))
        if onComplete then onComplete() end
    end)

    up:Play()
end

function BattleAnimations.kingWalk(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end
    local distance = (toPos - fromPos).Magnitude
    local duration = math.max(0.5, distance / 10)
    TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        Position = toPos
    }).Completed:Connect(function()
        if onComplete then onComplete() end
    end)
    TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = toPos}):Play()
end

function BattleAnimations.queenDash(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end
    local tween = TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = toPos})
    tween.Completed:Connect(function()
        if onComplete then onComplete() end
    end)
    tween:Play()
end

function BattleAnimations.rookSlide(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end
    -- Brief squish on departure
    local squish = TweenService:Create(part, TweenInfo.new(0.08), {
        Size = part.Size * Vector3.new(0.8, 1.2, 0.8)
    })
    squish.Completed:Connect(function()
        local slide = TweenService:Create(part, TweenInfo.new(0.28, Enum.EasingStyle.Linear), {
            Position = toPos,
            Size = part.Size,
        })
        slide.Completed:Connect(function()
            if onComplete then onComplete() end
        end)
        slide:Play()
    end)
    squish:Play()
end

function BattleAnimations.bishopGlide(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end
    local tween = TweenService:Create(part, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        Position = toPos,
        Orientation = Vector3.new(0, 180, 0),
    })
    tween.Completed:Connect(function()
        part.Orientation = Vector3.new(0, 0, 0)
        if onComplete then onComplete() end
    end)
    tween:Play()
end

function BattleAnimations.pawnStep(piece, fromPos, toPos, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end
    local mid = Vector3.new((fromPos.X + toPos.X) / 2, fromPos.Y + 1.5, (fromPos.Z + toPos.Z) / 2)
    local up = TweenService:Create(part, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = mid})
    local down = TweenService:Create(part, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = toPos})
    up.Completed:Connect(function() down:Play() end)
    down.Completed:Connect(function()
        if onComplete then onComplete() end
    end)
    up:Play()
end

-- Smart router: picks capture or move animation based on piece type and isCapture flag
function BattleAnimations.smartMove(piece, fromPos, toPos, pieceType, isCapture, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Constants = require(ReplicatedStorage.Shared).Constants
    local P = Constants.PieceType

    if isCapture then
        if pieceType == P.KNIGHT then
            BattleAnimations.knightCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.QUEEN then
            BattleAnimations.queenCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.ROOK then
            BattleAnimations.rookCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.BISHOP then
            BattleAnimations.bishopCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.KING then
            BattleAnimations.kingCapture(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.PAWN then
            BattleAnimations.pawnCapture(piece, fromPos, toPos, onComplete)
        else
            BattleAnimations.pounceCapture(piece, fromPos, toPos, onComplete)
        end
    else
        if pieceType == P.KNIGHT then
            BattleAnimations.knightHop(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.KING then
            BattleAnimations.kingWalk(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.QUEEN then
            BattleAnimations.queenDash(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.ROOK then
            BattleAnimations.rookSlide(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.BISHOP then
            BattleAnimations.bishopGlide(piece, fromPos, toPos, onComplete)
        elseif pieceType == P.PAWN then
            BattleAnimations.pawnStep(piece, fromPos, toPos, onComplete)
        else
            BattleAnimations.slideMove(piece, fromPos, toPos, onComplete)
        end
    end
end

-- ==========================================
-- BOARD STATE ANIMATIONS
-- ==========================================

-- Dramatic captured piece death: flash red, spin out, explode
function BattleAnimations.fadeOutCapture(piece, onComplete)
    local part = getMainPart(piece)
    if not part then
        if onComplete then onComplete() end
        return
    end

    -- Flash red
    flashPart(part, Color3.fromRGB(255, 50, 50), 0.1)

    task.delay(0.1, function()
        if not part or not part.Parent then
            if onComplete then onComplete() end
            return
        end
        -- Spin out and shrink
        local spinOut = TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Orientation = Vector3.new(0, 720, 45),
            Size = part.Size * 0.1,
            Transparency = 1,
        })
        spinOut.Completed:Connect(function()
            if piece and piece.Parent then piece:Destroy() end
            if onComplete then onComplete() end
        end)
        spinOut:Play()
    end)
end

-- Victory dance: escalating celebration with multiple phases
function BattleAnimations.victoryDance(piece)
    local part = getMainPart(piece)
    if not part then return end

    local originalPos = part.Position
    local originalSize = part.Size

    -- Phase 1: excited bouncing
    local bounce = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 4, true), {
        Position = originalPos + Vector3.new(0, 3, 0)
    })
    bounce:Play()

    -- Phase 2: spin with color flash
    task.delay(1.6, function()
        if not part or not part.Parent then return end
        flashPart(part, Color3.fromRGB(255, 215, 0), 0.4)
        local spin = TweenService:Create(part, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 2), {
            Orientation = Vector3.new(0, 720, 0)
        })
        spin:Play()

        -- Float up
        TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Position = originalPos + Vector3.new(0, 4, 0)
        }):Play()
    end)

    -- Phase 3: settle back down
    task.delay(3.5, function()
        if not part or not part.Parent then return end
        part.Orientation = Vector3.new(0, 0, 0)
        TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            Position = originalPos,
            Size = originalSize,
        }):Play()
    end)
end

-- Check shake: urgent, panicked trembling
function BattleAnimations.checkShake(piece)
    local part = getMainPart(piece)
    if not part then return end

    flashPart(part, Color3.fromRGB(255, 50, 50), 0.6)
    shakePart(part, 0.6, 0.6)
    spawnCombatText(part.Position, "CHECK!", Color3.fromRGB(255, 80, 80))
end

-- Spawn animation: dramatic drop-in from the sky with bounce
function BattleAnimations.spawnPiece(piece, targetPos)
    local part = getMainPart(piece)
    if not part then return end

    local originalSize = part.Size
    part.Size = originalSize * 0.1
    part.Transparency = 1
    part.Position = targetPos + Vector3.new(0, 20, 0)

    local drop = TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = targetPos,
        Transparency = 0,
    })
    drop.Completed:Connect(function()
        spawnImpactRing(targetPos, Color3.fromRGB(255, 215, 0))
        TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            Size = originalSize
        }):Play()
    end)
    drop:Play()
end

return BattleAnimations
