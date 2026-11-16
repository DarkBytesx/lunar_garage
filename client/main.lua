local function getVehicleType(model)
    if IsThisModelABike(model) then
        return 'bike'
    end

    -- Not really sure if quadbike is considered an automobile or a bike
    if IsThisModelACar(model) or IsThisModelAQuadbike(model) then
        return 'automobile'
    end

    if IsThisModelABoat(model) or IsThisModelAJetski(model) then
        return 'boat'
    end

    if IsThisModelAPlane(model) then
        return 'plane'
    end

    if IsThisModelAHeli(model) then
        return 'heli'
    end
end

-- Taken from ox_lib, but higher timeout value and modified
RegisterNetEvent('lunar_garage:setVehicleProperties', function(netId, data)
    local timeout = 10000

    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
        Wait(0)
        timeout -= 1
    end

    if timeout > 0 then
        local vehicle = NetToVeh(netId)

        if NetworkGetEntityOwner(vehicle) ~= cache.playerId then return end

        lib.setVehicleProperties(vehicle, data)
    end
end)

function SpawnVehicle(args)
    ---@type integer, VehicleProperties
    local index, props in args
    
    local garage = Config.Garages[index]
    
    if Config.SpawnpointCheck and lib.getClosestVehicle(garage.SpawnPosition.xyz, 3.0, false) then
        ShowNotification(locale('spawn_occupied'), 'error')
        return
    end

    lib.requestModel(props.model)
    local type = getVehicleType(props.model)
    local netId = lib.callback.await('lunar_garage:takeOutVehicle', false, index, props.plate, type)
    if not netId then return end
    
    while not NetworkDoesEntityExistWithNetworkId(netId) do Wait(0) end

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    CreateThread(function()
        while true do
            if NetworkGetEntityOwner(vehicle) == cache.playerId then
                lib.setVehicleProperties(vehicle, props)
                return
            end

            local plate = GetVehicleNumberPlateText(vehicle)

            if plate == props.plate then
                return
            end

            Wait(0)
        end
    end)

    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)

    -- The player doesn't get warped in the vehicle sometimes, repeat it and timeout after 2000 attempts
    for _ = 1, 2000 do
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
    
        if GetVehiclePedIsIn(cache.ped, false) == vehicle then
            break
        end

        Wait(0)
    end

    SetVehicleFuel(vehicle, props.fuelLevel or 100.0)
    SetVehicleOwner(props.plate, vehicle)
end

function GetVehicleLabel(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    
    if label == 'NULL' then 
        label = GetDisplayNameFromVehicleModel(model)
    end

    return label
end

local function getClassIcon(class)
    if class == 8 then
        return 'motorcycle'
    elseif class == 13 then
        return 'bicycle'
    elseif class == 15 then
        return 'helicopter'
    else
        return 'car'
    end
end

local function getFuelBarColor(fuel)
    -- fuelLevel not defined in vehicleProps??
    if not fuel then return 'lime' end

    if fuel > 75.0 then
        return 'lime'
    elseif fuel > 50.0 then
        return 'yellow'
    elseif fuel > 25.0 then
        return 'orange'
    else
        return 'red'
    end
end

local vehicleClassNames = {
    [0] = 'Compacts', [1] = 'Sedans', [2] = 'SUVs', [3] = 'Coupes',
    [4] = 'Muscle', [5] = 'Sports Classics', [6] = 'Sports', [7] = 'Super',
    [8] = 'Motorcycles', [9] = 'Off-Road', [10] = 'Industrial', [11] = 'Utility',
    [12] = 'Vans', [13] = 'Cycles', [14] = 'Boats', [15] = 'Helicopters',
    [16] = 'Planes', [17] = 'Service', [18] = 'Emergency', [19] = 'Military',
    [20] = 'Commercial', [21] = 'Trains', [22] = 'Open Wheel'
}

local function formatVehicleForNui(vehicle)
    local props = json.decode(vehicle.mods or vehicle.vehicle) or {}
    props.plate = vehicle.plate

    local isFav = (vehicle.is_favorite == 1 or vehicle.favorite == 1 or vehicle.is_favorite == true or vehicle.favorite == true)
    local nickname = (vehicle.custom_name and vehicle.custom_name ~= '') and vehicle.custom_name or ((vehicle.nickname and vehicle.nickname ~= '') and vehicle.nickname or nil)

    local classNum = GetVehicleClassFromName(GetDisplayNameFromVehicleModel(props.model))
    local className = vehicleClassNames[classNum] or 'Automobile'

    local fuelLevel = props.fuelLevel or 100.0
    local fuelPercent = math.floor(math.min(100.0, math.max(0.0, fuelLevel)) + 0.5)

    local bodyHealth = props.bodyHealth or 1000.0
    local bodyPercent = math.floor((math.min(1000.0, math.max(0.0, bodyHealth)) / 10.0) + 0.5)

    local engineHealth = props.engineHealth or 1000.0
    local enginePercent = math.floor((math.min(1000.0, math.max(0.0, engineHealth)) / 10.0) + 0.5)

    local impData = nil
    if vehicle.impound_data then
        if type(vehicle.impound_data) == 'table' then
            impData = vehicle.impound_data
        else
            pcall(function()
                impData = json.decode(vehicle.impound_data)
            end)
        end
    end

    local baseLabel = GetVehicleLabel(props.model)

    return {
        plate = vehicle.plate,
        model = props.model,
        label = baseLabel,
        class = classNum,
        className = className,
        fuel = fuelPercent,
        body = bodyPercent,
        engine = enginePercent,
        state = vehicle.state or (impData and 'in_impound' or (vehicle.stored == 1 and 'in_garage' or 'out_garage')),
        is_favorite = isFav,
        nickname = nickname,
        impound_data = impData,
        props = props
    }
end

local function openGarage(index)
    local garage = Config.Garages[index]
    local garageName = (garage and (garage.Label or garage.Name)) or ('Garage #' .. index)
    local raw = lib.callback.await('lunar_garage:getOwnedVehicles', false, index, false)
    local formatted = {}
    if raw then
        for _, v in ipairs(raw) do
            table.insert(formatted, formatVehicleForNui(v))
        end
    end

    local job = Framework.getJob and Framework.getJob() or nil
    local hasSociety = job ~= nil and job ~= 'unemployed'

    SendNUIMessage({
        action = 'open',
        type = 'garage',
        garageIndex = index,
        garageName = garageName,
        vehicles = formatted,
        hasSociety = hasSociety
    })
    SetNuiFocus(true, true)
end

---@param vehicle number?
local function saveVehicle(vehicle)
    if not vehicle and cache.seat ~= -1 then
        ShowNotification(locale('not_driver'), 'error')
        return
    end

    local vehicle = cache.vehicle or vehicle
    local props = lib.getVehicleProperties(vehicle)

    if not props then return end

    props.plate = props.plate:strtrim(' ') -- Trim whitespace
    props.fuelLevel = GetVehicleFuel(vehicle)
    props.bodyHealth = math.floor(GetVehicleBodyHealth(vehicle) + 0.5)
    props.engineHealth = math.floor(GetVehicleEngineHealth(vehicle) + 0.5)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = lib.callback.await('lunar_garage:saveVehicle', false, props, netId)
    
    if result then
        if cache.vehicle then
            TaskLeaveAnyVehicle(cache.ped, 0, 0)
            Wait(1000)
        end

        RemoveVehicleKey(props.plate)
        ShowNotification(locale('vehicle_saved'), 'success')
    else
        ShowNotification(locale('not_your_vehicle'), 'error')
    end
end

local function retrieveVehicle(args)
    ---@type integer, VehicleProperties
    local index = (type(args) == 'table' and args.index) or args
    local props = (type(args) == 'table' and args.props) or nil
    if not props then return end
    
    lib.requestModel(props.model)
    local type = getVehicleType(props.model)
    local success, res = lib.callback.await('lunar_garage:retrieveVehicle', false, index, props.plate, type)

    if not success or not res then
        if res == 'hold' then
            ShowNotification(locale('vehicle_on_hold'), 'error')
        else
            ShowNotification(locale('not_enough_money'), 'error')
        end
        return false, res
    end

    local netId = res
    while not NetworkDoesEntityExistWithNetworkId(netId) do Wait(0) end

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    CreateThread(function()
        while true do
            if NetworkGetEntityOwner(vehicle) == cache.playerId then
                lib.setVehicleProperties(vehicle, props)
                return
            end

            local plate = GetVehicleNumberPlateText(vehicle)

            if plate == props.plate then
                return
            end

            Wait(0)
        end
    end)

    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)

    -- The player doesn't get warped in the vehicle sometimes, repeat it and timeout after 2000 attempts
    for _ = 1, 2000 do
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
        
        if GetVehiclePedIsIn(cache.ped, false) == vehicle then
            break
        end

        Wait(0)
    end

    SetVehicleFuel(vehicle, props.fuelLevel or 100.0)
    SetVehicleOwner(props.plate, vehicle)
    return true
end

local function openImpound(index)
    local impound = Config.Impounds[index]
    local impoundName = (impound and (impound.Label or impound.Name)) or ('City Impound #' .. index)
    local raw = lib.callback.await('lunar_garage:getImpoundedVehicles', false, index, false)
    local formatted = {}
    if raw then
        for _, v in ipairs(raw) do
            table.insert(formatted, formatVehicleForNui(v))
        end
    end

    local job = Framework.getJob and Framework.getJob() or nil
    local hasSociety = job ~= nil and job ~= 'unemployed'

    SendNUIMessage({
        action = 'open',
        type = 'impound',
        garageIndex = index,
        garageName = impoundName,
        vehicles = formatted,
        hasSociety = hasSociety
    })
    SetNuiFocus(true, true)
end

-- ========================================================
-- NUI CALLBACKS
-- ========================================================
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('getVehicles', function(data, cb)
    local category = data.category or 'personal'
    local index = data.index or 1
    local raw
    if category == 'society' then
        raw = lib.callback.await('lunar_garage:getOwnedVehicles', false, index, true)
    elseif category == 'impound' then
        raw = lib.callback.await('lunar_garage:getImpoundedVehicles', false, index, false)
    else
        raw = lib.callback.await('lunar_garage:getOwnedVehicles', false, index, false)
    end

    local formatted = {}
    if raw then
        for _, v in ipairs(raw) do
            table.insert(formatted, formatVehicleForNui(v))
        end
    end
    cb(formatted)
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    SetNuiFocus(false, false)
    SpawnVehicle({ index = data.index, props = data.props })
    cb('ok')
end)

RegisterNUICallback('markGps', function(data, cb)
    local coords = lib.callback.await('lunar_garage:getVehicleCoords', false, data.plate)
    if coords then
        SetNewWaypoint(coords.x, coords.y)
        ShowNotification(locale('out_garage_message'), 'info')
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('retrieveImpound', function(data, cb)
    local success, res = retrieveVehicle({ index = data.index, props = data.props })
    if success then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        cb({ success = true })
    else
        cb({ success = false, error = res })
    end
end)

RegisterNUICallback('toggleFavorite', function(data, cb)
    local success, newStatus = lib.callback.await('lunar_garage:toggleVehicleFavorite', false, data.plate)
    if success then
        ShowNotification(newStatus and locale('favorite_added') or locale('favorite_removed'), 'success')
        cb({ success = true, is_favorite = newStatus })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('setNickname', function(data, cb)
    local newNick = data.nickname and data.nickname:match('^%s*(.-)%s*$') or ''
    local success = lib.callback.await('lunar_garage:setVehicleNickname', false, data.plate, newNick)
    if success then
        if newNick ~= '' then
            ShowNotification(locale('nickname_saved'), 'success')
        else
            ShowNotification(locale('nickname_cleared'), 'info')
        end
        cb({ success = true, nickname = newNick })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('submitImpound', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('lunar_garage:server:impoundVehicle', data.plate, data.netId, {
        reason = data.reason,
        fee = tonumber(data.fee),
        hold = data.hold == true
    })
    cb('ok')
end) 

local function garagePrompt(index, data)
    if cache.vehicle then
        ShowUI(('[%s] - %s'):format(Binds.second.currentKey, locale('save_vehicle')), 'floppy-disk')
        Binds.second.addListener('garage', function()
            saveVehicle()
        end)
    else
        local prompt

        if data.Interior then
            prompt = ('[%s] - %s  \n  [%s] - %s'):format(Binds.first.currentKey, locale('open_garage'), Binds.second.currentKey, locale('enter_interior'))
        else
            prompt = (('[%s] - %s'):format(Binds.first.currentKey, locale('open_garage')))
        end

        ShowUI(prompt, 'warehouse')
        Binds.first.addListener('garage', function()
            openGarage(index)
        end)
        Binds.second.addListener('garage', function()
            EnterInterior(index)
        end)
    end
end

local currentGarageIndex

lib.onCache('vehicle', function(vehicle)
    if not currentGarageIndex then return end

    local garage = Config.Garages[currentGarageIndex]

    if not garage then return end
    
    -- Update value manually, because it gets updated after the call of onCache
    cache.vehicle = vehicle
    garagePrompt(currentGarageIndex, garage)
end)

for index, data in ipairs(Config.Garages) do
    if (not Config.Target or not data.PedPosition) and data.Position then
        lib.zones.sphere({
            coords = data.Position,
            radius = Config.MaxDistance,
            onEnter = function()
                if data.Jobs and not Utils.hasJobs(data.Jobs) then return end

                garagePrompt(index, data)
                currentGarageIndex = index
            end,
            onExit = function()
                HideUI()
                Binds.first.removeListener('garage')
                Binds.second.removeListener('garage')
                currentGarageIndex = nil
            end
        })
    elseif (Config.Target or not data.Position) and data.PedPosition then
        if not data.Model then
            warn(('Skipping garage - missing Model, index: %s'):format(index))
            goto continue
        end

        Utils.createPed(data.PedPosition, data.Model, {
            {
                label = locale('open_garage'),
                icon = 'warehouse',
                job = data.Jobs,
                args = index,
                onSelect = openGarage
            },
            {
                label = locale('enter_interior'),
                icon = 'right-to-bracket',
                job = data.Jobs,
                args = index,
                canInteract = function()
                    return data.Interior ~= nil
                end,
                onSelect = EnterInterior
            },
            {
                label = locale('save_vehicle'),
                icon = 'floppy-disk',
                job = data.Jobs,
                onSelect = function()
                    local vehicle = GetVehiclePedIsIn(cache.ped, true)

                    if Utils.distanceCheck(cache.ped, vehicle, 20.0) then
                        saveVehicle(vehicle)
                    end
                end
            }
        })
    else
        warn(('Skipping garage - missing Position or PedPosition, index: %s'):format(index))
    end

    ::continue::
end

for index, data in ipairs(Config.Impounds) do
    if (not Config.Target or not data.PedPosition) and data.Position then
        lib.zones.sphere({
            coords = data.Position,
            radius = Config.MaxDistance,
            onEnter = function()
                if data.Jobs and not Utils.hasJobs(data.Jobs) then return end

                ShowUI(('[%s] - %s'):format(Binds.first.currentKey, locale('open_impound')), 'warehouse')
                Binds.first.addListener('impound', function()
                    openImpound(index)
                end)
            end,
            onExit = function()
                HideUI()
                Binds.first.removeListener('impound')
            end
        })
    elseif (Config.Target or not data.Position) and data.PedPosition then
        if not data.Model then
            warn(('Skipping impound - missing Model, index: %s'):format(index))
            goto continue
        end

        Utils.createPed(data.PedPosition, data.Model, {
            {
                label = locale('open_impound'),
                icon = 'warehouse',
                job = data.Jobs,
                args = index,
                onSelect = openImpound
            }
        })
    else
        warn(('Skipping impound - missing Position or PedPosition, index: %s'):format(index))
    end

    ::continue::
end

RegisterNetEvent('lunar_garage:client:impoundClosestVehicle', function()
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then
        vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, true)
    end
    if not vehicle or vehicle == 0 then
        ShowNotification(locale('no_vehicle_near_you'), 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    plate = plate and (string.strtrim and plate:strtrim(' ') or plate:match('^%s*(.-)%s*$')) or ''
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    SendNUIMessage({
        action = 'openImpoundDialog',
        plate = plate,
        netId = netId,
        defaultFee = Config.ImpoundPrice or 1000
    })
    SetNuiFocus(true, true)
end)

CreateThread(function()
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addGlobalVehicle({
            {
                name = 'lunar_garage:target_impound',
                icon = 'fa-solid fa-truck-tow',
                label = 'Impound Vehicle',
                groups = { 'police', 'mechanic' },
                distance = 2.5,
                onSelect = function(data)
                    TriggerEvent('lunar_garage:client:impoundClosestVehicle')
                end
            }
        })
    end
end)