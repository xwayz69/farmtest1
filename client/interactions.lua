--- Plant Interactions Module
--- Handles plant checking, watering, fertilizing, harvesting, and clearing

--- Check Plant Menu
RegisterNetEvent('maximgm-farming:client:CheckPlant', function(data)
    -- ✅ JOB CHECK
    if not requireJobAccess() then return end

    local plantData = _G.PlantClass.PlantCache[data.entity]
    if not plantData then return end

    local success, result = lib.callback.await('maximgm-farming:server:GetPlantData', 200, plantData.id)
    if not success then
        return
    end

    local options = {}

    -- Header dengan owner name
    local headerTitle = Locales['plant_header'] .. ' (' .. result.plantType .. ')'
    if result.ownerName then
        headerTitle = headerTitle .. ' - Owner: ' .. result.ownerName
    end

    if result.health == 0 then -- Dead plant
        if result.isOwner then
            options = {
                {
                    title = Locales['clear_plant_header'],
                    description = Locales['clear_plant_text'],
                    icon = 'fas fa-skull-crossbones',
                    event = 'maximgm-farming:client:ClearPlant',
                    args = data.entity
                }
            }
        else
            options = {
                {
                    title = Locales['plant_dead'],
                    description = Locales['not_plant_owner'] or 'Only the owner can remove this plant',
                    icon = 'fas fa-lock',
                }
            }
        end
    elseif result.growth == 100 then -- Ready to harvest
        local fertInfo = ''
        if result.totalFertilizer > 0 then
            fertInfo = string.format(' | Fertilizer: %dx (+%d%% bonus)', result.totalFertilizer, result.fertilizerBonus)
        end
        
        if result.isOwner then
            options[#options + 1] = {
                title = 'Health: ' .. result.health .. '%' .. ' - Stage: ' .. result.stage,
                description = 'Growth: ' .. result.growth .. '%' .. fertInfo,
                progress = result.growth,
                colorScheme = 'green',
                icon = 'fas fa-scissors',
                event = 'maximgm-farming:client:HarvestPlant',
                args = data.entity
            }
        else
            options[#options + 1] = {
                title = 'Ready to Harvest',
                description = Locales['not_plant_owner'] or 'Only the owner can harvest this plant',
                icon = 'fas fa-lock',
            }
        end
    else -- Growing
        options[#options + 1] = {
            title = 'Health: ' .. result.health .. '%' .. ' - Stage: ' .. result.stage,
            description = 'Growth: ' .. result.growth .. '%',
            progress = result.growth,
            colorScheme = 'green',
            icon = 'fas fa-chart-simple',
        }

        if result.isOwner then
            options[#options + 1] = {
                title = 'Water: ' .. result.water .. '%',
                description = Locales['add_water'],
                progress = result.water,
                colorScheme = 'cyan',
                icon = 'fas fa-shower',
                event = 'maximgm-farming:client:GiveWater',
                args = data.entity
            }
            
            options[#options + 1] = {
                title = 'Fertilizer: ' .. result.fertilizer .. '%' .. ' (Used: ' .. result.totalFertilizer .. 'x)',
                description = Locales['add_fertilizer'],
                progress = result.fertilizer,
                colorScheme = 'yellow',
                icon = 'fab fa-nutritionix',
                event = 'maximgm-farming:client:GiveFertilizer',
                args = data.entity
            }
        else
            options[#options + 1] = {
                title = 'Water: ' .. result.water .. '%',
                description = 'Only owner can interact',
                progress = result.water,
                colorScheme = 'cyan',
                icon = 'fas fa-lock',
            }
            
            options[#options + 1] = {
                title = 'Fertilizer: ' .. result.fertilizer .. '%',
                description = 'Only owner can interact',
                progress = result.fertilizer,
                colorScheme = 'yellow',
                icon = 'fas fa-lock',
            }
        end
    end
    
    -- Add clear option for owner
    if result.isOwner and result.growth ~= 100 then
        options[#options + 1] = {
            title = Locales['clear_plant_header'],
            description = Locales['clear_plant_desc'] or 'Remove this plant',
            icon = 'fas fa-trash',
            event = 'maximgm-farming:client:ClearPlant',
            args = data.entity
        }
    end
    
    lib.registerContext({
        id = 'maximgm_farming_main',
        title = headerTitle,
        options = options
    })

    lib.showContext('maximgm_farming_main')
end)

--- Clear Plant
RegisterNetEvent('maximgm-farming:client:ClearPlant', function(entity)
    if not requireJobAccess() then return end
    local plantData = _G.PlantClass.PlantCache[entity]
    if not plantData then return end

    local ped = cache.ped

    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(500)

    lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
    lib.playAnim(ped, 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, 8.0, -1, 48, 0, false, false, false)

    if lib.progressBar({
        duration = 8500,
        label = Locales['clear_plant'],
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true, mouse = false },
    }) then
        TriggerServerEvent('maximgm-farming:server:ClearPlant', plantData.id)
        ClearPedTasks(ped)
    else
        ClearPedTasks(ped)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'], 'error', 3000)
    end
end)

--- Harvest Plant
RegisterNetEvent('maximgm-farming:client:HarvestPlant', function(entity)
    if not requireJobAccess() then return end
    local plantData = _G.PlantClass.PlantCache[entity]
    if not plantData then return end

    local ped = cache.ped
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(500)

    lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
    lib.playAnim(ped, 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, 8.0, -1, 48, 0, false, false, false)

    if lib.progressBar({
        duration = 8500,
        label = Locales['harvesting_plant'],
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true, mouse = false },
    }) then
        TriggerServerEvent('maximgm-farming:server:HarvestPlant', plantData.id)
        ClearPedTasks(ped)
    else
        utils.notify(Locales['notify_title_farming'], Locales['canceled'], 'error', 3000)
        ClearPedTasks(ped)
    end
end)

--- Give Water
RegisterNetEvent('maximgm-farming:client:GiveWater', function(entity)
    if not requireJobAccess() then return end
    local plantData = _G.PlantClass.PlantCache[entity]
    if not plantData then return end
    
    local plantConfig = Config.Plants[plantData.type]
    if not plantConfig then return end

    if not client.hasItems(plantConfig.water, 1) then
        return utils.notify(Locales['notify_title_farming'], Locales['missing_water'], 'error', 3000)
    end

    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local model = joaat('prop_wateringcan')

    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(500)

    lib.requestModel(model)
    local created_object = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(created_object, ped, GetPedBoneIndex(ped, 28422), 0.4, 0.1, 0.0, 90.0, 180.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)

    lib.requestNamedPtfxAsset('core')
    UseParticleFxAsset('core')
    local effect = StartParticleFxLoopedOnEntity('ent_sht_water', created_object, 0.35, 0.0, 0.25, 0.0, 0.0, 0.0, 2.0, false, false, false)

    if lib.progressBar({
        duration = 6000,
        label = Locales['watering_plant'],
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true, mouse = false },
        anim = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flags = 1 },
    }) then
        DeleteEntity(created_object)
        StopParticleFxLooped(effect, 0)
        RemoveNamedPtfxAsset('core')
        TriggerServerEvent('maximgm-farming:server:GiveWater', plantData.id)
    else
        DeleteEntity(created_object)
        StopParticleFxLooped(effect, 0)
        RemoveNamedPtfxAsset('core')
        utils.notify(Locales['notify_title_farming'], Locales['canceled'], 'error', 3000)
    end
end)

--- Give Fertilizer
RegisterNetEvent('maximgm-farming:client:GiveFertilizer', function(entity)
    if not requireJobAccess() then return end
    local plantData = _G.PlantClass.PlantCache[entity]
    if not plantData then return end
    
    local plantConfig = Config.Plants[plantData.type]
    if not plantConfig then return end

    if not client.hasItems(plantConfig.fertilizer, 1) then
        return utils.notify(Locales['notify_title_farming'], Locales['missing_fertilizer'], 'error', 3000)
    end

    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local model = joaat('w_am_jerrycan_sf')

    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(500)

    lib.requestModel(model)
    local created_object = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    SetModelAsNoLongerNeeded(model)
    AttachEntityToEntity(created_object, ped, GetPedBoneIndex(ped, 28422), 0.3, 0.1, 0.0, 90.0, 180.0, 0.0, true, true, false, true, 1, true)

    if lib.progressBar({
        duration = 6000,
        label = Locales['fertilizing_plant'],
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true, mouse = false },
        anim = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flags = 1 },
    }) then
        TriggerServerEvent('maximgm-farming:server:GiveFertilizer', plantData.id)
        ClearPedTasks(ped)
        DeleteEntity(created_object)
    else
        ClearPedTasks(ped)
        DeleteEntity(created_object)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'], 'error', 3000)
    end
end)