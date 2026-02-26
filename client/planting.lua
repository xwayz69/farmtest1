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

    -- ✅ JOB CHECK: hanya farmer yang boleh menanam
    if not requireJobAccess() then return end
    
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
    -- Untuk row mode: arahkan ke prop box, set titik awal & akhir di atas box
    if rowMode then
        local ModelHash = plantConfig.props[1]
        local zOffset   = plantConfig.stageZOffset[1] or 0.0

        lib.requestModel(ModelHash)
        local tempObject = CreateObject(ModelHash, 0, 0, 0, false, false, false)
        SetModelAsNoLongerNeeded(ModelHash)
        SetEntityCollision(tempObject, false, false)
        SetEntityAlpha(tempObject, 200, true)

        lib.showTextUI(Locales['row_plant_start'] or '[E] Aim at plot box - Set Start / [X] Cancel', {
            position = 'left-center', icon = 'fas fa-seedling', style = { borderRadius = 10 }
        })

        -- ── Pilih titik START ──────────────────────────────────
        local startPos   = nil
        local startPlotId = nil

        while not startPos do
            local hit, entityHit, endCoords = RayCast(511, 4, rayCastDistance)

            if IsControlPressed(0, 186) then
                lib.hideTextUI(); DeleteObject(tempObject); placingSeed = false; return
            end

            local onMyPlot, hovPlotId = false, nil
            if hit then
                onMyPlot, hovPlotId = exports[Config.Resource]:isInsideMyPlot(endCoords)
            end

            if hit then
                SetEntityCoords(tempObject, endCoords.x, endCoords.y, endCoords.z + zOffset)
                SetEntityAlpha(tempObject, onMyPlot and 220 or 80, true)
            end

            if IsControlPressed(0, 38) and hit then
                if not onMyPlot then
                    utils.notify(Locales['notify_title_farming'],
                        Locales['plot_aim_at_box'] or 'Aim at your farm plot box!', 'error', 3000)
                    Wait(300)
                else
                    startPos    = endCoords
                    startPlotId = hovPlotId
                    Wait(200)
                end
            end
            Wait(0)
        end

        -- ── Pilih titik END & tanam ────────────────────────────
        lib.showTextUI(Locales['row_plant_end'] or '[E] Aim at plot box - Set End & Plant / [X] Cancel', {
            position = 'left-center', icon = 'fas fa-seedling', style = { borderRadius = 10 }
        })

        local rowObjects = { tempObject }

        while true do
            local hit, entityHit, endCoords = RayCast(511, 4, rayCastDistance)

            if IsControlPressed(0, 186) then
                lib.hideTextUI()
                for _, obj in ipairs(rowObjects) do DeleteObject(obj) end
                placingSeed = false; return
            end

            local onMyPlot = false
            local endPlotId = nil
            if hit then
                onMyPlot, endPlotId = exports[Config.Resource]:isInsideMyPlot(endCoords)
                -- Harus dalam plot yang sama dengan start
                if endPlotId ~= startPlotId then onMyPlot = false end
            end

            if hit then
                local positions = calculateRowPositions(startPos, endCoords, Config.MinPlantDistance)

                -- Hapus preview lama
                for i = 2, #rowObjects do DeleteObject(rowObjects[i]) end
                rowObjects = { tempObject }

                -- Spawn preview baru
                for i = 2, #positions do
                    local alpha = onMyPlot and 200 or 60
                    local obj   = CreateObject(ModelHash, positions[i].x, positions[i].y, positions[i].z + zOffset, false, false, false)
                    SetEntityCollision(obj, false, false)
                    SetEntityAlpha(obj, alpha, true)
                    table.insert(rowObjects, obj)
                end
                SetEntityAlpha(tempObject, onMyPlot and 200 or 60, true)

                if IsControlPressed(0, 38) then
                    if not onMyPlot then
                        utils.notify(Locales['notify_title_farming'],
                            Locales['plot_aim_at_box'] or 'Aim at your farm plot box!', 'error', 3000)
                        Wait(300)
                    else
                        local positions2 = calculateRowPositions(startPos, endCoords, Config.MinPlantDistance)
                        local seedsNeeded = #positions2

                        if not client.hasItems(plantConfig.seed, seedsNeeded) then
                            utils.notify(Locales['notify_title_farming'],
                                string.format('You need %d seeds!', seedsNeeded), 'error', 3000)
                            Wait(200)
                        else
                            lib.hideTextUI()
                            for _, obj in ipairs(rowObjects) do DeleteObject(obj) end

                            local ped = cache.ped
                            lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
                            lib.playAnim(ped, 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, 8.0, -1, 48, 0, false, false, false)

                            if lib.progressBar({
                                duration = 2000 * seedsNeeded,
                                label    = string.format('Planting %d seeds...', seedsNeeded),
                                useWhileDead = false, canCancel = true,
                                disable  = { car = true, move = true, combat = true, mouse = false },
                            }) then
                                for _, pos in ipairs(positions2) do
                                    plantSeedAtLocation(pos, plantType, true)
                                end
                                ClearPedTasks(ped)
                                placingSeed = false
                                utils.notify(Locales['notify_title_farming'],
                                    string.format('Planted %d seeds in a row!', seedsNeeded), 'success', 3000)
                                return
                            else
                                ClearPedTasks(ped)
                                placingSeed = false
                                utils.notify(Locales['notify_title_farming'], Locales['canceled'], 'error', 3000)
                                return
                            end
                        end
                    end
                end
            end
            Wait(0)
        end
    else
        -- Single plant mode
        -- Raycast harus kena PROP BOX plot milik sendiri, bukan ground
        lib.showTextUI(Locales['place_or_cancel'] or '[E] - Place Seed / [X] - Cancel', {
            position = 'left-center',
            icon = 'fas fa-seedling',
            style = { borderRadius = 10 }
        })

        local ModelHash = plantConfig.props[1]
        local zOffset   = plantConfig.stageZOffset[1] or 0.0

        lib.requestModel(ModelHash)
        local plant = CreateObject(ModelHash, 0, 0, 0, false, false, false)
        SetModelAsNoLongerNeeded(ModelHash)
        SetEntityCollision(plant, false, false)
        SetEntityAlpha(plant, 200, true)

        while not seedPlaced do
            local hit, entityHit, endCoords, _, _ = RayCast(511, 4, rayCastDistance)

            if IsControlPressed(0, 186) then -- [X] Cancel
                lib.hideTextUI()
                seedPlaced    = false
                placingSeed   = false
                currentPlantType = nil
                DeleteObject(plant)
                return
            end

            if hit then
                -- Cek apakah coords berada dalam radius plot milik sendiri
                local onMyPlot, plotId = exports[Config.Resource]:isInsideMyPlot(endCoords)

                -- Preview: tampilkan di atas prop jika valid, merah jika tidak
                if onMyPlot then
                    SetEntityCoords(plant, endCoords.x, endCoords.y, endCoords.z + zOffset)
                    SetEntityAlpha(plant, 220, true)
                else
                    SetEntityCoords(plant, endCoords.x, endCoords.y, endCoords.z + zOffset)
                    SetEntityAlpha(plant, 80, true)
                end

                if IsControlPressed(0, 38) then -- [E] Place
                    if not onMyPlot then
                        utils.notify(
                            Locales['notify_title_farming'],
                            Locales['plot_aim_at_box'] or 'Aim at your farm plot box to plant!',
                            'error', 3000
                        )
                        Wait(300)
                    else
                        local tooClose, distance = isPlantTooClose(endCoords)
                        if tooClose then
                            utils.notify(
                                Locales['notify_title_farming'],
                                string.format(
                                    Locales['plant_too_close'] or 'Too close! (%.1fm, min: %.1fm)',
                                    distance, Config.MinPlantDistance
                                ),
                                'error', 3000
                            )
                            Wait(200)
                        else
                            seedPlaced = true
                            lib.hideTextUI()
                            DeleteObject(plant)

                            if plantSeedAtLocation(endCoords, plantType, false) then
                                placingSeed      = false
                                currentPlantType = nil
                                return
                            else
                                placingSeed      = false
                                currentPlantType = nil
                                return
                            end
                        end
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