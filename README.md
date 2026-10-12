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

### Students
- Three students (Pip, Drizzle, Bo) walk around on their own. The **Students** panel (top left) shows
  their Calm, Fun, and Rest (0-10) and what each one is doing
- Needs change once per **period** (every 20 seconds for now; the day clock arrives in week 4).
  Each student walks to the item that best helps their lowest need. An item serves 2 students at once
- Below 3, a **mood icon** pops up: a shaky face (Calm), a frown (Fun), or a yawn (Rest)
- At 0 they act it out for one period: **hide** under a blanket (Calm), **wander** off to a toy (Fun),
  or **nap** where they stand (Rest)
- **Hover a student** to see their needs and why they changed. While hovering, **C**, **F**, or **Z**
  empties Calm, Fun, or Rest so you can see an act-out right away (a test shortcut)

## Where things live
- `scenes/main.tscn` is the main scene. It is nearly empty on purpose.
- `scripts/main.gd` builds the light, the grid floor, and the three rooms in code.
  Room sizes and positions are in the `ROOMS` list at the top.
- `scripts/camera_rig.gd` is the camera. Speeds and zoom limits are at the top.
- `scripts/build_mode.gd` is build mode: placing, rotating, selling, combos. Feel numbers
  (wobble, sell refund) are at the top.
- `scripts/build_hud.gd` is the placeholder HUD (Giggles, catalog bar, hints, combo popup).
- `scripts/item_visuals.gd` makes the gray shapes, rings, and check/cross badges.
- `scripts/students.gd` runs the students: periods, choosing items, act-outs, and the navigation
  mesh (re-baked whenever an item is placed, moved, or sold). Tuning numbers are at the top.
- `scripts/student.gd` is one student: needs, walking, hopping, act-outs, hover text.
- `scripts/student_visuals.gd` makes the capsules, blankets, and mood icons.
- `data/students/*.tres` are the students (`StudentData`): name, kind, starting needs, color.
- `scripts/game_state.gd` is autoloaded as `GameState`: Giggles and discovered combos.
- `data/items/*.tres` are the items (`ItemData`). Double-click one in Godot to edit cost,
  radius, effects, and tags in the Inspector. Add an item by duplicating one.
- `data/combos/*.tres` are combos (`ComboData`). They match items by tag.
- `art/` and `ui/` are empty for now (`.gitkeep` files keep them in Git).
