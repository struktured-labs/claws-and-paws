# Claws & Paws: Game Design Document

## Overview

**Claws & Paws** is a simplified, cat-themed chess variant for Roblox featuring a 6x6 board, reduced piece count, Fischer Random-style back rank randomization, and cute battle animations. The game targets casual players while sneakily teaching chess fundamentals.

---

## Core Game Mechanics

### Board Layout
- **6x6 grid** (36 squares vs traditional 64)
- Alternating light/dark squares with imaginative theming (yarn balls, scratching posts, fish patterns)
- Visual clarity maintained for tactical analysis

### Piece Set (Per Player)
| Piece | Count | Cat Breed | Personality |
|-------|-------|-----------|-------------|
| King | 1 | **Lion** (Leo) | Majestic, protective, deep voice |
| Queen | 1 | **Persian** | Elegant, calculating, regal demeanor |
| Rook | 1 | **Maine Coon** | Large, sturdy, dependable guardian |
| Bishop | 2 | **Sphinx** | Mystical, wise, spiritual advisor |
| Knight | 1 | **Caracal** | Agile, unpredictable, wild energy |
| Pawns | 6 | **Alley Cats** | Scrappy, diverse, underdog spirit |

**Total: 12 pieces per player (24 total)**

### Starting Position
- Fischer Random style: Back rank pieces randomly shuffled each game
- Pawns always start on rank 2 (white) / rank 5 (black)
- Ensures variety and reduces opening memorization advantage

### Simplified Rules
- **No castling** (only 1 rook anyway)
- **No en passant** (keeps it simple)
- Pawn promotion at final rank (choose any captured piece or default to Queen)
- Standard movement patterns otherwise preserved

---

## Cat Piece Deep Dive

### The Lion King
- Visual: Golden mane, crown, regal pose
- Battle animation: Mighty roar and pounce
- Capture sound: Triumphant lion roar
- Personality (AI): Wise elder, speaks in proverbs

### The Persian Queen
- Visual: Fluffy, tiara, flowing fur, elegant walk
- Battle animation: Graceful but deadly swipe
- Capture sound: Satisfied purr
- Personality (AI): Strategic mastermind, slightly condescending

### The Maine Coon Rook
- Visual: Massive, fluffy, tower-like stance
- Battle animation: Powerful charge, unstoppable force
- Capture sound: Deep, resonant meow
- Personality (AI): Loyal protector, few words

### The Sphinx Bishops
- Visual: Hairless, mysterious eyes, mystic aura/glow
- Battle animation: Diagonal energy beam / mystical pounce
- Capture sound: Ethereal chime
- Personality (AI): Speaks in riddles, ancient wisdom

### The Caracal Knight
- Visual: Tufted ears, athletic build, dynamic pose
- Battle animation: Acrobatic leap and twist
- Capture sound: Wild cat screech
- Personality (AI): Chaotic, unpredictable, trash-talks

### The Alley Cat Pawns
- Visual: Varied appearances (tabby, calico, tuxedo, orange, grey, black)
- Battle animation: Scrappy street fight
- Capture sound: Hiss and scratch
- Personality (AI): Underdog spirit, can be promoted to greatness

---

## Hybrid Pieces (Unlockable / Special Modes)

| Hybrid | Movement | Cat Breed Concept |
|--------|----------|-------------------|
| **Archbishop** (Bishop+Knight) | Diagonal + L-shape | **Serval** - tall, spotted, agile |
| **Chancellor** (Rook+Knight) | Straight + L-shape | **Cheetah** - fastest hybrid |
| **Amazon** (Queen+Knight) | All directions + L | **Jaguar** - ultimate apex predator |

---

## Visual Style

### Art Direction
- **Nintendo flagship quality** (Mario Odyssey, Kirby vibes)
- Overly shiny, saturated colors
- Expressive cartoon eyes on all cats
- Bouncy, playful animations
- Particle effects (sparkles, yarn threads, paw prints)

### Chess Board Themes (Unlockable)
1. **Cat Cafe** - Cozy indoor setting, mugs, cushions
2. **Cardboard Kingdom** - Giant boxes, cat towers
3. **Fish Market** - Waterfront, fish crates as squares
4. **Yarn Factory** - Colorful yarn balls, knitting needles
5. **Moonlit Rooftop** - Nighttime city, stars, moon
6. **Ancient Egypt** - Pyramids, honoring cat deity history

---

## Game Modes

### Multiplayer
- **Ranked Play**: ELO-based matchmaking, seasonal rewards
- **Casual Play**: No ranking impact, practice mode
- **Speed Chess**: 1-minute, 3-minute, 5-minute variants
- **Daily Challenge**: Same puzzle for all players, leaderboard

### Single Player (Quest Mode)
- **Campaign**: Face AI cats with escalating difficulty
- **AI Personalities**: Each opponent is a unique cat character
- **LLM Integration**: Dynamic dialogue, trash talk, hints
- **Boss Battles**: Special hybrid-piece opponents

### Puzzles
- **Daily Puzzle**: "Mate in X" challenges
- **Puzzle Rush**: Solve as many as possible in time limit
- **Learn Mode**: Interactive tutorials teaching piece movement

---

## Equalizer Mechanics ("Blue Shell" Alternatives)

### Catnip Power-Ups
Earned by losing player or randomly spawning:

| Power-Up | Effect |
|----------|--------|
| **Catnip Bomb** | Opponent's piece of choice skips 1 turn (distracted) |
| **Summon Alley Cat** | Place an extra pawn on empty back rank |
| **Laser Pointer** | Force opponent's piece to move to specific square |
| **Cardboard Box** | Make one of your pieces invisible for 2 turns |
| **Zoomies** | One piece gets +1 square movement range this turn |

### Balance Notes
- Power-ups optional (can be disabled in ranked)
- 6x6 board already reduces complexity advantage
- Fischer Random reduces opening theory advantage

---

## Social Features

### Cat Gesture Menu (Trash Talk)
Limited expressive options (safe for all ages):
- 😺 Happy meow
- 😾 Angry hiss
- 🙀 Surprised gasp
- 😸 Sly grin
- 😿 Sad meow
- 🐱 Paw wave
- 💤 Sleepy yawn (when opponent takes too long)
- 🐟 Fish offering (good game)

### Emotes & Celebrations
- Victory dance animations
- Defeat graceful bow
- Piece-specific celebrations when capturing

---

## Monetization & Skins

### Skin Categories
1. **Piece Skins**: Alternative breeds/styles per piece type
2. **Board Skins**: Themed chess boards
3. **Animation Packs**: Different battle/capture animations
4. **Sound Packs**: Alternative meows and effects
5. **Accessories**: Hats, collars, glasses for pieces

### Acquisition Methods
- **In-game currency** (earned through play)
- **Robux** (premium currency)
- **Battle Pass** (seasonal cosmetic track)
- **Achievement unlocks** (skill-based rewards)

### Example Skin Lines
- **Cosmic Cats**: Galaxy-themed, starry fur
- **Steampunk Strays**: Victorian mechanical cats
- **Pixel Purrfect**: 8-bit retro style
- **Holiday Collection**: Seasonal event skins

---

## Technical Architecture

### Roblox Structure
```
src/
├── server/           # Server-side logic
│   ├── ChessEngine/  # Game state, move validation
│   ├── Matchmaking/  # Player pairing, ELO
│   ├── DataStore/    # Persistence, rankings
│   └── AI/           # Bot opponents
├── client/           # Client-side logic
│   ├── UI/           # Menus, HUD, chat
│   ├── Input/        # Piece selection, moves
│   ├── Animation/    # Battle animations
│   └── Audio/        # Sound management
└── shared/           # Shared modules
    ├── Constants/    # Piece values, board size
    ├── MoveLogic/    # Movement rules
    └── Types/        # Type definitions
```

### Key Systems
1. **Chess Engine**: Validates moves, checks win conditions
2. **Networking**: RemoteEvents for move sync
3. **Animation Controller**: Battle sequence playback
4. **AI Engine**: Minimax with alpha-beta pruning, adjustable depth
5. **LLM Integration**: API calls for AI personality dialogue

---

## Development Phases

### Phase 1: Core Chess (MVP)
- 6x6 board with standard piece movement
- Local 2-player hotseat mode
- Basic piece models and animations
- Move validation and win detection

### Phase 2: Multiplayer
- Server-authoritative game state
- Matchmaking and ranked play
- Basic UI and menus

### Phase 3: Polish & Personality
- Battle animations
- Cat gesture menu
- Sound design
- Board themes

### Phase 4: Single Player & AI
- AI opponents with difficulty levels
- Quest mode structure
- LLM personality integration

### Phase 5: Monetization & Live Ops
- Skin marketplace
- Battle pass system
- Daily challenges
- Seasonal events

---

## Success Metrics

### Viral Potential Factors
- Unique cat theme (underserved niche)
- Simplified chess (lower barrier)
- Visual appeal (shareable moments)
- Social features (friend invites)
- Regular content updates

### KPIs to Track
- Daily Active Users (DAU)
- Session length
- Matches per session
- Conversion rate (free to paid)
- Retention (D1, D7, D30)

---

## Appendix: Name Ideas
- **Claws & Paws** (current)
- **Purrfect Check**
- **Meow Mate**
- **Feline Tactics**
- **Cat-ch the King**
- **Whisker Wars**
- **9 Lives Chess**
