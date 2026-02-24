--- Weather Sync Client
--- Baca weather dari GlobalState Renewed-Weathersync

local currentWeather = 'CLEAR'

local function isRainWeather(w)
    if not Config.Weather then return false end
    for _, v in ipairs(Config.Weather.RainWeathers or {}) do
        if v == w then return true end
    end
    return false
end

local function isHotWeather(w)
    if not Config.Weather then return false end
    for _, v in ipairs(Config.Weather.HotWeathers or {}) do
        if v == w then return true end
    end
    return false
end

local function syncWeather(weather)
    if not weather or weather == currentWeather then return end
    currentWeather = weather
    TriggerServerEvent('maximgm-farming:server:WeatherChanged', weather)
    print(string.format('^2[MaximGM-Farming]^7 Weather: %s (rain=%s, hot=%s)',
        weather, tostring(isRainWeather(weather)), tostring(isHotWeather(weather))))
end

-- =============================================
-- Baca dari GlobalState (Renewed set globalState.weather.weather)
-- Di FiveM: GlobalState = globalState
-- =============================================
local function fetchWeather()
    -- Cara 1: GlobalState.weather (Renewed-Weathersync set ini)
    local weatherState = GlobalState.weather
    if weatherState then
        local w = nil
        if type(weatherState) == 'table' then
            w = weatherState.weather
        elseif type(weatherState) == 'string' then
            w = weatherState
        end
        if w and type(w) == 'string' then
            return w:upper()
        end
    end

    -- Cara 2: GlobalState langsung dengan key berbeda
    local w2 = GlobalState.currentWeather or GlobalState.weatherType
    if w2 and type(w2) == 'string' then
        return w2:upper()
    end

    return nil
end

-- =============================================
-- Main loop
-- =============================================
CreateThread(function()
    Wait(5000)

    local w = fetchWeather()
    if w then
        print('^3[MaximGM-Farming]^7 Initial weather: ' .. w)
        syncWeather(w)
    else
        print('^1[MaximGM-Farming]^7 Could not fetch weather from GlobalState!')
        print('^3[MaximGM-Farming]^7 Run "debugweather" for more info')
    end

    while true do
        Wait(30000)
        local weather = fetchWeather()
        if weather then syncWeather(weather) end
    end
end)

-- StateBag listener - auto update saat weather berubah
AddStateBagChangeHandler('weather', 'global', function(_, _, value)
    if not value then return end
    local w = nil
    if type(value) == 'table' then
        w = value.weather
    elseif type(value) == 'string' then
        w = value
    end
    if w and type(w) == 'string' then
        syncWeather(w:upper())
    end
end)

-- =============================================
-- Debug command
-- =============================================
RegisterCommand('debugweather', function()
    print('=== WEATHER DEBUG ===')
    print('currentWeather = ' .. currentWeather)
    print('GlobalState.weather = ' .. tostring(GlobalState.weather))
    if type(GlobalState.weather) == 'table' then
        print('GlobalState.weather.weather = ' .. tostring(GlobalState.weather.weather))
    end
    print('GlobalState.currentWeather = ' .. tostring(GlobalState.currentWeather))
    print('GetCloudHatOpacity = ' .. tostring(GetCloudHatOpacity()))
    print('=====================')
end, false)

-- =============================================
-- Exports
-- =============================================
exports('getCurrentWeather', function() return currentWeather end)
exports('isRaining', function() return isRainWeather(currentWeather) end)
exports('isHot', function() return isHotWeather(currentWeather) end)

print('^2[MaximGM-Farming]^7 Weather client loaded!')