local ESX = exports['es_extended']:getSharedObject()
local activeContracts = {}
local playerData = {}
local contractQueue = {}
local cooldowns = {}
local pendingVehicleNet = {}
local policeBlips = {} -- track active police blip states keyed by contract id

local json = json or require('json') -- fallback if environment supplies

MySQL.ready(function()
    print('[cg-boosting] MySQL ready')
end)

local function ensurePlayer(xPlayer)
    local identifier = xPlayer.getIdentifier()
    if not playerData[identifier] then
        local result = MySQL.single.await('SELECT * FROM boosting_players WHERE identifier = ?', { identifier })
        if not result then
            MySQL.insert.await('INSERT INTO boosting_players (identifier, reputation, daily_requests, last_request) VALUES (?, 0, 0, 0)', { identifier })
            playerData[identifier] = { rep = 0, daily_requests = 0, last_request = 0 }
        else
            playerData[identifier] = { rep = result.reputation or 0, daily_requests = result.daily_requests or 0, last_request = result.last_request or 0 }
        end
    end
    return playerData[identifier]
end

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    ensurePlayer(xPlayer)
end)

local function getTierByRep(rep)
    local tier
    for i=#Config.Tiers,1,-1 do
        if rep >= Config.Tiers[i].repRequired then
            tier = Config.Tiers[i]
            break
        end
    end
    return tier or Config.Tiers[1]
end

local function rollTier(rep)
    -- Weighted logic: higher rep increases chance for higher tier
    local unlocked = {}
    for _,t in ipairs(Config.Tiers) do
        if rep >= t.repRequired then
            unlocked[#unlocked+1] = t
        end
    end
    local idx = math.random(1, #unlocked)
    return unlocked[idx]
end

local function generateContract(identifier)
    local pdata = playerData[identifier]
    if not pdata then return nil end
    local tier = rollTier(pdata.rep)
    local vehicles = Config.Vehicles[tier.name]
    local model = vehicles[math.random(1, #vehicles)]
    local vinScratch = Config.VINScratch.enabled and (math.random() < Config.VINScratch.chance)
    local contract = {
        id = ('%s-%s'):format(tier.name, os.time() .. math.random(100,999)),
        tier = tier.name,
        model = model,
        payout = math.random(tier.basePayout.min, tier.basePayout.max),
        tracker = (math.random() < tier.trackerChance),
        policeChance = tier.policeChance,
        repGain = tier.repGain,
        time = tier.time,
        owner = identifier,
        vinScratch = vinScratch and 1 or 0,
        status = 'pending',
        trackerState = { hacks = 0, disabledUntil = 0, removed = false }
    }
    contractQueue[identifier] = contractQueue[identifier] or {}
    if #contractQueue[identifier] < Config.ContractRequest.queueSize then
        table.insert(contractQueue[identifier], contract)
    end
    return contract
end

local function refreshQueue(identifier)
    contractQueue[identifier] = contractQueue[identifier] or {}
    while #contractQueue[identifier] < Config.ContractRequest.queueSize do
        generateContract(identifier)
    end
end

local function canRequest(identifier)
    local pdata = playerData[identifier]
    if not pdata then return false, 'not_loaded' end
    if pdata.daily_requests >= Config.ContractRequest.dailyCap then
        return false, 'daily_cap'
    end
    if (os.time() - pdata.last_request) < Config.ContractRequest.baseCooldown then
        return false, 'cooldown'
    end
    return true
end

lib.callback.register('cg-boosting:fetchContracts', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    ensurePlayer(xPlayer)
    local identifier = xPlayer.getIdentifier()
    refreshQueue(identifier)
    return contractQueue[identifier]
end)

lib.callback.register('cg-boosting:fetchReputation', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { rep = 0 } end
    local pdata = ensurePlayer(xPlayer)
    -- also push to client for UI update
    TriggerClientEvent('cg-boosting:reputation', source, { rep = pdata.rep })
    return { rep = pdata.rep }
end)

RegisterNetEvent('cg-boosting:requestContract', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    ensurePlayer(xPlayer)
    local ok, reason = canRequest(identifier)
    if not ok then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Cannot request: '..reason, type = 'error' })
        return
    end
    local contract = generateContract(identifier)
    if contract then
        local pdata = playerData[identifier]
        pdata.daily_requests = pdata.daily_requests + 1
        pdata.last_request = os.time()
        MySQL.update('UPDATE boosting_players SET daily_requests = ?, last_request = ? WHERE identifier = ?', { pdata.daily_requests, pdata.last_request, identifier })
        TriggerClientEvent('cg-boosting:updateContracts', src, contractQueue[identifier])
    end
end)

RegisterNetEvent('cg-boosting:acceptContract', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    contractQueue[identifier] = contractQueue[identifier] or {}
    local contract
    for i,c in ipairs(contractQueue[identifier]) do
        if c.id == id then
            contract = c
            table.remove(contractQueue[identifier], i)
            break
        end
    end
    if not contract then return end
    if activeContracts[identifier] then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Already have an active contract', type = 'error' })
        return
    end
    contract.status = 'active'
    contract.startTime = os.time()
    contract.expires = os.time() + contract.time
    -- choose spawn & drop-off
    local spawn = Config.Spawns[math.random(1, #Config.Spawns)]
    local drop = Config.DropOffs[math.random(1, #Config.DropOffs)]
    contract.spawn = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }
    contract.drop = { x = drop.x, y = drop.y, z = drop.z }
    activeContracts[identifier] = contract
    MySQL.insert('INSERT INTO boosting_contracts (id, owner, tier, model, payout, tracker, vinScratch, created_at, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        contract.id, identifier, contract.tier, contract.model, contract.payout, contract.tracker and 1 or 0, contract.vinScratch, os.time(), 'active'
    })
    MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'accept', '' })
    -- request client to spawn vehicle (avoids server-side native limitations)
    pendingVehicleNet[identifier] = contract.id
    TriggerClientEvent('cg-boosting:contractAccepted', src, contract) -- send contract first for UI/blips
    TriggerClientEvent('cg-boosting:spawnVehicle', src, contract.model, contract.spawn, contract.id)
end)

RegisterNetEvent('cg-boosting:declineContract', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    contractQueue[identifier] = contractQueue[identifier] or {}
    for i,c in ipairs(contractQueue[identifier]) do
        if c.id == id then
            table.remove(contractQueue[identifier], i)
            break
        end
    end
    TriggerClientEvent('cg-boosting:updateContracts', src, contractQueue[identifier])
end)

-- receive vehicle network id from client after spawn
RegisterNetEvent('cg-boosting:vehicleSpawned', function(netId, contractId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    local contract = activeContracts[identifier]
    if not contract or contract.id ~= contractId then return end
    if pendingVehicleNet[identifier] ~= contractId then return end
    pendingVehicleNet[identifier] = nil
    contract.vehicle = netId
end)

-- Failure if vehicle destroyed (client side detection can trigger this too)
RegisterNetEvent('cg-boosting:vehicleFailed', function(reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    local contract = activeContracts[identifier]
    if not contract then return end
    if contract.status == 'failed' or contract.status == 'completed' then return end
    contract.status = 'failed'
    local penalty = (Config.AntiAbuse and Config.AntiAbuse.repPenalty) or 0
    if penalty > 0 then
        local pdata = playerData[identifier]
        pdata.rep = math.max(0, pdata.rep - penalty)
        MySQL.update('UPDATE boosting_players SET reputation = ? WHERE identifier = ?', { pdata.rep, identifier })
        TriggerClientEvent('cg-boosting:reputation', src, { rep = pdata.rep })
    end
    MySQL.update('UPDATE boosting_contracts SET status = ? WHERE id = ?', { 'failed', contract.id })
    MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'fail', reason or '' })
    TriggerClientEvent('ox_lib:notify', src, { description = 'Contract failed: vehicle destroyed', type = 'error' })
    TriggerClientEvent('cg-boosting:delivered', src) -- reuse client cleanup
    activeContracts[identifier] = nil
end)

-- Internal reusable delivery processor
local function processDelivery(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false, 'no_player' end
    local identifier = xPlayer.getIdentifier()
    local contract = activeContracts[identifier]
    if not contract then return false, 'no_active' end
    if os.time() > contract.expires then
        activeContracts[identifier] = nil
        TriggerClientEvent('ox_lib:notify', src, { description = 'Contract expired', type = 'error' })
        return false, 'expired'
    end
    local cfg = Config.Delivery or { radius = 6.0, ignoreZ = true }
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if cfg.requireInsideVehicle and veh == 0 then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Get in the car', type = 'error' })
        return false, 'not_in_vehicle'
    end
    if cfg.requireDriver and veh ~= 0 and GetPedInVehicleSeat(veh, -1) ~= ped then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Be driver to deliver', type = 'error' })
        return false, 'not_driver'
    end
    if veh ~= 0 and contract.vehicle and veh ~= NetworkGetEntityFromNetworkId(contract.vehicle) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Wrong vehicle', type = 'error' })
        return false, 'wrong_vehicle'
    end
    local coords = GetEntityCoords(ped)
    local dx = coords.x - contract.drop.x
    local dy = coords.y - contract.drop.y
    local dz = (cfg.ignoreZ and 0.0) or (coords.z - contract.drop.z)
    local dist2 = dx*dx + dy*dy + dz*dz
    local radius = cfg.radius or 6.0
    if dist2 > (radius * radius) then
        if Config.Debug then
            TriggerClientEvent('ox_lib:notify', src, { description = ('Not at drop-off (%.1fm away)'):format(math.sqrt(dist2)), type = 'error' })
        else
            TriggerClientEvent('ox_lib:notify', src, { description = 'Not at drop-off', type = 'error' })
        end
        return false, 'not_in_zone'
    end
    -- If tracker must be removed first
    if Config.Tracker and Config.Tracker.enabled and Config.Tracker.requireRemovalToDeliver and contract.tracker and not contract.trackerState.removed then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Remove tracker before delivering', type = 'error' })
        return false, 'tracker_active'
    end
    -- Success: payout & rep (+ VIN scratch bonus if flagged)
    local payout = contract.payout
    -- VIN scratch bonus
    if contract.vinScratch == 1 and contract.vinBonusApplied then
        -- already applied (shouldn't happen twice)
    elseif contract.vinScratch == 1 and Config.VINScratch and Config.VINScratch.bonusPercent and contract.vinScratched then
        local vinBonus = math.floor(payout * (Config.VINScratch.bonusPercent / 100))
        payout = payout + vinBonus
        contract.vinBonusApplied = true
    end
    -- Tracker removal bonus
    if contract.tracker and Config.Tracker and Config.Tracker.removalBonusPercent and contract.trackerState and contract.trackerState.removed then
        local trackBonus = math.floor(contract.payout * (Config.Tracker.removalBonusPercent / 100))
        payout = payout + trackBonus
    end
    xPlayer.addAccountMoney('black_money', payout)
    local pdata = playerData[identifier]
    pdata.rep = pdata.rep + contract.repGain
    MySQL.update('UPDATE boosting_players SET reputation = ? WHERE identifier = ?', { pdata.rep, identifier })
    MySQL.update('UPDATE boosting_contracts SET status = ? WHERE id = ?', { 'completed', contract.id })
    MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'complete', payout })
    TriggerClientEvent('cg-boosting:reputation', src, { rep = pdata.rep })
    TriggerClientEvent('ox_lib:notify', src, { description = ('Delivered! +$%d | +%d rep'):format(payout, contract.repGain), type = 'success' })

    -- Attempt to delete vehicle server-side as fallback (client also cleans up)
    if contract.vehicle then
        local ent = NetworkGetEntityFromNetworkId(contract.vehicle)
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end

    activeContracts[identifier] = nil
    -- Inform client to perform local cleanup (blips, entity if still exists)
    TriggerClientEvent('cg-boosting:delivered', src)
    return true
end

RegisterNetEvent('cg-boosting:completeDelivery', function()
    local src = source
    processDelivery(src)
end)

-- Auto-complete from client detection (sanity re-validates same rules)
RegisterNetEvent('cg-boosting:autoCompleteAttempt', function()
    local src = source
    -- Only attempt if autoComplete config still enabled (backwards compatibility)
    if Config.Delivery and Config.Delivery.autoComplete then
        processDelivery(src)
    end
end)

-- VIN scratch placeholder
RegisterNetEvent('cg-boosting:vinScratch', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    local contract = activeContracts[identifier]
    if not contract or contract.vinScratch ~= 1 then return end
    if Config.VINScratch.requireTrackerRemoved and contract.tracker and Config.Tracker and Config.Tracker.enabled then
        local state = contract.trackerState
        if not (state and state.removed) then
            TriggerClientEvent('ox_lib:notify', src, { description = 'Remove tracker first', type = 'error' })
            return
        end
    end
    if contract.vinScratched then
        TriggerClientEvent('ox_lib:notify', src, { description = 'VIN already scratched', type = 'error' })
        return
    end
    contract.vinScratched = true
    TriggerClientEvent('ox_lib:notify', src, { description = 'VIN scratched. Bonus will be added on delivery.', type = 'success' })
    -- Apply rep penalty (risk) immediately
    local pdata = playerData[identifier]
    pdata.rep = math.max(0, pdata.rep - (Config.VINScratch.repLoss or 0))
    MySQL.update('UPDATE boosting_players SET reputation = ? WHERE identifier = ?', { pdata.rep, identifier })
    TriggerClientEvent('cg-boosting:reputation', src, { rep = pdata.rep })
    MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'vin_scratch', 'pending_delivery' })
end)

-- Tracker hack request
RegisterNetEvent('cg-boosting:hackTracker', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    local contract = activeContracts[identifier]
    if not contract or not contract.tracker or not (Config.Tracker and Config.Tracker.enabled) then return end
    local state = contract.trackerState
    if state.removed then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Tracker already removed', type = 'success' })
        return
    end
    if state.disabledUntil > os.time() then
        local remain = state.disabledUntil - os.time()
        TriggerClientEvent('ox_lib:notify', src, { description = ('Tracker offline (%ds)'):format(remain), type = 'info' })
        return
    end
    -- Item requirement
    if Config.Tracker.hackItem then
        local item = xPlayer.getInventoryItem(Config.Tracker.hackItem)
        local count = item and (item.count or item.amount) or 0
        if count <= 0 then
            TriggerClientEvent('ox_lib:notify', src, { description = 'Missing hacking device', type = 'error' })
            return
        end
        if Config.Tracker.consumeItem then
            xPlayer.removeInventoryItem(Config.Tracker.hackItem, 1)
        end
    end
    -- Perform hack progression (simplified: always succeeds) - could add minigame hook
    state.hacks = state.hacks + 1
    local idx = state.hacks
    local disableDur = (Config.Tracker.disableDurations[idx] or Config.Tracker.disableDurations[#Config.Tracker.disableDurations])
    if state.hacks >= Config.Tracker.hackAttempts then
        state.removed = true
        state.disabledUntil = os.time() + 999999 -- effectively permanent
        TriggerClientEvent('ox_lib:notify', src, { description = 'Tracker permanently removed!', type = 'success' })
        MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'tracker_removed', state.hacks })
    else
        state.disabledUntil = os.time() + disableDur
        TriggerClientEvent('ox_lib:notify', src, { description = ('Tracker disabled for %ds (%d/%d)'):format(disableDur, state.hacks, Config.Tracker.hackAttempts), type = 'success' })
        MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'tracker_hack', state.hacks })
    end
    -- Update client with tracker state
    TriggerClientEvent('cg-boosting:trackerState', src, state)
end)

-- Periodic police ping thread
CreateThread(function()
    while true do
        local interval = (Config.Police and Config.Police.pingInterval) or 15
        if interval < 5 then interval = 5 end
        if Config.Police then
            local now = os.time()
            for identifier, contract in pairs(activeContracts) do
                if contract.tracker and Config.Tracker and Config.Tracker.enabled then
                    local state = contract.trackerState
                    local trackerActive = state and (not state.removed) and (state.disabledUntil <= now)
                    if trackerActive or (Config.Police.showWhileDisabled and not (state and state.removed)) then
                        -- fetch entity
                        local ent
                        if contract.vehicle then
                            ent = NetworkGetEntityFromNetworkId(contract.vehicle)
                        end
                        if ent and DoesEntityExist(ent) then
                            local coords = GetEntityCoords(ent)
                            -- Send ping to police players
                            local jobs = (Config.Police.jobs or {})
                            for _, playerId in ipairs(ESX.GetPlayers()) do
                                local xp = ESX.GetPlayerFromId(playerId)
                                if xp then
                                    local jobName = (xp.job and xp.job.name) or ''
                                    for _, pj in ipairs(jobs) do
                                        if pj == jobName then
                                            TriggerClientEvent('cg-boosting:policePing', playerId, contract.id, coords, trackerActive)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    elseif Config.Police.removeOnDisable and state and state.disabledUntil > now then
                        -- instruct removal for disabled period
                        local jobs = (Config.Police.jobs or {})
                        for _, playerId in ipairs(ESX.GetPlayers()) do
                            local xp = ESX.GetPlayerFromId(playerId)
                            if xp then
                                local jobName = (xp.job and xp.job.name) or ''
                                for _, pj in ipairs(jobs) do
                                    if pj == jobName then
                                        TriggerClientEvent('cg-boosting:policeRemovePing', playerId, contract.id)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(((Config.Police and Config.Police.pingInterval) or 15) * 1000)
    end
end)

lib.addCommand('boost', {
    help = 'Open boosting tablet'
}, function(source, args, raw)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    if Config.RequireTabletItem then
        local invItem = xPlayer.getInventoryItem(Config.TabletItem)
        if not invItem or (invItem.count or invItem.amount or 0) <= 0 then
            TriggerClientEvent('ox_lib:notify', source, { description = 'You need a boosting tablet', type = 'error' })
            return
        end
    end
    TriggerClientEvent('cg-boosting:openTablet', source)
end)

-- ESX usable item route (optional). Ensure item exists in database items table.
CreateThread(function()
    while not ESX do Wait(100) end
    if ESX.RegisterUsableItem then
        ESX.RegisterUsableItem(Config.TabletItem, function(source)
            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then return end
            TriggerClientEvent('cg-boosting:openTablet', source)
        end)
    end
end)

RegisterNetEvent('cg-boosting:openFromItem', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if Config.RequireTabletItem then
        local invItem = xPlayer.getInventoryItem(Config.TabletItem)
        if not invItem or (invItem.count or invItem.amount or 0) <= 0 then
            TriggerClientEvent('ox_lib:notify', src, { description = 'Tablet missing', type = 'error' })
            return
        end
    end
    TriggerClientEvent('cg-boosting:openTablet', src)
end)
