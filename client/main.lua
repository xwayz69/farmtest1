--- Main Client Loader
--- This file verifies all client modules are loaded

CreateThread(function()
    Wait(1500)
    
    if _G.InsideZone ~= nil and _G.PlantClass and _G.Planting then
        print('^2[MaximGM-Farming]^7 All systems ready!')
    else
        print('^1[MaximGM-Farming]^7 ERROR: Some modules failed to load!')
    end
end)