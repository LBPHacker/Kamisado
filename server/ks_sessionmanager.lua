local ks_timer = require("ks_timer")

local PING_TIMER_TIMEOUT = 60
local KILL_TIMER_TIMEOUT = 90

local session_i = {}
local session_m = {__index = session_i}

function session_i:close()
	self.kill_timer:cancel()
	self.ping_timer:cancel()
	self.protocol:session_close(self)
	self.sessionmanager.ws_to_session[self.websocket] = nil
	self.websocket:close()
	--printf("[SMGR] closed session %s", tostring(self))
end

function session_i:message(message)
	self.protocol:session_message(self, message)
end

function session_i:send(message)
	self.websocket:send(message)
end

function session_i:ping_callback()
	self.ping_timer:cancel()
	self.protocol:send_ping(self)
	self.ping_timer = ks_timer.new(PING_TIMER_TIMEOUT, self.ping_callback, self)
end

function session_i:reset_kill_timer()
	self.kill_timer:cancel()
	self.kill_timer = ks_timer.new(KILL_TIMER_TIMEOUT, self.kill_callback, self)
end

function session_i:kill_callback()
	self.kill_timer:cancel()
	self.protocol:send_pingtimeout(self)
	self:close()
end


local sessionmanager_i = {}
local sessionmanager_m = {__index = sessionmanager_i}

function sessionmanager_i:open(ws)
	local new_session = setmetatable({
		websocket = ws,
		sessionmanager = self,
		protocol = self.protocol,
		ping_timer = false,
		kill_timer = false,
		endpoint = false
	}, session_m)
	
	new_session.ping_timer = ks_timer.new(PING_TIMER_TIMEOUT, new_session.ping_callback, new_session)
	new_session.kill_timer = ks_timer.new(KILL_TIMER_TIMEOUT, new_session.kill_callback, new_session)
	
	self.ws_to_session[ws] = new_session
	--printf("[SMGR] opened session %s", tostring(new_session))
	return new_session
end

function sessionmanager_i:lookup(ws)
	return self.ws_to_session[ws]
end

return {
	new = function(protocol)
		return setmetatable({
			protocol = protocol,
			ws_to_session = {}
		}, sessionmanager_m)
	end
}

