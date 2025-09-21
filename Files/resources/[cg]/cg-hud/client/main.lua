function HUD:Toggle(state)
    SendNUIMessage({ type = "SHOW", value = state })
end

function HUD:SetHudColor()
    SendNUIMessage({ type = "SET_CONFIG_DATA", value = Config })
end

function HUD:Start(xPlayer)
    while not ESX.PlayerLoaded do
        Wait(0)
    end

    if not xPlayer then
        xPlayer = ESX.GetPlayerData()
    end

    self:SetHudColor()

    -- Initialize money before starting threads so first HUD_DATA uses real values
    if not Config.Disable.Money then
        self:UpdateAccounts(xPlayer.accounts)
        if (self.Data.Money.bank or 0) == 0 and (self.Data.Money.cash or 0) == 0 then
            -- Pull from server if still zero (covers keyed accounts / ox_inventory variants)
            ESX.TriggerServerCallback('esx_hud:getAccounts', function(acc)
                if acc then
                    self.Data.Money.bank = acc.bank or self.Data.Money.bank or 0
                    self.Data.Money.cash = acc.money or self.Data.Money.cash or 0
                end
                SendNUIMessage({ type = "HUD_DATA", value = { moneys = { bank = self.Data.Money.bank or 0, money = self.Data.Money.cash or 0 } } })
            end)
        else
            SendNUIMessage({ type = "HUD_DATA", value = { moneys = { bank = self.Data.Money.bank or 0, money = self.Data.Money.cash or 0 } } })
        end
    end

    self:SlowThick()
    self:FastThick()

    if not Config.Disable.Status then
        self:StatusThread()
    end

    if Config.Disable.MinimapOnFoot then
        DisplayRadar(false)
    end

    self:Toggle(true)
end

local function ToggleHud(state)
    HUD:Toggle(state)
    HUD.Data.hudHidden = not state
end

RegisterNetEvent("esx_hud:HudToggle", ToggleHud)
exports("HudToggle", ToggleHud)

-- Handlers
-- On script start
AddEventHandler("onResourceStart", function(resource)
    if GetCurrentResourceName() ~= resource then
        return
    end
    Wait(1000)
    HUD:Start()
end)

-- On player loaded
ESX.SecureNetEvent("esx:playerLoaded", function(xPlayer)
    while IsScreenFadedOut() do
        Wait(200)
    end

    HUD:Start(xPlayer)
end)

-- ForceLog or Logout
ESX.SecureNetEvent("esx:onPlayerLogout", function()
    Wait(1000)
    HUD:Toggle(false)
end)
