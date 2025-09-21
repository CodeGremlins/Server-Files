local ESX = exports['es_extended']:getSharedObject()
local activeContracts = {}
local playerData = {}
local contractQueue = {}
local cooldowns = {}
local pendingVehicleNet = {}

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
        status = 'pending'
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

RegisterNetEvent('cg-boosting:completeDelivery', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    local contract = activeContracts[identifier]
    if not contract then return end
    if os.time() > contract.expires then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Contract expired', type = 'error' })
        activeContracts[identifier] = nil
        return
    end
    -- Validate player near drop-off and inside spawned vehicle (basic)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Get in the car', type = 'error' })
        return
    end
    if contract.vehicle and veh ~= NetworkGetEntityFromNetworkId(contract.vehicle) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Wrong vehicle', type = 'error' })
        return
    end
    local coords = GetEntityCoords(ped)
    local dx = coords.x - contract.drop.x
    local dy = coords.y - contract.drop.y
    local dz = coords.z - contract.drop.z
    if (dx*dx + dy*dy + dz*dz) > (25.0) then -- ~5m radius squared (5^2=25)
        TriggerClientEvent('ox_lib:notify', src, { description = 'Not at drop-off', type = 'error' })
        return
    end
    local payout = contract.payout
    xPlayer.addAccountMoney('black_money', payout)
    local pdata = playerData[identifier]
    pdata.rep = pdata.rep + contract.repGain
    MySQL.update('UPDATE boosting_players SET reputation = ? WHERE identifier = ?', { pdata.rep, identifier })
    MySQL.update('UPDATE boosting_contracts SET status = ? WHERE id = ?', { 'completed', contract.id })
    MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'complete', payout })
    TriggerClientEvent('cg-boosting:reputation', src, { rep = pdata.rep })
    TriggerClientEvent('ox_lib:notify', src, { description = ('Delivered! +$%d | +%d rep'):format(payout, contract.repGain), type = 'success' })
    activeContracts[identifier] = nil
end)

-- VIN scratch placeholder
RegisterNetEvent('cg-boosting:vinScratch', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    local contract = activeContracts[identifier]
    if not contract or contract.vinScratch ~= 1 then return end
    -- custom logic to grant vehicle
    TriggerClientEvent('ox_lib:notify', src, { description = 'VIN scratched. Vehicle is now yours (placeholder).', type = 'success' })
    local pdata = playerData[identifier]
    pdata.rep = math.max(0, pdata.rep - (Config.VINScratch.repLoss or 0))
    MySQL.update('UPDATE boosting_players SET reputation = ? WHERE identifier = ?', { pdata.rep, identifier })
    MySQL.update('UPDATE boosting_contracts SET status = ? WHERE id = ?', { 'vin_scratch', contract.id })
    MySQL.insert('INSERT INTO boosting_runs (contract_id, identifier, action, detail) VALUES (?, ?, ?, ?)', { contract.id, identifier, 'vin_scratch', '' })
    TriggerClientEvent('cg-boosting:reputation', src, { rep = pdata.rep })
    activeContracts[identifier] = nil
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
