local M = {}

function M:printTable(t, indent)  -- Обратите внимание на двоеточие в объявлении
    indent = indent or 0
    local formatting = string.rep("  ", indent)

    for key, value in pairs(t) do
        if type(value) == "table" then
            print(formatting .. tostring(key) .. ":")
            self:printTable(value, indent + 1)  -- Вызов через двоеточие
        else
            print(formatting .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

function M:UbusValidateInputData(msg)  -- Двоеточие в объявлении
    local direction_valid = (msg.direction == "in" or msg.direction == "out")
    local trigger_valid = true
    if msg.direction == "in" then
        trigger_valid = (msg.trigger == "none" or msg.trigger == "rising" or
                         msg.trigger == "falling" or msg.trigger == "both")
    end
    return direction_valid and trigger_valid
end

return M