--[[
    Claws & Paws - Campaign Data
    Boss cat battles with increasing difficulty and sinisterness
]]

local CampaignData = {}

-- Campaign bosses - each with personality, difficulty, and sinister backstory
CampaignData.BOSSES = {
    {
        id = "whiskers",
        name = "Sir Whiskers",
        title = "The Lazy Lord",
        difficulty = "Easy",
        aiDifficulty = "AI_EASY",
        description = "A pampered house cat who naps through most of his turns. Good for beginners!",
        portrait = "😺",
        taunt = "Yawn... is it my turn already?",
        victoryQuote = "Well played! Now, back to my nap...",
        defeatQuote = "You dare disturb my slumber?!",
        theme = "Calico", -- Board color theme
        unlocked = true,
    },
    {
        id = "mittens",
        name = "Mittens the Menace",
        title = "Knocking Things Off Tables Since 2019",
        difficulty = "Medium",
        aiDifficulty = "AI_MEDIUM",
        description = "A mischievous kitten who plays chaotically. Unpredictable and dangerous!",
        portrait = "😼",
        taunt = "Oops! Did your piece fall off the board?",
        victoryQuote = "Haha! Just like knocking over your water glass!",
        defeatQuote = "No fair! You didn't let me push any pieces off!",
        theme = "Orange Tabby",
        unlocked = false,
        requiresVictory = "whiskers",
    },
    {
        id = "shadow",
        name = "Shadow",
        title = "The Silent Stalker",
        difficulty = "Hard",
        aiDifficulty = "AI_HARD",
        description = "A mysterious alley cat who hunts in darkness. Masters tactical ambushes.",
        portrait = "😾",
        taunt = "You won't see me coming...",
        victoryQuote = "The shadows always win.",
        defeatQuote = "Impossible... I was perfectly hidden!",
        theme = "Tuxedo Cat",
        unlocked = false,
        requiresVictory = "mittens",
    },
    {
        id = "duchess",
        name = "Duchess Fluffington III",
        title = "Royal Pain in the Paws",
        difficulty = "Expert",
        aiDifficulty = "AI_HARD",
        description = "A Persian cat of noble lineage. Demands perfection and accepts no defeat.",
        portrait = "😻",
        taunt = "Do you even KNOW who I am?!",
        victoryQuote = "Of course. Peasants never stood a chance.",
        defeatQuote = "OUTRAGEOUS! My family will hear about this!",
        theme = "Purple Majesty",
        unlocked = false,
        requiresVictory = "shadow",
    },
    {
        id = "lucifer",
        name = "Lucifur",
        title = "The Nine-Life Necromancer",
        difficulty = "NIGHTMARE",
        aiDifficulty = "AI_HARD",
        description = "An ancient evil cat who has mastered death itself. Uses dark chess magic...",
        portrait = "😈",
        taunt = "I've had nine lives to perfect my game. You have one.",
        victoryQuote = "Another soul for my collection... Purr purr purr...",
        defeatQuote = "This isn't over! I have eight lives left!",
        theme = "Forest Floor",
        unlocked = false,
        requiresVictory = "duchess",
        finalBoss = true,
    },
}

-- Get boss by ID
function CampaignData.getBoss(bossId)
    for _, boss in ipairs(CampaignData.BOSSES) do
        if boss.id == bossId then
            return boss
        end
    end
    return nil
end

-- Get all unlocked bosses for a player
function CampaignData.getUnlockedBosses(playerProgress)
    local unlocked = {}

    for _, boss in ipairs(CampaignData.BOSSES) do
        if boss.unlocked then
            -- First boss is always unlocked
            table.insert(unlocked, boss)
        elseif boss.requiresVictory and playerProgress[boss.requiresVictory] then
            -- Unlocked by defeating previous boss
            table.insert(unlocked, boss)
        end
    end

    return unlocked
end

-- Get next boss to unlock
function CampaignData.getNextBoss(playerProgress)
    for _, boss in ipairs(CampaignData.BOSSES) do
        if not boss.unlocked and boss.requiresVictory then
            if playerProgress[boss.requiresVictory] then
                return boss
            end
        elseif not boss.unlocked and not boss.requiresVictory then
            -- First locked boss with no requirement
            return boss
        end
    end
    return nil
end

-- Calculate campaign completion percentage
function CampaignData.getCompletionPercentage(playerProgress)
    local total = #CampaignData.BOSSES
    local completed = 0

    for bossId, defeated in pairs(playerProgress) do
        if defeated then
            completed = completed + 1
        end
    end

    return math.floor((completed / total) * 100)
end

return CampaignData
