# Anime Adventures Adaptive Autofarm v5 (Experimental)

An experimental **mobile-friendly Roblox Lua script** targeting Anime Adventures with Delta. This project is **not affiliated with Roblox or the Anime Adventures developers**.

## Delta loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua"))()
```

## Intended features

- Scans available equipped and owned units to recommend a team for the map.
- Observes enemy types and potential counters, including air, shields, regeneration and bosses.
- Estimates suitable placements, upgrade priorities and map threat history.
- Offers a touch-friendly configuration UI and diagnostic reports.
- Includes experimental event queue learning, card recommendations and replay support.


## New: in-game card advice and big rewards (experimental)

The mobile menu now uses **six touch-friendly tabs**. It opens on **CARDS** by default:

| Tab | Features |
| --- | --- |
| **PLAY** | Mode selector and Start/Stop Full Auto |
| **CARDS** | Card advisor, auto-pick toggle, strategies, AprilCoins |
| **FARM** | Placement, upgrades, abilities, wave control and limits |
| **REPORTS** | Auto-run logging, clipboard copies and diagnostics |
| **UNITS** | Roster and team scan, recommendations, equip settings |
| **OTHER** | Event rejoin learning and close button |

For **Fool's Hunt**, go to **PLAY** to confirm MODE: Event, and keep START FULL AUTO OFF if manually placing/upgrading towers. In **CARDS**, keep CARD ADVISOR ON (default), optionally turn on AUTO CHOOSE BEST CARD (default OFF), then choose SAFE CLEAR, BALANCED, or BIG REWARDS. A floating PICK banner provides suggestions whenever the script detects valid cards.

Changing tabs does **not** enable autofarming or change saved settings. Auto-pick is independent of full farming. Turning the card advisor OFF also turns auto-pick OFF. A saved auto-pick ON state will reactivate the adviser on the next load.

**Big Rewards** assigns greater weight to visible AprilCoins bonuses; when several cards give the same bonus, it tends to prefer the lower-risk curse. It does **not** guarantee more currency, a clear, or the optimal choice. Aggressive curses can end a run sooner.

**Limitations:** The card detection is based on client-visible GUI labels, and clicking depends on what Delta supports. Auto-clicking is attempted only for a limited number of readable choices with a scoring margin; close calls, high-risk options and target-specific spells are left for manual selection. A reported input attempt is not server confirmation. Verify behavior in a supervised run before relying on it.

## Mobile crash hotfix (November 1, 2026)

The latest main.lua disables the global `__namecall` hook on startup and avoids an automatic `getgc(true)` inventory scan when a manual Event run starts. It also pre-filters candidate card buttons before deep UI traversal and reduces scanning frequency.

**After a crash, fully close Roblox and reopen it before using the same loadstring.** Old injected hooks can remain in the running process even after replacing main.lua. For the first test, execute in the lobby, keep FULL AUTO OFF and use the CARDS menu. Do not run the loadstring repeatedly within the same Roblox session while troubleshooting.

Event action signature recording and event/equip join-action learning require the hook and are therefore disabled by default in this stability build. The card advisor, on-screen recommendations, and basic run logging do not depend on that hook. If the app still crashes before the GUI appears, stop testing rather than repeatedly injecting it; check the executor's compatibility and try a clean unmodified game session.

## Goal farming: Rukia or Griffin (new experimental presets)

In the **PLAY** tab, choose **FARM TARGET**: OFF → RUKIA → GRIFFIN. The target is saved and preselects the associated mode. **CHECK FARM READINESS** checks whether the normal auto-placement prerequisites are visible. **COPY FARM GUIDE / CHECKLIST** copies target-specific steps. FULL AUTO does not turn on just by selecting a goal.

**Rukia / Snow Reaper (War):** selects Dungeon mode. Obtain a dungeon key and enter the randomly generated 20-depth run manually. Rukia is a chance-based rare/golden chest reward after dungeon progression. Prioritize rare chests and useful chest-conversion perks such as Philosopher's Stone. Because random tile/room choices, chest opening, and key inventory are not tested, **those steps are manual**. The preset prevents automatic replay votes to avoid accidental repeat key consumption. This is a combat-autofarm *foundation*, **not** an unattended 20-depth dungeon auto-run.

**Griffin:** selects Infinite mode. Infinite modes can give Gems by wave progression; obtain the regular Griffin from its summon banner **only while available**. Then use Griffin for the 7,500-takedown ascension requirement. Current banner status is not detected. **Auto-summoning, resource spending, Mythic sacrifices, and egg ascension are disabled**, because neither their current UI paths nor safe confirmations have been verified.

To test existing combat automation for a selected target, enter a supported match manually, verify your roster through the UNITS menu, and use CHECK FARM READINESS first. If required unit IDs, enemy path objects, or the placement endpoint are missing, FULL AUTO refuses to start. The older generic combat engine is still experimental and has **not** been verified to complete current Dungeon/Infinite stages. The mobile stability hotfix remains active; startup hooks and automatic GC scans remain disabled. Don't leave the farm unattended until placements, upgrades, stage transitions, and rewards are verified in a supervised run.

## Fool's Hunt fully automatic play: current status

**Not ready for unattended Wave 30 runs.** The game's random offered units and spells are not part of the standard equipped roster, and the tested event instance did not expose the expected `_ENEMIES` folder. Existing generic auto-placement and auto-upgrade cannot be assumed to work in this event, regardless of the card strategy. The **CHECK EVENT AUTO-PLAY READINESS** button in the **PLAY** tab reports known blockers.

To gather the exact event-specific inputs without manually copying each wave, the recorder now attempts to log **EVENT ACTION SHAPE** entries for relevant user-originated actions (remote name and argument types only), plus a **WORKSPACE PROBE** summary of visible folder names. It deliberately omits UUID values and full argument contents. This data may not appear on executors where read-only call interception is unavailable, and it does not make placement automatic yet.

The card advisor now rates early enemy-speed curses more cautiously. This adjustment is heuristic and still needs to be verified in a real match. **Do not enable generic Full Auto for unattended Fool's Hunt play** until its random-unit and spell paths have been tested.

## New in v5.1: automatic run reports

You **do not need to start the autofarm** to record a normal Event run.

- **AUTO-LOG RUN** is ON by default. The script records map/mode and equipped units at the start, unit/upgrade snapshots every 5 waves, first sightings of bosses and enemy traits, visible modifier-card choices, and the result screen when detected.
- **AUTO-COPY CARDS / BOSSES / END** is ON by default. A cumulative report is automatically copied to the clipboard when cards appear, bosses are seen, or a run ends. The clipboard holds only the latest copy, so avoid overwriting it before pasting.
- If Delta supports \`writefile\` or \`appendfile\`, it also stores a persistent text file called \`K_AA_AutoReport_<your-user-id>_<place-id>.txt\` in the executor workspace.
- **COPY COMPLETE AUTO REPORT** can be used at any time to recover the current in-memory report. **SHOW AUTO REPORT STATUS** reveals whether local saving succeeded.
- If a match ends via a teleport before the end screen is visible, the last collected file may be incomplete. Some event cards may not be detectable from the client GUI. Recording is best-effort and has not yet been live-tested.

For a safe first test, **leave START FULL AUTO OFF**, set MODE to Event, and play normally. The recorder makes observations without trying to place units, buy upgrades, select cards, or join the next event.

## Getting started

1. Join Anime Adventures on a mobile device and open Delta.
2. Execute the loadstring above.
3. In an easy Story stage, scan your equipped units and generate a team recommendation.
4. Observe the first placements and upgrades with the autofarm enabled.
5. Use the **COPY MAP / BOSSES / TEAM COUNTERS** button to capture diagnostics if anything fails.

## Limitations and safety

- **Not live-tested** in the current Anime Adventures build or on Delta.
- **Do not assume all modes are fully autonomous.** Certain event tower offers, spells, dungeon branches, matchmaking and card voting still need in-game verification.
- Automatic equipping is **off by default** until an actual equip action is learned and verified.
- Enemy/boss intelligence is restricted to client-visible or previously observed information; unseen future waves cannot be guaranteed.
- A Lua syntax check alone does not confirm game compatibility or successful runs.
- Using an executor can violate Roblox/game rules and may result in account action. Use at your own risk.
- Review remotely loaded code before execution, as changes to `main.lua` can change what the loadstring executes.

## Files

- `main.lua`: autofarm Lua source.
- `loadstring.txt`: one-line loader for easy copying.
- `TESTING.md`: mobile testing checklist and troubleshooting.

Created to be tested incrementally; this is not a guaranteed perfect-run script.
