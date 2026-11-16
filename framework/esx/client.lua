if GetResourceState('es_extended') ~= 'started' then return end

Framework = { name = 'es_extended' }
local sharedObject = exports['es_extended']:getSharedObject()

AddEventHandler('esx:setPlayerData', function(key, val, last)
    if GetInvokingResource() == 'es_extended' then
        sharedObject.PlayerData[key] = val
        if OnPlayerData then
            OnPlayerData(key, val, last)
        end
    end
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    sharedObject.PlayerData = xPlayer
    sharedObject.PlayerLoaded = true
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    sharedObject.PlayerLoaded = false
    sharedObject.PlayerData = {}
end)

Framework.isPlayerLoaded = function()
    if sharedObject.IsPlayerLoaded then
        return sharedObject.IsPlayerLoaded()
    end
    return sharedObject.PlayerLoaded == true
end

---@diagnostic disable-next-line: duplicate-set-field
Framework.getJob = function()
    local playerData = (sharedObject.GetPlayerData and sharedObject.GetPlayerData()) or sharedObject.PlayerData
    if not playerData or not playerData.job then
        return nil
    end

    return playerData.job.name
end

Framework.hasItem = function(name)
    local playerData = (sharedObject.GetPlayerData and sharedObject.GetPlayerData()) or sharedObject.PlayerData
    if not playerData or not playerData.inventory then return false end
    for k, v in ipairs(playerData.inventory) do
        if v.name == name then
            return true
        end
    end
    return false
end

Framework.spawnVehicle = sharedObject.Game.SpawnVehicle

Framework.spawnLocalVehicle = sharedObject.Game.SpawnLocalVehicle

Framework.deleteVehicle = sharedObject.Game.DeleteVehicle

Framework.getPlayersInArea = sharedObject.Game.GetPlayersInArea