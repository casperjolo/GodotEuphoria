# Animation Setup - Quick Guide

## The Problem
Your FBX files are in the Animations folder, but Godot hasn't imported them yet so they're not accessible to the AnimationPlayer.

## The Solution - 3 Steps

### Step 1: Ensure FBX Files Are in Correct Locations
Your Animations folder should look like:
```
Animations/
├── Idle/
│   ├── animation1.fbx
│   ├── animation2.fbx
│   └── ...
├── Walk/
│   ├── M_Neutral_Walk_Box_B_LL_Lfoot.fbx
│   ├── M_Neutral_Walk_Box_B_LL_Rfoot.fbx
│   └── ... (1700+ walk animations)
├── Run/
├── Sprint/
├── Jump/
├── Crouch/
├── AimOffset/
└── Traversal/
```

**Important:** Files must be directly in these folders, not in subfolders.

### Step 2: Force Godot to Import the FBX Files
1. In Godot Editor, go to: **Project → Tools → Reimport**
2. Wait for the import to complete
3. You should see FBX files appear in the FileSystem panel

### Step 3: Run the Scene
1. Open `Scenes/Fred.tscn`
2. Press **Play (F5)**
3. Check the console output (F8)

You should see:
```
FBXAnimationImporter: Starting animation import...
FBXAnimationImporter: Loaded X animations from res://Animations/Walk/
FBXAnimationImporter: Loaded Y animations from res://Animations/Run/
... (for each folder)
MotionMatcherInitializer: SUCCESS - 1250+ animations in database
```

## What Happens on Startup

1. **FBXAnimationImporter** searches Animations folders for FBX/GLB/GLTF files
2. Loads each file as a scene and extracts animations
3. Adds all found animations to the AnimationPlayer
4. **AnimationLoader** reads from AnimationPlayer and categorizes them
5. **MotionMatcher** builds a database of all animation features
6. Fred is ready to move with motion matching!

## If Animations Still Don't Load

### Check 1: Verify FBX Files Exist
```bash
# In your project folder, verify Animations folder has files:
ls -R Animations/
```

Should show FBX files in each subfolder.

### Check 2: Force Godot Import
1. **Project → Tools → Reimport**
2. Wait for completion
3. Check FileSystem panel - should see `.fbx` entries

### Check 3: Check Console Output
When you run Fred.tscn, watch console (F8) for:
- `FBXAnimationImporter:` messages
- `AnimationLoader:` messages  
- `MotionMatcherInitializer:` messages

If you see `0 animations`, the import didn't work.

### Check 4: Manual Import
If automatic import fails:

1. Open **FBX file directly** in Godot (double-click in FileSystem)
2. It will show import options
3. Make sure it has an AnimationPlayer node
4. Change import settings if needed
5. Click **Reimport**

## Understanding the System

```
Your FBX Files (in Animations/)
        ↓
Godot Import System
        ↓
Imported .fbx.tres files (in .godot/imported/)
        ↓
FBXAnimationImporter.gd (loads them at runtime)
        ↓
AnimationPlayer (contains all loaded animations)
        ↓
AnimationLoader.gd (reads from AnimationPlayer)
        ↓
MotionDatabase (stores features for motion matching)
        ↓
MotionMatcher (selects animations in real-time)
        ↓
Fred plays the right animation!
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Console shows "0 animations" | Run Project > Tools > Reimport |
| FBX files don't appear in FileSystem | They may not be valid FBX files |
| Import takes very long | Normal for 1700+ files - be patient |
| "Cannot open folder" error | Check folder names are exact (case-sensitive) |
| Animations load but Fred doesn't move | Check WASD input and debug with M key |

## Debug Commands (In-Game)

- **M** - Toggle motion matcher debug (shows animation names)
- **R** - Reload animations manually
- **D** - Save motion database to disk

## Next Steps

1. Run the scene and check console output
2. Press M to see what animations are being selected
3. Press WASD to move Fred - he should animate smoothly
4. Tune motion matching weights if animations feel wrong

If animations load (console shows count > 0) but Fred doesn't move, check:
- Is Fred responding to WASD? (Add debug print in FredController)
- Are motion features being extracted? (Press M for debug)
- Is database built? (Check MotionMatcher console output)

Good luck!
