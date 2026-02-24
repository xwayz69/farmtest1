fx_version 'cerulean'
game 'gta5'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

version '1.0.1'
description 'MaximGM Farming System - Multi-Crop Planting Script (Optimized)'
author 'MaximGM Development'

dependencies {
    'ox_lib',
    'oxmysql'
}

files {
    'locales/*.json'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/locales.lua',
}

client_scripts {
    'bridge/**/client.lua',
    'utils/client.lua',       -- Load utils first
    'client/zones.lua',        -- Load zones second
    'client/plant.lua',        -- Load plant third
    'client/planting.lua',     -- Load planting fourth
    'client/interactions.lua', -- Load interactions fifth
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/**/server.lua',
    'utils/server.lua',
    'server/sv_setup.lua',
    'server/sv_planting.lua',   -- Part 1: Plant Class & Functions (MUST LOAD FIRST!)
    'server/sv_callbacks.lua',  -- Part 2: Callbacks (FIXED - was missing GetPlantLocations)
    'server/sv_events.lua',
     'server/sv_interactions.lua',    -- Part 3: Events
}