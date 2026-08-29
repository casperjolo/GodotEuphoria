# Retargeting

How an 887-clip Unreal Engine 5 animation set is transferred onto Fred's
GTA/RAGE skeleton.

All of this lives in [`Tools/retarget_lib.gd`](../Tools/retarget_lib.gd).

## The problem

The source clips and the target character share nothing useful:

| | Source (UE5 "Manny") | Target (Fred, GTA/RAGE) |
| --- | --- | --- |
| Bone count | 88 | 27 |
| Root | `root` | `_rootJoint` |
| Hips | `pelvis` | `SKEL_Pelvis_00` |
| Spine | `spine_01` … `spine_05` (5) | `SKEL_Spine_Root_07` … `SKEL_Spine3_010` (4) |
| Up axis | **+Y** | **+Z** |
| Extras | fingers, twist bones, IK bones | none |
| Clip name | `"Unreal Take"` (every file) | — |

Fred.glb also ships **without an AnimationPlayer** — it contains a `Skeleton3D`
and meshes only.

Copying local bone rotations across would produce nonsense: the rigs have
different rest poses, different bone axes, and different up vectors.

## The approach

A **rest-pose-relative** retarget. For each mapped bone, per frame:

1. Compute the source bone's pose in **model space** by walking the hierarchy.
2. Measure its **deviation from its own rest pose**:
   `deviation = pose · rest⁻¹`
3. Rotate that deviation from source space into target space: `C · deviation · C⁻¹`
4. Re-apply it over the target's rest orientation: `target = (C · deviation · C⁻¹) · target_rest`
5. Convert model space back to parent-local for the output track.

Working from each rig's *own* rest pose is what lets two skeletons with
different proportions and bone axes agree. Only the deviation transfers — never
raw orientations.

### Deriving `C`, the space change

`C` is not hardcoded. It's derived from the two rest poses, so the pipeline
handles any pair of rigs:

```
up   = normalize(head_position - hips_position)
side = normalize(right_thigh_position - left_thigh_position)
fwd  = normalize(side × up)
side = normalize(up × fwd)          # re-orthogonalise
basis = Basis(side, up, fwd)

C = target_basis · source_basis⁻¹
```

For this pair, `C` works out to the Y-up → Z-up rotation. Measured values:

```
source up axis = (0.000, 0.9999, -0.017)   # +Y
target up axis = (0.000, 0.006,   0.9999)  # +Z
source leg len = 0.851
target leg len = 0.832
```

> Careful: `side × up` yields the character's **back**, not its front. Fred's
> mesh faces **−Z**, matching Godot's own node-forward convention — which is why
> `FredController` uses `atan2(-d.x, -d.z)` to face him along his travel
> direction. The `atan2(d.x, d.z)` form is for +Z-facing meshes and turns a
> character a full 180°.

## Bone map

23 pairs. Fingers, twist bones and IK bones are dropped — Fred has no equivalents.

| UE5 | Fred |
| --- | --- |
| `pelvis` | `SKEL_Pelvis_00` |
| `spine_01` | `SKEL_Spine_Root_07` |
| `spine_02` | `SKEL_Spine1_08` |
| `spine_03` | `SKEL_Spine2_09` |
| `spine_05` | `SKEL_Spine3_010` |
| `neck_01` | `SKEL_Neck_1_019` |
| `head` | `SKEL_Head_020` |
| `clavicle_l` / `_r` | `SKEL_L_Clavicle_011` / `SKEL_R_Clavicle_015` |
| `upperarm_l` / `_r` | `SKEL_L_UpperArm_012` / `SKEL_R_UpperArm_016` |
| `lowerarm_l` / `_r` | `SKEL_L_Forearm_013` / `SKEL_R_Forearm_017` |
| `hand_l` / `_r` | `SKEL_L_Hand_014` / `SKEL_R_Hand_018` |
| `thigh_l` / `_r` | `SKEL_L_Thigh_01` / `SKEL_R_Thigh_04` |
| `calf_l` / `_r` | `SKEL_L_Calf_02` / `SKEL_R_Calf_05` |
| `foot_l` / `_r` | `SKEL_L_Foot_03` / `SKEL_R_Foot_06` |
| `ball_l` / `_r` | `SKEL_L_Foot_end_021` / `SKEL_R_Foot_end_022` |

**`spine_04` is intentionally unmapped.** UE5 has five spine bones to Fred's
four, and the clavicles and neck hang off `spine_05` in the source but off
`SKEL_Spine3_010` in Fred. Mapping `spine_05 → Spine3` preserves the correct
shoulder parent; `spine_04`'s rotation is small in locomotion and is dropped.

Unmapped intermediate bones keep their rest orientation. When converting model
space to parent-local, the code walks up until it finds a bone that was actually
animated (`_nearest_mapped_parent_rot`), so gaps in the map don't corrupt the
chain.

## Hip translation

The hips carry the character through the world. That displacement is:

1. Rotated into target space by `C`
2. Scaled by the leg-length ratio, so a taller rig's stride doesn't overshoot
3. **Split** — the component along the target's up axis (the vertical bob) stays
   on the pelvis; everything else moves to `_rootJoint`

That split is what makes root motion work. See
[animation pipeline](animation-pipeline.md#root-motion).

## Changing the map

Edit `BONE_MAP` in [`Tools/retarget_lib.gd`](../Tools/retarget_lib.gd), then
re-bake:

```bash
godot --headless --path . --script res://Tools/bake_retargeted.gd
```

To inspect either rig's bone names, axes, or ground offset:

```bash
godot --headless --path . --script res://Tools/measure_placement.gd
```
