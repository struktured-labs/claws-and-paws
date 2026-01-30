--[[
    Claws & Paws - Settings Manager
    Handles game settings, preferences, and customization
]]

local SettingsManager = {}

-- Color theme presets - DIVERSE colors that contrast well with pieces!
local COLOR_THEMES = {
    ["Forest Floor"] = {
        lightColor = Color3.fromRGB(144, 238, 144), -- Light green
        darkColor = Color3.fromRGB(34, 139, 34),    -- Forest green
        description = "Green meadow (best contrast)"
    },
    ["Ocean Depths"] = {
        lightColor = Color3.fromRGB(135, 206, 235), -- Sky blue
        darkColor = Color3.fromRGB(25, 25, 112),    -- Midnight blue
        description = "Deep blue ocean"
    },
    ["Sunset Sky"] = {
        lightColor = Color3.fromRGB(255, 182, 193), -- Light pink
        darkColor = Color3.fromRGB(220, 20, 60),    -- Crimson
        description = "Warm sunset colors"
    },
    ["Purple Majesty"] = {
        lightColor = Color3.fromRGB(216, 191, 216), -- Thistle
        darkColor = Color3.fromRGB(128, 0, 128),    -- Purple
        description = "Royal purple tones"
    },
    ["Autumn Harvest"] = {
        lightColor = Color3.fromRGB(255, 215, 0),   -- Gold
        darkColor = Color3.fromRGB(184, 134, 11),   -- Dark goldenrod
        description = "Golden autumn leaves"
    },
    ["Coral Reef"] = {
        lightColor = Color3.fromRGB(255, 160, 122), -- Light coral
        darkColor = Color3.fromRGB(255, 99, 71),    -- Tomato red
        description = "Tropical coral colors"
    },
    ["Tuxedo Cat"] = {
        lightColor = Color3.fromRGB(200, 200, 200), -- Light gray
        darkColor = Color3.fromRGB(40, 40, 40),     -- Charcoal
        description = "Classic gray and charcoal"
    },
    ["Orange Tabby"] = {
        lightColor = Color3.fromRGB(255, 228, 181), -- Moccasin
        darkColor = Color3.fromRGB(210, 105, 30),   -- Chocolate orange
        description = "Warm tabby cat colors"
    },
}

-- Default settings
local DEFAULT_SETTINGS = {
    -- Visual
    colorTheme = "Forest Floor",  -- Green board with best contrast (no white!)

    -- Audio
    masterVolume = 0.7,
    musicVolume = 0.5,
    sfxVolume = 0.6,

    -- Gameplay
    showCoordinates = true,  -- Show A-F, 1-6 by default
    showValidMoves = true,
    animationSpeed = 1.0,

    -- Camera
    cameraSmooth = true,
}

-- Current settings (loaded from storage or defaults)
local currentSettings = {}

-- Initialize settings
function SettingsManager.init()
    -- Try to load saved settings
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- For now, just use defaults (later can add DataStore persistence)
    for key, value in pairs(DEFAULT_SETTINGS) do
        currentSettings[key] = value
    end

    -- Store volume settings as player attributes for cross-module access
    LocalPlayer:SetAttribute("masterVolume", currentSettings.masterVolume)
    LocalPlayer:SetAttribute("musicVolume", currentSettings.musicVolume)
    LocalPlayer:SetAttribute("sfxVolume", currentSettings.sfxVolume)

    print("🐱 [SETTINGS] Initialized with defaults")
end

-- Get current setting value
function SettingsManager.get(key)
    return currentSettings[key]
end

-- Set a setting value
function SettingsManager.set(key, value)
    currentSettings[key] = value
    print("🐱 [SETTINGS] Set " .. key .. " = " .. tostring(value))

    -- TODO: Save to DataStore for persistence
end

-- Get all color themes
function SettingsManager.getColorThemes()
    return COLOR_THEMES
end

-- Get current theme colors
function SettingsManager.getCurrentTheme()
    local themeName = currentSettings.colorTheme
    return COLOR_THEMES[themeName] or COLOR_THEMES["Orange Tabby"]
end

-- Apply settings to board
function SettingsManager.applyToBoardConfig(boardConfig)
    local theme = SettingsManager.getCurrentTheme()
    boardConfig.lightColor = theme.lightColor
    boardConfig.darkColor = theme.darkColor
end

-- Create settings UI
function SettingsManager.createSettingsUI(onClose)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SettingsMenu"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui

    -- Settings panel
    local panel = Instance.new("Frame")
    panel.Name = "SettingsPanel"
    panel.Size = UDim2.new(0, 600, 0, 700)
    panel.Position = UDim2.new(0.5, -300, 0.5, -350)
    panel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    panel.BorderSizePixel = 0
    panel.Parent = overlay

    -- Panel corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = panel

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 50)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "⚙️ Settings"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 32
    title.Font = Enum.Font.FredokaOne
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    -- Scrolling frame for settings
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "SettingsScroll"
    scrollFrame.Size = UDim2.new(1, -40, 1, -140)
    scrollFrame.Position = UDim2.new(0, 20, 0, 80)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will auto-size
    scrollFrame.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollFrame

    -- Auto-size canvas
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    local yOffset = 0

    -- Helper: Create section header
    local function createSectionHeader(text, order)
        local header = Instance.new("TextLabel")
        header.Name = "Header_" .. text
        header.Size = UDim2.new(1, 0, 0, 30)
        header.BackgroundTransparency = 1
        header.Text = text
        header.TextColor3 = Color3.fromRGB(255, 215, 0)
        header.TextSize = 24
        header.Font = Enum.Font.FredokaOne
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.LayoutOrder = order
        header.Parent = scrollFrame
    end

    -- Helper: Create slider
    local function createSlider(labelText, settingKey, minVal, maxVal, order)
        local container = Instance.new("Frame")
        container.Name = "Slider_" .. settingKey
        container.Size = UDim2.new(1, 0, 0, 60)
        container.BackgroundTransparency = 1
        container.LayoutOrder = order
        container.Parent = scrollFrame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, 0, 0, 30)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.TextSize = 18
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0, 50, 0, 30)
        valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(math.floor(SettingsManager.get(settingKey) * 100)) .. "%"
        valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        valueLabel.TextSize = 18
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.Parent = container

        -- Slider background
        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, 0, 0, 8)
        sliderBg.Position = UDim2.new(0, 0, 0, 40)
        sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = container

        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 4)
        sliderCorner.Parent = sliderBg

        -- Slider fill
        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new(SettingsManager.get(settingKey), 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 4)
        fillCorner.Parent = sliderFill

        -- Draggable button
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 20, 0, 20)
        button.Position = UDim2.new(SettingsManager.get(settingKey), -10, 0.5, -10)
        button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        button.BorderSizePixel = 0
        button.Text = ""
        button.Parent = sliderBg

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(1, 0)
        btnCorner.Parent = button

        -- Dragging logic
        local dragging = false
        button.MouseButton1Down:Connect(function()
            dragging = true
        end)

        local UserInputService = game:GetService("UserInputService")
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = UserInputService:GetMouseLocation()
                local relativePos = (mousePos.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
                relativePos = math.clamp(relativePos, 0, 1)

                -- Update UI
                sliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
                button.Position = UDim2.new(relativePos, -10, 0.5, -10)
                valueLabel.Text = tostring(math.floor(relativePos * 100)) .. "%"

                -- Update setting
                SettingsManager.set(settingKey, relativePos)

                -- Apply audio settings immediately via player attributes
                if settingKey:find("Volume") then
                    local Players = game:GetService("Players")
                    local LocalPlayer = Players.LocalPlayer
                    LocalPlayer:SetAttribute(settingKey, relativePos)

                    -- Update MusicManager directly
                    local success, MusicMgr = pcall(function()
                        return require(script.Parent.MusicManager)
                    end)
                    if success and MusicMgr then
                        MusicMgr.updateVolumeFromSettings(
                            SettingsManager.get("masterVolume"),
                            SettingsManager.get("musicVolume")
                        )
                    end
                end
            end
        end)
    end

    -- Helper: Create color theme selector
    local function createThemeSelector(order)
        local container = Instance.new("Frame")
        container.Name = "ThemeSelector"
        container.Size = UDim2.new(1, 0, 0, 400) -- Space for all theme buttons
        container.BackgroundTransparency = 1
        container.LayoutOrder = order
        container.Parent = scrollFrame

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(0, 170, 0, 80)
        gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.Parent = container

        local themeOrder = 1
        for themeName, themeData in pairs(COLOR_THEMES) do
            local themeBtn = Instance.new("TextButton")
            themeBtn.Name = "Theme_" .. themeName
            themeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            themeBtn.BorderSizePixel = 0
            themeBtn.Text = ""
            themeBtn.LayoutOrder = themeOrder
            themeBtn.Parent = container

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = themeBtn

            -- Color preview squares
            local previewFrame = Instance.new("Frame")
            previewFrame.Size = UDim2.new(1, -10, 0, 30)
            previewFrame.Position = UDim2.new(0, 5, 0, 5)
            previewFrame.BackgroundTransparency = 1
            previewFrame.Parent = themeBtn

            local light = Instance.new("Frame")
            light.Size = UDim2.new(0.48, 0, 1, 0)
            light.BackgroundColor3 = themeData.lightColor
            light.BorderSizePixel = 0
            light.Parent = previewFrame

            local lightCorner = Instance.new("UICorner")
            lightCorner.CornerRadius = UDim.new(0, 4)
            lightCorner.Parent = light

            local dark = Instance.new("Frame")
            dark.Size = UDim2.new(0.48, 0, 1, 0)
            dark.Position = UDim2.new(0.52, 0, 0, 0)
            dark.BackgroundColor3 = themeData.darkColor
            dark.BorderSizePixel = 0
            dark.Parent = previewFrame

            local darkCorner = Instance.new("UICorner")
            darkCorner.CornerRadius = UDim.new(0, 4)
            darkCorner.Parent = dark

            -- Theme name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -10, 0, 20)
            nameLabel.Position = UDim2.new(0, 5, 0, 40)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = themeName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 14
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Parent = themeBtn

            -- Selection indicator
            local selected = Instance.new("Frame")
            selected.Name = "SelectedBorder"
            selected.Size = UDim2.new(1, 4, 1, 4)
            selected.Position = UDim2.new(0, -2, 0, -2)
            selected.BackgroundTransparency = 1
            selected.BorderSizePixel = 3
            selected.BorderColor3 = Color3.fromRGB(255, 215, 0)
            selected.Visible = (SettingsManager.get("colorTheme") == themeName)
            selected.Parent = themeBtn

            local selCorner = Instance.new("UICorner")
            selCorner.CornerRadius = UDim.new(0, 10)
            selCorner.Parent = selected

            -- Click handler
            themeBtn.MouseButton1Click:Connect(function()
                SettingsManager.set("colorTheme", themeName)

                -- Update all selection borders
                for _, btn in ipairs(container:GetChildren()) do
                    if btn:IsA("TextButton") then
                        local border = btn:FindFirstChild("SelectedBorder")
                        if border then
                            border.Visible = (btn.Name == "Theme_" .. themeName)
                        end
                    end
                end

                -- Notify that theme changed (will be handled by caller)
                if onClose then
                    -- Theme will be applied when settings close
                end
            end)

            themeOrder = themeOrder + 1
        end

        -- Auto-size container based on grid
        gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            container.Size = UDim2.new(1, 0, 0, gridLayout.AbsoluteContentSize.Y)
        end)
    end

    -- Helper: Create toggle
    local function createToggle(labelText, settingKey, order)
        local container = Instance.new("Frame")
        container.Name = "Toggle_" .. settingKey
        container.Size = UDim2.new(1, 0, 0, 40)
        container.BackgroundTransparency = 1
        container.LayoutOrder = order
        container.Parent = scrollFrame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.TextSize = 18
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 60, 0, 30)
        toggleBtn.Position = UDim2.new(1, -60, 0.5, -15)
        toggleBtn.BackgroundColor3 = SettingsManager.get(settingKey) and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(100, 100, 100)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Text = SettingsManager.get(settingKey) and "ON" or "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.TextSize = 14
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Parent = container

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 15)
        btnCorner.Parent = toggleBtn

        toggleBtn.MouseButton1Click:Connect(function()
            local newValue = not SettingsManager.get(settingKey)
            SettingsManager.set(settingKey, newValue)
            toggleBtn.Text = newValue and "ON" or "OFF"
            toggleBtn.BackgroundColor3 = newValue and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(100, 100, 100)
        end)
    end

    -- Build settings UI
    local orderCounter = 1

    -- VISUAL SETTINGS
    createSectionHeader("🎨 Board Colors", orderCounter)
    orderCounter = orderCounter + 1

    createThemeSelector(orderCounter)
    orderCounter = orderCounter + 1

    -- AUDIO SETTINGS
    createSectionHeader("🔊 Audio", orderCounter)
    orderCounter = orderCounter + 1

    createSlider("Master Volume", "masterVolume", 0, 1, orderCounter)
    orderCounter = orderCounter + 1

    createSlider("Music Volume", "musicVolume", 0, 1, orderCounter)
    orderCounter = orderCounter + 1

    createSlider("Sound Effects", "sfxVolume", 0, 1, orderCounter)
    orderCounter = orderCounter + 1

    -- GAMEPLAY SETTINGS
    createSectionHeader("🎮 Gameplay", orderCounter)
    orderCounter = orderCounter + 1

    createToggle("Show Coordinates", "showCoordinates", orderCounter)
    orderCounter = orderCounter + 1

    createToggle("Show Valid Moves", "showValidMoves", orderCounter)
    orderCounter = orderCounter + 1

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 200, 0, 50)
    closeBtn.Position = UDim2.new(0.5, -100, 1, -70)
    closeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "Close"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 24
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.Parent = panel

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if onClose then
            onClose()
        end
    end)

    return screenGui
end

return SettingsManager
