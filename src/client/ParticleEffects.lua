--[[
    Claws & Paws - Particle Effects
    Visual flair: sparkles, paw prints, explosions, screen flash
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ParticleEffects = {}

-- Create sparkle effect for piece selection
function ParticleEffects.createSparkles(part)
    local sparkles = Instance.new("Sparkles")
    sparkles.Name = "SelectionSparkles"
    sparkles.SparkleColor = Color3.fromRGB(255, 215, 0)
    sparkles.Parent = part
    return sparkles
end

-- Create paw print trail effect
function ParticleEffects.createPawPrints(part)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "PawPrints"
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    emitter.Color = ColorSequence.new(Color3.fromRGB(139, 90, 60))
    emitter.Size = NumberSequence.new(0.5)
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.Rate = 5
    emitter.Speed = NumberRange.new(0, 0)
    emitter.SpreadAngle = Vector2.new(0, 0)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Enabled = false
    emitter.Parent = part
    return emitter
end

-- Multi-wave capture explosion with fur/spark burst
function ParticleEffects.captureExplosion(position, color)
    local function makeWave(delay, size, count, speed, lifetime)
        task.delay(delay, function()
            local host = Instance.new("Part")
            host.Size = Vector3.new(0.1, 0.1, 0.1)
            host.Position = position
            host.Anchored = true
            host.CanCollide = false
            host.Transparency = 1
            host.Parent = workspace

            local emitter = Instance.new("ParticleEmitter")
            emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            emitter.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.3, color),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50)),
            })
            emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, size),
                NumberSequenceKeypoint.new(1, 0),
            })
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.7, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            })
            emitter.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
            emitter.Speed = NumberRange.new(speed * 0.8, speed * 1.2)
            emitter.SpreadAngle = Vector2.new(180, 180)
            emitter.RotSpeed = NumberRange.new(-200, 200)
            emitter.Rotation = NumberRange.new(0, 360)
            emitter.Parent = host

            emitter:Emit(count)
            task.delay(lifetime + 0.5, function() host:Destroy() end)
        end)
    end

    makeWave(0,    2.5, 30, 14, 0.8)  -- Main burst
    makeWave(0.05, 1.2, 20, 8,  0.6)  -- Secondary fur/spark
    makeWave(0.12, 0.7, 15, 5,  1.0)  -- Lingering embers
end

-- Highlight valid moves with glow
function ParticleEffects.highlightSquare(square, color)
    local glow = Instance.new("SurfaceLight")
    glow.Name = "ValidMoveGlow"
    glow.Color = color or Color3.fromRGB(144, 238, 144)
    glow.Brightness = 1
    glow.Range = 8
    glow.Face = Enum.NormalId.Top
    glow.Parent = square
    return glow
end

-- Screen-edge flash for dramatic captures (red = enemy captured, gold = you captured)
function ParticleEffects.screenFlash(color, duration)
    local player = Players.LocalPlayer
    if not player then return end

    local gui = player.PlayerGui:FindFirstChild("ScreenFlashGui")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "ScreenFlashGui"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.IgnoreGuiInset = true
        gui.Parent = player.PlayerGui
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.Parent = gui

    -- Gradient so only edges show
    local gradient = Instance.new("UIGradient")
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.25, 1),
        NumberSequenceKeypoint.new(0.75, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    gradient.Rotation = 0
    gradient.Parent = frame

    TweenService:Create(frame, TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1
    }).Completed:Connect(function()
        frame:Destroy()
    end)

    TweenService:Create(frame, TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1
    }):Play()
end

-- Meow speech bubble
function ParticleEffects.createMeowBubble(piece, emoji)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MeowBubble"
    billboard.Size = UDim2.new(2, 0, 2, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = piece

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = emoji or "😺"
    label.TextSize = 48
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Parent = billboard

    task.spawn(function()
        for i = 1, 10 do
            label.TextTransparency = i / 10
            label.BackgroundTransparency = 0.3 + (i / 10) * 0.7
            billboard.StudsOffset = Vector3.new(0, 3 + i * 0.2, 0)
            task.wait(0.1)
        end
        billboard:Destroy()
    end)
end

return ParticleEffects
