# Claws & Paws

A simplified, cat-themed chess variant for Roblox featuring a 6x6 board, Fischer Random-style starting positions, and adorable battle animations.

## Game Concept

**Claws & Paws** reimagines chess as an accessible, viral-ready Roblox experience where cats battle for board supremacy. Simplified rules lower the barrier to entry while maintaining strategic depth.

### Key Features

- **6x6 Board**: Faster games, easier to learn
- **Cat-Themed Pieces**: Lion King, Persian Queen, Maine Coon Rook, Sphinx Bishops, Caracal Knight, Alley Cat Pawns
- **Fischer Random**: No opening memorization - back rank is randomized each game
- **No Castling/En Passant**: Streamlined rules for new players
- **Cute Battle Animations**: Watch cats clash when pieces capture
- **AI Opponents**: Personality-driven cat commanders with LLM dialogue
- **Multiplayer**: Ranked and casual matchmaking
- **Skin Marketplace**: Customizable cat breeds and board themes

## Project Structure

```
claws-and-paws/
├── src/
│   ├── client/          # Client-side scripts
│   │   └── init.client.lua
│   ├── server/          # Server-side scripts
│   │   └── init.server.lua
│   └── shared/          # Shared modules
│       ├── Constants.lua
│       ├── ChessEngine.lua
│       ├── ChessAI.lua
│       └── init.lua
├── assets/
│   ├── images/
│   ├── sounds/
│   └── animations/
├── docs/
│   └── GAME_DESIGN.md
├── default.project.json  # Rojo project config
└── README.md
```

## Development Setup

### Prerequisites

- [Roblox Studio](https://www.roblox.com/create)
- [Rojo](https://rojo.space/) for file sync
- [Selene](https://kampfkarren.github.io/selene/) (optional, for linting)

### Getting Started

1. Clone the repository:
   ```bash
   git clone git@github.com:struktured-labs/claws-and-paws.git
   cd claws-and-paws
   ```

2. Start Rojo server:
   ```bash
   rojo serve
   ```

3. Open Roblox Studio and connect via the Rojo plugin

4. Changes sync automatically between filesystem and Studio

## Cat Piece Roster

| Piece | Cat Breed | Personality |
|-------|-----------|-------------|
| King | **Lion** | Majestic elder, speaks in proverbs |
| Queen | **Persian** | Calculating, slightly condescending |
| Rook | **Maine Coon** | Loyal guardian, few words |
| Bishop | **Sphinx** | Mystical, speaks in riddles |
| Knight | **Caracal** | Chaotic, trash-talks |
| Pawns | **Alley Cats** | Scrappy underdogs |

### Hybrid Pieces (Special Modes)

| Hybrid | Movement | Cat Breed |
|--------|----------|-----------|
| Archbishop | Bishop + Knight | Serval |
| Chancellor | Rook + Knight | Cheetah |
| Amazon | Queen + Knight | Jaguar |

## Roadmap

1. **MVP**: Core chess logic, 6x6 board, local play
2. **Multiplayer**: Server-authoritative games, matchmaking
3. **Polish**: Battle animations, sound design, themes
4. **AI**: Minimax opponents with personalities
5. **Live Ops**: Skins, battle pass, daily challenges

## License

TBD

## Contributing

This project is currently in early development.
