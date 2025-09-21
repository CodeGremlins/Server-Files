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

Config.DropOffs = {
    vector3(1234.5, -3012.3, 5.9),
    vector3(-456.2, -1023.4, 28.3),
    vector3(234.7, 2178.5, 130.4)
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

-- Item required to open the tablet UI
Config.TabletItem = 'boosting_tablet'
Config.RequireTabletItem = true
