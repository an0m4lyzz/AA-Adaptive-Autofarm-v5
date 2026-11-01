# Mobile testing checklist (Delta)

## First launch
1. Launch Anime Adventures and enter a low-stakes Story stage.
2. Execute the loadstring in Delta.
3. Confirm that the menu appears.
4. Scan your equipped and owned units and inspect the recommendations.
5. Enable the automatic features one at a time.

## Placement and upgrade verification
- Check whether placed units actually appear.
- Check that placement and upgrade costs deduct correctly.
- Check that the unit role and priority report matches the units you own.
- Stop the script immediately if it places or upgrades the wrong units repeatedly.

## Map and boss learning
- Run through several waves while inspecting live enemy observations.
- Compare detected air, shield, regen and boss types to actual enemies.
- Copy the map/boss/team diagnostics report after the wave.

## Event testing
- Do not assume normal-loadout placement applies to events that supply random towers or spells.
- Treat automatic card picking and matchmaking as experimental.
- Verify all card votes and rejoining commands manually before unattended usage.

## Troubleshooting
- Menu does not appear: verify game and executor compatibility.
- No units scanned: current client state may not expose inventory data.
- No placement: current remote call or map geometry may be incompatible.
- Cannot equip: no verified equip action has been captured.

This is an unverified experiment; never assume that a syntax check means the script works in-game.


## Unattended recording test (Fool's Hunt)

1. Execute the loadstring, then select MODE: Event.
2. Keep START FULL AUTO OFF. The logger still runs.
3. Leave AUTO-LOG RUN and AUTO-COPY CARDS / BOSSES / END ON.
4. Play the event normally (manual tower placement and card selection).
5. The script will attempt to capture cards, enemy types, bosses, checkpoints (waves 1, 5, 10, 15, 20, 25, 30), and the end result automatically.
6. On completion or defeat, the cumulative report is copied automatically when the executor supports clipboard access. Paste it in ChatGPT. If clipboard was overwritten, use COPY COMPLETE AUTO REPORT.
7. Check SHOW AUTO REPORT STATUS for the local backup filename and whether writing succeeded.

**Limitations:** Results and cards must be visible to the client. The recorder is read-only but executor behavior is untested on this device. If the game teleports before reporting finishes, the last events may only be in the saved file or current in-memory session.
