#! /usr/bin/env lua

local SERVICE_NAME = "kamisadoserver"
--local SERVICE_COMMAND = "./wrapper.lua unix:/home/kamisadoserver/Kamisado/server/kamisado.socket"
local SERVICE_COMMAND = "./wrapper.lua 55559"
local USER = "$(whoami)"
local CONF = "start.conf"
--local FILE_STDOUT = SERVICE_NAME .. ".stdout"
--local FILE_STDERR = SERVICE_NAME .. ".stdout"
local FILE_STDOUT = "/dev/null"
local FILE_STDERR = "/dev/null"
local FILE_PID = SERVICE_NAME .. ".pid"
local FILE_PIDPIPE = SERVICE_NAME .. ".pidpipe"

local start_arg = ...

local config = {}
local function save_config()
	local handle = io.open(CONF, "w")
	for key, value in next, config do
		handle:write(key .. "=" .. value .. "\n")
	end
	handle:close()
end
do
	local handle = io.open(CONF, "r")
	if handle then
		local content = handle:read("*a")
		handle:close()
		for key, value in content:gmatch("([^=]+)=([^\n]+)\n") do
			config[key] = value
		end
	end
end
config.enabled = config.enabled or "false"
save_config()

local function print(msg, ...)
	io.stderr:write(msg:format(...))
end

local function is_running()
	local handle = io.open(FILE_PID)
	if handle then
		local content = handle:read("*a")
		handle:close()
		return tonumber(content)
	end
end

local function execute_service()
	local stathandle = io.open("/proc/self/stat", "r")
	local pidhandle = io.open(FILE_PID, "w")
	pidhandle:write(stathandle:read("*a"):match("^%s*(%S+)"))
	pidhandle:close()
	stathandle:close()
	local result = os.execute(SERVICE_COMMAND .. [[ >> ]] .. FILE_STDOUT .. [[ 2>> ]] .. FILE_STDERR)
	os.remove(FILE_PID)
	return result
end

local function start_service()
	local in_service_pid = is_running()
	if in_service_pid then
		print("Service %s already started (%i)\n", SERVICE_NAME, in_service_pid)
		return 8
	end
	
	os.execute([[./start.lua execute &]])
	do
		for ix = 1, 20 do
			if is_running() then
				break
			end
			os.execute("sleep 0.05")
		end
	end
	
	local service_pid = is_running()
	if service_pid then
		print("Service %s started (%i)\n", SERVICE_NAME, service_pid)
		return 0
	else
		print("Failed to start service %s\n", SERVICE_NAME)
		return 2
	end
end

local function stop_service()
	local in_service_pid = is_running()
	if not in_service_pid then
		print("Service %s already stopped\n", SERVICE_NAME)
		return 8
	end
	
	local idhandle = io.popen([[pgrep -g `ps --no-headers -p ]] .. in_service_pid .. [[ -o pgrp`]])
	local ids = idhandle:read("*a")
	idhandle:close()
	
	local ids_to_kill = {}
	for idstr in ids:gmatch("%S+") do
		local id = tonumber(idstr)
		if id ~= in_service_pid then
			table.insert(ids_to_kill, id)
		end
	end
	
	os.execute([[kill ]] .. table.concat(ids_to_kill, " ") .. [[ > /dev/null 2> /dev/null]])
	os.remove(FILE_PID)
	
	print("Service %s stopped\n", SERVICE_NAME)
	return 0
end

if start_arg == "start" then
	return start_service()
	
elseif start_arg == "stop" then
	return stop_service()
	
elseif start_arg == "restart" then
	stop_service()
	return start_service()
	
elseif start_arg == "execute" then
	return execute_service()
	
elseif start_arg == "enable" then
	print("Service %s enabled\n", SERVICE_NAME)
	config.enabled = "true"
	save_config()
	return 0
	
elseif start_arg == "disable" then
	print("Service %s disabled\n", SERVICE_NAME)
	config.enabled = "false"
	save_config()
	return 0
	
elseif start_arg == "autostart" then
	if config.enabled == "true" then
		return start_service()
	else
		return 16
	end
	
else
	print("Invalid start_arg: %s\n", start_arg or "")
	return -1
end


