-- Tracks player connections and sessions via Qbox events.

local recentLoginsByIp = {}

-- Fires when a player fully loads into the server via qbx_core.
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

    -- Use license2 as primary key if available, fall back to license
    if not license then license = license2 end
    if not license then return end

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
