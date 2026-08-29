# Motion Matching System Setup Guide for Fred

## Overview
This guide explains how to set up the motion matching system for the Fred character. The system automatically matches character animations based on desired motion parameters (velocity, direction, etc.).

## Components

### Core Scripts
- **BoneMapping.gd** - Maps animation bones to Fred's skeleton
- **Retargeter.gd** - Applies retargeted animations to Fred's model
- **MotionFeature.gd** - Data structure for animation frame features
- **MotionDatabase.gd** - Stores and queries motion features
- **MotionMatcher.gd** - Main motion matching engine
- **AnimationLoader.gd** - Loads animations from folders
- **FredController.gd** - Character controller for input handling

### Scene Structure
```
Fred (CharacterBody3D)
├── DriverShape (CollisionShape3D)
├── HipMarker (Marker3D)
├── MotionMatcher (Node) -> MotionMatcher.gd
├── RootMotionNeutraliser (Node)
├── AnimatedTarget (Fred.glb)
├── Retargeter (Node) -> Retargeter.gd
├── AnimationLoader (Node) -> AnimationLoader.gd
├── FootIK (Node)
├── FredController (Node) -> FredController.gd
└── CameraRig (Node3D)
    └── SpringArm3D
        └── Camera3D
```

## Setup Instructions

### 1. Prepare Animations

The system expects FBX animations in the following folder structure:
```
Animations/
├── Idle/
├── Walk/
├── Run/
├── Sprint/
├── Jump/
├── Crouch/
├── AimOffset/
└── Traversal/
```

**Important:** FBX files must be imported by Godot before use. To do this:
1. Ensure your FBX files are in folders under `res://Animations/`
2. Godot will automatically detect and import them
3. Check `Project > Tools > Reimport` if needed to force import

### 2. Configure Bone Mapping

The bone mapping is automatic but can be customized in `BoneMapping.gd`:
- Edit `SOURCE_BONES` dictionary to match your animation skeleton
- The script automatically maps common bone names
- Test with `Motion Matcher > enable_debug = true`

### 3. Load Animations at Runtime

The `AnimationLoader` loads animations from the folder structure. To trigger:
- Press **R** in-game to reload animations
- Or call `animation_loader.load_all_animations()`

### 4. Build Motion Database

Once animations are loaded, the motion database is built automatically:
```gdscript
motion_matcher.build_database_from_animations()
```

This extracts motion features (velocity, foot position, contact, etc.) from each frame.

### 5. Test the System

1. Press Play to start the scene
2. Use **WASD** to move Fred around
3. Hold **Space** to sprint
4. Press **M** to toggle debug output
5. Press **D** to save the motion database

## Motion Matching Algorithm

The system uses a feature-distance metric to find the best matching animation frame:

**Distance Metric:**
- Root position difference
- Velocity difference (weighted heavily)
- Foot position differences
- Foot contact state matching
- Heading/direction difference

**Weights (configurable in MotionFeature.distance_to):**
- Position: 1.0
- Velocity: 2.0
- Foot Contact: 1.5
- Direction: 1.0

## Advanced Configuration

### Customize Speed Values
Edit in `FredController.gd`:
```gdscript
@export var move_speed: float = 5.0      # Walk speed
@export var sprint_speed: float = 10.0   # Sprint speed
@export var rotation_speed: float = 5.0  # Turn speed
```

### Adjust Matching Sensitivity
Edit in `MotionFeature.gd` the `distance_to()` function to change weights for different features.

### Transition Blend Time
Edit in `MotionMatcher.gd`:
```gdscript
@export var transition_blend_time: float = 0.25
```

## Input Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Space | Sprint |
| M | Toggle debug output |
| R | Reload animations |
| D | Save motion database |

## Troubleshooting

### No Animations Loading
- Ensure FBX files are in `res://Animations/` subfolders
- Check Godot's import status
- Check console for errors (F8)

### Fred Not Moving
- Verify AnimatedTarget has a valid skeleton
- Check Retargeter bone mapping in debug mode
- Ensure MotionMatcher and AnimationLoader scripts are attached

### Jerky Animation Blending
- Increase `transition_blend_time` in MotionMatcher
- Adjust motion feature weights in MotionFeature.distance_to()
- Ensure animation frame rate matches (default 30 FPS)

### Poor Animation Matching
- Verify animations are categorized correctly (walk/run/sprint in folder names)
- Adjust distance metric weights in MotionFeature
- Ensure foot contact detection is working (toggle debug)

## Performance Tips

1. **Animation Database Caching:** The motion database is built at startup and can be saved to disk
2. **Frame Rate:** Adjust sampling rate in MotionMatcher._extract_features_from_animation()
3. **Query Optimization:** Limit matching searches by locomotion type

## Future Enhancements

- Foot IK for better ground contact
- Root motion neutralization
- Blending between multiple animation candidates
- Phase-matched transitions for smoother blending
- Advanced feature extraction (ground normal, slope, etc.)
- Controller support for analog input
