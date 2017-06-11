#! /usr/bin/env luajit

local args = {...}

local LOG_PATH = "log.log"
local LOG_BACKUP_PATH = "log.log1"
local LOG_SWAP_THRESHOLD = 1048576

local lfs = require("lfs")

local log_handle = io.open(LOG_PATH, "a")
function print(...)
	local safe_tbl = {}
	for key, value in next, {...} do
		safe_tbl[key] = tostring(value)
	end
	log_handle:write(("[%s] %s\n"):format(
		os.date("%c", os.time()),
		table.concat(safe_tbl, "\t")
	))
	log_handle:flush()
	
	if lfs.attributes(LOG_PATH).size > LOG_SWAP_THRESHOLD then
		log_handle:close()
		log_handle = io.open(LOG_PATH, "r")
		local log_backup_handle = io.open(LOG_BACKUP_PATH, "w")
		log_backup_handle:write(log_handle:read("*a"))
		log_backup_handle:close()
		log_handle:close()
		log_handle = io.open(LOG_PATH, "a")
	end
end

xpcall(function()
	loadfile("server.lua")(unpack(args))
end, function(err)
	print("Top level exception: " .. err)
	print(debug.traceback())
	os.exit(1)
end)

log_handle:close()

