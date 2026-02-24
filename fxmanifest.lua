--- fxmanifest.lua (Updated for Plot System v2 - Private)

fx_version 'cerulean'
game 'gta5'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
this_is_a_map 'yes'
version '1.2.0'
description 'MaximGM Farming System - Private Plot System'
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
    'shared/plot_config.lua',   -- Plot tiers & config
    'shared/locales.lua',
}

client_scripts {
    'bridge/**/client.lua',
    'utils/client.lua',
    'client/zones.lua',
    'client/plant.lua',
    'client/planting.lua',      -- PATCH ini dulu sebelum pakai plot
    'client/interactions.lua',
    'client/cl_plot.lua',       -- Plot client (privat)
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/**/server.lua',
    'utils/server.lua',
    'server/sv_setup.lua',
    'server/sv_plot_setup.lua',     -- Plot DB setup
    'server/sv_planting.lua',       -- Plant class (HARUS sebelum plot core)
    'server/sv_plot_core.lua',      -- Plot class, events, callbacks
    'server/sv_plot_callbacks.lua', -- Usable item registration
    'server/sv_callbacks.lua',
    'server/sv_events.lua',         -- PATCH ini untuk validasi plot
    'server/sv_interactions.lua',
}

data_file 'DLC_ITYP_REQUEST' 'stream/*.ytyp'

files {'stream/*.ytyp'}