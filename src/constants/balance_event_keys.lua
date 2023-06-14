--[[
    These keys are used as balance value. Driver keep them in its state just like normal balance value.
    But web-interface uses these keys to interpretate situation and so affects UI logic.
]]
local BALANCE_EVENT_KEYS = {
  ["-998"] = "USSD response doesn't look like balance message. Please check USSD-command or template.",
  ["-999"] = "GSM provider cancels USSD session. We will get the balance later.",
  ["-9999"] = "in progress",
}
return BALANCE_EVENT_KEYS
