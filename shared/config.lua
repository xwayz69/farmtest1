Config = {
    --- Compatibility Settings
    Resource = GetCurrentResourceName(),
    Lang = 'en',
    Target = 'ox_target', -- 'qb-target' or 'ox_target'
    Inventory = 'ox_inventory', -- 'ox_inventory', 'qb-inventory' or 'ps-inventory'
    Logging = 'ox_lib', -- 'ox_lib' or 'qb' or 'esx'

    --- Farming Zones Configuration
    FarmingZones = {
        {
            name = 'farm_zone_grapeseed',
            coords = vector3(376.6797, 6479.1621, 29.3963),
            radius = 150.0,
            debug = false -- OPTIMIZED: Set false in production to reduce draw calls
        },
        {
            name = 'farm_zone_paleto',
            coords = vector3(-57.5822, 6350.0732, 31.4904),
            radius = 100.0,
            debug = false -- OPTIMIZED: Set false in production
        },
    },



    --- Farming Plants Configuration
    Plants = {
        -- Vegetables
        tomato = {
            seed = 'maximgm_seed_tomato',
            harvest = 'maximgm_tomato',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01c'),
                [2] = joaat('bkr_prop_weed_01_small_01b'),
                [3] = joaat('bkr_prop_weed_01_small_01a'),
                [4] = joaat('bkr_prop_weed_med_01b'),
                [5] = joaat('bkr_prop_weed_lrg_01a'),
            },
            stageZOffset = {
                [1] = 0.0,
                [2] = -0.1,
                [3] = -0.2,
                [4] = -0.3,
                [5] = -0.4,
            },
            growTime = 3,
            harvestAmount = {1, 3},
            fertilizerBonus = 50,
        },
        potato = {
            seed = 'maximgm_seed_potato',
            harvest = 'maximgm_potato',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01b'),
                [2] = joaat('bkr_prop_weed_med_01a'),
                [3] = joaat('bkr_prop_weed_med_01b'),
                [4] = joaat('bkr_prop_weed_lrg_01a'),
                [5] = joaat('bkr_prop_weed_lrg_01b')
            },
            stageZOffset = {
                [1] = -0.3,
                [2] = -0.35,
                [3] = -0.4,
                [4] = -0.45,
                [5] = -0.5,
            },
            growTime = 7,
            harvestAmount = {2, 4},
            fertilizerBonus = 40,
        },
        carrot = {
            seed = 'maximgm_seed_carrot',
            harvest = 'maximgm_carrot',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01b'),
                [2] = joaat('bkr_prop_weed_med_01a'),
                [3] = joaat('bkr_prop_weed_med_01b'),
                [4] = joaat('bkr_prop_weed_lrg_01a'),
                [5] = joaat('bkr_prop_weed_lrg_01b')
            },
            stageZOffset = {
                [1] = -0.4,
                [2] = -0.45,
                [3] = -0.5,
                [4] = -0.55,
                [5] = -0.6,
            },
            growTime = 6,
            harvestAmount = {2, 5},
            fertilizerBonus = 35,
        },
        strawberry = {
            seed = 'maximgm_seed_strawberry',
            harvest = 'maximgm_strawberry',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01b'),
                [2] = joaat('bkr_prop_weed_med_01a'),
                [3] = joaat('bkr_prop_weed_med_01b'),
                [4] = joaat('bkr_prop_weed_lrg_01a'),
                [5] = joaat('bkr_prop_weed_lrg_01b')
            },
            stageZOffset = {
                [1] = -0.6,
                [2] = -0.65,
                [3] = -0.7,
                [4] = -0.75,
                [5] = -0.8,
            },
            growTime = 8,
            harvestAmount = {3, 6},
            fertilizerBonus = 45,
        },
        watermelon = {
            seed = 'maximgm_seed_watermelon',
            harvest = 'maximgm_watermelon',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01b'),
                [2] = joaat('bkr_prop_weed_med_01a'),
                [3] = joaat('bkr_prop_weed_med_01b'),
                [4] = joaat('bkr_prop_weed_lrg_01a'),
                [5] = joaat('bkr_prop_weed_lrg_01b')
            },
            stageZOffset = {
                [1] = -0.2,
                [2] = -0.25,
                [3] = -0.3,
                [4] = -0.35,
                [5] = -0.4,
            },
            growTime = 10,
            harvestAmount = {1, 2},
            fertilizerBonus = 60,
        },
        cannabis = {
            seed = 'maximgm_seed_cannabis',
            harvest = 'maximgm_cannabis_bud',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01b'),
                [2] = joaat('bkr_prop_weed_med_01a'),
                [3] = joaat('bkr_prop_weed_med_01b'),
                [4] = joaat('bkr_prop_weed_lrg_01a'),
                [5] = joaat('bkr_prop_weed_lrg_01b')
            },
            stageZOffset = {
                [1] = -0.5,
                [2] = -0.55,
                [3] = -0.6,
                [4] = -0.65,
                [5] = -0.7,
            },
            growTime = 2,
            harvestAmount = {1, 3},
            fertilizerBonus = 70,
        },
        wheat = {
            seed = 'maximgm_seed_wheat',
            harvest = 'maximgm_wheat',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01b'),
                [2] = joaat('bkr_prop_weed_med_01a'),
                [3] = joaat('bkr_prop_weed_med_01b'),
                [4] = joaat('bkr_prop_weed_lrg_01a'),
                [5] = joaat('bkr_prop_weed_lrg_01b')
            },
            stageZOffset = {
                [1] = -0.7,
                [2] = -0.75,
                [3] = -0.8,
                [4] = -0.85,
                [5] = -0.9,
            },
            growTime = 5,
            harvestAmount = {4, 8},
            fertilizerBonus = 30,
        },
        corn = {
            seed = 'maximgm_seed_corn',
            harvest = 'maximgm_corn',
            fertilizer = 'maximgm_fertilizer',
            water = 'maximgm_water_bottle',
            props = {
                [1] = joaat('bkr_prop_weed_01_small_01b'),
                [2] = joaat('bkr_prop_weed_med_01a'),
                [3] = joaat('bkr_prop_weed_med_01b'),
                [4] = joaat('bkr_prop_weed_lrg_01a'),
                [5] = joaat('bkr_prop_weed_lrg_01b')
            },
            stageZOffset = {
                [1] = -0.4,
                [2] = -0.45,
                [3] = -0.5,
                [4] = -0.55,
                [5] = -0.6,
            },
            growTime = 9,
            harvestAmount = {2, 4},
            fertilizerBonus = 35,
        },
    },

    --- Ground MaterialHash (valid planting surfaces)
    GroundHashes = {
        [1333033863] = true,
        [-1286696947] = true,
        [223086562] = true,
        [-1885547121] = true,
        [-461750719] = true,
        [951832588] = true,
        [-1942898710] = true,
        [510490462] = true,
    },

    --- Growing Related Settings (OPTIMIZED)
    SpawnRadius = 50.0, -- REDUCED from 75.0 to reduce checks (plants spawn when closer)
    rayCastingDistance = 20.0,
    MinPlantDistance = 1.0, -- Minimum distance between plants (used in row planting too)
    ClearOnStartup = true,
    LoopUpdate = 15,
    WaterDecay = 0.5,
    FertilizerDecay = 0.5,

    FertilizerThreshold = 50,
    WaterThreshold = 40,
    HealthBaseDecay = {10, 13},
}

Config.PlantHealth = {
    -- ── Status Threshold ────────────────────────────
    HealthyThreshold = 60,  -- > 60%  = 🟢 Healthy
    DyingThreshold   = 30,  -- 30-60% = 🟡 Dying  |  < 30% = 🔴 Dead

    -- ── Visual Update di Client ──────────────────────
    -- Interval cek health & update tint warna prop (ms)
    VisualUpdateInterval = 15000, -- 15 detik

    -- ── Warning ke Owner ────────────────────────────
    -- Notif ke owner saat jalan dekat tanaman dying/dead
    WarnOwnerOnNearby = true,
    WarnCooldown      = 30000, -- Jeda antar warning: 30 detik (ms)

    -- ── Auto Delete Tanaman Mati ─────────────────────
    -- true  = tanaman mati otomatis dihapus saat decay tick
    -- false = tanaman mati dibiarkan, player harus hapus manual
    AutoDeleteDead = false,

    -- ── Catatan Decay (read-only, dari Config utama) ──
    -- Water habis dalam  : 100 / WaterDecay menit      → default 200 menit (~3.3 jam)
    -- Fertilizer habis   : 100 / FertilizerDecay menit → default 200 menit (~3.3 jam)
    -- Decay check setiap : LoopUpdate menit             → default 15 menit
    -- Health turun       : HealthBaseDecay per interval yang gagal → default 10-13 poin
    --
    -- Supaya tanaman tetap SEHAT:
    -- ✅ Siram sebelum air turun di bawah WaterThreshold (default 40%)
    -- ✅ Pupuk sebelum pupuk turun di bawah FertilizerThreshold (default 50%)
}
-- =============================================
-- Weather System Config
-- Terintegrasi dengan Renewed-Weathersync
-- =============================================
Config.Weather = {
    Enabled = true,

    -- Weather yang dianggap "hujan" → air otomatis terisi
    RainWeathers = {
        'RAIN', 'THUNDER', 'BLIZZARD', 'SNOWLIGHT', 'CLEARING'
    },

    -- Weather yang dianggap "panas" → health decay lebih cepat
    HotWeathers = {
        'EXTRASUNNY', 'CLEAR', 'SMOG', 'FOGGY'
    },

    -- Saat hujan: tambah water level sekian persen per LoopUpdate
    RainWaterBonus = 30.0,

    -- Saat panas: health decay multiplier (1.0 = normal, 1.5 = 50% lebih cepat)
    HotDecayMultiplier = 1.5,

    -- Interval cek weather di server (menit), sebaiknya sama dengan LoopUpdate
    CheckInterval = 15,
}