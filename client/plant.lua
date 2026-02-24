--- Plant Class Module
--- ✅ FIX: SetEntityRgba tidak ada di FiveM → pakai SetEntityAlpha + DrawSprite overlay
--- ✅ Health tint: Healthy=normal, Dying=alpha redup, Dead=alpha sangat redup
--- ✅ Delete via ox_target langsung tanpa buka menu
--- Life System: Healthy → Dying → Dead

print('^3[MaximGM-Farming]^7 Loading Plant module...')

local PlantCache  = {}
local AllPlantProps = {}

--- Global StateBag time sync
local currentTime = GlobalState.MaximgmFarmingTime

AddStateBagChangeHandler('MaximgmFarmingTime', '', function(bagName, _, value)
    if bagName == 'global' and value then
        currentTime = value
    end
end)

--- Hitung stage tanaman
local function calculateStage(time, plantType)
    local current_time = currentTime
    local plantConfig  = Config.Plants[plantType]
    if not plantConfig then return 1 end

    local growTime        = plantConfig.growTime * 60
    local progress        = current_time - time
    local growthThreshold = 20
    local growth          = math.min(lib.math.round(progress * 100 / growTime, 2), 100.00)

    return math.min(5, math.floor((growth - 1) / growthThreshold) + 1)
end

-- =============================================
-- Health Visual System
-- ✅ FIX: FiveM tidak punya SetEntityRgba
--    Gunakan SetEntityAlpha untuk efek visual health
--    Healthy = alpha 255 (normal penuh)
--    Dying   = alpha 180 (agak transparan, kesan layu)
--    Dead    = alpha 100 (sangat redup, kesan mati)
-- =============================================

local HealthWarnCooldown = {}

local function getHealthStatus(health)
    local cfg = Config.PlantHealth
    if health > cfg.HealthyThreshold then
        return 'healthy'
    elseif health > cfg.DyingThreshold then
        return 'dying'
    else
        return 'dead'
    end
end

--- ✅ Fix: pakai SetEntityAlpha (valid di FiveM) bukan SetEntityRgba
--- Healthy = opaque penuh, Dying = redup, Dead = sangat redup
local function applyHealthTint(entity, health)
    if not entity or not DoesEntityExist(entity) then return end

    local status = getHealthStatus(health)

    if status == 'healthy' then
        -- Normal, tanaman segar
        SetEntityAlpha(entity, 255, false)
    elseif status == 'dying' then
        -- Redup ~70% — kesan layu
        SetEntityAlpha(entity, 180, false)
    else
        -- Sangat redup ~40% — kesan mati/kering
        SetEntityAlpha(entity, 100, false)
    end
end

local function warnOwnerIfNeeded(plantId, health, isOwnerPlant)
    if not Config.PlantHealth.WarnOwnerOnNearby then return end
    if not isOwnerPlant then return end

    local status = getHealthStatus(health)
    if status == 'healthy' then return end

    local now      = GetGameTimer()
    local lastWarn = HealthWarnCooldown[plantId] or 0
    if (now - lastWarn) < Config.PlantHealth.WarnCooldown then return end
    HealthWarnCooldown[plantId] = now

    if status == 'dying' then
        utils.notify(
            Locales['notify_title_farming'],
            Locales['plant_dying_warn'] or '⚠️ Your plant is dying! Water & fertilize it ASAP!',
            'warning', 5000
        )
    else
        utils.notify(
            Locales['notify_title_farming'],
            Locales['plant_dead_warn'] or '💀 Your plant is dead! Remove it to free up space.',
            'error', 5000
        )
    end
end

-- =============================================
-- Plant Class
-- =============================================

local Plants = {}

local Plant = {}
Plant.__index = Plant

-- ✅ Track identifier player ini (diisi saat load)
local MyIdentifier = nil

-- Ambil identifier player dari server
CreateThread(function()
    Wait(2500)
    local id = lib.callback.await('maximgm-farming:server:Plot:GetMyIdentifier', 5000)
    if id then
        MyIdentifier = id
    end
end)

--- Daftarkan ox_target delete ke entity tanaman
--- Hanya owner yang bisa delete
local function registerPlantTarget(entity, plantId, plantType)
    if Config.Target ~= 'ox_target' then return end
    if not entity or not DoesEntityExist(entity) then return end

    exports['ox_target']:addLocalEntity(entity, {
        -- ✅ Check/Interact
        {
            name     = 'maximgm_plant_check_' .. plantId,
            label    = Locales['check_plant'] or 'Check Plant',
            icon     = 'fas fa-seedling',
            distance = 1.5,
            canInteract = function(ent)
                return PlantCache[ent] ~= nil
            end,
            onSelect = function()
                TriggerEvent('maximgm-farming:client:CheckPlant', { entity = entity })
            end,
        },
        -- ✅ Delete langsung via ox_target (hanya owner)
        {
            name     = 'maximgm_plant_delete_' .. plantId,
            label    = Locales['clear_plant_header'] or '🗑️ Remove Plant',
            icon     = 'fas fa-trash',
            distance = 1.5,
            canInteract = function(ent)
                local data = PlantCache[ent]
                if not data then return false end
                -- Tampilkan opsi delete hanya ke owner
                if not MyIdentifier then return false end
                -- Cek ownership via PlantCache (owner diisi saat load)
                return data.isOwner == true
            end,
            onSelect = function()
                TriggerEvent('maximgm-farming:client:ClearPlant', entity)
            end,
        },
    })
end

function Plant:create(id, coords, time, plantType)
    local plant = setmetatable({}, Plant)

    plant.id        = id
    plant.coords    = coords
    plant.time      = time
    plant.plantType = plantType

    local plantConfig = Config.Plants[plantType]
    if not plantConfig then return plant end

    plant.point = lib.points.new({
        coords    = coords,
        distance  = Config.SpawnRadius,
        plantId   = id,
        time      = time,
        plantType = plantType,

        onEnter = function(self)
            local pConfig = Config.Plants[self.plantType]
            if not pConfig then return end

            local stage   = math.max(1, calculateStage(self.time, self.plantType))
            local model   = pConfig.props[stage]
            if not model then return end

            local zOffset = pConfig.stageZOffset and pConfig.stageZOffset[stage] or 0.0

            lib.requestModel(model)
            local entity = CreateObjectNoOffset(model, self.coords.x, self.coords.y, self.coords.z + zOffset, false, false, false)
            SetModelAsNoLongerNeeded(model)

            FreezeEntityPosition(entity, true)
            SetEntityInvincible(entity, true)

            self.entity     = entity
            self.lastHealth = 100
            self.isOwner    = false

            PlantCache[entity] = { id = self.plantId, type = self.plantType, isOwner = false }

            -- Ambil health + ownership dari server
            CreateThread(function()
                local success, result = lib.callback.await('maximgm-farming:server:GetPlantData', 3000, self.plantId)
                if success and result then
                    self.lastHealth = result.health
                    self.isOwner    = result.isOwner

                    -- ✅ Update isOwner di PlantCache untuk dipakai target canInteract
                    if PlantCache[entity] then
                        PlantCache[entity].isOwner = result.isOwner
                    end

                    -- ✅ Apply health visual (alpha-based)
                    applyHealthTint(entity, result.health)
                    warnOwnerIfNeeded(self.plantId, result.health, result.isOwner)

                    -- ✅ Daftarkan ox_target dengan opsi delete ke entity ini
                    registerPlantTarget(entity, self.plantId, self.plantType)
                else
                    -- Fallback: daftarkan target tanpa delete (belum tahu ownership)
                    registerPlantTarget(entity, self.plantId, self.plantType)
                end
            end)
        end,

        onExit = function(self)
            local entity = self.entity
            if not entity then return end

            -- Hapus ox_target dari entity ini
            if Config.Target == 'ox_target' then
                exports['ox_target']:removeLocalEntity(entity)
            end

            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)

            self.entity = nil
            PlantCache[entity] = nil
        end,

        nearby = function(self)
            Wait(Config.PlantHealth.VisualUpdateInterval)
            if self.removed then return end

            local entity = self.entity
            if not entity then return end

            local pConfig = Config.Plants[self.plantType]
            if not pConfig then return end

            -- Cek stage berubah → ganti model
            local stage = math.max(1, calculateStage(self.time, self.plantType))
            local model = pConfig.props[stage]
            if not model then return end

            local currentModel = GetEntityModel(entity)
            if currentModel ~= model then
                local zOffset = pConfig.stageZOffset and pConfig.stageZOffset[stage] or 0.0

                -- Hapus target dari entity lama
                if Config.Target == 'ox_target' then
                    exports['ox_target']:removeLocalEntity(entity)
                end

                lib.requestModel(model)
                local newEntity = CreateObjectNoOffset(model, self.coords.x, self.coords.y, self.coords.z + zOffset, false, false, false)
                SetModelAsNoLongerNeeded(model)

                FreezeEntityPosition(newEntity, true)
                SetEntityInvincible(newEntity, true)

                PlantCache[newEntity] = { id = self.plantId, type = self.plantType, isOwner = self.isOwner }
                PlantCache[entity]    = nil

                SetEntityAsMissionEntity(entity, false, true)
                DeleteEntity(entity)

                self.entity = newEntity
                entity      = newEntity

                -- Daftarkan ulang target ke entity baru
                registerPlantTarget(newEntity, self.plantId, self.plantType)
            end

            -- Update health & tint secara berkala
            CreateThread(function()
                local success, result = lib.callback.await('maximgm-farming:server:GetPlantData', 3000, self.plantId)
                if success and result then
                    self.lastHealth = result.health
                    self.isOwner    = result.isOwner

                    if PlantCache[self.entity] then
                        PlantCache[self.entity].isOwner = result.isOwner
                    end

                    applyHealthTint(self.entity, result.health)
                    warnOwnerIfNeeded(self.plantId, result.health, result.isOwner)
                end
            end)
        end,
    })

    Plants[id] = plant
    return plant
end

function Plant:remove()
    local point = self.point
    if point then
        point.removed = true

        local entity = point.entity
        if entity then
            if Config.Target == 'ox_target' then
                exports['ox_target']:removeLocalEntity(entity)
            end
            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)
            PlantCache[entity] = nil
        end

        point:remove()
    end
    Plants[self.id] = nil
end

function Plant:set(property, value)
    self[property] = value
end

function Plant:getPlant(id)
    return Plants[id]
end

-- =============================================
-- Event Handlers
-- =============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= Config.Resource then return end
    for entity, _ in pairs(PlantCache) do
        if DoesEntityExist(entity) then
            if Config.Target == 'ox_target' then
                exports['ox_target']:removeLocalEntity(entity)
            end
            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)
        end
    end
end)

RegisterNetEvent('maximgm-farming:client:NewPlant', function(id, coords, time, plantType)
    Plant:create(id, coords, time, plantType)
end)

RegisterNetEvent('maximgm-farming:client:RemovePlant', function(plantId)
    local plant = Plant:getPlant(plantId)
    if not plant then return end
    plant:remove()
end)

-- ✅ Auto-delete notification dari server
RegisterNetEvent('maximgm-farming:client:Plant:AutoDelete', function(plantId)
    utils.notify(
        Locales['notify_title_farming'],
        Locales['plant_auto_deleted'] or '💀 A dead plant has been automatically removed.',
        'error', 6000
    )
end)

--- Load plants on start
CreateThread(function()
    Wait(2000)

    local result = lib.callback.await('maximgm-farming:server:GetPlantLocations', 5000)

    if result then
        local count = 0
        for id, data in pairs(result) do
            if data then
                Plant:create(id, data.coords, data.time, data.plantType)
                count = count + 1
            end
        end
        print('^2[MaximGM-Farming]^7 Loaded ' .. count .. ' plants successfully!')
    else
        print('^1[MaximGM-Farming]^7 Failed to load plants from server!')
    end
end)

-- =============================================
-- Target System Setup (model-based fallback)
-- Ini sebagai fallback untuk qb-target
-- ox_target sudah dihandle per-entity di registerPlantTarget
-- =============================================

CreateThread(function()
    Wait(1000)

    for plantType, plantData in pairs(Config.Plants) do
        if plantData and type(plantData) == "table" then
            if plantData.props and type(plantData.props) == "table" then
                for _, prop in pairs(plantData.props) do
                    if prop and type(prop) == "number" then
                        AllPlantProps[prop] = true
                    end
                end
            end
        end
    end

    local propsList = {}
    for prop, _ in pairs(AllPlantProps) do
        table.insert(propsList, prop)
    end

    if #propsList > 0 then
        -- ✅ ox_target: pakai addLocalEntity per-entity (sudah di registerPlantTarget)
        -- Ini hanya untuk qb-target fallback
        if Config.Target == 'qb-target' then
            exports['qb-target']:AddTargetModel(propsList, {
                options = {
                    {
                        type  = 'client',
                        event = 'maximgm-farming:client:CheckPlant',
                        icon  = 'fas fa-seedling',
                        label = Locales['check_plant'],
                        canInteract = function(entity)
                            return PlantCache[entity] ~= nil
                        end,
                    },
                    {
                        type  = 'client',
                        event = 'maximgm-farming:client:ClearPlant',
                        icon  = 'fas fa-trash',
                        label = Locales['clear_plant_header'] or 'Remove Plant',
                        canInteract = function(entity)
                            local data = PlantCache[entity]
                            return data ~= nil and data.isOwner == true
                        end,
                    },
                },
                distance = 1.5,
            })
        end

        print('^2[MaximGM-Farming]^7 Target system initialized with ' .. #propsList .. ' plant props')
    end
end)

-- =============================================
-- Global Export
-- =============================================

_G.PlantClass = {
    Plant          = Plant,
    PlantCache     = PlantCache,
    calculateStage = calculateStage,
}

-- =============================================
-- Dev Commands (hapus di production)
-- =============================================

RegisterCommand('plantrow', function(args)
    local plantType = args[1] or 'cannabis'
    if not Config.Plants[plantType] then
        utils.notify('Farming', 'Invalid type! Use: ' .. table.concat((function()
            local t = {}
            for k in pairs(Config.Plants) do t[#t+1] = k end
            return t
        end)(), ', '), 'error', 5000)
        return
    end
    TriggerEvent('maximgm-farming:client:StartPlanting', plantType, true)
end, false)

RegisterCommand('plantsingle', function(args)
    local plantType = args[1] or 'cannabis'
    TriggerEvent('maximgm-farming:client:StartPlanting', plantType, false)
end, false)