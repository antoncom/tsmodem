local lpeg = require "lpeg"
local log = require "tsmodem.util.log"

--function not_inserted(s) return s and "false" end
--function ready(s) return s and "true" end
--function failure(s) return s and "failure" end

function not_inserted(s) return s 	and "SIM not inserted" end
function ready(s) return s 			and "SIM READY" end
function failure(s) return s 		and "SIM failure" end
function pin_required(s) return s 	and "SIM PIN required" end
function pin2_required(s) return s 	and "SIM PIN2 required" end
function puk_required(s) return s 	and "SIM PUK required" end
function puk2_required(s) return s 	and "SIM PUK2 required" end
function busy(s) return s 			and "SIM busy" end
function wrong(s) return s 			and "SIM wrong" end
function incorr_pass(s) return s 	and "Incorrect password" end


local spc = lpeg.S(" \t\n\r")^0
local sim_not_inserted = spc * lpeg.P('+CME ERROR: SIM not inserted') * spc / not_inserted
local sim_ready = spc * lpeg.P('+CPIN: READY') * spc / ready
local sim_failure = spc * lpeg.P('+CME ERROR: SIM failure') * spc / failure
local sim_pin_required = spc * lpeg.P('+CME ERROR: SIM PIN required') * spc / pin_required
local sim_pin2_required = spc * lpeg.P('+CME ERROR: SIM PIN2 required') * spc / pin2_required
local sim_puk_required = spc * lpeg.P('+CME ERROR: SIM PUK required') * spc / puk_required
local sim_puk2_required = spc * lpeg.P('+CME ERROR: SIM PUK2 required') * spc / puk2_required
local sim_busy = spc * lpeg.P('+CME ERROR: SIM busy') * spc / busy
local sim_wrong = spc * lpeg.P('+CME ERROR: SIM wrong') * spc / wrong
local sim_incorr_pass = spc * lpeg.P('+CME ERROR: Incorrect password') * spc / incorr_pass


local cpin = sim_not_inserted + sim_ready + sim_failure + sim_pin_required + sim_pin2_required + sim_puk_required + sim_busy + sim_wrong + sim_incorr_pass

return cpin

--local text = "+CME ERROR: SIM not inserted"
-- local text = "+CPIN: READY"
--local text = "+CME ERROR: (U)SIM failure"
--print(text)
--print(cpin:match(text))
