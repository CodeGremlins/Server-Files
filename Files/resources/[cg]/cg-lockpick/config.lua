Config = {}

-- Name of the usable item representing a lockpick
Config.LockpickItem = 'lockpick'

-- Minimum police (optional); set to 0 to disable requirement
Config.MinPolice = 0
Config.PoliceJobs = { 'police', 'sheriff' }

-- Base success chance (0-100). Modified by vehicle class below.
Config.BaseSuccess = 55
-- Chance (0-100) the lockpick breaks on failed attempt.
Config.BreakChanceOnFail = 35
-- Chance it breaks even on success (adds risk) 0 to disable.
Config.BreakChanceOnSuccess = 10

-- Additional difficulty modifiers by vehicle class (game vehicle class index)
-- Positive lowers success (harder), negative increases success
Config.ClassDifficulty = {
    [1] = 5,   -- Sedans
    [2] = 8,   -- SUVs
    [7] = 12,  -- Super
    [6] = 10,  -- Sports
}

-- Animation & progress settings
Config.PickDuration = 7500  -- ms
Config.ProgressLabel = 'Lockpicking vehicle...'

-- Alarm trigger chance on failure (0-100)
Config.AlarmChanceFail = 50
-- Alarm trigger chance on success (0-100)
Config.AlarmChanceSuccess = 15

-- Enable to print debug info to console & extra notifications
Config.Debug = false

-- Skill check (minigame) settings using ox_lib's lib.skillCheck
-- (Deprecated path) Keep false so we exclusively use custom NUI minigame now
Config.UseSkillCheck = false
Config.SkillCheckStages = { }
Config.SkillCheckShowChance = false
Config.SkillCheckRequiresProgress = false
Config.SkillCheckAbortOnFail = false

-- TIER SYSTEM for custom NUI lockpick
-- Each tier can define:
--  requiredItem: item name required to use that tier (nil = always available)
--  pins: number of pins (columns) player must clear
--  window: ms timing window to press inside the moving marker zone
--  speed: base speed multiplier for marker movement (higher = faster)
--  attemptsPerPin: how many misses allowed on each pin before entire attempt fails
--  failBreakModifier: added % break chance on a fail (applied to base failure break chance)
--  classDifficulty: optional per-vehicle-class adjustments overriding/adding to global modifiers
Config.Tiers = {
    basic = {
        requiredItem = 'lockpick',
        pins = 3,
        window = 180, -- ms
        speed = 1.0,
        attemptsPerPin = 2,
        failBreakModifier = 10,
    },
    advanced = {
        requiredItem = 'adv_lockpick',
        pins = 4,
        window = 140,
        speed = 1.25,
        attemptsPerPin = 2,
        failBreakModifier = 5,
    },
    master = {
        requiredItem = 'master_lockpick',
        pins = 5,
        window = 110,
        speed = 1.4,
        attemptsPerPin = 1,
        failBreakModifier = 0,
    }
}

-- Order tiers checked (first the player qualifies for will be used)
Config.TierOrder = { 'master', 'advanced', 'basic' }

-- Base break chance adjustments: we reuse Config.BreakChanceOnFail / Success but can add tier modifiers
Config.TierBreakBonusSuccess = {
    basic = 0,
    advanced = -5, -- reduces break chance on success
    master = -10,
}
Config.TierBreakBonusFail = {
    basic = 0,
    advanced = -3,
    master = -5,
}

-- Vehicle class scaling may increase pin count dynamically (optional)
Config.ClassPinBonus = {
    [7] = 1, -- Super
    [6] = 1, -- Sports
}

-- Maximum extra pins added from class bonus
Config.MaxClassBonusPins = 2

-- If true, fail early when any pin runs out of attempts; if false allow continuing but mark failure at end
Config.FailFast = true

-- Time allowed (ms) for entire minigame (0 = unlimited)
Config.GlobalTimeLimit = 0

-- NUI styling / theming (simple config hooks)
Config.NUITheme = {
    accent = '#4ade80',
    danger = '#ef4444',
    bg = 'rgba(15,15,18,0.88)',
}

-- Notify function wrappers (can replace with custom framework events)
function NotifySuccess(msg) lib.notify({ title = 'Lockpick', description = msg, type = 'success' }) end
function NotifyError(msg) lib.notify({ title = 'Lockpick', description = msg, type = 'error' }) end
function NotifyInfo(msg) lib.notify({ title = 'Lockpick', description = msg, type = 'inform' }) end

-- Internal debug helper
function LPDebug(msg)
    if Config.Debug then
        print(('^3[cg-lockpick]^7 %s'):format(msg))
        lib.notify({ title = 'Lockpick Debug', description = msg, type = 'inform' })
    end
end
