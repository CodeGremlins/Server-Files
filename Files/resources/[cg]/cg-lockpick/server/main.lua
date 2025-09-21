local ESX

CreateThread(function()
    while not ESX do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(50)
    end
end)

local function hasPoliceOnline()
    if Config.MinPolice <= 0 then return true end
    local xPlayers = ESX.GetExtendedPlayers()
    local count = 0
    for _, xPlayer in pairs(xPlayers) do
        for _, job in ipairs(Config.PoliceJobs) do
            if xPlayer.job.name == job then
                count += 1
                break
            end
        end
    end
    return count >= Config.MinPolice
end

lib.callback.register('cg-lockpick:server:attempt', function(source, netId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return { ok = false, reason = 'no_player' } end

    if not hasPoliceOnline() then
        return { ok = false, reason = 'no_police' }
    end

    local invItem = exports.ox_inventory:Search(src, 'count', Config.LockpickItem)
    if (invItem or 0) <= 0 then
        return { ok = false, reason = 'no_item' }
    end

    -- Optionally validate entity still exists
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        return { ok = false, reason = 'no_vehicle' }
    end

    -- Determine tier
    local chosenTier, tierConfig
    for _, tierName in ipairs(Config.TierOrder or {}) do
        local def = Config.Tiers[tierName]
        if def then
            if not def.requiredItem or (exports.ox_inventory:Search(src, 'count', def.requiredItem) or 0) > 0 then
                chosenTier = tierName
                tierConfig = def
                break
            end
        end
    end
    if not chosenTier then
        return { ok = false, reason = 'no_item' }
    end

    -- Server returns only base tier pins; client will add class bonus (server avoids client-only natives)
    local pins = tierConfig.pins

    local resp = {
        ok = true,
        tier = chosenTier,
        pins = pins,
        window = tierConfig.window,
        speed = tierConfig.speed,
        attemptsPerPin = tierConfig.attemptsPerPin,
        failBreakModifier = tierConfig.failBreakModifier or 0,
        globalTimeLimit = Config.GlobalTimeLimit,
        theme = Config.NUITheme,
    }
    return resp
end)

RegisterNetEvent('cg-lockpick:server:consume', function(success)
    local src = source
    if not success and math.random(100) <= Config.BreakChanceOnFail then
        exports.ox_inventory:RemoveItem(src, Config.LockpickItem, 1)
        TriggerClientEvent('cg-lockpick:client:itemBroken', src)
    elseif success and Config.BreakChanceOnSuccess > 0 and math.random(100) <= Config.BreakChanceOnSuccess then
        exports.ox_inventory:RemoveItem(src, Config.LockpickItem, 1)
        TriggerClientEvent('cg-lockpick:client:itemBroken', src)
    end
end)
