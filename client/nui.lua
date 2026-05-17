local isOpen = false

-- Request admin check from server; panel opens via callback if confirmed.
local function tryOpenPanel()
    TriggerServerEvent('mcSentinel:checkAdmin')
end

RegisterNetEvent('mcSentinel:adminConfirmed', true)
AddEventHandler('mcSentinel:adminConfirmed', function()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', charFields = Config.CharacterFields, toast = Config.Toast })
    TriggerServerEvent('mcSentinel:requestData', 'overview', {})
end)

-- Close panel (ESC or NUI close button)
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Data request from NUI
RegisterNUICallback('requestData', function(data, cb)
    TriggerServerEvent('mcSentinel:requestData', data.query, data.params)
    cb('ok')
end)

-- Note submission from NUI
RegisterNUICallback('addNote', function(data, cb)
    TriggerServerEvent('mcSentinel:addNote', data.playerId, data.note)
    cb('ok')
end)

-- Forward server data response to NUI
RegisterNetEvent('mcSentinel:dataResponse', true)
AddEventHandler('mcSentinel:dataResponse', function(page, data)
    if not isOpen then return end
    SendNUIMessage({ action = 'dataResponse', page = page, data = data })
end)

-- Send toast config to NUI on resource start
CreateThread(function()
    Wait(500)
    SendNUIMessage({ action = 'initConfig', toast = Config.Toast })
end)

-- Live alert — show toast even if panel is closed
RegisterNetEvent('mcSentinel:liveAlert', true)
AddEventHandler('mcSentinel:liveAlert', function(alert)
    SendNUIMessage({ action = 'liveAlert', data = alert })
end)

-- Toggle panel with `sentinel` command (default keybind: F8)
RegisterCommand('sentinel', function()
    if isOpen then
        isOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    else
        tryOpenPanel()
    end
end, false)

RegisterKeyMapping('sentinel', 'Open mcSentinel Panel', 'keyboard', 'F8')

-- Toggle live alert toasts on/off for this admin session
local alertsEnabled = true
RegisterCommand('sentinelalerts', function()
    alertsEnabled = not alertsEnabled
    SendNUIMessage({ action = 'setToastEnabled', enabled = alertsEnabled })
    TriggerEvent('chat:addMessage', { args = { '[mcSentinel]', 'Live alerts ' .. (alertsEnabled and 'enabled.' or 'disabled.') } })
end, false)
