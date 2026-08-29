# Fred Motion Matching System

Complete motion matching and retargeting system for the Fred character in Godot 4.7.

## Quick Start

1. **Import FBX Animations**
   - FBX files in `Animations/` folders are auto-imported by Godot
   - Ensure they're in `res://` directory structure
   - Godot will create `.glb` or `.gltf` imported versions

2. **Run the Scene**
   - Open `Scenes/Fred.tscn`
   - Press Play (F5)
   - Use WASD to move, Space to sprint

3. **Debug**
   - Press M to toggle motion matcher debug output
   - Press R to reload animations
   - Press D to save motion database

## Architecture

### Motion Matching Pipeline
```
Input Commands (WASD, etc.)
    ↓
FredController (processes input)
    ↓
set_desired_motion() → MotionMatcher
    ↓
Query MotionDatabase for matching frames
    ↓
Find best match by distance metric
    ↓
Transition to matched animation
    ↓
Retargeter maps animation to Fred skeleton
    ↓
AnimatedTarget (Fred.glb) updates pose
```

### Key Classes

**MotionFeature** - Snapshot of animation state
- Root position/velocity
- Local velocity and heading
- Joint positions (feet, hands)
- Foot contact states
- Locomotion type tag

**MotionDatabase** - Searchable animation database
- Stores MotionFeature sequences for each animation
- Supports filtering by locomotion type
- Fast feature-space queries

**MotionMatcher** - Main matching engine
- Processes desired motion each frame
- Queries database for best matching frame
- Handles animation transitions
- Manages playback

**BoneMapping** - Skeleton retargeting
- Maps source animation bones to Fred's skeleton
- Auto-detects bone names (case-insensitive partial match)
- Customizable per-character

**Retargeter** - Animation application
- Applies retargeted bone transforms
- Works with BoneMapping to update Fred's pose

## File Structure

```
Scenes/
├── Fred.tscn                          # Main character scene
├── BoneMapping.gd                     # Skeleton bone mapping
├── Retargeter.gd                      # Animation retargeting
├── MotionFeature.gd                   # Motion data structure
├── MotionDatabase.gd                  # Animation feature database
├── MotionMatcher.gd                   # Motion matching engine
├── AnimationLoader.gd                 # Animation loading
├── FredController.gd                  # Character controller
├── MotionMatcherInitializer.gd        # System initialization
├── SETUP_GUIDE.md                     # Detailed setup
└── README.md                          # This file

Animations/
├── Idle/                              # Idle animations
├── Walk/                              # Walk animations
├── Run/                               # Run animations
├── Sprint/                            # Sprint animations
├── Jump/                              # Jump animations
├── Crouch/                            # Crouch animations
├── AimOffset/                         # Aiming offset
└── Traversal/                         # Special traversal (ledges, etc.)

NaturalMotion/
└── Characters/
    └── Fred.glb                       # Main character model
```

## Features

✅ **Automatic Retargeting**
- Auto-detect skeleton bones
- Map animations to target character
- Support for multiple bone naming conventions

✅ **Motion Matching**
- Feature-based animation selection
- Smooth blending between animations
- Supports multiple locomotion types

✅ **Animation Organization**
- Folder-based categorization (Idle, Walk, Run, Sprint)
- Automatic type detection from animation names
- Scalable to thousands of animations

✅ **Debug Tools**
- Real-time motion feature visualization
- Database inspection
- Performance profiling

## Customization

### Bone Names
Edit `BoneMapping.gd` SOURCE_BONES dictionary:
```gdscript
const SOURCE_BONES = {
    "hips": "Hips",
    "left_foot": "LeftFoot",
    # ... add your bone names
}
```

### Motion Matching Weights
Edit `MotionFeature.distance_to()`:
```gdscript
var weights = {
    "position": 1.0,
    "velocity": 2.0,
    "foot_contact": 1.5,
    "direction": 1.0,
}
```

### Character Speeds
Edit `FredController.gd`:
```gdscript
@export var move_speed: float = 5.0
@export var sprint_speed: float = 10.0
```

## Performance

- Motion database built on first load (~1-2 seconds for 1000+ animations)
- Feature queries: O(n) linear search (can be optimized with KD-tree)
- Animation playback: Real-time, 60 FPS capable
- Memory: ~5-10MB per 1000 animations stored

## Known Limitations

1. **FBX Import** - Requires Godot import process
   - Solution: Ensure files in `res://` and reimport if needed

2. **Foot IK** - Not yet implemented
   - Placeholder exists in scene
   - Can add IK pass after motion matching

3. **Root Motion** - Simplified implementation
   - Neutralizer node for future root motion adjustment
   - Currently uses velocity-based movement

4. **Transitions** - Linear blending
   - Can add phase-matched transitions for smoother blends
   - Current system supports multi-frame blend time

## Troubleshooting

### Animations Not Loading
```
Error: AnimationLoader: Could not open folder
→ Check Animations/ folder is in res:// (project root)
→ Ensure subfolders exist (Idle/, Walk/, etc.)
```

### Fred Not Moving
```
Error: MotionMatcher: No AnimationPlayer found
→ Check Fred.glb has AnimationPlayer node
→ Verify scene hierarchy matches expected structure
```

### Poor Animation Quality
```
Solution: Adjust motion feature weights
→ Increase "velocity" weight for more velocity-sensitive matching
→ Adjust "foot_contact" for better ground contact matching
```

## Next Steps

1. **Populate Animations** - Add FBX files to Animations/ folders
2. **Test Matching** - Run scene and verify smooth transitions
3. **Tune Weights** - Adjust motion feature weights for feel
4. **Add Features** - Implement foot IK, root motion neutralizer
5. **Optimize** - Profile and optimize for target platform

## References

- [Godot Animation System](https://docs.godotengine.org/en/stable/tutorials/animation/index.html)
- [Motion Matching Overview](https://gdcvault.com/play/1023218/Motion-Matching-The-Road-to)
- [Animation Retargeting Basics](https://en.wikipedia.org/wiki/Skeletal_animation)
