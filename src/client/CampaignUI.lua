--[[
    Claws & Paws - Campaign UI
    Boss selection and campaign progress screen
]]

local CampaignUI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Create campaign menu
function CampaignUI.createCampaignMenu(onBossSelected, onBack)
    local Shared = require(ReplicatedStorage.Shared)
    local CampaignData = Shared.CampaignData

    -- TODO: Load player progress from DataStore
    -- For now, unlock all bosses for testing
    local playerProgress = {
        whiskers = true,
        mittens = true,
        shadow = true,
        duchess = true,
    }

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CampaignMenu"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Background
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0
    bg.Parent = screenGui

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 600, 0, 80)
    title.Position = UDim2.new(0.5, -300, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "😼 CAT BOSS GAUNTLET 😼"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 48
    title.Parent = screenGui

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, 0, 0, 30)
    subtitle.Position = UDim2.new(0, 0, 0, 100)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Defeat increasingly sinister cat overlords!"
    subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 18
    subtitle.Parent = screenGui

    -- Progress bar
    local completion = CampaignData.getCompletionPercentage(playerProgress)
    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(0, 600, 0, 40)
    progressBg.Position = UDim2.new(0.5, -300, 0, 140)
    progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = screenGui

    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 8)
    progressCorner.Parent = progressBg

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(completion / 100, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg

    local progressFillCorner = Instance.new("UICorner")
    progressFillCorner.CornerRadius = UDim.new(0, 8)
    progressFillCorner.Parent = progressFill

    local progressLabel = Instance.new("TextLabel")
    progressLabel.Size = UDim2.new(1, 0, 1, 0)
    progressLabel.BackgroundTransparency = 1
    progressLabel.Text = string.format("Campaign Progress: %d%%", completion)
    progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    progressLabel.Font = Enum.Font.GothamBold
    progressLabel.TextSize = 18
    progressLabel.Parent = progressBg

    -- Boss list container
    local bossListFrame = Instance.new("ScrollingFrame")
    bossListFrame.Size = UDim2.new(0, 700, 0, 400)
    bossListFrame.Position = UDim2.new(0.5, -350, 0, 200)
    bossListFrame.BackgroundTransparency = 1
    bossListFrame.BorderSizePixel = 0
    bossListFrame.ScrollBarThickness = 8
    bossListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    bossListFrame.Parent = screenGui

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 15)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = bossListFrame

    -- Auto-size canvas
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        bossListFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end)

    -- Create boss cards
    local unlockedBosses = CampaignData.getUnlockedBosses(playerProgress)

    for i, boss in ipairs(CampaignData.BOSSES) do
        local isUnlocked = false
        for _, unlockedBoss in ipairs(unlockedBosses) do
            if unlockedBoss.id == boss.id then
                isUnlocked = true
                break
            end
        end

        local bossCard = Instance.new("TextButton")
        bossCard.Name = "Boss_" .. boss.id
        bossCard.Size = UDim2.new(1, 0, 0, 120)
        bossCard.BackgroundColor3 = isUnlocked and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30)
        bossCard.BackgroundTransparency = isUnlocked and 0 or 0.5
        bossCard.BorderSizePixel = 0
        bossCard.Text = ""
        bossCard.LayoutOrder = i
        bossCard.Parent = bossListFrame

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 10)
        cardCorner.Parent = bossCard

        -- Boss portrait
        local portrait = Instance.new("TextLabel")
        portrait.Size = UDim2.new(0, 100, 0, 100)
        portrait.Position = UDim2.new(0, 10, 0, 10)
        portrait.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        portrait.BorderSizePixel = 0
        portrait.Text = isUnlocked and boss.portrait or "🔒"
        portrait.TextSize = 60
        portrait.Parent = bossCard

        local portraitCorner = Instance.new("UICorner")
        portraitCorner.CornerRadius = UDim.new(0, 8)
        portraitCorner.Parent = portrait

        -- Boss name and title
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 560, 0, 30)
        nameLabel.Position = UDim2.new(0, 120, 0, 10)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = isUnlocked and boss.name or "???"
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.FredokaOne
        nameLabel.TextSize = 24
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = bossCard

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(0, 560, 0, 20)
        titleLabel.Position = UDim2.new(0, 120, 0, 40)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = isUnlocked and boss.title or "Locked - Defeat previous boss"
        titleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 14
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = bossCard

        -- Difficulty badge
        local difficultyLabel = Instance.new("TextLabel")
        difficultyLabel.Size = UDim2.new(0, 100, 0, 25)
        difficultyLabel.Position = UDim2.new(0, 120, 0, 65)
        difficultyLabel.BackgroundColor3 = boss.difficulty == "Easy" and Color3.fromRGB(100, 200, 100)
            or boss.difficulty == "Medium" and Color3.fromRGB(255, 200, 100)
            or boss.difficulty == "Hard" and Color3.fromRGB(255, 100, 100)
            or boss.difficulty == "Expert" and Color3.fromRGB(200, 100, 255)
            or Color3.fromRGB(255, 0, 0)
        difficultyLabel.BorderSizePixel = 0
        difficultyLabel.Text = isUnlocked and boss.difficulty or "???"
        difficultyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        difficultyLabel.Font = Enum.Font.GothamBold
        difficultyLabel.TextSize = 12
        difficultyLabel.Parent = bossCard

        local diffCorner = Instance.new("UICorner")
        diffCorner.CornerRadius = UDim.new(0, 5)
        diffCorner.Parent = difficultyLabel

        -- Status (defeated or not)
        if playerProgress[boss.id] then
            local defeatedLabel = Instance.new("TextLabel")
            defeatedLabel.Size = UDim2.new(0, 80, 0, 25)
            defeatedLabel.Position = UDim2.new(0, 230, 0, 65)
            defeatedLabel.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            defeatedLabel.BorderSizePixel = 0
            defeatedLabel.Text = "✓ DEFEATED"
            defeatedLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
            defeatedLabel.Font = Enum.Font.GothamBold
            defeatedLabel.TextSize = 10
            defeatedLabel.Parent = bossCard

            local defCorner = Instance.new("UICorner")
            defCorner.CornerRadius = UDim.new(0, 5)
            defCorner.Parent = defeatedLabel
        end

        -- Click handler
        if isUnlocked then
            bossCard.MouseButton1Click:Connect(function()
                if onBossSelected then
                    onBossSelected(boss)
                end
                screenGui:Destroy()
            end)

            -- Hover effects
            bossCard.MouseEnter:Connect(function()
                bossCard.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            end)

            bossCard.MouseLeave:Connect(function()
                bossCard.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            end)
        end
    end

    -- Back button
    local backBtn = Instance.new("TextButton")
    backBtn.Size = UDim2.new(0, 200, 0, 50)
    backBtn.Position = UDim2.new(0.5, -100, 1, -70)
    backBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    backBtn.BorderSizePixel = 0
    backBtn.Text = "← Back to Menu"
    backBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextSize = 20
    backBtn.Parent = screenGui

    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(0, 8)
    backCorner.Parent = backBtn

    backBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if onBack then
            onBack()
        end
    end)

    return screenGui
end

return CampaignUI
