local using = false

local function calcSuccessChance(veh)
    local base = Config.BaseSuccess
    local class = GetVehicleClass(veh)
    local mod = Config.ClassDifficulty[class] or 0
    local chance = base - mod
    if chance < 5 then chance = 5 end
    if chance > 95 then chance = 95 end
    return chance
end

local function attemptLockpick(entity, data)
    if using then return end
    using = true

    if not DoesEntityExist(entity) then
        LPDebug('Selected entity no longer exists')
        NotifyError('Vehicle vanished')
        using = false
        return
    end

    if not NetworkGetEntityIsNetworked(entity) then
        LPDebug('Entity not networked, registering')
        NetworkRegisterEntityAsNetworked(entity)
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(entity), true)
    end

    LPDebug('Starting lockpick attempt')
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local can = lib.callback.await('cg-lockpick:server:attempt', false, netId)
    if not can or not can.ok then
        LPDebug('Server attempt denied reason='..tostring(can and can.reason))
        if can and can.reason == 'no_item' then NotifyError('You need a lockpick')
        elseif can and can.reason == 'no_police' then NotifyError('Not enough police')
        elseif can and can.reason == 'no_vehicle' then NotifyError('Vehicle missing')
        elseif can and can.reason == 'no_player' then LPDebug('ESX player not ready on server') NotifyError('Try again in a moment')
        else NotifyError('Cannot lockpick right now') end
        using = false
        return
    end

    local veh = entity
    local chance = calcSuccessChance(veh)

    -- Ensure anim dict loaded (sometimes ox_lib handles but we double-guard)
    local animDict = 'mini@repair'
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        local timeout = 0
        while not HasAnimDictLoaded(animDict) and timeout < 200 do
            Wait(25)
            timeout += 1
        end
    end

    -- Launch custom NUI minigame
    local attemptData = can -- server returned tier info

    -- Apply class pin bonus client-side
    local classBonus = 0
    if Config.ClassPinBonus and DoesEntityExist(veh) then
        local class = GetVehicleClass(veh)
        classBonus = Config.ClassPinBonus[class] or 0
        if classBonus > (Config.MaxClassBonusPins or 2) then classBonus = Config.MaxClassBonusPins end
    end
    if classBonus > 0 then
        attemptData.pins = attemptData.pins + classBonus
        LPDebug(('Applied class bonus pins +%d (total %d)'):format(classBonus, attemptData.pins))
    end

    local nuiPayload = {
        action = 'open',
        tier = attemptData.tier,
        pins = attemptData.pins,
        window = attemptData.window,
        speed = attemptData.speed,
        attemptsPerPin = attemptData.attemptsPerPin,
        theme = attemptData.theme,
        failBreakModifier = attemptData.failBreakModifier,
        globalTimeLimit = attemptData.globalTimeLimit,
    }
    LPDebug(('Opening NUI minigame tier %s pins %d window %d speed %.2f attemptsPerPin %d'):format(
        tostring(attemptData.tier), attemptData.pins, attemptData.window, attemptData.speed, attemptData.attemptsPerPin))
    SetNuiFocus(true, true)
    SendNUIMessage(nuiPayload)
    -- store context
    _cgLockpickContext = { veh = veh, netId = netId }
end

-- Add ox_target option on vehicles
CreateThread(function()
    while not exports.ox_target do Wait(100) end

    exports.ox_target:addGlobalVehicle({
        {
            name = 'cg_lockpick_vehicle',
            icon = 'fa-solid fa-screwdriver-wrench',
            label = 'Lockpick Vehicle',
            distance = 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                if using then return false end
                if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                -- Check door lock status (0/1 unlocked; >=2 locked)
                local lockStatus = GetVehicleDoorLockStatus(entity)
                if lockStatus == 0 or lockStatus == 1 then return false end
                return true
            end,
            onSelect = function(data)
                LPDebug('Target selected on vehicle '..tostring(data.entity))
                attemptLockpick(data.entity, data)
            end
        }
    })
    LPDebug('Global vehicle target registered')
end)

RegisterNetEvent('cg-lockpick:client:itemBroken', function()
    NotifyError('Your lockpick broke')
end)

-- NUI Callbacks
RegisterNUICallback('lockpick:result', function(data, cb)
    cb(1)
    SetNuiFocus(false, false)
    local ctx = _cgLockpickContext
    _cgLockpickContext = nil
    if not ctx then using = false return end
    local veh = ctx.veh
    local success = data and data.success
    LPDebug('NUI result success='..tostring(success))

    -- Alarms based on success/fail
    if success then
        if math.random(100) <= Config.AlarmChanceSuccess then
            TriggerServerEvent('InteractSound_SV:PlayOnSource', 'alarm', 0.4)
        end
    else
        if math.random(100) <= Config.AlarmChanceFail then
            TriggerServerEvent('InteractSound_SV:PlayOnSource', 'alarm', 0.6)
        end
    end

    TriggerServerEvent('cg-lockpick:server:consume', success)

    if success and DoesEntityExist(veh) then
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleDoorsLockedForAllPlayers(veh, false)
        NotifySuccess('Unlocked vehicle')
    elseif not success then
        NotifyError('Lockpick failed')
    end

    using = false
end)

RegisterNUICallback('lockpick:close', function(_, cb)
    cb(1)
    SetNuiFocus(false, false)
    _cgLockpickContext = nil
    NotifyInfo('Cancelled')
    using = false
end)
