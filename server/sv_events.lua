--- Server Events Handler
--- Handles all plant-related events

--- Create New Plant Event
RegisterNetEvent('maximgm-farming:server:CreateNewPlant', function(coords, plantType)
    if not _G.Plant then
        print('^1[MaximGM-Farming] ERROR: Plant class not loaded!^7')
        return
    end

    local src = source
    local Player = server.GetPlayerFromId(src)
    if not Player then return end

    local PlayerData = server.getPlayerData(Player)

    if not coords or type(coords) ~= "vector3" then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.rayCastingDistance + 10 then return end

    local plantConfig = Config.Plants[plantType]
    if not plantConfig then return end

    -- ================================================
    -- PLOT VALIDATION
    -- Cek XY saja (ignore Z) karena tanaman di atas box lebih tinggi dari plot coords
    -- ================================================
    if not _G.Plot then
        utils.notify(src, Locales['notify_title_farming'], 'Plot system not loaded!', 'error', 3000)
        return
    end

    local identifier = PlayerData.identifier
    local foundPlot  = nil
    local foundTier  = nil

    for _, plot in pairs(_G.PlotCache) do
        if plot.owner == identifier then
            local tierConfig = Config.Plots.tiers[plot.tier]
            if tierConfig then
                -- Cek jarak XY saja (2D), abaikan perbedaan Z karena nanam di atas box
                local dx   = coords.x - plot.coords.x
                local dy   = coords.y - plot.coords.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= tierConfig.radius then
                    foundPlot = plot
                    foundTier = tierConfig
                    break
                end
            end
        end
    end

    if not foundPlot then
        utils.notify(src, Locales['notify_title_farming'],
            Locales['plot_not_in_plot'] or 'You must plant inside your own farm plot!',
            'error', 4000)
        return
    end

    -- Hitung tanaman yang sudah ada di plot ini (XY check juga)
    local plantCount = 0
    if _G.PlantCache then
        for _, plantData in pairs(_G.PlantCache) do
            if plantData and plantData.coords then
                local dx   = plantData.coords.x - foundPlot.coords.x
                local dy   = plantData.coords.y - foundPlot.coords.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= foundTier.radius then
                    plantCount = plantCount + 1
                end
            end
        end
    end

    if plantCount >= foundTier.maxPlants then
        utils.notify(src, Locales['notify_title_farming'],
            Locales['plot_full'] or 'Your plot is full! Upgrade to plant more.',
            'error', 4000)
        return
    end
    -- ================================================

    if server.removeItem(src, plantConfig.seed, 1) then
        _G.Plant:new(coords, plantType, PlayerData.identifier)
        server.createLog(
            PlayerData.name,
            'New Plant',
            PlayerData.name .. ' (identifier: ' .. PlayerData.identifier .. ' | id: ' .. src .. ')' ..
            ' placed new ' .. plantType .. ' plant at ' .. tostring(coords)
        )
    end
end)

--- Clear Plant Event
RegisterNetEvent('maximgm-farming:server:ClearPlant', function(plantId)
    if not _G.Plant then
        print('^1[MaximGM-Farming] ERROR: Plant class not loaded!^7')
        return
    end
    
    local src = source
    local Player = server.GetPlayerFromId(src)
    if not Player then return end

    local PlayerData = server.getPlayerData(Player)

    local plant = _G.Plant:getPlant(plantId)
    if not plant then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - plant.coords) > 10 then return end

    -- Check if player is the owner
    if plant.owner ~= PlayerData.identifier then
        utils.notify(
            src, 
            Locales['notify_title_farming'], 
            Locales['not_plant_owner'] or 'You do not own this plant!', 
            'error', 
            3000
        )
        return
    end

    plant:remove()
    server.createLog(
        PlayerData.name, 
        'Clear Plant', 
        PlayerData.name .. ' (identifier: ' .. PlayerData.identifier .. ' | id: ' .. src .. ')' .. 
        ' cleared plant ' .. plantId
    )
end)

--- Harvest Plant Event
RegisterNetEvent('maximgm-farming:server:HarvestPlant', function(plantId)
    if not _G.Plant then
        print('^1[MaximGM-Farming] ERROR: Plant class not loaded!^7')
        return
    end
    
    local src = source
    local Player = server.GetPlayerFromId(src)
    if not Player then return end

    local PlayerData = server.getPlayerData(Player)

    local plant = _G.Plant:getPlant(plantId)
    if not plant then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - plant.coords) > 10 then return end

    -- Check if player is the owner
    if plant.owner ~= PlayerData.identifier then
        utils.notify(
            src, 
            Locales['notify_title_farming'], 
            Locales['not_plant_owner'] or 'You do not own this plant!', 
            'error', 
            3000
        )
        return
    end

    if plant:calcGrowth() ~= 100 then return end

    local health = plant:calcHealth()
    local plantConfig = Config.Plants[plant.plantType]
    
    if plantConfig then
        -- Calculate harvest amount based on health
        local healthMultiplier = health / 100
        local minAmount = plantConfig.harvestAmount[1]
        local maxAmount = plantConfig.harvestAmount[2]
        local baseHarvest = math.floor((minAmount + (maxAmount - minAmount) * healthMultiplier))
        
        -- Calculate fertilizer bonus
        local totalFertilizer = plant:calcTotalFertilizer()
        local fertilizerBonus = 0
        local finalHarvest = baseHarvest
        
        if totalFertilizer > 0 and plantConfig.fertilizerBonus then
            fertilizerBonus = totalFertilizer * plantConfig.fertilizerBonus
            local bonusMultiplier = 1 + (fertilizerBonus / 100)
            finalHarvest = math.floor(baseHarvest * bonusMultiplier)
        end
        
        server.addItem(src, plantConfig.harvest, math.max(1, finalHarvest))
        
        -- Notify player about bonus
        if fertilizerBonus > 0 then
            utils.notify(
                src, 
                Locales['notify_title_farming'], 
                string.format(
                    Locales['harvest_with_bonus'] or 'Harvested %dx items (+%d%% fertilizer bonus)', 
                    finalHarvest, 
                    fertilizerBonus
                ), 
                'success', 
                5000
            )
        end
        
        server.createLog(
            PlayerData.name, 
            'Harvest Plant', 
            PlayerData.name .. ' (identifier: ' .. PlayerData.identifier .. ' | id: ' .. src .. ')' .. 
            ' harvested plant: ' .. plantId .. 
            ' Type: ' .. plant.plantType .. 
            ' Health: ' .. health .. 
            ' Base Harvest: ' .. baseHarvest .. 
            ' Final Harvest: ' .. finalHarvest .. 
            ' Fertilizer Used: ' .. totalFertilizer .. 
            ' Bonus: ' .. fertilizerBonus .. '%'
        )
    end

    plant:remove()
end)

--- Give Water Event
RegisterNetEvent('maximgm-farming:server:GiveWater', function(plantId)
    if not _G.Plant then
        print('^1[MaximGM-Farming] ERROR: Plant class not loaded!^7')
        return
    end
    
    local src = source
    local Player = server.GetPlayerFromId(src)
    if not Player then return end
    
    local plant = _G.Plant:getPlant(plantId)
    if not plant then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - plant.coords) > 10 then return end

    local plantConfig = Config.Plants[plant.plantType]
    if not plantConfig then return end

    if server.removeItem(src, plantConfig.water, 1) then
        local water = plant.water
        water[#water + 1] = os.time()

        plant:set('water', water)
        local saved = plant:save()

        if not saved then
            utils.print(("Could not save plant with id %s"):format(plantId))
        end

        utils.notify(
            src, 
            Locales['notify_title_farming'], 
            Locales['watered_plant'], 
            'success', 
            2500
        )
    end
end)

--- Give Fertilizer Event
RegisterNetEvent('maximgm-farming:server:GiveFertilizer', function(plantId)
    if not _G.Plant then
        print('^1[MaximGM-Farming] ERROR: Plant class not loaded!^7')
        return
    end
    
    local src = source
    local Player = server.GetPlayerFromId(src)
    if not Player then return end

    local plant = _G.Plant:getPlant(plantId)
    if not plant then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - plant.coords) > 10 then return end

    local plantConfig = Config.Plants[plant.plantType]
    if not plantConfig then return end

    if server.removeItem(src, plantConfig.fertilizer, 1) then
        local fertilizer = plant.fertilizer
        fertilizer[#fertilizer + 1] = os.time()

        plant:set('fertilizer', fertilizer)
        local saved = plant:save()

        if not saved then
            utils.print(("Could not save plant with id %s"):format(plantId))
        end

        local totalFert = #fertilizer
        local bonusPercent = totalFert * plantConfig.fertilizerBonus
        
        utils.notify(
            src, 
            Locales['notify_title_farming'], 
            string.format(
                Locales['fertilizer_added_bonus'] or 'Fertilizer added! Total: %dx (+%d%% harvest bonus)', 
                totalFert, 
                bonusPercent
            ), 
            'success', 
            3500
        )
    end
end)