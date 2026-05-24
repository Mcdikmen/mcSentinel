-- Monitors money transactions via QBCore event.

local function getLicense(src)
    local fallback = nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id:sub(1, 8) == 'license:'  and id:sub(1, 9) ~= 'license2:' then return id end
        if id:sub(1, 9) == 'license2:' then fallback = id end
    end
    return fallback
end

local VALID_MONEY_TYPES   = { cash = true, bank = true, crypto = true }
local VALID_ACTION_TYPES  = { add = true, remove = true, set = true }

local function handleMoneyChange(src, moneyType, amount, actionType, reason)
    -- Strict type validation — this is a server-to-server event from QBCore,
    -- but we still sanitise in case of unexpected calls.
    amount     = tonumber(amount) or 0
    moneyType  = type(moneyType)  == 'string' and moneyType  or 'unknown'
    actionType = type(actionType) == 'string' and actionType or 'unknown'
    reason     = type(reason)     == 'string' and reason:sub(1, 255) or 'none'

    -- Warn but still log if unexpected type is seen (could indicate a new QBCore release).
    if not VALID_MONEY_TYPES[moneyType] then
        moneyType = 'unknown:' .. moneyType:sub(1, 16)
    end
    if not VALID_ACTION_TYPES[actionType] then
        actionType = 'unknown:' .. actionType:sub(1, 16)
    end

    local flagged = math.abs(amount) >= Config.Thresholds.moneyDelta
    local license = getLicense(src)
    if not license then return end

    MySQL.scalar('SELECT id FROM sentinel_players WHERE license = ?', { license }, function(pid)
        Sentinel_Push(
            flagged and 'money_alert' or 'money_tx',
            pid,
            {
                name       = GetPlayerName(src),
                amount     = amount,
                actionType = actionType,
                moneyType  = moneyType,
                reason     = reason,
            },
            flagged
        )
    end)
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, actionType, reason)
    handleMoneyChange(src, moneyType, amount, actionType, reason)
end)
