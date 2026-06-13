-- Функции, реализующие режим занят/свободен.
-- Это необходимо когда к сервису Tsmodem обращаются разные потребители (Tsmsms, Tsmatconsole, Tsmsmsconsole),
-- для того, чтобы потребители друг другу не мешали.

local lock = {
    owner = "",
    last_request_time = 0,
}

function lock.unlock(module_name, is_timeout)
    if lock.owner == module_name or is_timeout then
        lock.owner = ""
        lock.last_request_time = 0
        return true, "unlocked"
    elseif lock.owner == "" then
        return true, "already was unlocked"
    else
        return false, "not the owner"
    end
end

function lock.unlock_if_timeout()
    if lock.owner ~= "" and os.difftime(os.time(), lock.last_request_time) > 60 then
        lock.unlock("", true)
        if_debug("lock", "I'm unlocked on timeout.","bright_yellow")
    end
end

function lock.is_owner_or_set_if_unlocked(module_name)
    lock.unlock_if_timeout()

    if lock.owner == "" then
        lock.owner = module_name
        lock.last_request_time = os.time()

        if_debug("lock", "When free, I'm locked by: [" .. tostring(module_name) .. "]","bright_yellow")


        return true
    end

    if lock.owner == module_name then
        lock.last_request_time = os.time()
        if_debug("lock", "......","bright_yellow")
        return true
    end

    return false
end

function lock.is_automation()
    lock.unlock_if_timeout()
    return lock.owner == ""
end

function lock.is_notify()
    return lock.owner ~= ""
end

return lock
