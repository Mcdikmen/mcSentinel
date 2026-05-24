-- Event queue: flushed to DB every Config.FlushInterval ms.
local queue = {}

-- Online players map: [player_id] = server_src
OnlineMap = {}

local function flush()
    if #queue == 0 then return end
    local batch = queue
    queue = {}
    DB_InsertEvents(batch)
end

-- Public: any server module calls this to queue an event.
function Sentinel_Push(eventType, playerId, data, flagged)
    queue[#queue + 1] = {
        player_id = playerId,
        type      = eventType,
        data      = data,
        flagged   = flagged or false,
    }

    if flagged then
        local serverSrc = playerId and OnlineMap[playerId] or nil
        local safeData  = {}
        for k, v in pairs(data) do
            if k ~= 'ip' then safeData[k] = v end
        end

        local alert = {
            type      = eventType,
            player_id = playerId,
            server_id = serverSrc,
            data      = safeData,
        }

        -- Broadcast only to confirmed admin sources, never to all clients.
        for adminSrc in pairs(AdminSources) do
            TriggerClientEvent('mcSentinel:liveAlert', adminSrc, alert)
        end

        if Config.DiscordWebhook ~= '' then
            local playerName = data.name or ('ID:' .. tostring(playerId))
            local tpl = Config.DiscordMessages[eventType] or Config.DiscordMessages.default
            local d   = data.detail or data
            local pos = d.pos or {}
            local desc = tpl
                :gsub('{player}',      playerName)
                :gsub('{speed}',       ('%.1f'):format(d.speed or 0))
                :gsub('{x}',           ('%.1f'):format(pos.x or 0))
                :gsub('{y}',           ('%.1f'):format(pos.y or 0))
                :gsub('{z}',           ('%.1f'):format(pos.z or 0))
                :gsub('{dist}',        ('%.1f'):format(d.dist or 0))
                :gsub('{from_x}',      ('%.1f'):format(d.from and d.from.x or 0))
                :gsub('{from_y}',      ('%.1f'):format(d.from and d.from.y or 0))
                :gsub('{to_x}',        ('%.1f'):format(d.to and d.to.x or 0))
                :gsub('{to_y}',        ('%.1f'):format(d.to and d.to.y or 0))
                :gsub('{last_health}', tostring(d.lastHealth or 0))
                :gsub('{health}',      tostring(d.health or 0))
                :gsub('{action}',      tostring(d.actionType or '?'))
                :gsub('{money_type}',  tostring(d.moneyType or '?'))
                :gsub('{amount}',      tostring(d.amount or 0))
                :gsub('{reason}',      tostring(d.reason or 'none'))
                :gsub('{json}',        json.encode(data):sub(1, 400))

            PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST',
                json.encode({
                    embeds = {{
                        title       = '[mcSentinel] ' .. eventType,
                        description = desc,
                        color       = 16711680,
                        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                    }}
                }),
                { ['Content-Type'] = 'application/json' }
            )
        end
    end
end

-- Flush loop
CreateThread(function()
    while true do
        Wait(Config.FlushInterval)
        flush()
    end
end)

-- Resource performance sampler
CreateThread(function()
    while true do
        Wait(Config.PerfInterval)
        local stats, n = {}, GetNumResources()
        for i = 0, n - 1 do
            local res = GetResourceByFindIndex(i)
            if GetResourceState(res) == 'started' then
                stats[#stats + 1] = { name = res }
            end
        end
        Sentinel_Push('resource_perf', nil, { resources = stats }, false)
    end
end)

-- ─── NUI data request handler ─────────────────────────────────────────────────

local ALLOWED_QUERIES = { overview = true, players = true, player_detail = true, logs = true }

RegisterNetEvent('mcSentinel:requestData', true)
AddEventHandler('mcSentinel:requestData', function(query, params)
    local src = source
    if not IsPlayerAdmin(src) then return end
    if type(query) ~= 'string' or not ALLOWED_QUERIES[query] then return end
    params = type(params) == 'table' and params or {}

    if query == 'overview' then
        MySQL.query([[
            SELECT
                (SELECT COUNT(*) FROM sentinel_players)                         AS total_players,
                (SELECT COUNT(*) FROM sentinel_events WHERE flagged = 1)        AS total_alerts,
                (SELECT COUNT(*) FROM sentinel_events)                          AS total_events,
                (SELECT COUNT(*) FROM sentinel_sessions WHERE left_at IS NULL)  AS online_now
        ]], {}, function(rows)
            local stats = rows and rows[1] or {}
            MySQL.query([[
                SELECT e.type, e.data, e.created_at, p.name AS player_name, p.id AS player_id
                FROM sentinel_events e
                LEFT JOIN sentinel_players p ON p.id = e.player_id
                WHERE e.flagged = 1
                ORDER BY e.created_at DESC LIMIT 20
            ]], {}, function(alerts)
                TriggerClientEvent('mcSentinel:dataResponse', src, 'overview', {
                    stats  = stats,
                    alerts = alerts or {},
                })
            end)
        end)

    elseif query == 'players' then
        local search = type(params.search) == 'string' and params.search:sub(1, 64) or ''
        local page   = type(params.page)   == 'number' and math.max(1, math.floor(params.page)) or 1
        local offset = (page - 1) * 25
        MySQL.query([[
            SELECT p.id, p.name, p.license, p.ip, p.updated_at,
                   COUNT(e.id) AS alert_count
            FROM sentinel_players p
            LEFT JOIN sentinel_events e ON e.player_id = p.id AND e.flagged = 1
            WHERE p.name LIKE ? OR p.license LIKE ?
            GROUP BY p.id
            ORDER BY p.updated_at DESC
            LIMIT 25 OFFSET ?
        ]], { '%' .. search .. '%', '%' .. search .. '%', offset }, function(rows)
            rows = rows or {}
            for _, row in ipairs(rows) do
                local srv = OnlineMap[row.id]
                if srv then
                    row.online    = true
                    row.server_id = srv
                    local qbPlayer = exports.qbx_core:GetPlayer(srv)
                    if qbPlayer then
                        local ci = qbPlayer.PlayerData.charinfo
                        row.char_name = (ci.firstname or '') .. ' ' .. (ci.lastname or '')
                    else
                        row.char_name = GetPlayerName(srv)
                    end
                end
            end
            TriggerClientEvent('mcSentinel:dataResponse', src, 'players', rows)
        end)

    elseif query == 'player_detail' then
        local pid = type(params.id) == 'number' and math.floor(params.id) or nil
        if not pid or pid < 1 then return end
        MySQL.query('SELECT * FROM sentinel_players WHERE id = ?', { pid }, function(p)
            if not p or not p[1] then return end
            local license = p[1].license
            MySQL.query('SELECT * FROM sentinel_events WHERE player_id = ? ORDER BY created_at DESC LIMIT 50', { pid }, function(evs)
                MySQL.query('SELECT * FROM sentinel_sessions WHERE player_id = ? ORDER BY joined_at DESC LIMIT 20', { pid }, function(sess)
                    MySQL.query('SELECT n.*, n.admin FROM sentinel_notes n WHERE n.player_id = ? ORDER BY n.created_at DESC', { pid }, function(notes)
                        local qbLicense = p[1].license2 or license
                        MySQL.query('SELECT citizenid, charinfo, job, money FROM players WHERE license = ?', { qbLicense }, function(chars)
                            local onlineCharId = nil
                            local srv = OnlineMap[pid]
                            if srv then
                                local qbp = exports.qbx_core:GetPlayer(srv)
                                if qbp then onlineCharId = qbp.PlayerData.citizenid end
                            end
                            TriggerClientEvent('mcSentinel:dataResponse', src, 'player_detail', {
                                player       = p[1],
                                events       = evs   or {},
                                sessions     = sess  or {},
                                notes        = notes or {},
                                characters   = chars or {},
                                onlineCharId = onlineCharId,
                            })
                        end)
                    end)
                end)
            end)
        end)

    elseif query == 'logs' then
        local filter  = type(params.filter)  == 'string'  and params.filter:sub(1, 32) or ''
        local flagged = params.flagged == true
        local page    = type(params.page) == 'number' and math.max(1, math.floor(params.page)) or 1
        local offset  = (page - 1) * 50
        local sqlParams = {}
        local where = 'WHERE 1=1'
        if flagged then
            where = where .. ' AND e.flagged = 1'
        end
        if filter ~= '' then
            where = where .. ' AND e.type = ?'
            sqlParams[#sqlParams + 1] = filter
        end
        sqlParams[#sqlParams + 1] = offset
        MySQL.query([[
            SELECT e.id, e.type, e.data, e.flagged, e.created_at,
                   p.name AS player_name, p.id AS player_id
            FROM sentinel_events e
            LEFT JOIN sentinel_players p ON p.id = e.player_id
            ]] .. where .. [[
            ORDER BY e.created_at DESC
            LIMIT 50 OFFSET ?
        ]], sqlParams, function(rows)
            TriggerClientEvent('mcSentinel:dataResponse', src, 'logs', rows or {})
        end)
    end
end)

-- ─── Admin note submission ────────────────────────────────────────────────────

RegisterNetEvent('mcSentinel:addNote', true)
AddEventHandler('mcSentinel:addNote', function(playerId, note)
    local src = source
    if not IsPlayerAdmin(src) then return end
    if type(playerId) ~= 'number' or playerId < 1 then return end
    if type(note) ~= 'string' or #note == 0 then return end
    note = note:sub(1, 1000)
    local adminName = GetPlayerName(src)
    MySQL.insert('INSERT INTO sentinel_notes (player_id, admin, note) VALUES (?, ?, ?)',
        { math.floor(playerId), adminName, note })
end)

-- ─── Populate OnlineMap for players already in-game on resource restart ───────

CreateThread(function()
    Wait(1500)
    local players = GetPlayers()
    for _, src in ipairs(players) do
        src = tonumber(src)
        local license = nil
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local id = GetPlayerIdentifier(src, i)
            if id:sub(1, 8) == 'license:' then license = id break end
        end
        if license then
            MySQL.scalar('SELECT id FROM sentinel_players WHERE license = ?', { license }, function(pid)
                if pid then OnlineMap[pid] = src end
            end)
        end
    end
end)

print('^2[mcSentinel]^0 Started')

-- ─── Async update checker ─────────────────────────────────────────────────────

local _currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'

CreateThread(function()
    Wait(5000)
    PerformHttpRequest(
        'https://api.github.com/repos/Mcdikmen/mcSentinel/releases/latest',
        function(status, body)
            if status == 404 then
                print('^2[mcSentinel]^0 v' .. _currentVersion .. ' — no releases published yet')
                return
            end
            if status ~= 200 then
                print('^3[mcSentinel]^0 Update check failed (HTTP ' .. tostring(status) .. ')')
                return
            end
            local ok, data = pcall(json.decode, body)
            if not ok or not data or not data.tag_name then
                print('^3[mcSentinel]^0 Update check failed (invalid response)')
                return
            end
            local latest = data.tag_name:gsub('^v', '')
            if latest == _currentVersion then
                print('^2[mcSentinel]^0 Up to date — v' .. _currentVersion)
            else
                print('')
                print('^3╔══════════════════════════════════════════╗^0')
                print('^3║         mcSentinel — Update Available    ║^0')
                print('^3╠══════════════════════════════════════════╣^0')
                print('^3║  Current : ^1v' .. _currentVersion .. string.rep(' ', 28 - #_currentVersion) .. '^3║^0')
                print('^3║  Latest  : ^2v' .. latest          .. string.rep(' ', 28 - #latest)          .. '^3║^0')
                print('^3║  https://github.com/Mcdikmen/mcSentinel ║^0')
                print('^3╚══════════════════════════════════════════╝^0')
                print('')
            end
        end,
        'GET', '', { ['User-Agent'] = 'mcSentinel/' .. _currentVersion }
    )
end)
