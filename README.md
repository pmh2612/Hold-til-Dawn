# Hold 'til Dawn (prototype)

Godot 4.7.2. Rules from the GDD live in `game.gd` (server only); `main.gd` is network, input, drawing and HUD.

## Run
- **Play locally / host:** open the project in Godot, press Play, choose a role, click **Host**. Others click **Join by IP** with the host's IP (UDP 7777).
- **Dedicated server:** `godot --headless --path . -- --server`, then every player joins by IP.
- The lobby leader (first to join) picks the mode and presses **Start** (needs at least one Engineer).

## Controls
WASD move, mouse aim, LMB attack, E (hold) gather / repair door (Engineer) / revive, Q bandage, C workbench (inside the base by day, then number keys), RMB healing flask (Healer), F (hold 2 s, Engineer at night) enter or leave the base through a closed door, V skip-day vote, Esc leave.

## What is in
- 5 day/night cycles on a 15 x 10 tile base with doors A (west), B (north), C (east), no south door; players enter only through doors, and at night only the Engineer (hold F) or anyone through a broken door.
- Night waves in a band 25-35 tiles in front of each attacked door (FML-04 budget x `SPAWN_MUL` = 3 in `game.gd`, playtest only; `SPAWN_ALL_SIDES` for every side), boss on nights 2 and 4, night-5 helicopter extraction.
- Daytime roamers beyond 20 tiles from the base (chance grows with distance, x `ROAM_MUL` = 2 for playtests, pairs, max 8); at dusk they walk to an attacked door.
- Enemy drops (GDD: Grunt 10%, Spitter 15%, Wrecker 20%, boss always; x `DROP_MUL` = 3 for playtests; resource nodes x `NODE_MUL` = 2): walk over to pick up, gone after 30 s, not from inside the base.

## Dev
- `-- --autohost` hosts and starts at once; add `--night` to jump to night 1. `-- --autojoin` joins 127.0.0.1 and starts.
- F9 (host, debug build) ends the current phase.
- Rules check: `godot --headless --path . -s tests/sim_check.gd`
