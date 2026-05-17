-- DB bootstrap + all query functions.

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `sentinel_players` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `name`       VARCHAR(64)  NOT NULL,
            `license`    VARCHAR(64)  NOT NULL UNIQUE,
            `license2`   VARCHAR(72)  DEFAULT NULL,
            `discord`    VARCHAR(32)  DEFAULT NULL,
            `steam`      VARCHAR(32)  DEFAULT NULL,
            `ip`         VARCHAR(45)  DEFAULT NULL,
            `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX(`license`),
            INDEX(`updated_at`)
        );
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `sentinel_sessions` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `player_id`  INT UNSIGNED NOT NULL,
            `ip`         VARCHAR(45)  NOT NULL,
            `joined_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `left_at`    DATETIME     DEFAULT NULL,
            `reason`     VARCHAR(255) DEFAULT NULL,
            INDEX(`player_id`)
        );
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `sentinel_events` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `player_id`  INT UNSIGNED DEFAULT NULL,
            `type`       VARCHAR(32)  NOT NULL,
            `data`       JSON         NOT NULL,
            `flagged`    TINYINT(1)   NOT NULL DEFAULT 0,
            `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX(`type`),
            INDEX(`flagged`),
            INDEX(`created_at`),
            INDEX(`player_id`)
        );
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `sentinel_admins` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `license`    VARCHAR(64)  NOT NULL UNIQUE,
            `name`       VARCHAR(64)  NOT NULL,
            `granted_by` VARCHAR(64)  NOT NULL,
            `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX(`license`)
        );
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `sentinel_notes` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `player_id`  INT UNSIGNED NOT NULL,
            `admin`      VARCHAR(64)  NOT NULL,
            `note`       TEXT         NOT NULL,
            `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX(`player_id`)
        );
    ]])

    -- Migrations: safely add columns that may not exist in older installs.
    MySQL.query([[
        ALTER TABLE `sentinel_players`
        ADD COLUMN IF NOT EXISTS `license2` VARCHAR(72) DEFAULT NULL
    ]])

    print('^2[mcSentinel]^0 Database tables ready')
end)

-- ─── Helper functions ────────────────────────────────────────────────────────

function DB_UpsertPlayer(name, license, license2, discord, steam, ip, cb)
    MySQL.query([[
        INSERT INTO sentinel_players (name, license, license2, discord, steam, ip)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name=VALUES(name), license2=VALUES(license2), ip=VALUES(ip), updated_at=NOW()
    ]], { name, license, license2, discord, steam, ip }, function()
        MySQL.scalar('SELECT id FROM sentinel_players WHERE license = ?', { license }, cb)
    end)
end

function DB_InsertEvents(rows, cb)
    if #rows == 0 then return end
    local params = {}
    for _, r in ipairs(rows) do
        params[#params + 1] = { r.player_id, r.type, json.encode(r.data), r.flagged and 1 or 0 }
    end
    MySQL.prepare(
        'INSERT INTO sentinel_events (player_id, type, data, flagged) VALUES (?, ?, ?, ?)',
        params, cb
    )
end

function DB_CloseSession(playerId, reason)
    MySQL.query([[
        UPDATE sentinel_sessions SET left_at = NOW(), reason = ?
        WHERE player_id = ? AND left_at IS NULL
        ORDER BY joined_at DESC LIMIT 1
    ]], { reason, playerId })
end

function DB_OpenSession(playerId, ip)
    MySQL.insert('INSERT INTO sentinel_sessions (player_id, ip) VALUES (?, ?)', { playerId, ip })
end
