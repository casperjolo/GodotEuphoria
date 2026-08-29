# Troubleshooting Guide

## Common Issues & Solutions

### Issue: "MotionMatcher: No AnimationPlayer found"

**Cause:** The AnimationPlayer node is not being found in the Fred.glb model hierarchy.

**Solutions:**

1. **Check Fred.glb Structure**
   - Open `NaturalMotion/Characters/Fred.glb` as a scene
   - Verify it contains:
     - `AnimationPlayer` node (somewhere in the hierarchy)
     - `Skeleton3D` node
     - At least one animation in the library
   
2. **Verify Scene Hierarchy**
   - Run the scene with the SceneDebugger enabled
   - It will print the complete scene structure
   - Look for `ANIMATION PLAYER` and `SKELETON` markers
   - Check the console output (F8) for the diagnostic report

3. **Manual Node Setup**
   - If Fred.glb doesn't have AnimationPlayer:
     - Right-click on `AnimatedTarget` in Fred.tscn
     - Select "Make Unique" to create a unique instance
     - Add an AnimationPlayer node manually
     - Load animation files into it

4. **Force Animation Assignment**
   - Open the `AnimationLoader.gd` script
   - Add this code in `_ready()`:
   ```gdscript
   # Force find AnimationPlayer in root scene
   anim_player = get_tree().root.find_child("AnimationPlayer", true, false)
   ```

---

### Issue: "Retargeter: No target skeleton found"

**Cause:** The Skeleton3D node is not accessible from Retargeter.

**Solutions:**

1. **Verify Skeleton Exists**
   - Open Fred.glb in the editor
   - Check that it has a `Skeleton3D` node
   - Verify it has multiple bones (should show in tree)

2. **Check Scene Structure**
   - Run the scene
   - Look at the console diagnostic output
   - Verify `Skeleton3D` shows `✓ FOUND`
   - Check the bone count (should be > 0)

3. **Manual Skeleton Assignment**
   - Edit `Scenes/Fred.tscn`
   - Add this to the Retargeter node:
   ```gdscript
   @onready var target_skeleton = %Skeleton3D  # Using unique name
   ```

---

### Issue: No Animations Loading

**Cause:** FBX files aren't imported by Godot, or AnimationPlayer is empty.

**Solutions:**

1. **Ensure FBX Files are in Project**
   - Move FBX files to `res://Animations/` folders
   - Example: `res://Animations/Walk/M_Neutral_Walk.fbx`
   - Files MUST be in `res://` (project root), not elsewhere

2. **Force Godot to Import FBX**
   - Go to `Project > Tools > Reimport`
   - Wait for import to complete
   - Check if FBX files appear in FileSystem panel
   - They should show as `.fbx.tres` or similar

3. **Check AnimationPlayer Library**
   - Open Fred.glb in the editor
   - Select the AnimationPlayer node
   - Check the "Anim" section in Inspector
   - Should show loaded animations in the library
   - If empty, FBX files haven't been imported

4. **Add Test Animation Manually**
   - Create a simple animation in AnimationPlayer
   - Use `AnimationLibrary > Add` in Inspector
   - Add a test animation with a few keyframes
   - This verifies AnimationPlayer is working

---

### Issue: Fred Not Moving / No Response to Input

**Cause:** Multiple possibilities - check in order:

1. **Verify Input System**
   ```gdscript
   # Add debug code to FredController._process()
   if Input.is_action_just_pressed("ui_up"):
       print("Input detected!")
   ```

2. **Check Motion Matcher Status**
   - Press `M` key to enable debug output
   - Should print motion matcher info each frame
   - If nothing prints, MotionMatcher not running

3. **Verify Character Body**
   - Fred should be a `CharacterBody3D` node
   - Should have a `CollisionShape3D` child
   - Collision layer should be 2

4. **Check Physics**
   - Verify Godot physics is enabled
   - Character should have gravity applied
   - Check collision layer/mask settings

---

### Issue: Jerky or No Animation Blending

**Cause:** Animation database not built or features not extracted.

**Solutions:**

1. **Build Database Manually**
   - In console, run:
   ```gdscript
   var motion_matcher = get_node("Fred/MotionMatcher")
   motion_matcher.build_database_from_animations()
   print("Database built!")
   ```

2. **Check Database Status**
   - Add debug print in MotionMatcher._process():
   ```gdscript
   print("Database has %d animations" % motion_database.motion_features.size())
   ```

3. **Verify Animations Loaded**
   - Press `R` key to reload animations
   - Check console output
   - Should show number of animations loaded

4. **Check Animation Duration**
   - Animations must have minimum length
   - Invalid/empty animations cause issues
   - Verify in AnimationPlayer inspector

---

## Diagnostic Steps

### Step 1: Check Scene Structure
```
Run Fred.tscn (F5)
↓
Look at console output for "SCENE STRUCTURE DIAGNOSTIC"
↓
Verify all nodes are found with ✓ marks
```

### Step 2: Check Components
```
Console should show:
✓ MotionMatcher
✓ AnimationLoader
✓ Retargeter
✓ AnimatedTarget
  ✓ AnimationPlayer
  ✓ Skeleton3D
    ✓ Bones (should show count)
```

### Step 3: Check Animations
```
Console should show:
✓ Found N animations

If it shows ✗ or 0 animations:
→ Check Animations/ folder structure
→ Run Project > Tools > Reimport
→ Verify FBX files are in res://Animations/
```

### Step 4: Test Motion Matching
```
Press M in-game to enable debug
↓
Should see output: "Motion Matcher - Animation: ..., Frame: ..., Type: ..."
↓
Press WASD - should see animation names change
```

---

## Console Output Reference

### Good Output
```
✓ MotionMatcher
✓ AnimationLoader  
✓ Retargeter
✓ AnimatedTarget
  ✓ AnimationPlayer
  ✓ Skeleton3D
    ✓ Bones (78 bones)
✓ Found 1250 animations
MotionMatcher: Built database with 1250 animations
```

### Problem Output
```
✗ AnimationPlayer     ← AnimationPlayer not found!
✗ Skeleton3D         ← Skeleton not found!
✗ Found 0 animations ← No animations loaded!
```

---

## Manual Fix Procedures

### If AnimationPlayer Missing
1. Open Fred.glb as scene
2. Right-click on root node
3. Create new Node → AnimationPlayer
4. Import/add animations to it
5. Save Fred.glb

### If Skeleton Not Found
1. Check Fred.glb structure
2. Ensure there's a Skeleton3D node
3. Verify it's not nested under a Node without proper inheritance
4. May need to re-export the model

### If No Animations
1. Place FBX files in `res://Animations/Idle/`, `res://Animations/Walk/`, etc.
2. In Godot: `Project > Tools > Reimport`
3. Wait for import to complete
4. Verify FBX.tres files appear in file system
5. Drag them into AnimationPlayer in Fred.glb

---

## Advanced Debugging

### Enable Full Debug Output
Edit `MotionMatcher.gd`:
```gdscript
@export var enable_debug: bool = true  # Set to true for verbose output
```

### Check Bone Mapping
Add to BoneMapping.gd:
```gdscript
func debug_print_mappings() -> void:
    print("Bone Mappings:")
    for source in source_to_target_map:
        var target_idx = source_to_target_map[source]
        var target_name = target_bones.keys()[target_idx] if target_idx < target_bones.size() else "UNKNOWN"
        print("  %s → %s (bone %d)" % [source, target_name, target_idx])
```

### Log All Animations
Add to AnimationLoader._ready():
```gdscript
for anim_name in get_loaded_animations():
    var meta = get_animation_metadata(anim_name)
    print("Animation: %s (type: %s, length: %.2f)" % [
        anim_name, meta["type"], meta["length"]
    ])
```

---

## Getting Help

1. **Read the Logs**
   - Open console (F8)
   - Look for error/warning messages
   - They often point directly to the problem

2. **Run Diagnostic**
   - Press Play to run scene
   - Note what's working/not working
   - Check each ✓/✗ in the diagnostic output

3. **Check File Structure**
   - Ensure `Animations/` folder exists
   - Verify subfolders: Idle/, Walk/, Run/, Sprint/
   - Check FBX files are there (not in subfolders of subfolders)

4. **Verify Scene Setup**
   - Open `Scenes/Fred.tscn`
   - Expand AnimatedTarget node
   - Should see AnimationPlayer and Skeleton3D nodes
   - If missing, you need to set up Fred.glb properly

---

## Quick Reference

| Issue | Check | Fix |
|-------|-------|-----|
| No AnimationPlayer | Console diagnostic | Verify Fred.glb structure |
| No Skeleton | Console diagnostic | Check Fred.glb has Skeleton3D |
| No Animations | Console shows 0 | Reimport FBX files |
| No Movement | Try pressing WASD | Check input mapping |
| Jerky Animation | Press M for debug | Build database, check frame rate |
| Fred Floating | Check physics | Verify gravity and collision |

---

## Still Not Working?

1. **Save and Reload**
   - Save scene: Ctrl+S
   - Restart Godot
   - Reimport: Project > Tools > Reimport

2. **Check Project Structure**
   - Verify project.godot exists
   - All paths use `res://`
   - No spaces in critical paths

3. **Verify Godot Version**
   - Project requires Godot 4.7
   - Check: About > Godot Engine
   - May not work on 4.6 or earlier

4. **Create Fresh Fred Instance**
   - Create new scene
   - Add Fred.glb as node
   - Add AnimationPlayer if missing
   - Export/save as new scene
   - Test with that

5. **Check System Requirements**
   - Sufficient disk space for imported assets
   - No permission issues on folders
   - File encoding is UTF-8

If still stuck, the SceneDebugger output will show exactly what's found/missing!
