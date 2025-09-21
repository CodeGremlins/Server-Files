local tabletOpen = false
local activeContract
local dropBlip
local spawnBlip
local dropZoneRadius = 5.0
local spawnedVeh

RegisterNetEvent('cg-boosting:openTablet', function()
    if tabletOpen then return end
    tabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    lib.notify({ description = 'Boosting tablet opened', type = 'info' })
end)

RegisterNUICallback('close', function(_, cb)
    if not tabletOpen then cb('ok'); return end
    tabletOpen = false
    SetNuiFocus(false, false)
    -- tell UI to hide itself
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNetEvent('cg-boosting:updateContracts', function(contracts)
    SendNUIMessage({ action = 'contracts', data = contracts })
end)

RegisterNetEvent('cg-boosting:contractAccepted', function(contract)
    SendNUIMessage({ action = 'accepted', data = contract })
    activeContract = contract
    -- spawn location guidance
    if spawnBlip then RemoveBlip(spawnBlip) end
    spawnBlip = AddBlipForCoord(contract.spawn.x, contract.spawn.y, contract.spawn.z)
    SetBlipSprite(spawnBlip, 225); SetBlipColour(spawnBlip, 2); SetBlipScale(spawnBlip, 0.85)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Boost Target'); EndTextCommandSetBlipName(spawnBlip)
    -- drop-off blip (hidden until player enters target vehicle maybe, for MVP show now)
    if dropBlip then RemoveBlip(dropBlip) end
    dropBlip = AddBlipForCoord(contract.drop.x, contract.drop.y, contract.drop.z)
    SetBlipSprite(dropBlip, 524); SetBlipColour(dropBlip, 46); SetBlipScale(dropBlip, 0.8)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Drop-Off'); EndTextCommandSetBlipName(dropBlip)
end)

-- client-side spawn handler
RegisterNetEvent('cg-boosting:spawnVehicle', function(modelName, spawn, contractId)
    local model = joaat(modelName)
    if not IsModelInCdimage(model) then
        lib.notify({ description = 'Invalid vehicle model', type = 'error' })
        return
    end
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 500 do
        Wait(10)
        timeout = timeout + 10
    end
    if not HasModelLoaded(model) then
        lib.notify({ description = 'Failed to load model', type = 'error' })
        return
    end
    if spawnedVeh and DoesEntityExist(spawnedVeh) then DeleteEntity(spawnedVeh) end
    spawnedVeh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    if spawnedVeh ~= 0 then
        SetVehicleOnGroundProperly(spawnedVeh)
        SetVehicleDoorsLocked(spawnedVeh, 2)
        SetVehicleNumberPlateText(spawnedVeh, string.upper(string.sub(contractId,1,8)))
        SetEntityAsMissionEntity(spawnedVeh, true, true)
        local netId = NetworkGetNetworkIdFromEntity(spawnedVeh)
        TriggerServerEvent('cg-boosting:vehicleSpawned', netId, contractId)
    end
end)

RegisterNetEvent('cg-boosting:reputation', function(data)
    SendNUIMessage({ action = 'reputation', data = data })
end)

-- NUI Callbacks bridging to server
RegisterNUICallback('fetchContracts', function(_, cb)
    lib.callback('cg-boosting:fetchContracts', false, function(data)
        cb(data)
    end)
end)

RegisterNUICallback('fetchReputation', function(_, cb)
    lib.callback('cg-boosting:fetchReputation', false, function(data)
        cb(data)
    end)
end)

RegisterNUICallback('requestContract', function(_, cb)
    TriggerServerEvent('cg-boosting:requestContract')
    cb('ok')
end)

RegisterNUICallback('acceptContract', function(data, cb)
    TriggerServerEvent('cg-boosting:acceptContract', data.id)
    cb('ok')
end)

RegisterNUICallback('declineContract', function(data, cb)
    TriggerServerEvent('cg-boosting:declineContract', data.id)
    cb('ok')
end)

RegisterNUICallback('completeDelivery', function(_, cb)
    -- client-side pre-check distance to drop-off
    if not activeContract then
        lib.notify({ description = 'No active contract', type = 'error' })
        cb('fail')
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local dx = coords.x - activeContract.drop.x
    local dy = coords.y - activeContract.drop.y
    local dz = coords.z - activeContract.drop.z
    if (dx*dx + dy*dy + dz*dz) > (dropZoneRadius * dropZoneRadius) then
        lib.notify({ description = 'Go to the drop-off zone', type = 'error' })
        cb('fail')
        return
    end
    TriggerServerEvent('cg-boosting:completeDelivery')
    cb('ok')
end)

RegisterNUICallback('vinScratch', function(_, cb)
    TriggerServerEvent('cg-boosting:vinScratch')
    cb('ok')
end)

-- ESC closes
CreateThread(function()
    while true do
        if tabletOpen and (IsControlJustPressed(0, 177) or IsControlJustPressed(0, 322)) then -- Backspace or ESC
            tabletOpen = false
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
        end
        -- draw drop-off marker if active
        if activeContract and not tabletOpen then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - vector3(activeContract.drop.x, activeContract.drop.y, activeContract.drop.z))
            if dist < 50.0 then
                DrawMarker(1, activeContract.drop.x, activeContract.drop.y, activeContract.drop.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.5,2.5,1.2, 30,190,120, 140, false, false, 2, false, nil, nil, false)
            end
        end
        Wait(0)
    end
end)
