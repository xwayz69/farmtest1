--- Plot System Configuration

Config.Plots = {
    --- Item yang dipakai untuk place plot
    plotItem = 'maximgm_plot',

    --- Max plot per player
    maxPlotsPerPlayer = 10,

    --- Minimum jarak antar plot (meter)
    minPlotDistance = 7.0,

    --- Tiers plot
    --- plantZOffset = tinggi di atas prop box tempat tanaman di-spawn
    tiers = {
        [1] = {
            name         = 'Basic Plot',
            label        = 'Basic Farm Plot',
            maxPlants    = 4,
            radius       = 5.0,
            color        = { r = 0, g = 200, b = 0 },

            -- Prop box yang di-spawn sebagai raised bed
            -- prop_box_tea_01a = wooden crate / box (ada di base game)
            prop         = `plot`,
            propZOffset  = 0.0,       -- offset Z saat spawn prop (turunkan jika amblas)
            plantZOffset = 0.55,      -- tinggi tanaman di atas prop (di atas permukaan box)

            upgradeItem  = 'maximgm_plot_upgrade_t2',
        },
        [2] = {
            name         = 'Standard Plot',
            label        = 'Standard Farm Plot',
            maxPlants    = 9,
            radius       = 8.0,
            color        = { r = 0, g = 120, b = 255 },

            prop         = `prop_box_tea_01a`,
            propZOffset  = 0.0,
            plantZOffset = 0.55,

            upgradeItem  = 'maximgm_plot_upgrade_t3',
        },
        [3] = {
            name         = 'Advanced Plot',
            label        = 'Advanced Farm Plot',
            maxPlants    = 16,
            radius       = 12.0,
            color        = { r = 255, g = 165, b = 0 },

            prop         = `prop_box_tea_01a`,
            propZOffset  = 0.0,
            plantZOffset = 0.55,

            upgradeItem  = nil, -- max tier
        },
    },
}