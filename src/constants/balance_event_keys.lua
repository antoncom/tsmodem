--[[
    These keys are used as balance value. Driver keep them in its state just like normal balance value.
    But web-interface uses these keys to interpretate situation and so affects UI logic.
]]
local BALANCE_EVENT_KEYS = {
  ["ussd-response-error"] = "USSD response doesn't look like balance message. <br>Please check USSD-command or template.",
  ["provider-cansel-ussd-session"] = "GSM provider cancels USSD session. <br>We will get the balance later.",
  ["sim-settings-dont-match-provider-autodetected"] = "Autodetected provider doesn't match sim-settings.",
  ["timeout-reached"] = "No USSD response containing correct balance.",
  ["get-balance-in-progress"] = "*",
}
return BALANCE_EVENT_KEYS
