# Validation and review

Validated locally with the official Luau CLI at source revision 2a3d8937c19c8fd9f7b72b6ec9068c62760e6588. Run scripts/check.py to reproduce with that compiler/interpreter.

- 32 pure-core tests: exact identity, unknown versus zero, budget boundaries, target protection, raw-grade scope, fresh roster, unrelated/existing tower rejection, outcome ambiguity, timeouts, stop-on-goal, Dungeon replay prohibition, transitions, log bounds, persisted settings, level readback, free replay limits, asynchronous map readback, scoped permission and selected-copy retention.
- 13 mocked Roblox tests: partial inventory, no invented fetch, ownership filtering, collection scope, single-flight lock, late replies after close, result visibility/ambiguity/truncation, cost slot indexing, early map reset, incomplete unit observation and finished-without-readable-result handling.
- All active source modules and main.lua compile with Luau; bundle is reproducible; active forbidden-API checks and unchanged loader checks pass.
- Archived v5 main.lua is byte-identical to the audited base revision.

A fresh independent reviewer found four Important problems: replay identity arriving asynchronously, stale stage after an early reset, capped unit scans masquerading as complete, and replay/cost confirmations carrying to other stages. Each now has regression coverage and was corrected. Selected-copy fallback, classified Minor by the reviewer, was corrected because it could falsely satisfy a chosen-copy goal. Passive outcome flicker and unreadable finished-state handling also have regression coverage.

No deferred minor findings remain. No current live Roblox, Delta or Android session was executed. UI rendering/input behavior, native memory/FPS, protocol signatures, replicated schemas, real placement acceptance, ability behavior, drops, current Rukia availability and complete dungeon progression remain unverified. Local passing tests are not evidence of successful unattended farming. CI configuration is included; hosted CI completion is separate from these local results.

## Implementation decisions

- Use a new controller and retain v5 as rollback, because patching the old coupled state/action/UI loops would retain the false-positive and concurrency hazards. Cost: legacy card/equip/queue tools are archived instead of active.
- Use explicit player-replicated Instances and recorded maps; no global client introspection. Cost: current table-based inventory may be unavailable and block farming.
- Block premium mutations and dungeon navigation without a verified current adapter. Cost: progression cannot be unattended yet.
- Bind confirmations to stage/mode/place; do not restore them from settings. Cost: manual reconfirmation on a different stage or new injection.
