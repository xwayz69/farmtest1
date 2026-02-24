--- Farming Zones Module (OPTIMIZED)
--- Handles farming zone creation and detection

local FarmingZones = {}

-- Make InsideZone global so it can be accessed from other files
_G.InsideZone = false

--- Initialize all farming zones
local function initializeFarmingZones()
    if not Config.FarmingZones or #Config.FarmingZones == 0 then
        _G.InsideZone = true -- Allow planting everywhere if no zones
        print('^3[MaximGM-Farming]^7 No farming zones configured - planting allowed everywhere')
        return
    end
    
    for i, zoneData in ipairs(Config.FarmingZones) do
        local zoneName = zoneData.name or ('Zone_' .. i)
        
        local zone = lib.zones.sphere({
            coords = zoneData.coords,
            radius = zoneData.radius,
            debug = zoneData.debug or false,
            onEnter = function()
                _G.InsideZone = true
                utils.notify(
                    Locales['notify_title_farming'], 
                    Locales['entered_farming_zone'] or 'You entered a farming zone', 
                    'info', 
                    3000
                )
            end,
            onExit = function()
                _G.InsideZone = false
                utils.notify(
                    Locales['notify_title_farming'], 
                    Locales['left_farming_zone'] or 'You left the farming zone', 
                    'info', 
                    3000
                )
            end
        })
        
        if zone then
            table.insert(FarmingZones, zone)
            print(string.format('^2[MaximGM-Farming]^7 Zone "%s" initialized (radius: %.1fm)', zoneName, zoneData.radius))
        else
            print(string.format('^1[MaximGM-Farming]^7 Failed to create zone "%s"', zoneName))
        end
    end
    
    print(string.format('^2[MaximGM-Farming]^7 Loaded %d farming zones', #FarmingZones))
end

--- Cleanup zones on resource stop
local function cleanupZones()
    for _, zone in ipairs(FarmingZones) do
        zone:remove()
    end
    FarmingZones = {}
    print('^3[MaximGM-Farming]^7 All zones cleaned up')
end

--- Initialize zones when resource starts
CreateThread(function()
    Wait(1500) -- Increased wait to ensure all systems loaded
    initializeFarmingZones()
end)

--- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= Config.Resource then return end
    cleanupZones()
end)