# CodeGremlins FiveM Server Base (ESX Legacy + Overextended)

A pre-configured FiveM roleplay server base using ESX Legacy core plus the Overextended (ox) ecosystem (`ox_lib`, `ox_inventory`, `ox_target`, `oxmysql`, etc.), pma-voice, and a curated set of ESX jobs & quality-of-life addons.

This README guides you from a clean machine to a running development instance.

---
## 1. Prerequisites

| Component | Recommended | Notes |
|-----------|------------|-------|
| OS | Windows 10/11 or Ubuntu 22.04 LTS | Production is usually Linux, but dev on Windows is fine |
| Git | Latest | To clone/update this repo |
| Database (MariaDB) | MariaDB 10.6+ (preferred) or MySQL 8+ | Use MariaDB unless you have a strong reason; utf8mb4 required |
| Visual C++ Redistributable | 2019+ | Needed by FiveM artifacts on Windows |
| Node.js (optional) | 18+ LTS | Only if you rebuild any web UIs |
| FXServer Artifact | Current recommended | Download from https://runtime.fivem.net/artifacts/fivem/ |
| txAdmin (bundled) | Latest | Use for easier management |

> Tip: On Windows install MariaDB via MSI, on Linux use apt packages.

---
## 2. Clone the Repository

```powershell
# Choose a working folder
cd C:\Servers
# Clone
git clone https://github.com/CodeGremlins/Server-Files.git CodeGremlinsRP
cd CodeGremlinsRP
```

The important folders:
```
Files/            <- Server data folder (place your artifacts next to this if using run.cmd)
Files/resources/  <- All resources grouped in collections: [core], [esx_addons], [ox], [standalone], [cg]
artifacts/        <- (Optional) Looks like DLLs already staged; you can replace with newer build
```

---
## 3. Obtain & Place FiveM Artifacts

Download the latest recommended Windows artifact from: https://runtime.fivem.net/artifacts/fivem/build_server_windows/.

Extract the contents (e.g. `FXServer.exe`, `.dll` files) into a folder above or parallel to `Files`. Example layout:
```
CodeGremlinsRP/
  ├─ FXServer.exe
  ├─ run.cmd (optional launcher)
  ├─ Files/
  │   ├─ server.cfg
  │   └─ resources/...
```

If you prefer to keep artifacts in the existing `artifacts/` folder, create a simple launcher that points DATA path to `Files`:
```powershell
# run.cmd example
@echo off
FXServer.exe +set serverProfile "default" +set txAdminPort 40120 +set resources_useSystemChat true +exec Files/server.cfg
```

> Ensure you run from the folder that contains `FXServer.exe` so relative resource paths resolve.

---
## 4. Database Setup (MariaDB Recommended)

1. (Install MariaDB) – Prefer MariaDB over MySQL for slightly faster replication handling and broad community usage in FiveM / ESX stacks.
2. Create database:
   ```sql
   CREATE DATABASE codegremlins CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
3. Create a dedicated user (recommended):
   ```sql
   CREATE USER 'fivem'@'localhost' IDENTIFIED BY 'StrongPasswordHere';
   GRANT ALL PRIVILEGES ON codegremlins.* TO 'fivem'@'localhost';
   FLUSH PRIVILEGES;
   ```
4. Update the connection string in `Files/server.cfg` (switch `root:root` to your real user/pass):
   ```
   set mysql_connection_string "mysql://fivem:StrongPasswordHere@localhost/codegremlins?charset=utf8mb4"
   ```
5. Import ESX & addon SQL schemas:
   - Core schemas usually inside each resource (look for `.sql` files, e.g. `es_extended`, `esx_vehicleshop`, `esx_garage/esx_garage.sql`).
   - Run them in this order (approximate):
     1. `oxmysql` (no schema, just ensure running)
     2. `es_extended` base SQL
     3. Foundational ESX addons: addonaccount, addoninventory, datastore, society, identity, status, basicneeds, jobs, joblisting
     4. Remaining job / feature scripts (garage, vehicleshop, properties, policejob, ambulancejob, etc.)

> Always inspect SQL files for duplicate table creation before importing to avoid conflicts.

---
## 5. License Keys & Secrets

Edit `Files/server.cfg`:
```cfg
sv_licenseKey "YOUR_FIVEM_LICENSE_KEY"
sv_hostname "CodeGremlins | Dev"
sets sv_projectName "CodeGremlins RP"
sets sv_projectDesc "ESX Legacy + Overextended Base"
```
Obtain key at: https://portal.cfx.re/servers/registration-keys

> Never commit real license keys or database passwords to version control.

---
## 6. Resource Collections Explanation

| Collection | Purpose |
|------------|---------|
| `[core]` | ESX Legacy core modules (es_extended, menus, inventory, identity, skinchanger, multichar, notify, textui) |
| `[esx_addons]` | ESX jobs & feature addons (garage, policejob, vehicleshop, society, status, etc.) |
| `[ox]` | Overextended stack (`ox_lib`, `ox_inventory`, `ox_target`, `oxmysql`, `ox_fuel`, `ox_doorlock`) |
| `[standalone]` | Standalone dependencies (pma-voice, bob74_ipl) |
| `[cg]` | Custom CodeGremlins scripts (our custom logic) |

The `ensure` order in `server.cfg` already respects dependencies (core → ox → standalone/addons/custom).

---
## 7. Voice (pma-voice)
`pma-voice` convars already in `server.cfg`:
```cfg
setr voice_enableRadioAnim 1
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
```
Adjust additional ranges or radio settings in the resource config if needed.

---
## 8. Starting the Server (txAdmin GUI)

1. Run `FXServer.exe` (first launch opens txAdmin setup in browser).  
2. Choose: "Create a new server" → Select existing folder → point data path to the `Files` directory.  
3. Import or point to `Files/server.cfg`.  
4. Set your admin password, then start the recipe.
5. Verify console shows `Started resource es_extended` and `oxmysql` connects successfully.

### Direct Launch (without txAdmin)
```powershell
FXServer.exe +exec Files/server.cfg
```

---
## 9. Testing Basic Flow

1. Start server → open FiveM client → Direct connect to `127.0.0.1:30120`.
2. Create character (ESX identity / multichar flow).  
3. Use a garage marker to test the remade UI (`esx_garage`).  
4. Check inventory (`ox_inventory`) opens and no console errors leak.  
5. Test a job (e.g., set job via admin command or database) and verify society accounts loaded.

---
## 10. Common Configuration Tweaks
| Goal | Where |
|------|-------|
| Change language | Uncomment `setr esx:locale "en"` (or other) in `server.cfg` |
| Adjust player cap | `sv_maxclients` in `server.cfg` |
| Add admin | Add principal line with your identifier in `server.cfg` |
| Add/Remove jobs | SQL + edit job-related resources in `[esx_addons]` |
| Change fuel system | Configure or replace `ox_fuel` |
| Disable a feature | Comment out its `ensure` line |

---
## 11. Upgrading Artifacts / Resources

1. Stop server.
2. Backup `Files/` & database.
3. Replace artifact files with newer build.
4. Update `ox_lib` first when upgrading overextended stack.
5. Check each resource's CHANGELOG for breaking convar changes.
6. Start server and watch first 200 lines for warnings.

---
## 12. Troubleshooting
| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `Failed to fetch MySQL interface` | `oxmysql` not ensured early or bad connection string | Ensure `oxmysql` before ESX core; verify credentials |
| Character creation loop | Missing `users` table or `es_extended` SQL not imported | Re-import base SQL |
| Inventory not opening | Missing `ox_lib` / outdated dependency | Update `ox_lib` & ensure it's before `ox_inventory` |
| Garage UI empty | No stored vehicles, or encoding mismatch | Verify vehicles saved; check server console for `esx_garage` errors |
| Voice not working | Wrong pma-voice config or ports blocked | Open UDP 30120; review pma-voice fxmanifest & config |
| High CPU usage | Debug prints or spammy loops in custom scripts | Profile with `profiler record` |

---
## 13. Security & Production Hardening
- Use a non-root DB user with limited privileges (already suggested above).
- Set a strong `sv_master1` (FiveM handles; do not expose unnecessary ports).
- Do not leave `sv_maxclients 1` for production.
- Rotate license key if leaked.
- Enable Cloudflare/Firewall rules if exposing MySQL (prefer not to).  
- Regularly backup both database and the `Files/` directory (resources + config overrides).

---
## 14. Adding New Resources
1. Drop the resource folder into an appropriate collection (`[standalone]` for independent, `[esx_addons]` if it binds to ESX).
2. Add `ensure resourceName` AFTER its dependencies.
3. If it has SQL, import before first launch.
4. Restart server (or `refresh` + `ensure` via console for hot-add if dependency graph simple).

---
## 15. The `esx_garage` Remade UI
You now have a redesigned NUI (cards, search, condition bar). To tweak:
- UI HTML: `Files/resources/[esx_addons]/esx_garage/nui/ui.html`
- Styles: `.../css/app.css`
- Logic: `.../js/app.js`
Add localization keys (`no_veh_parking`, `no_veh_impounded`) via the Lua send payload if desired.

---
## 16. Backup Strategy (Suggested)
- Nightly DB dump: `mysqldump -u fivem -p codegremlins > backups/$(date +%F).sql`
- Weekly full zip of `Files/` excluding cache.

---
## 17. Next Recommended Enhancements
- Add logging/metrics (e.g. txAdmin health exports or a lightweight Prometheus exporter).
- Migrate any password-like config values to environment variables or a secrets file not committed.
- Add CI step to lint Lua (luacheck) & validate fxmanifest syntax.
- Implement automated SQL migration scripts.

---
## 18. Quick Start Cheat Sheet
```powershell
# 1. Clone
git clone https://github.com/CodeGremlins/Server-Files.git CodeGremlinsRP
cd CodeGremlinsRP

# 2. Configure DB (adjust credentials) in Files/server.cfg
# 3. Import SQL schemas (es_extended first, then addons)

# 4. Launch (after placing artifacts)
FXServer.exe +exec Files/server.cfg

# 5. Connect in FiveM client
Direct Connect -> 127.0.0.1:30120
```

---
## 19. Support / Attribution
- ESX Framework: https://esx-framework.org/
- Overextended (ox): https://overextended.dev/
- pma-voice: https://github.com/AvarianKnight/pma-voice

For custom issues open an Issue or PR in this repository.

---
**Happy modding!**
