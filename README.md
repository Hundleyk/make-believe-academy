# Make-Believe Academy

A cozy institution-builder in Godot 4 (made with Godot 4.7.2). Gray boxes until M4.

## Open it
Godot Project Manager → **Import** → pick `project.godot` in this folder → **Import & Edit**. Press **F5** to play.

## Starting
The game opens on the **title screen**: New Game, Continue (your newest save), Load Game, Settings, Quit.
New Game brings Leo's letter: accept it to pin his request and start his crayon notes (the objectives, top right).

## The HUD
- **Top**: Giggles (left), the clock with Pause, slower/faster, and Menu (center), Kids' Trust hearts (right)
- **Bottom tabs**: **Build (B)**, Timetable (T, week 4), **Students (P)**, Staff (H, M2), **Requests (R)**
- **Students** drawer: click a student for their trading card (skills, personality, quirk, could they help Leo?)
- **Requests** drawer: each child's letter and who could help, ranked Very likely / Maybe / Unlikely with reasons
- **Esc** or **right-click** backs out one step: stop holding or selling, close the card, close the drawer, then the pause screen
- **Space** pauses the students; **[** and **]** change speed
- **Pause screen** (Esc or Menu): Resume, Save Game, Load Game (3 slots), Settings, Quit to Title
- **Settings** (saved between sessions): readable font (Atkinson Hyperlegible), UI size, reduce motion, fullscreen, camera speed

## Controls
- **WASD** or arrow keys: pan the camera
- **Mouse wheel**: zoom
- **Q / E**: rotate the camera

### Build mode
- The **Build menu** (bottom right) has a tab for each room plus **Anywhere**. Picking a room tab glides
  the camera there and shows that room's items, its **whimsy** score, and a **This room needs** checklist
  (click a line to pick that item up). Hover a card to see what the item does
- **Click a card** (or press **1-9** for the open tab) to hold it. The check-mark badge means it fits;
  the cross means it doesn't (the hint box says why)
- **Left-click** to place it. You keep holding it so you can place another
- **R**: rotate the held item (when you're not holding anything, R opens Requests).  **Right-click** or **Esc**: stop holding
- **Partition walls** (Anywhere tab): click and drag to build a line of cardboard wall
- **Glow stars** go on a tile next to a wall (a room wall or a partition)
- **Hover a placed item**: its effect ring shows. **Click** to move it (free); **X** sells it
- **Sell items** button: click placed items to sell them for half price (right-click or Esc to stop)
- Items whose card says **Research** are locked until the research board arrives (M3)
- Put a **Nightlight** near the **Story Corner Rug** to discover Bedtime Story. There are 7 combos to find,
  and the first find of each pays a 25-Giggle grant

### Earning Giggles (so far)
- You start with 500. Each period, every student with Fun 7 or more giggles **+2** (**+3** in a room whose
  whimsy is Just Right). Finding a new combo pays **+25**. Selling refunds half
- Coming later: daily allowance (week 4), postcards (week 5), Joke Lab shows, grants, and graduate gifts

### Students
- Three students (Pip, Drizzle, Bo) walk around on their own. The **Students** panel (top left) shows
  their Calm, Fun, and Rest (0-10) and what each one is doing
- Needs change once per **period** (every 20 seconds for now; the day clock arrives in week 4).
  Each student walks to the item that best helps their lowest need. An item serves 2 students at once
- Below 3, a **mood icon** pops up: a shaky face (Calm), a frown (Fun), or a yawn (Rest)
- At 0 they act it out for one period: **hide** under a blanket (Calm), **wander** off to a toy (Fun),
  or **nap** where they stand (Rest)
- **Hover a need name** (Calm, Fun, Rest) in the Students panel to see every item that raises it
- **Hover a student** to see their needs and why they changed. While hovering, **C**, **F**, or **Z**
  empties Calm, Fun, or Rest so you can see an act-out right away (a test shortcut)

## Where things live
- `scenes/main.tscn` is the main scene. It is nearly empty on purpose.
- `scripts/main.gd` builds the light, the grid floor, and the three rooms in code.
  Room sizes, positions, and each room's "needs" checklist are in the `ROOMS` list at the top.
- `scripts/camera_rig.gd` is the camera. Speeds and zoom limits are at the top.
- `scripts/build_mode.gd` is build mode: placing, rotating, selling, combos. Feel numbers
  (wobble, sell refund) are at the top.
- `scripts/ui/` is the interface: `hud.gd` (the frame), `ui.gd` (autoloaded as `UI`: which drawer is open,
  toasts, the Esc chain), `ui_style.gd` (colors, fonts, paper boxes: the one file the M4 art pass changes),
  `widgets.gd` (drawn pieces: hearts, badges, skill bars, portraits, notebook paper, stamps),
  `students_panel.gd`, `trading_card.gd`, `requests_panel.gd`, `crayon_notes.gd` (objectives), `screens.gd`
  (title, pause, settings, save/load, loading, the letter).
- `scripts/settings.gd` is autoloaded as `Settings`; `scripts/save_game.gd` saves to `user://saves/`.
- `scripts/readiness.gd` turns skills and personality into Very likely / Maybe / Unlikely.
- `data/letters/*.tres` are the children's letters (`LetterData`), with each chapter's crayon notes.
- `ui/fonts/` holds Fredoka, Patrick Hand, and Atkinson Hyperlegible (all SIL Open Font License; licenses beside them).
- `scripts/build_menu.gd` is the Build menu: room tabs, item cards, room needs, whimsy, Sell button.
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
- `art/` is empty for now (a `.gitkeep` file keeps it in Git).
