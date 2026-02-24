utils = {}

utils.print = function(message)
    print('^3[MaximGM-Farming] ^5' .. message .. '^7')
end

utils.notify = function(source, title, message, notifType, timeOut)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        duration = timeOut,
        type = notifType,
        position = 'center-right',
    })
end