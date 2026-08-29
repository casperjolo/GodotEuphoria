# Architecture

## Scene structure

`Scenes/Fred.tscn`:

```
Fred (CharacterBody3D)          ← FredController.gd
├── DriverShape (CollisionShape3D)   capsule, base at origin
├── HipMarker (Marker3D)
├── AnimatedTarget (Fred.glb)        offset +0.9882 on Y
│   └── … └── Skeleton3D             27 bones, Z-up
│           └── AnimationPlayer      created at runtime
├── FredAnimation (Node)        ← FredAnimation.gd
├── FredMaterial (Node)         ← FredMaterial.gd
├── FootIK (Node)                    placeholder
└── CameraRig (Node3D)               top_level, driven by FredController
    └── ShoulderPivot (Node3D)       lateral offset
        └── SpringArm3D
            └── Camera3D
```

### Why `AnimatedTarget` is offset +0.9882

Fred's lowest bone sits 0.988 m below the character origin, while the collision
capsule's base is *at* the origin. Without the offset he stands buried to the
waist.

### Why `CameraRig` is `top_level`

The rig is a child of Fred for tidiness, but must not inherit his yaw: Fred
turns to face his direction of travel, and that direction is derived from the
camera's basis. Left as a normal child, the two feed back into each other and he
spins on the spot when strafing.

### Why the shoulder offset is on the pivot

`ShoulderPivot` shifts the **whole orbit** right, not just the camera. That
keeps Fred framed left of centre while you look straight ahead. Offsetting only
the `Camera3D` would swing him back toward centre as you turn.

## Scripts

| Script | Responsibility |
| --- | --- |
| [`Scenes/FredController.gd`](../Scenes/FredController.gd) | Input, movement, camera, clip selection |
| [`Scenes/FredAnimation.gd`](../Scenes/FredAnimation.gd) | Builds the `AnimationPlayer`, loads libraries, root motion |
| [`Scenes/FredMaterial.gd`](../Scenes/FredMaterial.gd) | Recolours the body meshes |
| [`Tools/retarget_lib.gd`](../Tools/retarget_lib.gd) | Retargeting maths — see [retargeting](retargeting.md) |
| [`Tools/bake_retargeted.gd`](../Tools/bake_retargeted.gd) | Offline bake driver |
| [`Tools/measure_placement.gd`](../Tools/measure_placement.gd) | Diagnostic: rig axes, ground offset, facing |
| [`Tools/dump_rig.gd`](../Tools/dump_rig.gd) | Diagnostic: bone names and track paths |

### FredController

Movement is camera-relative. The camera's forward and right vectors are
flattened to the ground plane and **re-normalised** — pitching the camera
shortens the forward vector, which otherwise biases diagonal input toward
strafing.

Facing uses `atan2(-dir.x, -dir.z)`, because Fred's mesh looks down −Z like a
Godot node does. See the note in [retargeting](retargeting.md#deriving-c-the-space-change).

The spring arm's `collision_mask` is set to layer 1 only. Fred is on layer 2 —
leaving him in the mask makes the camera collide with its own character and snap
into his back.

Clip selection resolves through name hints at startup, so a renamed or missing
clip degrades to something playable rather than silence.

### FredMaterial

Duplicates the mesh's **existing imported material** and overrides only
`albedo_color`. Assigning a material built from scratch resets cull mode,
shading mode and specular to engine defaults — which shows backfaces through the
model and turns the shading black.

## Superseded scripts

`Scenes/` still contains an earlier motion-matching attempt —
`MotionMatcher.gd`, `MotionDatabase.gd`, `MotionFeature.gd`, `BoneMapping.gd`,
`Retargeter.gd`, `AnimationLoader.gd`, `FBXAnimationImporter.gd`,
`MotionMatcherInitializer.gd`, `SceneDebugger.gd`.

**None are wired into any scene.** They were written against wrong assumptions
(Mixamo bone names; an `AnimationPlayer` inside Fred.glb) and the matcher scanned
every frame of every clip each rendered frame. Kept only as reference for the
rewrite; delete freely.

## What's next

Motion matching. Clip choice in `FredController._update_clip()` is a three-way
speed threshold — that method is the seam a real matcher replaces.

A working implementation needs:

1. **A pose-feature database** built offline — per-frame trajectory, foot
   positions and velocities, contact state.
2. **An acceleration structure.** 887 clips × ~120 frames is ~100k poses; a
   linear scan per frame is not viable.
3. **Inertialisation** for blending between matched poses.

The baked set already contains the directional coverage this needs —
`Walk_Loop_FL` / `FR` / `LL` / `LR`, the `Box` / `Diamond` / `Hourglass` step
variants, and the run→walk transitions.
