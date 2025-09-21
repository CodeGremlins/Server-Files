local ESX

CreateThread(function()
    while ESX == nil do
        ESX = exports['es_extended']:getSharedObject()
        if ESX == nil then Wait(100) end
    end
end)

local uiOpen = false

local function openUI()
    if uiOpen then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    -- fetch jobs
    lib.callback('cg-jobcenter:getJobs', false, function(jobs)
        SendNUIMessage({ action = 'jobs', data = jobs })
    end)
end

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb(1)
end)

RegisterNUICallback('apply', function(data, cb)
    local job = data and data.job
    local motivation = data and data.motivation or ''
    TriggerServerEvent('cg-jobcenter:apply', job, motivation)
    cb(1)
end)

RegisterCommand(Config.Command, function()
    openUI()
end)

RegisterKeyMapping(Config.Command, 'Open Job Center', 'keyboard', 'F6')

-- Target integration
if Config.UseTarget then
    CreateThread(function()
        local model = joaat(Config.PedModel)
        lib.requestModel(model, 5000)
        local ped = CreatePed(0, model, Config.Location.x, Config.Location.y, Config.Location.z - 1.0, Config.Heading, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)

        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'cg_jobcenter_ped',
                icon = 'fa-solid fa-terminal',
                label = 'Open Job Center',
                distance = Config.TargetDistance,
                onSelect = function()
                    openUI()
                end
            }
        })
    end)
end

-- ESC key close binding (NUI side also handles)
RegisterNUICallback('escape', function(_, cb)
    closeUI()
    cb(1)
end)

-- Optional: close when player dies
AddEventHandler('esx:onPlayerDeath', function()
    closeUI()
end)
