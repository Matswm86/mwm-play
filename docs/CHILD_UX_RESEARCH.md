# MWM Play: child UX and pedagogy research (2026-10-05)

Source: scientific-literature-researcher run, 2026-10-05. Claude spot-checked the Anthony 2019 preprint by hand (edge padding "almost doubling" misses, points + prizes raising completion 73% to 97%, holdovers): all three match the PDF text.

## Verdict

QUALIFIED. Touch/gesture rules and manipulative-design rules rest on peer-reviewed studies (Anthony 2019, Nacher 2015, Radesky 2022, Meyer 2019). Stopping cues, praise and co-play are moderate to weak. Parent gates: NO peer-reviewed study of gate effectiveness was found, so that section is guideline plus reasoning.

Gaps with no sourced number: choices per screen, minimum text size for children, haptics, mm data for ages 3-4 (Vatavu 2015 not reachable).

Numbers marked (my calc) or (assumption) come from the researcher, not from a source.

## Strength key

Strong = replicated across peer-reviewed studies. Mod = one peer-reviewed study. Weak = guideline / industry practice. Rule = binding platform or legal requirement. Std = WCAG. Mine = reasoning, untested.

## Design-rule checklist

### Touch

| # | Rule | Number | Source | Strength |
|---|---|---|---|---|
| 1 | Main game objects and buttons for ages 4-7 | >= 12.7 mm ~ 80 dp (my calc); Godot px = mm x dpi / 25.4 | Anthony 2019: child miss rate ~4-5% at 12.7 mm | Mod-Strong |
| 2 | Floor for secondary UI, ages 8-10 | >= 9.5 mm ~ 60 dp (miss ~9-12%) | Anthony 2019 | Mod-Strong |
| 3 | Never a child target under 6.35 mm / 40 dp | miss ~22-31% | Anthony 2019 | Mod-Strong |
| 4 | Gap between targets | >= 8 dp adult floor, more for children | Google a11y help | Weak |
| 5 | Hit area larger than the drawing | ~25% pad (assumption) | Anthony Table 2 | Mod |
| 6 | No targets on the bottom edge (wrist rest) | bottom strip free | Sesame 2012 p.11 | Weak |
| 7 | Top/side targets: hit area runs to the screen edge | inset gap ~doubles misses | Anthony Fig. 6 | Mod-Strong |
| 8 | Filter holdovers (repeat touch on the previous target) | start ~300 ms (assumption), tune | Anthony p.6 | Mod / Mine |
| 9 | Core gameplay = tap and drag | tap ~94%, drag ~91% at age 2-3 | Nacher 2015 | Mod |
| 10 | No long press or double tap in gameplay; double tap only as a guard on "leave game" | long press ~50%, double tap ~62% | Nacher 2015; Sesame p.7 | Mod |
| 11 | No two-finger rotation, shape drawing, tilt/shake | 2-finger rot ~41%; shape recog ~66% at 5 | Nacher; Anthony p.9 | Mod |
| 12 | Drag snaps when close; partial drags accepted | snap ~half a target (assumption) | Nacher DG1; Sesame p.6 | Mod/Weak |
| 13 | Ball Connect: also allow tap cell, then tap cell | single-pointer alternative | WCAG 2.5.1 | Std |
| 14 | Racer hold-steer: latest touch wins, ignore resting palm, no flick/tilt | | Sesame p.14; Nacher | Weak/Mod |
| 15 | Feedback on touch-down, action on release inside hit area | | Sesame vs WCAG 2.5.2, resolved | Std/Mine |
| 16 | No reflex demands at the easiest Breakout/racer level | children slower, not more accurate | Anthony p.11; Nacher DG3 | Mod |

### Pre-readers

| # | Rule | Number | Source | Strength |
|---|---|---|---|---|
| 17 | Every instruction spoken AND shown; action word last; skippable | | Sesame pp.12-13 | Weak |
| 18 | Idle hint (glow on next move) | after 6-8 s idle | Sesame p.4 | Weak |
| 19 | Sound + visual on every accepted touch | same frame | Sesame p.13; Anthony Table 2 | Weak/Mod |
| 20 | Home icon always in the same place; conventional icons; no scrolling | | Sesame pp.8, 11-12 | Weak |
| 21 | Choices per screen: few, then playtest with 4-5 year olds | no sourced number | none | Gap |

### Parent gate

| # | Rule | Number | Source | Strength |
|---|---|---|---|---|
| 22 | Everything adult (unlock, settings, info, credits) behind ONE gate; nothing purchase-related visible to the child | | Apple 1.3; Meyer 2019; Radesky 2022 | Rule/Mod |
| 23 | Gate: random 3-digit code spelled in Norwegian words ("sju - fire - to"), numeric keypad, new code each try, no per-digit hint, voice says "Hent en voksen" | 3 digits | reasoning; Apple voiceover tip | Mine |
| 24 | No hold-to-unlock gates | | inferred from Nacher | Mine |
| 25 | Purchase only via Google Play Billing (Google re-verifies every purchase in apps for ages <= 12) | | Google Play help 1626831 | Rule |

### Healthy play

| # | Rule | Number | Source | Strength |
|---|---|---|---|---|
| 26 | Never auto-start the next level; calm "done" screen needs a tap | 0 autoplay | Hiniker 2018; ICO std 5 | Mod/Rule-UK |
| 27 | Banned: streaks, daily rewards, "come back tomorrow", countdowns, limited-time offers, characters urging play or begging, guilt on quit | 0 | Radesky 2022 | Mod |
| 28 | Pause anywhere; progress always saved; quitting costs nothing | | ICO std 5 | Rule-UK |
| 29 | Optional parent-set play limit that ends at the next natural stopping point | parent sets minutes | Hiniker 2016 | Weak |
| 30 | Finish rewards OK (star, sticker) tied to the task, never to time or return visits | | Anthony p.5 (73%->97%); Radesky | Mod |

### Feedback and frustration

| # | Rule | Number | Source | Strength |
|---|---|---|---|---|
| 31 | Wrong move: gentle cue -> hint -> show answer; undo always; no game over for 4-7 | 3 steps | Sesame p.4 | Weak |
| 32 | Praise the action ("Du fikk alle ballene i riktig ror!"), not the child ("du er så flink") | | Mueller & Dweck (contested); Rhodes 2019 | Weak-contested |
| 33 | Music low; separate mute in the parent area; haptics off by default | | Sesame p.13; haptics gap | Weak/Gap |

### Visual

| # | Rule | Number | Source | Strength |
|---|---|---|---|---|
| 34 | Text contrast | >= 4.5:1 (large >= 3:1) | WCAG 1.4.3 | Std |
| 35 | Pieces and UI vs background | >= 3:1 | WCAG 1.4.11 | Std |
| 36 | Colour never the only cue: each ball/liquid colour also gets a shape or pattern | up to 8% of boys colour-blind | WCAG 1.4.1 | Std |
| 37 | Flashes (bursts, brick breaks) | <= 3 per second or below area threshold | WCAG 2.3.1; Epilepsy Society | Std |
| 38 | Racer/Breakout: no high-contrast moving or flickering stripes | | Epilepsy Society | Weak |
| 39 | "Less motion" switch in parent area (shake, parallax, particles off) | toggle | WCAG 2.3.3 | Std |
| 40 | Child text sans-serif, size playtested | no sourced number | Sesame p.10 | Weak/Gap |

### Co-play

| # | Rule | Source | Strength |
|---|---|---|---|
| 41 | A take-turns mode where it fits; child-teaches-adult moments | Takeuchi & Stevens 2011; Hirsh-Pasek 2015 | Weak |
| 42 | Parent area: short "how to play together" tip per game | Sesame p.5 | Weak |

### Privacy

| # | Rule | Source | Strength |
|---|---|---|---|
| 43 | No third-party SDK except Play Billing; no analytics, crash SDK, ad ID, location | Play Families policy; Apple 1.3 | Rule |
| 44 | Drop INTERNET permission if billing works without it (verify); no own network calls | unverified | Mine |
| 45 | No accounts, chat or external links in the child area | Apple 1.3; Play Families | Rule |
| 46 | Privacy text says no personal data; re-check if Norway raises the consent age 13 -> 15 | Lovdata § 5; Medietilsynet 2025-10-07 | Rule |

## Counter-considerations

1. Free-to-try is close to what Meyer 2019 codes as "full-app teasers" (advertising, 46% of apps). It stays clean only if the child never sees locked items they are urged to want: no padlocks in games, no character mentioning the full version. Offer lives in the gated parent area only.
2. Rewards work (points + prizes 73% -> 97% completion). The evidence argues against time/return-visit rewards, not against a star for finishing.
3. Young children can do more gestures than the cautious rules assume (Nacher: two-finger scale ~94%); tap + drag only is a safety choice.
4. Praise evidence is contested (Mueller & Dweck vs Li & Bates replication failure).
5. The one field test of hard lock-outs (Coco's Videos) did not reduce viewing; prefer app-led endings at natural stopping points.
6. Touch data is from 2011-2017 devices; no re-test on modern 6-7 inch phones.

## Not checked

Vatavu 2015 full text; Cimpian 2007; Hiniker 2016 full paper (press release only); haptics; text size; choices per screen; dynamic difficulty; motion sickness in mobile 3D for kids; EU DSA Art. 28; Forbrukertilsynet games guidance; Play Data safety form rules; whether Godot Play Billing needs INTERNET; whether Godot exposes OS reduced-motion.

## Sources (fetched 2026-10-05 by the researcher unless marked)

- Anthony et al. 2019, IJHCS 128 (preprint): https://init.cise.ufl.edu/wp-content/uploads/sites/378/2019/03/anthony-et-al-IJHCS2019-MTAGIC-final-preprint.pdf
- Nacher et al. 2015, IJHCS 73: https://riunet.upv.es/handle/10251/64752
- Radesky et al. 2022, JAMA Netw Open: https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2793493
- Meyer et al. 2019, J Dev Behav Pediatr 40: https://blogs.ubc.ca/etec523/files/2021/01/00004703-201901000-00004.pdf
- Hiniker et al. 2018 (abstract): https://faculty.washington.edu/alexisr/CocosVideos.pdf
- Hiniker et al. 2016 (UW news): https://www.washington.edu/news/2016/05/05/two-minute-warnings-make-kids-screen-time-tantrums-worse/
- Mueller & Dweck 1998 (abstract): https://www.columbia.edu/cu/psychology/courses/3615/Readings/Mueller_Dweck.pdf
- Li & Bates replication (title + snippet): https://mrbartonmaths.com/resourcesnew/8.%20Research/Mindset/Mindset%20replication.pdf
- Rhodes et al. 2019 (abstract): https://swh.princeton.edu/~sjleslie/Subtle%20Linguistic%20Cues.pdf
- Hirsh-Pasek et al. 2015 (summary): https://www.psychologicalscience.org/publications/educational-apps.html
- Takeuchi & Stevens 2011: https://joanganzcooneycenter.org/wp-content/uploads/2011/12/jgc_coviewing_desktop.pdf
- Sesame Workshop 2012: https://joanganzcooneycenter.org/wp-content/uploads/2020/02/SesameWorkshop-2012.pdf
- Epilepsy Society 2023: https://epilepsysociety.org.uk/sites/default/files/2023-07/PhotosensitiveepilepsyJuly2023.pdf
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- Google touch targets: https://support.google.com/accessibility/android/answer/7101858
- Google Play Families policy: https://support.google.com/googleplay/android-developer/answer/9893335
- Google Play purchase verification: https://support.google.com/googleplay/answer/1626831
- Apple guidelines: https://developer.apple.com/app-store/review/guidelines/
- COPPA 16 CFR 312.2: https://www.law.cornell.edu/cfr/text/16/312.2
- ICO children's code std 5 and 13: https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/age-appropriate-design-a-code-of-practice-for-online-services/
- GDPR Art. 8: https://gdpr-info.eu/art-8-gdpr/
- Personopplysningsloven § 5: https://lovdata.no/lov/2018-06-15-38/§5
- Colour vision snippet only: https://pmc.ncbi.nlm.nih.gov/articles/PMC12385717/
