--[[
    Claws & Paws - Camera Controller
    Positions camera for optimal board viewing
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CameraController = {}

-- Set up camera for chess board viewing
function CameraController.setupGameCamera()
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable

    -- Position camera above and angled toward board
    -- Board center is at (0, 0, 0), size is 6x6 squares at 8 studs each = 48 studs
    local cameraPosition = Vector3.new(0, 60, -50) -- Higher and farther back for bigger board
    local lookAt = Vector3.new(0, 0, 0) -- Board center

    camera.CFrame = CFrame.new(cameraPosition, lookAt)

    return camera
end

-- Allow camera rotation with right mouse
function CameraController.enableCameraRotation()
    local camera = workspace.CurrentCamera
    local UserInputService = game:GetService("UserInputService")

    local rotating = false
    local lastMousePos = nil
    local currentAngle = 0
    local currentHeight = 60 -- Match new camera height

    UserInputService.InputBegan:Connect(function(input)
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
        if rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
            if lastMousePos then
                local delta = input.Position - lastMousePos
                currentAngle = currentAngle + delta.X * 0.01

                -- Update camera position
                local radius = 50 -- Bigger radius for bigger board
                local x = math.sin(currentAngle) * radius
                local z = math.cos(currentAngle) * radius
                local pos = Vector3.new(x, currentHeight, z)

                camera.CFrame = CFrame.new(pos, Vector3.new(0, 0, 0))

                lastMousePos = input.Position
            end
        end

        -- Mouse wheel for zoom
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            currentHeight = math.clamp(currentHeight - input.Position.Z * 5, 40, 100)

            local radius = 50 -- Match new radius
            local x = math.sin(currentAngle) * radius
            local z = math.cos(currentAngle) * radius
            local pos = Vector3.new(x, currentHeight, z)

            camera.CFrame = CFrame.new(pos, Vector3.new(0, 0, 0))
        end
    end)
end

-- Reset camera to default position
function CameraController.resetCamera()
    CameraController.setupGameCamera()
end

return CameraController
