--[[
    Claws & Paws - Camera Controller
    Positions camera for optimal board viewing
    Supports mouse (right-click drag, scroll) and touch (one-finger drag, pinch zoom)
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local CameraController = {}

-- Camera state
local currentAngle = 0
local currentHeight = 120
local RADIUS = 110
local MIN_HEIGHT = 80
local MAX_HEIGHT = 180

local function updateCameraPosition()
    local camera = workspace.CurrentCamera
    local x = math.sin(currentAngle) * RADIUS
    local z = math.cos(currentAngle) * RADIUS - RADIUS
    local pos = Vector3.new(x, currentHeight, z)
    camera.CFrame = CFrame.new(pos, Vector3.new(0, 0, 0))
end

-- Set up camera for chess board viewing
function CameraController.setupGameCamera()
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
    currentAngle = 0
    currentHeight = 120
    updateCameraPosition()
    return camera
end

-- Enable camera rotation (mouse + touch)
function CameraController.enableCameraRotation()
    -- Mouse controls
    local rotating = false
    local lastMousePos = nil

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rotating = true
            lastMousePos = input.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rotating = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        -- Mouse drag rotation
        if rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
            if lastMousePos then
                local delta = input.Position - lastMousePos
                currentAngle = currentAngle + delta.X * 0.01
                updateCameraPosition()
                lastMousePos = input.Position
            end
        end

        -- Mouse wheel zoom
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            currentHeight = math.clamp(currentHeight - input.Position.Z * 8, MIN_HEIGHT, MAX_HEIGHT)
            updateCameraPosition()
        end
    end)

    -- Touch controls
    local activeTouches = {}

    UserInputService.TouchStarted:Connect(function(input, processed)
        if processed then return end
        activeTouches[input] = input.Position
    end)

    UserInputService.TouchEnded:Connect(function(input)
        activeTouches[input] = nil
    end)

    UserInputService.TouchMoved:Connect(function(input, processed)
        if processed then return end
        local prevPos = activeTouches[input]
        if not prevPos then return end

        local touchCount = 0
        for _ in pairs(activeTouches) do touchCount = touchCount + 1 end

        if touchCount == 1 then
            -- Single finger: rotate camera (only if moved significantly)
            local delta = input.Position - prevPos
            if math.abs(delta.X) > 1 then
                currentAngle = currentAngle + delta.X * 0.005
                updateCameraPosition()
            end
        elseif touchCount == 2 then
            -- Two fingers: pinch to zoom
            local otherInput, otherPos
            for inp, pos in pairs(activeTouches) do
                if inp ~= input then
                    otherInput = inp
                    otherPos = pos
                    break
                end
            end
            if otherPos then
                local prevDist = (prevPos - otherPos).Magnitude
                local newDist = (input.Position - otherPos).Magnitude
                local zoomDelta = (newDist - prevDist) * 0.3
                currentHeight = math.clamp(currentHeight - zoomDelta, MIN_HEIGHT, MAX_HEIGHT)
                updateCameraPosition()
            end
        end

        activeTouches[input] = input.Position
    end)
end

-- Reset camera to default position
function CameraController.resetCamera()
    currentAngle = 0
    currentHeight = 120
    CameraController.setupGameCamera()
end

return CameraController
