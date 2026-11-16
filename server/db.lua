Queries = {
    getGarage = 'SELECT * FROM %s WHERE owner = ? and type = ? and job is NULL',
    getGarageSociety = 'SELECT * FROM %s WHERE job = ? and type = ?',
    getImpound = 'SELECT * FROM %s WHERE owner = ? and type = ? and (`stored` = 0 or `pound` IS NOT NULL or `impound_data` IS NOT NULL) and job is NULL',
    getImpoundSociety = 'SELECT * FROM %s WHERE job = ? and type = ? and (`stored` = 0 or `pound` IS NOT NULL or `impound_data` IS NOT NULL)',
    getStoredVehicle = 'SELECT * FROM %s WHERE (owner = ? or job = ?) and TRIM(plate) = ? and `stored` = ?',
    setStoredVehicle = 'UPDATE %s SET `stored` = ?, `pound` = NULL, `impound_data` = NULL WHERE TRIM(plate) = ?',
    getOwnedVehicle = 'SELECT * FROM %s WHERE (owner = ? or job = ?) and TRIM(plate) = ?',
    getVehicle = 'SELECT * FROM %s WHERE owner = ? and TRIM(plate) = ?',
    getVehicleStrict = 'SELECT * FROM %s WHERE owner = ? and TRIM(plate) = ? and job is NULL',
    transferVehiclePlayer = 'UPDATE %s SET owner = ? WHERE TRIM(plate) = ?',
    transferVehicleSociety = 'UPDATE %s SET job = ? WHERE TRIM(plate) = ?',
    withdrawVehicleSociety = 'UPDATE %s SET job = NULL WHERE TRIM(plate) = ?',
    getStoredGarage = 'SELECT * FROM %s WHERE owner = ? and type = ? and job is NULL and `stored` = 1'
}

local table
if Framework.name == 'es_extended' then
    table = 'owned_vehicles'
    Queries.setVehicleProps = 'UPDATE %s SET vehicle = ? WHERE TRIM(plate) = ?'
elseif Framework.name == 'qb-core' then
    table = 'player_vehicles'
    Queries.setVehicleProps = 'UPDATE %s SET mods = ? WHERE TRIM(plate) = ?'
else
    error(('%s framework isn\'t supported by default, you have to implement it yourself.'))
end

for key, query in pairs(Queries) do
    Queries[key] = query:format(table)
    if Framework.name == 'qb-core' then
        Queries[key] = Queries[key]:gsub('owner', 'citizenid')
    end
end
