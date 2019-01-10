#! /usr/bin/env luajit

local args = {...}

local ev = require("ev")
local websocket = require("websocket")

function printf(msg, ...)
	print(msg:format(...))
end

local akmgr = require("ks_accesskeymanager").new()
local proto = require("ks_protocol").new(akmgr)
local smgr = require("ks_sessionmanager").new(proto)

local function call_show_errors(func)
	local err_outer
	local ok = xpcall(func, function(err)
		err_outer = err
		printf(err)
		printf(debug.traceback())
	end)
	if not ok then
		error(err_outer)
	end
end

local server = websocket.server.ev.listen({
	port = 55559,
	protocols = {
		kamisado = function(ws)
			call_show_errors(function()
				smgr:open(ws)
				
				ws:on_message(function(ws, message)
					call_show_errors(function()
						local session = smgr:lookup(ws)
						if session then
							session:message(message)
						else
							--printf("[SERVER] websocket %s is not associated to a session", tostring(ws))
						end
					end)
				end)
				
				ws:on_close(function()
					call_show_errors(function()
						local session = smgr:lookup(ws)
						if session then
							session:close()
						else
							--printf("[SERVER] websocket %s is not associated to a session", tostring(ws))
						end
					end)
				end)
				
				ws:on_error(function()
					call_show_errors(function()
						local session = smgr:lookup(ws)
						if session then
							session:close()
						else
							--printf("[SERVER] websocket %s is not associated to a session", tostring(ws))
						end
					end)
				end)
			end)
		end
	}
})

printf("[SERVER] Looping away ...")
ev.Loop.default:loop()

