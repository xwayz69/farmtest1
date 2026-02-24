--- Plot System - Client
--- Semua player bisa LIHAT plot (prop box + marker)
--- Hanya OWNER yang bisa interact (tanam, siram, upgrade, remove)

print('^3[MaximGM-Farming]^7 Loading Plot Client module...')

-- id -> { id, owner, coords, tier }
local AllPlots     = {}
-- id -> entity handle prop box
local PlotObjects  = {}
-- id -> bool, kontrol draw loop per plot
local PlotMarkers  = {}
-- identifier player ini (diisi saat load)
local MyIdentifier = nil

local RayCast         = lib.raycast.cam
local rayCastDistance = Config.rayCastingDistance
local placingPlot     = false

-- =============================================
-- Internal Helpers
-- =============================================

local function isOwner(plotId)
    if not MyIdentifier then return false end
    local plot = AllPlots[plotId]
    if not plot then return false end
    return plot.owner == MyIdentifier
end

-- =============================================
-- Visual - Prop Box
-- =============================================

local function spawnPlotProp(id, coords, tier)
    -- Hapus prop lama
    if PlotObjects[id] and DoesEntityExist(PlotObjects[id]) then
        SetEntityAsMissionEntity(PlotObjects[id], false, true)
        DeleteEntity(PlotObjects[id])
        PlotObjects[id] = nil
    end

    local tierConfig = Config.Plots.tiers[tier]
    if not tierConfig then return end

    local model    = tierConfig.prop
    local zOffset  = tierConfig.propZOffset or 0.0

    lib.requestModel(model)
    local obj = CreateObjectNoOffset(
        model,
        coords.x, coords.y, coords.z + zOffset,
        false, false, false
    )
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)

    PlotObjects[id] = obj
    return obj
end

local function removePlotVisual(id)
    -- Stop draw loop
    PlotMarkers[id] = false

    if PlotObjects[id] and DoesEntityExist(PlotObjects[id]) then
        SetEntityAsMissionEntity(PlotObjects[id], false, true)
        DeleteEntity(PlotObjects[id])
        PlotObjects[id] = nil
    end
end

-- Ground circle marker draw loop
local function startDrawLoop(id, coords, tier)
    PlotMarkers[id] = true

    CreateThread(function()
        local tierConfig = Config.Plots.tiers[tier]
        if not tierConfig then return end

        local radius = tierConfig.radius
        local r      = tierConfig.color.r
        local g      = tierConfig.color.g
        local b      = tierConfig.color.b

        while PlotMarkers[id] do
            local alpha = isOwner(id) and 70 or 35 -- owner lebih terang

            DrawMarker(
                1,
                coords.x, coords.y, coords.z + 0.05,
                0, 0, 0,
                0, 0, 0,
                radius * 2, radius * 2, 0.3,
                r, g, b, alpha,
                false, false, 2, false, nil, nil, false
            )
            Wait(0)
        end
    end)
end

-- =============================================
-- ox_target - Semua player lihat, aksi dibatasi owner
-- =============================================

local function registerPlotTarget(id, entityHandle)
    if not entityHandle or not DoesEntityExist(entityHandle) then return end
    if Config.Target ~= 'ox_target' then return end

    exports['ox_target']:addLocalEntity(entityHandle, {
        -- Info - semua player bisa lihat
        {
            name     = 'maximgm_plot_info_' .. id,
            label    = Locales['plot_check'] or 'Check Plot',
            icon     = 'fas fa-info-circle',
            distance = 2.5,
            onSelect = function()
                TriggerEvent('maximgm-farming:client:Plot:OpenMenu', id)
            end,
        },
        -- Upgrade - hanya owner
        {
            name      = 'maximgm_plot_upgrade_' .. id,
            label     = Locales['plot_upgrade'] or 'Upgrade Plot',
            icon      = 'fas fa-arrow-circle-up',
            distance  = 2.5,
            canInteract = function()
                return isOwner(id)
            end,
            onSelect  = function()
                TriggerEvent('maximgm-farming:client:Plot:Upgrade', id)
            end,
        },
        -- Remove - hanya owner
        {
            name      = 'maximgm_plot_remove_' .. id,
            label     = Locales['plot_remove'] or 'Remove Plot',
            icon      = 'fas fa-trash',
            distance  = 2.5,
            canInteract = function()
                return isOwner(id)
            end,
            onSelect  = function()
                TriggerEvent('maximgm-farming:client:Plot:Remove', id)
            end,
        },
    })
end

-- =============================================
-- Add/Remove Plot (dipanggil dari load & network event)
-- =============================================

local function addPlot(id, owner, coords, tier)
    AllPlots[id] = { id = id, owner = owner, coords = coords, tier = tier }

    local obj = spawnPlotProp(id, coords, tier)
    startDrawLoop(id, coords, tier)
    registerPlotTarget(id, obj)
end

local function removePlot(id)
    AllPlots[id] = nil
    removePlotVisual(id)
end

-- =============================================
-- Plot Placement via Raycast
-- Nanam di atas box → preview pakai prop yang sama + z-offset
-- =============================================

local function startPlotPlacement()
    if placingPlot then return end
    if cache.vehicle then return end

    if not client.hasItems(Config.Plots.plotItem, 1) then
        utils.notify(
            Locales['notify_title_farming'],
            Locales['plot_no_item'] or "You don't have a farm plot item!",
            'error', 3000)
        return
    end

    placingPlot = true

    local tierConfig = Config.Plots.tiers[1]
    local radius     = tierConfig.radius

    lib.showTextUI(
        Locales['plot_place_hint'] or '[E] - Place Plot / [X] - Cancel',
        { position = 'left-center', icon = 'fas fa-seedling', style = { borderRadius = 10 } }
    )

    -- Preview: spawn prop box yang sama
    local previewModel = tierConfig.prop
    lib.requestModel(previewModel)
    local previewObj = CreateObjectNoOffset(previewModel, 0, 0, 0, false, false, false)
    SetModelAsNoLongerNeeded(previewModel)
    SetEntityCollision(previewObj, false, false)
    SetEntityAlpha(previewObj, 150, false)

    local validPlacement = false
    local previewCoords  = vector3(0, 0, 0)
    local drawPreview    = true

    -- Draw circle preview loop
    CreateThread(function()
        while drawPreview do
            local r = validPlacement and 0   or 255
            local g = validPlacement and 255 or 0
            DrawMarker(1,
                previewCoords.x, previewCoords.y, previewCoords.z + 0.05,
                0,0,0, 0,0,0,
                radius * 2, radius * 2, 0.3,
                r, g, 0, 70,
                false, false, 2, false, nil, nil, false)
            Wait(0)
        end
    end)

    -- Raycast loop
    CreateThread(function()
        local hit, endCoords, materialHash

        while placingPlot do
            hit, _, endCoords, _, materialHash = RayCast(511, 4, rayCastDistance)

            if hit then
                previewCoords  = endCoords
                validPlacement = Config.GroundHashes[materialHash] ~= nil
                SetEntityCoords(previewObj,
                    endCoords.x,
                    endCoords.y,
                    endCoords.z + (tierConfig.propZOffset or 0.0))
            end

            -- [X] Cancel
            if IsControlJustPressed(0, 186) then break end

            -- [E] Place
            if IsControlJustPressed(0, 38) and hit then
                if not validPlacement then
                    utils.notify(Locales['notify_title_farming'],
                        Locales['cannot_plant_here'] or 'Cannot place here!', 'error', 2000)

                elseif Config.FarmingZones and #Config.FarmingZones > 0 and not _G.InsideZone then
                    utils.notify(Locales['notify_title_farming'],
                        Locales['not_in_farming_zone'] or 'Must be in a farming zone!', 'error', 3000)
                else
                    drawPreview = false
                    lib.hideTextUI()
                    if DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
                    placingPlot = false
                    TriggerServerEvent('maximgm-farming:server:Plot:Place', previewCoords)
                    return
                end
            end

            Wait(0)
        end

        -- Cancelled
        drawPreview = false
        lib.hideTextUI()
        if DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
        placingPlot = false
    end)
end

-- =============================================
-- Plot Menu
-- Semua player bisa buka, tapi isi berbeda
-- =============================================

RegisterNetEvent('maximgm-farming:client:Plot:OpenMenu', function(plotId)
    local plot = AllPlots[plotId]
    if not plot then return end

    local tierConfig = Config.Plots.tiers[plot.tier]
    if not tierConfig then return end

    local isMine = isOwner(plotId)

    -- Hitung tanaman di plot ini (client-side estimate)
    local plantCount = 0
    if _G.PlantClass and _G.PlantClass.PlantCache then
        for _, plantData in pairs(_G.PlantClass.PlantCache) do
            if plantData and plantData.coords then
                local dist = #(plot.coords - plantData.coords)
                if dist <= tierConfig.radius then
                    plantCount = plantCount + 1
                end
            end
        end
    end

    local ownerLabel = isMine and '(Your Plot)' or '(Not your plot)'

    local options = {
        {
            title    = string.format('%s %s', tierConfig.name, ownerLabel),
            description = string.format(
                'Plants: %d/%d  |  Radius: %.0fm',
                plantCount, tierConfig.maxPlants, tierConfig.radius
            ),
            icon     = 'fas fa-seedling',
            disabled = true,
        },
    }

    if isMine then
        -- Upgrade
        if tierConfig.upgradeItem and Config.Plots.tiers[plot.tier + 1] then
            local nextTier = Config.Plots.tiers[plot.tier + 1]
            options[#options + 1] = {
                title       = string.format('Upgrade → %s', nextTier.name),
                description = string.format('Requires: %s  |  Max plants: %d', tierConfig.upgradeItem, nextTier.maxPlants),
                icon        = 'fas fa-arrow-circle-up',
                event       = 'maximgm-farming:client:Plot:Upgrade',
                args        = plotId,
            }
        else
            options[#options + 1] = {
                title    = Locales['plot_max_tier'] or '★ Max Tier',
                icon     = 'fas fa-star',
                disabled = true,
            }
        end

        -- Remove
        options[#options + 1] = {
            title       = Locales['plot_remove'] or 'Remove Plot',
            description = Locales['plot_remove_desc'] or 'Remove all plants first. Item will be returned.',
            icon        = 'fas fa-trash',
            event       = 'maximgm-farming:client:Plot:Remove',
            args        = plotId,
        }
    else
        -- Bukan owner: tampilkan info saja
        options[#options + 1] = {
            title    = 'This plot belongs to someone else.',
            icon     = 'fas fa-lock',
            disabled = true,
        }
    end

    lib.registerContext({
        id      = 'maximgm_plot_menu_' .. plotId,
        title   = Locales['plot_header'] or 'Farm Plot',
        options = options,
    })
    lib.showContext('maximgm_plot_menu_' .. plotId)
end)

-- =============================================
-- Upgrade (owner only)
-- =============================================

RegisterNetEvent('maximgm-farming:client:Plot:Upgrade', function(plotId)
    if not isOwner(plotId) then return end

    local plot = AllPlots[plotId]
    if not plot then return end

    local tierConfig = Config.Plots.tiers[plot.tier]
    if not tierConfig or not tierConfig.upgradeItem then
        utils.notify(Locales['notify_title_farming'],
            Locales['plot_max_tier'] or 'Already max tier!', 'error', 3000)
        return
    end

    if not client.hasItems(tierConfig.upgradeItem, 1) then
        utils.notify(Locales['notify_title_farming'],
            string.format(Locales['plot_no_upgrade_item'] or 'You need %s!', tierConfig.upgradeItem),
            'error', 3000)
        return
    end

    local ped = cache.ped
    lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)

    if lib.progressBar({
        duration = 5000, label = Locales['plot_upgrading'] or 'Upgrading plot...',
        useWhileDead = false, canCancel = true,
        disable = { car = true, move = true, combat = true, mouse = false },
    }) then
        TriggerServerEvent('maximgm-farming:server:Plot:Upgrade', plotId)
        ClearPedTasks(ped)
    else
        ClearPedTasks(ped)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'] or 'Canceled.', 'error', 2000)
    end
end)

-- =============================================
-- Remove (owner only)
-- =============================================

RegisterNetEvent('maximgm-farming:client:Plot:Remove', function(plotId)
    if not isOwner(plotId) then return end

    local plot = AllPlots[plotId]
    if not plot then return end

    local ped = cache.ped
    lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)

    if lib.progressBar({
        duration = 4000, label = Locales['plot_removing'] or 'Removing plot...',
        useWhileDead = false, canCancel = true,
        disable = { car = true, move = true, combat = true, mouse = false },
    }) then
        TriggerServerEvent('maximgm-farming:server:Plot:Remove', plotId)
        ClearPedTasks(ped)
    else
        ClearPedTasks(ped)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'] or 'Canceled.', 'error', 2000)
    end
end)

-- =============================================
-- Network Events dari Server
-- =============================================

-- Plot baru → broadcast ke semua player
RegisterNetEvent('maximgm-farming:client:Plot:New', function(id, owner, coords, tier)
    addPlot(id, owner, coords, tier)
    -- Notify hanya ke owner
    if MyIdentifier and owner == MyIdentifier then
        utils.notify(Locales['notify_title_farming'],
            Locales['plot_placed'] or 'Farm plot placed!', 'success', 3000)
    end
end)

-- Plot dihapus → broadcast ke semua player
RegisterNetEvent('maximgm-farming:client:Plot:Remove', function(id)
    removePlot(id)
end)

-- Tier update → broadcast ke semua player
RegisterNetEvent('maximgm-farming:client:Plot:UpdateTier', function(id, newTier)
    local plot = AllPlots[id]
    if not plot then return end

    plot.tier   = newTier
    AllPlots[id] = plot

    -- Refresh visual
    removePlotVisual(id)
    local obj = spawnPlotProp(id, plot.coords, newTier)
    startDrawLoop(id, plot.coords, newTier)
    registerPlotTarget(id, obj)

    -- Notify hanya ke owner
    if MyIdentifier and plot.owner == MyIdentifier then
        local tierConfig = Config.Plots.tiers[newTier]
        utils.notify(Locales['notify_title_farming'],
            string.format(Locales['plot_upgraded'] or 'Upgraded to %s!',
                tierConfig and tierConfig.name or 'Tier ' .. newTier),
            'success', 4000)
    end
end)

-- =============================================
-- Load semua plot saat join
-- =============================================

CreateThread(function()
    Wait(3000)

    -- Ambil identifier sendiri dulu
    MyIdentifier = lib.callback.await('maximgm-farming:server:Plot:GetMyIdentifier', 5000)
    if MyIdentifier then
        print('^2[MaximGM-Farming]^7 My identifier: ' .. MyIdentifier)
    end

    -- Ambil SEMUA plot (untuk render prop semua orang)
    local result = lib.callback.await('maximgm-farming:server:Plot:GetAll', 5000)

    if result then
        local count = 0
        for id, data in pairs(result) do
            if data and data.coords then
                addPlot(id, data.owner, data.coords, data.tier)
                count = count + 1
            end
        end
        print(string.format('^2[MaximGM-Farming]^7 Loaded %d plot(s)', count))
    end
end)

-- =============================================
-- Export: cek apakah entity adalah prop plot milik sendiri
-- Return plotId jika ya, nil jika bukan
exports('getPlotIdByProp', function(entityHandle)
    if not entityHandle then return nil end
    if not MyIdentifier then return nil end
    for id, plot in pairs(AllPlots) do
        if plot.owner == MyIdentifier then
            if PlotObjects[id] and PlotObjects[id] == entityHandle then
                return id
            end
        end
    end
    return nil
end)

-- Export: cek apakah coords ada di dalam plot MILIK SENDIRI
-- Dipakai planting.lua sebelum trigger server
-- =============================================

exports('isInsideMyPlot', function(coords)
    if not coords or not MyIdentifier then return false, nil end
    for id, plot in pairs(AllPlots) do
        if plot.owner == MyIdentifier then
            local tierConfig = Config.Plots.tiers[plot.tier]
            if tierConfig then
                local dist = #(coords - plot.coords)
                if dist <= tierConfig.radius then
                    return true, id
                end
            end
        end
    end
    return false, nil
end)

-- =============================================
-- Export usePlot (trigger dari ox_inventory item)
-- =============================================

exports('usePlot', function()
    startPlotPlacement()
end)

-- =============================================
-- Cleanup
-- =============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= Config.Resource then return end
    for id, _ in pairs(AllPlots) do
        removePlotVisual(id)
    end
end)

_G.PlotSystem = {
    AllPlots       = AllPlots,
    isOwner        = isOwner,
    startPlacement = startPlotPlacement,
}

print('^2[MaximGM-Farming]^7 Plot Client loaded!')