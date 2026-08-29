# Animation pipeline

From source `.FBX` to a clip playing on Fred.

```
Animations/<Category>/*.FBX          source, UE5 Manny rig
        │
        │  Tools/bake_retargeted.gd      (offline, ~45 s)
        ▼
Animations/Retargeted/<Category>.res  AnimationLibrary, Fred's rig
        │
        │  Scenes/FredAnimation.gd      (runtime)
        ▼
AnimationPlayer on Fred's skeleton
```

Retargeting happens **once, offline**. Nothing is retargeted at runtime.

## Source layout

Categories are top-level folders under `Animations/`. Sub-folders are recursed
and flattened into the clip name, since `/` separates library from clip in an
`AnimationPlayer` and can't appear inside a clip name.

```
Animations/
├── AimOffset/     42
├── Crouch/       213
├── Idle/          23
├── Jump/          67
├── Run/          229
├── Sprint/        44
├── Traversal/     44   (Catch/ Climb/ Hurdle/ Mantle/ Vault/)
├── Walk/         224
└── ExperimentalStateMachineData/  1
```

**887 clips total.** Every source file contains a single animation named
`"Unreal Take"`.

## Baking

```bash
godot --headless --path . --script res://Tools/bake_retargeted.gd
```

Produces one `AnimationLibrary` per category in `Animations/Retargeted/`:

| Library | Clips | Size |
| --- | --- | --- |
| `Walk.res` | 224 | 16.8 MB |
| `Crouch.res` | 213 | 13.0 MB |
| `Run.res` | 229 | 12.2 MB |
| `Jump.res` | 67 | 3.3 MB |
| `Sprint.res` | 44 | 2.0 MB |
| `Traversal.res` | 44 | — |
| `Idle.res` | 23 | 1.1 MB |
| `AimOffset.res` | 42 | 0.2 MB |
| **Total** | **887** | **~51 MB** |

Clips are sampled at **30 fps**. A key is dropped when it sits within
`ROT_EPSILON` (0.0015 rad) of both neighbours — locomotion leaves several bones
near-static, so this trims size with no visible change.

The baked libraries are **self-contained**. A fresh clone runs without the
source `.FBX` present; you only need them to re-bake.

## Root motion

Baked clips would otherwise drag Fred's mesh metres away from his collision
capsule. Instead the hip displacement is split at bake time:

- **Vertical bob** → stays on `SKEL_Pelvis_00`
- **Horizontal travel** → written to a dedicated `_rootJoint` position track

`FredAnimation` then declares that track as the mixer's root motion source:

```gdscript
anim_player.root_motion_track = NodePath("Skeleton3D:_rootJoint")
```

A track named as `root_motion_track` is **excluded from the pose**, so Fred
animates in place while the displacement stays readable via
`get_root_motion_position()`.

A dedicated root bone is used rather than pointing at the pelvis directly
because the exclusion applies to *all* transform components on that path —
aiming it at the pelvis would discard pelvis rotation too, flattening the pose.

Movement is currently code-driven (velocity → `move_and_slide`), with root
motion consumed only to keep the mesh in place. Switching to animation-driven
movement means feeding `get_root_motion_position()` into the body instead.

## Runtime loading

`FredAnimation` builds the `AnimationPlayer` itself, because **Fred.glb has
none** — it ships with a `Skeleton3D` and meshes only.

The player is created as a **sibling of the skeleton**. An `AnimationPlayer`'s
`root_node` defaults to `".."`, which then resolves to the skeleton's parent —
so the baked `"Skeleton3D:<bone>"` track paths resolve with no per-scene fixups.

Every `Retargeted/*.res` is loaded as a library named after its file, making
clips addressable as `"<Category>/<clip>"`:

```gdscript
animation.play("Walk/M_Neutral_Walk_Loop_F")
```

FBX clips import as one-shots, so `FredAnimation.play()` sets `loop_mode` per
playback — locomotion needs cycling, while jumps and traversal must play once.

## Adding animations

1. Drop `.FBX` files into a category folder under `Animations/`.
2. Let Godot import them.
3. Re-run the bake.

A new top-level folder becomes a new library automatically — no code change.
