function ShowNotification(message, notifyType)
    lib.notify({
        description = message,
        type = notifyType,
        position = 'top-right'
    })
end

RegisterNetEvent('lunar_garage:showNotification')
AddEventHandler('lunar_garage:showNotification', ShowNotification)

function ShowUI(text, icon)
    if icon == 0 then
        lib.showTextUI(text)
    else
        lib.showTextUI(text, {
            icon = icon
        })
    end
end

function HideUI()
    lib.hideTextUI()
end

function GetVehicleFuel(vehicle)
    if GetResourceState('ox_fuel') == 'started' then
        return Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)
    elseif GetResourceState('LegacyFuel') == 'started' then
        local fuelLevel = exports['LegacyFuel']:GetFuel(vehicle)
        return math.floor(fuelLevel * 100) / 100
    else
        return GetVehicleFuelLevel(vehicle)
    end
end

function SetVehicleFuel(vehicle, fuelLevel)
    fuelLevel = fuelLevel or 100.0
    if GetResourceState('ox_fuel') == 'started' then
        Entity(vehicle).state:set('fuel', fuelLevel, true)
        SetVehicleFuelLevel(vehicle, fuelLevel + 0.0)
    elseif GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, fuelLevel)
    else
        SetVehicleFuelLevel(vehicle, fuelLevel + 0.0)
    end
end

function SetVehicleOwner(plate, vehicle)
    if not Config.UseKeySystem then
        if Config.Debug then
            print('^3[lunar_garage:DEBUG:CLIENT]^7 SetVehicleOwner skipped: Config.UseKeySystem is false')
        end
        return
    end

    plate = plate and (string.strtrim and plate:strtrim(' ') or plate:match('^%s*(.-)%s*$')) or ''
    if plate == '' then
        if Config.Debug then
            print('^1[lunar_garage:DEBUG:CLIENT]^7 SetVehicleOwner failed: plate is empty')
        end
        return
    end

    vehicle = vehicle or GetVehiclePedIsIn(cache.ped, false)
    if not vehicle or vehicle == 0 then
        vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 10.0, true)
    end

    local isNetworked = vehicle and vehicle ~= 0 and NetworkGetEntityIsNetworked(vehicle) or false
    local netId = isNetworked and NetworkGetNetworkIdFromEntity(vehicle) or nil

    if Config.Debug then
        print(string.format('^3[lunar_garage:DEBUG:CLIENT]^7 SetVehicleOwner -> plate: "%s", vehicleHandle: %s, networked: %s, netId: %s',
            tostring(plate), tostring(vehicle), tostring(isNetworked), tostring(netId)
        ))
    end

    if vehicle and vehicle ~= 0 then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        if Config.Debug then
            print(string.format('^2[lunar_garage:DEBUG:CLIENT]^7 Vehicle unlocked and ownership confirmed for handle %s', tostring(vehicle)))
        end
    end

    if GetResourceState('p_vehiclekeys') == 'started' then
        if Config.Debug then
            print('^2[lunar_garage:DEBUG:CLIENT]^7 p_vehiclekeys active: vehicle key item is managed authoritatively by server on spawn')
        end
    elseif Framework.name == 'es_extended' then
        if GetResourceState('wasabi_carlock') == 'started' then
            if Config.Debug then
                print(string.format('^2[lunar_garage:DEBUG:CLIENT]^7 Calling wasabi_carlock:GiveKey for plate: "%s"', plate))
            end
            exports['wasabi_carlock']:GiveKey(plate)
        end
    elseif Framework.name == 'qb-core' then
        if Config.Debug then
            print(string.format('^2[lunar_garage:DEBUG:CLIENT]^7 Triggering vehiclekeys:client:SetOwner for plate: "%s"', plate))
        end
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    end
end

function RemoveVehicleKey(plate)
    if not Config.UseKeySystem then
        if Config.Debug then
            print('^3[lunar_garage:DEBUG:CLIENT]^7 RemoveVehicleKey skipped: Config.UseKeySystem is false')
        end
        return
    end

    plate = plate and (string.strtrim and plate:strtrim(' ') or plate:match('^%s*(.-)%s*$')) or ''
    if plate == '' then return end

    if Config.Debug then
        print(string.format('^3[lunar_garage:DEBUG:CLIENT]^7 RemoveVehicleKey -> plate: "%s"', tostring(plate)))
    end

    if GetResourceState('p_vehiclekeys') == 'started' then
        if Config.Debug then
            print('^2[lunar_garage:DEBUG:CLIENT]^7 p_vehiclekeys active: vehicle key removal is managed authoritatively by server on saveVehicle')
        end
    elseif Framework.name == 'es_extended' then
        if GetResourceState('wasabi_carlock') == 'started' then
            pcall(function()
                if Config.Debug then
                    print(string.format('^2[lunar_garage:DEBUG:CLIENT]^7 Calling wasabi_carlock:RemoveKey for plate: "%s"', plate))
                end
                exports['wasabi_carlock']:RemoveKey(plate)
            end)
        end
    end
end