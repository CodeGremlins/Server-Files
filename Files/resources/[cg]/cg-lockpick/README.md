# cg-lockpick
Simple lightweight vehicle lockpick system using `ox_target`, `ox_lib` and ESX inventory (ox_inventory). Now includes a fully custom NUI lockpick minigame with tool tiers.

## Features
- Context target on locked vehicles (not inside a vehicle, within 2.0 units)
- Success chance affected by vehicle class
- Lockpick item consumption chances (fail & success) configurable
- Optional police online requirement
- Alarm chance on success/fail
- Progress bar + animation
- Clean separation (client calculates, server validates & consumes item)
- Custom NUI timing minigame (no random success rolls)
- Tool tiers (basic / advanced / master) change pin count, speed, timing window, attempts per pin

## Configuration (`config.lua`)
Key values:
- `Config.LockpickItem`: item name in ox_inventory
Legacy (chance/ox_lib skill check) disabled: success is purely player skill in minigame. Some retained config still used for break & alarms.

Essentials:
`Config.BreakChanceOnFail` / `Config.BreakChanceOnSuccess`
- `Config.MinPolice` + `Config.PoliceJobs`
- Alarm chances: `Config.AlarmChanceFail`, `Config.AlarmChanceSuccess`
Tier System (see `Config.Tiers`):
```
basic    -> moderate speed, 3 pins, forgiving window
advanced -> faster, 4 pins
master   -> fastest, 5 pins, fewer attempts
```
Dynamic vehicle class bonus pins via `Config.ClassPinBonus`.
 - Skill check:
	 - `Config.UseSkillCheck` (bool)
	 - `Config.SkillCheckStages` (array of difficulties: easy/medium/hard/veryhard etc.)
	 - `Config.SkillCheckShowChance` (show base percent text on progress bar if bar enabled)
	 - `Config.SkillCheckRequiresProgress` (show progress bar before starting skill stages)
	 - `Config.SkillCheckAbortOnFail` (stop immediately at first failed stage)

Adjust the notify wrappers if you use a different notification system.

## Adding the Item (ox_inventory example)
If you do not already have a lockpick item:
```sql
INSERT INTO items (name, label, weight, stack, closeonuse, description) VALUES
('lockpick', 'Lockpick', 100, 10, 0, 'Used to unlock vehicles');
```

## Installation
1. Place folder in `resources/[cg]/cg-lockpick`
2. Ensure after core libs in `server.cfg`:
```
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure cg-lockpick
```
3. Add the item to database (above) if missing.
4. Restart server or run `refresh` + `ensure cg-lockpick`.

## Minigame Mechanics
UI displays vertical pin columns. A moving marker travels up/down; press SPACE while marker is inside the green zone to clear a pin. Misses reduce attempts for that pin. Clear all pins before attempts or (if set) global time expires.

Failure conditions:
- Running out of attempts on a pin (with `Config.FailFast = true`)
- Global timer (if configured) reaches zero

On success: vehicle unlocks immediately. On fail: standard alarm & break chance logic triggers. No RNG decides success.

## Tier Items
`lockpick` (basic), `adv_lockpick` (advanced), `master_lockpick` (master). First matching tier in `Config.TierOrder` that you own is chosen.

## Future Ideas
- Alternate patterns (rotating arcs, sequential memory)
- Multi-player assist bonuses
- Audio feedback cues per tier
- Police alert event dispatch with street name
- Difficulty scaling based on time-of-day or player skill
- Tool tiers (basic, advanced) modifying success chance

## Events
- Client: `cg-lockpick:client:itemBroken` fired when the attempt consumes (breaks) the item.
- Server Callback: `cg-lockpick:server:attempt` used internally for permission & validation.

## Uninstall
Remove the resource and related `ensure` line; optional: delete the lockpick item from inventory table if unused elsewhere.

---
Enjoy!
