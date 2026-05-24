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

-- Dedicated high-frequency speed check (100ms).
-- Requires 3 consecutive violations before reporting to eliminate false positives.
CreateThread(function()
    local violations = 0
    while true do
        Wait(100)
        if not _token then violations = 0 goto spd_continue end

        local ped   = PlayerPedId()
        local inVeh = IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, true) ~= 0

        if not inVeh and GetEntitySpeed(ped) > Config.Thresholds.speedOnFoot then
            violations = violations + 1
            if violations >= 3 then
                local pos = GetEntityCoords(ped)
                TriggerServerEvent('mcSentinel:exploitReport', _token, 'speed_hack', {
                    speed = GetEntitySpeed(ped),
                    pos   = { x = pos.x, y = pos.y, z = pos.z },
                })
                violations = 0
                Wait(5000) -- cooldown to avoid spam after a confirmed report
            end
        else
            violations = 0
        end
        ::spd_continue::
    end
end)

-- Main anomaly loop: teleport + godmode (1s tick is sufficient for these).
CreateThread(function()
    while true do
        Wait(1000)
        if not _token then goto main_continue end

        local ped    = PlayerPedId()
        local health = GetEntityHealth(ped)
        local pos    = GetEntityCoords(ped)
        local inVeh  = IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, true) ~= 0

        if justSpawned then
            justSpawned = false
            lastPos     = pos
            lastHealth  = health
            goto main_continue
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

        ::main_continue::
    end
end)
