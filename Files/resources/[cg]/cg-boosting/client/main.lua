local tabletOpen = false
local activeContract
local dropBlip
local spawnBlip -- now used only until vehicle is spawned (temporary guidance)
local vehicleBlip
local dropZoneRadius = Config.Delivery and Config.Delivery.radius or 6.0
local spawnedVeh
local delivered = false
local trackerState = nil
local trackerTick = 0
local policePings = {}
local hackFailLockUntil = 0

local function draw3D(x,y,z,text)
    SetDrawOrigin(x,y,z,0)
    SetTextScale(0.35,0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255,255,255,215)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0,0.0)
    ClearDrawOrigin()
end

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
    trackerState = contract.tracker and { hacks = 0, disabledUntil = 0, removed = false } or nil
    -- temporary spawn location guidance (removed once entity spawns & gets attached blip)
    if spawnBlip then RemoveBlip(spawnBlip) end
    if Config.TargetBlip and Config.TargetBlip.enabled then
        spawnBlip = AddBlipForCoord(contract.spawn.x, contract.spawn.y, contract.spawn.z)
        SetBlipSprite(spawnBlip, Config.TargetBlip.sprite or 225)
        SetBlipColour(spawnBlip, Config.TargetBlip.colour or 2)
        SetBlipScale(spawnBlip, Config.TargetBlip.scale or 0.85)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString((Config.TargetBlip.label or 'Boost Target')..' (Spawn)'); EndTextCommandSetBlipName(spawnBlip)
    end
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
    if spawnedVeh and DoesEntityExist(spawnedVeh) then
        if vehicleBlip and DoesBlipExist(vehicleBlip) then RemoveBlip(vehicleBlip) end
        DeleteEntity(spawnedVeh)
    end
    spawnedVeh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    if spawnedVeh ~= 0 then
        SetVehicleOnGroundProperly(spawnedVeh)
        SetVehicleDoorsLocked(spawnedVeh, 2)
        SetVehicleNumberPlateText(spawnedVeh, string.upper(string.sub(contractId,1,8)))
        SetEntityAsMissionEntity(spawnedVeh, true, true)
        local netId = NetworkGetNetworkIdFromEntity(spawnedVeh)
        TriggerServerEvent('cg-boosting:vehicleSpawned', netId, contractId)
        -- Replace spawn blip with entity-attached blip
        if Config.TargetBlip and Config.TargetBlip.enabled then
            if spawnBlip and DoesBlipExist(spawnBlip) then RemoveBlip(spawnBlip) end
            if vehicleBlip and DoesBlipExist(vehicleBlip) then RemoveBlip(vehicleBlip) end
            vehicleBlip = AddBlipForEntity(spawnedVeh)
            SetBlipSprite(vehicleBlip, Config.TargetBlip.sprite or 225)
            SetBlipColour(vehicleBlip, Config.TargetBlip.colour or 2)
            SetBlipScale(vehicleBlip, Config.TargetBlip.scale or 0.85)
            if Config.TargetBlip.route then
                SetBlipRoute(vehicleBlip, true)
                SetBlipRouteColour(vehicleBlip, Config.TargetBlip.colour or 2)
            end
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.TargetBlip.label or 'Boost Target'); EndTextCommandSetBlipName(vehicleBlip)
        end
    end
end)

RegisterNetEvent('cg-boosting:reputation', function(data)
    SendNUIMessage({ action = 'reputation', data = data })
end)

RegisterNetEvent('cg-boosting:trackerState', function(state)
    trackerState = state
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
        if activeContract and not tabletOpen and not delivered then
            local cfg = Config.Delivery or {}
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dropVec = vector3(activeContract.drop.x, activeContract.drop.y, activeContract.drop.z)
            local dist = #(coords - dropVec)
            -- Tracker hacking prompt (if enabled & tracker present)
            if activeContract.tracker and Config.Tracker and Config.Tracker.enabled then
                if trackerState and not trackerState.removed then
                    local now = os.time()
                    local statusText
                    if trackerState.disabledUntil > now then
                        statusText = ('Tracker Offline %ds'):format(trackerState.disabledUntil - now)
                    else
                        statusText = 'Tracker Active (H to Hack)'
                        if IsControlJustPressed(0, Config.Tracker.hackKey or 74) then
                            local now = GetGameTimer()
                            if hackFailLockUntil > now then
                                lib.notify({ description = 'Systems resetting...', type = 'error' })
                            else
                                local function performHack()
                                    if Config.Tracker.progress then
                                        if not lib.progressCircle({ duration = Config.Tracker.progress.duration, label = Config.Tracker.progress.label, position = 'bottom', useWhileDead = false, canCancel = true }) then
                                            lib.notify({ description = 'Hack cancelled', type = 'error' })
                                            return
                                        end
                                    end
                                    TriggerServerEvent('cg-boosting:hackTracker')
                                end
                                local mg = Config.Tracker.minigame
                                if mg and mg.enabled and lib.skillCheck then
                                    local passed = lib.skillCheck(mg.sequence or { 'easy','medium','hard' })
                                    if passed then
                                        performHack()
                                    else
                                        if not mg.allowFailRetry then
                                            hackFailLockUntil = GetGameTimer() + ((mg.failCooldown or 5) * 1000)
                                        end
                                        lib.notify({ description = 'Hack failed', type = 'error' })
                                    end
                                else
                                    performHack()
                                end
                            end
                        end
                    end
                    if statusText then
                        draw3D(coords.x, coords.y, coords.z + 1.0, ('~y~%s'):format(statusText))
                    end
                elseif trackerState and trackerState.removed then
                    draw3D(coords.x, coords.y, coords.z + 1.0, '~g~Tracker Removed')
                end
            end
            if dist < (cfg.showMarkerDistance or 60.0) then
                local m = cfg.marker or { r=30,g=190,b=120,a=140 }
                DrawMarker(1, dropVec.x, dropVec.y, dropVec.z - 1.0, 0.0,0.0,0.0,0.0,0.0,0.0, 2.5,2.5,1.2, m.r,m.g,m.b,m.a, false,false,2,false,nil,nil,false)
            end
            if dist <= (cfg.radius or 6.0) and cfg.requireKeyPress then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 or not cfg.requireInsideVehicle then
                    local isDriver = (veh ~= 0 and GetPedInVehicleSeat(veh,-1) == ped)
                    if (not cfg.requireDriver) or isDriver then
                        if activeContract.tracker and Config.Tracker and Config.Tracker.enabled and Config.Tracker.requireRemovalToDeliver and (not trackerState or not trackerState.removed) then
                            draw3D(dropVec.x, dropVec.y, dropVec.z + (cfg.promptOffsetZ or 0.5), '~r~Remove tracker first')
                        else
                        draw3D(dropVec.x, dropVec.y, dropVec.z + (cfg.promptOffsetZ or 0.5), '~g~E~w~ Deliver Vehicle')
                        if IsControlJustPressed(0, cfg.key or 38) then
                            TriggerServerEvent('cg-boosting:completeDelivery')
                        end
                        end
                    end
                end
            end
        end
        Wait(0)
    end
end)

RegisterNetEvent('cg-boosting:delivered', function()
    delivered = true
    if vehicleBlip and DoesBlipExist(vehicleBlip) then RemoveBlip(vehicleBlip) end
    if spawnBlip and DoesBlipExist(spawnBlip) then RemoveBlip(spawnBlip) end
    if spawnedVeh and DoesEntityExist(spawnedVeh) then
        DeleteEntity(spawnedVeh)
        spawnedVeh = nil
    end
    activeContract = nil
    trackerState = nil
end)

-- Police side: receive tracker pings
RegisterNetEvent('cg-boosting:policePing', function(contractId, coords, active)
    if not Config.Police or not Config.Police.blip then return end
    -- Only show if player has police job (client trust minimal; server already filtered)
    local jobName = exports['es_extended'] and (ESX and ESX.GetPlayerData and ESX.GetPlayerData().job and ESX.GetPlayerData().job.name)
    -- If ESX not accessible on client, still create (can refine later)
    if policePings[contractId] and DoesBlipExist(policePings[contractId]) then
        SetBlipCoords(policePings[contractId], coords.x, coords.y, coords.z)
    else
        local b = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(b, Config.Police.blip.sprite or 161)
        SetBlipColour(b, Config.Police.blip.colour or 1)
        SetBlipScale(b, Config.Police.blip.scale or 0.9)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.Police.blip.label or 'Stolen Vehicle'); EndTextCommandSetBlipName(b)
        policePings[contractId] = b
    end
    if not active then
        -- maybe pulse or make it semi-transparent to show last known
        SetBlipColour(policePings[contractId], 0)
    end
end)

RegisterNetEvent('cg-boosting:policeRemovePing', function(contractId)
    local b = policePings[contractId]
    if b and DoesBlipExist(b) then RemoveBlip(b) end
    policePings[contractId] = nil
end)

-- Monitor vehicle health for failure
CreateThread(function()
    while true do
        if activeContract and spawnedVeh and DoesEntityExist(spawnedVeh) and not delivered then
            if Config.AntiAbuse and Config.AntiAbuse.failOnVehicleDestroyed then
                local eng = GetVehicleEngineHealth(spawnedVeh)
                if eng <= (Config.AntiAbuse.engineHealthThreshold or 0.0) or eng <= 0.0 then
                    TriggerServerEvent('cg-boosting:vehicleFailed', 'engine')
                end
            end
        end
        Wait(2000)
    end
end)
