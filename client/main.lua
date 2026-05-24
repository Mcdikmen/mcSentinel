-- Cache frequently used natives as locals to avoid repeated global table lookups.
local Wait               = Wait
local CreateThread       = CreateThread
local PlayerPedId        = PlayerPedId
local GetEntityCoords    = GetEntityCoords
local GetEntityHealth    = GetEntityHealth
local GetEntitySpeed     = GetEntitySpeed
local GetPedMaxHealth    = GetPedMaxHealth
local IsPedInAnyVehicle  = IsPedInAnyVehicle
local GetVehiclePedIsIn  = GetVehiclePedIsIn
local TriggerServerEvent = TriggerServerEvent
local AddEventHandler    = AddEventHandler

local lastPos     = nil
local lastHealth  = nil
local justSpawned = true
local _token      = nil  -- session token issued by the server on PlayerLoaded

-- Receive session token from server (issued in server/events/player.lua).
RegisterNetEvent('mcSentinel:init', true)
AddEventHandler('mcSentinel:init', function(token)
    _token = token
end)

-- Reset position/health baseline after each spawn so the teleport from the
-- character-select screen to the spawn point does not trigger a false positive.
AddEventHandler('playerSpawned', function()
    justSpawned = true
    lastPos     = nil
    lastHealth  = nil
end)

CreateThread(function()
    while true do
        -- Idle until we have a valid token from the server.
        if not _token then
            Wait(1000)
            goto continue
        end

        local ped    = PlayerPedId()
        local health = GetEntityHealth(ped)
        local inVeh  = IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, true) ~= 0

        -- Speed check (on-foot only)
        if not inVeh then
            local speed = GetEntitySpeed(ped)
            if speed > Config.Thresholds.speedOnFoot then
                local pos = GetEntityCoords(ped)
                TriggerServerEvent('mcSentinel:exploitReport', _token, 'speed_hack', {
                    speed = speed,
                    pos   = { x = pos.x, y = pos.y, z = pos.z },
                })
                Wait(1000)
                goto continue
            end
        end

        local pos = GetEntityCoords(ped)

        if justSpawned then
            justSpawned = false
            lastPos     = pos
            lastHealth  = health
            Wait(1000)
            goto continue
        end

        -- Teleport check (on-foot only)
        if lastPos and not inVeh then
            local dist = #(pos - lastPos)
            if dist > Config.Thresholds.teleportDist then
                TriggerServerEvent('mcSentinel:positionAnomaly', _token, {
                    dist = dist,
                    from = { x = lastPos.x, y = lastPos.y, z = lastPos.z },
                    to   = { x = pos.x,     y = pos.y,     z = pos.z     },
                })
            end
        end

        -- Godmode check: health jumped by >50 pts and is now at max, while player wasn't dead.
        local maxHealth = GetPedMaxHealth(ped)
        local wasDead   = lastHealth ~= nil and lastHealth <= 105
        if lastHealth and not wasDead and (maxHealth - lastHealth) > 50 and health >= maxHealth then
            TriggerServerEvent('mcSentinel:exploitReport', _token, 'godmode_suspect', {
                health     = health,
                lastHealth = lastHealth,
            })
        end

        lastPos    = pos
        lastHealth = health

        -- Dynamic wait: sleep longer when health is full and player hasn't moved much
        -- (reduces unnecessary wakeups while still catching anomalies quickly).
        local sleepTime = 1000
        if lastPos and #(pos - lastPos) < 1.0 and health >= maxHealth then
            sleepTime = 2000
        end
        Wait(sleepTime)
        ::continue::
    end
end)
