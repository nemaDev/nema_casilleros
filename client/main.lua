local QBCore = exports['qb-core']:GetCoreObject()
Config = {}
local OwnedLockerBlips = {}
local currentLocker, lockerName

Citizen.CreateThread(function() --add an onplayer loaded for blips and config fetch as well as this thread
    while QBCore == nil do
        TriggerEvent("QBCore:GetObject", function(obj) QBCore = obj end)
        Citizen.Wait(100) 
    end
    TriggerEvent('nema_casilleros:client:FetchConfig')
    TriggerEvent('nema_casilleros:client:setupBlips')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('nema_casilleros:client:FetchConfig')
    TriggerEvent('nema_casilleros:client:setupBlips')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    for k, v in pairs(OwnedLockerBlips) do
        RemoveBlip(v)
    end
end)

RegisterNetEvent('nema_casilleros:client:FetchConfig')
AddEventHandler('nema_casilleros:client:FetchConfig', function()
    QBCore.Functions.TriggerCallback("nema_casilleros:server:FetchConfig", function(lockers)
        Config.Lockers = lockers
    end)
end)

RegisterNetEvent('nema_casilleros:client:setupBlips')
AddEventHandler('nema_casilleros:client:setupBlips', function()
    for k, v in pairs(OwnedLockerBlips) do
        RemoveBlip(v)
    end
    QBCore.Functions.TriggerCallback('nema_casilleros:server:getOwnedLockers', function(ownedLockers)
        if ownedLockers ~= nil then
            for k, v in pairs(ownedLockers) do
                local locker = Config.Lockers[v]['coords']
                local lockerBlip = AddBlipForCoord(locker.x, locker.y, locker.z)
                SetBlipSprite (lockerBlip, 568)
                SetBlipDisplay(lockerBlip, 4)
                SetBlipScale  (lockerBlip, 0.65)
                SetBlipAsShortRange(lockerBlip, true)
                SetBlipColour(lockerBlip, 3)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentSubstringPlayerName("Casillero")
                EndTextCommandSetBlipName(lockerBlip)
                table.insert(OwnedLockerBlips, lockerBlip)
            end
        end
    end)
end)

Citizen.CreateThread(function() 
    while true do
        sleep = 1000
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            if Config.Lockers ~= nil then
                for k, v in pairs(Config.Lockers) do
                    local dist = #(pos - vector3(v["coords"].x, v["coords"].y, v["coords"].z))
                    if dist < 1.5 then
                        currentLocker = v
                        lockerName = k
                        sleep = 5
                        DrawText3D(v["coords"].x, v["coords"].y, v["coords"].z, "~g~E~w~ - Usar casillero")
                        if IsControlJustReleased(0, 38) then
                            TriggerEvent("nema_casilleros:client:interact", k, v)
                        end
                    end
                end
            end
    Wait(sleep)
    end
end)

RegisterNetEvent("nema_casilleros:client:interact")
AddEventHandler("nema_casilleros:client:interact", function(k, v)
    local lockername = k
    local lockertable = v
    local citizenid = QBCore.Functions.GetPlayerData().citizenid
    PlayerJob = QBCore.Functions.GetPlayerData().job
    TriggerEvent('nh-context:sendMenu', { --send the close button all the time
        {
            id = 0,
            header = "Casillero "..lockername,
            txt = "",
        },        
    }) 
    if not lockertable["isOwned"] then
        TriggerEvent('nh-context:sendMenu', { --if not owned send the purchase button to the menu
            {
                id = 2,
                header = "Comprar",
                txt = "Comprar casillero por $" .. v.price,
                params = {
                    event = "nema_casilleros:client:purchase",
                }
            },
        })
    elseif lockertable["isOwned"] then
        TriggerEvent('nh-context:sendMenu', { --if locker is owned send these buttons to the menu
            {
                id = 3,
                header = "Abrir casillero",
                txt = "",
                params = {
                    event = "nema_casilleros:client:openLocker",
                }
            },
        })
    end
    if lockertable["owner"] == citizenid then
        TriggerEvent('nh-context:sendMenu', { --send the close button all the time
            {
                id = 4,
                header = "Cambiar clave",
                txt = "",
                params = {
                    event = "nema_casilleros:client:changePasscode", 
                }
            },
            {
                id = 5,
                header = "Vender casillero",
                txt = "",
                params = {
                    event = "nema_casilleros:client:sellLocker",
                    args = {
                        lockername = lockername,
                        lockertable = lockertable
                    }
                }
            },
        }) 
    end
    if PlayerJob.name == "police" then
        TriggerEvent('nh-context:sendMenu', {
            {
                id = 6,
                header = "Casillero de incursión",
                txt = "",
                params = {
                    event = "nema_casilleros:client:raidLocker", 
                    args = {
                        lockername = lockername,
                        lockertable = lockertable
                    }
                }
            },
        })
    end
    TriggerEvent('nh-context:sendMenu', { --send the close button all the time
        {
            id = 9999,
            header = "Cerrar menu",
            txt = "",
            params = {
                event = "nh-context:closeMenu",
            }
        },   
    }) 
end)

RegisterNetEvent('nema_casilleros:client:sellLocker')
AddEventHandler('nema_casilleros:client:sellLocker', function(data)
    TriggerServerEvent('nema_casilleros:server:sellLocker', data.lockername, data.lockertable)
end)

RegisterNetEvent('nema_casilleros:client:changePasscode')
AddEventHandler('nema_casilleros:client:changePasscode', function()
    SendNUIMessage({
        type = "changePasscode",
        action = "openKeypad",
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('nema_casilleros:client:raidLocker')
AddEventHandler('nema_casilleros:client:raidLocker', function(data)
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(HasItem)
        if HasItem then
            --add progressbar/animation
            TriggerServerEvent("inventory:server:OpenInventory", "stash", data.lockername, {
                maxweight = currentLocker.capacity,
                slots = currentLocker.slots,
                })
            TriggerEvent("inventory:client:SetCurrentStash", data.lockername)  
        else
            QBCore.Functions.Notify("No tienes un rompe puertas encima..", "error")
        end
    end, 'police_stormram' )
end)

RegisterNetEvent('nema_casilleros:client:purchase') --trigger event after nh-context purchase button. Set password which then starts the buying process
AddEventHandler('nema_casilleros:client:purchase', function()
    --add the money check here instead
    QBCore.Functions.Notify("Por favor, establezca una contraseña.")
    SendNUIMessage({
        type = "create",
        action = "openKeypad",
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('nema_casilleros:client:openLocker') --trigger event after nh-context open locker button. Opens the password UI for the locker
AddEventHandler('nema_casilleros:client:openLocker', function()
    SendNUIMessage({
        type = "attempt",
        action = "openKeypad",
    })
    SetNuiFocus(true, true)
end)

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end 

RegisterNUICallback('PadLockClose', function()
    SetNuiFocus(false, false)
end)

RegisterNUICallback("CombinationSound", function(data, cb)
    PlaySound(-1, "Place_Prop_Fail", "DLC_Dmod_Prop_Editor_Sounds", 0, 0, 1)
end)

RegisterNUICallback('UseCombination', function(data, cb)
    if data.type == 'attempt' then
        QBCore.Functions.TriggerCallback('nema_casilleros:server:getData', function(combination)
            if tonumber(data.combination) ~= nil then
                if tonumber(data.combination) == tonumber(combination) then
                    SetNuiFocus(false, false)
                    SendNUIMessage({
                        action = "closeKeypad",
                        error = false,
                    })
                    TriggerServerEvent("inventory:server:OpenInventory", "stash", lockerName, {
                    maxweight = currentLocker.capacity,
                    slots = currentLocker.slots,
                    })
                    TriggerEvent("inventory:client:SetCurrentStash", lockerName)   
                    --takeAnim()
                else
                    QBCore.Functions.Notify("Contraseña incorrecta", 'error')
                    SetNuiFocus(false, false)
                    SendNUIMessage({
                        action = "closeKeypad",
                        error = true,
                    })
                end
            end        
        end, lockerName, 'password') 
    elseif data.type == 'create' then
        SendNUIMessage({
            action = "closeKeypad",
            error = false,
        })
        if data.combination ~= nil then
            QBCore.Functions.TriggerCallback('nema_casilleros:server:purchaselocker', function(bankmoney)
                if bankmoney >= currentLocker.price then
                    TriggerServerEvent("nema_casilleros:server:createPassword", data.combination, lockerName)
                    TriggerEvent('nema_casilleros:client:FetchConfig')
                    QBCore.Functions.Notify("Has comprado este casillero","success")
                end
            end, currentLocker, lockerName)
        end
    elseif data.type == 'changePasscode' then
        SendNUIMessage({
            action = "closeKeypad",
            error = false,
        })
        if data.combination ~= nil then
            TriggerServerEvent("nema_casilleros:server:changePasscode", data.combination, lockerName, currentLocker)
        end
    end
end)