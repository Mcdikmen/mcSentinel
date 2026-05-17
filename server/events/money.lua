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

local function handleMoneyChange(src, moneyType, amount, actionType, reason)
    amount = tonumber(amount) or 0
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
                reason     = reason or 'none',
            },
            flagged
        )
    end)
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, actionType, reason)
    handleMoneyChange(src, moneyType, amount, actionType, reason)
end)
