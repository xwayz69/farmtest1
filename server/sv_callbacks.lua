--- Server Callbacks Handler
--- Handles all plant-related callbacks

--- Get Plant Data Callback
lib.callback.register('maximgm-farming:server:GetPlantData', function(source, plantId)
    if not _G.Plant then
        print('^1[MaximGM-Farming] ERROR: Plant class not loaded!^7')
        return false, "Plant class not initialized"
    end
    
    local plant = _G.Plant:getPlant(plantId)
    if not plant then
        return false, ("Could not find plant with id %s"):format(plantId)
    end
    
    local src = source
    local Player = server.GetPlayerFromId(src)
    local PlayerData = server.getPlayerData(Player)
    local isOwner = (plant.owner == PlayerData.identifier)
    
    -- Get owner name (simplified)
    local ownerName = "Unknown"
    if plant.owner and plant.owner ~= '' then
        -- Try to get from online players first
        for _, playerId in ipairs(GetPlayers()) do
            local ownerPlayer = server.GetPlayerFromId(tonumber(playerId))
            if ownerPlayer then
                local ownerData = server.getPlayerData(ownerPlayer)
                if ownerData.identifier == plant.owner then
                    ownerName = ownerData.name
                    break
                end
            end
        end
        
        -- If still unknown and function exists, try database
        if ownerName == "Unknown" and server.getPlayerDataByIdentifier then
            local ownerData = server.getPlayerDataByIdentifier(plant.owner)
            if ownerData and ownerData.name then
                ownerName = ownerData.name
            end
        end
    end
    
    local plantConfig = Config.Plants[plant.plantType]
    local totalFertilizer = plant:calcTotalFertilizer()
    local fertilizerBonus = 0
    
    if totalFertilizer > 0 and plantConfig and plantConfig.fertilizerBonus then
        fertilizerBonus = totalFertilizer * plantConfig.fertilizerBonus
    end
    
    local retData = {
        id = plant.id,
        coords = plant.coords,
        time = plant.time,
        plantType = plant.plantType,
        owner = plant.owner,
        ownerName = ownerName,
        isOwner = isOwner,
        fertilizer = plant:calcFertilizer(),
        water = plant:calcWater(),
        stage = plant:calcStage(),
        health = plant:calcHealth(),
        growth = plant:calcGrowth(),
        totalFertilizer = totalFertilizer,
        fertilizerBonus = fertilizerBonus
    }

    return true, retData
end)

--- Get Plant Locations Callback (FIXED)
lib.callback.register('maximgm-farming:server:GetPlantLocations', function(source)
    if not _G.PlantCache then
        print('^1[MaximGM-Farming] ERROR: PlantCache not initialized!^7')
        return {}
    end
    
    -- Make sure we return a proper table
    local plants = {}
    local count = 0
    
    for id, data in pairs(_G.PlantCache) do
        plants[id] = data
        count = count + 1
    end
    
    print(string.format('^2[MaximGM-Farming]^7 Sending %d plants to client %d', count, source))
    return plants
end)

--- Get Nearby Plants Callback (FIXED)
lib.callback.register('maximgm-farming:server:GetNearbyPlants', function(source, coords, radius)
    if not _G.PlantCache then
        return {}
    end
    
    local nearbyPlants = {}
    
    -- Check if coords is valid
    if not coords or type(coords) ~= "vector3" then
        print('^1[MaximGM-Farming] ERROR: Invalid coords in GetNearbyPlants^7')
        return nearbyPlants
    end
    
    for id, plantData in pairs(_G.PlantCache) do
        if plantData and plantData.coords then
            local distance = #(coords - plantData.coords)
            if distance <= radius then
                table.insert(nearbyPlants, {
                    id = id,
                    coords = plantData.coords,
                    distance = distance
                })
            end
        end
    end
    
    return nearbyPlants
end)

--- Register useable items for all plant types
CreateThread(function()
    Wait(1000) -- Wait for server bridge to load
    
    for plantType, plantData in pairs(Config.Plants) do
        server.registerUseableItem(plantData.seed, function(source)
            TriggerClientEvent('maximgm-farming:client:UseSeed_' .. plantType, source)
        end)
    end
    
    print('^2[MaximGM-Farming]^7 Registered ' .. #Config.Plants .. ' useable seed items')
end)