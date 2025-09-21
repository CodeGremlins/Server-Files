Config = {}

-- Reputation tiers unlocking contract tiers
Config.Tiers = {
    { name = 'D', repRequired = 0,    basePayout = { min = 1500, max = 2500 },  trackerChance = 0.10, policeChance = 0.05, time = 15 * 60, repGain = 5,  tools = { lockpick = true } },
    { name = 'C', repRequired = 200,  basePayout = { min = 2500, max = 4000 },  trackerChance = 0.20, policeChance = 0.08, time = 18 * 60, repGain = 7,  tools = { lockpick = true } },
    { name = 'B', repRequired = 500,  basePayout = { min = 4000, max = 6500 },  trackerChance = 0.35, policeChance = 0.12, time = 22 * 60, repGain = 10, tools = { lockpick = true, hacking = true } },
    { name = 'A', repRequired = 1000, basePayout = { min = 6500, max = 10000 }, trackerChance = 0.55, policeChance = 0.18, time = 25 * 60, repGain = 14, tools = { lockpick = true, hacking = true, jammer = true } },
    { name = 'S', repRequired = 1800, basePayout = { min = 12000, max = 18000 }, trackerChance = 0.75, policeChance = 0.25, time = 30 * 60, repGain = 20, tools = { lockpick = true, hacking = true, jammer = true, trailer = true } },
}

-- VIN scratch settings
Config.VINScratch = {
    enabled = true,
    cooldownHours = 24,
    repLoss = 50, -- optional risk
    chance = 0.15, -- base chance that a contract is VIN scratchable
    requireTrackerRemoved = true -- must fully remove tracker before VIN scratch allowed
}

Config.ContractRequest = {
    baseCooldown = 60, -- seconds between requestContract attempts
    dailyCap = 25,
    maxActive = 1,
    queueSize = 5
}

Config.Dispatch = {
    enabled = true,
    eventName = 'police:server:boostDispatch',
}

-- Drop-off locations (updated per user request)
-- Provided values interpreted as three groups: (x,y,z,heading). Heading kept for future use, currently only x,y,z used.
Config.DropOffs = {
    vector4(319.3009, 3405.4067, 36.7479, 253.0479),
    vector4(2416.3062, 3095.9504, 48.1529, 40.1105),
    vector4(1130.6948, -794.9101, 57.4747, 251.6035)
}

-- Vehicles pool per tier (placeholder)
Config.Vehicles = {
    D = { 'asea', 'issi2', 'blista' },
    C = { 'sultan', 'f620', 'felon' },
    B = { 'comet2', 'buffalo', 'elegy2' },
    A = { 'italigtb', 'coquette', 'seven70' },
    S = { 'tyrus', 'entityxf', 'pfister811' }
}

-- Potential spawn points for boosting targets (expand as needed)
Config.Spawns = {
    vector4(215.12, -810.43, 30.73, 157.0),
    vector4(-42.51, -1098.64, 26.42, 70.0),
    vector4(-1184.92, -1549.82, 4.38, 215.0),
    vector4(1204.25, -3115.44, 5.54, 90.0),
    vector4(1733.67, 3310.14, 41.22, 20.0),
    vector4(-3043.21, 1196.65, 20.59, 340.0)
}

Config.Debug = false

-- Anti-abuse / failure handling
Config.AntiAbuse = {
    failOnVehicleDestroyed = true,   -- fail contract if target vehicle destroyed or despawns
    engineHealthThreshold = 50.0,    -- if engine health drops below this treat as destroyed (0.0 to disable threshold check)
    repPenalty = 5                   -- reputation loss on failure (set 0 to disable)
}

-- Item required to open the tablet UI
Config.TabletItem = 'water'
Config.RequireTabletItem = true

-- Delivery handling configuration
Config.Delivery = {
    radius = 6.0,            -- meters radius for valid drop
    ignoreZ = true,          -- ignore vertical difference when checking distance
    autoComplete = false,    -- we now require key press instead of auto
    requireKeyPress = true,  -- press E in zone to deliver
    key = 38,                -- default control (E)
    requireDriver = true,    -- must be in driver seat
    requireInsideVehicle = true, -- must be inside the boosted vehicle
    showMarkerDistance = 60.0,   -- draw marker when within this distance
    marker = { r = 30, g = 190, b = 120, a = 140 },
    promptOffsetZ = 0.5,     -- 3D text offset
}

-- Blip settings for target vehicle (entity-attached)
Config.TargetBlip = {
    enabled = true,
    sprite = 225,
    colour = 2,
    scale = 0.85,
    route = true,       -- enable GPS route to moving target
    label = 'Boost Target'
}

-- Tracker hacking system
Config.Tracker = {
    enabled = true,                -- only applies if contract.tracker == true
    hackAttempts = 5,              -- number of successful hacks to permanently remove tracker
    disableDurations = { 15, 25, 40, 60, 90 }, -- seconds disabled per successful hack (indexed by attempt #)
    hackKey = 74,                  -- default H
    requireRemovalToDeliver = true,-- must fully remove tracker before delivery allowed
    progress = { duration = 5000, label = 'Bypassing Tracker...' }, -- optional ox_lib progress style
    hackItem = 'hacking_laptop',   -- item required to perform each hack attempt
    consumeItem = false,           -- set true if you want to remove one item per attempt
    minigame = {
        enabled = true,
        -- sequence of difficulty steps for ox_lib skillcheck
        sequence = { 'easy', 'medium', 'medium', 'hard' },
        allowFailRetry = true,     -- if false failing one step consumes attempt time window
        failCooldown = 5           -- seconds lockout after failed sequence (client side gate)
    },
    removalBonusPercent = 15       -- extra payout percent if tracker removed before delivery
}

-- Additional VIN scratch bonus (applied on delivery if scratched)
Config.VINScratch.bonusPercent = 20 -- extra payout percent when scratched (e.g. +20%)

-- Police tracker blip / ping settings
Config.Police = {
    jobs = { 'police', 'sheriff' },   -- job names considered law enforcement
    pingInterval = 15,                -- seconds between automatic pings while tracker active
    showWhileDisabled = false,        -- if true, pings still appear when tracker temporarily disabled
    removeOnDisable = true,           -- remove blip immediately when disabled (until re-enabled)
    blip = {
        sprite = 225,
        colour = 1,
        scale = 0.9,
        label = 'Stolen Vehicle'
    }
}
