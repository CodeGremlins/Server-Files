Config = {}

-- Command to open the Jobcenter UI
Config.Command = 'jobcenter'

-- Enable ox_target interaction (set false if you only want the command)
Config.UseTarget = true

-- Target model (e.g., a ped) or zone location for the job center
Config.PedModel = 'cs_bankman'
Config.Location = vector3(-268.97, -955.43, 31.22)
Config.Heading = 205.0
Config.TargetDistance = 2.0

-- Jobs that should not appear (admin, police if whitelist, etc.)
Config.ExcludedJobs = {
    ['unemployed'] = true
}

-- Cooldown between applications per job (seconds)
Config.ApplicationCooldown = 300

-- Maximum length for application motivation text
Config.MaxMotivationLength = 500

-- Minimum length for motivation
Config.MinMotivationLength = 5

-- Whether to auto-assign the job upon application or just store application
Config.AutoAssign = true

-- If AutoAssign = true, set grade to assign
Config.AutoAssignGrade = 0
