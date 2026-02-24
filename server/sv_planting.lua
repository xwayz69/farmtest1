local globalState = GlobalState
local HealthBaseDecay = math.random(Config.HealthBaseDecay[1], Config.HealthBaseDecay[2])

-- Initialize global PlantCache
_G.PlantCache = {}
local PlantCache = _G.PlantCache

--- @type table<any, Plant>
--- Global table holding all Plant instances, keyed by their unique ID
local Plants = {}

--- @class Plant
--- @field id number The unique identifier of the plant
--- @field coords vector3 The coordinates of the plant in the game world
--- @field time number The planting time (Unix timestamp)
--- @field plantType string The type of plant
--- @field owner string The identifier of the player who planted it
--- @field fertilizer table A table containing timestamps of fertilizer applications
--- @field water table A table containing timestamps of water applications

local Plant = {}
Plant.__index = Plant

--- Creates a new Plant instance
--- @param id number The unique identifier of the plant
--- @param coords vector3 The coordinates of the plant in the game world
--- @param time number The planting time (Unix timestamp)
--- @param plantType string The type of plant
--- @param owner string The identifier of the owner
--- @param fertilizer table A table containing timestamps of fertilizer applications
--- @param water table A table containing timestamps of water applications
--- @return Plant The created Plant object
function Plant:create(id, coords, time, plantType, owner, fertilizer, water)
    local plant = setmetatable({}, Plant)

    plant.id = id
    plant.coords = coords
    plant.time = time or os.time()
    plant.plantType = plantType
    plant.owner = owner or ''
    plant.fertilizer = fertilizer or {}
    plant.water = water or {}

    Plants[id] = plant
    PlantCache[id] = {
        coords = coords,
        time = time,
        plantType = plantType,
        owner = owner
    }

    return plant
end

--- Inserts a new plant into the database, creating a new Plant instance
--- @param coords (vector3) - Coordinates of the plant
--- @param plantType (string) - Type of plant
--- @param owner (string) - Identifier of the owner
--- @return plant (Plant) or false, error message if failed
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
        coords = json.encode(coords),
        time = os.date('%Y-%m-%d %H:%M:%S', time),
        fertilizer = json.encode({}),
        water = json.encode({}),
        plantType = plantType,
        owner = owner or ''
    })

    if not id then
        return false, "Failed to insert new plant into database"
    end

    -- Create and return the Plant object using newly generated ID
    local plant = Plant:create(id, coords, time, plantType, owner, {}, {})

    -- Update clients cache
    TriggerClientEvent('maximgm-farming:client:NewPlant', -1, id, coords, time, plantType)
    
    print(string.format('^2[MaximGM-Farming]^7 New plant created: ID=%d, Type=%s', id, plantType))
    
    return plant
end

--- Removes the plant from the database and clears it from Plants
--- @return success (boolean), message (string)
function Plant:remove()
    local id = self.id

    local success = MySQL.query.await([[
        DELETE FROM `maximgm_plants`
        WHERE `id` = :id
    ]], { 
        id = id
    })

    Plants[id] = nil
    PlantCache[id] = nil

    -- Update clients cache
    TriggerClientEvent('maximgm-farming:client:RemovePlant', -1, id)

    if success then
        return true, ("Successfully deleted plant from database with id %s"):format(id)
    else
        return false, ("Could not delete plant from database with id %s"):format(id)
    end
end

--- Sets a specific property of the plant instance
--- @param property (string) - Property to set
--- @param value - New value for the property
function Plant:set(property, value)
    self[property] = value
end

--- Saves the current state of the plant to the database
--- @return success (boolean) - True if rows were affected
function Plant:save()
    local affectedRows = MySQL.update.await([[
        UPDATE `maximgm_plants` SET
            `coords` = :coords,
            `time` = :time,
            `fertilizer` = :fertilizer,
            `water` = :water,
            `plantType` = :plantType,
            `owner` = :owner
        WHERE `id` = :id
    ]], {
        coords = json.encode(self.coords),
        time = os.date('%Y-%m-%d %H:%M:%S', self.time),
        fertilizer = json.encode(self.fertilizer),
        water = json.encode(self.water),
        plantType = self.plantType,
        owner = self.owner or '',
        id = self.id
    })

    return affectedRows > 0
end

--- Retrieves a Plant instance by its ID
--- @param id (number) - ID of the plant
--- @return Plant instance or nil if not found
function Plant:getPlant(id)
    return Plants[id]
end

--- Calculates the plant's growth progress as a percentage
--- @return growth (number) - Growth percentage (0-100)
function Plant:calcGrowth()
    local plantConfig = Config.Plants[self.plantType]
    if not plantConfig then return 0 end

    local current_time = os.time()
    local growTime = plantConfig.growTime * 60
    local progress = os.difftime(current_time, self.time)
    local growth = lib.math.round(progress * 100 / growTime, 2)

    return math.min(growth, 100.00)
end

--- Determines the growth stage of the plant
--- @return stage (number) - Growth stage (1-5)
function Plant:calcStage()
    local plantConfig = Config.Plants[self.plantType]
    if not plantConfig then return 1 end

    local current_time = os.time()
    local growTime = plantConfig.growTime * 60
    local progress = os.difftime(current_time, self.time)
    local growth = math.min(lib.math.round(progress * 100 / growTime, 2), 100.00)

    local growthThreshold = 20
    
    return math.min(5, math.floor((growth - 1) / growthThreshold) + 1)
end

--- Calculates the remaining fertilizer level as a percentage
--- @return fertilizer (number) - Fertilizer level percentage (0-100)
function Plant:calcFertilizer()
    local current_time = os.time()

    if #self.fertilizer == 0 then
        return 0
    else
        local last_fertilizer = self.fertilizer[#self.fertilizer]
        local time_elapsed = os.difftime(current_time, last_fertilizer)
        local fertilizer = lib.math.round(100 - (time_elapsed / 60 * Config.FertilizerDecay), 2)

        return math.max(fertilizer, 0.00)
    end
end

--- Calculates total fertilizer applications
--- @return count (number) - Total fertilizer uses
function Plant:calcTotalFertilizer()
    return #self.fertilizer
end

--- Calculates the remaining water level as a percentage
--- @return water (number) - Water level percentage (0-100)
function Plant:calcWater()
    local current_time = os.time()

    if #self.water == 0 then
        return 0
    else
        local last_water = self.water[#self.water]
        local time_elapsed = os.difftime(current_time, last_water)
        local water = lib.math.round(100 - (time_elapsed / 60 * Config.WaterDecay), 2)

        return math.max(water, 0.00)
    end
end

--- Calculates the overall health of the plant based on water and fertilizer levels over time
--- @return health (number) - Plant health percentage (0-100)
function Plant:calcHealth()
    local health = 100
    local current_time = os.time()
    local planted_time = self.time
    local elapsed_time = os.difftime(current_time, planted_time)
    local intervals = math.floor(elapsed_time / 60 / Config.LoopUpdate)

    if intervals == 0 then return 100 end

    for i = 1, intervals do
        local interval_time = planted_time + math.floor(i * Config.LoopUpdate * 60)

        if #self.fertilizer == 0 then
            health = health - HealthBaseDecay
        else
            local last_fertilizer = planted_time

            for j = 1, #self.fertilizer, 1 do
                if self.fertilizer[j] < interval_time then
                    last_fertilizer = math.max(last_fertilizer, self.fertilizer[j])
                end
            end

            local time_since_fertilizer = os.difftime(interval_time, last_fertilizer)
            local fertilizer_amount = math.max(lib.math.round(100 - (time_since_fertilizer / 60 * Config.FertilizerDecay), 2), 0.00)

            if last_fertilizer == planted_time or fertilizer_amount < Config.FertilizerThreshold then
                health = health - HealthBaseDecay
            end
        end
    
        if #self.water == 0 then
            health = health - HealthBaseDecay
        else
            local last_water = planted_time

            for j = 1, #self.water, 1 do
                if self.water[j] < interval_time then
                    last_water = math.max(last_water, self.water[j])
                end
            end

            local time_since_water = os.difftime(interval_time, last_water)
            local water_amount = math.max(lib.math.round(100 - (time_since_water / 60 * Config.WaterDecay), 2), 0.00)

            if last_water == planted_time or water_amount < Config.WaterThreshold then
                health = health - HealthBaseDecay
            end
        end
    end

    return math.max(health, 0.0)
end

--- Fetches all data from the database and creates Plant instances
local setupPlants = function()
    local clear = Config.ClearOnStartup
    local result = MySQL.Sync.fetchAll([[
        SELECT * 
        FROM `maximgm_plants`
    ]])

    local plantCount = 0
    local clearedCount = 0

    for _, data in pairs(result) do
        local coords = json.decode(data.coords)
        local fertilizer = json.decode(data.fertilizer)
        local water = json.decode(data.water)
        local time = math.floor(data.time / 1000)
        local owner = data.owner or ''

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

-- Make Plant class global for access in other files
_G.Plant = Plant

--- Initialize plants on startup
CreateThread(function()
    Wait(2000) -- Wait for database
    setupPlants()

    while true do
        globalState.MaximgmFarmingTime = os.time()
        Wait(1000)
    end
end)