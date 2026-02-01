--[[
    Claws & Paws - Tutorial Manager
    In-game help and instructions for new players
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local TutorialManager = {}

-- Track if tutorial was shown this session (persist via player attribute)
local tutorialShownThisSession = false

-- Create help overlay with improved responsive layout
function TutorialManager.createHelpOverlay()
    -- Prevent duplicate overlays
    local existing = LocalPlayer.PlayerGui:FindFirstChild("TutorialOverlay")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TutorialOverlay"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 50
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Semi-transparent background (clickable to close)
    local background = Instance.new("TextButton")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.5
    background.BorderSizePixel = 0
    background.Text = ""
    background.AutoButtonColor = false
    background.Parent = screenGui

    -- Help panel - responsive sizing
    local panel = Instance.new("Frame")
    panel.Name = "HelpPanel"
    panel.Size = UDim2.new(0.9, 0, 0.85, 0)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = screenGui

    -- Constrain max size
    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MaxSize = Vector2.new(520, 650)
    sizeConstraint.Parent = panel

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 16)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(255, 200, 100)
    panelStroke.Thickness = 2
    panelStroke.Parent = panel

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundColor3 = Color3.fromRGB(60, 55, 75)
    title.Text = "Welcome to Claws & Paws!"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 26
    title.Parent = panel

    -- Scrolling content frame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Content"
    scroll.Size = UDim2.new(1, -20, 1, -120)
    scroll.Position = UDim2.new(0, 10, 0, 55)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 100)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 580)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = panel

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = scroll

    -- Section helper
    local function addSection(titleText, bodyText, order)
        local section = Instance.new("Frame")
        section.Name = "Section" .. order
        section.Size = UDim2.new(1, -10, 0, 0)
        section.BackgroundTransparency = 1
        section.AutomaticSize = Enum.AutomaticSize.Y
        section.LayoutOrder = order
        section.Parent = scroll

        local sectionLayout = Instance.new("UIListLayout")
        sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
        sectionLayout.Padding = UDim.new(0, 2)
        sectionLayout.Parent = section

        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 28)
        header.BackgroundTransparency = 1
        header.Text = titleText
        header.TextColor3 = Color3.fromRGB(255, 200, 100)
        header.Font = Enum.Font.FredokaOne
        header.TextSize = 20
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.LayoutOrder = 1
        header.Parent = section

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, 0, 0, 0)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.BackgroundTransparency = 1
        body.Text = bodyText
        body.TextColor3 = Color3.fromRGB(220, 220, 230)
        body.Font = Enum.Font.Gotham
        body.TextSize = 15
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextWrapped = true
        body.LayoutOrder = 2
        body.Parent = section
    end

    addSection("How to Play", "It's chess with cats! Tap a piece to select it (sparkles appear), then tap a green square to move there. Capture enemies by moving onto their square - watch the cat fight!", 1)

    addSection("Your Cat Army", "Lion (K) = King - protect him!\nPersian (Q) = Queen - moves anywhere\nMaine Coon (R) = Rook - straight lines\nSphynx (B) = Bishop - diagonals\nCaracal (N) = Knight - L-shape jumps\nAlley Cat (P) = Pawn - marches forward", 2)

    addSection("Win the Game", "Checkmate the opponent's Lion King! That means trapping the King so it can't escape.\n\nYou can also win if your opponent runs out of time.", 3)

    addSection("Controls", "Tap/click a piece to select it\nGreen squares = valid moves\nGold square = selected piece\nMiniboard (top right) = tactical overview\nChat emotes (bottom) = send cat gestures!", 4)

    addSection("Tips for Beginners", "Start with Easy AI to learn the basics\nPawns promote to Queens at the far end\nKnights can jump over other pieces\nControl the center of the board\nDon't forget about your clock!", 5)

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(1, -20, 0, 50)
    closeBtn.Position = UDim2.new(0, 10, 1, -60)
    closeBtn.AnchorPoint = Vector2.new(0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    closeBtn.Text = "Let's Play!"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextSize = 22
    closeBtn.Parent = panel

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = closeBtn

    local function closeTutorial()
        -- Animate out
        local tween = TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Position = UDim2.new(0.5, 0, 1.5, 0)
        })
        tween.Completed:Connect(function()
            screenGui:Destroy()
        end)
        tween:Play()
    end

    closeBtn.MouseButton1Click:Connect(closeTutorial)
    background.MouseButton1Click:Connect(closeTutorial)

    -- Animate in
    panel.Position = UDim2.new(0.5, 0, -0.5, 0)
    local tweenIn = TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0)
    })
    tweenIn:Play()

    return screenGui
end

-- Create persistent help button (always visible)
function TutorialManager.createHelpButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HelpButton"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 10
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local button = Instance.new("TextButton")
    button.Name = "HelpBtn"
    button.Size = UDim2.new(0, 50, 0, 50)
    button.Position = UDim2.new(1, -65, 0, 15)
    button.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    button.Text = "?"
    button.TextColor3 = Color3.fromRGB(40, 40, 40)
    button.Font = Enum.Font.FredokaOne
    button.TextSize = 28
    button.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 160, 80)
    stroke.Thickness = 2
    stroke.Parent = button

    button.MouseButton1Click:Connect(function()
        TutorialManager.createHelpOverlay()
    end)

    return screenGui
end

-- Show initial tutorial on first play
function TutorialManager.showInitialTutorial()
    if tutorialShownThisSession then return end
    tutorialShownThisSession = true

    -- Use player attribute to remember if they've seen the tutorial
    local hasSeenTutorial = LocalPlayer:GetAttribute("hasSeenTutorial")
    if hasSeenTutorial then return end

    task.wait(1)
    TutorialManager.createHelpOverlay()
    LocalPlayer:SetAttribute("hasSeenTutorial", true)
end

return TutorialManager
