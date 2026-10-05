# MWM Play

One Android app with calm puzzle and play games for children and families. No ads, no tracking, no data collected, works offline. Children can try every game for free; a parent can unlock everything with one payment behind a parent gate.

Website and privacy policy: https://play.mwmai.no

## Games inside

- Ball Connect
- Water Sort

More games join one at a time as they pass the child-safety checks in `docs/CHILD_UX_RESEARCH.md`.

## Layout

- `app/`: the Godot 4.6 project (portrait 1080x1920, Mobile renderer). The shell lives in `app/shell/`, each game in `app/games/<slug>/`.
- `tools/sync_game.py`: copies a game in from its own repo at a given commit and records the commit in `app/games/<slug>/SOURCE`. `tools/check_collisions.py` fails the build if two games share a class name, autoload or resource id.
- `docs/`: design spec, child UX research (46 rules with sources), merge plan, mockups.
- `site/`: the static page served at play.mwmai.no.

## Build

GitHub Actions builds a debug APK on every push (`.github/workflows/build-android.yml`). Nothing is built locally.

## Status

Version 0.1.0, early test build. The unlock button shows "Kommer snart" until Google Play Billing is wired in.
