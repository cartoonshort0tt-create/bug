# Bug Catcher Kingdom

A Roblox bug-catching collection game. This repo is the Rojo project for the
**Meadow prototype** (roadmap weeks 1–2): walk up to a bug, hit the timing ring,
fill your bag, sell, buy a better net and unlock the Forest gate. The design
blueprint (v1.2) is on the Bug Catcher Kingdom canvas.

## Run it in Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` here
   (installs Rojo 7.4.4 from `rokit.toml`). Install the Rojo plugin in Studio too.
2. Start the sync server:
   ```
   rojo serve
   ```
3. In Studio: open a new Baseplate, delete the `Baseplate` part, then click
   **Rojo → Connect**.
4. Press **Play**. The server builds a greybox Sunny Meadow, spawns 25 bugs and
   prints the economy check to the Output window.

**Saving in Studio:** turn on *Game Settings → Security → Enable Studio Access to API
Services*. Without it, data loads as defaults and is not saved (on purpose: the game
never overwrites real data when the DataStore is unavailable).

**Controls:** the big **SWING** button (bottom right), `E` on keyboard or `R2` on
a gamepad. First tap starts the ring on the highlighted bug; tap again while the
shrinking white circle is inside the green band. The gold line is a perfect hit.

## What's in the prototype

| System | Where | Notes |
|---|---|---|
| Global weather clock | `src/shared/WeatherClock.luau` | Weather is a pure function of zone + server time, so every server agrees and forecasts are always true. Day/dawn/night, Rainbow after storms, Eclipse every 3 h. |
| Spawn odds | `src/shared/SpawnOdds.luau` | Per-zone tables, tiers drop out when no bug is available, tiered luck exponent, ×3 boost weathers. Shared by server and client. |
| Configs | `src/shared/Config/` | All 48 bugs, 12 nets, 8 zones, weather tables, rarity and catch tuning, with v1.2 numbers. |
| Economy check | `src/shared/EconomyCheck.luau` | Recomputes coins per catch from the configs; fails if any zone isn't 2.7–3.3× the previous one. |
| Saving | `src/server/Services/DataService.luau` | Session-locked DataStore (no duplication on rejoin), autosave with jitter, release on leave, save on shutdown. |
| Catching | `src/server/Services/CatchService.luau` | Server-authoritative, lag-tolerant timing ring (judged at the client's synced hit time), reach and Power checks, bug reservation, rate limiting, perfect-rate flagging, combo luck, first Golden Ladybug. |
| Spawning | `src/server/Services/SpawnService.luau` | Keeps each zone stocked; bugs whose time or weather ends fly away; personal spawns. |
| Economy | `src/server/Services/EconomyService.luau` | Sell Stand, Net Shop and zone gate via ProximityPrompts. |
| World | `src/server/Services/WorldService.luau` | Greybox Meadow. Build the real map in Studio with parts named `SellPad`, `NetShop`, `ForestGate` inside `Workspace.Meadow` and the code uses yours. |
| HUD | `src/client/Controllers/` | Coins, bag, net, weather + next special weather, toasts, timing ring, Swing button, bug bobbing and name tags. |

## Checks

```
python3 tools/run_tests.py     # needs the `luau` CLI on PATH
rojo build default.project.json -o build.rbxl
```

CI (`.github/workflows/ci.yml`) runs the tests, a Rojo build and a strict type
check against the Roblox API on every push.

## Next steps (roadmap)

- Weeks 3–5: Forest and Swamp maps, Bugdex UI with the Odds button, bag upgrades,
  forecast board.
- Weeks 6–8: pets, Bug Hotel, quests, terrarium, Desert, Metamorphosis.
- Weeks 9–10: party luck, Swarm Hunts, game passes and developer products
  (ProcessReceipt through DataService), Boosted tag.
