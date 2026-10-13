# Doing Nothing

A Roblox game about doing absolutely nothing. Spawn in a night zen garden, sit in one
of 20 private booths, and once the "Hands off" countdown ends, the timer counts up
for as long as you touch nothing: no mouse, keys, screen, controller, or standing up.
Do anything and you lose. Continue from your time (25 Robux, doubling each continue
in the run) or Restart from 0:00 for free. Two live leaderboards in the plaza: longest
time doing nothing (all servers, ticking live) and top supporters.

## Run it in Studio

1. Install the Rojo plugin in Studio, and Rojo on your computer (`rokit install` here,
   or any Rojo 7.4+).
2. In this folder: `rojo serve`
3. Studio: open a new **Baseplate**, delete the `Baseplate` part, click **Rojo → Connect**.
4. **Game Settings → Security → Enable Studio Access to API Services** (for saving and
   leaderboards).
5. Press **Play**. The loading screen plays, then the night garden is built around you.

In Studio the Continue is free (no products set yet) and the 18-minute idle re-join is
switched off, because teleports don't work in Studio.

## Before publishing

1. **Max Players: 20** (Game Settings → Places), one per booth.
2. **Create the Continue products.** Creator Hub → your experience → Monetization →
   Developer Products. Make 15, named `Continue 1` … `Continue 15`, priced:

   | Step | Price | Step | Price | Step | Price |
   |---|---|---|---|---|---|
   | 1 | 25 | 6 | 800 | 11 | 25,600 |
   | 2 | 50 | 7 | 1,600 | 12 | 51,200 |
   | 3 | 100 | 8 | 3,200 | 13 | 102,400 |
   | 4 | 200 | 9 | 6,400 | 14 | 204,800 |
   | 5 | 400 | 10 | 12,800 | 15 | 409,600 |

   Paste each product ID into `src/shared/Config.luau` (`productId = 0` → your ID).
   The game reads each product's real price from Roblox, so the button always shows
   what the player will pay.
3. **Sounds (optional):** add `rbxassetid://` IDs for the phone and knock distractions in
   `Config.luau`. Without them, only the caption shows.
4. **Test the idle re-join in a live server.** Roblox disconnects players after about
   20 minutes with no input. At 18 minutes the server saves the run and re-joins the
   player to this place, and the timer carries on. This is the main thing to check in
   a published test: sit, don't touch anything for 20+ minutes, and confirm you are
   re-joined and your time continues.

## How it works

| Part | File |
|---|---|
| Loading screen (dark, drooping title, falling leaves, deadpan tips, Skip) | `src/first/LoadingScreen.client.luau` |
| Run rules: countdown, lose on input, Continue, Restart, resume (pure, tested) | `src/shared/Run.luau` |
| All settings: prices, booths, countdown, idle re-join, distractions | `src/shared/Config.luau` |
| Night garden lobby, 20 booths, boards, lighting | `src/server/Services/LobbyBuilder.luau` |
| Game service: chairs, server-side clock, Continue/Restart, idle re-join, booth screens | `src/server/Services/NothingService.luau` |
| Purchases: one ProcessReceipt, each purchase granted exactly once | `src/server/Services/Purchases.luau` |
| Saving: best time, Robux spent, Continue credits (atomic merges) | `src/server/Services/Store.luau` |
| Leaderboards: all-time + live sitters from every server | `src/server/Services/Leaderboards.luau` |
| Any-input detection | `src/client/Controllers/InputWatch.luau` |
| Camera facing your booth screen | `src/client/Controllers/CameraController.luau` |
| HUD and the "You moved." panel | `src/client/Controllers/Hud.luau` |
| Distractions | `src/client/Controllers/Distractions.luau` |

**Fairness rules built in** (Roblox: players must never be "misled, confused, or
pressured" into buying):
- the Continue price is always on the button, and the lost screen waits forever;
- distractions never copy Roblox's interface, never mention Robux, and disappear on
  the lost screen;
- the jokes only tease the player for moving, never for not paying;
- Continue credits are tied to their price step, and each purchase is recorded with its
  PurchaseId before Roblox is told it was granted.

## Checks

```
python3 tools/run_tests.py                  # needs the `luau` CLI on PATH
rojo build default.project.json -o build.rbxl
```

CI runs the tests, a Rojo build and a strict type check on every push.
