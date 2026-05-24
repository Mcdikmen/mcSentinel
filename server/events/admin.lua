-- Ace-based admin check + in-game permission management.

-- Tracks which server source IDs currently have admin access.
-- Used by Sentinel_Push to broadcast live alerts only to admins.
AdminSources = {}

local function getLicense(src)
    local fallback = nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id:sub(1, 9) == 'license2:' then return id end
        if id:sub(1, 8) == 'license:'  then fallback = id end
    end
    return fallback
end

local function applyAce(license)
    ExecuteCommand('add_ace identifier.' .. license .. ' mcSentinel.admin allow')
end

local function removeAce(license)
    ExecuteCommand('remove_ace identifier.' .. license .. ' mcSentinel.admin allow')
end

function IsPlayerAdmin(src)
    return IsPlayerAceAllowed(src, 'mcSentinel.admin')
end

-- Rebuild AdminSources and apply ace permissions for all stored admins on resource start.
CreateThread(function()
    Wait(1000)
    MySQL.query('SELECT license FROM sentinel_admins', {}, function(rows)
        if not rows then return end
        for _, row in ipairs(rows) do
            applyAce(row.license)
        end
        -- Populate AdminSources for players already online when resource restarts.
        for _, src in ipairs(GetPlayers()) do
            src = tonumber(src)
            if IsPlayerAceAllowed(src, 'mcSentinel.admin') then
                AdminSources[src] = true
            end
        end
        print('^2[mcSentinel]^0 ' .. #rows .. ' admin(s) loaded from DB')
    end)
end)

-- Keep AdminSources in sync when a player is confirmed admin via the panel command.
-- (Also fired from sentineladd after applyAce runs.)
AddEventHandler('mcSentinel:internal:adminGranted', function(src)
    if IsPlayerAceAllowed(src, 'mcSentinel.admin') then
        AdminSources[src] = true
    end
end)

AddEventHandler('playerDropped', function()
    AdminSources[source] = nil
end)

RegisterNetEvent('mcSentinel:checkAdmin', true)
AddEventHandler('mcSentinel:checkAdmin', function()
    local src = source
    if IsPlayerAdmin(src) then
        AdminSources[src] = true
        TriggerClientEvent('mcSentinel:adminConfirmed', src)
    end
end)

-- /sentineladd [playerid]
RegisterCommand('sentineladd', function(src, args)
    if src ~= 0 and not IsPlayerAdmin(src) then
        if src ~= 0 then TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', 'You do not have permission.' } }) end
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        if src ~= 0 then TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', 'Usage: /sentineladd [playerid]' } }) end
        return
    end

    local targetName    = GetPlayerName(targetId)
    local targetLicense = getLicense(targetId)
    if not targetLicense or not targetName then
        if src ~= 0 then TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', 'Player not found.' } }) end
        return
    end

    local grantedBy = src == 0 and 'console' or GetPlayerName(src)

    MySQL.query('INSERT IGNORE INTO sentinel_admins (license, name, granted_by) VALUES (?, ?, ?)',
        { targetLicense, targetName, grantedBy }, function()
            applyAce(targetLicense)
            AdminSources[targetId] = true
            print('[mcSentinel] Admin added: ' .. targetName .. ' (' .. targetLicense .. ') by ' .. grantedBy)
            if src ~= 0 then
                TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', targetName .. ' is now an admin.' } })
            end
            TriggerClientEvent('chat:addMessage', targetId, { args = { '[mcSentinel]', 'You have been granted mcSentinel admin access.' } })
        end)
end, true)

-- /sentinelremove [playerid]
RegisterCommand('sentinelremove', function(src, args)
    if src ~= 0 and not IsPlayerAdmin(src) then
        if src ~= 0 then TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', 'You do not have permission.' } }) end
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        if src ~= 0 then TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', 'Usage: /sentinelremove [playerid]' } }) end
        return
    end

    local targetName    = GetPlayerName(targetId)
    local targetLicense = getLicense(targetId)
    if not targetLicense then
        if src ~= 0 then TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', 'Player not found.' } }) end
        return
    end

    MySQL.query('DELETE FROM sentinel_admins WHERE license = ?', { targetLicense }, function()
        removeAce(targetLicense)
        AdminSources[targetId] = nil
        print('[mcSentinel] Admin removed: ' .. tostring(targetName) .. ' (' .. targetLicense .. ')')
        if src ~= 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { '[mcSentinel]', tostring(targetName) .. ' admin access revoked.' } })
        end
        if targetId and targetName then
            TriggerClientEvent('chat:addMessage', targetId, { args = { '[mcSentinel]', 'Your mcSentinel admin access has been revoked.' } })
        end
    end)
end, true)
