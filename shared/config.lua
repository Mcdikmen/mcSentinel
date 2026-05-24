Config = {}

-- Qbox group names that are treated as admin (legacy reference; ace permission system is authoritative)
Config.AdminGroups = { 'admin', 'superadmin', 'god' }

-- Discord webhook URL (leave empty to disable)
Config.DiscordWebhook = ''

-- Discord message templates.
-- Available variables are listed per event type. {player} is available in all.
Config.DiscordMessages = {

    -- Variables: {player}, {speed}, {x}, {y}, {z}
    exploit_speed_hack = '🚨 **Speed Hack Detected**\n' ..
        '👤 **Player:** {player}\n' ..
        '💨 **Speed:** {speed} m/s\n' ..
        '📍 **Location:** {x}, {y}, {z}',

    -- Variables: {player}, {dist}, {from_x}, {from_y}, {to_x}, {to_y}
    exploit_teleport = '🚨 **Teleport Detected**\n' ..
        '👤 **Player:** {player}\n' ..
        '📏 **Distance:** {dist} m\n' ..
        '📍 **From:** {from_x}, {from_y}\n' ..
        '📍 **To:** {to_x}, {to_y}',

    -- Variables: {player}, {last_health}, {health}
    exploit_godmode_suspect = '🚨 **Godmode Suspected**\n' ..
        '👤 **Player:** {player}\n' ..
        '❤️ **Health:** {last_health} → {health} (abnormal increase)',

    -- Variables: {player}, {action}, {money_type}, {amount}, {reason}
    money_alert = '💰 **Suspicious Money Transaction**\n' ..
        '👤 **Player:** {player}\n' ..
        '💳 **Action:** {action}  |  **Type:** {money_type}\n' ..
        '💵 **Amount:** ${amount}\n' ..
        '📝 **Reason:** {reason}',

    -- Variables: {player}
    multi_account = '⚠️ **Multi-Account Suspected**\n' ..
        '👤 **Player:** {player}\n' ..
        'Multiple accounts detected for the same person.',

    -- Used for any undefined event type. All variables are available.
    default = '⚠️ **Suspicious Activity**\n' ..
        '👤 **Player:** {player}\n' ..
        '```\n{json}\n```',
}

-- Detection thresholds
Config.Thresholds = {
    moneyDelta      = 100000,  -- single transaction above this amount triggers an alert
    eventRate       = 50,      -- events per second above this triggers rate-limit flag
    loginGapSeconds = 5,       -- same IP reconnecting within this window triggers multi-account flag
    speedOnFoot     = 15.0,    -- m/s on-foot speed limit
    teleportDist    = 500.0,   -- meters moved in a single tick to trigger teleport flag
}

-- Fields shown on each character card in the player detail panel.
-- Set any field to false to hide it.
Config.CharacterFields = {
    citizenid = true,
    phone     = true,
    birthdate = true,
    job       = true,
    cash      = true,
    bank      = true,
    crypto    = true,
}

-- Live alert toast notifications (shown in-game when a flagged event occurs)
Config.Toast = {
    enabled  = true,   -- set to false to disable all toasts
    duration = 6000,   -- how long each toast stays on screen (ms)
    messages = {
        exploit_speed_hack      = '🚨 Speed Hack Detected\n👤 {player} [ID:{server_id}]  💨 {speed} m/s',
        exploit_teleport        = '🚨 Teleport Detected\n👤 {player} [ID:{server_id}]  📏 {dist} m',
        exploit_godmode_suspect = '🚨 Godmode Suspected\n👤 {player} [ID:{server_id}]  ❤️ {last_health} → {health}',
        money_alert             = '💰 Suspicious Transaction\n👤 {player} [ID:{server_id}]  💵 ${amount} ({action})',
        multi_account           = '⚠️ Multi-Account Suspected\n👤 {player} [ID:{server_id}]',
        default                 = '⚠️ {type}\n👤 {player} [ID:{server_id}]',
    },
}

-- How often (ms) the event queue is flushed to the database
Config.FlushInterval = 3000

-- Resource performance sampling interval (ms)
Config.PerfInterval = 15000
