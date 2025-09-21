local Config = Config
local stock = {}
local ESX

-- Framework init
CreateThread(function()
    if Config.Framework == 'esx' then
        local exportName = Config.ESXExport or 'es_extended.getSharedObject'
        ESX = exports['es_extended']:getSharedObject() or exports['es_extended'][exportName]()
    end
end)

local function getIdentifier(xPlayer)
    return xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
end

local function sendWebhookPurchase(xPlayer, itemName, quantity, total)
    if not Config.Webhook or not Config.Webhook.Enabled or not Config.Webhook.URL or Config.Webhook.URL == '' then return end
    local identifier = getIdentifier(xPlayer)
    local name = xPlayer.getName and xPlayer.getName() or ('ID %s'):format(xPlayer.source)
    local color = (Config.Webhook.Color or 16711680)
    local ts = os.date('!%Y-%m-%d %H:%M:%S UTC')
    local rolePing = ''
    if Config.Webhook.PingRoleId then
        rolePing = string.format('<@&%s> ', Config.Webhook.PingRoleId)
    end
    local description = string.format('**Player:** %s\n**Identifier:** `%s`\n**Item:** `%s` x **%s**\n**Total:** %s\n**Currency:** %s\n**Remaining Stock:** %s\n**Time:** %s', name, identifier, itemName, quantity, total, Config.Currency, (stock[itemName] and stock[itemName].amount or '?'), ts)

    local payload
    if Config.Webhook.UseEmbed then
        payload = json.encode({
            username = Config.Webhook.Username or 'Black Market',
            avatar_url = Config.Webhook.Avatar,
            content = rolePing ~= '' and rolePing or nil,
            embeds = { {
                title = 'Black Market Purchase',
                description = description,
                color = color,
                footer = { text = 'cg-blackmarket' },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%S.000Z')
            } }
        })
    else
        payload = json.encode({
            username = Config.Webhook.Username or 'Black Market',
            avatar_url = Config.Webhook.Avatar,
            content = rolePing .. '**Black Market Purchase**\n' .. description
        })
    end

    PerformHttpRequest(Config.Webhook.URL, function(err, text, headers)
        if err ~= 204 and err ~= 200 then
            print(('[cg-blackmarket] Webhook error (%s): %s'):format(err, text or ''))
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

local function loadStock()
    if not Config.PersistStock then
        for _, item in ipairs(Config.Items) do
            stock[item.name] = { amount = item.start or item.max, max = item.max, price = item.price, label = item.label, metadata = item.metadata, license = item.license, give = item.give }
        end
        return
    end
    MySQL.query('SELECT item, amount FROM cg_blackmarket_stock', {}, function(rows)
        local existing = {}
        for _, r in ipairs(rows) do existing[r.item] = r.amount end
        for _, item in ipairs(Config.Items) do
            local amount = existing[item.name]
            if amount == nil then
                amount = item.start or item.max
                MySQL.insert('INSERT INTO cg_blackmarket_stock (item, amount) VALUES (?, ?)', { item.name, amount })
            end
            stock[item.name] = { amount = amount, max = item.max, price = item.price, label = item.label, metadata = item.metadata, license = item.license, give = item.give }
        end
        print('[cg-blackmarket] Stock loaded.')
    end)
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        loadStock()
    end
end)

-- Purchase handler
lib.callback.register('cg-blackmarket:buyItem', function(source, itemName, quantity)
    local src = source
    local xPlayer
    if ESX then xPlayer = ESX.GetPlayerFromId(src) end
    if not xPlayer then return false, 'no_player' end

    local entry = stock[itemName]
    if not entry then return false, 'invalid' end
    quantity = math.floor(tonumber(quantity) or 1)
    if quantity < 1 then quantity = 1 end
    if entry.amount < quantity then return false, 'no_stock' end

    -- License check
    if entry.license then
        local has = exports.ox_inventory:Search(src, 'count', entry.license)
        if (has or 0) < 1 then
            return false, 'missing_license'
        end
    end

    -- Currency deduction
    local total = entry.price * quantity
    local currency = Config.Currency
    local paid = false

    if currency:sub(1,8) == 'account:' then
        local accountName = currency:sub(9)
        local account = xPlayer.getAccount(accountName)
        if not account or account.money < total then return false, 'not_enough' end
        xPlayer.removeAccountMoney(accountName, total, ('BlackMarket %s x%s'):format(itemName, quantity))
        paid = true
    elseif currency == 'money' then
        if xPlayer.getMoney() < total then return false, 'not_enough' end
        xPlayer.removeMoney(total, ('BlackMarket %s x%s'):format(itemName, quantity))
        paid = true
    else
        -- treat as inventory item name (e.g., 'black_money' item token)
        local count = exports.ox_inventory:Search(src, 'count', currency)
        if (count or 0) < total then return false, 'not_enough' end
        exports.ox_inventory:RemoveItem(src, currency, total)
        paid = true
    end

    if not paid then return false, 'currency' end

    -- Add item(s) with give multiplier (e.g. ammo packs)
    local giveMult = entry.give or 1
    local addAmount = quantity * giveMult
    local success = exports.ox_inventory:AddItem(src, itemName, addAmount, entry.metadata)
    if not success then
        -- refund
        if currency:sub(1,8) == 'account:' then
            xPlayer.addAccountMoney(currency:sub(9), total, 'Refund BlackMarket failure')
        elseif currency == 'money' then
            xPlayer.addMoney(total, 'Refund BlackMarket failure')
        else
            exports.ox_inventory:AddItem(src, currency, total)
        end
        return false, 'inventory_full'
    end

    entry.amount = entry.amount - quantity
    if Config.PersistStock then
        MySQL.update('UPDATE cg_blackmarket_stock SET amount = ? WHERE item = ?', { entry.amount, itemName })
    end

    if Config.LogPurchases then
        print(('[cg-blackmarket] %s bought %s x%s (gave %s) for %s'):format(getIdentifier(xPlayer), itemName, quantity, addAmount, total))
    end

    -- Webhook
    sendWebhookPurchase(xPlayer, itemName, addAmount, total)

    return true, entry.amount
end)

-- Provide list to client
lib.callback.register('cg-blackmarket:getStock', function(source)
    local list = {}
    for name, v in pairs(stock) do
        list[#list+1] = { name = name, label = v.label or name, price = v.price, amount = v.amount, max = v.max, license = v.license, give = v.give }
    end
    return list
end)

-- Restock logic
local function restock(full)
    for _, item in ipairs(Config.Items) do
        local entry = stock[item.name]
        if entry then
            if full or Config.RestockMode == 'full' then
                entry.amount = item.max
            else
                entry.amount = math.min(entry.amount + Config.RestockAmount, entry.max)
            end
            if Config.PersistStock then
                MySQL.update('UPDATE cg_blackmarket_stock SET amount = ? WHERE item = ?', { entry.amount, item.name })
            end
        end
    end
    TriggerClientEvent('ox_lib:notifyAll', { title = 'Black Market', description = _L('restocked'), type = 'inform' })
end

if Config.RestockInterval > 0 then
    CreateThread(function()
        while true do
            Wait(Config.RestockInterval * 60000)
            restock(false)
        end
    end)
end

-- Admin command
RegisterCommand(Config.RestockCommand, function(source, args)
    if source == 0 then
        restock(true)
        print('[cg-blackmarket] Manual restock (console)')
        return
    end
    local xPlayer = ESX and ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    for _, g in ipairs(Config.AdminGroups) do
        if g == group then
            restock(true)
            TriggerClientEvent('ox_lib:notify', source, { title = 'Black Market', description = _L('restocked'), type = 'success' })
            return
        end
    end
end)
