-- Tracks player connections and sessions via Qbox events.
-- Also manages per-session security tokens used to authenticate client exploit reports.

local recentLoginsByIp = {}

-- ─── Token system ─────────────────────────────────────────────────────────────

local playerTokens = {} -- [src] = token string

local function generateToken()
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local t = {}
    for i = 1, 40 do
        t[i] = chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return table.concat(t)
end

-- Called by exploit.lua to validate a token accompanying a client report.
function ValidateClientToken(src, token)
    if type(token) ~= 'string' or #token ~= 40 then return false end
    return playerTokens[src] ~= nil and playerTokens[src] == token
end

-- ─── Player load / drop ───────────────────────────────────────────────────────

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    local identifiers = {}
    local license, license2, discord, steam, ip = nil, nil, nil, nil, 'unknown'

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        identifiers[#identifiers + 1] = id
        if     id:sub(1, 9) == 'license2:' then license2 = id
        elseif id:sub(1, 8) == 'license:'  then license  = id
        elseif id:sub(1, 8) == 'discord:'  then discord  = id:sub(9)
        elseif id:sub(1, 6) == 'steam:'    then steam    = id:sub(7)
        elseif id:sub(1, 3) == 'ip:'       then ip       = id:sub(4)
        end
    end

    if not license then license = license2 end
    if not license then return end

    -- Issue session token for this player
    local token = generateToken()
    playerTokens[src] = token
    TriggerClientEvent('mcSentinel:init', src, token)

    local name = GetPlayerName(src)
    local now  = os.time()

    local flagMulti = recentLoginsByIp[ip] and (now - recentLoginsByIp[ip]) < Config.Thresholds.loginGapSeconds
    recentLoginsByIp[ip] = now

    DB_UpsertPlayer(name, license, license2, discord, steam, ip, function(pid)
        if not pid then return end
        DB_OpenSession(pid, ip)
        OnlineMap[pid] = src

        if flagMulti then
            Sentinel_Push('multi_account_flag', pid, { name = name, ip = ip }, true)
        end

        Sentinel_Push('player_connect', pid, { name = name, ip = ip }, false)
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    playerTokens[src] = nil

    local license = nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id:sub(1, 8) == 'license:' then license = id break end
    end

    if license then
        MySQL.scalar('SELECT id FROM sentinel_players WHERE license = ?', { license }, function(pid)
            if pid then
                DB_CloseSession(pid, reason)
                OnlineMap[pid] = nil
            end
        end)
    end

    Sentinel_Push('player_drop', nil, { name = GetPlayerName(src), reason = reason }, false)
end)
