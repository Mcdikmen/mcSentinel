# mcSentinel

A FiveM admin monitoring resource for **Qbox** (`qbx_core`) servers. Runs entirely inside FiveM — no external process, no separate backend. All data is persisted via **oxmysql** and the admin dashboard is a NUI panel embedded in the resource.

## Features

- **In-game admin dashboard** — Overview, Players, Logs, Player Detail panels (open with `F8` or `/sentinel`)
- **Money monitoring** — Flags suspicious transactions above a configurable threshold
- **Anti-cheat detection** — Speed hack (including superjump via Z-velocity), teleport, godmode suspect; high-frequency 100 ms tick with multi-strike confirmation to eliminate false positives
- **Secure event architecture** — Per-session server-issued tokens authenticate all client reports; unauthorized event triggers are silently discarded
- **Rate limiting** — Detects event flooding from malicious clients
- **Multi-account detection** — Same IP reconnecting within a configurable time window
- **Live alert toasts** — In-game toast notifications for all flagged events (even when panel is closed)
- **Discord webhook** — Rich embeds for flagged events with configurable message templates
- **Admin management** — Ace-permission based; add/remove admins in-game or from console
- **Session tracking** — Full join/leave history per player
- **Admin notes** — Per-player notes visible in the dashboard

## Requirements

| Dependency | Version |
|---|---|
| [qbx_core](https://github.com/Qbox-project/qbx_core) | latest |
| [oxmysql](https://github.com/overextended/oxmysql) | latest |

## Installation

1. Clone or download this repository into your resources folder:
   ```
   resources/[standalone]/mcSentinel/
   ```

2. Add to `server.cfg` **after** `qbx_core` and `oxmysql`:
   ```
   ensure oxmysql
   ensure qbx_core
   ensure mcSentinel
   ```

3. Allow the resource to manage ace permissions in `server.cfg`:
   ```cfg
   add_ace resource.mcSentinel command.add_ace    allow
   add_ace resource.mcSentinel command.remove_ace allow
   ```

4. Start / restart your server. The four database tables are created automatically on first start.

5. Grant the **first admin** from the server console while the player is online:
   ```
   sentineladd [playerid]
   ```
   After that, admins can add/remove each other in-game with `/sentineladd` and `/sentinelremove`.

## Configuration

All settings are in `shared/config.lua`.

```lua
-- Threshold for flagging a money transaction (single amount)
Config.Thresholds.moneyDelta = 100000

-- Maximum events per second before exploit_rate is flagged
Config.Thresholds.eventRate = 50

-- Same-IP reconnect window for multi-account detection (seconds)
Config.Thresholds.loginGapSeconds = 5

-- On-foot speed limit (m/s) — above this triggers speed hack flag
Config.Thresholds.speedOnFoot = 15.0

-- Distance moved in a single tick to trigger teleport flag (meters)
Config.Thresholds.teleportDist = 500.0

-- Discord webhook (leave empty to disable)
Config.DiscordWebhook = ''

-- How often the event queue is written to the database (ms)
Config.FlushInterval = 3000
```

### Discord Webhook

Set `Config.DiscordWebhook` to your webhook URL. Message templates for each event type are customisable in `Config.DiscordMessages`.

Available template variables:

| Variable | Description |
|---|---|
| `{player}` | Player name |
| `{speed}` | Speed in m/s (speed hack) |
| `{x}` `{y}` `{z}` | World coordinates |
| `{dist}` | Distance teleported |
| `{from_x}` `{from_y}` | Teleport origin |
| `{to_x}` `{to_y}` | Teleport destination |
| `{last_health}` `{health}` | Health before/after (godmode) |
| `{action}` | Money action type |
| `{money_type}` | Money type (cash/bank/…) |
| `{amount}` | Transaction amount |
| `{reason}` | Transaction reason |
| `{json}` | Raw JSON data (first 400 chars) |

### Live Toast Notifications

Toasts appear in-game for every flagged event, even when the panel is closed. Disable with `/sentinelalerts` or permanently in config:

```lua
Config.Toast.enabled = false
```

### Character Fields

Control which fields appear on the Player Detail card:

```lua
Config.CharacterFields = {
    citizenid = true,
    phone     = true,
    birthdate = true,
    job       = true,
    cash      = true,
    bank      = true,
    crypto    = true,
}
```

## Usage

### Opening the Dashboard

| Method | Action |
|---|---|
| `F8` | Toggle panel (default keybind) |
| `/sentinel` | Toggle panel (chat command) |

### Admin Commands

| Command                      | Description                                      |
| ---------------------------- | ------------------------------------------------ |
| `/sentineladd [playerid]`    | Grant mcSentinel admin access to a player        |
| `/sentinelremove [playerid]` | Revoke mcSentinel admin access from a player     |
| `/sentinelalerts`            | Toggle live alert toasts on/off for your session |

All commands also work from the **server console** (use `0` as the source).

### Server Console Examples

```
# Add admin while player is online
sentineladd 5

# Remove admin while player is online
sentinelremove 5
```

### First Admin Setup Example

```cfg
# server.cfg — only these two lines are needed
add_ace resource.mcSentinel command.add_ace    allow
add_ace resource.mcSentinel command.remove_ace allow
```

```
# server console — run while the target player is online
sentineladd 1
```

## Dashboard Pages

| Page | Description |
|---|---|
| **Overview** | Server stats (online, total players, flagged events, all events) + last 20 alerts feed |
| **Players** | Searchable player list with online status, alert count, character name |
| **Player Detail** | Full profile: identifiers, characters, last 50 events, last 20 sessions, admin notes |
| **Logs** | Filterable event log — by type and/or flagged-only; 50 per page |

## Detected Event Types

| Type | Trigger | Flagged |
|---|---|---|
| `player_connect` | Player joins | No |
| `player_drop` | Player leaves | No |
| `money_tx` | Money change below threshold | No |
| `money_alert` | Money change above `moneyDelta` | Yes |
| `multi_account_flag` | Same IP reconnects within `loginGapSeconds` | Yes |
| `exploit_speed_hack` | On-foot speed or Z-velocity > `speedOnFoot` (100 ms tick, 2-strike) | Yes |
| `exploit_teleport` | Position delta > `teleportDist` in one tick | Yes |
| `exploit_godmode_suspect` | Health jumps > 50 pts to max while alive | Yes |
| `exploit_rate` | More than `eventRate` exploit reports/second | Yes |
| `resource_perf` | Periodic resource list snapshot | No |

## Database Tables

All tables are created automatically on resource start. Safe to restart — uses `CREATE TABLE IF NOT EXISTS`.

| Table | Description |
|---|---|
| `sentinel_players` | One row per unique license |
| `sentinel_sessions` | Join/leave history |
| `sentinel_events` | All events with `flagged` bit and JSON `data` |
| `sentinel_notes` | Admin notes per player |
| `sentinel_admins` | Admins granted via `/sentineladd` (persisted across restarts) |

## Adding a Custom Event Type

1. Detect the condition in the appropriate server event handler (or create a new file under `server/events/`).
2. Call `Sentinel_Push('your_event_type', playerId, dataTable, isFlagged)`.
3. Optionally add a Discord message template in `Config.DiscordMessages` and a filter option in `web/index.html`.

```lua
-- Example: detect a custom admin abuse event
Sentinel_Push('admin_abuse', playerId, {
    name   = GetPlayerName(src),
    action = 'spawned_weapon',
    weapon = weaponHash,
}, true)
```

## Contact

- **Discord Server:** [discord.gg/de8fABdPyf](https://discord.gg/de8fABdPyf)
- **Discord:** mcdikmen
- **Email:** muratcan.dikmen@outlook.com

## License

MIT © Mcdikmen — free to use, modify, and distribute.
