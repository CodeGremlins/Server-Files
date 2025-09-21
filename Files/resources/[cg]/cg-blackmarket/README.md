# cg-blackmarket

Black Market script for ESX using ox_lib, ox_inventory, ox_target and oxmysql.

## Features
- Persistent (or ephemeral) stock with automatic timed restock.
- Additive or full restock mode.
- License requirement per item (checks inventory item as license).
- Multiple locations / peds supported.
- Context menu UI via ox_lib OR optional in-game tablet NUI interface (Config.UseTabletUI).
- Currency can be ESX account (e.g. account:black_money), regular money, or any inventory item token.
 - Admin restock command.
 - Optional Discord webhook logging for purchases (embed or plain; role ping support).

## Dependencies
Required resources (start before this resource):
- es_extended (ESX)
- oxmysql
- ox_lib
- ox_inventory
- ox_target

## Installation
1. Place the `cg-blackmarket` folder into `resources/[name of folder]/` (already structured).
2. Import `sql/install.sql` into your database.
3. Ensure dependencies are started in `server.cfg` before this resource.
4. Add `ensure cg-blackmarket` to your `server.cfg`.
5. Restart the server or start the resource.

## Configuration
Edit `shared/config.lua`:
- `Currency`: choose `money`, `account:black_money`, or an item name.
- `Items`: Add entries: `{ name, label, price, max, start, license }`.
- `Locations`: Add additional dealer spots with ped model, coords and Blip (or false).
- `RestockInterval`: Minutes between auto restocks (0 disables).
- `RestockMode`: `full` or `additive`.
 - `UseTabletUI`: true switches to immersive tablet interface (NUI). False uses ox_lib context menu.
 - `Webhook`: Enable purchase logging: `Enabled`, `URL`, `Username`, `Avatar`, `Color` (decimal), `UseEmbed`, `PingRoleId`.

## Commands
- `/bmrestock` (configurable): Restock all items (admin groups defined in config or console).

## Callbacks / Events
Client uses lib.callback:
- `cg-blackmarket:getStock` => returns table of items with amount/max.
- `cg-blackmarket:buyItem` (server) internal only via UI.

## Localization
Edit or add entries in `shared/locale.lua` and switch `Config.Locale`.

## Roadmap Ideas
- Job restricted markets
- Dynamic price scaling
 - Advanced webhook templating / multi-channel logs

## Support
Use at your own risk; adapt to your server's conventions.
