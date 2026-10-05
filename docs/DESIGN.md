# MWM Play: shell design spec

Status: design spec, 2026-10-05. Covers only the **shell** around the games: start screen, in-game home button, parent gate, parent area, credits, "done for now" screen and app icon. Each game keeps its own look inside its own scene; nothing here restyles a game.

Rule numbers like (rule 7) point at `docs/CHILD_UX_RESEARCH.md`. Numbers marked (my calc) are my own arithmetic.

Mockups (1080x1920, regenerate with `python3 docs/mockups/src/crops.py && python3 docs/mockups/src/make_mockups.py`):

| File | What it shows |
|---|---|
| `docs/mockups/start_screen.png` | Start screen, five game tiles |
| `docs/mockups/start_screen_hitareas.png` | Same, with tile hit areas (green), adult corner (plum) and the no-target wrist strip (red) |
| `docs/mockups/parent_gate.png` | Parent gate with the first digit typed |
| `docs/mockups/parent_area.png` | Parent area, top of the scroll |
| `docs/mockups/ingame_home_guard.png` | Home button in its "tap again" guard state over a real Timber Valley capture |
| `docs/mockups/ingame_home_hitarea.png` | Same, with the 216x216 px hit area to the screen edges |
| `docs/mockups/done_for_now.png` | Play-limit stopping screen |
| `docs/mockups/app_icon_512.png` | Google Play icon, 512x512 |
| `docs/mockups/icon_adaptive_{foreground,background,monochrome}.png` | Adaptive icon layers, 432x432 (108 dp at xxxhdpi) |

Fonts are in `assets/fonts/` with their licence files. Contrast numbers come from `docs/mockups/src/contrast.py`.

---

## 1. Art direction

**A warm paper playroom shelf.** The shell is a quiet, light frame: warm off-white paper, ink-dark text, one green accent, and each game shown as a big picture card cut from its own real screen, so the game art is the button. Nothing moves until a finger touches it. Adults get a plain, readable settings page that looks like a calm document, not a shop. The evening "done for now" screen is the one place that uses dusk purple, to signal "the day is winding down" without words.

References (take the idea, not the look):
- **Nintendo Switch HOME menu**: one large picture tile per game, with the game's own art as the label. Taken: the tile *is* the game's art; no invented mascots or shell-only illustrations.
- **Khan Academy Kids parent section**: the adult area is a separate, plain settings list behind a gate, with no child styling. Taken: the adult area shares only tokens with the child screens, not their playfulness.

**Match with the public page:** yes. Paper `#fbf8f2`, ink `#24211d` and green `#1f7a5a` are the site's own tokens. The only difference is the muted text: `#5c5449` in the app (7.0:1) vs `#6b645a` on the site, darkened so 30 px secondary text stays readable on a phone in daylight.

### Palette tokens

60/30/10 split: paper and white cards about 60%, game art and tile bands about 30%, green accent 10% (parent buttons, toggles, selected states, wordmark).

| Token | Hex | Godot | Use |
|---|---|---|---|
| paper | #fbf8f2 | Color(0.984, 0.973, 0.949) | Background of all light shell screens |
| card | #ffffff | Color(1.000, 1.000, 1.000) | Cards, keypad keys, home disc |
| ink | #24211d | Color(0.141, 0.129, 0.114) | All primary text, icons, home ring |
| ink_soft | #5c5449 | Color(0.361, 0.329, 0.286) | Secondary text, adult corner icon |
| line | #e6dfd2 | Color(0.902, 0.875, 0.824) | Decorative dividers and card edges only (never the only edge of a control) |
| edge | #8f8371 | Color(0.561, 0.514, 0.443) | Outline of every interactive control: tiles, keys, off toggles, segments |
| green | #1f7a5a | Color(0.122, 0.478, 0.353) | Primary button, toggle on, selected segment, guard ring, wordmark |
| green_soft | #e3f0ea | Color(0.890, 0.941, 0.918) | Pressed state of white controls |
| plum | #5b3f8c | Color(0.357, 0.247, 0.549) | Adult figure on the gate; adult-only accents |
| dusk | #2e2b4f | Color(0.180, 0.169, 0.310) | "Done for now" background |
| moon | #c9c3e6 | Color(0.788, 0.765, 0.902) | Moon, stars and secondary text on dusk |
| band_bc / ws / te / sp / tv | #e6ddf3 / #d3e8f5 / #f0dcc4 / #cdeeed / #d8eccb | (0.902, 0.867, 0.953) / (0.827, 0.910, 0.961) / (0.941, 0.863, 0.769) / (0.804, 0.933, 0.929) / (0.847, 0.925, 0.796) | Tile band per game: Ball Connect, Water Sort, Tile Explorer, Spotless, Timber Valley |
| hill_1 / hill_2 / sand | #e4ecd8 / #d5e3c6 / #f1e7d6 | (0.894, 0.925, 0.847) / (0.835, 0.890, 0.776) / (0.945, 0.906, 0.839) | Decorative hills in the bottom wrist strip |

### Contrast (my calc, WCAG 2.x formula)

| Pair | Ratio | Need |
|---|---|---|
| ink on paper | 15.12:1 | 4.5 (rule 34) |
| ink_soft on paper / on card | 7.03 / 7.45:1 | 4.5 |
| green text on paper | 4.97:1 | 4.5 |
| white on green button | 5.26:1 | 4.5 |
| ink on each tile band | 12.01 to 13.01:1 | 4.5 |
| edge outline vs paper / vs card | 3.50 / 3.71:1 | 3.0 (rule 35) |
| plum on paper | 7.82:1 | 4.5 |
| paper text on dusk | 12.58:1 | 4.5 |
| moon text on dusk | 7.90:1 | 4.5 |
| Home button vs game backgrounds: white disc on Ball Connect black 21.0, on Water Sort navy 16.3; ink ring on Tile Explorer sky 14.3, on Spotless wall 12.2, on Timber grass 7.8 | all >= 7.8:1 | 3.0 |

The home button is a white disc with a 5 px ink ring, so one of the two edges always contrasts, whether the game behind it is dark (Ball Connect, Water Sort) or light (Tile Explorer, Spotless).

### Colour-blind check (my calc, Machado 2009 simulation, minimum CIELAB distance)

| Group | Normal | Protan | Deutan | Tritan | Verdict |
|---|---|---|---|---|---|
| Toggle on (green) vs off (edge) | 37.2 | 8.0 | 12.4 | 40.2 | Too close for protans by colour alone, so state is also shown by knob side, a check mark in the on knob, and the words **På / Av** (rule 36) |
| Five tile bands | 8.6 | 3.6 | 0.8 | 4.2 | Bands are indistinct for colour-blind children. Accepted: the band is decoration. Each tile is told apart by its picture, its name and the spoken name (rule 36) |
| Icon balls (red, blue, yellow) | 56.2 | 48.7 | 28.5 | 49.0 | Distinct for all three |

No shell state relies on colour alone: the selected play-limit segment is filled *and* has white bold text, and wrong gate input clears the boxes and changes the code instead of turning anything red.

---

## 2. Screens

### Units: mm to px

Formula: **px = mm x dpi / 25.4**, where dpi = design px across the screen divided by its physical width in inches.

- Brief assumption: 6.1" phone at about 400 dpi, so **1 mm = 15.75 px** and 1 dp = 2.5 px.
- Worst case I also check: a 6.1" 20:9 phone is 64.0 mm wide (my calc: 6.1 in x 9 / sqrt(9^2 + 20^2) = 2.52 in), so 1080 px over 64 mm gives about 430 dpi, or **1 mm = 16.9 px**. A 200 px target is 12.7 mm at 400 dpi but 11.8 mm at 430 dpi. Child targets below are sized so they pass at 430 dpi too.
- Taller phones (20:9): with `stretch/aspect = expand` the canvas stays 1080 wide and grows to about 2400 px tall. Top items anchor to the top, the wrist strip anchors to the bottom, and the tile block centres in the space between.
- **10" tablet** (16:10 portrait, 215 mm tall): the 1920 px height maps to 215 mm, so 1 design px = 0.112 mm (my calc), and **everything is 1.77x physically larger** than on the phone. The canvas becomes about 1200 px wide; the extra 120 px goes to side margins, and the home button and adult corner stay anchored to their corners. No layout change is needed: the bigger targets suit a tablet held further away. The 32-bit Samsung tablet must still be checked by eye.

### Shared rules for every child screen
- Home is **always the top-left corner** (rule 20). On the start screen that corner holds the wordmark, which is not a button.
- **Bottom wrist strip has no targets** (rule 6): y >= 1664 at 1080x1920, which is 256 px = 16.3 mm. It holds only decorative hills.
- Touch-down gives a sound and a visual in the same frame; the action fires on release inside the hit area (rules 15, 19).
- Holdover filter: for **300 ms** after any screen change, ignore all touches (rule 8). This stops the finger that pressed home in a game from also starting a tile on the start screen.
- Only tap. No long press, no double-tap except the leave guard, and no swipe in the shell (rules 9-11, 24).
- No scrolling on child screens (rule 20).

### 2a. Start screen (`start_screen.png`)

| Element | px (1080x1920) | mm at 400 / 430 dpi | Rule |
|---|---|---|---|
| Wordmark "MWM Play", top-left, Fredoka SemiBold 56 px, green | x 56, centre y 104 | | Not a button |
| Game tile | 468 x 440 | 29.7 x 27.9 / 27.7 x 26.0 | 2.2x the 12.7 mm floor (rule 1) |
| Tile hit area | tile + 8 px each side | | rule 5 (see note) |
| Gap between tiles | 48 px drawn, 32 px between hit areas | 3.0 mm drawn = 19 dp | >= 8 dp (rule 4) |
| Tile art | 440 x 318, radius 32, inset 14 px | | |
| Name, Andika Bold 50 px, ink, centred on the band | | | rules 17, 40 |
| Rows | y 232, 720, 1208 (5th tile centred, x 306) | | |
| Adult corner, top-right | 104 px disc, gear 46 px in ink_soft, "Voksne" label 30 px below; hit area 160 x 160 to the corner | 6.6 mm drawn, 10.2 mm hit | rule 7 (to the edge), rule 22 |

- **Tile art** is cut from each game's own screenshots (`docs/mockups/src/crops.py`): Ball Connect level 1, Water Sort mid-pour, Tile Explorer level 5, Spotless foamed car, Timber Valley mill and lumberjack. For release, recrop from 1080x1920 capture-bot shots; today's sources are 540x960 and look slightly soft when upscaled.
- **Playable by a non-reader** (rules 17-21): the picture identifies the game. Touch-down plays a soft wooden "tok" and presses the tile to 96% scale. On release, the game's **name is spoken** while the scene loads, so a child learns the names by hearing them. One tap launches: no confirm and no second screen.
- **Hit-area note (rule 5):** the 25% pad assumption would make tiles overlap. With tiles already 2.2x the rule-1 floor, an 8 px pad plus a 32 px dead gap is my call.
- **Adult corner:** muted gear in ink_soft with the word "Voksne", no colour and no animation, so it is not inviting. A child who taps it only reaches the gate, which says "Hent en voksen". It is a deliberately small target, not a child target: it meets the 6.35 mm floor of rule 3 through its 10.2 mm hit area, not rule 1.
- **Free to try is invisible to the child** (counter-consideration 1, rule 22). There are no padlocks, grey tiles, badges, stars, "new" labels, "full version" lines or prices on any child screen. All five tiles always look the same and always open. When a child finishes the last free level of a game, the shell shows a calm card titled "Du har spilt alle banene her" ("You have played all the levels here"), with a **replay** icon (start the free levels again) and a **house** icon. Nothing mentions buying, more levels or asking a parent. Parents learn about the unlock only in the parent area.
- **7 games later:** four rows of 2 with tiles at 468 x 328 (20.8 mm tall at 400 dpi), art 440 x 214, rows from y 232 with 36 px gaps, ending at y 1656, still above the strip. Whether 7 choices is too many for a 4-year-old is unknown (rule 21 gap): playtest with 4-5 year olds before adding the 6th and 7th tile.
- No music on the start screen. It is the quiet room between games, and that avoids two music tracks overlapping during scene changes.

### 2b. In-game overlay (`ingame_home_guard.png`, `ingame_home_hitarea.png`)

| Element | px | mm at 400 / 430 dpi | Rule |
|---|---|---|---|
| Home disc, top-left, white with 5 px ink ring, ink house 68 px | dia 136, centre (104, 104) | 8.6 / 8.0 | rule 20 |
| Hit area: from the top-left screen corner | 0,0 to 216,216 | 13.7 / 12.8 | runs to both edges (rule 7); >= 12.7 mm (rule 1) |
| Guard state: disc grows to dia 164, white halo dia 208 with a 3 px ink edge, green 12 px ring filling clockwise | | | rule 10 |
| Shell CanvasLayer | layer 100 | | MERGE_PLAN section 3 |

**Leaving a game uses a "tap again" guard (rule 10):**
1. First tap on home: the disc pops to 1.2x, a white halo appears and a green ring fills around it over **2.0 s**, with one soft "pling". The game keeps running and is not paused.
2. A second tap on the disc **between 300 ms and 2.0 s** after the first leaves the game. The 300 ms floor filters holdovers (rule 8), so one shaky tap cannot count twice.
3. With no second tap, the ring fades out over 250 ms and nothing else happens.
4. This is a slow "tap, tap", not a strict 300 ms double-tap: young children manage double-tap only about 62% of the time (rule 10), and a guard is supposed to filter accidents, not skill.

**Android back** (system back button or edge-swipe gesture) does exactly what a home tap does. The first back starts the guard and a second back within 2 s leaves. This matters because children often trigger the edge-swipe gesture by accident when they hold a phone. `quit_on_go_back = false` (MERGE_PLAN item 10).

Back on the other screens:

| Screen | Back does |
|---|---|
| Start screen | Default Android behaviour: the app goes to the background. Nothing is lost (rule 28), so there is no confirm. |
| Parent gate | Back to the start screen |
| Parent area, credits, tip pages | Up one level; from the parent area, back to the start screen |
| Done for now | Same as the check button (closes the app) |

**Leaving saves first.** The adapter's `exit()` saves (MERGE_PLAN section 3). Ball Connect and Tile Explorer must gain progress saves upstream before launch (MERGE_PLAN section 7, step 1).

**Top-left collisions found in the real screenshots.** Rule 20 wants home in one fixed place, which conflicts with MERGE_PLAN's per-game `home_button_corner()`. **I chose one fixed corner**, so the adapter field becomes a fixed constant. Four games put something in the 216 x 216 px home square today:

| Game | What sits under the home square | Upstream fix needed |
|---|---|---|
| Ball Connect | Top-left ball of the level-1 board (about 100,190) and the neon frame corner | Board top margin of at least 232 px when in the shell |
| Water Sort | Its restart button (about 50,90) | Move restart right of x 232 |
| Tile Explorer | Left end of the level card | Card starts at x 232, or y 232 |
| Spotless | Level card text and the restart button (about 44,210) | Card starts at x 232; restart moves below y 232 |
| Timber Valley | Nothing | None |

Each game needs a small upstream hook, for example `set_shell_inset(Vector2(232, 232))`, called by the adapter on `enter()`. It does nothing in the standalone build, as MERGE_PLAN section 5 allows. On phones with a top-left camera cutout, push the disc below `DisplayServer.get_display_safe_area()` but keep the hit area running to the screen edge.

### 2c. Parent gate (`parent_gate.png`)

| Element | px | mm at 400 dpi |
|---|---|---|
| Home disc, top-left, same as in games (one tap, no guard: leaving the gate is harmless) | dia 136, hit 216 | 13.7 hit |
| Adult (plum) and child (green) figures | about 240 tall, centre x 540, y 200-430 | |
| Title "Hent en voksen", Fredoka SemiBold 76 px | y 500 | |
| Line "Voksne: skriv tallene med sifre", Andika 40 px, ink_soft | y 580 | |
| Code card, white, Andika Bold 84 px, e.g. "sju · fire · to" | 840 x 150 | 53 x 9.5 |
| Three answer boxes (empty: edge outline; filled: ink outline + digit) | 150 x 140 each, 30 px apart | 9.5 x 8.9 |
| Keypad 1-9, then [blank] 0 delete | keys 290 x 150, 28 px gaps, y 1010-1694 | 18.4 x 9.5 per key |

Behaviour (rule 23):
- When the gate opens, a recorded voice says **"Hent en voksen."** once. Tapping the figures replays it.
- The code is 3 random digits from **2-9**, with no repeats, written as Norwegian words ("sju - fire - to"). 0 and 1 are left out because "null" is easy to misread and "en" is also the article in "Hent en voksen" (my reasoning). English devices get English words ("seven - four - two").
- There is no per-digit feedback. On the third digit the answer is checked. If it is wrong, the boxes clear, a **new code** appears with a 200 ms crossfade, and the line under the title changes to "Prøv igjen med de nye tallene" ("Try again with the new numbers"). No red, no shake, no lock-out timer.
- No hold-to-unlock (rule 24). The keypad is the numeric layout adults know.
- The gate is asked **every time** someone enters the parent area. Inside, adults move freely; going back to the child screens locks it again.
- What the gate cannot do: a child of about 7 or older who reads Norwegian can decode "sju fire to". The gate keeps pre-readers out of settings. Money is protected separately because Google Play asks for its own confirmation on purchases in apps for ages 12 and under (rule 25).

### 2d. Parent area (`parent_area.png`)

Adult screen, scrolls vertically (rule 20's no-scroll applies to child screens). Top bar: home disc top-left (back to the games), title "For voksne" in Fredoka SemiBold 60 px. Cards are white, 984 px wide, radius 36, with a `line` edge and 24 px gaps between them. Body text is Andika 34 px; the minimum anywhere is 30 px (1.9 mm, about 12 sp).

In order:
1. **Unlock all games** ("Lås opp alle spillene"): two sentences in plain words, then a green full-width button 896 x 110 px "Lås opp for 79 kr", then a text button "Gjenopprett kjøp" ("Restore purchase"). Body text: "Prøveversjonen har de første banene i hvert spill. Én betaling låser opp alle baner i alle spill, også spill som kommer senere. Ingen abonnement og ingen reklame." ("The trial has the first levels in each game. One payment unlocks every level in every game, including games added later. No subscription and no ads.") The price string comes from Google Play Billing's localised price, never hard-coded (rule 25). States: *pending* shows "Venter på Google Play" ("Waiting for Google Play") in place of the button; *owned* replaces the card with "Alle spillene er låst opp. Takk!" ("All games are unlocked. Thank you!") and hides the button. Nothing about the purchase ever leaks into a child screen.
2. **Sound and motion** ("Lyd og bevegelse"), with rows 112 px tall and the whole row as the hit area:
   - Lydeffekter (sound effects), default on.
   - Musikk (music), default on, at low volume (rule 33).
   - Vibrasjon (vibration), default **off** (rule 33).
   - Mindre bevegelse (less motion), default off, with the line "Ingen risting, parallakse eller partikler" ("No shaking, parallax or particles") (rule 39).

   Toggles are 128 x 72 px. The state shows by knob side, a check mark and the word På/Av, not by colour alone. The shell passes all four settings to every adapter on `enter()`. Games that do not read "less motion" yet must add support upstream; the shell itself obeys it now (section 3).
3. **Play limit** ("Grense for spilletid"): segmented Av / 15 / 30 / 45 / 60 min (171 x 110 px each), default **Av**. Line under it: "Spillet stopper ved neste naturlige pause. Ingen nedtelling." ("The game stops at the next natural break. No countdown.") (rules 27, 29). While a limit is running, this card also shows "Brukt i dag: 12 min" ("Used today: 12 min") and a "Start på nytt" ("Start over") button.
4. **Play together** ("Spill sammen", rule 42): one row per game (96 px thumbnail, name, "Tips til å spille sammen"), opening a short page with 2-3 sentences. Draft tips, for game-designer to finalise:
   - Ball Connect: "Ta annenhver linje: barnet viser hvilke baller som hører sammen, du drar, så bytter dere." ("Take turns by line: the child shows which balls belong together, you drag, then swap.") (rule 41)
   - Water Sort: "Spør hvilken flaske som snart er full før dere heller, og la barnet forklare planen." ("Ask which bottle is nearly full before you pour, and let the child explain the plan.")
   - Tile Explorer: "Si navnet på bildene dere plukker. Barnet finner den tredje som er lik." ("Name the pictures you pick. The child finds the third one that matches.")
   - Spotless: "Del jobben: én vasker, én pusser. Snakk om hva som skjer med skitten." ("Split the job: one washes, one polishes. Talk about what happens to the dirt.")
   - Timber Valley: "La barnet bestemme hva dere kjøper neste gang, og spør hvorfor." ("Let the child decide what you buy next, and ask why.")
5. **About the app** ("Om appen"): "Personvern" (privacy text shown in the app, no web link, works offline; rules 45, 46), "Lisenser og takk" (licences and thanks, section 2e), and the version number.

### 2e. Credits screen ("Lisenser og takk", adult only)
- Reached only from the parent area, so it is behind the gate (rule 22). Same top bar as the parent area, with title "Lisenser og takk". One long vertical scroll.
- Text: Andika Regular 30 px, ink, line height 1.45; section headings Andika Bold 40 px; 48 px side margins. Licence texts are shown verbatim in their original English.
- Sections, in order:
  1. **MWM Play**: one line saying who made it, plus "No ads, no tracking."
  2. **Godot Engine**: `Engine.get_license_text()` (the MIT text, read at runtime so it always matches the engine build).
  3. **Third-party components in Godot**: loop over `Engine.get_copyright_info()` (component name, files, copyright, licence id) and print each licence once from `Engine.get_license_info()`. This covers FreeType, HarfBuzz and the other bundled libraries without hand-copying them.
  4. **Fonts**: Andika (Copyright SIL Global, SIL Open Font License 1.1) and Fredoka (Copyright 2016 The Fredoka Project Authors, OFL 1.1), each followed by the full OFL text from `assets/fonts/Andika-OFL.txt` and `Fredoka-OFL.txt`.
  5. **Game assets**: Kenney (kenney.nl) CC0 kits used in Spotless and Timber Valley (credited out of courtesy; CC0 needs no credit). Music and most sound are made in code by each game's tools.
  6. **Google Play Billing plugin**: its licence text (Apache 2.0 if the official Godot plugin is used; confirm against the plugin actually chosen).
- No links out (rule 45). Plain text only.

### 2f. Done for now (`done_for_now.png`)
- Shown by the play limit (rules 26, 29) only at a **natural stopping point**: after a level-complete screen in Ball Connect, Water Sort, Tile Explorer and Spotless. Timber Valley has no levels: game-designer must define its stopping point (open item, see the end of this document).
- Never a countdown or a warning beforehand (rule 27; Hiniker 2016 found that two-minute warnings make transitions worse).
- Look: dusk background, moon and five small stars that stay still, title "Ferdig for nå" ("Done for now", Fredoka SemiBold 96 px, paper), the line "Alt er lagret." ("Everything is saved.", Andika 44 px, moon), and one round check button (240 px = 15.2 mm, hit 320 px).
- Voice: "Nå er spilletiden ferdig. Alt er lagret." ("Playtime is over now. Everything is saved."). No guilt, no "come back tomorrow", no character asking the child to stay or return (rule 27). Progress is saved before this screen appears (rule 28).
- Tapping the check closes the app (`get_tree().quit()`), since progress is already saved. If the app is opened again while the limit is still used up, this screen shows again. The adult corner (top-right, same size and place as on the start screen) leads through the gate to the play-limit card ("Start på nytt").
- The used time resets automatically after the app has been closed for **60 minutes**. This is my call and untested; the owner or game-designer may prefer a midnight reset.

---

## 3. Typography, icons, motion and sound

**Fonts** (both SIL Open Font License 1.1, files in `assets/fonts/`):
- **Andika** (SIL Global), Regular and Bold: every word a child might read (tile names, the "done" screen) and all adult body text. It is a sans-serif built for beginning readers, with a single-storey a and g and a distinct l, I and 1 (rule 40), and it covers æ ø å.
- **Fredoka** (The Fredoka Project Authors), variable, SemiBold and Medium: the wordmark, screen titles and keypad digits. It is the same file Spotless and Timber Valley already ship, so it adds no new licence.

| Use | Size |
|---|---|
| Tile name | Andika Bold 50 px |
| Screen title | Fredoka SemiBold 60-96 px |
| Adult body | Andika 34 px |
| Smallest text anywhere | 30 px |

Text size for children is unsourced (rule 40 gap): playtest the 50 px tile names with 4-5 year olds.

**Icons:** filled, rounded shapes in ink on a white disc, with no outlines inside the shape. Only conventional symbols (rule 20): house = home, gear = adults, check = OK, back arrow = back, replay arrow = play again. No text inside child buttons. Game names appear only on tile bands.

**Motion** (all of it can be switched off by "less motion", rule 39):

| Event | Motion | With "less motion" on |
|---|---|---|
| Tile touch-down | Scale 0.96 in 80 ms, ease-out; release springs back in 120 ms | Colour change to `green_soft` only |
| Screen change | 180 ms crossfade, no slides | Instant cut |
| Home guard | Pop to 1.2x in 120 ms, ring fills linearly over 2.0 s | No pop; the ring appears full and static, and the 2 s window is unchanged |
| Idle | Nothing moves on any shell screen; no breathing tiles, no bouncing badges | |

There are no flashes in the shell. Any burst stays at 3 per second or fewer (rule 37).

**Sound** (rules 19, 33):

| Event | Sound |
|---|---|
| Touch-down on any shell control | Soft wooden "tok", under 80 ms, about -18 dBFS, on the same frame as the visual |
| Tile release | The game's spoken name |
| Guard | One soft "pling" |
| Wrong gate code | Silence |

There is no shell music. Effects follow "Lydeffekter" and games follow both toggles. All volumes are kept low; music sits at least 6 dB under effects.

**Voice lines to record.** These must be a native Norwegian human voice: the owner has rejected all free TTS. English versions are needed for English devices.
- The five game names
- "Hent en voksen."
- "Prøv igjen med de nye tallene." (shown as text; voice optional)
- "Du har spilt alle banene her."
- "Nå er spilletiden ferdig. Alt er lagret."

---

## 4. App icon (`app_icon_512.png`, adaptive layers)

- **Concept:** a cream rounded "play" triangle on the green field, where each corner is a coloured ball (red, blue, yellow) with a cream rim. It reads as "play", hints at a set of games, and does not copy any single game's icon or another company's look.
- **Google Play icon:** 512 x 512 PNG, full-bleed green with no baked-in corner rounding (Play applies its own mask), 27 KB, which is far under the 1 MB limit. It shows no text and no "Free / Best / #1".
- **Adaptive icon (Android 8+)**, 432 x 432 per layer (108 dp at xxxhdpi):
  - Background: solid green `#1f7a5a`.
  - Foreground: the triangle and balls, kept inside the 66 dp safe circle. Art scale 0.68 fits within the 132 px safe radius (my calc: 0.436 x 0.68 x 432 = 128 px).
  - Monochrome: the same shape in white, for themed icons on Android 13+.
- **Checked:** in `docs/mockups/src/app_icon_preview.png` at 512 with the Play corner mask, in a circular launcher mask with the safe circle drawn in red, and at 96 and 48 px. At 48 px it still reads as a play triangle with three coloured dots.
- **Risk:** three joined dots resemble the Android "share" glyph. The filled cream triangle is what separates them, so never draw it as an outline.

---

## 5. Do and don't

**Do:**
- Use the game's own art as its tile.
- Keep home top-left in every child screen.
- Leave the bottom 256 px free of targets.
- Use the gate for everything adult.
- Read the price from Play Billing.
- Recrop tiles from the capture bot whenever a game's look changes.

**Don't:**
- No padlocks, prices, "full version", stars, streaks, "new" badges or daily anything on child screens (rules 22, 27).
- No shell styling inside a game.
- No per-game home corner.
- No long-press or hold gate.
- No countdown before the play limit.
- No shell music.
- No red or shake on a wrong gate code.

## 6. Visual tier

The shell is a clean 2D UI layer (Control nodes on CanvasLayer 100, `gl_compatibility`-safe drawing on the `mobile` renderer). The games keep their own tiers: Water Sort is clean 2D; Spotless, Timber Valley, Ball Connect and Tile Explorer are premium stylized 3D. The shell costs nothing while a game runs except the home disc.

## 7. Open items I could not decide

1. **What "free to try" contains** (how many levels per game, and what the free part of Timber Valley is): this is an economy decision for game-designer and the owner. The visual rule is fixed either way: the child never sees the difference.
2. **Timber Valley's "natural stopping point"** for the play limit, since it has no levels. My suggestion is the next completed purchase, or 5 minutes after the limit, whichever comes first. This is game-designer's call.
3. **Play-limit reset:** 60 minutes closed (my default) or midnight. Neither choice is sourced.
4. **Upstream inset hooks** in four games (section 2b) need their own OK per repo before the shell can keep home in one place.
5. **Voice recording:** there is no acceptable voice yet, so every voice line above is blocked until a native speaker records it.
6. **Number of choices** (rule 21): the 5-tile layout is fine on paper, but whether 7 tiles overwhelm a 4-year-old is unknown until a playtest.
