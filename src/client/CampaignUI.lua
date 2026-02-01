--[[
    Claws & Paws - Campaign UI
    Boss selection and campaign progress screen
    Responsive layout for mobile and desktop
]]

local CampaignUI = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Create campaign menu
function CampaignUI.createCampaignMenu(onBossSelected, onBack)
    local Shared = require(ReplicatedStorage.Shared)
    local CampaignData = Shared.CampaignData

    -- Load player progress from attributes (DataStore loads into attributes on join)
    local playerProgress = {}
    for _, boss in ipairs(CampaignData.BOSSES) do
        if LocalPlayer:GetAttribute("boss_" .. boss.id) then
            playerProgress[boss.id] = true
        end
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CampaignMenu"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 20
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Full-screen dark background
    local bg = Instance.new("TextButton")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
    bg.BackgroundTransparency = 0.15
    bg.BorderSizePixel = 0
    bg.Text = ""
    bg.AutoButtonColor = false
    bg.Parent = screenGui

    -- Main panel (responsive)
    local panel = Instance.new("Frame")
    panel.Name = "CampaignPanel"
    panel.Size = UDim2.new(0.92, 0, 0.9, 0)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = screenGui

    local panelConstraint = Instance.new("UISizeConstraint")
    panelConstraint.MaxSize = Vector2.new(600, 700)
    panelConstraint.Parent = panel

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 14)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(255, 200, 50)
    panelStroke.Thickness = 2
    panelStroke.Parent = panel

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 55)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 40, 65)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "CAT BOSS GAUNTLET"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 28
    title.TextScaled = true
    title.Parent = titleBar

    local titlePadding = Instance.new("UIPadding")
    titlePadding.PaddingLeft = UDim.new(0, 15)
    titlePadding.PaddingRight = UDim.new(0, 15)
    titlePadding.Parent = title

    local titleTextConstraint = Instance.new("UITextSizeConstraint")
    titleTextConstraint.MaxTextSize = 28
    titleTextConstraint.Parent = title

    -- Progress bar
    local completion = CampaignData.getCompletionPercentage(playerProgress)

    local progressContainer = Instance.new("Frame")
    progressContainer.Name = "ProgressContainer"
    progressContainer.Size = UDim2.new(1, -24, 0, 30)
    progressContainer.Position = UDim2.new(0, 12, 0, 62)
    progressContainer.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
    progressContainer.BorderSizePixel = 0
    progressContainer.Parent = panel

    local progCorner = Instance.new("UICorner")
    progCorner.CornerRadius = UDim.new(0, 6)
    progCorner.Parent = progressContainer

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(completion / 100, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressContainer

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = progressFill

    local progressLabel = Instance.new("TextLabel")
    progressLabel.Size = UDim2.new(1, 0, 1, 0)
    progressLabel.BackgroundTransparency = 1
    progressLabel.Text = string.format("%d/%d Bosses Defeated", completion * #CampaignData.BOSSES / 100, #CampaignData.BOSSES)
    progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    progressLabel.Font = Enum.Font.GothamBold
    progressLabel.TextSize = 14
    progressLabel.Parent = progressContainer

    -- Boss list (scrolling)
    local bossScroll = Instance.new("ScrollingFrame")
    bossScroll.Name = "BossList"
    bossScroll.Size = UDim2.new(1, -16, 1, -155)
    bossScroll.Position = UDim2.new(0, 8, 0, 100)
    bossScroll.BackgroundTransparency = 1
    bossScroll.BorderSizePixel = 0
    bossScroll.ScrollBarThickness = 5
    bossScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 50)
    bossScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    bossScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    bossScroll.Parent = panel

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = bossScroll

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
        local isDefeated = playerProgress[boss.id] == true

        -- Boss card
        local card = Instance.new("TextButton")
        card.Name = "Boss_" .. boss.id
        card.Size = UDim2.new(1, -8, 0, 90)
        card.BackgroundColor3 = isUnlocked and Color3.fromRGB(50, 45, 60) or Color3.fromRGB(30, 28, 38)
        card.BackgroundTransparency = isUnlocked and 0 or 0.4
        card.BorderSizePixel = 0
        card.Text = ""
        card.AutoButtonColor = false
        card.LayoutOrder = i
        card.Parent = bossScroll

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card

        if isUnlocked then
            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = isDefeated and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(80, 75, 95)
            cardStroke.Thickness = isDefeated and 2 or 1
            cardStroke.Parent = card
        end

        -- Portrait (left side)
        local portrait = Instance.new("TextLabel")
        portrait.Name = "Portrait"
        portrait.Size = UDim2.new(0, 60, 0, 60)
        portrait.Position = UDim2.new(0, 10, 0.5, -30)
        portrait.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
        portrait.BorderSizePixel = 0
        portrait.Text = isUnlocked and boss.portrait or "?"
        portrait.TextSize = isUnlocked and 40 or 30
        portrait.TextColor3 = isUnlocked and Color3.new(1, 1, 1) or Color3.fromRGB(100, 100, 100)
        portrait.Parent = card

        local portraitCorner = Instance.new("UICorner")
        portraitCorner.CornerRadius = UDim.new(0, 8)
        portraitCorner.Parent = portrait

        -- Info area (right of portrait)
        local infoX = 80

        -- Boss name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "BossName"
        nameLabel.Size = UDim2.new(1, -(infoX + 10), 0, 22)
        nameLabel.Position = UDim2.new(0, infoX, 0, 6)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = isUnlocked and boss.name or "???"
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.FredokaOne
        nameLabel.TextSize = 18
        nameLabel.TextScaled = true
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = card

        local nameConstraint = Instance.new("UITextSizeConstraint")
        nameConstraint.MaxTextSize = 18
        nameConstraint.Parent = nameLabel

        -- Boss title/description
        local descText = isUnlocked and boss.title or "Defeat the previous boss to unlock"
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "Description"
        descLabel.Size = UDim2.new(1, -(infoX + 10), 0, 16)
        descLabel.Position = UDim2.new(0, infoX, 0, 28)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = descText
        descLabel.TextColor3 = Color3.fromRGB(170, 165, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 12
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descLabel.Parent = card

        -- Taunt line (flavor text)
        if isUnlocked then
            local tauntLabel = Instance.new("TextLabel")
            tauntLabel.Name = "Taunt"
            tauntLabel.Size = UDim2.new(1, -(infoX + 10), 0, 16)
            tauntLabel.Position = UDim2.new(0, infoX, 0, 46)
            tauntLabel.BackgroundTransparency = 1
            tauntLabel.Text = '"' .. boss.taunt .. '"'
            tauntLabel.TextColor3 = Color3.fromRGB(200, 180, 140)
            tauntLabel.Font = Enum.Font.GothamMedium
            tauntLabel.TextSize = 11
            tauntLabel.TextXAlignment = Enum.TextXAlignment.Left
            tauntLabel.TextTruncate = Enum.TextTruncate.AtEnd
            tauntLabel.Parent = card
        end

        -- Difficulty badge + status
        local badgeY = 66

        local diffBadge = Instance.new("TextLabel")
        diffBadge.Name = "DifficultyBadge"
        diffBadge.Size = UDim2.new(0, 70, 0, 18)
        diffBadge.Position = UDim2.new(0, infoX, 0, badgeY)
        diffBadge.BackgroundColor3 = boss.difficulty == "Easy" and Color3.fromRGB(80, 170, 80)
            or boss.difficulty == "Medium" and Color3.fromRGB(220, 170, 50)
            or boss.difficulty == "Hard" and Color3.fromRGB(220, 80, 80)
            or boss.difficulty == "Expert" and Color3.fromRGB(170, 80, 220)
            or Color3.fromRGB(200, 30, 30) -- NIGHTMARE
        diffBadge.BorderSizePixel = 0
        diffBadge.Text = isUnlocked and boss.difficulty or "???"
        diffBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
        diffBadge.Font = Enum.Font.GothamBold
        diffBadge.TextSize = 11
        diffBadge.Parent = card

        local diffCorner = Instance.new("UICorner")
        diffCorner.CornerRadius = UDim.new(0, 4)
        diffCorner.Parent = diffBadge

        -- Defeated checkmark
        if isDefeated then
            local defBadge = Instance.new("TextLabel")
            defBadge.Name = "DefeatedBadge"
            defBadge.Size = UDim2.new(0, 70, 0, 18)
            defBadge.Position = UDim2.new(0, infoX + 78, 0, badgeY)
            defBadge.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            defBadge.BorderSizePixel = 0
            defBadge.Text = "DEFEATED"
            defBadge.TextColor3 = Color3.fromRGB(30, 25, 15)
            defBadge.Font = Enum.Font.GothamBold
            defBadge.TextSize = 10
            defBadge.Parent = card

            local defCorner = Instance.new("UICorner")
            defCorner.CornerRadius = UDim.new(0, 4)
            defCorner.Parent = defBadge
        end

        -- Click + hover handlers
        if isUnlocked then
            card.MouseButton1Click:Connect(function()
                if onBossSelected then
                    onBossSelected(boss)
                end
                screenGui:Destroy()
            end)

            card.MouseEnter:Connect(function()
                TweenService:Create(card, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(65, 58, 80)
                }):Play()
            end)

            card.MouseLeave:Connect(function()
                TweenService:Create(card, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(50, 45, 60)
                }):Play()
            end)
        end
    end

    -- Back button (bottom of panel)
    local backBtn = Instance.new("TextButton")
    backBtn.Name = "BackButton"
    backBtn.Size = UDim2.new(1, -24, 0, 40)
    backBtn.Position = UDim2.new(0, 12, 1, -48)
    backBtn.BackgroundColor3 = Color3.fromRGB(80, 75, 95)
    backBtn.BorderSizePixel = 0
    backBtn.Text = "Back to Menu"
    backBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextSize = 16
    backBtn.Parent = panel

    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(0, 8)
    backCorner.Parent = backBtn

    backBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if onBack then
            onBack()
        end
    end)

    -- Also close on background click
    bg.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if onBack then
            onBack()
        end
    end)

    -- Animate in
    panel.Position = UDim2.new(0.5, 0, 1.5, 0)
    TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()

    return screenGui
end

return CampaignUI
