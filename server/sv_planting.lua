--- Plant System - Server Core
--- Handles plant creation, health calculation, decay system, and lifecycle
--- Life System: Health 0-100 based on water & fertilizer maintenance
---
--- HOW TO KEEP PLANTS HEALTHY:
---   - Water your plant before water drops below Config.WaterThreshold (default 40%)
---   - Fertilize your plant before fertilizer drops below Config.FertilizerThreshold (default 50%)
---   - Water decays at Config.WaterDecay % per minute
---   - Fertilizer decays at Config.FertilizerDecay % per minute
---   - Every Config.LoopUpdate minutes, health is recalculated
---   - If water OR fertilizer is below threshold → health decreases by HealthBaseDecay
---   - Health reaches 0 → plant is DEAD and can only be removed

local globalState    = GlobalState
local HealthBaseDecay = math.random(Config.HealthBaseDecay[1], Config.HealthBaseDecay[2])

-- Initialize global PlantCache
_G.PlantCache = {}
local PlantCache = _G.PlantCache

--- @type table<any, Plant>
local Plants = {}

--- @class Plant
--- @field id number
--- @field coords vector3
--- @field time number
--- @field plantType string
--- @field owner string
--- @field fertilizer table timestamps of fertilizer applications
--- @field water table timestamps of water applications

local Plant = {}
Plant.__index = Plant

-- =============================================
-- Plant Class - CRUD
-- =============================================

function Plant:create(id, coords, time, plantType, owner, fertilizer, water)
    local plant = setmetatable({}, Plant)

    plant.id         = id
    plant.coords     = coords
    plant.time       = time or os.time()
    plant.plantType  = plantType
    plant.owner      = owner or ''
    plant.fertilizer = fertilizer or {}
    plant.water      = water or {}

    Plants[id] = plant
    PlantCache[id] = {
        coords    = coords,
        time      = time,
        plantType = plantType,
        owner     = owner
    }

    return plant
end

function Plant:new(coords, plantType, owner)
    if not coords or type(coords) ~= "vector3" then
        return false, "Coords must be a vector3"
    end

    if not Config.Plants[plantType] then
        return false, "Invalid plant type"
    end

    local time = os.time()

    local id = MySQL.insert.await([[
        INSERT INTO `maximgm_plants` (`coords`, `time`, `fertilizer`, `water`, `plantType`, `owner`)
        VALUES (:coords, :time, :fertilizer, :water, :plantType, :owner)
    ]], {
        coords     = json.encode(coords),
        time       = os.date('%Y-%m-%d %H:%M:%S', time),
        fertilizer = json.encode({}),
        water      = json.encode({}),
        plantType  = plantType,
        owner      = owner or ''
    })

    if not id then
        return false, "Failed to insert new plant into database"
    end

    local plant = Plant:create(id, coords, time, plantType, owner, {}, {})

    TriggerClientEvent('maximgm-farming:client:NewPlant', -1, id, coords, time, plantType)

    print(string.format('^2[MaximGM-Farming]^7 New plant created: ID=%d, Type=%s', id, plantType))

    return plant
end

function Plant:remove()
    local id = self.id

    local success = MySQL.query.await([[
        DELETE FROM `maximgm_plants` WHERE `id` = :id
    ]], { id = id })

    Plants[id]     = nil
    PlantCache[id] = nil

    TriggerClientEvent('maximgm-farming:client:RemovePlant', -1, id)

    if success then
        return true, ("Successfully deleted plant with id %s"):format(id)
    else
        return false, ("Could not delete plant with id %s"):format(id)
    end
end

function Plant:set(property, value)
    self[property] = value
end

function Plant:save()
    local affectedRows = MySQL.update.await([[
        UPDATE `maximgm_plants` SET
            `coords`    = :coords,
            `time`      = :time,
            `fertilizer`= :fertilizer,
            `water`     = :water,
            `plantType` = :plantType,
            `owner`     = :owner
        WHERE `id` = :id
    ]], {
        coords     = json.encode(self.coords),
        time       = os.date('%Y-%m-%d %H:%M:%S', self.time),
        fertilizer = json.encode(self.fertilizer),
        water      = json.encode(self.water),
        plantType  = self.plantType,
        owner      = self.owner or '',
        id         = self.id
    })

    return affectedRows > 0
end

function Plant:getPlant(id)
    return Plants[id]
end

-- =============================================
-- Calculation Methods
-- =============================================

function Plant:calcGrowth()
    local plantConfig = Config.Plants[self.plantType]
    if not plantConfig then return 0 end

    local current_time = os.time()
    local growTime     = plantConfig.growTime * 60
    local progress     = os.difftime(current_time, self.time)
    local growth       = lib.math.round(progress * 100 / growTime, 2)

    return math.min(growth, 100.00)
end

function Plant:calcStage()
    local plantConfig = Config.Plants[self.plantType]
    if not plantConfig then return 1 end

    local current_time = os.time()
    local growTime     = plantConfig.growTime * 60
    local progress     = os.difftime(current_time, self.time)
    local growth       = math.min(lib.math.round(progress * 100 / growTime, 2), 100.00)

    local growthThreshold = 20
    return math.min(5, math.floor((growth - 1) / growthThreshold) + 1)
end

function Plant:calcFertilizer()
    local current_time = os.time()

    if #self.fertilizer == 0 then return 0 end

    local last_fertilizer = self.fertilizer[#self.fertilizer]
    local time_elapsed    = os.difftime(current_time, last_fertilizer)
    local fertilizer      = lib.math.round(100 - (time_elapsed / 60 * Config.FertilizerDecay), 2)

    return math.max(fertilizer, 0.00)
end

function Plant:calcTotalFertilizer()
    return #self.fertilizer
end

function Plant:calcWater()
    local current_time = os.time()

    if #self.water == 0 then return 0 end

    local last_water   = self.water[#self.water]
    local time_elapsed = os.difftime(current_time, last_water)
    local water        = lib.math.round(100 - (time_elapsed / 60 * Config.WaterDecay), 2)

    return math.max(water, 0.00)
end

--- Calculates health berdasarkan riwayat water & fertilizer
--- Health berkurang setiap interval jika water/fertilizer di bawah threshold
--- @return health number 0-100
function Plant:calcHealth()
    local health       = 100
    local current_time = os.time()
    local planted_time = self.time
    local elapsed_time = os.difftime(current_time, planted_time)
    local intervals    = math.floor(elapsed_time / 60 / Config.LoopUpdate)

    if intervals == 0 then return 100 end

    for i = 1, intervals do
        local interval_time = planted_time + math.floor(i * Config.LoopUpdate * 60)

        -- Cek fertilizer di interval ini
        if #self.fertilizer == 0 then
            health = health - HealthBaseDecay
        else
            local last_fertilizer = planted_time

            for j = 1, #self.fertilizer do
                if self.fertilizer[j] < interval_time then
                    last_fertilizer = math.max(last_fertilizer, self.fertilizer[j])
                end
            end

            local time_since_fertilizer = os.difftime(interval_time, last_fertilizer)
            local fertilizer_amount     = math.max(lib.math.round(100 - (time_since_fertilizer / 60 * Config.FertilizerDecay), 2), 0.00)

            if last_fertilizer == planted_time or fertilizer_amount < Config.FertilizerThreshold then
                health = health - HealthBaseDecay
            end
        end

        -- Cek water di interval ini
        if #self.water == 0 then
            health = health - HealthBaseDecay
        else
            local last_water = planted_time

            for j = 1, #self.water do
                if self.water[j] < interval_time then
                    last_water = math.max(last_water, self.water[j])
                end
            end

            local time_since_water = os.difftime(interval_time, last_water)
            local water_amount     = math.max(lib.math.round(100 - (time_since_water / 60 * Config.WaterDecay), 2), 0.00)

            if last_water == planted_time or water_amount < Config.WaterThreshold then
                health = health - HealthBaseDecay
            end
        end
    end

    return math.max(health, 0.0)
end

-- =============================================
-- Decay Loop - Server tick setiap LoopUpdate menit
-- Ini yang menjalankan pengecekan health, warning ke owner,
-- dan auto-remove tanaman mati
-- =============================================

local function runDecayLoop()
    CreateThread(function()
        -- Tunggu resource siap
        Wait(5000)

        print(string.format(
            '^2[MaximGM-Farming]^7 Decay loop started. Interval: %d min | WaterDecay: %.1f%%/min | FertDecay: %.1f%%/min | HealthDecay: %d/interval',
            Config.LoopUpdate, Config.WaterDecay, Config.FertilizerDecay, HealthBaseDecay
        ))

        while true do
            -- Tunggu interval (LoopUpdate menit)
            Wait(Config.LoopUpdate * 60 * 1000)

            local processedCount = 0
            local deadCount      = 0
            local warnCount      = 0

            for id, plant in pairs(Plants) do
                if plant then
                    local health     = plant:calcHealth()
                    local water      = plant:calcWater()
                    local fertilizer = plant:calcFertilizer()
                    processedCount   = processedCount + 1

                    -- ✅ Auto-remove tanaman yang sudah mati total (health 0)
                    if health <= 0 then
                        deadCount = deadCount + 1
                        print(string.format('^3[MaximGM-Farming]^7 Plant ID=%d is DEAD. Auto-removing.', id))

                        -- Notify owner kalau online
                        if plant.owner and plant.owner ~= '' then
                            local players = GetPlayers()
                            for _, playerId in ipairs(players) do
                                local Player = server.GetPlayerFromId(tonumber(playerId))
                                if Player then
                                    local PlayerData = server.getPlayerData(Player)
                                    if PlayerData and PlayerData.identifier == plant.owner then
                                        utils.notify(
                                            tonumber(playerId),
                                            Locales['notify_title_farming'],
                                            Locales['plant_server_dead'] or '💀 One of your plants has died! Go remove it.',
                                            'error', 8000
                                        )
                                        break
                                    end
                                end
                            end
                        end

                        -- ✅ Auto-delete berdasarkan Config.PlantHealth.AutoDeleteDead
                        if Config.PlantHealth.AutoDeleteDead then
                            print(string.format('^3[MaximGM-Farming]^7 Auto-deleting dead plant ID=%d (owner: %s)', id, plant.owner))
                            if plant.owner and plant.owner ~= '' then
                                local players = GetPlayers()
                                for _, playerId in ipairs(players) do
                                    local Player = server.GetPlayerFromId(tonumber(playerId))
                                    if Player then
                                        local PlayerData = server.getPlayerData(Player)
                                        if PlayerData and PlayerData.identifier == plant.owner then
                                            TriggerClientEvent('maximgm-farming:client:Plant:AutoDelete', tonumber(playerId), id)
                                            break
                                        end
                                    end
                                end
                            end
                            plant:remove()
                        end

                    -- ✅ Warning ke owner kalau tanaman mulai dying
                    elseif health <= Config.PlantHealth.DyingThreshold then
                        warnCount = warnCount + 1

                        if plant.owner and plant.owner ~= '' then
                            local players = GetPlayers()
                            for _, playerId in ipairs(players) do
                                local Player = server.GetPlayerFromId(tonumber(playerId))
                                if Player then
                                    local PlayerData = server.getPlayerData(Player)
                                    if PlayerData and PlayerData.identifier == plant.owner then
                                        -- Kirim warning dengan info detail
                                        local warnMsg = string.format(
                                            Locales['plant_server_dying'] or '⚠️ Plant dying! Health: %d%% | Water: %d%% | Fertilizer: %d%%',
                                            math.floor(health),
                                            math.floor(water),
                                            math.floor(fertilizer)
                                        )
                                        utils.notify(
                                            tonumber(playerId),
                                            Locales['notify_title_farming'],
                                            warnMsg,
                                            'warning', 8000
                                        )
                                        break
                                    end
                                end
                            end
                        end

                    -- ✅ Reminder ke owner kalau water/fertilizer hampir habis
                    elseif health <= Config.PlantHealth.HealthyThreshold then
                        -- Health di zona "aman tapi perlu perhatian"
                        if plant.owner and plant.owner ~= '' then
                            local needsAttention = (water < Config.WaterThreshold + 20) or (fertilizer < Config.FertilizerThreshold + 20)
                            if needsAttention then
                                local players = GetPlayers()
                                for _, playerId in ipairs(players) do
                                    local Player = server.GetPlayerFromId(tonumber(playerId))
                                    if Player then
                                        local PlayerData = server.getPlayerData(Player)
                                        if PlayerData and PlayerData.identifier == plant.owner then
                                            local reminderMsg = string.format(
                                                Locales['plant_server_needs_care'] or '🌿 Plant needs care! Water: %d%% | Fertilizer: %d%%',
                                                math.floor(water),
                                                math.floor(fertilizer)
                                            )
                                            utils.notify(
                                                tonumber(playerId),
                                                Locales['notify_title_farming'],
                                                reminderMsg,
                                                'primary', 6000
                                            )
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            print(string.format(
                '^2[MaximGM-Farming]^7 Decay tick complete | Plants: %d | Dying/Dead warnings: %d | Dead: %d',
                processedCount, warnCount, deadCount
            ))
        end
    end)
end

-- =============================================
-- Setup & Initialize
-- =============================================

local setupPlants = function()
    local clear  = Config.ClearOnStartup
    local result = MySQL.Sync.fetchAll('SELECT * FROM `maximgm_plants`')

    local plantCount   = 0
    local clearedCount = 0

    for _, data in pairs(result) do
        local coords     = json.decode(data.coords)
        local fertilizer = json.decode(data.fertilizer)
        local water      = json.decode(data.water)
        local time       = math.floor(data.time / 1000)
        local owner      = data.owner or ''

        local plant = Plant:create(data.id, vector3(coords.x, coords.y, coords.z), time, data.plantType, owner, fertilizer, water)

        if clear then
            if plant:calcHealth() == 0 then
                plant:remove()
                clearedCount = clearedCount + 1
            else
                plantCount = plantCount + 1
            end
        else
            plantCount = plantCount + 1
        end
    end

    print(string.format('^2[MaximGM-Farming]^7 Loaded %d plants (cleared %d dead plants)', plantCount, clearedCount))
end

_G.Plant = Plant

CreateThread(function()
    Wait(2000)
    setupPlants()

    -- ✅ Decay loop aktif setelah plant loaded
    runDecayLoop()

    -- Global time sync untuk client
    while true do
        globalState.MaximgmFarmingTime = os.time()
        Wait(1000)
    end
end)