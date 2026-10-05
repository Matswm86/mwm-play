# MWM Play: merge plan for five games in one Godot app

Status: PLAN ONLY (2026-10-05). No code was changed in any game repo. Everything below was read from the real files at these commits:

| Game | Repo HEAD read | Notes |
|---|---|---|
| ball-connect | `76528f6` | |
| water-sort | `1ea83d6` | renderer switch to `mobile` |
| tile-explorer | `3b05977` | renderer switch + inspiration.jpeg removal |
| spotless | `93248f3` | |
| timber-valley | `09f4526` | |

MWM Les is not part of this plan. `projects/mwm-play/site/` is not touched by it.

## Verdict

**Copy each game into `res://games/<slug>/` with a sync script that rewrites paths, class names, autoload names and save names (option a).** Submodules and runtime PCK files both still need the same rewrites, and each adds its own new problems (details in "Strategy options"). Every game is portrait 1080x1920 on Godot 4.6.2 with the `mobile` renderer, so there is no orientation switching to build. The merged debug APK comes to about 205 MB (my calc); a Play download for one phone is about 125 MB.

## 1. What each game is today

### Shared by all five
- Godot `4.6.2` in CI (`GODOT_VERSION: 4.6.2` in every `.github/workflows/build-android.yml`); local editor is `4.6.2.stable.official.71f334935`. `config/features=("4.6", "Mobile")`.
- `renderer/rendering_method="mobile"` and `.mobile="mobile"`, `import_etc2_astc=true`.
- Viewport 1080x1920, `stretch/mode="canvas_items"`, `window/handheld/orientation=1` (portrait). **All five are portrait.**
- `pointing/emulate_touch_from_mouse=true`. No custom input map actions in any game. Timber Valley only reads the built-in `ui_left/right/up/down` and physical WASD keys (desktop testing).
- No `[physics]` section anywhere: default ticks for all.
- No `default_bus_layout.tres` anywhere: only the Master bus.
- No `addons/`, no theme `.tres` files.
- `export_presets.cfg` is the same template in all five: armeabi-v7a + arm64-v8a, gradle build, immersive mode, `exclude_filter="tests/*"`. Only the package name, APK name and version differ (Tile Explorer: version code 5 / 1.0.0 and empty exclude filter; others 1 / 0.1.0).
- CI exports with `--export-debug` and a debug keystore. Native libs are stored uncompressed (`compress_native_libraries=false`).
- No game handles Android back (`NOTIFICATION_WM_GO_BACK_REQUEST` appears nowhere), so back quits the app today (Godot default `quit_on_go_back=true`).
- Every game reads input in `_unhandled_input` or `_gui_input`. Only PerfOverlay uses `_input`. A shell button on a high CanvasLayer will get taps first.
- No UID collides across the five repos (all `uid://` values in `.uid`, `.import`, `.tscn` and `.tres` files compared).

### Per game

| | Ball Connect | Water Sort | Tile Explorer | Spotless | Timber Valley |
|---|---|---|---|---|---|
| Main scene | `scenes/Game.tscn` (Node2D + Board3D + UI CanvasLayer) | `scenes/Game.tscn` (Node2D, builds its own CanvasLayer in code) | `scenes/Game3D.tscn` (UI CanvasLayer) | `scenes/Main.tscn` (Node3D) | `scenes/Main.tscn` (Node3D, Hud CanvasLayer, World) |
| Autoloads | none | none | none | `Game`, `Sfx` | `Game`, `Sfx`, `PerfOverlay` |
| class_name | none | `Puzzle`, `Bottle`, `IconButton` | `Tile3D`, `Fx3D`, `IconBaker`, `Board3D`, `Icons`, `Tray3D`, `RoundedBox`, `Drawing` | `Shapes`, `Objects`, `CleanMask`, `Hud`, `Swatch`, `Trash`, `Levels`, `Rooms`, `ToolRig`, `IconButton` | 39 names, incl. `Shapes`, `Hud`, `World`, `Player`, `Items`, `Fx`, `Zone`, `Region`, `Shop`, `Balance`, `Models` |
| Save file | none (level progress is not saved) | `user://save.cfg` (ConfigFile) | none (level progress is not saved) | `user://save.json` | `user://save.json` (version 4, autosave every 8 s, offline earnings) |
| stretch/aspect | expand | expand | **keep** (not set) | expand | expand |
| msaa_3d | 2x | off | **off** | 2x | 2x |
| Shadow settings | default | default | default | size.mobile 2048, soft quality .mobile 2 | same as Spotless |
| Clear colour | (0, 0, 0) | (0.06, 0.13, 0.2) | (0.92, 0.95, 1) | (0.9, 0.88, 0.85) | (0.55, 0.75, 0.85) |
| Window override (desktop only) | none | 540x960 | none | 540x960 | 540x960 |
| Fonts | engine default | engine default | engine default | `assets/fonts/Fredoka.ttf` | `assets/fonts/Fredoka.ttf` (same md5 as Spotless) |
| Icon | icon.svg | icon.svg | icon.svg | icon.png (origin unknown, licence audit) | icon.png (origin unknown) |
| Runtime dirs | scenes, scripts, data (28 KB) | scenes, scripts, assets (1 MB) | scenes, scripts, data (344 KB) | scenes, scripts, assets (2.9 MB) | scenes, scripts, assets (84 MB on disk) |
| `res://` literals | 7 | 4 | 4 | 11 (incl. `"res://assets/models/%s.glb"`) | 272 (258 under assets/) |
| Screenshot bot | tests/capture.tscn | tests/capture.tscn | none (uses `TILE_DEVSHOT` env in GameManager3D) | tests/capture.tscn | tests/capture.tscn |
| Global state it touches | none | `get_viewport().size_changed` | `get_tree().quit(0)` only in the dev-shot path | `AudioServer.set_bus_mute(0, ...)`, save on APPLICATION_PAUSED | `AudioServer.set_bus_mute(0, ...)`, `reload_current_scene()` on reset, `get_tree().current_scene` for FX, static mesh caches |
| Release APK | 160.5 MB | 160.7 MB | 160.1 MB (May build) | 163.9 MB | 199.1 MB |

No game builds a path with `"res://" + x` or loads with a relative path, so a prefix rewrite of every `res://` literal is complete.

Timber Valley's `scripts/PerfOverlay.gd` is byte-identical to `game-studio/templates/scripts/PerfOverlay.gd`, and no Timber script references `PerfOverlay`.

## 2. Collisions if copied under `res://games/<slug>/`

### Must fix (the project will not load or will misbehave)
1. **Duplicate `class_name`** (parse error, project refuses to load the second script):
   - `Shapes`: Spotless + Timber Valley
   - `Hud`: Spotless + Timber Valley
   - `IconButton`: Water Sort + Spotless
   - Not colliding today but generic and likely to collide with the shell or the next game: `World`, `Player`, `Items`, `Fx`, `Zone`, `Region`, `Levels`, `Objects`, `Board3D`.
2. **Duplicate autoload names**: `Game` and `Sfx` in both Spotless and Timber Valley. Spotless references `Game.` in 3 files, Timber in 22; `Sfx.` appears in 20 files across both.
3. **Absolute `res://` paths**: all 298 literals plus every `ext_resource path=` in `.tscn`/`.tres` and `source_file=` in `.import` files point at the repo root (`res://scripts/`, `res://scenes/`, `res://assets/`, `res://data/`). Both Spotless and Timber use `res://scenes/Main.tscn`, `res://scripts/Game.gd`, `res://scripts/Sfx.gd`, `res://assets/audio/music.ogg`, `res://assets/fonts/Fredoka.ttf`.
4. **Save name clash**: Spotless and Timber Valley both write `user://save.json`. In one app they would overwrite each other.
5. **Autoloads run from app start, not from game start**:
   - Both `Sfx` autoloads call their `apply_*` function at the end of `_ready`, so Spotless music and Timber music plus ambience would start together on the launcher screen.
   - Both call `AudioServer.set_bus_mute(0, not Game.sound_on)`: one game's "sound off" mutes the Master bus for the shell and every other game.
   - Timber's `Game._process` autosaves every 8 s while you play a different game.
   - Timber computes offline earnings in `load_game()`, which runs once at app start. Leaving Timber for 30 min to play Water Sort would not pay offline earnings on return.

### Must handle per game (project settings are global, the games differ)
6. `stretch/aspect`: Tile Explorer is `keep`, the rest `expand`. Set `get_window().content_scale_aspect` on entry.
7. MSAA 3D: Tile Explorer and Water Sort run without it, the others with 2x. Set `get_viewport().msaa_3d` on entry. Turning it on for Tile Explorer would change its look and cost.
8. Soft shadow filter quality on mobile: Spotless/Timber use 2, Ball Connect and Tile Explorer (both have shadow-casting lights) use the default. Set via `RenderingServer.directional_soft_shadow_filter_set_quality()` on entry. Shadow atlas size is the same (2048 on mobile) for all.
9. Default clear colour: differs in all five. Set `RenderingServer.set_default_clear_color()` on entry.
10. `quit_on_go_back` must become `false` in MWM Play, or Android back quits the whole app from inside a game.

### No collision
- Orientation (all portrait), physics ticks, audio bus layout, input map actions, UIDs, addons, themes.
- `Fredoka.ttf` is duplicated (same file, both copies kept under their own game folder; about 100 KB extra, dedupe later if wanted).
- Static caches in Tile3D, Timber `Items`/`Shapes`/`Models`/`MeshMerge`/`Fx` and Spotless `Shapes`/`ToolRig` stay in memory after the game exits. That is not a bug, but memory after returning to the shell has to be checked with PerfOverlay on the phone.

### Not a merge problem, but players will notice it in a launcher
- Ball Connect and Tile Explorer do not save progress, so a kid who goes back to the launcher loses their level. The fix belongs in the source repos (one small save each), before launch.

## 3. What a game needs to launch from the shell and return

The shell owns one autoload, `Shell`, plus the template `PerfOverlay` (Timber's copy is dropped; it is identical). Each game gets an **adapter** script written in MWM Play, at `res://shell/adapters/<slug>.gd`. The sync script never overwrites adapters. Game code stays as the source repo has it, apart from the mechanical rewrites.

Adapter contract:
```
const MAIN_SCENE := "res://games/<slug>/scenes/Main.tscn"
const AUTOLOADS := ["TimberGame", "TimberSfx"]   # parked when not playing
const SETTINGS := {msaa_3d, clear_color, aspect, soft_shadow_quality, orientation}
func enter() -> void   # before change_scene: unpark autoloads, reload save, apply settings
func exit() -> void    # save, stop audio, unpark → park, restore shell settings
func home_button_corner() -> int   # where the 130 px home button sits without covering the HUD
```

Launch sequence (`Shell.launch(slug)`):
1. Shell started the app with every game autoload **parked**: in its own `_ready` (Shell is registered first) it waits one frame, then removes each game autoload node from `/root`, keeping the reference. Removing an AudioStreamPlayer from the tree stops its sound, and a node outside the tree gets no `_process`, so the 8 s Timber autosave stops too. The global names (`TimberGame`, ...) still point at the same live objects.
2. Shell resets `AudioServer.set_bus_mute(0, false)` after parking, because the parked `_ready` calls may already have muted Master.
3. `adapter.enter()`: re-add the autoload nodes to `/root`, call `load_game()` (Timber: re-runs the offline earnings math from `saved_at`; whether `load_game()` is safe to call twice is UNVERIFIED and must be checked), call `apply_settings()` / `apply_sound_setting()`, and apply the per-game settings from item 6-9.
4. `get_tree().change_scene_to_file(MAIN_SCENE)`. Use change_scene, not add_child: Timber uses `get_tree().current_scene` for FX and `reload_current_scene()` for reset, and both only work when the game root is the current scene.
5. Shell adds the home button on CanvasLayer 100 and listens for `NOTIFICATION_WM_GO_BACK_REQUEST`.

Return sequence (back gesture or home button):
1. `adapter.exit()`: `save_game()` on games that have one, then park the autoloads (stops music/ambience/autosave), `Engine.time_scale = 1`, `get_tree().paused = false`, restore the Master mute to the shell's own sound setting, restore aspect/MSAA/clear colour/shadow quality.
2. `change_scene_to_file("res://shell/Launcher.tscn")`. Scene nodes are freed; Water Sort's `size_changed` connection goes with its node.
3. Stale references such as `TimberGame.world/player/hud` point at freed nodes until the next `World._ready` sets them again. Timber already guards `player` with `is_instance_valid`; the adapter should also null them on exit to be safe.

Orientation: not needed now (all portrait). The adapter field exists so a later landscape game calls `DisplayServer.screen_set_orientation()` on entry and resets it on exit.

## 4. Strategy options

### (a) Copy into `res://games/<slug>/`, kept in sync by a script (CHOSEN)
- The sync script (`tools/sync_game.py <slug> [<sha>]`) reads from the local sibling repo with `git archive <sha>`, so it only ever copies committed code, and writes the SHA to `games/<slug>/SOURCE`.
- It copies only runtime folders: `scenes scripts assets data`. It never copies `tests tools screenshots screenshots_v3 docs store .github project.godot export_presets.cfg *.md`. This also keeps Timber's 132 MB `tools/` and 109 MB `screenshots_v3/` out.
- Rewrites, all mechanical and repeatable:
  1. `res://` → `res://games/<slug>/` in `.gd .tscn .tres .gdshader .import .cfg .json`, except `res://.godot/` (Godot re-imports moved files).
  2. Every `class_name X` → `<Prefix>X` (prefixes `Bc`, `Ws`, `Te`, `Sp`, `Tv`), plus every use of `X` in that game's `.gd` files. Prefix all of them, not only today's three clashes, so the next game cannot collide. The rewrite must be token-based (a small Python tokenizer): skip string literals, comments, and `$Hud` / `%Name` / `"World"` node paths, because Timber has nodes literally named `Hud` and `World`.
  3. Autoloads `Game`/`Sfx` → `SpotlessGame`/`SpotlessSfx` and `TimberGame`/`TimberSfx` with the same tokenizer; registered in MWM Play's `project.godot` by the script.
  4. `"user://` → `"user://<slug>_` (gives `user://spotless_save.json`, `user://timber-valley_save.json`, `user://water-sort_save.cfg`). Flat names, so no folder has to exist first. There is nothing to migrate: MWM Play is a new package and cannot read the sideload apps' data.
- Then a collision check (`tools/check_collisions.py`) that fails the sync on any duplicate class_name or autoload, any `res://` in `games/<slug>/` that does not point inside `games/<slug>/`, duplicate `user://` names, or duplicate UIDs.
- Pros: one normal Godot project, CI unchanged from the studio template, the editor sees everything, lint and load-check work as usual. A fix in a source repo arrives with one command and shows up as a reviewable diff.
- Cons: about 90 MB of game assets get copied into a second git repo, and each Timber asset sync grows its history. Accepted; if it hurts, move `games/*/assets` to Git LFS later.

### (b) Git submodules
- Godot's editor skips any subfolder that contains its own `project.godot` (based on my memory of the editor's filesystem scan code, not tested here), so a whole-repo submodule would not even be imported.
- The absolute `res://` paths, class_name clashes and autoload clashes are all still there. Fixing them inside the source repos would break the standalone games, which still ship to the owner's phone.
- Each clone would also pull Timber's `tools/` and screenshots.
- Rejected. Submodules only replace the `git archive` step of (a) and add clone pain in CI.

### (c) One PCK per game, loaded with `ProjectSettings.load_resource_pack()`
- `load_resource_pack(pack, replace_files, offset)` has no mount point. Every game uses `res://scripts/` and `res://scenes/`, and Spotless and Timber share `res://scenes/Main.tscn`, `res://scripts/Game.gd` and more, so the packs would overwrite each other. The path rewrite from (a) is still required.
- Autoloads in a PCK's own `project.godot` are not registered. My understanding is that `class_name` scripts inside a PCK the base project never saw are also not in the global class list (known Godot limitation, UNVERIFIED here). Both need the same rewrites as (a).
- No size gain: the PCKs still ship inside the AAB. Godot has no built-in Play Asset Delivery support for on-demand download.
- Five export pipelines to keep in step with one engine version.
- Rejected for now. Worth another look only if the catalogue outgrows the Play download limit, and only then as Play Asset Delivery packs built from the already-rewritten `games/<slug>/` folders.

## 5. How fixes flow later

1. Fix in the source repo (`projects/<slug>/`), as today. Standalone CI goes green, and the owner can still sideload the single game.
2. In MWM Play: `tools/sync_game.py <slug>` (defaults to the source repo's HEAD commit; refuses a dirty or unpushed HEAD) → collision check → `godot --headless --import` → lint → load check → shell capture of that game.
3. Commit in mwm-play: "Sync Timber Valley to 09f4526: <player-visible change>". CI builds the MWM Play APK/AAB.
4. Never edit `games/<slug>/` by hand. A pre-commit hook in mwm-play rejects changes under `games/<slug>/` unless `games/<slug>/SOURCE` changes in the same commit. Bugs found while testing in MWM Play are fixed upstream first, then synced.
5. Anything only MWM Play needs (enter/exit hooks, settings) goes in the adapter, never in game code. If an adapter needs a hook the game lacks (e.g. a public `save_game()` on a game without one), add it upstream; it is harmless in the standalone build.

## 6. Size estimate

Measured from the GitHub `latest` release APKs (2026-10-05; Ball Connect and Timber Valley downloaded and listed with `unzip -l`):
- Fixed engine part per APK: `libgodot_android.so` 80.3 MB (armeabi-v7a) + 74.9 MB (arm64-v8a), stored uncompressed, plus `classes.dex` 6.1 MB and libc++ 2.1 MB. Ball Connect's APK is 160.5 MB with 0.48 MB of game assets, so the engine baseline is about 160.1 MB.
- Game content = release APK minus that baseline (my calc): Ball Connect 0.5 MB, Water Sort 0.6 MB, Tile Explorer about 0.4 MB (its release is from May; on-disk data 344 KB), Spotless 3.8 MB, Timber Valley 39.0 MB (39.4 MB of `assets/` in the APK). Total about 44 MB.
- **Merged debug APK, both ABIs: about 160 + 44 + 1 (shell, billing plugin) ≈ 205 MB (my calc).**
- **Play AAB, per device:** Play serves one ABI, so arm64 is about 75 + 8 + 45 ≈ 128 MB installed and 32-bit about 134 MB (my calc, before Play's download compression). A release export template should be smaller than the debug one used today (not measured). The Play limit of about 200 MB compressed download for the base module is from memory: check it in `game-studio/docs/play-store-checklist.md` before the first AAB.
- Easy savings if needed: Timber's `screenshots/*.jpg` and Ball Connect's `screenshots/level_*.jpeg` are packed today (add `.gdignore`, as the licence audit says). This does not matter for MWM Play itself, since the sync never copies `screenshots/`.

## 7. Work order

1. **Upstream prep (source repos, one small commit each, each needs its own OK):** add progress saves to Ball Connect and Tile Explorer, and give Tile Explorer a `tests/capture.tscn`. Optional, because the adapter can work around it: make the `load_game()` paths in Spotless and Timber safe to call twice.
2. **Skeleton `projects/mwm-play/app/`:** `project.godot` from the studio template (portrait, `mobile`, `import_etc2_astc`, `quit_on_go_back=false`, MSAA off as the shell default), `Shell` and `PerfOverlay` autoloads, `shell/Launcher.tscn` with five 130 px+ tiles, CI workflow from `game-studio/templates`, new package name (the owner picks, e.g. `com.matswm.mwmplay`). Own git repo, `gh repo create`.
3. **Sync tooling:** `tools/sync_game.py`, token renamer, `tools/check_collisions.py`, pre-commit guard. Test it first on Ball Connect (no class_name, no autoloads, 7 paths).
4. **Games in order of risk, one commit each, all checks green after each:** Ball Connect → Water Sort (`IconButton` rename, save rename) → Tile Explorer (aspect keep, MSAA off) → Spotless (autoloads, `Shapes`/`Hud`/`IconButton`) → Timber Valley (39 classes, 272 paths, autosave, offline earnings, reset via `reload_current_scene`).
5. **Adapters + home/back:** for each game, a launch → play → back → launch-another-game capture loop in Xvfb (no stacked music, Master not muted, saves under the new names, settings restored). Screenshots of each game inside the shell compared with the standalone captures.
6. **Phone check by the owner:** PerfOverlay fps and memory after five game switches, on the phone and on the 32-bit tablet.
7. **Then the store layer:** parent gate, Google Play Billing one-time product, credits screen (Godot MIT, OFL for Fredoka), release keystore, AAB, target API 36, 16 KB page check (`game-studio/docs/play-store-checklist.md`).

## Unverified in this plan
- That Godot skips nested `project.godot` folders (affects only rejected option b).
- That `class_name` in a runtime-loaded PCK is not registered (affects only rejected option c).
- That `load_game()` in Spotless and Timber can safely run twice.
- Release-template `.so` sizes and the exact Play download limit.
- Nothing has run on a phone.
