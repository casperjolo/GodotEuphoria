# Changes Made for Jumping, Falling, and Ragdoll System

## New Files Created

### Scripts
1. **`Scripts/Character/CharacterStateMachine.gd`**
   - Complete state machine for character states
   - Manages: IDLE, WALK, RUN, JUMP, FALL, LAND, RAGDOLL, RECOVER
   - Handles state transitions automatically
   - Integrates with EuphoriaRagdoll
   - Emits signals for state changes

2. **`Scripts/Physics/EuphoriaRagdoll.gd`**
   - NaturalMotion Euphoria engine style ragdoll
   - Procedural falling with air resistance
   - Impact detection and physics reaction
   - Smooth recovery blending
   - Configurable parameters

### Documentation
1. **`Docs/CharacterStates.md`**
   - Complete documentation of the system
   - Usage instructions
   - Customization guide
   - Signal reference

2. **`Tests/test_character_states.gd`**
   - Test script to verify functionality
   - Signal monitoring
   - Manual test triggers

## Modified Files

### `project.godot`
- Added `jump` input action mapped to Space key (physical_keycode: 32)

### `Scenes/Fred.tscn`
- Added `StateMachine` node with CharacterStateMachine script
- Added `EuphoriaRagdoll` node with EuphoriaRagdoll script
- Added resource references for both new scripts

### `Scenes/FredController.gd`
- Added new exported properties:
  - Jump settings: `jump_force`, `jump_duration`
  - Fall settings: `fall_threshold`, `fall_speed_threshold`
  - Ragdoll settings: `enable_ragdoll`, `ragdoll_duration`, `impact_threshold`
- Added state tracking variables
- Added references to StateMachine and EuphoriaRagdoll nodes
- Updated `_ready()` to initialize state machine and ragdoll
- Updated `_physics_process()` to:
  - Update state machine each frame
  - Handle jump input
  - Detect landing and impact
  - Apply state-based movement control
  - Call ragdoll physics updates
- Added fall timer and ground tracking
- Added ragdoll integration

## Features Implemented

### Jumping
- Press Space to jump
- Configurable jump force and duration
- Jump animation support (if available)
- Smooth transition to fall state when descending

### Falling
- Automatic detection based on:
  - Time in air (`fall_threshold`)
  - Vertical speed (`fall_speed_threshold`)
- Procedural falling with air resistance
- Fall animation support (if available)
- Smooth transition to landing or ragdoll

### Landing
- Impact velocity detection
- Landing animation support (if available)
- Automatic transition to appropriate state based on impact

### Ragdoll (Euphoria Engine Style)
- Physics-based ragdoll on impact
- Configurable impact threshold
- Impact force application based on velocity and normal
- Ragdoll duration control
- Smooth recovery blending
- Signals for ragdoll start/end and impact detection

### State Machine
- Clean hierarchical state management
- Automatic state transitions
- Manual state forcing capability
- Integration with animation system
- Signals for all state changes

## How It Works

1. **Normal Movement**: Character moves using standard locomotion
2. **Jump**: Space key triggers JUMP state, applies upward velocity
3. **Fall Detection**: If in air for too long or falling too fast, enters FALL state
4. **Landing**: On ground contact, checks impact velocity
5. **Ragdoll Decision**: If impact velocity > threshold, triggers RAGDOLL state
6. **Ragdoll Physics**: Applies physics forces, disables normal movement
7. **Recovery**: After duration, blends back to normal control

## Configuration

All parameters are configurable in the FredController inspector:
- **Jump**: Force, duration
- **Fall**: Threshold time, speed threshold
- **Ragdoll**: Enable/disable, duration, impact threshold

## Testing

To test:
1. Run the Main.tscn scene
2. Use WASD to move
3. Press Space to jump
4. Walk off ledges to fall
5. Land with different velocities

Expected behavior:
- Small jumps: Normal jump and land
- High falls: Fall state with procedural physics
- Hard landings: Ragdoll on impact, then recovery

## Integration

The system integrates with:
- Existing motion matching (disabled during ragdoll)
- Animation system (plays appropriate animations)
- Input system (new jump action)
- Physics system (CharacterBody3D)

## Backward Compatibility

- All existing functionality remains intact
- Motion matching continues to work when not in ragdoll
- Can be disabled by setting `enable_ragdoll = false`
