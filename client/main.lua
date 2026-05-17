local lastPos    = nil
local lastHealth = nil
local justSpawned = true

-- Reset position/health baseline after each spawn so the teleport from the
-- character-select screen to the spawn point doesn't trigger a false positive.
AddEventHandler('playerSpawned', function()
    justSpawned = true
    lastPos     = nil
    lastHealth  = nil
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped    = PlayerPedId()
        local pos    = GetEntityCoords(ped)
        local health = GetEntityHealth(ped)
        local speed  = GetEntitySpeed(ped)
        local inVeh  = IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, true) ~= 0

        if not inVeh and speed > Config.Thresholds.speedOnFoot then
            TriggerServerEvent('mcSentinel:exploitReport', 'speed_hack', {
                speed = speed,
                pos   = { x = pos.x, y = pos.y, z = pos.z },
            })
        end

        if justSpawned then
            justSpawned = false
            lastPos     = pos
            lastHealth  = health
        end

        if lastPos and not inVeh then
            local dist = #(pos - lastPos)
            if dist > Config.Thresholds.teleportDist then
                TriggerServerEvent('mcSentinel:positionAnomaly', {
                    dist = dist,
                    from = { x = lastPos.x, y = lastPos.y, z = lastPos.z },
                    to   = { x = pos.x,    y = pos.y,    z = pos.z    },
                })
            end
        end

        -- GTA health range: 0–200. 100 = empty bar, 200 = full.
        -- Flag if health jumped by more than 50 points and is now at max.
        -- Skip check if player was dead/downed last tick (health <= 105) to avoid respawn false-positive.
        local maxHealth = GetPedMaxHealth(ped)
        local wasDead   = lastHealth ~= nil and lastHealth <= 105
        if lastHealth and not wasDead and (maxHealth - lastHealth) > 50 and health >= maxHealth then
            TriggerServerEvent('mcSentinel:exploitReport', 'godmode_suspect', {
                health     = health,
                lastHealth = lastHealth,
            })
        end

        lastPos    = pos
        lastHealth = health
    end
end)
