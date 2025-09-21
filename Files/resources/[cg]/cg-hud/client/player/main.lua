local bool, ammoInClip = false, 0
local WeaponList = {}
function HUD:GetJobLabel()
    if not ESX.PlayerData.job then
        return
    end

    if ESX.PlayerData.job.name == "unemployed" then
        return ESX.PlayerData.job.label
    end

    local dutySuffix = ESX.PlayerData.job.onDuty and "" or Translate("job_off_duty")
    return string.format("%s - %s %s", ESX.PlayerData.job.label, ESX.PlayerData.job.grade_label, dutySuffix)
end
function HUD:GetLocation()
    local PPos = GetEntityCoords(ESX.PlayerData.ped)
    local streetHash = GetStreetNameAtCoord(PPos.x, PPos.y, PPos.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    return streetName
end

function HUD:UpdateAccounts(accounts)
    if Config.Disable.Money then return end

    -- Prefer provided accounts; fallback to ESX.GetPlayerData()
    local p = ESX.GetPlayerData() or {}
    local accs = accounts or p.accounts or {}

    -- Reset if missing so we don't keep stale zeros when real values exist
    local bank, cash

    -- Read from accounts array/table if present (supports both array and keyed forms)
    if accs then
        for _, data in pairs(accs) do
            if data and data.name == "bank" then
                bank = tonumber(data.money) or bank
            elseif data and (data.name == "money" or data.name == "cash") then
                cash = tonumber(data.money) or cash
            end
        end
        -- Keyed form: accounts.bank.money, accounts.money.money
        if type(accs) == "table" then
            if accs.bank and accs.bank.money ~= nil then
                bank = tonumber(accs.bank.money) or bank
            end
            if accs.money and accs.money.money ~= nil then
                cash = tonumber(accs.money.money) or cash
            end
            if accs.cash and accs.cash.money ~= nil then
                cash = tonumber(accs.cash.money) or cash
            end
        end
    end

    -- Fallback: some ESX builds keep cash on top-level `money`
    if cash == nil and type(p.money) ~= "nil" then
        cash = tonumber(p.money) or cash
    end

    -- Write into HUD store
    if bank ~= nil then self.Data.Money.bank = bank end
    if cash ~= nil then self.Data.Money.cash = cash end

    -- Emit to UI whenever accounts are updated
    SendNUIMessage({
        type = "HUD_DATA",
        value = { moneys = { bank = self.Data.Money.bank or 0, money = self.Data.Money.cash or 0 } }
    })
end

function HUD:GetWeapons()
    WeaponList = ESX.GetWeaponList(true)
end

function HUD:SlowThick()
    CreateThread(function()
        while not ESX.PlayerLoaded do
            Wait(200)
        end
        while ESX.PlayerLoaded do
            self.Data.Position = GetEntityCoords(ESX.PlayerData.ped)

            if not Config.Disable.Position then
                self.Data.Location = self:GetLocation()
            end

            if not Config.Disable.Weapon then
                self.Data.Weapon.Active, self.Data.Weapon.CurrentWeapon = GetCurrentPedWeapon(ESX.PlayerData.ped, false)
                if self.Data.Weapon.CurrentWeapon == 0 then
                    self.Data.Weapon.Active = false
                end
                if self.Data.Weapon.Active and WeaponList[self.Data.Weapon.CurrentWeapon] then
                    self.Data.Weapon.MaxAmmo = (GetAmmoInPedWeapon(ESX.PlayerData.ped, self.Data.Weapon.CurrentWeapon) - ammoInClip)
                    self.Data.Weapon.Name = WeaponList[self.Data.Weapon.CurrentWeapon].label and WeaponList[self.Data.Weapon.CurrentWeapon].label or false
                    self.Data.Weapon.isWeaponMelee = not WeaponList[self.Data.Weapon.CurrentWeapon].ammo
                    self.Data.Weapon.Image = string.gsub(WeaponList[self.Data.Weapon.CurrentWeapon].name, "WEAPON_", "")
                    self.Data.Weapon.Image = string.lower(self.Data.Weapon.Image)
                end

                --here we handle it when we find a hash that is not in the weapon list so we don't show the weapon data on the hud
                if self.Data.Weapon.Active then
                    self.Data.Weapon.Active = self.Data.Weapon.CurrentWeapon ~= 0 and self.Data.Weapon.Name and self.Data.Weapon.Image
                end
            end

            Wait(1000)
        end
    end)
end

function HUD:FastThick()
    CreateThread(function()
        while not ESX.PlayerLoaded do
            Wait(200)
        end

    local srvLogo = Config.Default.ServerLogo
        while ESX.PlayerLoaded do
            if not Config.Disable.Voice then
                self.Data.isTalking = NetworkIsPlayerTalking(ESX.playerId)
            end

            if self.Data.Weapon.Active then
                bool, ammoInClip = GetAmmoInClip(ESX.PlayerData.ped, self.Data.Weapon.CurrentWeapon)
                self.Data.Weapon.CurrentAmmo = ammoInClip
            end

            local values = {
                playerId = ESX.serverId,
                onlinePlayers = GlobalState["playerCount"],
                serverLogo = srvLogo,
                moneys = { bank = self.Data.Money.bank or 0, money = self.Data.Money.cash or 0 },
                weaponData = {
                    use = self.Data.Weapon.Active,
                    image = self.Data.Weapon.Image or false,
                    name = self.Data.Weapon.Name or false,
                    isWeaponMelee = self.Data.Weapon.isWeaponMelee,
                    currentAmmo = self.Data.Weapon.CurrentAmmo or 0,
                    maxAmmo = self.Data.Weapon.MaxAmmo or 0,
                },
                streetName = self.Data.Location or "Unknown street",
                voice = {
                    mic = self.Data.isTalking or false,
                    radio = self.Data.isTalkingOnRadio,
                    range = self.Data.VoiceRange,
                },
                job = HUD:GetJobLabel() or "",
            }

            SendNUIMessage({ type = "HUD_DATA", value = values })
            Wait(500)
        end
    end)
end

-- Handlers
-- On script start
AddEventHandler("onResourceStart", function(resource)
    if GetCurrentResourceName() ~= resource then
        return
    end
    Wait(1000)
    if not Config.Disable.Weapon then
        HUD:GetWeapons()
    end
end)

-- On player loaded
ESX.SecureNetEvent("esx:playerLoaded", function(xPlayer)
    if not Config.Disable.Weapon then
        HUD:GetWeapons()
    end
    HUD:GetJobLabel()
    if not Config.Disable.Money then
        HUD:UpdateAccounts(xPlayer.accounts)
        SendNUIMessage({
            type = "HUD_DATA",
            value = { moneys = { bank = HUD.Data.Money.bank or 0, money = HUD.Data.Money.cash or 0 } }
        })
    end
end)

AddEventHandler("esx:pauseMenuActive", function(state)
    if HUD.Data.hudHidden then
        return
    end
    HUD:Toggle(not state)
end)

-- job handler
RegisterNetEvent("esx:setJob")
AddEventHandler("esx:setJob", function(job)
    ESX.PlayerData.job = job
end)

--Cash and Bank handler
if not Config.Disable.Money then
    RegisterNetEvent("esx:setAccountMoney", function(account)
        if account.name == "money" then
            HUD.Data.Money.cash = account.money
        elseif account.name == "bank" then
            HUD.Data.Money.bank = account.money
        end
        -- Immediately push HUD_DATA update for money to refresh TopRight
        local b = HUD.Data.Money.bank or 0
        local c = HUD.Data.Money.cash or 0
        SendNUIMessage({
            type = "HUD_DATA",
            value = { moneys = { bank = b, money = c } }
        })
    end)
end

-- Timed retry: some frameworks populate accounts slightly later
CreateThread(function()
    while not ESX.PlayerLoaded do Wait(200) end
    Wait(3000)
    if (HUD.Data.Money.bank or 0) == 0 and (HUD.Data.Money.cash or 0) == 0 then
        ESX.TriggerServerCallback('esx_hud:getAccounts', function(acc)
            if acc then
                HUD.Data.Money.bank = acc.bank or HUD.Data.Money.bank or 0
                HUD.Data.Money.cash = acc.money or HUD.Data.Money.cash or 0
                SendNUIMessage({ type = 'HUD_DATA', value = { moneys = { bank = HUD.Data.Money.bank or 0, money = HUD.Data.Money.cash or 0 } } })
            end
        end)
    end
end)

-- Manual command to re-fetch and print money
RegisterCommand('hudmoney', function()
    ESX.TriggerServerCallback('esx_hud:getAccounts', function(acc)
        if acc then
            HUD.Data.Money.bank = acc.bank or 0
            HUD.Data.Money.cash = acc.money or 0
            SendNUIMessage({ type = 'HUD_DATA', value = { moneys = { bank = HUD.Data.Money.bank, money = HUD.Data.Money.cash } } })
        else
        end
    end)
end, false)
