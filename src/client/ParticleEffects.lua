--[[
    Claws & Paws - Particle Effects
    Sparkles, paw prints, and other visual flair
]]

local ParticleEffects = {}

-- Create sparkle effect for piece selection
function ParticleEffects.createSparkles(part)
    local sparkles = Instance.new("Sparkles")
    sparkles.Name = "SelectionSparkles"
    sparkles.SparkleColor = Color3.fromRGB(255, 215, 0) -- Gold sparkles
    sparkles.Parent = part
    return sparkles
end

-- Create paw print trail effect
function ParticleEffects.createPawPrints(part)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "PawPrints"

    -- Paw print appearance
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds" -- Placeholder
    emitter.Color = ColorSequence.new(Color3.fromRGB(139, 90, 60))
    emitter.Size = NumberSequence.new(0.5)
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })

    -- Emission properties
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.Rate = 5
    emitter.Speed = NumberRange.new(0, 0)
    emitter.SpreadAngle = Vector2.new(0, 0)
    emitter.EmissionDirection = Enum.NormalId.Top

    emitter.Parent = part
    emitter.Enabled = false -- Only enable during movement
    return emitter
end

-- Create capture explosion effect (BIG and OBVIOUS)
function ParticleEffects.captureExplosion(position, color)
    local explosion = Instance.new("Part")
    explosion.Name = "CaptureEffect"
    explosion.Size = Vector3.new(1, 1, 1)
    explosion.Position = position
    explosion.Anchored = true
    explosion.CanCollide = false
    explosion.Transparency = 1
    explosion.Parent = workspace

    -- Add MULTIPLE particle emitters for dramatic effect
    -- Sparkles explosion
    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkles.Color = ColorSequence.new(color)
    sparkles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2),
        NumberSequenceKeypoint.new(1, 0)
    })
    sparkles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    sparkles.Lifetime = NumberRange.new(0.8, 1.5)
    sparkles.Rate = 200
    sparkles.Speed = NumberRange.new(15, 25)
    sparkles.SpreadAngle = Vector2.new(180, 180)
    sparkles.Parent = explosion

    -- Smoke poof
    local smoke = Instance.new("ParticleEmitter")
    smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
    smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
    smoke.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 3),
        NumberSequenceKeypoint.new(1, 6)
    })
    smoke.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    smoke.Lifetime = NumberRange.new(1, 1.5)
    smoke.Rate = 50
    smoke.Speed = NumberRange.new(3, 8)
    smoke.SpreadAngle = Vector2.new(360, 360)
    smoke.Parent = explosion

    -- Flash of light
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = 10
    light.Range = 30
    light.Parent = explosion

    -- Emit and cleanup
    task.spawn(function()
        sparkles:Emit(50)
        smoke:Emit(20)

        -- Flash the light
        for i = 1, 10 do
            light.Brightness = 10 - i
            task.wait(0.05)
        end

        task.wait(1.5)
        explosion:Destroy()
    end)
end

-- Create meow speech bubble
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

    -- Animate and remove
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

-- Highlight valid moves with glow
function ParticleEffects.highlightSquare(square, color)
    local glow = Instance.new("SurfaceLight")
    glow.Name = "ValidMoveGlow"
    glow.Color = color or Color3.fromRGB(144, 238, 144) -- Light green
    glow.Brightness = 1
    glow.Range = 8
    glow.Face = Enum.NormalId.Top
    glow.Parent = square
    return glow
end

return ParticleEffects
