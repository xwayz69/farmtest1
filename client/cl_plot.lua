--- Plot System - Client (FIXED)
--- ✅ FIX kedip: DrawMarker di thread terpisah, BUKAN di nearby lib.points
--- ✅ FIX arrow: pakai Z/C untuk height, Q/E untuk rotate (key universal)
--- ✅ Proximity: prop & target hanya aktif saat dekat (lib.points)
--- ✅ Marker: thread stabil, tidak flicker

print('^3[MaximGM-Farming]^7 Loading Plot Client module...')

local AllPlots    = {}
local PlotObjects = {}
local PlotPoints  = {}
local PlotMarkerActive = {}  -- [id] = true/false, kontrol draw thread per plot
local MyIdentifier = nil

local RayCast         = lib.raycast.cam
local rayCastDistance = Config.rayCastingDistance
local placingPlot     = false

local PLOT_RENDER_DISTANCE = 60.0   -- Jarak spawn prop
local MARKER_DRAW_DISTANCE = 30.0   -- Jarak gambar lingkaran

-- =============================================
-- Helpers
-- =============================================

local function isOwner(plotId)
    if not MyIdentifier then return false end
    local plot = AllPlots[plotId]
    if not plot then return false end
    return plot.owner == MyIdentifier
end

-- =============================================
-- Prop Management
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

local function despawnPlotProp(id)
    if PlotObjects[id] and DoesEntityExist(PlotObjects[id]) then
        if Config.Target == 'ox_target' then
            exports['ox_target']:removeLocalEntity(PlotObjects[id])
        end
        SetEntityAsMissionEntity(PlotObjects[id], false, true)
        DeleteEntity(PlotObjects[id])
        PlotObjects[id] = nil
    end
end

-- =============================================
-- ox_target
-- =============================================

local function registerPlotTarget(id, entityHandle)
    if not entityHandle or not DoesEntityExist(entityHandle) then return end
    if Config.Target ~= 'ox_target' then return end

    exports['ox_target']:addLocalEntity(entityHandle, {
        {
            name     = 'maximgm_plot_info_' .. id,
            label    = Locales['plot_check'] or 'Check Plot',
            icon     = 'fas fa-info-circle',
            distance = 2.5,
            onSelect = function()
                TriggerEvent('maximgm-farming:client:Plot:OpenMenu', id)
            end,
        },
        {
            name        = 'maximgm_plot_upgrade_' .. id,
            label       = Locales['plot_upgrade'] or 'Upgrade Plot',
            icon        = 'fas fa-arrow-circle-up',
            distance    = 2.5,
            canInteract = function() return isOwner(id) end,
            onSelect    = function()
                TriggerEvent('maximgm-farming:client:Plot:Upgrade', id)
            end,
        },
        {
            name        = 'maximgm_plot_remove_' .. id,
            label       = Locales['plot_remove'] or 'Remove Plot',
            icon        = 'fas fa-trash',
            distance    = 2.5,
            canInteract = function() return isOwner(id) end,
            onSelect    = function()
                TriggerEvent('maximgm-farming:client:Plot:Remove', id)
            end,
        },
    })
end

-- =============================================
-- MARKER DRAW THREAD (STABIL, tidak flicker)
-- ✅ Fix: jangan taruh DrawMarker di nearby lib.points
--    Buat thread terpisah per plot, matikan saat keluar radius
-- =============================================

local function startMarkerThread(id, coords, tier)
    -- Hentikan thread lama kalau ada
    PlotMarkerActive[id] = false
    Wait(20) -- kasih waktu thread lama berhenti

    local tierConfig = Config.Plots.tiers[tier]
    if not tierConfig then return end

    local r      = tierConfig.color.r
    local g      = tierConfig.color.g
    local b      = tierConfig.color.b
    local radius = tierConfig.radius

    PlotMarkerActive[id] = true

    CreateThread(function()
        while PlotMarkerActive[id] do
            -- Cek jarak player ke plot
            local playerCoords = GetEntityCoords(cache.ped)
            local dist         = #(playerCoords - coords)

            if dist <= MARKER_DRAW_DISTANCE then
                local alpha = isOwner(id) and 70 or 35
                DrawMarker(
                    1,
                    coords.x, coords.y, coords.z + 0.05,
                    0, 0, 0,
                    0, 0, 0,
                    radius * 2, radius * 2, 0.3,
                    r, g, b, alpha,
                    false, false, 2, false, nil, nil, false
                )
                Wait(0)   -- Render tiap frame saat dekat
            else
                Wait(500) -- Tidur saat masih dalam RENDER_DISTANCE tapi di luar MARKER_DISTANCE
            end
        end
    end)
end

local function stopMarkerThread(id)
    PlotMarkerActive[id] = false
end

-- =============================================
-- PROXIMITY SYSTEM
-- lib.points: onEnter/onExit untuk spawn/despawn prop
-- nearby DIKOSONGKAN (tidak ada logic di dalamnya)
-- Draw marker dihandle oleh thread terpisah di atas
-- =============================================

local function createPlotPoint(id, coords, tier)
    if PlotPoints[id] then
        PlotPoints[id]:remove()
        PlotPoints[id] = nil
    end

    PlotPoints[id] = lib.points.new({
        coords   = coords,
        distance = PLOT_RENDER_DISTANCE,
        plotId   = id,
        plotTier = tier,

        onEnter = function(self)
            -- Spawn prop
            local obj = spawnPlotProp(self.plotId, coords, self.plotTier)
            if obj then
                registerPlotTarget(self.plotId, obj)
            end
            -- Mulai draw marker (thread stabil)
            startMarkerThread(self.plotId, coords, self.plotTier)
        end,

        onExit = function(self)
            -- Despawn prop & target
            despawnPlotProp(self.plotId)
            -- Hentikan draw marker
            stopMarkerThread(self.plotId)
        end,

        -- ✅ nearby KOSONG - tidak ada DrawMarker di sini!
        -- Kalau nearby diisi Wait(0) + DrawMarker → flicker karena race condition
        nearby = function(self)
            Wait(1000) -- Tidur panjang, tidak ada yang perlu dilakukan di sini
        end,
    })
end

local function removePlotPoint(id)
    stopMarkerThread(id)
    despawnPlotProp(id)
    if PlotPoints[id] then
        PlotPoints[id]:remove()
        PlotPoints[id] = nil
    end
end

-- =============================================
-- Add / Remove Plot
-- =============================================

local function addPlot(id, owner, coords, tier)
    AllPlots[id] = { id = id, owner = owner, coords = coords, tier = tier }
    createPlotPoint(id, coords, tier)
end

local function removePlot(id)
    AllPlots[id] = nil
    removePlotPoint(id)
end

-- =============================================
-- PLACEMENT SYSTEM
-- ✅ FIX arrow: pakai Z (naik) / C (turun), Q (rotate kiri) / E (rotate kanan)
--    Key yang pasti bebas di hampir semua framework FiveM
--    Z = keycode 20, C = keycode 26, Q = keycode 44, E = keycode 38
--    (E juga dipakai untuk [Place] → pakai IsControlJustPressed untuk Place
--     dan IsControlPressed untuk rotate agar tidak bentrok)
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

    -- ✅ Update hint sesuai key yang dipakai
    lib.showTextUI(
        '[E] Place  |  [X] Cancel  |  [Z] Up  |  [C] Down  |  [Q] Rotate Left  |  [R] Rotate Right',
        { position = 'left-center', icon = 'fas fa-seedling', style = { borderRadius = 10 } }
    )

    lib.requestModel(tierConfig.prop)
    local previewObj = CreateObjectNoOffset(tierConfig.prop, 0, 0, 0, false, false, false)
    SetModelAsNoLongerNeeded(tierConfig.prop)
    SetEntityCollision(previewObj, false, false)
    SetEntityAlpha(previewObj, 150, false)

    local validPlacement = false
    local previewCoords  = vector3(0, 0, 0)
    local drawPreview    = true
    local extraZ         = 0.0
    local heading        = 0.0

    -- Thread draw preview marker (stabil, tidak flicker)
    CreateThread(function()
        while drawPreview do
            if previewCoords.x ~= 0 or previewCoords.y ~= 0 then
                local r = validPlacement and 0 or 255
                local g = validPlacement and 255 or 0
                DrawMarker(
                    1,
                    previewCoords.x, previewCoords.y, previewCoords.z + 0.05,
                    0, 0, 0, 0, 0, 0,
                    radius * 2, radius * 2, 0.3,
                    r, g, 0, 70,
                    false, false, 2, false, nil, nil, false
                )
            end
            Wait(0)
        end
    end)

    -- Thread raycast + input
    CreateThread(function()
        local notifCooldown = 0

        while placingPlot do
            local hit, _, endCoords, _, materialHash = RayCast(511, 4, rayCastDistance)

            -- ✅ Z = naik (keycode 20)
            if IsControlPressed(0, 20) then
                extraZ = extraZ + 0.005
            end

            -- ✅ C = turun (keycode 26)
            if IsControlPressed(0, 26) then
                extraZ = extraZ - 0.005
            end

            -- ✅ Q = rotate kiri (keycode 44)
            if IsControlPressed(0, 44) then
                heading = (heading + 1.5) % 360.0
            end

            -- ✅ R = rotate kanan (keycode 45)
            if IsControlPressed(0, 45) then
                heading = (heading - 1.5) % 360.0
            end

            if hit then
                previewCoords  = endCoords
                validPlacement = Config.GroundHashes[materialHash] ~= nil

                SetEntityCoords(previewObj,
                    endCoords.x,
                    endCoords.y,
                    endCoords.z + (tierConfig.propZOffset or 0.0) + extraZ)
                SetEntityHeading(previewObj, heading)
            end

            -- X = cancel
            if IsControlJustPressed(0, 186) then break end

            -- E = place (JustPressed agar tidak bentrok dengan rotate)
            if IsControlJustPressed(0, 38) and hit then
                if not validPlacement then
                    utils.notify(Locales['notify_title_farming'],
                        Locales['cannot_plant_here'] or 'Cannot place here!', 'error', 2000)

                elseif Config.FarmingZones and #Config.FarmingZones > 0 and not _G.InsideZone then
                    utils.notify(Locales['notify_title_farming'],
                        Locales['not_in_farming_zone'] or 'Must be in a farming zone!', 'error', 2000)

                else
                    local tooClose      = false
                    local onOtherPlayer = false

                    for pid, plot in pairs(AllPlots) do
                        local dist = #(endCoords - plot.coords)
                        if dist < Config.Plots.minPlotDistance then
                            tooClose = true
                            if not isOwner(pid) then onOtherPlayer = true end
                            break
                        end
                    end

                    if onOtherPlayer then
                        if GetGameTimer() > notifCooldown then
                            utils.notify(Locales['notify_title_farming'],
                                Locales['plot_placed_on_other'] or "Cannot place near another player's plot!",
                                'error', 2000)
                            notifCooldown = GetGameTimer() + 2500
                        end
                    elseif tooClose then
                        if GetGameTimer() > notifCooldown then
                            utils.notify(Locales['notify_title_farming'],
                                string.format(Locales['plot_too_close'] or 'Too close! (%.1fm min)',
                                    Config.Plots.minPlotDistance),
                                'error', 2000)
                            notifCooldown = GetGameTimer() + 2500
                        end
                    else
                        drawPreview = false
                        lib.hideTextUI()
                        if DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
                        placingPlot = false

                        local finalCoords = vector3(endCoords.x, endCoords.y, endCoords.z + extraZ)
                        TriggerServerEvent('maximgm-farming:server:Plot:Place', finalCoords, heading)
                        return
                    end
                end
            end

            Wait(0)
        end

        -- Dibatalkan
        drawPreview = false
        lib.hideTextUI()
        if DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
        placingPlot = false
    end)
end

-- =============================================
-- Plot Menu
-- =============================================

RegisterNetEvent('maximgm-farming:client:Plot:OpenMenu', function(plotId)
    local plot = AllPlots[plotId]
    if not plot then return end

    local tierConfig = Config.Plots.tiers[plot.tier]
    if not tierConfig then return end

    local isMine     = isOwner(plotId)
    local plantCount = 0

    if _G.PlantClass and _G.PlantClass.PlantCache then
        for _, plantData in pairs(_G.PlantClass.PlantCache) do
            if plantData and plantData.coords then
                if #(plot.coords - plantData.coords) <= tierConfig.radius then
                    plantCount = plantCount + 1
                end
            end
        end
    end

    local options = {
        {
            title       = string.format('%s %s', tierConfig.name, isMine and '(Your Plot)' or '(Not yours)'),
            description = string.format('Plants: %d/%d  |  Radius: %.0fm', plantCount, tierConfig.maxPlants, tierConfig.radius),
            icon        = 'fas fa-seedling',
            disabled    = true,
        },
    }

    if isMine then
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

        options[#options + 1] = {
            title       = Locales['plot_remove'] or 'Remove Plot',
            description = Locales['plot_remove_desc'] or 'Remove all plants first.',
            icon        = 'fas fa-trash',
            event       = 'maximgm-farming:client:Plot:Remove',
            args        = plotId,
        }
    else
        options[#options + 1] = {
            title    = 'This plot belongs to someone else.',
            icon     = 'fas fa-lock',
            disabled = true,
        }
    end

    lib.registerContext({ id = 'maximgm_plot_menu_' .. plotId, title = Locales['plot_header'] or 'Farm Plot', options = options })
    lib.showContext('maximgm_plot_menu_' .. plotId)
end)

-- =============================================
-- Upgrade
-- =============================================

RegisterNetEvent('maximgm-farming:client:Plot:Upgrade', function(plotId)
    if not isOwner(plotId) then return end
    local plot = AllPlots[plotId]
    if not plot then return end

    local tierConfig = Config.Plots.tiers[plot.tier]
    if not tierConfig or not tierConfig.upgradeItem then
        utils.notify(Locales['notify_title_farming'], Locales['plot_max_tier'] or 'Already max tier!', 'error', 3000)
        return
    end

    if not client.hasItems(tierConfig.upgradeItem, 1) then
        utils.notify(Locales['notify_title_farming'],
            string.format(Locales['plot_no_upgrade_item'] or 'You need %s!', tierConfig.upgradeItem), 'error', 3000)
        return
    end

    local ped = cache.ped
    lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)

    if lib.progressBar({ duration = 5000, label = Locales['plot_upgrading'] or 'Upgrading...', useWhileDead = false, canCancel = true, disable = { car = true, move = true, combat = true } }) then
        TriggerServerEvent('maximgm-farming:server:Plot:Upgrade', plotId)
        ClearPedTasks(ped)
    else
        ClearPedTasks(ped)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'] or 'Canceled.', 'error', 2000)
    end
end)

-- =============================================
-- Remove Plot
-- =============================================

RegisterNetEvent('maximgm-farming:client:Plot:Remove', function(plotId)
    if not isOwner(plotId) then return end
    local plot = AllPlots[plotId]
    if not plot then return end

    local ped = cache.ped
    lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)

    if lib.progressBar({ duration = 4000, label = Locales['plot_removing'] or 'Removing...', useWhileDead = false, canCancel = true, disable = { car = true, move = true, combat = true } }) then
        TriggerServerEvent('maximgm-farming:server:Plot:Remove', plotId)
        ClearPedTasks(ped)
    else
        ClearPedTasks(ped)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'] or 'Canceled.', 'error', 2000)
    end
end)

-- =============================================
-- Delete Plant (dari ox_target langsung)
-- =============================================

RegisterNetEvent('maximgm-farming:client:ClearPlant', function(entity)
    local plantData = _G.PlantClass and _G.PlantClass.PlantCache[entity]
    if not plantData then return end

    local ped = cache.ped
    lib.playAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)

    if lib.progressBar({ duration = 3000, label = Locales['clear_plant'] or 'Clearing Plant..', useWhileDead = false, canCancel = true, disable = { car = true, move = true, combat = true } }) then
        TriggerServerEvent('maximgm-farming:server:ClearPlant', plantData.id)
        ClearPedTasks(ped)
    else
        ClearPedTasks(ped)
        utils.notify(Locales['notify_title_farming'], Locales['canceled'] or 'Canceled.', 'error', 2000)
    end
end)

RegisterNetEvent('maximgm-farming:client:Plant:AutoDelete', function()
    utils.notify(Locales['notify_title_farming'],
        Locales['plant_auto_deleted'] or '💀 A dead plant has been automatically removed.', 'error', 6000)
end)

-- =============================================
-- Network Events
-- =============================================

RegisterNetEvent('maximgm-farming:client:Plot:New', function(id, owner, coords, tier)
    addPlot(id, owner, coords, tier)
    if MyIdentifier and owner == MyIdentifier then
        utils.notify(Locales['notify_title_farming'], Locales['plot_placed'] or 'Farm plot placed!', 'success', 3000)
    end
end)

RegisterNetEvent('maximgm-farming:client:Plot:Remove', function(id)
    removePlot(id)
end)

RegisterNetEvent('maximgm-farming:client:Plot:UpdateTier', function(id, newTier)
    local plot = AllPlots[id]
    if not plot then return end

    plot.tier    = newTier
    AllPlots[id] = plot

    removePlotPoint(id)
    createPlotPoint(id, plot.coords, newTier)

    local playerCoords = GetEntityCoords(cache.ped)
    if #(playerCoords - plot.coords) <= PLOT_RENDER_DISTANCE then
        local obj = spawnPlotProp(id, plot.coords, newTier)
        if obj then
            registerPlotTarget(id, obj)
            startMarkerThread(id, plot.coords, newTier)
        end
    end

    if MyIdentifier and plot.owner == MyIdentifier then
        local tierConfig = Config.Plots.tiers[newTier]
        utils.notify(Locales['notify_title_farming'],
            string.format(Locales['plot_upgraded'] or 'Upgraded to %s!', tierConfig and tierConfig.name or ''), 'success', 4000)
    end
end)

-- =============================================
-- Load
-- =============================================

CreateThread(function()
    Wait(3000)

    MyIdentifier = lib.callback.await('maximgm-farming:server:Plot:GetMyIdentifier', 5000)
    if MyIdentifier then
        print('^2[MaximGM-Farming]^7 My identifier: ' .. MyIdentifier)
    end

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
-- Exports
-- =============================================

exports('getPlotIdByProp', function(entityHandle)
    if not entityHandle or not MyIdentifier then return nil end
    for id, plot in pairs(AllPlots) do
        if plot.owner == MyIdentifier and PlotObjects[id] == entityHandle then
            return id
        end
    end
    return nil
end)

exports('isInsideMyPlot', function(coords)
    if not coords or not MyIdentifier then return false, nil end
    for id, plot in pairs(AllPlots) do
        if plot.owner == MyIdentifier then
            local tierConfig = Config.Plots.tiers[plot.tier]
            if tierConfig and #(coords - plot.coords) <= tierConfig.radius then
                return true, id
            end
        end
    end
    return false, nil
end)

exports('usePlot', function()
    startPlotPlacement()
end)

-- =============================================
-- Cleanup
-- =============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= Config.Resource then return end
    for id, _ in pairs(AllPlots) do
        removePlotPoint(id)
    end
end)

_G.PlotSystem = {
    AllPlots       = AllPlots,
    isOwner        = isOwner,
    startPlacement = startPlotPlacement,
}

print('^2[MaximGM-Farming]^7 Plot Client loaded!')