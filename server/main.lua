-- Used to store vehicles that have been taken out
---@type table<string, number>
local activeVehicles = {}

CreateThread(function()
    Wait(1500)
    pcall(function()
        local cols = MySQL.query.await([[
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles'
        ]])
        local existing = {}
        if cols then
            for _, c in ipairs(cols) do
                local col = c.COLUMN_NAME or c.column_name
                if col then existing[col:lower()] = true end
            end
        end
        if not existing['is_favorite'] and not existing['favorite'] then
            MySQL.query.await("ALTER TABLE `owned_vehicles` ADD COLUMN `is_favorite` TINYINT(1) NOT NULL DEFAULT 0")
        end
        if not existing['custom_name'] and not existing['nickname'] then
            MySQL.query.await("ALTER TABLE `owned_vehicles` ADD COLUMN `custom_name` VARCHAR(50) DEFAULT NULL")
        end
        if not existing['impound_data'] then
            MySQL.query.await("ALTER TABLE `owned_vehicles` ADD COLUMN `impound_data` LONGTEXT DEFAULT NULL")
        end
    end)
end)

local function resolveVehicleState(vehicle)
    if vehicle.pound or vehicle.impound_data then
        return 'in_impound'
    elseif vehicle.stored == 1 or vehicle.stored == true then
        return 'in_garage'
    else
        local entity = activeVehicles[vehicle.plate]
        -- If entity not found in activeVehicles cache, check if it's anywhere in server world
        if not entity or not DoesEntityExist(entity) then
            for _, veh in ipairs(GetAllVehicles()) do
                local vehPlate = GetVehicleNumberPlateText(veh)
                if vehPlate and vehPlate:match('^%s*(.-)%s*$') == vehicle.plate then
                    entity = veh
                    activeVehicles[vehicle.plate] = veh
                    break
                end
            end
        end

        if entity and DoesEntityExist(entity) then
            if GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                DeleteEntity(entity)
                activeVehicles[vehicle.plate] = nil
                return 'in_impound'
            else
                return 'out_garage'
            end
        else
            activeVehicles[vehicle.plate] = nil
            return 'in_impound'
        end
    end
end

local function giveVehicleKey(source, plate, netId)
    if not Config.UseKeySystem then
        if Config.Debug then
            print('^3[lunar_garage:DEBUG:SERVER]^7 giveVehicleKey skipped: Config.UseKeySystem is false')
        end
        return
    end

    local trimmedPlate = plate and (string.strtrim and plate:strtrim(' ') or plate:match('^%s*(.-)%s*$')) or ''
    if trimmedPlate == '' then
        if Config.Debug then
            print('^1[lunar_garage:DEBUG:SERVER]^7 giveVehicleKey failed: plate is empty')
        end
        return
    end

    if Config.Debug then
        print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 giveVehicleKey called -> source: %s, plate: "%s", netId: %s',
            tostring(source), trimmedPlate, tostring(netId)
        ))
    end

    pcall(function()
        if GetResourceState('p_vehiclekeys') == 'started' then
            if GetResourceState('ox_inventory') == 'started' then
                local count = exports.ox_inventory:Search(source, 'count', 'car_key', { plate = trimmedPlate }) or 0
                if Config.Debug then
                    print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 ox_inventory check: player %s currently has %s car_key(s) for plate "%s"',
                        tostring(source), tostring(count), trimmedPlate
                    ))
                end

                if count and count > 0 then
                    if Config.Debug then
                        print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 Player %s already holds %s car_key for plate "%s", skipping to prevent duplicate keys',
                            tostring(source), count, trimmedPlate
                        ))
                    end
                    return
                end

                local success, response = exports.ox_inventory:AddItem(source, 'car_key', 1, { plate = trimmedPlate })
                if Config.Debug then
                    print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 ox_inventory:AddItem("car_key", 1, { plate = "%s" }) to player %s -> success: %s, response: %s',
                        trimmedPlate, tostring(source), tostring(success), tostring(response)
                    ))
                end
            else
                if Config.Debug then
                    print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 ox_inventory not running, triggering p_vehiclekeys/compat/addKey for player %s, plate "%s"',
                        tostring(source), trimmedPlate
                    ))
                end
                TriggerClientEvent('p_vehiclekeys/compat/addKey', source, trimmedPlate)
            end
        elseif GetResourceState('wasabi_carlock') == 'started' then
            if Config.Debug then
                print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 Calling wasabi_carlock:GiveKey(%s, "%s")', tostring(source), trimmedPlate))
            end
            exports['wasabi_carlock']:GiveKey(source, trimmedPlate)
        elseif GetResourceState('Renewed-Vehiclekeys') == 'started' then
            if Config.Debug then
                print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 Calling Renewed-Vehiclekeys:addKey(%s, "%s")', tostring(source), trimmedPlate))
            end
            exports['Renewed-Vehiclekeys']:addKey(source, trimmedPlate)
        elseif GetResourceState('qb-vehiclekeys') == 'started' then
            if Config.Debug then
                print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 Calling qb-vehiclekeys:GiveKeys(%s, "%s")', tostring(source), trimmedPlate))
            end
            exports['qb-vehiclekeys']:GiveKeys(source, trimmedPlate)
        else
            if Config.Debug then
                print('^3[lunar_garage:DEBUG:SERVER]^7 No supported vehicle key resource detected')
            end
        end
    end)
end

local function removeVehicleKey(source, plate)
    if not Config.UseKeySystem then
        if Config.Debug then
            print('^3[lunar_garage:DEBUG:SERVER]^7 removeVehicleKey skipped: Config.UseKeySystem is false')
        end
        return
    end

    local trimmedPlate = plate and (string.strtrim and plate:strtrim(' ') or plate:match('^%s*(.-)%s*$')) or ''
    if trimmedPlate == '' then return end

    if Config.Debug then
        print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 removeVehicleKey called -> source: %s, plate: "%s"',
            tostring(source), trimmedPlate
        ))
    end

    pcall(function()
        if GetResourceState('p_vehiclekeys') == 'started' then
            if GetResourceState('ox_inventory') == 'started' then
                local count = exports.ox_inventory:Search(source, 'count', 'car_key', { plate = trimmedPlate }) or 0
                if Config.Debug then
                    print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 ox_inventory: found %s car_key(s) for plate "%s" on player %s',
                        tostring(count), trimmedPlate, tostring(source)
                    ))
                end

                if count and count > 0 then
                    local removed = exports.ox_inventory:RemoveItem(source, 'car_key', count, { plate = trimmedPlate })
                    if Config.Debug then
                        print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 ox_inventory:RemoveItem removed %s car_key(s) for plate "%s": result=%s',
                            count, trimmedPlate, tostring(removed)
                        ))
                    end
                end
            else
                TriggerClientEvent('p_vehiclekeys/client/removeKey', source, trimmedPlate)
            end
        elseif GetResourceState('wasabi_carlock') == 'started' then
            if Config.Debug then
                print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 wasabi_carlock:RemoveKey(%s, "%s")', tostring(source), trimmedPlate))
            end
            exports['wasabi_carlock']:RemoveKey(source, trimmedPlate)
        elseif GetResourceState('Renewed-Vehiclekeys') == 'started' then
            if Config.Debug then
                print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 Renewed-Vehiclekeys:removeKey(%s, "%s")', tostring(source), trimmedPlate))
            end
            exports['Renewed-Vehiclekeys']:removeKey(source, trimmedPlate)
        elseif GetResourceState('qb-vehiclekeys') == 'started' then
            if Config.Debug then
                print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 qb-vehiclekeys:RemoveKeys(%s, "%s")', tostring(source), trimmedPlate))
            end
            exports['qb-vehiclekeys']:RemoveKeys(source, trimmedPlate)
        end
    end)
end

lib.callback.register('lunar_garage:getOwnedVehicles', function(source, index, society)
    local player = Framework.getPlayerFromId(source)
    if not player then return {} end
    
    local garage = Config.Garages[index]
    local query = society and Queries.getGarageSociety or Queries.getGarage
    local param1 = society and player:getJob() or player:getIdentifier()
    local vehicles = MySQL.query.await(query, { param1, garage.Type }) or {}

    for _, vehicle in ipairs(vehicles) do
        vehicle.state = resolveVehicleState(vehicle)
    end

    return vehicles
end)

lib.callback.register('lunar_garage:getImpoundedVehicles', function(source, index, society)
    local player = Framework.getPlayerFromId(source)
    if not player then return {} end
    
    local impound = Config.Impounds[index]
    local query = society and Queries.getImpoundSociety or Queries.getImpound
    local param1 = society and player:getJob() or player:getIdentifier()
    local vehicles = MySQL.query.await(query, { param1, impound.Type }) or {}

    local filtered = {}

    for _, vehicle in ipairs(vehicles) do
        vehicle.state = resolveVehicleState(vehicle)
        table.insert(filtered, vehicle)
    end

    return filtered
end)

lib.callback.register('lunar_garage:takeOutVehicle', function(source, index, plate, type)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    if Config.Debug then
        print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 takeOutVehicle -> player: %s, index: %s, plate: "%s", type: "%s"',
            tostring(source), tostring(index), tostring(plate), tostring(type)
        ))
    end

    local vehicle = MySQL.single.await(Queries.getStoredVehicle, {
        player:getIdentifier(), player:getJob(), plate, 1
    })

    if vehicle then
        MySQL.update.await(Queries.setStoredVehicle, { 0, plate })
        local garage = Config.Garages[index]
        local coords = garage.SpawnPosition
        local props = json.decode(vehicle.mods or vehicle.vehicle)
        local entity = Utils.createVehicle(props.model, coords, type)

        if entity == 0 then
            if Config.Debug then
                print(string.format('^1[lunar_garage:DEBUG:SERVER]^7 Failed to create vehicle entity for plate "%s"', tostring(plate)))
            end
            return
        end

        while NetworkGetEntityOwner(entity) == -1 do Wait(0) end

        local netId, owner = NetworkGetNetworkIdFromEntity(entity), NetworkGetEntityOwner(entity)
        
        if Config.Debug then
            print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 Vehicle created -> entity: %s, netId: %s, owner: %s',
                tostring(entity), tostring(netId), tostring(owner)
            ))
        end

        TriggerClientEvent('lunar_garage:setVehicleProperties', owner, netId, props)

        activeVehicles[plate] = entity

        giveVehicleKey(source, plate, netId)

        return netId
    else
        if Config.Debug then
            print(string.format('^1[lunar_garage:DEBUG:SERVER]^7 Vehicle "%s" not found in garage or already out (stored != 1)', tostring(plate)))
        end
    end
end)

lib.callback.register('lunar_garage:saveVehicle', function(source, props, netId)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    if Config.Debug then
        print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 saveVehicle -> player: %s, plate: "%s", netId: %s',
            tostring(source), tostring(props and props.plate), tostring(netId)
        ))
    end

    local vehicle = MySQL.single.await(Queries.getOwnedVehicle, {
        player:getIdentifier(), player:getJob(), props.plate
    })
    
    if vehicle then
        local oldProps = json.decode(vehicle.mods or vehicle.vehicle)

        if props.model ~= oldProps.model then
            if Config.Debug then
                print(string.format('^1[lunar_garage:DEBUG:SERVER]^7 Model mismatch for plate "%s"', props.plate))
            end
            return false
        end

        MySQL.update.await(Queries.setStoredVehicle, { 1, props.plate })
        MySQL.update.await(Queries.setVehicleProps, { json.encode(props), props.plate })

        SetTimeout(500, function()
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
        end)

        activeVehicles[props.plate] = nil;

        removeVehicleKey(source, props.plate)

        return true
    end
    
    return false
end)

lib.callback.register('lunar_garage:retrieveVehicle', function(source, index, plate, type)
    plate = plate and plate:match('^%s*(.-)%s*$')
    if not plate or plate == '' then return false end

    if Config.Debug then
        print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 retrieveVehicle -> player: %s, impoundIndex: %s, plate: "%s", type: "%s"',
            tostring(source), tostring(index), tostring(plate), tostring(type)
        ))
    end

    -- If the vehicle is already spawned in the world, delete the old instance so the player can retrieve it
    if activeVehicles[plate] then
        if DoesEntityExist(activeVehicles[plate]) then
            if Config.Debug then
                print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 Deleting existing active vehicle entity %s for plate "%s"', tostring(activeVehicles[plate]), plate))
            end
            DeleteEntity(activeVehicles[plate])
        end
        activeVehicles[plate] = nil
    end

    for _, veh in ipairs(GetAllVehicles()) do
        local vehPlate = GetVehicleNumberPlateText(veh)
        if vehPlate and vehPlate:match('^%s*(.-)%s*$') == plate then
            if Config.Debug then
                print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 Deleting world vehicle %s matching plate "%s"', tostring(veh), plate))
            end
            DeleteEntity(veh)
            break
        end
    end

    local player = Framework.getPlayerFromId(source)
    if not player then return false end

    local vehicle = MySQL.single.await(Queries.getOwnedVehicle, {
        player:getIdentifier(), player:getJob(), plate
    })

    if vehicle then
        local impData = vehicle.impound_data and json.decode(vehicle.impound_data) or nil
        if impData and impData.hold then
            if Config.Debug then
                print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 Vehicle "%s" is on police hold, retrieval blocked', plate))
            end
            return false, 'hold'
        end

        local price = impData and tonumber(impData.fee) or Config.ImpoundPrice
        if player:getAccountMoney('money') < price then
            if Config.Debug then
                print(string.format('^3[lunar_garage:DEBUG:SERVER]^7 Player has insufficient funds for fee $%s', price))
            end
            return false, 'money'
        end

        player:removeAccountMoney('money', price)

        -- Clear stored and impound states
        MySQL.update.await(Queries.setStoredVehicle, { 0, plate })

        local impound = Config.Impounds[index]
        local coords = impound.SpawnPosition
        local props = json.decode(vehicle.mods or vehicle.vehicle) or {}
        props.plate = plate
        local entity = Utils.createVehicle(props.model, coords, type)

        if entity == 0 then return false end

        while NetworkGetEntityOwner(entity) == -1 do Wait(0) end

        local netId, owner = NetworkGetNetworkIdFromEntity(entity), NetworkGetEntityOwner(entity)
        
        if Config.Debug then
            print(string.format('^2[lunar_garage:DEBUG:SERVER]^7 Impound vehicle created -> entity: %s, netId: %s, owner: %s',
                tostring(entity), tostring(netId), tostring(owner)
            ))
        end

        TriggerClientEvent('lunar_garage:setVehicleProperties', owner, netId, props)

        activeVehicles[plate] = entity

        giveVehicleKey(source, plate, netId)

        return true, netId
    end

    return false
end)

local function impoundVehicleByPlate(plate, impoundData)
    plate = plate and plate:match('^%s*(.-)%s*$')
    if not plate or plate == '' then return false end

    if activeVehicles[plate] then
        if DoesEntityExist(activeVehicles[plate]) then
            DeleteEntity(activeVehicles[plate])
        end
        activeVehicles[plate] = nil
    end

    for _, veh in ipairs(GetAllVehicles()) do
        local vehPlate = GetVehicleNumberPlateText(veh)
        if vehPlate and vehPlate:match('^%s*(.-)%s*$') == plate then
            DeleteEntity(veh)
            break
        end
    end

    local jsonStr = impoundData and json.encode(impoundData) or nil
    MySQL.update.await('UPDATE owned_vehicles SET `stored` = 0, `pound` = ?, `impound_data` = ? WHERE TRIM(`plate`) = ?', {
        'impound', jsonStr, plate
    })
    return true
end

exports('impoundVehicle', impoundVehicleByPlate)

RegisterNetEvent('lunar_garage:server:impoundVehicle', function(plate, netId, data)
    local src = source
    local player = Framework.getPlayerFromId(src)
    if not player then return end

    local job = player:getJob()
    local isAuthorized = job == 'police' or job == 'mechanic' or player:hasGroup('admin') or player:hasGroup('superadmin')
    if not isAuthorized then return end

    plate = plate and plate:match('^%s*(.-)%s*$')
    if not plate or plate == '' then return end

    if netId and netId ~= 0 then
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    local officerName = 'Officer #' .. src
    if player.getFirstName and player:getFirstName() and player.getLastName and player:getLastName() then
        officerName = player:getFirstName() .. ' ' .. player:getLastName()
    end

    local impoundData = {
        reason = (data and data.reason and data.reason ~= '') and data.reason or 'Impounded by authority',
        fee = (data and tonumber(data.fee)) and tonumber(data.fee) or (Config.ImpoundPrice or 1000),
        hold = (data and data.hold) and true or false,
        officer = officerName,
        date = os.date('%Y-%m-%d %H:%M')
    }

    impoundVehicleByPlate(plate, impoundData)
    TriggerClientEvent('lunar_garage:showNotification', src, ('Vehicle [%s] has been impounded.'):format(plate), 'success')
end)

RegisterCommand('impound', function(source)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local job = player:getJob()
    local isAuthorized = job == 'police' or job == 'mechanic' or player:hasGroup('admin') or player:hasGroup('superadmin')
    if not isAuthorized then
        TriggerClientEvent('lunar_garage:showNotification', source, 'You are not authorized to impound vehicles.', 'error')
        return
    end

    TriggerClientEvent('lunar_garage:client:impoundClosestVehicle', source)
end, false)

RegisterCommand('unhold', function(source, args)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local job = player:getJob()
    local isAuthorized = job == 'police' or player:hasGroup('admin') or player:hasGroup('superadmin')
    if not isAuthorized then
        TriggerClientEvent('lunar_garage:showNotification', source, 'You are not authorized to release police holds.', 'error')
        return
    end

    local plate = args[1] and args[1]:match('^%s*(.-)%s*$')
    if not plate or plate == '' then
        TriggerClientEvent('lunar_garage:showNotification', source, 'Usage: /unhold [plate]', 'error')
        return
    end

    local vehicle = MySQL.single.await('SELECT impound_data FROM owned_vehicles WHERE TRIM(`plate`) = ?', { plate })
    if not vehicle then
        TriggerClientEvent('lunar_garage:showNotification', source, 'Vehicle not found.', 'error')
        return
    end

    local data = vehicle.impound_data and json.decode(vehicle.impound_data) or {}
    data.hold = false
    data.unheldBy = (player.getFirstName and player:getFirstName() and player.getLastName and player:getLastName()) and (player:getFirstName() .. ' ' .. player:getLastName()) or ('Officer #' .. source)

    MySQL.update.await('UPDATE owned_vehicles SET `impound_data` = ? WHERE TRIM(`plate`) = ?', {
        json.encode(data), plate
    })
    TriggerClientEvent('lunar_garage:showNotification', source, ('Police hold on vehicle [%s] has been released.'):format(plate), 'success')
end, false)

lib.callback.register('lunar_garage:toggleVehicleFavorite', function(source, plate)
    local player = Framework.getPlayerFromId(source)
    if not player then return false end
    plate = plate and plate:match('^%s*(.-)%s*$')
    if not plate or plate == '' then return false end

    local vehicle = MySQL.single.await('SELECT is_favorite, favorite FROM owned_vehicles WHERE TRIM(`plate`) = ? AND (`owner` = ? OR `job` = ?)', {
        plate, player:getIdentifier(), player:getJob()
    })
    if not vehicle then return false end

    local current = (vehicle.is_favorite == 1 or vehicle.favorite == 1 or vehicle.is_favorite == true) and 1 or 0
    local newStatus = current == 1 and 0 or 1

    pcall(function()
        MySQL.update.await('UPDATE owned_vehicles SET `is_favorite` = ? WHERE TRIM(`plate`) = ? AND (`owner` = ? OR `job` = ?)', {
            newStatus, plate, player:getIdentifier(), player:getJob()
        })
    end)
    pcall(function()
        MySQL.update.await('UPDATE owned_vehicles SET `favorite` = ? WHERE TRIM(`plate`) = ? AND (`owner` = ? OR `job` = ?)', {
            newStatus, plate, player:getIdentifier(), player:getJob()
        })
    end)
    return true, newStatus == 1
end)

lib.callback.register('lunar_garage:setVehicleNickname', function(source, plate, nickname)
    local player = Framework.getPlayerFromId(source)
    if not player then return false end
    plate = plate and plate:match('^%s*(.-)%s*$')
    if not plate or plate == '' then return false end

    nickname = nickname and nickname:match('^%s*(.-)%s*$') or ''
    if nickname == '' then nickname = nil end

    pcall(function()
        MySQL.update.await('UPDATE owned_vehicles SET `custom_name` = ? WHERE TRIM(`plate`) = ? AND (`owner` = ? OR `job` = ?)', {
            nickname, plate, player:getIdentifier(), player:getJob()
        })
    end)
    pcall(function()
        MySQL.update.await('UPDATE owned_vehicles SET `nickname` = ? WHERE TRIM(`plate`) = ? AND (`owner` = ? OR `job` = ?)', {
            nickname, plate, player:getIdentifier(), player:getJob()
        })
    end)
    return true
end)

lib.callback.register('lunar_garage:getVehicleCoords', function(source, plate)
    local entity = activeVehicles[plate]

    if not entity then return end

    return GetEntityCoords(entity)
end)