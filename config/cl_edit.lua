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
    if not Config.UseKeySystem then return end

    plate = plate and (string.strtrim and plate:strtrim(' ') or plate:match('^%s*(.-)%s*$')) or ''
    if plate == '' then return end

    vehicle = vehicle or GetVehiclePedIsIn(cache.ped, false)
    if not vehicle or vehicle == 0 then
        vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 10.0, true)
    end

    if vehicle and vehicle ~= 0 then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    end

    if GetResourceState('p_vehiclekeys') == 'started' then
        pcall(function()
            local alreadyHasKey = false
            if GetResourceState('ox_inventory') == 'started' then
                local count = exports.ox_inventory:Search('count', 'car_key', { plate = plate }) or 0
                if count and count > 0 then alreadyHasKey = true end
            end

            if not alreadyHasKey then
                if exports['p_vehiclekeys'] and exports['p_vehiclekeys'].createKey then
                    exports['p_vehiclekeys']:createKey(plate, vehicle)
                else
                    local netId = (vehicle and vehicle ~= 0 and NetworkGetEntityIsNetworked(vehicle)) and NetworkGetNetworkIdFromEntity(vehicle) or nil
                    if netId then
                        TriggerServerEvent('p_vehiclekeys/createKey', plate, netId)
                    end
                end
            end
        end)
    elseif Framework.name == 'es_extended' then
        if GetResourceState('wasabi_carlock') == 'started' then
            exports['wasabi_carlock']:GiveKey(plate)
        end
    elseif Framework.name == 'qb-core' then
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    end
end

function RemoveVehicleKey(plate)
    if not Config.UseKeySystem then return end

    plate = plate and (string.strtrim and plate:strtrim(' ') or plate:match('^%s*(.-)%s*$')) or ''
    if plate == '' then return end

    if GetResourceState('p_vehiclekeys') == 'started' then
        pcall(function()
            if exports['p_vehiclekeys'] and exports['p_vehiclekeys'].removeKey then
                exports['p_vehiclekeys']:removeKey(plate, nil, true)
            else
                TriggerServerEvent('p_vehiclekeys/removeKey', plate, true)
            end
        end)
    elseif Framework.name == 'es_extended' then
        if GetResourceState('wasabi_carlock') == 'started' then
            pcall(function()
                exports['wasabi_carlock']:RemoveKey(plate)
            end)
        end
    end
end