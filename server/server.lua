#! /usr/bin/env luajit

local args = {...}
local port_unix = args[1]:match("^unix:(.+)$")
local port_numeric = (not port_unix) and tonumber(args[1]) or nil

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

if port_unix then
	os.remove(port_unix)
end
local server = websocket.server.ev.listen({
	-- don't mind this, this will only work on my server
	-- yes I rigged luawebsocket
	socketfactory = port_unix and function()
		local socket_unix = require("socket.unix")
		local socket, err = socket_unix()
		if not socket then
			return nil, err
		end
		local ok, err = socket:bind(port_unix)
		if not ok then
			return nil, err
		end
		local ok, err = socket:listen(32)
		if not ok then
			return nil, err
		end
		return socket
	end,
	port = port_numeric,
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

