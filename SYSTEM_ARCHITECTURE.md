# Motion Matching System Architecture

## Complete System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GODOT GAME ENGINE (4.7)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         FRED CHARACTER SCENE                          │  │
│  │                       (Scenes/Fred.tscn)                            │  │
│  ├──────────────────────────────────────────────────────────────────────┤  │
│  │                                                                      │  │
│  │  ┌─ INPUT LAYER ────────────────────────────────────────────────┐  │  │
│  │  │                                                              │  │  │
│  │  │  ┌──────────────────┐      ┌──────────────────────────┐   │  │  │
│  │  │  │ FredController   │      │  Player Input (WASD)     │   │  │  │
│  │  │  │                  │ ←─── │  Keyboard/Gamepad Input  │   │  │  │
│  │  │  │ • Input capture  │      └──────────────────────────┘   │  │  │
│  │  │  │ • Movement calc  │                                     │  │  │
│  │  │  │ • Heading update │                                     │  │  │
│  │  │  └──────────────────┘                                     │  │  │
│  │  │         │                                                  │  │  │
│  │  └─────────┼──────────────────────────────────────────────────┘  │  │
│  │            │                                                      │  │
│  │            ↓                                                      │  │
│  │  ┌─ MOTION MATCHING LAYER ──────────────────────────────────┐  │  │
│  │  │                                                           │  │  │
│  │  │  ┌──────────────────────┐   ┌────────────────────────┐  │  │  │
│  │  │  │  MotionMatcher       │   │  MotionDatabase        │  │  │  │
│  │  │  │                      │───│                        │  │  │  │
│  │  │  │ • Query database     │   │ • Store features      │  │  │  │
│  │  │  │ • Find best match    │   │ • Index by type       │  │  │  │
│  │  │  │ • Manage transitions │   │ • Fast queries        │  │  │  │
│  │  │  └──────────────────────┘   └────────────────────────┘  │  │  │
│  │  │                                                           │  │  │
│  │  │  ┌──────────────────────────────────────────────────┐   │  │  │
│  │  │  │  MotionFeature (Data Structure)                 │   │  │  │
│  │  │  │  ┌────────────────────────────────────────────┐ │   │  │  │
│  │  │  │  │ • Root position & velocity                 │ │   │  │  │
│  │  │  │  │ • Joint positions (feet, hands)            │ │   │  │  │
│  │  │  │  │ • Foot contact state                       │ │   │  │  │
│  │  │  │  │ • Heading & direction                      │ │   │  │  │
│  │  │  │  │ • Locomotion type tag                      │ │   │  │  │
│  │  │  │  │ • Distance metric for matching             │ │   │  │  │
│  │  │  └────────────────────────────────────────────────┘ │   │  │  │
│  │  │                                                           │  │  │
│  │  │  ┌──────────────────────────────────────────────────┐   │  │  │
│  │  │  │  Distance Metric Formula                        │   │  │  │
│  │  │  │  ┌────────────────────────────────────────────┐ │   │  │  │
│  │  │  │  │ distance =                                  │ │   │  │  │
│  │  │  │  │   |root_pos_delta|      * 1.0 +            │ │   │  │  │
│  │  │  │  │   |velocity_delta|      * 2.0 +  ← important│ │   │  │  │
│  │  │  │  │   |foot_pos_delta|      * 0.5 +            │ │   │  │  │
│  │  │  │  │   |foot_contact_delta|  * 1.5 +            │ │   │  │  │
│  │  │  │  │   |heading_delta|       * 1.0               │ │   │  │  │
│  │  │  │  └────────────────────────────────────────────┘ │   │  │  │
│  │  │  │                                                    │   │  │  │
│  │  │  └──────────────────────────────────────────────────┘   │  │  │
│  │  │                                                           │  │  │
│  │  └───────────────────────────────────────────────────────────┘  │  │
│  │                            │                                    │  │
│  │                            ↓                                    │  │
│  │  ┌─ RETARGETING LAYER ──────────────────────────────────┐     │  │
│  │  │                                                      │     │  │
│  │  │  ┌──────────────────┐     ┌────────────────────┐   │     │  │
│  │  │  │ AnimationLoader  │     │ BoneMapping        │   │     │  │
│  │  │  │                  │     │                    │   │     │  │
│  │  │  │ • Load from      │     │ • Map source bones │   │     │  │
│  │  │  │   AnimationPlayer│──→  │   to target bones  │   │     │  │
│  │  │  │ • Categorize     │     │ • Auto-detect      │   │     │  │
│  │  │  │ • Extract frames │     │   bone names       │   │     │  │
│  │  │  └──────────────────┘     └────────────────────┘   │     │  │
│  │  │                                                      │     │  │
│  │  │  ┌──────────────────────────────────────────┐      │     │  │
│  │  │  │  Retargeter                              │      │     │  │
│  │  │  │                                          │      │     │  │
│  │  │  │ • Apply animation pose                  │      │     │  │
│  │  │  │ • Map animation bones to Fred skeleton  │      │     │  │
│  │  │  │ • Update transforms (rotation, pos)     │      │     │  │
│  │  │  │ • Cache poses for performance           │      │     │  │
│  │  │  └──────────────────────────────────────────┘      │     │  │
│  │  │                                                      │     │  │
│  │  └──────────────────────────────────────────────────────┘     │  │
│  │                            │                                  │  │
│  │                            ↓                                  │  │
│  │  ┌─ RENDERING LAYER ────────────────────────────────────┐   │  │
│  │  │                                                      │   │  │
│  │  │  ┌──────────────────────────────────────────┐       │   │  │
│  │  │  │ AnimatedTarget (Fred.glb)                │       │   │  │
│  │  │  │                                          │       │   │  │
│  │  │  │ ┌──────────────────────────────────────┐ │       │   │  │
│  │  │  │ │ Skeleton3D                           │ │       │   │  │
│  │  │  │ │ • Hips, Spine, Chest...             │ │       │   │  │
│  │  │  │ │ • LeftLeg, RightLeg                 │ │       │   │  │
│  │  │  │ │ • LeftArm, RightArm                 │ │       │   │  │
│  │  │  │ │ • Head, Neck                        │ │       │   │  │
│  │  │  │ └──────────────────────────────────────┘ │       │   │  │
│  │  │  │                                          │       │   │  │
│  │  │  │ ┌──────────────────────────────────────┐ │       │   │  │
│  │  │  │ │ Mesh/Material                        │ │       │   │  │
│  │  │  │ │ • Fred's 3D model                    │ │       │   │  │
│  │  │  │ │ • Textures, skin, clothing           │ │       │   │  │
│  │  │  │ └──────────────────────────────────────┘ │       │   │  │
│  │  │  └──────────────────────────────────────────┘       │   │  │
│  │  │                                                      │   │  │
│  │  │  ┌──────────────────────────────────────────┐       │   │  │
│  │  │  │ Support Systems                         │       │   │  │
│  │  │  │                                          │       │   │  │
│  │  │  │ • RootMotionNeutraliser                │       │   │  │
│  │  │  │   (handles animation root motion)      │       │   │  │
│  │  │  │                                          │       │   │  │
│  │  │  │ • FootIK (placeholder for future)       │       │   │  │
│  │  │  │   (foot inverse kinematics)             │       │   │  │
│  │  │  │                                          │       │   │  │
│  │  │  │ • CameraRig                             │       │   │  │
│  │  │  │   (third-person camera follow)          │       │   │  │
│  │  │  └──────────────────────────────────────────┘       │   │  │
│  │  │                                                      │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─ INITIALIZATION ──────────────────────────────────────────┐     │
│  │                                                           │     │
│  │  MotionMatcherInitializer                               │     │
│  │  • Load animations at startup                           │     │
│  │  • Build motion database                                │     │
│  │  • Verify all systems ready                             │     │
│  │                                                           │     │
│  └───────────────────────────────────────────────────────────┘     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
                          RUNTIME FRAME
                          │
         ┌────────────────┴────────────────┐
         │                                 │
    Input Events                      Time Delta
    (WASD keys)                       (delta_time)
         │                                 │
         └────────────────┬────────────────┘
                          │
                          ↓
                    ┌─────────────┐
                    │FredController│
                    └─────────────┘
                         │ Process input
                         │ Calculate velocity
                         │ Update heading
                         │
                         ↓
              ┌──────────────────────────┐
              │ Desired Motion State     │
              ├──────────────────────────┤
              │ • velocity               │
              │ • heading                │
              │ • direction              │
              │ • locomotion_type        │
              └──────────────────────────┘
                         │
                         ↓
                  ┌────────────────┐
                  │MotionMatcher   │
                  │set_desired_    │
                  │motion()        │
                  └────────────────┘
                         │
                         ↓
        ┌────────────────────────────────┐
        │ Query MotionDatabase           │
        │ for best matching animation    │
        └────────────────────────────────┘
                         │
                         ↓
    ┌──────────────────────────────────────┐
    │ MotionDatabase.find_best_match()     │
    │                                      │
    │ For each animation:                 │
    │   For each frame:                   │
    │     Calculate distance_metric()     │
    │                                      │
    │ Sort by distance                    │
    │ Return top N matches                │
    └──────────────────────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────┐
        │ Best Match Found               │
        ├────────────────────────────────┤
        │ • animation_name               │
        │ • frame_number                 │
        │ • distance_score               │
        └────────────────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────┐
        │ Transition to Animation        │
        │ (if different from current)    │
        └────────────────────────────────┘
                         │
                         ↓
    ┌──────────────────────────────────────┐
    │ Retargeter.apply_animation_pose()    │
    │                                      │
    │ For each bone in animation:         │
    │   1. Get source animation bone      │
    │   2. Look up target bone via        │
    │      BoneMapping                    │
    │   3. Get transform from animation  │
    │   4. Apply to Fred's skeleton      │
    └──────────────────────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────┐
        │ Fred's Skeleton Updated        │
        │ • All bones have new poses     │
        └────────────────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────┐
        │ Godot Rendering                │
        │ • Skeleton drives mesh         │
        │ • Display Fred on screen       │
        │ • Camera follows Fred          │
        └────────────────────────────────┘
                         │
                         ↓
                   ┌──────────┐
                   │  FRAME   │
                   │ RENDERED │
                   └──────────┘
```

## Component Interaction

```
                          Fred Scene
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
    FredController      MotionMatcher         AnimationLoader
        │                      │                      │
        │ Input               │ Query               │ Load
        │ Velocity            │ Database            │ Categorize
        │                     │                     │
        └──────────────────────┼──────────────────────┘
                               │
                        MotionDatabase
                               │
                    (stores all features)
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
     Retargeter         BoneMapping          FootIK (future)
        │                      │                      │
        │ Apply         Map bones               Ground
        │ Transforms           │                contact
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                        AnimatedTarget
                       (Fred.glb model)
                               │
                        ┌──────┴──────┐
                        │             │
                    Skeleton3D      MeshInstance3D
                    (bone poses)    (visual)
```

## Animation Matching Algorithm (Detailed)

```
MOTION MATCHING ALGORITHM

Input: desired_motion = {velocity, heading, direction, type}
Output: best_matching_frame

┌─────────────────────────────────────────────────────┐
│ 1. Create Query Feature                             │
│    from desired_motion                              │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────┐
│ 2. Filter by Locomotion Type                        │
│    Only search Walk/Run/Sprint animations           │
│    if querying for "walk"                           │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────┐
│ 3. For Each Animation in Database                   │
│    For Each Frame in Animation                      │
│                                                     │
│      distance = query_feature.distance_to(         │
│                   frame_feature,                   │
│                   weights)                         │
│                                                     │
│      candidates[] += {                             │
│        feature: frame_feature,                     │
│        distance: distance,                         │
│        animation: anim_name,                       │
│        frame: frame_num                            │
│      }                                              │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────┐
│ 4. Sort Candidates                                  │
│    candidates.sort_by(distance)                     │
│    (ascending = best matches first)                 │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────┐
│ 5. Return Top N Results                             │
│    default N = 1 (just best match)                  │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
                    ┌──────────┐
                    │Best Match│
                    │Animation │
                    │ + Frame  │
                    └──────────┘
```

## File Dependencies

```
Fred.tscn
  ├── MotionMatcher.gd
  │   ├── MotionDatabase.gd
  │   ├── MotionFeature.gd
  │   └── AnimationPlayer (from Fred.glb)
  │
  ├── AnimationLoader.gd
  │   └── AnimationPlayer (from Fred.glb)
  │
  ├── Retargeter.gd
  │   ├── BoneMapping.gd
  │   └── Skeleton3D (from Fred.glb)
  │
  ├── FredController.gd
  │   ├── MotionMatcher.gd
  │   └── CharacterBody3D
  │
  ├── MotionMatcherInitializer.gd
  │   ├── MotionMatcher.gd
  │   ├── AnimationLoader.gd
  │   └── Retargeter.gd
  │
  └── AnimatedTarget (Fred.glb)
      ├── AnimationPlayer
      ├── Skeleton3D
      └── MeshInstance3D
```

## Performance Model

```
INITIALIZATION PHASE (once at startup)
├─ Load animations: ~500ms
├─ Extract features from all frames: ~1000ms
└─ Build database: ~500ms
  Total: ~2 seconds

RUNTIME PHASE (per frame @ 60 FPS)
├─ Process input: <1ms
├─ Query database: O(n) where n = total frames
│  └─ For 1000 animations × 100 frames each:
│     Worst case: ~100,000 distance calculations
│     → ~16ms (within 60 FPS budget)
├─ Retarget animation: ~2ms
└─ Render: ~10ms
  Total: ~28ms (leaves ~5ms buffer at 60 FPS)

MEMORY
├─ Motion database: ~5-10MB per 1000 animations
├─ Cached poses: ~1-2MB
└─ Animation resources: varies by animation complexity
  Total: ~20-30MB typical
```
