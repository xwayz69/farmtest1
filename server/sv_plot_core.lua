--- Plot System - Server Core (PRIVATE)
--- Plot adalah 100% privat. Setiap player hanya bisa akses plot miliknya sendiri.
--- Server menjadi satu-satunya authority untuk semua validasi ownership.

--- Global Plot Cache server-side (berisi SEMUA plot dari semua player)
--- Digunakan hanya untuk validasi server-side (jarak antar plot, plant placement, dsb)
_G.PlotCache = {}
local PlotCache = _G.PlotCache

--- @type table<number, Plot>
local Plots = {}

--- @class Plot
--- @field id number
--- @field owner string Identifier player pemilik
--- @field coords vector3
--- @field tier number
--- @field time number
local Plot = {}
Plot.__index = Plot

-- =============================================
-- Plot Class - Internal Methods
-- =============================================

--- Buat instance Plot di memory (TIDAK insert ke DB)
function Plot:create(id, owner, coords, tier, time)
    local plot = setmetatable({}, Plot)

    plot.id     = id
    plot.owner  = owner
    plot.coords = coords
    plot.tier   = tier or 1
    plot.time   = time or os.time()

    Plots[id] = plot

    -- Server-side cache untuk validasi internal
    PlotCache[id] = {
        id     = id,
        owner  = owner,
        coords = coords,
        tier   = tier or 1,
    }

    return plot
end

--- Insert plot baru ke DB lalu buat instance
--- @param owner string Identifier player
--- @param coords vector3
--- @param tier number
--- @return Plot|false, string|nil
function Plot:new(owner, coords, tier)
    tier = tier or 1
    local time = os.time()

    local id = MySQL.insert.await([[
        INSERT INTO `maximgm_plots` (`owner`, `coords`, `tier`, `time`)
        VALUES (:owner, :coords, :tier, :time)
    ]], {
        owner  = owner,
        coords = json.encode({ x = coords.x, y = coords.y, z = coords.z }),
        tier   = tier,
        time   = os.date('%Y-%m-%d %H:%M:%S', time),
    })

    if not id then
        return false, 'Failed to insert plot into database'
    end

    local plot = Plot:create(id, owner, coords, tier, time)

    -- Broadcast ke SEMUA client agar semua player bisa lihat prop box
    TriggerClientEvent('maximgm-farming:client:Plot:New', -1, id, owner, coords, tier)

    utils.print(string.format('New plot created: ID=%d Owner=%s Tier=%d', id, owner, tier))
    return plot
end

--- Hapus plot dari DB dan memory
function Plot:remove()
    local id    = self.id
    local owner = self.owner

    MySQL.query.await('DELETE FROM `maximgm_plots` WHERE `id` = :id', { id = id })

    Plots[id]     = nil
    PlotCache[id] = nil

    -- Broadcast ke SEMUA client agar prop box hilang di semua player
    TriggerClientEvent('maximgm-farming:client:Plot:Remove', -1, id)
end

--- Simpan state ke DB
function Plot:save()
    local rows = MySQL.update.await([[
        UPDATE `maximgm_plots` SET
            `tier`   = :tier,
            `coords` = :coords
        WHERE `id` = :id
    ]], {
        tier   = self.tier,
        coords = json.encode({ x = self.coords.x, y = self.coords.y, z = self.coords.z }),
        id     = self.id,
    })
    return rows > 0
end

--- Cari source (player ID) berdasarkan identifier
--- @param identifier string
--- @return number|nil
function Plot:_findSourceByIdentifier(identifier)
    for _, playerId in ipairs(GetPlayers()) do
        local src    = tonumber(playerId)
        local Player = server.GetPlayerFromId(src)
        if Player then
            local data = server.getPlayerData(Player)
            if data and data.identifier == identifier then
                return src
            end
        end
    end
    return nil
end

--- Get plot by ID
function Plot:getPlot(id)
    return Plots[id]
end

--- Get semua plot milik satu identifier
--- @param identifier string
--- @return Plot[]
function Plot:getPlayerPlots(identifier)
    local result = {}
    for _, plot in pairs(Plots) do
        if plot.owner == identifier then
            result[#result + 1] = plot
        end
    end
    return result
end

--- Hitung jumlah plot milik identifier
--- @param identifier string
--- @return number
function Plot:countPlayerPlots(identifier)
    local count = 0
    for _, plot in pairs(Plots) do
        if plot.owner == identifier then
            count = count + 1
        end
    end
    return count
end

--- Cari plot milik identifier yang mencakup coords ini
--- @param coords vector3
--- @param identifier string
--- @return Plot|nil, table|nil tierConfig
function Plot:getOwnerPlotAtCoords(coords, identifier)
    for _, plot in pairs(Plots) do
        if plot.owner == identifier then
            local tierConfig = Config.Plots.tiers[plot.tier]
            if tierConfig then
                local dist = #(coords - plot.coords)
                if dist <= tierConfig.radius then
                    return plot, tierConfig
                end
            end
        end
    end
    return nil, nil
end

--- Cek apakah ada plot (milik siapapun) yang terlalu dekat
--- @param coords vector3
--- @return boolean, number
function Plot:isAnyPlotTooClose(coords)
    for _, plot in pairs(Plots) do
        local dist = #(coords - plot.coords)
        if dist < Config.Plots.minPlotDistance then
            return true, dist
        end
    end
    return false, 0
end

-- =============================================
-- Load plots dari DB saat startup
-- =============================================
local function setupPlots()
    local result = MySQL.Sync.fetchAll('SELECT * FROM `maximgm_plots`')

    local count = 0
    for _, data in pairs(result) do
        local coords = json.decode(data.coords)
        if coords then
            Plot:create(
                data.id,
                data.owner,
                vector3(coords.x, coords.y, coords.z),
                data.tier,
                data.time
            )
            count = count + 1
        end
    end

    utils.print(string.format('Loaded %d plots from database', count))
end

-- Expose ke global
_G.Plot = Plot

CreateThread(function()
    Wait(2500)
    setupPlots()
end)

-- =============================================
-- Kirim data plot ke player yang baru join
-- Dipanggil saat player load (dari callback GetMine)
-- =============================================

--- Saat player join, kirim HANYA plot miliknya sendiri
AddEventHandler('playerConnecting', function()
    -- Ini tidak cukup karena player belum fully loaded
    -- Kita handle via callback GetMine di bawah
end)

-- =============================================
-- Server Events
-- =============================================

--- Place Plot
RegisterNetEvent('maximgm-farming:server:Plot:Place', function(coords)
    local src    = source

    -- ✅ SERVER JOB CHECK
    if not jobGuard(src) then return end

    local Player = server.GetPlayerFromId(src)
    if not Player then return end

    local PlayerData   = server.getPlayerData(Player)
    local identifier   = PlayerData.identifier

    -- Validasi coords
    if not coords or type(coords) ~= 'vector3' then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.rayCastingDistance + 10 then return end

    -- Cek max plots per player
    if _G.Plot:countPlayerPlots(identifier) >= Config.Plots.maxPlotsPerPlayer then
        utils.notify(src, Locales['notify_title_farming'],
            Locales['plot_max_reached'] or 'You have reached the maximum number of plots!',
            'error', 4000)
        return
    end

    -- Cek jarak ke plot lain (siapapun pemiliknya)
    local tooClose, dist = _G.Plot:isAnyPlotTooClose(coords)
    if tooClose then
        utils.notify(src, Locales['notify_title_farming'],
            string.format(Locales['plot_too_close'] or 'Too close to another plot! (%.1fm)', dist),
            'error', 3000)
        return
    end

    -- Cek farming zone (opsional)
    -- Server-side zone check bisa ditambahkan di sini jika diperlukan

    -- Hapus item plot dari inventory
    if not server.removeItem(src, Config.Plots.plotItem, 1) then
        utils.notify(src, Locales['notify_title_farming'],
            Locales['plot_no_item'] or "You don't have a plot item!",
            'error', 3000)
        return
    end

    local plot = _G.Plot:new(identifier, coords, 1)
    if not plot then
        -- Kembalikan item jika gagal insert
        server.addItem(src, Config.Plots.plotItem, 1)
        utils.notify(src, Locales['notify_title_farming'],
            'Failed to create plot, try again.', 'error', 3000)
        return
    end

    utils.notify(src, Locales['notify_title_farming'],
        Locales['plot_placed'] or 'Farm plot placed!', 'success', 3000)

    server.createLog(PlayerData.name, 'Plot Placed',
        string.format('%s (%s) placed plot ID=%d at %s', PlayerData.name, identifier, plot.id, tostring(coords)))
end)

--- Remove Plot
RegisterNetEvent('maximgm-farming:server:Plot:Remove', function(plotId)
    local src    = source

    -- ✅ SERVER JOB CHECK
    if not jobGuard(src) then return end

    local Player = server.GetPlayerFromId(src)
    if not Player then return end

    local PlayerData = server.getPlayerData(Player)
    local plot       = _G.Plot:getPlot(plotId)
    if not plot then return end

    -- Hanya pemilik yang bisa remove
    if plot.owner ~= PlayerData.identifier then
        utils.notify(src, Locales['notify_title_farming'],
            Locales['plot_not_owner'] or 'You do not own this plot!', 'error', 3000)
        return
    end

    -- Cek apakah masih ada plant di dalam plot
    local tierConfig = Config.Plots.tiers[plot.tier]
    if tierConfig and _G.PlantCache then
        for _, plantData in pairs(_G.PlantCache) do
            if plantData and plantData.coords then
                local dist = #(plot.coords - plantData.coords)
                if dist <= tierConfig.radius then
                    utils.notify(src, Locales['notify_title_farming'],
                        Locales['plot_has_plants'] or 'Remove all plants inside the plot first!',
                        'error', 4000)
                    return
                end
            end
        end
    end

    plot:remove()

    -- Kembalikan item plot
    server.addItem(src, Config.Plots.plotItem, 1)
    utils.notify(src, Locales['notify_title_farming'],
        Locales['plot_removed'] or 'Plot removed. Item returned.', 'success', 3000)

    server.createLog(PlayerData.name, 'Plot Removed',
        string.format('%s (%s) removed plot ID=%d', PlayerData.name, PlayerData.identifier, plotId))
end)

--- Upgrade Plot
RegisterNetEvent('maximgm-farming:server:Plot:Upgrade', function(plotId)
    local src    = source

    -- ✅ SERVER JOB CHECK
    if not jobGuard(src) then return end

    local Player = server.GetPlayerFromId(src)
    if not Player then return end

    local PlayerData = server.getPlayerData(Player)
    local plot       = _G.Plot:getPlot(plotId)
    if not plot then return end

    -- Hanya pemilik
    if plot.owner ~= PlayerData.identifier then
        utils.notify(src, Locales['notify_title_farming'],
            Locales['plot_not_owner'] or 'You do not own this plot!', 'error', 3000)
        return
    end

    local currentTierConfig = Config.Plots.tiers[plot.tier]
    if not currentTierConfig then return end

    -- Cek sudah tier max
    if not currentTierConfig.upgradeItem or not Config.Plots.tiers[plot.tier + 1] then
        utils.notify(src, Locales['notify_title_farming'],
            Locales['plot_max_tier'] or 'This plot is already at maximum tier!', 'error', 3000)
        return
    end

    -- Cek dan ambil upgrade item
    if not server.removeItem(src, currentTierConfig.upgradeItem, 1) then
        utils.notify(src, Locales['notify_title_farming'],
            string.format(
                Locales['plot_no_upgrade_item'] or 'You need a %s to upgrade!',
                currentTierConfig.upgradeItem
            ), 'error', 3000)
        return
    end

    local newTier = plot.tier + 1
    plot.tier = newTier
    plot:save()

    -- Update PlotCache server-side juga
    if PlotCache[plotId] then
        PlotCache[plotId].tier = newTier
    end

    -- Sync HANYA ke pemilik
    -- Broadcast ke SEMUA client agar semua player lihat perubahan tier/prop
    TriggerClientEvent('maximgm-farming:client:Plot:UpdateTier', -1, plotId, newTier)

    local newTierConfig = Config.Plots.tiers[newTier]
    utils.notify(src, Locales['notify_title_farming'],
        string.format(
            Locales['plot_upgraded'] or 'Plot upgraded to %s! (Max plants: %d)',
            newTierConfig.name, newTierConfig.maxPlants
        ), 'success', 4000)

    server.createLog(PlayerData.name, 'Plot Upgraded',
        string.format('%s upgraded plot %d to tier %d', PlayerData.name, plotId, newTier))
end)

-- =============================================
-- Callbacks
-- =============================================

--- Return SEMUA plot ke semua client (untuk render prop box)
lib.callback.register('maximgm-farming:server:Plot:GetAll', function(source)
    local result = {}
    for id, data in pairs(_G.PlotCache) do
        result[id] = {
            id     = data.id,
            owner  = data.owner,
            coords = data.coords,
            tier   = data.tier,
        }
    end
    return result
end)

--- Validasi plant placement di dalam plot milik player
--- Dipanggil dari sv_events.lua sebelum _G.Plant:new()
lib.callback.register('maximgm-farming:server:Plot:ValidatePlantPlacement', function(source, coords)
    local Player = server.GetPlayerFromId(source)
    if not Player then return false, 'no_player' end

    local PlayerData = server.getPlayerData(Player)
    local identifier = PlayerData.identifier

    -- Cari plot milik player yang mencakup coords ini
    local plot, tierConfig = _G.Plot:getOwnerPlotAtCoords(coords, identifier)

    if not plot then
        return false, 'not_in_plot'
    end

    -- Hitung plant yang sudah ada di dalam plot ini
    local plantCount = 0
    if _G.PlantCache then
        for _, plantData in pairs(_G.PlantCache) do
            if plantData and plantData.coords then
                local dist = #(plot.coords - plantData.coords)
                if dist <= tierConfig.radius then
                    plantCount = plantCount + 1
                end
            end
        end
    end

    if plantCount >= tierConfig.maxPlants then
        return false, 'plot_full'
    end

    return true, plot.id
end)

--- Kembalikan identifier player ke client (untuk ownership display)
lib.callback.register('maximgm-farming:server:Plot:GetMyIdentifier', function(source)
    local Player = server.GetPlayerFromId(source)
    if not Player then return nil end
    local PlayerData = server.getPlayerData(Player)
    return PlayerData.identifier
end)

--- Get info satu plot (untuk menu, validasi ownership di server)
lib.callback.register('maximgm-farming:server:Plot:GetInfo', function(source, plotId)
    local Player = server.GetPlayerFromId(source)
    if not Player then return nil end

    local PlayerData = server.getPlayerData(Player)
    local plot       = _G.Plot:getPlot(plotId)

    if not plot then return nil end

    -- Hanya pemilik yang bisa get info detail
    if plot.owner ~= PlayerData.identifier then
        return nil
    end

    local tierConfig = Config.Plots.tiers[plot.tier]

    -- Hitung plants di dalam plot ini
    local plantCount = 0
    if _G.PlantCache and tierConfig then
        for _, plantData in pairs(_G.PlantCache) do
            if plantData and plantData.coords then
                local dist = #(plot.coords - plantData.coords)
                if dist <= tierConfig.radius then
                    plantCount = plantCount + 1
                end
            end
        end
    end

    return {
        id         = plot.id,
        tier       = plot.tier,
        tierName   = tierConfig and tierConfig.name or 'Unknown',
        maxPlants  = tierConfig and tierConfig.maxPlants or 0,
        radius     = tierConfig and tierConfig.radius or 0,
        plantCount = plantCount,
        upgradeItem = tierConfig and tierConfig.upgradeItem or nil,
        isMaxTier  = (tierConfig and tierConfig.upgradeItem == nil),
        nextTier   = Config.Plots.tiers[plot.tier + 1] or nil,
    }
end)