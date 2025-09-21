local spawnedPeds = {}
local usingTablet = Config.UseTabletUI
local tabletOpen = false

local function timeIsAllowed(loc)
    if not loc.time then return true end
    local hour = GetClockHours()
    if loc.time.start <= loc.time.stop then
        return hour >= loc.time.start and hour < loc.time.stop
    else -- overnight wrap
        return hour >= loc.time.start or hour < loc.time.stop
    end
end

local function setupLocation(loc)
    local model = joaat(loc.ped or 'g_m_m_armboss_01')
    lib.requestModel(model)
    local ped = CreatePed(0, model, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.heading or 0.0, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if loc.scenario then
        TaskStartScenarioInPlace(ped, loc.scenario, 0, true)
    end

    spawnedPeds[loc.id] = ped

    -- target zone/box
    local targetOptions = {
        {
            name = 'cg_blackmarket_'..loc.id,
            label = _L('open_market'),
            icon = 'fa-solid fa-sack-dollar',
            distance = Config.TargetDistance,
            onSelect = function()
                if not timeIsAllowed(loc) then
                    lib.notify({ title = 'Black Market', description = _L('not_open'), type = 'error' })
                    return
                end
                if usingTablet then
                    openTabletUI()
                else
                    openMarketUI()
                end
            end
        }
    }

    exports.ox_target:addLocalEntity(ped, targetOptions)

    if loc.blip then
        local b = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(b, loc.blip.sprite or 84)
        SetBlipColour(b, loc.blip.colour or 1)
        SetBlipScale(b, loc.blip.scale or 0.8)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(loc.blip.text or 'Shady Dealer')
        EndTextCommandSetBlipName(b)
    end
end

-- UI open function (context menu)
function openMarketUI()
    lib.callback('cg-blackmarket:getStock', false, function(items)
        if not items then return end
        local options = {}
        for _, v in ipairs(items) do
            local giveInfo = ''
            if v.give and v.give > 1 then
                giveInfo = (' x%d/each'):format(v.give)
            end
            local label = ('%s - $%s%s (%s/%s)'):format(v.label or v.name, v.price, giveInfo, v.amount, v.max)
            options[#options+1] = {
                title = label,
                description = v.license and ('Requires: '..v.license) or nil,
                event = 'cg-blackmarket:attemptBuy',
                args = { name = v.name }
            }
        end
        lib.registerContext({
            id = 'cg_blackmarket_menu',
            title = 'Black Market',
            options = options
        })
        lib.showContext('cg_blackmarket_menu')
    end)
end

-- Tablet UI (NUI)
function openTabletUI()
    if tabletOpen then return end
    tabletOpen = true
    SetNuiFocus(true, true)
    lib.callback('cg-blackmarket:getStock', false, function(items)
        SendNUIMessage({ action = 'open', items = items })
    end)
end

RegisterNUICallback('close', function(_, cb)
    tabletOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    if not data or not data.name then cb('fail'); return end
    local qty = tonumber(data.qty) or 1
    lib.callback('cg-blackmarket:buyItem', false, function(success, reasonOrRemaining)
        if not success then
            lib.notify({ title='Black Market', description=_L(reasonOrRemaining), type='error' })
            cb('fail')
            return
        end
        lib.notify({ title='Black Market', description=_L('bought_item', qty, data.name), type='success' })
        -- refresh stock inside tablet
        lib.callback('cg-blackmarket:getStock', false, function(items)
            SendNUIMessage({ action = 'refresh', items = items })
        end)
        cb('ok')
    end, data.name, qty)
end)

-- Close tablet if player leaves resource focus (optional: ESC handled in UI)
CreateThread(function()
    while true do
        if tabletOpen and not usingTablet then
            -- safety: should not happen
            SetNuiFocus(false,false)
            tabletOpen = false
        end
        Wait(1000)
    end
end)

RegisterNetEvent('cg-blackmarket:attemptBuy', function(data)
    local input = lib.inputDialog('Purchase Quantity', { { type = 'number', label = 'Amount', default = 1, min = 1, max = 100 } })
    if not input then return end
    local qty = tonumber(input[1]) or 1
    lib.callback('cg-blackmarket:buyItem', false, function(success, reasonOrRemaining)
        if not success then
            lib.notify({ title='Black Market', description=_L(reasonOrRemaining), type='error' })
            return
        end
        lib.notify({ title='Black Market', description=_L('bought_item', qty, data.name), type='success' })
        openMarketUI() -- refresh
    end, data.name, qty)
end)

-- Spawn all locations
CreateThread(function()
    for _, loc in ipairs(Config.Locations) do
        setupLocation(loc)
    end
end)
