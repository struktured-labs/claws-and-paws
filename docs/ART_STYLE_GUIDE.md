# Claws & Paws - Art Style Guide

## Visual Direction: Anime HD 2D Cute Kitties

### Overview
The game aims for a **high-definition 2D anime aesthetic** with cute, expressive cat characters rendered in HD resolution. Think "HD-2D" style pioneered by games like Octopath Traveler, but with adorable anime cats instead of realistic sprites.

---

## Core Aesthetic Principles

### 1. HD-2D Hybrid Style
- **2D sprites/art** for characters (cat chess pieces)
- **3D environment** for the board and effects
- **High resolution** assets (1024x1024 minimum for piece sprites)
- **Pixel-perfect** clarity, no blurry upscaling

### 2. Anime Cute Cat Style
- **Big expressive eyes** (anime style)
- **Soft, rounded shapes** (kawaii aesthetic)
- **Vibrant colors** with subtle gradients
- **Clean linework** (not overly realistic)
- **Chibi proportions** acceptable for smaller pieces (pawns)

### 3. Color Palette
**Current theme: Cozy Cat Cafe**

| Element | Color | Hex/RGB | Usage |
|---------|-------|---------|-------|
| Light Squares | Cream | rgb(255, 245, 230) | Board |
| Dark Squares | Warm Brown | rgb(139, 90, 60) | Board |
| Accent | Golden Orange | rgb(255, 200, 100) | Highlights |
| UI Primary | Soft Pink | rgb(255, 200, 220) | Buttons (future) |
| UI Secondary | Sky Blue | rgb(180, 220, 255) | Menus (future) |

---

## Cat Character Design Guidelines

### General Rules for All Pieces

1. **Silhouette Clarity**: Each piece type must be instantly recognizable by shape alone
2. **Personality Expression**: Cats should have distinct personalities matching their role
3. **Team Colors**: White team = cream/beige cats, Black team = brown/tabby cats
4. **Size Hierarchy**: King > Queen > Rook/Bishop/Knight > Pawn

### Piece-Specific Character Designs

#### 🦁 **Lion (King)**
- **Concept**: Majestic but cute anime lion
- **Key Features**:
  - Large fluffy mane (anime spiky style)
  - Confident, regal expression
  - Small crown accessory
  - Golden fur with highlights
- **Pose**: Sitting upright, chest puffed out
- **Size**: Largest piece (3.5x3.5 studs)
- **Reference**: Simba (Lion King) meets anime chibi style

#### 👑🐱 **Persian Cat (Queen)**
- **Concept**: Elegant, fluffy anime cat
- **Key Features**:
  - Long, flowing fur (Princess Carolyn vibes)
  - Jeweled collar or tiara
  - Graceful, poised expression
  - Pearl white or chocolate brown fur
- **Pose**: Sitting prettily, tail curled
- **Size**: Second largest (3x3 studs)
- **Reference**: Marie from The Aristocats + anime sparkles

#### 🏰🐱 **Maine Coon (Rook)**
- **Concept**: Big, sturdy, friendly giant
- **Key Features**:
  - Large, muscular build (still cute!)
  - Fluffy fur with tufted ears
  - Confident, protective expression
  - Darker stripes/patches
- **Pose**: Sitting solid, guard-like
- **Size**: 2.8x2.8 studs
- **Reference**: Totoro-style gentle giant, but cat

#### 🔮🐱 **Sphinx Cat (Bishop)**
- **Concept**: Mystical, elegant, slightly mysterious
- **Key Features**:
  - Hairless with smooth skin texture
  - Large ears and eyes (extra anime)
  - Jeweled third-eye marking
  - Wise, knowing expression
- **Pose**: Sitting upright, slightly otherworldly
- **Size**: 2.5x2.5 studs
- **Reference**: Egyptian cat statues + anime magical girl aesthetic

#### ⚡🐱 **Caracal (Knight)**
- **Concept**: Energetic, athletic, playful
- **Key Features**:
  - Distinctive ear tufts (caracal signature)
  - Sleek, agile build
  - Mischievous, determined expression
  - Light tan/golden fur
- **Pose**: Ready to pounce, dynamic
- **Size**: 2.5x2.5 studs
- **Reference**: Anime action cat (think Meowth energy)

#### 🐾 **Alley Cat (Pawn)**
- **Concept**: Scrappy, cute, underdog
- **Key Features**:
  - Simple tabby pattern
  - Big hopeful eyes
  - Small, compact build (chibi style)
  - Determined but innocent expression
- **Pose**: Standing on hind legs or sitting alert
- **Size**: Smallest (2x2 studs)
- **Reference**: Chi from Chi's Sweet Home

---

## Technical Specifications for 2D Sprites

### Resolution & Format
- **Size**: 1024x1024px minimum
- **Format**: PNG with transparency
- **DPI**: 300 for crisp rendering
- **Color Mode**: RGB with alpha channel

### Sprite Requirements
1. **Idle Pose**: Default standing/sitting
2. **Selected Pose**: Slight glow/shimmer effect
3. **Victory Pose**: Happy/celebrating (optional)
4. **Capture Pose**: Attack animation frame (optional)

### Roblox Integration
- Import as **ImageLabel** billboard GUI attached to invisible Part
- Or use **SurfaceGui** on a flat Part facing camera
- Enable **AlwaysOnTop** for visibility
- Add soft drop shadow for depth

---

## Animation Style

### Movement Animations
- **Smooth tweening** (TweenService with Quad/Sine easing)
- **Slight squash/stretch** on landing (anime style)
- **Particle trails** (sparkles, paw prints) during movement
- **Bounce** on selection (kawaii feedback)

### Battle Animations
- **Pounce Attack**: Arc trajectory with spin
- **Capture Hit**: Small anime "impact star" effect
- **Hurt**: Brief shake with sweat drop emoji
- **Victory**: Happy bounce with star particles

---

## UI Design Language

### Fonts
- **Primary**: FredokaOne (playful, rounded)
- **Secondary**: Gotham (clean, readable)
- **Accent**: Comic Sans (for cat puns only, sparingly)

### Button Style
- **Shape**: Rounded rectangles (UICorner radius 10-15)
- **Colors**: Pastel gradients (pink → orange, blue → purple)
- **Hover**: Slight scale up (1.05x) + glow
- **Click**: Scale down (0.95x) + sound effect

### Panel Style
- **Background**: Semi-transparent dark (40% opacity)
- **Border**: Bright outline stroke (3px, anime-style)
- **Corners**: Heavily rounded (15-20px radius)
- **Shadow**: Soft drop shadow for depth

---

## Lighting & Effects

### Board Lighting
- **Ambient**: Soft warm light from above
- **Piece Highlights**: Rim lighting on selected pieces
- **Square Glow**: Neon-style glow for valid moves (anime magic circle vibes)

### Particle Effects
- **Sparkles**: Gold twinkles on selection
- **Paw Prints**: Brown paw trail during movement
- **Magic Circles**: Anime-style circles for power-ups (future)
- **Confetti**: Colorful on victory

---

## Reference Games/Shows

### Visual Inspiration
1. **Octopath Traveler** - HD-2D style
2. **Genshin Impact** - Anime character design
3. **Neko Atsume** - Cute cat personalities
4. **Chi's Sweet Home** - Adorable cat expressions
5. **The Aristocats** - Classic Disney cat elegance

### Art Styles to Emulate
- **Kurzgesagt** - Clean, modern vector art
- **Studio Ghibli** - Soft, warm colors
- **Pokémon** - Clear silhouettes, vibrant colors
- **Undertale/Deltarune** - Expressive character sprites

---

## Asset Creation Workflow

### For Artists
1. **Sketch** concept in Procreate/Photoshop
2. **Linework** clean with pen tool
3. **Color** with cel-shading (anime style)
4. **Highlights** add sparkles/shine
5. **Export** at 1024x1024 PNG

### For Roblox Integration
1. Upload to Roblox as Decal/Image
2. Get Asset ID
3. Update `AssetLoader.lua` with ID
4. Test in Studio for scale/alignment

---

## Current Placeholder vs. Target

| Current | Target |
|---------|--------|
| Sphere with emoji | HD 2D sprite billboard |
| Generic colors | Team-specific fur patterns |
| No animation | Smooth anime tweens |
| Basic particles | Anime-style effects |

---

## Next Steps for Art Implementation

1. **Commission artist** familiar with anime/chibi cat art
   - Budget: ~$50-100 per piece (6 types × 2 teams = 12 sprites)
   - Total: ~$600-1200 for full set

2. **DIY with AI** (DALL-E, Midjourney, Stable Diffusion)
   - Prompt: "cute anime chibi [CAT BREED] cat, HD 2D game sprite, transparent background, front view, sitting pose"
   - Upscale to 1024x1024
   - Manual touch-ups in Photoshop

3. **Use stock assets** (temporary)
   - Search "anime cat sprite" on itch.io, OpenGameArt
   - Modify colors for team distinction

4. **Hybrid approach** (recommended)
   - AI generate base designs
   - Commission artist to refine/polish
   - Budget: ~$30-50 per piece

---

## Color Variations for Teams

### White Team
- **Base Color**: Cream (rgb(255, 240, 220))
- **Accent**: Soft gold highlights
- **Eyes**: Blue or green
- **Accessories**: Silver, white

### Black Team
- **Base Color**: Brown tabby (rgb(80, 60, 50))
- **Accent**: Dark chocolate shadows
- **Eyes**: Amber or yellow
- **Accessories**: Bronze, copper

---

## Accessibility Notes

- **Colorblind Mode**: Add pattern overlays (stripes for black, solid for white)
- **Dyslexia-Friendly**: Use OpenDyslexic font option
- **High Contrast**: Toggle for bold outlines
- **Screen Reader**: All pieces have text labels

---

## Implementation Priority

1. **Phase 1** (Current): Emoji placeholders ✅
2. **Phase 2** (Next): Simple 2D icon sprites
3. **Phase 3**: HD anime-style sprites
4. **Phase 4**: Animated sprite sheets
5. **Phase 5**: 3D cel-shaded models (optional premium tier)

---

## Budget Estimate

| Item | Cost | Notes |
|------|------|-------|
| Placeholder emoji | $0 | Done ✅ |
| Icon pack (itch.io) | $10-30 | Interim solution |
| AI-generated sprites | $20 | DALL-E credits |
| Commission artist | $600-1200 | Full custom set |
| Animated sheets | +$500 | If desired |
| **Total (Custom)** | **~$1000** | One-time investment |

---

## Style Examples (Text Description for AI Generation)

### King Lion Prompt
```
A cute chibi anime lion with a fluffy golden mane, wearing a small crown,
sitting upright with a confident smile, front-facing view, HD 2D game sprite,
transparent background, soft cel-shading, warm lighting, kawaii style
```

### Pawn Alley Cat Prompt
```
An adorable chibi anime tabby kitten, big sparkling eyes, sitting on hind legs
with paws together, innocent expression, front-facing view, HD 2D game sprite,
transparent background, soft pastel colors, kawaii style
```

---

End of Art Style Guide. Update as art direction evolves!
