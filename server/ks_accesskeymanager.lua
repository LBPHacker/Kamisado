local accesskeymanager_i = {}
local accesskeymanager_m = {__index = accesskeymanager_i}

local alphabet_str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local alphabet = {}
for pos, letter in alphabet_str:gmatch("()(.)") do
	alphabet[pos - 1] = letter
end
function accesskeymanager_i:generate()
	local random_handle = io.open("/dev/urandom", "rb")
	local keys = {}
	for ix = 1, 3 do
		local key_str
		while true do
			local key_tbl = {}
			for nx = 1, 4 do
				local random_stuff = random_handle:read(3)
				local random_value = random_stuff:byte(1) + random_stuff:byte(2) * 0x100 + random_stuff:byte(3) * 0x10000
				for bx = 1, 4 do
					table.insert(key_tbl, alphabet[bit.band(random_value, 0x3F)])
					random_value = bit.rshift(random_value, 6)
				end
			end
			key_str = table.concat(key_tbl)
			if not self.keys_in_use[key_str] then
				break
			end
		end
		self.keys_in_use[key_str] = true
		--printf("[AKMGR] reserve %s", key_str)
		keys[ix] = key_str
	end
	random_handle:close()
	return keys
end

function accesskeymanager_i:free(keys)
	for key, value in next, keys do
		self.keys_in_use[value] = nil
		--printf("[AKMGR] free %s", value)
	end
end

function accesskeymanager_i:get(key)
	return self.keys_in_use[key]
end

function accesskeymanager_i:set(key, value)
	self.keys_in_use[key] = value
	--printf("[AKMGR] set %s", key)
end

return {
	new = function()
		return setmetatable({
			keys_in_use = {}
		}, accesskeymanager_m)
	end
}

