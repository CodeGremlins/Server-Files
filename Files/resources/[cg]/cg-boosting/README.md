# cg-boosting

Car Boosting Tablet for ESX using ox_lib & oxmysql.

## Features (Implemented in this MVP)
- Tiered contracts (D -> S) with payouts, tracker chance, reputation gain
- Reputation stored in DB; unlocks higher tier generation
- Request / Accept / Decline contract flow with queue & cooldown
- VIN scratch flag (placeholder ownership grant) with rep loss
- NUI tablet UI (open with /boost) listing contracts & details
- Server-side validation for contract acceptance & delivery timing
- Logging tables for auditing
 - Dynamic target vehicle blip (attached to entity once spawned, with route option)

## Not Yet / Roadmap
- Crew matchmaking / invites
- Tracker removal actual minigame & police dispatch probability
- Improved drop-off delivery validation (radius, driver/vehicle checks, configurable)
- Advanced anti-exploit (distance, vehicle ownership, zone checks)
- Daily reset logic for requests (skeleton table `boosting_settings`)
- Police integration dispatch event stub

## Installation
1. Place resource in `resources/[cg]/cg-boosting`.
2. Import SQL file `sql/boosting.sql` into your database.
3. Ensure dependencies installed: es_extended, ox_lib, oxmysql.
4. Add to your server.cfg after dependencies:
```
ensure cg-boosting
```
5. Restart server.

## Commands
- `/boost` open the tablet.

## Events & Callbacks
Client -> Server Events:
- `cg-boosting:requestContract`
- `cg-boosting:acceptContract`, args: (contractId)
- `cg-boosting:declineContract`, args: (contractId)
- `cg-boosting:completeDelivery`
- `cg-boosting:vinScratch`

Server -> Client Events:
- `cg-boosting:updateContracts` (table of contracts)
- `cg-boosting:contractAccepted` (contract data)
- `cg-boosting:reputation` ({ rep = number })

lib Callbacks:
- `cg-boosting:fetchContracts`
- `cg-boosting:fetchReputation`

## Configuration
See `config.lua` for:
- Tier definitions (rep, payout range, tracker/police probability, time limit, rep gain, required tools)
- VIN scratch enable, cooldown (future), rep loss
- Contract request cooldown, queue size, daily cap
- Dispatch toggle + event name
- Vehicle pools per tier
- Delivery settings (`Config.Delivery`):
	- `radius`: radius (meters) for successful delivery (default 6.0)
	- `ignoreZ`: ignore vertical difference (useful for ramps / multi-level)
	- `autoComplete`: automatically tries completion when you drive into zone
	- `requireDriver`: must be driver seat
	- `requireInsideVehicle`: must be inside target vehicle
	- `showMarkerDistance`: draws marker inside this distance
	- `marker`: RGBA marker color
 - Target vehicle blip (`Config.TargetBlip`): `enabled`, `sprite`, `colour`, `scale`, `route`, `label`

## Database Tables
- `boosting_players`: Player rep and request counters
- `boosting_contracts`: Persist accepted contracts
- `boosting_runs`: Log of actions (accept, complete, vin_scratch)
- `boosting_settings`: Placeholder for daily resets

## TODO (inline in code)
Search for `TODO` comments to implement validation & gameplay enhancements.

## Security & Anti-Exploit (Current Approach)
- Server only creates & owns authoritative contract state
- Payouts & rep granted only server-side upon completion
- VIN scratch rep adjustment server-side

Further enhancements recommended: enhanced entity anti-spoofing (plate/net id double-check), police dispatch integration, exploit logging (attempted wrong vehicle deliveries).

## Delivery Testing
1. Accept a contract and note the Drop-Off blip.
2. Spawned target car will have plate prefix matching contract id segment.
3. Drive vehicle into marker; with `autoComplete = true` it should finish automatically.
4. If auto-complete disabled, open tablet -> Complete Delivery button.
5. If delivery fails, enable `Config.Debug = true` and re-test to see precise reason messages.

## Contributing
PRs welcome for minigames, police integration, matchmaking.

---
MVP prepared. Extend as desired.
