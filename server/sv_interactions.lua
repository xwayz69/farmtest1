--- Plant Interactions Module - Server Side
--- Handles check plant menu, showing health status, water, fertilizer info
--- Life System: shows Healthy / Dying / Dead status with color schemes

--- Check Plant Menu
RegisterNetEvent('maximgm-farming:client:CheckPlant', function(data)
    -- ✅ SERVER JOB CHECK
    if not jobGuard(source) then return end

    local plantData = _G.PlantClass.PlantCache[data.entity]
    if not plantData then return end

    local success, result = lib.callback.await('maximgm-farming:server:GetPlantData', 200, plantData.id)
    if not success then return end

    local options = {}

    -- Header dengan owner name
    local headerTitle = Locales['plant_header'] .. ' (' .. result.plantType .. ')'
    if result.ownerName then
        headerTitle = headerTitle .. ' - Owner: ' .. result.ownerName
    end

    -- ✅ Tentukan status health + emoji + warna
    local healthStatus      = ''
    local healthColorScheme = 'green'
    local cfg               = Config.PlantHealth

    if result.health > cfg.HealthyThreshold then
        healthStatus      = ' 🟢 ' .. (Locales['plant_status_healthy'] or 'Healthy')
        healthColorScheme = 'green'
    elseif result.health > cfg.DyingThreshold then
        healthStatus      = ' 🟡 ' .. (Locales['plant_status_dying'] or 'Dying!')
        healthColorScheme = 'yellow'
    else
        healthStatus      = ' 🔴 ' .. (Locales['plant_status_dead'] or 'Dead!')
        healthColorScheme = 'red'
    end

    -- ✅ Peringatan untuk tanaman yang butuh perhatian
    local waterStatus = ''
    if result.water < cfg.DyingThreshold then
        waterStatus = ' ⚠️'
    end

    local fertStatus = ''
    if result.fertilizer < cfg.DyingThreshold then
        fertStatus = ' ⚠️'
    end

    if result.health == 0 then
        -- ── DEAD PLANT ──────────────────────────────────────────
        if result.isOwner then
            options = {
                {
                    title       = '🔴 ' .. (Locales['clear_plant_header'] or 'Clear Plant'),
                    description = Locales['clear_plant_text'] or 'The plant is dead..',
                    icon        = 'fas fa-skull-crossbones',
                    event       = 'maximgm-farming:client:ClearPlant',
                    args        = data.entity
                }
            }
        else
            options = {
                {
                    title       = Locales['plant_dead'] or 'Plant is Dead',
                    description = Locales['not_plant_owner'] or 'Only the owner can remove this plant',
                    icon        = 'fas fa-lock',
                }
            }
        end

    elseif result.growth == 100 then
        -- ── READY TO HARVEST ────────────────────────────────────
        local fertInfo = ''
        if result.totalFertilizer > 0 then
            fertInfo = string.format(' | +%d%% bonus', result.fertilizerBonus)
        end

        options[#options + 1] = {
            title       = 'Health: ' .. result.health .. '%' .. healthStatus .. ' | Stage: ' .. result.stage,
            description = 'Growth: ' .. result.growth .. '% — Ready!' .. fertInfo,
            progress    = result.growth,
            colorScheme = healthColorScheme,
            icon        = 'fas fa-chart-simple',
            disabled    = true,
        }

        if result.isOwner then
            options[#options + 1] = {
                title       = '🌾 ' .. (Locales['harvesting_plant'] or 'Harvest Plant'),
                description = string.format('Base: %d items%s', result.growth, fertInfo),
                icon        = 'fas fa-scissors',
                event       = 'maximgm-farming:client:HarvestPlant',
                args        = data.entity
            }
        else
            options[#options + 1] = {
                title       = Locales['ready_for_harvest'] or 'Ready to Harvest',
                description = Locales['not_plant_owner'] or 'Only the owner can harvest this plant',
                icon        = 'fas fa-lock',
            }
        end

    else
        -- ── GROWING ─────────────────────────────────────────────

        -- ✅ Health bar dengan status
        options[#options + 1] = {
            title       = 'Health: ' .. result.health .. '%' .. healthStatus .. ' | Stage: ' .. result.stage,
            description = 'Growth: ' .. result.growth .. '%',
            progress    = result.health,
            colorScheme = healthColorScheme,
            icon        = 'fas fa-heart-pulse',
            disabled    = true,
        }

        -- Growth bar
        options[#options + 1] = {
            title       = 'Growth: ' .. result.growth .. '%',
            description = 'Stage ' .. result.stage .. ' / 5',
            progress    = result.growth,
            colorScheme = 'green',
            icon        = 'fas fa-chart-simple',
            disabled    = true,
        }

        if result.isOwner then
            -- ✅ Water bar dengan warning kalau mau habis
            local waterColorScheme = result.water > 50 and 'cyan' or result.water > 25 and 'yellow' or 'red'
            options[#options + 1] = {
                title       = 'Water: ' .. result.water .. '%' .. waterStatus,
                description = result.water < cfg.WaterThreshold
                    and '⚠️ ' .. (Locales['plant_water_low'] or 'Water is too low! Plant health is decaying!')
                    or Locales['add_water'] or 'Add water to this plant',
                progress    = result.water,
                colorScheme = waterColorScheme,
                icon        = 'fas fa-droplet',
                event       = 'maximgm-farming:client:GiveWater',
                args        = data.entity
            }

            -- ✅ Fertilizer bar dengan warning
            local fertColorScheme = result.fertilizer > 50 and 'yellow' or result.fertilizer > 25 and 'orange' or 'red'
            options[#options + 1] = {
                title       = 'Fertilizer: ' .. result.fertilizer .. '% (Used: ' .. result.totalFertilizer .. 'x)' .. fertStatus,
                description = result.fertilizer < cfg.FertilizerThreshold
                    and '⚠️ ' .. (Locales['plant_fertilizer_low'] or 'Fertilizer too low! Plant health is decaying!')
                    or string.format('%s | +%d%% harvest bonus', Locales['add_fertilizer'] or 'Add fertilizer', result.fertilizerBonus),
                progress    = result.fertilizer,
                colorScheme = fertColorScheme,
                icon        = 'fas fa-flask',
                event       = 'maximgm-farming:client:GiveFertilizer',
                args        = data.entity
            }

            -- ✅ Tips section - tampilkan apa yang perlu dilakukan
            local tipText = ''
            if result.water < cfg.WaterThreshold and result.fertilizer < cfg.FertilizerThreshold then
                tipText = Locales['plant_tip_both'] or '💡 Tip: Water AND fertilize to stop health decay!'
            elseif result.water < cfg.WaterThreshold then
                tipText = Locales['plant_tip_water'] or '💡 Tip: Water your plant to stop health decay!'
            elseif result.fertilizer < cfg.FertilizerThreshold then
                tipText = Locales['plant_tip_fertilizer'] or '💡 Tip: Fertilize your plant to stop health decay!'
            end

            if tipText ~= '' then
                options[#options + 1] = {
                    title       = tipText,
                    icon        = 'fas fa-lightbulb',
                    colorScheme = 'orange',
                    disabled    = true,
                }
            end

        else
            -- Non-owner: tampilkan info tapi tidak bisa interact
            options[#options + 1] = {
                title       = 'Water: ' .. result.water .. '%',
                description = 'Only owner can interact',
                progress    = result.water,
                colorScheme = 'cyan',
                icon        = 'fas fa-lock',
                disabled    = true,
            }

            options[#options + 1] = {
                title       = 'Fertilizer: ' .. result.fertilizer .. '%',
                description = 'Only owner can interact',
                progress    = result.fertilizer,
                colorScheme = 'yellow',
                icon        = 'fas fa-lock',
                disabled    = true,
            }
        end
    end

    lib.registerContext({
        id      = 'maximgm_plant_menu_' .. data.entity,
        title   = headerTitle,
        options = options,
    })
    lib.showContext('maximgm_plant_menu_' .. data.entity)
end)

--- Give Water
RegisterNetEvent('maximgm-farming:client:GiveWater', function(entity)
    if not jobGuard(source) then return end
    local plantData = _G.PlantClass.PlantCache[entity]
    if not plantData then return end

    local plantConfig = Config.Plants[plantData.type]
    if not plantConfig then return end

    if not client.hasItems(plantConfig.water, 1) then
        return utils.notify(Locales['notify_title_farming'], Locales['missing_water'], 'error', 3000)
    end

    local ped    = cache.ped
    local coords = GetEntityCoords(ped)
    local model  = joaat('prop_watering_can')

    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(500)

    lib.requestModel(model)
    local created_object = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    SetModelAsNoLongerNeeded(model)
    AttachEntityToEntity(created_object, ped, GetPedBoneIndex(ped, 28422), 0.12, 0.04, 0.02, 20.0, 175.0, 80.0, true, true, false, true, 1, true)

    local ptfxDict = 'core'
    RequestNamedPtfxAsset(ptfxDict)
    while not HasNamedPtfxAssetLoaded(ptfxDict) do Wait(0) end

    UseParticleFxAssetNextCall(ptfxDict)
    local effect = StartParticleFxLoopedOnEntity('ent_amb_jet_ml_1', entity, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.25, false, false, false)

    if lib.progressBar({
        duration     = 5000,
        label        = Locales['watering_plant'] or 'Watering Plant..',
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true, mouse = false },
        anim         = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flags = 1 },
    }) then
        DeleteEntity(created_object)
        StopParticleFxLooped(effect, 0)
        RemoveNamedPtfxAsset(ptfxDict)
        TriggerServerEvent('maximgm-farming:server:GiveWater', plantData.id)
    else
        DeleteEntity(created_object)
        StopParticleFxLooped(effect, 0)
        RemoveNamedPtfxAsset(ptfxDict)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'], 'error', 3000)
    end
end)

--- Give Fertilizer
RegisterNetEvent('maximgm-farming:client:GiveFertilizer', function(entity)
    if not jobGuard(source) then return end
    local plantData = _G.PlantClass.PlantCache[entity]
    if not plantData then return end

    local plantConfig = Config.Plants[plantData.type]
    if not plantConfig then return end

    if not client.hasItems(plantConfig.fertilizer, 1) then
        return utils.notify(Locales['notify_title_farming'], Locales['missing_fertilizer'], 'error', 3000)
    end

    local ped    = cache.ped
    local coords = GetEntityCoords(ped)
    local model  = joaat('w_am_jerrycan_sf')

    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(500)

    lib.requestModel(model)
    local created_object = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    SetModelAsNoLongerNeeded(model)
    AttachEntityToEntity(created_object, ped, GetPedBoneIndex(ped, 28422), 0.3, 0.1, 0.0, 90.0, 180.0, 0.0, true, true, false, true, 1, true)

    if lib.progressBar({
        duration     = 6000,
        label        = Locales['fertilizing_plant'] or 'Adding fertilizer..',
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true, mouse = false },
        anim         = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flags = 1 },
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