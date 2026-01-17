# Cat 3D Models Guide

## Overview
This guide covers how to find, import, and integrate cat 3D models for Claws & Paws chess pieces.

## Current Placeholder System
Right now, pieces are represented as:
- **Shape**: Spheres (balls) with cat emoji labels
- **Colors**: Cream (white pieces) and brown tabby (black pieces)
- **Size**: 3x3x3 studs

## Recommended Cat Models

### Option 1: Roblox Toolbox (Easiest)
1. Open Roblox Studio on Windows mini PC
2. View → Toolbox → Models
3. Search for:
   - "cat model" - general cat models
   - "lion model" - for King piece
   - "persian cat" - for Queen piece
   - Each breed mentioned in Constants.lua

**Pro**: Free, already optimized for Roblox, instant integration
**Con**: Quality varies, may need cleanup

### Option 2: Roblox Marketplace (Professional Quality)
Search the Roblox Creator Marketplace for:
- **Cat Character Packages** - Full rigged cat avatars (can be scaled down)
- **Animal Model Packs** - Often include cats
- **Medieval/Fantasy Packs** - May include Lion/cat creatures

Popular creators:
- ROBLOX official models
- Verified UGC creators

**Pro**: High quality, often rigged/animated
**Con**: May cost Robux ($5-$20 typically)

### Option 3: External 3D Models (Advanced)
1. Download CC0/free cat models from:
   - Sketchfab (search "cat", filter by "downloadable")
   - TurboSquid (free section)
   - CGTrader (free models)

2. Import to Blender
3. Export as `.fbx` or `.obj`
4. Use Roblox's mesh import tool (File → Import 3D)

**Pro**: Highest quality, full control
**Con**: Requires 3D modeling knowledge, time-consuming

## Asset IDs for Quick Testing

### Community Cat Models (Asset IDs)
These are placeholder IDs - replace with actual model IDs from Toolbox:

```lua
local CAT_MODEL_IDS = {
    LION = "rbxassetid://1234567890",      -- Lion (King)
    PERSIAN = "rbxassetid://1234567891",   -- Persian cat (Queen)
    MAINE_COON = "rbxassetid://1234567892", -- Maine Coon (Rook)
    SPHINX = "rbxassetid://1234567893",    -- Sphinx cat (Bishop)
    CARACAL = "rbxassetid://1234567894",   -- Caracal (Knight)
    ALLEY_CAT = "rbxassetid://1234567895", -- Generic cat (Pawn)
}
```

## Integration Steps

### Method 1: Using AssetService (Recommended)
```lua
local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")

local function loadCatModel(assetId)
    local success, model = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)

    if success and model then
        local cat = model:GetChildren()[1]
        if cat then
            -- Scale and position
            cat:ScaleTo(0.5) -- Adjust size for chess piece
            return cat:Clone()
        end
    end

    return nil -- Fallback to placeholder
end
```

### Method 2: Pre-imported Models
1. Import all cat models into ReplicatedStorage in Studio
2. Clone them at runtime:
```lua
local CatModels = ReplicatedStorage:WaitForChild("CatModels")

local function getCatPiece(pieceType)
    local modelName = Constants.CatBreed[pieceType]
    local template = CatModels:FindFirstChild(modelName)
    if template then
        return template:Clone()
    end
    return nil -- Fallback
end
```

## Recommended Workflow

### Phase 1: Find Models in Roblox Studio
1. On Windows PC, open Studio
2. Search Toolbox for each cat breed:
   - Lion
   - Persian cat
   - Maine Coon cat
   - Sphinx cat
   - Caracal
   - Alley cat / Tabby cat

3. Insert into workspace, test scale/appearance
4. Right-click → Save to Roblox (gets an asset ID)
5. Note the asset ID for each model

### Phase 2: Update AssetLoader.lua
Replace placeholder IDs with real asset IDs in `src/client/AssetLoader.lua`

### Phase 3: Test Integration
The game will automatically use 3D models if available, fall back to sphere placeholders if not.

## Cat Breeds per Piece (Reference)

| Piece Type | Cat Breed | Why? | Visual Notes |
|------------|-----------|------|--------------|
| King | Lion | King of the jungle! | Majestic mane |
| Queen | Persian | Elegant and regal | Fluffy, royal |
| Rook | Maine Coon | Big and strong | Largest domestic cat |
| Bishop | Sphinx | Mystical appearance | Unique, hairless |
| Knight | Caracal | Fast and agile | Distinctive ear tufts |
| Pawn | Alley Cat | Common, scrappy | Generic tabby |

### Hybrid Pieces (Future)
| Piece Type | Cat Breed | Visual |
|------------|-----------|--------|
| Archbishop | Serval | Spotted, elegant |
| Chancellor | Cheetah | Fast, powerful |
| Amazon | Jaguar | Ultimate predator |

## Sizing Guidelines

Chess pieces should be:
- **Height**: 2-4 studs
- **Width**: 1.5-3 studs
- **Anchored**: Yes
- **CanCollide**: No (so they don't bump into each other)

Use ScaleTo() or Size property to adjust model dimensions.

## Performance Tips

1. **Merge meshes** - Combine multiple parts into one MeshPart
2. **Reduce polycount** - Use low-poly models (< 5k triangles)
3. **Texture atlasing** - Use single texture per model
4. **LOD (Level of Detail)** - Not critical for a 6x6 board, but nice to have

## Fallback Strategy

The current code gracefully falls back to sphere placeholders if models can't load:
```lua
local catModel = AssetLoader.loadPiece(pieceType, color)
if not catModel then
    -- Use sphere placeholder with emoji
    catModel = createPlaceholderPiece(pieceType, color)
end
```

This ensures the game always works, even if 3D assets fail to load.

## Next Steps

1. Search Roblox Toolbox for cat models
2. Get asset IDs
3. Update `AssetLoader.lua` with real IDs
4. Test in Studio
5. Adjust scaling as needed
6. Optional: Commission custom models if budget allows (~$50-$200 per model)

## Resources

- [Roblox Creator Marketplace](https://create.roblox.com/marketplace)
- [Roblox Toolbox](https://create.roblox.com/docs/studio/toolbox)
- [Mesh Import Guide](https://create.roblox.com/docs/art/modeling/meshes)
- [Sketchfab - CC0 Models](https://sketchfab.com/search?q=cat&type=models&licenses=7c23a1ba438d4306920229c12afcb5f9)
