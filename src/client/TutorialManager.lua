--[[
    Claws & Paws - Tutorial Manager
    In-game help and instructions for new players
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TutorialManager = {}

-- Create help overlay
function TutorialManager.createHelpOverlay()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TutorialOverlay"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Semi-transparent background
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.5
    background.BorderSizePixel = 0
    background.ZIndex = 100
    background.Parent = screenGui

    -- Help panel
    local panel = Instance.new("Frame")
    panel.Name = "HelpPanel"
    panel.Size = UDim2.new(0, 500, 0, 600)
    panel.Position = UDim2.new(0.5, -250, 0.5, -300)
    panel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    panel.BorderSizePixel = 0
    panel.ZIndex = 101
    panel.Parent = screenGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 15)
    panelCorner.Parent = panel

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 60)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "🐾 How to Play Claws & Paws"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 28
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = panel

    -- Instructions
    local instructions = Instance.new("TextLabel")
    instructions.Name = "Instructions"
    instructions.Size = UDim2.new(1, -40, 1, -140)
    instructions.Position = UDim2.new(0, 20, 0, 80)
    instructions.BackgroundTransparency = 1
    instructions.TextColor3 = Color3.new(1, 1, 1)
    instructions.Font = Enum.Font.Gotham
    instructions.TextSize = 18
    instructions.TextXAlignment = Enum.TextXAlignment.Left
    instructions.TextYAlignment = Enum.TextYAlignment.Top
    instructions.TextWrapped = true
    instructions.ZIndex = 102
    instructions.Parent = panel

    instructions.Text = [[📖 Basic Controls

1️⃣ Click a piece to select it
   • Sparkles ✨ appear on selected piece
   • Valid moves glow green 💚

2️⃣ Click a green square to move
   • Your piece slides/pounces there
   • Turn switches to opponent

3️⃣ Capture enemy pieces
   • Click your piece, then enemy piece
   • Hiss + pounce animation plays!

🎮 Special Features
• Gesture Menu (bottom): Send cat emotes
• Resign Button (bottom right): Give up

🐱 Cat Chess Pieces
🦁 Lion = King (protect at all costs!)
👑🐱 Persian = Queen (most powerful)
🏰🐱 Maine Coon = Rook (straight lines)
🔮🐱 Sphinx = Bishop (diagonals)
⚡🐱 Caracal = Knight (L-shape jumps)
🐾 Alley Cat = Pawn (forward march)

💡 Tips
• Green highlight = you can move here
• Gold highlight = your selected piece
• Your turn shows at top of screen
]]

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 200, 0, 50)
    closeBtn.Position = UDim2.new(0.5, -100, 1, -70)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    closeBtn.Text = "Got it! Let's Play 🐾"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 20
    closeBtn.ZIndex = 102
    closeBtn.Parent = panel

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    return screenGui
end

-- Create persistent help button
function TutorialManager.createHelpButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HelpButton"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local button = Instance.new("TextButton")
    button.Name = "HelpBtn"
    button.Size = UDim2.new(0, 80, 0, 80)
    button.Position = UDim2.new(1, -100, 0, 20)
    button.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    button.Text = "❓\nHelp"
    button.TextColor3 = Color3.fromRGB(40, 40, 40)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 18
    button.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 40)
    corner.Parent = button

    button.MouseButton1Click:Connect(function()
        TutorialManager.createHelpOverlay()
    end)

    return screenGui
end

-- Show initial tutorial on first play
function TutorialManager.showInitialTutorial()
    -- Check if user has seen tutorial before
    local hasSeenTutorial = false -- Could store in DataStore

    if not hasSeenTutorial then
        task.wait(1) -- Wait for UI to load
        TutorialManager.createHelpOverlay()
    end
end

return TutorialManager
