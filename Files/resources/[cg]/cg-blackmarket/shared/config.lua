Config = {}

-- Framework detection (assumes ESX legacy or new export)
Config.Framework = 'esx' -- future: add qb support
Config.ESXExport = 'es_extended.getSharedObject'

-- Currency: set to inventory item token for ox_inventory based currency (e.g. 'black_money', 'dirty_money', 'markedbills')
Config.Currency = 'money'

-- How stock is persisted
Config.PersistStock = true
-- How often (minutes) to automatically restock (set 0 to disable auto restock)
Config.RestockInterval = 120
-- Restock mode: 'full' sets each item back to max, 'additive' adds RestockAmount per cycle up to max
Config.RestockMode = 'additive'
Config.RestockAmount = 2

-- Command for admins to force restock
Config.RestockCommand = 'bmrestock'
Config.AdminGroups = { 'admin', 'superadmin', 'god' }

-- Log purchase events to server console
Config.LogPurchases = true

-- UI options
Config.UseTabletUI = true       -- if true uses NUI tablet interface instead of ox_lib context menu
Config.IconExtension = 'png'    -- expected extension for ox_inventory web image export (usually png/webp)
-- If you mount ox_inventory web build (default) icons are accessible at /nui://ox_inventory/web/images/<item>.<ext>
-- If you changed build path adjust below; JS builds from item name automatically.

-- Discord webhook logging
Config.Webhook = {
    Enabled = true,                 -- set true and add URL to enable
    URL = 'https://discord.com/api/webhooks/1419097027450638488/yNTBJuHT3XEW-0pBhxecOZbV9jO5rMWdcQ7yw4Q9EqVfMX3rz1EG0ywTj7jH9vxPRnQ6',
    Username = 'Black Market',
    Avatar = 'https://i.imgur.com/3GZQPQZ.png', -- optional image
    Color = 16711680,                -- decimal embed color (red default)
    UseEmbed = true,
    PingRoleId = nil                 -- optionally set a role ID to ping (string), or nil
}

-- Ped / target interaction distance
Config.TargetDistance = 2.0

-- Items sold. Each entry:
-- name = item name in ox_inventory / ESX items table
-- price = unit price (in chosen currency)
-- max = maximum stock capacity (if PersistStock = true)
-- start = starting stock (nil => max)
-- minGrade = optional job grade requirement when restricted to job
-- jobs = optional { 'jobname1', 'jobname2' } restrict to these jobs only
-- license = optional license item required (e.g. 'weaponlicense')
-- metadata = optional metadata table passed to addItem (use for serial numbers etc.)
-- Optional field `give` lets you deliver multiple actual items per 1 unit of stock purchased (useful for ammo packs).
Config.Items = {
    { name = 'weapon_pistol', label = 'Pistol', price = 25000, max = 5, start = 3 },
    { name = 'ammo-9', label = 'Ammo x30', price = 3500, max = 30, start = 15, give = 30 },
    { name = 'lockpick', label = 'Lockpick', price = 1800, max = 40 },
    { name = 'bandage', label = 'Bandage', price = 750, max = 50 },
}

-- Black market locations (can have more than one) each with npc + optional schedule.
-- time = { start = 0, stop = 24 } 24h; Use 0-24 hour integers.
Config.Locations = {
    {
        id = 'docks',
    -- Using vector3 for FiveM (vec3 also works if using ox_lib helper)
        coords = vector3(1274.66, -1710.12, 54.77),
        heading = 213.64,
        ped = 'g_m_m_armboss_01',
        scenario = 'WORLD_HUMAN_LEANING', -- optional
        blip = false, -- or { sprite= 84, colour= 1, scale=0.8, text='Shady Dealer' }
        time = { start = 0, stop = 24 },
        radius = 1.2,
    }
}

-- Locale selection
Config.Locale = 'en'

return Config
