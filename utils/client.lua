utils = {}

utils.notify = function(title, message, notifType, timeOut)
    lib.notify({
        title = title,
        description = message,
        duration = timeOut,
        type = notifType,
        position = 'center-right',
    })
end