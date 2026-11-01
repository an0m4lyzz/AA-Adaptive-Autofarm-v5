# Targeted client-cache reader

The user's v6.0.2 live report confirms Loader exists, client modules have opaque numeric names, player inventory Instance roots are absent, and the account-balance reader works. More name-based traversal does not resolve ownership.

Implement an explicit manual, experimental reader: verify the exact Loader is reported as already loaded; retrieve its export once; inspect upvalues of only Loader.init and Loader.load_client_service, without calling either; identify named cached ItemInventoryServiceClient / StatsServiceClient / GUIService entries structurally, without fixed upvalue indices. Read only existing .module.session tables. No remote requests, service initialization, require of arbitrary numeric modules, hooks, GC enumeration, or repeated global scans.

Add a pure bounded parser for owned_units keyed by UUID, equipped_units slots, observed traits and actual item counts. Preserve unknown values; do not confuse stat potential multipliers with attack values. Detect exposed owner mismatch, conflicting UUIDs and stale schema. Follow the live service reference for cheap four-second refreshes only after explicit connection.

Use a single global pending-cache guard, eight-second deadline, late-result/lifecycle checks and one native lookup attempt per injection. Cache/VM behavior inside Delta is not verified: module cache isolation may differ from normal Roblox require behavior. If required APIs, loaded status or schema cannot be established, report an unsupported blocker; never initialize another service as a fallback.

Tests before implementation: parser identity/slots/materials/traits, malformed and truncated data, no source mutation, owner mismatch, bounded cache lookup; integration no startup lookup, unsupported APIs, Loader not loaded, cached registry success, late reply after close and timeout locks. Compile, rebuild reproducibly, run all tests, request independent review, then publish using an expected-head lease.

Historical code references (not current-patch certification): annguyen2311/andeptrai buff at a2f43d6; TrilhaX/scriptexec Testes/kaitunAA.lua at 97387f5; tfooio/zeno-hub-dist src/autoplay.lua at 5a3f913. Official Roblox ModuleScript documentation specifies caching per Luau environment; sUNC getloadedmodules specifies completed loaded modules only. No third-party code is executed or imported into the product.

## Validation record

Implemented manual reader, typed parser, report/UI control and reproducible bundle. Independent review identified two identity-alias ambiguity bugs; both are covered by failing-then-passing regressions. Registry entry replacement/removal is followed; wholesale Loader registry replacement and server freshness remain limitations. Source-to-target traits are protected even in a two-trait record. Battle-only observations cannot satisfy permanent acquisition.

Final local suite: 35 core + 34 adapter + 16 parser tests = 85 passing; active modules compile; bundle reproducibility, unchanged loader and API constraint checks pass. No current live cache read was performed here. Publishing must recheck the remote main revision and use an expected-head lease.
