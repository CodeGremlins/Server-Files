## cg-jobcenter

Job Center script for ESX using ox_lib and oxmysql. Terminal‑style UI (dark background, monospace, green/amber accents) where players can view available jobs and submit applications.

### Features
* Command (default: `/jobcenter`) + optional ox_target ped access
* Pulls jobs from `jobs` table (name + label)
* Filters out unwanted jobs via `Config.ExcludedJobs`
* Players can write a short motivation and apply
* Applications stored in `job_applications` table
* Server validates length, cooldown, and job existence
* (Optional) Auto hire on application (`Config.AutoAssign`)
* Notifications via `lib.notify`

### Dependencies
* es_extended (exported shared object)
* ox_lib
* oxmysql
* (Optional, recommended) ox_target

### Installation
1. Place the folder `[name of folder]/cg-jobcenter` inside your resources.
2. Import the SQL:
```sql
-- job applications table
CREATE TABLE IF NOT EXISTS `job_applications` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`identifier` VARCHAR(64) NOT NULL,
	`job` VARCHAR(50) NOT NULL,
	`motivation` TEXT NULL,
	`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (`id`),
	INDEX `idx_identifier` (`identifier`),
	INDEX `idx_job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
3. Ensure oxmysql is configured correctly in `server.cfg`.
4. Add to `server.cfg` (after dependencies):
```
ensure ox_lib
ensure oxmysql
ensure [name of folder with scripts]
```

### Configuration (`config.lua`)
| Field | Description |
|-------|-------------|
| `Config.Command` | Chat command to open UI |
| `Config.UseTarget` | Whether to spawn ox_target ped |
| `Config.PedModel` | Ped model name |
| `Config.Location` | Vector3 spawn position for ped |
| `Config.Heading` | Ped heading |
| `Config.TargetDistance` | Interaction distance for target |
| `Config.ExcludedJobs` | Jobs hidden from list |
| `Config.ApplicationCooldown` | Cooldown (sec) per job per player |
| `Config.MaxMotivationLength` | Max characters in motivation |
| `Config.MinMotivationLength` | Minimum characters |
| `Config.AutoAssign` | true/false auto hire immediately |
| `Config.AutoAssignGrade` | Grade used when auto assign |

### Usage
* Type `/jobcenter` or use the target ped to open.
* Select a job in the left panel.
* Enter motivation and click APPLY.
* Close via CLOSE button or ESC.

### Notifications
All feedback uses `lib.notify`:
```lua
lib.notify(source, { title = 'Job Center', description = 'Application sent!', type = 'success' })
```

### Events & Callbacks
Client -> Server:
* `cg-jobcenter:apply` (jobName, motivation)

Server callback registered:
* `cg-jobcenter:getJobs` returns `{ { name=..., label=... }, ... }`

### Security / Validation
* Server checks: job existence, exclusion list, motivation length, cooldown.
* Client cannot force a non-existent job.

### Auto Assign
Enable in config if players should be hired instantly. If manual review is desired leave `AutoAssign = false` and review `job_applications` table.

### Potential Future Enhancements
* Admin panel to approve/deny applications
* Discord webhook on new application
* Whitelist flag per job

### Support
Adjust colors, fonts and ped model in `config.lua` and `ui/style.css` as needed.

Enjoy.