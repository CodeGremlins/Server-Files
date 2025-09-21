---@diagnostic disable: undefined-global
if not Config.Disable.Status then
    local GetPlayerUnderwaterTimeRemaining = GetPlayerUnderwaterTimeRemaining
    local GetPlayerSprintStaminaRemaining = GetPlayerSprintStaminaRemaining
    local IsPedSwimmingUnderWater = IsPedSwimmingUnderWater
    local GetEntityHealth = GetEntityHealth
    local GetEntityMaxHealth = GetEntityMaxHealth
    local GetPedArmour = GetPedArmour
    local PlayerId = PlayerId
    local PlayerPedId = PlayerPedId
    local IsPedRunning = IsPedRunning
    local IsPedSprinting = IsPedSprinting
    local values = {}

    -- Removed esx_status:onTick dependency; we poll hunger/thirst directly in the status thread.

    function HUD:StatusThread()
        values = {}
        CreateThread(function()
            local staminaVal = 100.0
            local poll = 0
            -- Wait until player is fully loaded to avoid exiting the loop prematurely
            while not ESX.PlayerLoaded do
                Wait(200)
            end
            while ESX.PlayerLoaded do
                local oxygen, stamina = 0, 0
                local playerId = PlayerId()
                local ped = PlayerPedId()

                -- Stamina: Some servers have effectively infinite stamina. Simulate drain/refill for visual feedback.
                local running = IsPedRunning(ped) or IsPedSprinting(ped)
                if running then
                    staminaVal = staminaVal - 1.5
                else
                    staminaVal = staminaVal + 1.0
                end
                if staminaVal < 0.0 then staminaVal = 0.0 end
                if staminaVal > 100.0 then staminaVal = 100.0 end
                stamina = math.floor(staminaVal)

                -- Oxygen: normalize underwater time to percent (assume ~20s default capacity)
                if IsPedSwimmingUnderWater(ped) then
                    local remaining = GetPlayerUnderwaterTimeRemaining(playerId) or 0.0
                    oxygen = math.floor(math.min(100, math.max(0, remaining * 5))) -- 20s => 100%
                end

                -- Health/Armor: update continuously for responsive UI
                local maxHealth = GetEntityMaxHealth(ped)
                local currentHealth = GetEntityHealth(ped)
                -- In GTA V, base is 100; compute percent relative to (max - 100)
                local denom = (maxHealth - 100)
                if denom <= 0 then denom = 100 end
                local hpPct = math.floor(((currentHealth - 100) / denom) * 100)
                if hpPct < 0 then hpPct = 0 end
                if hpPct > 100 then hpPct = 100 end

                values.healthBar = hpPct
                values.armorBar = GetPedArmour(ped)
                if values.armorBar < 0 then values.armorBar = 0 end
                if values.armorBar > 100 then values.armorBar = 100 end

                -- Periodically poll esx_status for hunger/thirst if needed
                poll = poll + 1
                if poll >= 4 then -- roughly every second
                    poll = 0
                    TriggerEvent('esx_status:getStatus', 'hunger', function(status)
                        if status then
                            if status.getPercent then
                                values.foodBar = math.floor(status:getPercent())
                            elseif status.val then
                                values.foodBar = math.floor((status.val or 0) / 10000)
                            end
                        end
                    end)
                    TriggerEvent('esx_status:getStatus', 'thirst', function(status)
                        if status then
                            if status.getPercent then
                                values.drinkBar = math.floor(status:getPercent())
                            elseif status.val then
                                values.drinkBar = math.floor((status.val or 0) / 10000)
                            end
                        end
                    end)
                end
                -- Directly poll hunger/thirst from esx_status each cycle (no event dependency)
                local hPct, tPct
                TriggerEvent('esx_status:getStatus', 'hunger', function(status)
                    if status then
                        if status.getPercent then
                            hPct = math.floor(status:getPercent())
                        elseif status.val then
                            hPct = math.floor((status.val or 0) / 10000)
                        end
                    end
                end)
                TriggerEvent('esx_status:getStatus', 'thirst', function(status)
                    if status then
                        if status.getPercent then
                            tPct = math.floor(status:getPercent())
                        elseif status.val then
                            tPct = math.floor((status.val or 0) / 10000)
                        end
                    end
                end)

                if hPct ~= nil then values.foodBar = hPct end
                if tPct ~= nil then values.drinkBar = tPct end
                if values.foodBar == nil then values.foodBar = 0 end
                if values.drinkBar == nil then values.drinkBar = 0 end

                values.oxygenBar = oxygen or 0
                values.staminaBar = stamina
                SendNUIMessage({ type = "STATUS_HUD", value = values })
                Wait(500)
            end
        end)
    end
end
