--- Plant Class Module (OPTIMIZED)
--- Handles plant object creation and management

print('^3[MaximGM-Farming]^7 Loading Plant module...')

local PlantCache = {}
local AllPlantProps = {}

--- Global StateBag
local currentTime = GlobalState.MaximgmFarmingTime

AddStateBagChangeHandler('MaximgmFarmingTime', '', function(bagName, _, value)
    if bagName == 'global' and value then
        currentTime = value
    end
end)

--- Determines the growth stage of the plant
--- @param time number The time when the plant was created (Unix timestamp)
--- @param plantType string The type of plant
--- @return stage (number) - Growth stage (1-5) 
local function calculateStage(time, plantType)
    local current_time = currentTime
    local plantConfig = Config.Plants[plantType]
    if not plantConfig then return 1 end
    
    local growTime = plantConfig.growTime * 60
    local progress = current_time - time
    local growthThreshold = 20

    local growth = math.min(lib.math.round(progress * 100 / growTime, 2), 100.00)
    
    return math.min(5, math.floor((growth - 1) / growthThreshold) + 1)
end

--- @type table<any, Plant>
local Plants = {}

--- @class Plant
local Plant = {}
Plant.__index = Plant

--- Creates a new Plant instance and sets up proximity tracking
function Plant:create(id, coords, time, plantType)
    local plant = setmetatable({}, Plant)

    plant.id = id
    plant.coords = coords
    plant.time = time
    plant.plantType = plantType

    local plantConfig = Config.Plants[plantType]
    if not plantConfig then return plant end

    -- Create a proximity point to track the player entering/exiting the plant's vicinity
    plant.point = lib.points.new({
        coords = coords,
        distance = Config.SpawnRadius,
        plantId = id,
        time = time,
        plantType = plantType,

        onEnter = function(self)
            local pConfig = Config.Plants[self.plantType]
            if not pConfig then return end

            local stage = math.max(1, calculateStage(self.time, self.plantType))
            local model = pConfig.props[stage]
            if not model then return end
            
            local zOffset = pConfig.stageZOffset and pConfig.stageZOffset[stage] or 0.0
            
            lib.requestModel(model)
            local entity = CreateObjectNoOffset(model, self.coords.x, self.coords.y, self.coords.z + zOffset, false, false, false)
            SetModelAsNoLongerNeeded(model)
            
            FreezeEntityPosition(entity, true)
            SetEntityInvincible(entity, true)
        
            self.entity = entity
            PlantCache[entity] = {id = self.plantId, type = self.plantType}
        end,

        onExit = function(self)
            local entity = self.entity
            if not entity then return end
        
            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)
        
            self.entity = nil
            PlantCache[entity] = nil
        end,

        -- OPTIMIZED: Changed from constant loop to interval checks
        nearby = function(self)
            Wait(5000) -- Check every 5 seconds instead of 1 second

            if self.removed then return end
            local entity = self.entity
            if not entity then return end

            local pConfig = Config.Plants[self.plantType]
            if not pConfig then return end

            local stage = math.max(1, calculateStage(self.time, self.plantType))
            local model = pConfig.props[stage]
            if not model then return end

            local currentModel = GetEntityModel(entity)
            if currentModel ~= model then
                local zOffset = pConfig.stageZOffset and pConfig.stageZOffset[stage] or 0.0
                
                lib.requestModel(model)
                local newEntity = CreateObjectNoOffset(model, self.coords.x, self.coords.y, self.coords.z + zOffset, false, false, false)
                SetModelAsNoLongerNeeded(model)
                
                FreezeEntityPosition(newEntity, true)
                SetEntityInvincible(newEntity, true)
            
                self.entity = newEntity
                PlantCache[newEntity] = {id = self.plantId, type = self.plantType}

                SetEntityAsMissionEntity(entity, false, true)
                DeleteEntity(entity)
                PlantCache[entity] = nil
            end
        end
    })

    Plants[id] = plant

    return plant
end

--- Removes the Plant instance and the object from the game world
function Plant:remove()
    local point = self.point
    if point then
        point.removed = true
        
        local entity = point.entity
        
        if entity then
            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)
            PlantCache[entity] = nil
        end

        point:remove()
    end
    Plants[self.id] = nil
end

--- Sets a property on the Plant instance
function Plant:set(property, value)
    self[property] = value
end

--- Retrieves a Plant instance from the global Plants table by its ID
function Plant:getPlant(id)
    return Plants[id]
end

--- Event Handlers

AddEventHandler('onResourceStop', function(resource)
    if resource ~= Config.Resource then return end

    for entity, _ in pairs(PlantCache) do
        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)
        end
    end
end)

--- Events

RegisterNetEvent('maximgm-farming:client:NewPlant', function(id, coords, time, plantType)
    Plant:create(id, coords, time, plantType)
end)

RegisterNetEvent('maximgm-farming:client:RemovePlant', function(plantId)
    local plant = Plant:getPlant(plantId)
    if not plant then return end
    
    plant:remove()
end)

--- Load plants on start (OPTIMIZED)
CreateThread(function()
    Wait(2000)

    local result = lib.callback.await('maximgm-farming:server:GetPlantLocations', 5000) -- Added timeout

    if result then
        for id, data in pairs(result) do
            if data then
                Plant:create(id, data.coords, data.time, data.plantType)
            end
        end
        print('^2[MaximGM-Farming]^7 Loaded ' .. #result .. ' plants successfully!')
    else
        print('^1[MaximGM-Farming]^7 Failed to load plants from server!')
    end
end)

--- Build props list for target system (OPTIMIZED - Only runs once)
CreateThread(function()
    Wait(1000)
    
    -- Build props list from all plant types
    for plantType, plantData in pairs(Config.Plants) do
        if plantData and type(plantData) == "table" then
            if plantData.props and type(plantData.props) == "table" then
                for key, prop in pairs(plantData.props) do
                    if prop and type(prop) == "number" then
                        AllPlantProps[prop] = true
                    end
                end
            end
        end
    end
    
    -- Build dynamic model list from all plant props
    local propsList = {}
    for prop, _ in pairs(AllPlantProps) do
        table.insert(propsList, prop)
    end

    if #propsList > 0 then
        if Config.Target == 'ox_target' then
            exports['ox_target']:addModel(propsList, {
                {
                    name = 'maximgm_farming_main',
                    event = 'maximgm-farming:client:CheckPlant',
                    icon = 'fas fa-seedling',
                    label = Locales['check_plant'],
                    distance = 1.5,
                    canInteract = function(entity)
                        return PlantCache[entity] ~= nil
                    end,
                }
            })
        elseif Config.Target == 'qb-target' then
            exports['qb-target']:AddTargetModel(propsList, {
                options = {
                    {
                        type = 'client',
                        event = 'maximgm-farming:client:CheckPlant',
                        icon = 'fas fa-seedling',
                        label = Locales['check_plant'],
                        canInteract = function(entity)
                            return PlantCache[entity] ~= nil
                        end,
                    }
                },
                distance = 1.5, 
            })
        end
        print('^2[MaximGM-Farming]^7 Target system initialized with ' .. #propsList .. ' plant props')
    end
end)

--- Make module global (accessible from other files)
_G.PlantClass = {
    Plant = Plant,
    PlantCache = PlantCache,
    calculateStage = calculateStage
}

-- ========================================
-- TESTING COMMANDS (Optional - Remove in production)
-- ========================================
RegisterCommand('plantrow', function(args, rawCommand)
    local plantType = args[1] or 'cannabis'
    
    if not Config.Plants[plantType] then
        local availableTypes = {}
        for pType, _ in pairs(Config.Plants) do
            table.insert(availableTypes, pType)
        end
        
        utils.notify(
            'Farming', 
            'Invalid plant type! Available: ' .. table.concat(availableTypes, ','), 
            'error', 
            5000
        )
        return
    end
    
    TriggerEvent('maximgm-farming:client:UseSeedRow_' .. plantType)
end, false)

TriggerEvent('chat:addSuggestion', '/plantrow', 'Plant seeds in a row', {
    { name = 'plant_type', help = 'tomato, potato, carrot, strawberry, watermelon, cannabis, wheat, corn' }
})