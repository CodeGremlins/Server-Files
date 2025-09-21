local ESX

CreateThread(function()
    while ESX == nil do
        ESX = exports['es_extended']:getSharedObject()
        if ESX == nil then
            Wait(100)
        end
    end
end)

local cooldowns = {}

-- Fetch jobs (reads from ESX or database). We'll read from SQL jobs table to include labels.
lib.callback.register('cg-jobcenter:getJobs', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local jobs = {}
    local result = MySQL.query.await('SELECT name, label FROM jobs ORDER BY label ASC')
    if result then
        for _, row in ipairs(result) do
            if not Config.ExcludedJobs[row.name] then
                jobs[#jobs+1] = {
                    name = row.name,
                    label = row.label
                }
            end
        end
    end
    return jobs
end)

RegisterNetEvent('cg-jobcenter:apply', function(jobName, motivation)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if type(jobName) ~= 'string' or #jobName < 2 then
        lib.notify(src, {title='Job Center', description='Invalid job.', type='error'})
        return
    end

    motivation = tostring(motivation or '')
    if #motivation < Config.MinMotivationLength or #motivation > Config.MaxMotivationLength then
        lib.notify(src, {title='Job Center', description='Application length invalid.', type='error'})
        return
    end

    if Config.ExcludedJobs[jobName] then
        lib.notify(src, {title='Job Center', description='Job not available.', type='error'})
        return
    end

    -- Check job exists
    local exists = MySQL.scalar.await('SELECT 1 FROM jobs WHERE name = ? LIMIT 1', { jobName })
    if not exists then
        lib.notify(src, {title='Job Center', description='Job does not exist.', type='error'})
        return
    end

    local identifier = xPlayer.getIdentifier()
    local key = identifier .. ':' .. jobName
    local now = os.time()
    local cd = cooldowns[key]
    if cd and now < cd then
        local remaining = cd - now
        lib.notify(src, {title='Job Center', description='Wait '..remaining..'s before applying again.', type='error'})
        return
    end

    cooldowns[key] = now + Config.ApplicationCooldown

    -- Insert application
    MySQL.insert.await('INSERT INTO job_applications (identifier, job, motivation, created_at) VALUES (?, ?, ?, NOW())', {
        identifier,
        jobName,
        motivation
    })

    if Config.AutoAssign then
        xPlayer.setJob(jobName, Config.AutoAssignGrade or 0)
        lib.notify(src, {title='Job Center', description='You have been hired as '..jobName..'.', type='success'})
    else
        lib.notify(src, {title='Job Center', description='Application sent!', type='success'})
    end
end)
