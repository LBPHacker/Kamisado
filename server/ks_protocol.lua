local ks_game = require("ks_game")
local json = require("json")

local protocol_i = {}
local protocol_m = {__index = protocol_i}

protocol_i.action_handlers = {}

function protocol_i:send_choices(session, choices_assoc)
	self:session_send(session, {
		action = "choices",
		choices = choices_assoc
	})
end

function protocol_i:send_clearchoices(session)
	self:session_send(session, {
		action = "clearchoices"
	})
end

function protocol_i:send_setup(session, setup)
	-- * NOTE: should optimise this but meh
	self:session_send(session, {
		action = "setup",
		setup = setup
	})
end

function protocol_i:send_status(session, status)
	self:session_send(session, {
		action = "status",
		status = status
	})
end

function protocol_i:send_keys(session, key1, key2, key3)
	self:session_send(session, {
		action = "keys",
		key1 = key1,
		key2 = key2,
		key3 = key3
	})
end

function protocol_i:send_joined(session)
	self:session_send(session, {
		action = "joined"
	})
end

function protocol_i:send_left(session)
	self:session_send(session, {
		action = "left"
	})
end

function protocol_i:send_ping(session)
	self:session_send(session, {
		action = "ping"
	})
end

function protocol_i:send_pingtimeout(session)
	self:session_send(session, {
		action = "pingtimeout"
	})
end

function protocol_i.action_handlers:new(session, message_obj)
	if session.endpoint then
		-- * DEBUG
		printf("[PROTO] session %s invoked new while associated with an endpoint", tostring(session))
		return
	end
	
	message_obj.game_type = tostring(message_obj.game_type)
	local new_game = ks_game.new(self, message_obj.game_type)
	if not new_game then
		-- * DEBUG
		printf("[PROTO] session %s invoked new with unknown game type %s", tostring(session), message_obj.game_type)
		self:session_send(session, {
			action = "nogametype"
		})
		return
	end
	
	self:session_send(session, {
		action = "newkeys",
		key1 = new_game.keys[1],
		key2 = new_game.keys[2],
		key3 = new_game.keys[3]
	})
	
	for ix = 1, 3 do
		printf("[PROTO] Player %i: https://hikari.lbphacker.hu/kamisado/play/%s", ix, new_game.keys[ix])
	end
end

function protocol_i.action_handlers:join(session, message_obj)
	if session.endpoint then
		-- * DEBUG
		printf("[PROTO] session %s invoked join while associated with an endpoint", tostring(session))
		return
	end
	
	message_obj.access_key = tostring(message_obj.access_key)
	local game_endpoint = self.akmgr:get(message_obj.access_key)
	if not game_endpoint then
		-- * DEBUG
		printf("[PROTO] session %s invoked join with invalid access key %s", tostring(session), message_obj.access_key)
		self:session_send(session, {
			action = "nojoin",
			reason = "accesskey"
		})
		return
	end
	
	if game_endpoint.session then
		-- * NOTE: for now I'll just rely on the fact that pings happen every
		--         60s and we'll just end any session that didn't ping back for 90s
		-- * DEBUG
		printf("[PROTO] session %s invoked join with used access key %s", tostring(session), message_obj.access_key)
		self:session_send(session, {
			action = "nojoin",
			reason = "inuse"
		})
		return
	end
	
	game_endpoint.game:endpoint_join(game_endpoint, session)
	session.endpoint = game_endpoint
end

function protocol_i.action_handlers:leave(session)
	if not session.endpoint then
		-- * DEBUG
		printf("[PROTO] session %s invoked leave while not associated with an endpoint", tostring(session))
		return
	end
	
	session.endpoint.game:endpoint_leave(session.endpoint, session)
	session.endpoint = nil
end

function protocol_i.action_handlers:choose(session, message_obj)
	if not session.endpoint then
		-- * DEBUG
		printf("[PROTO] session %s invoked choose while not associated with an endpoint", tostring(session))
		return
	end
	
	if session.endpoint.session_set then
		-- * DEBUG
		printf("[PROTO] session %s invoked choose while associated with a viewer endpoint", tostring(session))
		return
	end
	
	message_obj.choice = tostring(message_obj.choice)
	if session.endpoint.endpoint_id == session.endpoint.game:player_turn() then
		if not session.endpoint.game:choose(message_obj.choice) then
			printf("[PROTO] session %s invoked choose with invalid choice %s", tostring(session), message_obj.choice)
			return
		end
	end
end

function protocol_i:session_send(session, message_obj)
	-- * NOTE: no pcall, let errors propagate because it's our fault if they do
	session:send(json.encode.encode(message_obj, json.encode.strict))
end

function protocol_i:session_message(session, message)
	local ok, message_obj = pcall(json.decode.decode, message, json.decode.strict)
	if not ok then
		-- * DEBUG
		self:session_send(session, {
			action = "invalidjson"
		})
		printf("[PROTO] session %s sent invalid json: %s", tostring(self), message)
		return
	end
	
	if not message_obj.action then
		printf("[PROTO] session %s sent invalid action field: %s", tostring(self), message_obj.action)
		return
	end
	
	if message_obj.action == "ping" then
		self:session_send(session, {
			action = "pong"
		})
		return
	elseif message_obj.action == "pong" then
		session:reset_kill_timer()
		return
	end
	
	
	local handler = self.action_handlers[message_obj.action]
	if handler then
		handler(self, session, message_obj)
	else
		-- * DEBUG
		printf("[PROTO] session %s invoked unknown action %s", tostring(session), tostring(message_obj.action))
	end
end

function protocol_i:session_close(session)
	if session.endpoint then
		-- * pretend that the session invoked leave
		self.action_handlers.leave(self, session)
	end
end

return {
	new = function(akmgr)
		return setmetatable({
			akmgr = akmgr,
		}, protocol_m)
	end
}

