--- server/sv_job_check.lua
--- Server-side job validation
--- ✅ FIX: Baca job via server.getPlayerData() yang sudah include job field

-- =============================================
-- Core Job Check Function
-- =============================================

local function hasAllowedJob(source)
    -- Jika job system dinonaktifkan → semua boleh
    if not Config.EnableJobSystem then
        return true
    end

    local Player = server.GetPlayerFromId(source)
    if not Player then
        return false
    end

    local jobName = nil

    -- ✅ FIX: Ambil via getPlayerData() yang sudah di-patch include 'job' field
    -- Ini works untuk QBCore, QBox, maupun ESX karena semua bridge
    -- sekarang return { identifier, name, job, ... }
    local PlayerData = server.getPlayerData(Player)

    if PlayerData and PlayerData.job then
        jobName = PlayerData.job.name
    end

    -- Fallback: baca langsung dari Player object kalau getPlayerData tidak return job
    if not jobName then
        if Config.Framework == 'esx' then
            -- ESX: Player.job.name
            jobName = Player.job and Player.job.name
        elseif Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
            -- QBCore/QBox: Player.PlayerData.job.name
            jobName = Player.PlayerData
                and Player.PlayerData.job
                and Player.PlayerData.job.name
        end
    end

    if not jobName then
        print(string.format('^1[MaximGM-Farming]^7 WARNING: Could not read job for source %d', source))
        return false
    end

    local allowed = Config.AllowedJobs[jobName] == true

    -- Debug log (aktifkan saat testing, comment setelah oke)
    -- print(string.format('[JobCheck] source=%d job=%s allowed=%s', source, jobName, tostring(allowed)))

    return allowed
end

-- =============================================
-- Callback: Client cek job mereka sendiri
-- =============================================

lib.callback.register('maximgm_farming:server:checkJob', function(source)
    return hasAllowedJob(source)
end)

-- =============================================
-- Job Guard Helper
-- Dipakai di sv_events.lua, sv_plot_core.lua, sv_interactions.lua
-- =============================================

function jobGuard(source, callback)
    if not hasAllowedJob(source) then
        utils.notify(
            source,
            Locales['notify_title_farming'] or 'Farming',
            Config.JobDeniedMessage or 'You need a farming job to do that!',
            'error',
            4000
        )
        return false
    end
    if callback then callback() end
    return true
end

-- =============================================
-- Debug Command (server console)
-- Ketik: maximgm_checkjob [playerid]
-- =============================================

RegisterCommand('maximgm_checkjob', function(_, args)
    local targetId = tonumber(args[1])
    if not targetId then
        print('Usage: maximgm_checkjob [playerid]')
        return
    end

    local Player = server.GetPlayerFromId(targetId)
    if not Player then
        print('Player not found: ' .. targetId)
        return
    end

    local PlayerData = server.getPlayerData(Player)
    local directJob  = nil

    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        directJob = Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name
    elseif Config.Framework == 'esx' then
        directJob = Player.job and Player.job.name
    end

    print(string.format(
        '[JobCheck Debug] source=%d | via getPlayerData: %s | direct: %s | allowed: %s',
        targetId,
        tostring(PlayerData and PlayerData.job and PlayerData.job.name),
        tostring(directJob),
        tostring(hasAllowedJob(targetId))
    ))
end, true)

-- =============================================
-- Export
-- =============================================

exports('hasAllowedFarmingJob', hasAllowedJob)

print('^2[MaximGM-Farming]^7 Server-side job checking loaded')

return hasAllowedJob