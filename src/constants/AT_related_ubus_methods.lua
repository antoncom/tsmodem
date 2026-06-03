-- Список методов, которые допустимо указывать при вызове команды отладки вида "tsmodem debug reg"

local AT_RELATED_UBUS_METHODS = {
    "netmode",
    "reg",
    "balance",
    "provider_name",
    "signal",
    "send_at"
}
return AT_RELATED_UBUS_METHODS
