local ev = require("ev")

local timer_i = {}
local timer_m = {__index = timer_i}

function timer_i:timeout()
	--printf("[TIMER] timeout on %s", tostring(self))
	self:cancel()
	-- * NOTE: weird self-call so I'll remember that self is passed
	local ok, err = pcall(self.callback_func, self)
	if not ok then
		printf(err)
		error(err)
	end
end

function timer_i:cancel()
	--printf("[TIMER] cancelling %s", tostring(self))
	self.ev_timer:stop(ev.Loop.default)
end

return {
	new = function(after_seconds, callback_func, ...)
		local args = {...}
		local new_timer = setmetatable({
			ev_timer = false,
			callback_func = function()
				callback_func(unpack(args))
			end
		}, timer_m)
		local ev_timer = ev.Timer.new(function(loop, timer)
			new_timer:timeout()
		end, after_seconds)
		new_timer.ev_timer = ev_timer
		--printf("[TIMER] starting %s, expecting timeout after %i seconds", tostring(new_timer), after_seconds)
		ev_timer:start(ev.Loop.default, true)
		return new_timer
	end
}

