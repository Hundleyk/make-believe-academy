# Make-Believe Academy

A cozy institution-builder in Godot 4 (made with Godot 4.7.2). Gray boxes until M4.

## Open it
Godot Project Manager → **Import** → pick `project.godot` in this folder → **Import & Edit**. Press **F5** to play.

## Starting
The game opens on the **title screen**: New Game, Continue (your newest save), Load Game, Settings, Quit.
**New School** asks which of the three save slots (cubbies) to use, empty or not, and lets you name the school.
Then Leo's letter arrives: **Find a Helper** approves it, opens Requests, and clips his notes (the objectives) bottom left.

**Requests have time limits:** answer a letter within 3 days of it arriving or it's gone (Kids' Trust -1); once
answered, the friend has to be ready by Dream Night (day 7 for Leo). Days start moving with the day clock (week 4).

The look is the Make-Believe Academy design system (tokens, components and mockups from Claude Design): PaperButtons
on a wood under-edge, hand-cut paper, washi tape, paperclips, stamps, Phosphor sticker icons (MIT), the felt-patch
badge. The UI's base size is the mockups' 1280x720; Godot scales it to the window.

## The HUD
- **Top**: Giggles (left), the Term · Day banner with Pause, Faster, and Menu tiles (center), the Kids' Trust meter (right)
- **Bottom**: Leo's clipped note (left), the tab bar: **Build (B)**, Timetable (T, week 4), **Students (P)**, Staff (H, M2), **Requests (R)**, quick-build tiles of your recent items (right)
- **Build** panel, docked left like Two Point and Let's School: a tab per room plus Anywhere, item cards with price, footprint, and effect chips; Sell and Close
- **Students** drawer: click a student for their trading card (dot skill bars, personality, quirk, today's diary, could they help Leo?)
- **Requests**: the Department form and "Who can help Leo?", every student ranked Very likely / Maybe / Unlikely; pick one to see why
- **Esc** or **right-click** backs out one step: stop holding or selling, close the card, close the drawer, then the pause screen
- **Space** pauses the students; **[** and **]** change speed
- **Main menu**: Continue, New School, Load School, Settings, Credits, Quit (with a note asking you to stay)
- **Pause** (Esc or the gear tile): Resume, Save School, Load School (3 slots with a picture of your school; Save School saves to the school's own slot), Settings, Main Menu
- **Settings** (Apply to save): Audio volumes, Video (fullscreen, UI size, reduce motion), Gameplay (readable font, camera speed), Controls (key list)

## Picking up students and teachers
- **Click** a student or teacher to pick them up, **click** again to put them down (or press, drag, and let go)
- Drop a student **on an item** and they go use it; drop the **paper dragon** (the first teacher) in a room and it becomes their room
- **Right-click** or **Esc** puts them back; **double-click** a student for their card

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
  toasts, the Esc chain), `ui_style.gd` (the design system: colors, fonts, cardboard buttons, tabs, sliders, toggles, chips),
  `widgets.gd` (drawn pieces: icons, coins, hearts, meters, dot bars, portraits, paper, tape, pins, the seal, stamps),
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
