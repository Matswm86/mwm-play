# Internet access in MWM Play

**Read this before adding anything that touches the network.**

MWM Play started as a fully local app: no `INTERNET` permission, nothing leaves the device. The released APKs up to 2026-10-05 still have zero permissions (see `QA_SLICE1_2026-10-05.md`, "Permissions").

On 2026-10-05 the owner decided that chess gets play between two devices, on the same Wi-Fi and online. Android grants permissions to the whole app through one manifest, so this decision means **the whole MWM Play app will ask for `INTERNET`**, not only the chess game. This file records why, what is allowed to use the network, and what must stay true.

## What uses the internet, and why

| Feature | Why it needs `INTERNET` | Status |
|---|---|---|
| Chess on two phones, same Wi-Fi | Android requires `INTERNET` for any socket, local network sockets included. | Planned (chess port not built) |
| Chess on two phones, online | The two phones meet through a relay server (chess.mwmai.no) so friends in different places can play each other. | Planned |
| One-time unlock (Google Play Billing) | The purchase is confirmed by Google Play. Whether the Billing library itself needs `INTERNET` in our manifest is **unverified** (`CHILD_UX_RESEARCH.md` rule 44). | Planned (needs Play Console account) |

Nothing else may use the network. Every other game, and chess against the computer or two players on one phone, works with no connection.

## Rules that keep the "no data collected" promise

1. **Chess moves are end-to-end encrypted.** Only the two phones can read them. The relay server forwards encrypted messages, keeps rooms in memory only, writes no logs and stores nothing. Google's Data safety rules say data "unreadable by you or anyone other than the sender and recipient as a result of end-to-end encryption does not need to be disclosed" (support.google.com/googleplay/android-developer/answer/10787469, read 2026-10-05).
2. **The encryption key never reaches the server** and is too long to guess. The server gets a room id; the secret travels separately (QR code or a long word code). A short code that both opens the room and makes the key is not allowed.
3. **No accounts, names, chat, matchmaking with strangers, analytics, ads or crash reporting.** Players join only by sharing a room code with someone they know.
4. **The Wi-Fi and online buttons sit behind the parent gate.** A child cannot open a network connection alone.
5. **Unverified:** whether the IP address the relay sees counts as "collected" on the Data safety form. Check before submitting the form.

## What changes on the store page and privacy text when this lands

- "Works offline" becomes "Every game works offline. Chess can also be played online with a friend (a parent turns it on)."
- `site/privacy/index.html` and the in-app privacy screen (`shell/screens/Privacy.gd`) must list exactly the rows in the table above, nothing more.
- The Data safety form declares the relay's in-memory processing (Google requires the declaration even though ephemeral processing is not shown on the listing).
- Until chess online ships, the app and its texts stay as they are: no `INTERNET` permission.
