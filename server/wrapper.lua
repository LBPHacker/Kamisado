#! /usr/bin/env luajit

local args = {...}

function print(...)
	local safe_tbl = {}
	for key, value in pairs({...}) do
		safe_tbl[key] = tostring(value)
	end
	io.stderr:write(table.concat(safe_tbl, "\t") .. "\n")
end

xpcall(function()
	loadfile("server.lua")(unpack(args))
end, function(err)
	print("Top level exception: " .. err)
	print(debug.traceback())
	os.exit(1)
end)

