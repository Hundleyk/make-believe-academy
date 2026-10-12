# Make-Believe Academy

A cozy institution-builder in Godot 4 (made with Godot 4.7.2). Gray boxes until M4.

## Open it
Godot Project Manager → **Import** → pick `project.godot` in this folder → **Import & Edit**. Press **F5** to play.

## Controls
- **WASD** or arrow keys: pan the camera
- **Mouse wheel**: zoom
- **Q / E**: rotate the camera

### Build mode
- **Click an item** in the Build bar (or press **1-6**) to hold it
- **Move the mouse** to aim. The check-mark badge means it fits; the cross means it doesn't (the hint box says why)
- **Left-click** to place it. You keep holding it so you can place another
- **R**: rotate the held item
- **Right-click** or **Esc**: stop holding
- **Hover a placed item**: its effect ring shows. **Click** to move it (free), **right-click** or **X** to sell it for half price
- Put a **Nightlight** near the **Story Corner Rug** to discover the Bedtime Story combo

## Where things live
- `scenes/main.tscn` is the main scene. It is nearly empty on purpose.
- `scripts/main.gd` builds the light, the grid floor, and the three rooms in code.
  Room sizes and positions are in the `ROOMS` list at the top.
- `scripts/camera_rig.gd` is the camera. Speeds and zoom limits are at the top.
- `scripts/build_mode.gd` is build mode: placing, rotating, selling, combos. Feel numbers
  (wobble, sell refund) are at the top.
- `scripts/build_hud.gd` is the placeholder HUD (Giggles, catalog bar, hints, combo popup).
- `scripts/item_visuals.gd` makes the gray shapes, rings, and check/cross badges.
- `scripts/game_state.gd` is autoloaded as `GameState`: Giggles and discovered combos.
- `data/items/*.tres` are the items (`ItemData`). Double-click one in Godot to edit cost,
  radius, effects, and tags in the Inspector. Add an item by duplicating one.
- `data/combos/*.tres` are combos (`ComboData`). They match items by tag.
- `art/` and `ui/` are empty for now (`.gitkeep` files keep them in Git).
