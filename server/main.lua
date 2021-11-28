Config = {}
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback("nema_casilleros:server:FetchConfig", function(source, cb)
    Config.Lockers = json.decode(LoadResourceFile(GetCurrentResourceName(), "lockers.json"))
    cb(Config.Lockers)
end)

QBCore.Functions.CreateCallback("nema_casilleros:server:purchaselocker", function(source, cb, v, k)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local CitizenID = Player.PlayerData.citizenid
    local price = v.price
    local bankMoney = Player.PlayerData.money["bank"]
    if bankMoney >= price then
        Player.Functions.RemoveMoney('bank', price, "Locker Purchased")
        Config.Lockers = json.decode(LoadResourceFile(GetCurrentResourceName(), "lockers.json"))
        Config.Lockers[k]['isOwned'] = true
        Config.Lockers[k]['owner'] = CitizenID 
        SaveResourceFile(GetCurrentResourceName(), "./lockers.json", json.encode(Config.Lockers), -1)
        TriggerClientEvent('nema_casilleros:client:FetchConfig', -1)
        TriggerClientEvent('nema_casilleros:client:setupBlips', src)
        cb(bankMoney)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No tienes suficiente dinero..', 'error')
        cb(bankMoney)
    end
end)

QBCore.Functions.CreateCallback("nema_casilleros:server:getData", function(source, cb, locker, data)  --make this a fetch event for everything and then pass through what you wanna fetch
    Config.Lockers = json.decode(LoadResourceFile(GetCurrentResourceName(), "lockers.json"))
    cb(Config.Lockers[locker][data])
end)

QBCore.Functions.CreateCallback('nema_casilleros:server:getOwnedLockers', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local ownedLockers = {}
    if Player then
        Config.Lockers = json.decode(LoadResourceFile(GetCurrentResourceName(), "lockers.json"))
        for k, v in pairs(Config.Lockers) do 
            if Player.PlayerData.citizenid == v["owner"] then
                table.insert(ownedLockers, k)
            end
        end
        if ownedLockers then
            cb(ownedLockers)
        else
            cb(false)
        end
    end
end)

RegisterNetEvent('nema_casilleros:server:changePasscode')
AddEventHandler('nema_casilleros:server:changePasscode', function(newPasscode, lockername, lockertable)
    local src = source
    Config.Lockers = json.decode(LoadResourceFile(GetCurrentResourceName(), "lockers.json"))
    Config.Lockers[lockername]['password'] = newPasscode
    SaveResourceFile(GetCurrentResourceName(), "./lockers.json", json.encode(Config.Lockers), -1)
    TriggerClientEvent('nema_casilleros:client:FetchConfig', -1)
    TriggerClientEvent('QBCore:Notify', src, 'Código de acceso cambiado', 'success')
end)

RegisterNetEvent('nema_casilleros:server:sellLocker')
AddEventHandler('nema_casilleros:server:sellLocker', function(lockername, lockertable)
    --add extra checks to make sure they own the locker
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = lockertable.price
    local saleprice = price - ((tonumber(price)/100) * 10)
    Config.Lockers[lockername]['isOwned'] = false
    Config.Lockers[lockername]['owner'] = '' --will this work?
    Player.Functions.AddMoney('bank', saleprice, "Locker Sold")
    SaveResourceFile(GetCurrentResourceName(), "./lockers.json", json.encode(Config.Lockers), -1)
    TriggerClientEvent('QBCore:Notify', src, 'Casillero vendido por ' .. saleprice, 'success')
    TriggerClientEvent('nema_casilleros:client:setupBlips', src)
    TriggerClientEvent('nema_casilleros:client:FetchConfig', -1)
end)

RegisterNetEvent('nema_casilleros:server:createPassword')
AddEventHandler('nema_casilleros:server:createPassword', function(password, locker)
    Config.Lockers = json.decode(LoadResourceFile(GetCurrentResourceName(), "lockers.json"))
    Config.Lockers[locker]['password'] = password
    SaveResourceFile(GetCurrentResourceName(), "./lockers.json", json.encode(Config.Lockers), -1)
    TriggerClientEvent('nema_casilleros:client:FetchConfig', -1)
end)

QBCore.Commands.Add("casillero", "Crea un casillero en tu ubicación actual", {{name = "nombre", help = "Nombre casillero"}, {name = "precio", help = "Precio del casillero"}, {name = "slots", help = "Slots - sugerido 30"}, {name = "capactiy", help = "Capacidad - suggested 5,000,000"} }, true, function(source, args)
    local coords = GetEntityCoords(GetPlayerPed(source))
    name = args[1]
    price = args[2]
    slots = args[3]
    capacity = args[4]
    newlocker = {
        ["capacity"] = {},
        ["price"] = {},
        ["slots"] = {},
        ["coords"] = {}
    }
    newlocker["price"] = tonumber(price)
    newlocker["capacity"] = tonumber(capacity)
    newlocker["slots"] = tonumber(slots)
    newlocker["coords"] = {x = coords.x, y = coords.y, z = coords.z}
    local currentConfig = json.decode(LoadResourceFile(GetCurrentResourceName(), "lockers.json"))
    currentConfig[name] = newlocker
    SaveResourceFile(GetCurrentResourceName(), "lockers.json", json.encode(currentConfig), -1)
    TriggerClientEvent('nema_casilleros:client:FetchConfig', -1)
end, "god")