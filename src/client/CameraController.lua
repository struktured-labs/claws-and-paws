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
    print("🐱 [DEBUG] CameraController.setupGameCamera() called")

    local camera = workspace.CurrentCamera

    -- Position camera above and angled toward board
    -- Camera is positioned SOUTH of board (negative Z) looking NORTH
    -- This ensures white (rows 1-2, negative Z) is always at bottom
    local cameraPosition = Vector3.new(0, 120, -110) -- Much higher for huge board (20 stud squares)
    local lookAt = Vector3.new(0, 0, 0)

    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(cameraPosition, lookAt)
    print("🐱 [DEBUG] Camera positioned for board view (white at bottom)")

    return camera
end

-- Allow camera rotation with right mouse
function CameraController.enableCameraRotation()
    local camera = workspace.CurrentCamera
    local UserInputService = game:GetService("UserInputService")

    local rotating = false
    local lastMousePos = nil
    local currentAngle = 0
    local currentHeight = 120 -- Match new camera height for huge board

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
                local radius = 110 -- Much bigger radius for huge board
                local x = math.sin(currentAngle) * radius
                local z = math.cos(currentAngle) * radius - 110 -- Offset to keep white at bottom
                local pos = Vector3.new(x, currentHeight, z)

                camera.CFrame = CFrame.new(pos, Vector3.new(0, 0, 0))

                lastMousePos = input.Position
            end
        end

        -- Mouse wheel for zoom
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            currentHeight = math.clamp(currentHeight - input.Position.Z * 8, 80, 180) -- Much higher limits for huge board

            local radius = 110 -- Match new radius
            local x = math.sin(currentAngle) * radius
            local z = math.cos(currentAngle) * radius - 110 -- Keep white at bottom
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
