--[[
    Claws & Paws - Camera Controller
    Positions camera for optimal board viewing
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CameraController = {}

-- Configuration
CameraController.boardView = nil -- Will be set from Constants

-- Set up camera for chess board viewing (uses current board view setting)
function CameraController.setupGameCamera(boardView)
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable

    -- Use provided view or fall back to stored view
    if boardView then
        CameraController.boardView = boardView
    end

    -- Load Constants for board view types
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = require(ReplicatedStorage.Shared)
    local Constants = Shared.Constants

    local currentView = CameraController.boardView or Constants.BoardView.PERSPECTIVE_3D

    -- Board center is at (0, 0, 0), size is 6x6 squares at 8 studs each = 48 studs
    local cameraPosition
    local lookAt = Vector3.new(0, 0, 0) -- Board center

    if currentView == Constants.BoardView.TOP_DOWN_2D then
        -- Pure top-down 2D view (directly above)
        cameraPosition = Vector3.new(0, 80, 0)
    elseif currentView == Constants.BoardView.SIDE_VIEW then
        -- Side perspective view
        cameraPosition = Vector3.new(60, 30, 0)
    else
        -- Default: Perspective 3D (angled)
        cameraPosition = Vector3.new(0, 60, -50)
    end

    camera.CFrame = CFrame.new(cameraPosition, lookAt)

    return camera
end

-- Set board view and update camera
function CameraController.setBoardView(boardView)
    CameraController.boardView = boardView
    CameraController.setupGameCamera()
end

-- Get current board view
function CameraController.getBoardView()
    return CameraController.boardView
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
