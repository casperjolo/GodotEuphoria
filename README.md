# GodotEuphoria

A proper NaturalMotion Euphoria Engine system in Godot 4.7+

<img width="2137" height="736" alt="image" src="https://github.com/user-attachments/assets/58469efa-9427-4944-8133-8892cdd56355" />

---

## What this is

A locomotion and physical-animation project built around **Fred**, a 27-bone
GTA/RAGE-rigged character, driven by an **887-clip Unreal Engine 5 animation
set** retargeted onto him at build time.

The two rigs share nothing — different bone names, different bone counts, and
different up axes — so the project carries its own retargeting pipeline rather
than relying on Godot's humanoid import retarget.

| | Source clips | Fred |
| --- | --- | --- |
| Rig | Unreal Engine 5 (Manny) | GTA / RAGE |
| Bones | 88 | 27 |
| Up axis | +Y | +Z |
| Naming | `pelvis`, `thigh_l`, `spine_01` | `SKEL_Pelvis_00`, `SKEL_L_Thigh_01` |

## Status

**Working**

- Full UE5 → GTA retargeting, 887/887 clips, verified against foot travel and stature
- Offline bake into 9 `AnimationLibrary` resources (~51 MB, ~45 s)
- Root motion split onto the skeleton root and consumed by the `AnimationMixer`
- WASD locomotion with a GTA-style over-the-shoulder camera

**Not yet**

- **Motion matching.** Clip selection is currently a three-way speed threshold
  (idle / walk / run). The baked set already contains the full directional
  library — `Walk_Loop_FL`, the `Box` / `Diamond` / `Hourglass` step variants,
  run→walk transitions — that a real pose-feature database would draw from.
- Foot IK — the `FootIK` node is a placeholder
- Euphoria-style physical reactions and ragdoll blending

## Requirements

- **Godot 4.7+** (developed on 4.7.2)
- Source `.FBX` animations under `Animations/` if you intend to re-bake.
  The game itself does not need them — the baked libraries are self-contained.

## Quick start

1. Open the project in Godot and let it import.
2. Run `Scenes/Main.tscn` (the configured main scene).

To re-bake after changing the retarget:

```bash
godot --headless --path . --script res://Tools/bake_retargeted.gd
```

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Move (camera-relative) |
| `Shift` | Sprint |
| Mouse | Look |
| `Esc` | Release / recapture cursor |

## Documentation

- **[Retargeting](docs/retargeting.md)** — how the UE5 → GTA transfer works and why
- **[Animation pipeline](docs/animation-pipeline.md)** — folder layout, baking, root motion
- **[Architecture](docs/architecture.md)** — scenes, scripts, and what owns what

## Licence

Project code is MIT — see [LICENSE](LICENSE).

Note that the `Animations/` source `.FBX` set and the character models carry
their own licensing terms, which are **not** granted by this project's MIT
licence. Check the terms of the pack they came from before redistributing them.
