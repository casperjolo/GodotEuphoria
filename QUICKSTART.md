# Motion Matching System - Quick Start Guide

## What You Have

A complete **motion matching and retargeting system** for the Fred character that automatically:
- Loads animations from organized folders
- Maps animations to Fred's skeleton (retargeting)
- Selects the best animation based on desired motion (velocity, direction, etc.)
- Smoothly transitions between animations

## Files Created

### Core System (in `Scenes/`)
- `BoneMapping.gd` - Maps skeleton bones between source and target
- `Retargeter.gd` - Applies retargeted animations to Fred
- `MotionFeature.gd` - Data structure for animation features
- `MotionDatabase.gd` - Searchable animation database
- `MotionMatcher.gd` - Main motion matching engine
- `AnimationLoader.gd` - Loads animations from AnimationPlayer
- `FredController.gd` - Character controller (WASD movement)
- `MotionMatcherInitializer.gd` - Initializes the system

### Documentation
- `Scenes/README.md` - Full architecture and reference
- `Scenes/SETUP_GUIDE.md` - Detailed setup instructions
- `QUICKSTART.md` - This file

### Scene
- `Scenes/Fred.tscn` - Updated with all system components

## How to Use

### Step 1: Prepare Your Animations

Place FBX files in the correct folder structure:
```
Animations/
├── Idle/          (idle animations)
├── Walk/          (walking animations)
├── Run/           (running animations)
├── Sprint/        (sprinting animations)
├── Jump/          (jump animations)
├── Crouch/        (crouch animations)
├── AimOffset/     (aiming animations)
└── Traversal/     (special traversal)
```

**Important:** Godot must import these FBX files. Ensure:
1. FBX files are in `res://` directory (your project root)
2. Godot will auto-detect and import them
3. If needed, go to `Project > Tools > Reimport`

### Step 2: Run the Scene

1. Open `Scenes/Fred.tscn` in Godot
2. Click the **Play** button (F5)
3. Fred should appear in the viewport

### Step 3: Test Movement

- **WASD** - Move Fred around
- **Space** - Sprint (faster movement)
- **M** - Toggle debug output (shows motion matching info)
- **R** - Reload animations from AnimationPlayer
- **D** - Save motion database to disk

### Step 4: Verify System

You should see:
1. Fred appearing with his model
2. Smooth animation transitions when moving
3. Debug output showing animation names and motion data

## How It Works (Overview)

```
You Press WASD
    ↓
FredController reads input
    ↓
Sets desired velocity and direction
    ↓
MotionMatcher queries MotionDatabase
    ↓
Finds best matching animation frame
    ↓
Transitions to new animation
    ↓
Retargeter maps animation to Fred's skeleton
    ↓
Fred's pose updates (smooth animation)
```

## Key Concepts

### Motion Matching
- **Query Space**: Velocity, heading, foot contact state
- **Distance Metric**: Finds closest animation frame to desired motion
- **Advantages**: Natural transitions, no explicit state machine needed

### Retargeting
- **Bone Mapping**: Maps animation skeleton to Fred's skeleton
- **Auto-Detection**: Tries to match bone names automatically
- **Customizable**: Edit `BoneMapping.gd` if needed

### Animation Database
- **Built Runtime**: Extracts motion features from all loaded animations
- **Searchable**: Fast queries to find best matching frame
- **Saveable**: Can save database to disk to speed up loading

## Troubleshooting

### Problem: Fred doesn't move
**Solution:**
1. Check console for errors (F8)
2. Verify `AnimatedTarget` contains Fred.glb
3. Ensure AnimationPlayer node exists in Fred.glb
4. Press R to reload animations

### Problem: No smooth transitions
**Solution:**
1. Press M to enable debug output
2. Check that animations are being matched
3. Verify `transition_blend_time` in MotionMatcher
4. Try adjusting motion feature weights in MotionFeature.gd

### Problem: Animations aren't loading
**Solution:**
1. Verify folder structure (Idle/, Walk/, Run/, etc.)
2. Ensure FBX files are in `res://Animations/`
3. Godot may not have imported them - try `Project > Tools > Reimport`
4. Check if animations appear in AnimationPlayer's list

## Customization

### Change Movement Speed
Edit `FredController.gd`:
```gdscript
@export var move_speed: float = 5.0      # Change this
@export var sprint_speed: float = 10.0   # Change this
```

### Adjust Animation Matching Sensitivity
Edit `MotionFeature.gd` in the `distance_to()` function:
```gdscript
var weights = {
    "position": 1.0,      # How much to match position
    "velocity": 2.0,      # How much to match velocity (higher = more important)
    "foot_contact": 1.5,  # How much to match foot contact
    "direction": 1.0,     # How much to match direction
}
```

### Change Blend Time Between Animations
Edit `MotionMatcher.gd`:
```gdscript
@export var transition_blend_time: float = 0.25  # Increase for smoother blends
```

## Performance Notes

- **Memory**: ~5-10MB per 1000 animations
- **CPU**: Feature queries are O(n) - linear search through all animations
- **Optimization**: Can use KD-tree for faster queries (future enhancement)

## Next Steps

1. **Add More Animations** - Populate the Animations/ folders
2. **Tune Weights** - Adjust motion matching sensitivity
3. **Implement IK** - Add foot IK for ground contact (placeholder exists)
4. **Add Features** - Add falling, climbing, swimming states
5. **Optimize** - Profile and optimize for your target platform

## Debug Commands

Press these keys in the running game:

| Key | Action |
|-----|--------|
| M | Toggle motion matcher debug output |
| R | Reload all animations |
| D | Save motion database to disk |

## Files Reference

**Main Scene:**
- `Scenes/Fred.tscn` - Character scene with all components

**Core System:**
- `Scenes/MotionMatcher.gd` - Main engine (attach to MotionMatcher node)
- `Scenes/AnimationLoader.gd` - Animation manager (attach to AnimationLoader node)
- `Scenes/Retargeter.gd` - Retargeting (attach to Retargeter node)
- `Scenes/FredController.gd` - Input handler (attach to FredController node)

**Data Structures:**
- `Scenes/BoneMapping.gd` - Skeleton mapping
- `Scenes/MotionFeature.gd` - Motion feature data
- `Scenes/MotionDatabase.gd` - Animation database
- `Scenes/MotionMatcherInitializer.gd` - Startup initialization

**Models:**
- `NaturalMotion/Characters/Fred.glb` - Character model

**Animations:**
- `Animations/` - Folder structure for FBX animations

## Support

For issues or questions:
1. Check the console output (F8)
2. Enable debug mode (press M)
3. Review `Scenes/README.md` for architecture details
4. Check `Scenes/SETUP_GUIDE.md` for detailed setup

Good luck with your motion matching system!
