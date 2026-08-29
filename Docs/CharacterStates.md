# Character States Implementation

## Overview

This implementation adds jumping, falling, landing, and Euphoria-style ragdoll physics to the Fred character.

## Components

### 1. CharacterStateMachine (`Scripts/Character/CharacterStateMachine.gd`)

Manages all character states:
- **IDLE** - Standing still
- **WALK** - Walking movement
- **RUN** - Running movement
- **JUMP** - Jumping (ascending)
- **FALL** - Falling (descending)
- **LAND** - Landing animation
- **RAGDOLL** - Physics ragdoll on impact
- **RECOVER** - Recovering from ragdoll

**Features:**
- Hierarchical state machine with clean transitions
- Automatic state detection based on movement and physics
- Integration with animation system
- Signals for state changes

### 2. EuphoriaRagdoll (`Scripts/Physics/EuphoriaRagdoll.gd`)

Implements NaturalMotion Euphoria engine style ragdoll:

**Features:**
- Procedural falling with air resistance
- Impact detection with velocity threshold
- Physics-based ragdoll reaction on impact
- Smooth recovery blending
- Configurable parameters:
  - `gravity_multiplier` - Adjust gravity during ragdoll
  - `air_resistance` - Air resistance during fall
  - `ragdoll_duration` - How long to stay in ragdoll after impact
  - `recovery_time` - Time to blend back to animation
  - `impact_threshold` - Minimum velocity to trigger ragdoll
  - `impact_force_multiplier` - Force multiplier on impact

**States:**
- **DISABLED** - Ragdoll system off
- **ANIMATED** - Normal animation control
- **FALLING** - Procedural falling
- **RAGDOLL** - Full physics ragdoll
- **RECOVERING** - Blending back to animation

### 3. FredController (`Scenes/FredController.gd`)

Updated to integrate with the new systems:

**New Features:**
- Jump input handling (Space key)
- Fall detection based on air time and vertical speed
- Landing detection with impact velocity
- Ragdoll triggering on significant impacts
- State-based movement control

**New Exported Properties:**
- `jump_force` - Initial jump velocity
- `jump_duration` - How long jump animation plays
- `fall_threshold` - Time in air before considered falling
- `fall_speed_threshold` - Vertical speed to trigger fall state
- `enable_ragdoll` - Enable/disable ragdoll system
- `ragdoll_duration` - How long to stay in ragdoll
- `impact_threshold` - Velocity threshold for ragdoll

## Input

Added jump action to `project.godot`:
```
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":32)]  # Space key
}
```

## Usage

### Basic Usage

The system works automatically once the scene is loaded:
1. Press **Space** to jump
2. Fall from heights to trigger fall state
3. Land with sufficient velocity to trigger ragdoll
4. Character automatically recovers after `ragdoll_duration`

### Customization

Adjust parameters in the FredController inspector:
- Tune jump force and duration
- Adjust fall thresholds
- Configure ragdoll behavior

### Script Control

You can also control states programmatically:

```gdscript
# Force a specific state
state_machine.force_state(CharacterStateMachine.State.JUMP)

# Check current state
if state_machine.is_in_ragdoll():
    print("Character is in ragdoll!")

# Check if can jump
if state_machine.can_jump():
    state_machine.force_state(CharacterStateMachine.State.JUMP)
```

## Scene Structure

Updated `Scenes/Fred.tscn` to include:
- `StateMachine` node (CharacterStateMachine)
- `EuphoriaRagdoll` node (EuphoriaRagdoll)

These nodes are children of the Fred CharacterBody3D.

## Animation

The system automatically tries to find and play animations for:
- Jump (from Jump library)
- Fall (from Fall library or any animation with "fall" or "drop" in name)
- Land (from Land library or any animation with "land" in name)

If no specific animations are found, the character will still function correctly using procedural physics.

## Euphoria Engine Style Ragdoll

The ragdoll implementation is inspired by NaturalMotion's Euphoria engine:

1. **Procedural Falling**: When the character falls, air resistance is applied to create realistic falling motion.

2. **Impact Detection**: When the character hits the ground with sufficient velocity, the ragdoll is triggered.

3. **Physics Reaction**: On impact, forces are applied based on the impact velocity and normal, causing the character to react realistically.

4. **Recovery**: After `ragdoll_duration`, the character smoothly blends back to normal animation control over `recovery_time`.

5. **Configurable**: All parameters can be tuned to achieve different styles of ragdoll behavior.

## Signals

### CharacterStateMachine Signals
- `state_changed(old_state, new_state)` - Emitted when state changes
- `jumped` - Emitted when jump starts
- `landed(impact_velocity)` - Emitted when landing
- `fell` - Emitted when falling starts
- `ragdoll_started` - Emitted when ragdoll starts
- `ragdoll_ended` - Emitted when ragdoll ends

### EuphoriaRagdoll Signals
- `ragdoll_started` - Emitted when ragdoll system activates
- `ragdoll_ended` - Emitted when ragdoll system deactivates
- `impact_detected(impact_velocity, impact_normal)` - Emitted when impact is detected

## Integration with Motion Matching

The system works alongside the existing motion matching system:
- When not in ragdoll, motion matching continues to work normally
- During ragdoll, motion matching is disabled and physics take over
- After recovery, motion matching resumes

## Testing

To test the system:
1. Run the Main.tscn scene
2. Use WASD to move
3. Press Space to jump
4. Walk off a ledge to fall
5. Land with different velocities to see ragdoll vs normal landing

## Future Enhancements

Possible improvements:
- More sophisticated bone-level physics for true ragdoll
- Better animation blending during transitions
- Support for getting up from prone position
- Dynamic balance system
- Injury system based on impact velocity
