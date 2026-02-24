--- Planting Module
--- Handles seed placement and planting logic

local RayCast = lib.raycast.cam
local rayCastDistance = Config.rayCastingDistance

local seedPlaced = false
local placingSeed = false
local currentPlantType = nil

--- Check if there's another plant nearby
--- @param coords vector3 The coordinates to check
--- @return boolean, number Returns true if too close, and the distance
local function isPlantTooClose(coords)
    local minDistance = Config.MinPlantDistance
    local nearbyPlants = lib.callback.await('maximgm-farming:server:GetNearbyPlants', 200, coords, minDistance)
    
    if nearbyPlants and #nearbyPlants > 0 then
        local closestDistance = minDistance + 1
        for _, plant in ipairs(nearbyPlants) do
            local distance = #(coords - plant.coords)
            if distance < closestDistance then
                closestDistance = distance
            end
        end
        return true, closestDistance
    end
    
    return false, 0
end

--- Check if player is inside farming zone
--- @return boolean
local function checkInsideFarmingZone()
    if not Config.FarmingZones or #Config.FarmingZones == 0 then
        return true
    end
    
    if _G.InsideZone == nil then
        return false
    end
    
    return _G.InsideZone
end

--- Plant single seed at location
--- @param coords vector3 The coordinates to plant
--- @param plantType string The type of plant
--- @param skipAnimation boolean Skip planting animation
local function plantSeedAtLocation(coords, plantType, skipAnimation)
    local plantConfig = Config.Plants[plantType]
    if not plantConfig then return false end

    -- Check distance to other plants
    local tooClose, distance = isPlantTooClose(coords)
    
    if tooClose then
        utils.notify(
            Locales['notify_title_farming'], 
            string.format(
                Locales['plant_too_close'] or 'Too close to another plant! (%.1fm, min: %.1fm)', 
                distance, 
                Config.MinPlantDistance
            ), 
            'error', 
            3000
        )
        return false
    end

    local ped = cache.ped

    if not skipAnimation then
        lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
        lib.playAnim(ped, 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, 8.0, -1, 48, 0, false, false, false)
        
        if lib.progressBar({
            duration = 2000,
            label = Locales['place_sapling'],
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true, mouse = false },
        }) then
            TriggerServerEvent('maximgm-farming:server:CreateNewPlant', coords, plantType)
            ClearPedTasks(ped)
            return true
        else
            ClearPedTasks(ped)
            return false
        end
    else
        TriggerServerEvent('maximgm-farming:server:CreateNewPlant', coords, plantType)
        return true
    end
end

--- Calculate row planting positions
--- @param startCoords vector3 Starting position
--- @param endCoords vector3 Ending position
--- @param spacing number Distance between plants
--- @return table Array of coordinates
local function calculateRowPositions(startCoords, endCoords, spacing)
    local positions = {}
    local distance = #(startCoords - endCoords)
    local numPlants = math.floor(distance / spacing)
    
    if numPlants < 1 then
        return {startCoords}
    end
    
    local direction = (endCoords - startCoords) / distance
    
    for i = 0, numPlants do
        local offset = i * spacing
        local pos = startCoords + (direction * offset)
        table.insert(positions, pos)
    end
    
    return positions
end

--- Starts the raycasting process to plant seeds
--- @param plantType string The type of plant to grow
--- @param rowMode boolean Enable row planting mode
local function useSeed(plantType, rowMode)
    if cache.vehicle then return end
    
    local plantConfig = Config.Plants[plantType]
    if not plantConfig then return end

    local hasItem = client.hasItems(plantConfig.seed, 1)
    if not hasItem then return end

    -- Check if inside farming zone
    if not checkInsideFarmingZone() then
        utils.notify(
            Locales['notify_title_farming'], 
            Locales['not_in_farming_zone'] or 'You must be in a farming zone to plant!', 
            'error', 
            3000
        )
        return
    end

    if placingSeed then return end
    
    placingSeed = true
    seedPlaced = false
    currentPlantType = plantType

    -- Row planting mode
    if rowMode then
        local startPos = nil
        local tempObject = nil
        
        lib.showTextUI(Locales['row_plant_start'] or '[E] Set Start Point | [X] Cancel', {
            position = 'left-center',
            icon = 'fas fa-seedling',
            style = { borderRadius = 10 }
        })

        local hit, entityHit, endCoords, surfaceNormal, materialHash = RayCast(511, 4, rayCastDistance)
        local ModelHash = plantConfig.props[1]
        local zOffset = plantConfig.stageZOffset[1] or 0.0
        
        lib.requestModel(ModelHash)
        tempObject = CreateObject(ModelHash, endCoords.x, endCoords.y, endCoords.z + zOffset, false, false, false)
        SetModelAsNoLongerNeeded(ModelHash)
        SetEntityCollision(tempObject, false, false)
        SetEntityAlpha(tempObject, 200, true)

        -- Select start position
        while not startPos do
            hit, entityHit, endCoords, surfaceNormal, materialHash = RayCast(511, 4, rayCastDistance)

            if IsControlPressed(0, 186) then -- [X] Cancel
                lib.hideTextUI()
                placingSeed = false
                DeleteObject(tempObject)
                return
            end

            if hit then
                SetEntityCoords(tempObject, endCoords.x, endCoords.y, endCoords.z + zOffset)

                if IsControlPressed(0, 38) then -- [E] Set start
                    if Config.GroundHashes[materialHash] then
                        if checkInsideFarmingZone() then
                            startPos = endCoords
                            Wait(200)
                        else
                            utils.notify(
                                Locales['notify_title_farming'], 
                                Locales['not_in_farming_zone'] or 'Must be in farming zone!', 
                                'error', 
                                3000
                            )
                            Wait(200)
                        end
                    else
                        utils.notify(Locales['notify_title_farming'], Locales['cannot_plant_here'], 'error', 3000)
                        Wait(200)
                    end
                end
            end
            Wait(0)
        end

        -- Select end position
        lib.showTextUI(Locales['row_plant_end'] or '[E] Set End Point & Plant | [X] Cancel', {
            position = 'left-center',
            icon = 'fas fa-seedling',
            style = { borderRadius = 10 }
        })

        local rowObjects = {}
        table.insert(rowObjects, tempObject)

        while true do
            hit, entityHit, endCoords, surfaceNormal, materialHash = RayCast(511, 4, rayCastDistance)

            if IsControlPressed(0, 186) then -- [X] Cancel
                lib.hideTextUI()
                placingSeed = false
                for _, obj in ipairs(rowObjects) do
                    DeleteObject(obj)
                end
                return
            end

            if hit then
                -- Calculate row positions
                local positions = calculateRowPositions(startPos, endCoords, Config.MinPlantDistance)
                
                -- Clear old preview objects
                for i = 2, #rowObjects do
                    DeleteObject(rowObjects[i])
                end
                rowObjects = {tempObject}
                
                -- Create preview objects
                for i = 2, #positions do
                    local previewObj = CreateObject(ModelHash, positions[i].x, positions[i].y, positions[i].z + zOffset, false, false, false)
                    SetEntityCollision(previewObj, false, false)
                    SetEntityAlpha(previewObj, 200, true)
                    table.insert(rowObjects, previewObj)
                end

                if IsControlPressed(0, 38) then -- [E] Plant row
                    if Config.GroundHashes[materialHash] then
                        if checkInsideFarmingZone() then
                            -- Check if player has enough seeds
                            local seedsNeeded = #positions
                            local hasSeeds = client.hasItems(plantConfig.seed, seedsNeeded)
                            
                            if not hasSeeds then
                                utils.notify(
                                    Locales['notify_title_farming'], 
                                    string.format('You need %d seeds! (Current positions: %d)', seedsNeeded, seedsNeeded), 
                                    'error', 
                                    3000
                                )
                                Wait(200)
                            else
                                lib.hideTextUI()
                                
                                -- Delete preview objects
                                for _, obj in ipairs(rowObjects) do
                                    DeleteObject(obj)
                                end

                                -- Plant all seeds
                                local ped = cache.ped
                                lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
                                lib.playAnim(ped, 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, 8.0, -1, 48, 0, false, false, false)
                                
                                if lib.progressBar({
                                    duration = 2000 * #positions,
                                    label = string.format('Planting %d seeds...', #positions),
                                    useWhileDead = false,
                                    canCancel = true,
                                    disable = { car = true, move = true, combat = true, mouse = false },
                                }) then
                                    for _, pos in ipairs(positions) do
                                        plantSeedAtLocation(pos, plantType, true)
                                    end
                                    
                                    ClearPedTasks(ped)
                                    placingSeed = false
                                    utils.notify(
                                        Locales['notify_title_farming'], 
                                        string.format('Planted %d seeds in a row!', #positions), 
                                        'success', 
                                        3000
                                    )
                                    return
                                else
                                    ClearPedTasks(ped)
                                    placingSeed = false
                                    utils.notify(Locales['notify_title_farming'], Locales['canceled'], 'error', 3000)
                                    return
                                end
                            end
                        else
                            utils.notify(
                                Locales['notify_title_farming'], 
                                Locales['not_in_farming_zone'] or 'Must be in farming zone!', 
                                'error', 
                                3000
                            )
                            Wait(200)
                        end
                    else
                        utils.notify(Locales['notify_title_farming'], Locales['cannot_plant_here'], 'error', 3000)
                        Wait(200)
                    end
                end
            end
            Wait(0)
        end
    else
        -- Single plant mode (original)
        lib.showTextUI(Locales['place_or_cancel'], {
            position = 'left-center',
            icon = 'fas fa-seedling',
            style = { borderRadius = 10 }
        })

        local hit, entityHit, endCoords, surfaceNormal, materialHash = RayCast(511, 4, rayCastDistance)

        local ModelHash = plantConfig.props[1]
        local zOffset = plantConfig.stageZOffset[1] or 0.0
        
        lib.requestModel(ModelHash)
        local plant = CreateObject(ModelHash, endCoords.x, endCoords.y, endCoords.z + zOffset, false, false, false)
        
        SetModelAsNoLongerNeeded(ModelHash)
        SetEntityCollision(plant, false, false)
        SetEntityAlpha(plant, 200, true)

        while not seedPlaced do
            hit, entityHit, endCoords, surfaceNormal, materialHash = RayCast(511, 4, rayCastDistance)

            if IsControlPressed(0, 186) then
                lib.hideTextUI()
                seedPlaced = false
                placingSeed = false
                currentPlantType = nil
                DeleteObject(plant)
                return
            end

            if hit then
                SetEntityCoords(plant, endCoords.x, endCoords.y, endCoords.z + zOffset)

                if IsControlPressed(0, 38) then
                    if Config.GroundHashes[materialHash] then
                        if not checkInsideFarmingZone() then
                            utils.notify(
                                Locales['notify_title_farming'], 
                                Locales['not_in_farming_zone'] or 'Must be in farming zone!', 
                                'error', 
                                3000
                            )
                            Wait(200)
                        else
                            local tooClose, distance = isPlantTooClose(endCoords)
                            
                            if tooClose then
                                utils.notify(
                                    Locales['notify_title_farming'], 
                                    string.format(
                                        Locales['plant_too_close'] or 'Too close! (%.1fm, min: %.1fm)', 
                                        distance, 
                                        Config.MinPlantDistance
                                    ), 
                                    'error', 
                                    3000
                                )
                                Wait(200)
                            else
                                seedPlaced = true
                                lib.hideTextUI()
                                DeleteObject(plant)

                                if plantSeedAtLocation(endCoords, plantType, false) then
                                    placingSeed = false
                                    currentPlantType = nil
                                    return
                                else
                                    placingSeed = false
                                    currentPlantType = nil
                                    return
                                end
                            end
                        end
                    else
                        utils.notify(Locales['notify_title_farming'], Locales['cannot_plant_here'], 'error', 3000)
                        Wait(200)
                    end
                end
            end

            Wait(0)
        end
    end
end

--- Register client events for each plant type (Single & Row mode)
for plantType, plantData in pairs(Config.Plants) do
    -- Single plant mode
    RegisterNetEvent('maximgm-farming:client:UseSeed_' .. plantType, function()
        useSeed(plantType, false)
    end)
    
    -- Row planting mode
    RegisterNetEvent('maximgm-farming:client:UseSeedRow_' .. plantType, function()
        useSeed(plantType, true)
    end)
end

--- Register exports
for plantType, plantData in pairs(Config.Plants) do
    exports('useSeed_' .. plantType, function()
        useSeed(plantType, false)
    end)
    
    exports('useSeedRow_' .. plantType, function()
        useSeed(plantType, true)
    end)
end

--- Make module global
_G.Planting = {
    useSeed = useSeed
}