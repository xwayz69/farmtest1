--- Plot System - Identifier Bridge
--- Fetches and caches local player's identifier for plot ownership checks

CreateThread(function()
    Wait(3000)

    -- Ask server for our own identifier
    local identifier = lib.callback.await('maximgm-farming:server:Plot:GetMyIdentifier', 3000)
    if identifier then
        _G.MyPlotIdentifier = identifier
        utils.print('Plot ownership identifier cached: ' .. identifier)
    end
end)