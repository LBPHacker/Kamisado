local ks_timer = require("ks_timer")

local CLEANUP_TIMER_TIMEOUT = 86400

local game_i = {}
local game_m = {__index = game_i}

function game_i:endpoint_join(game_endpoint, session)
	self.protocol:send_joined(session)
	
	local key1, key2, key3
	
	if game_endpoint.session_set then
		game_endpoint.session_set[session] = true
		game_endpoint.game.viewers = game_endpoint.game.viewers + 1
		key1, key2, key3 = ".", ".", game_endpoint.game.keys[3]
	else
		game_endpoint.session = session
		key1, key2, key3 = game_endpoint.game.keys[1], game_endpoint.game.keys[2], game_endpoint.game.keys[3]
	end
	
	self.protocol:send_setup(session, {
		game_type = self.game_type,
		endpoint_id = game_endpoint.endpoint_id,
		board_size = self.board.size,
		score_target = self.board.score_target,
		board_fields = self.board.field_coll,
		board_towers = self.board.tower_coll
	})
	self.protocol:send_keys(session, key1, key2, key3)
	
	self:update_status_cache()
	self:to_all_sessions(self.protocol.send_status, self.status_cache)
	self:manage_cleanup_timer()
	
	if game_endpoint.endpoint_id == game_endpoint.game:player_turn() then
		self.protocol:send_choices(session, self:choices_assoc())
	end
end

function game_i:endpoint_leave(game_endpoint, session)
	self.protocol:send_left(session)
	
	if game_endpoint.session_set then
		game_endpoint.session_set[session] = nil
		game_endpoint.game.viewers = game_endpoint.game.viewers - 1
	else
		game_endpoint.session = false
	end
	
	self:update_status_cache()
	self:to_all_sessions(self.protocol.send_status, self.status_cache)
	self:manage_cleanup_timer()
end

function game_i:player_turn()
	return self.board.player_turn
end

function game_i:winner()
	return self.board.winner
end

function game_i:choices_assoc()
	return self.board.choices_assoc
end

function game_i:choose(choice)
	local old_turn = self:player_turn()
	local choice_valid = self.board:choose(choice)
	if choice_valid then
		self:update_status_cache()
		self:to_all_sessions(self.protocol.send_status, self.status_cache)
		local endpoint_old = self.endpoints[old_turn]
		if endpoint_old.session then
			self.protocol:send_clearchoices(endpoint_old.session)
		end
			
		local new_turn = self:player_turn()
		if new_turn then
			local endpoint_turn = self.endpoints[new_turn]
			if endpoint_turn.session then
				self.protocol:send_choices(endpoint_turn.session, self:choices_assoc())
			end
		end
	end
	return choice_valid
end

function game_i:manage_cleanup_timer()
	if self.endpoints[1].session or self.endpoints[2].session or next(self.endpoints[3].session_set) then
		if self.cleanup_timer then
			self.cleanup_timer:cancel()
			self.cleanup_timer = false
		end
	else
		if not self.cleanup_timer then
			self.cleanup_timer = ks_timer.new(CLEANUP_TIMER_TIMEOUT, self.cleanup_callback, self)
		end
	end
end

function game_i:cleanup_callback()
	printf("[GAME] cleanup %s", tostring(self))
	self.cleanup_timer:cancel()
	self.akmgr:free(self.keys)
end

function game_i:update_status_cache()
	self.status_cache = {
		towers = {},
		player_turn = self:player_turn(),
		score1 = self.board.players[1].score,
		score2 = self.board.players[2].score,
		winner = self:winner(),
		viewers = self.viewers
	}
	
	for tower_name, tower in next, self.board.towers do
		self.status_cache.towers[tower_name] = {
			sumo_status = tower.sumo_status,
			field = tower.field.name
		}
	end
end

function game_i:to_all_sessions(protocol_func, ...)
	if self.endpoints[1].session then
		protocol_func(self.protocol, self.endpoints[1].session, ...)
	end
	if self.endpoints[2].session then
		protocol_func(self.protocol, self.endpoints[2].session, ...)
	end
	for session in next, self.endpoints[3].session_set do
		protocol_func(self.protocol, session, ...)
	end
end

local game_types = {}
for key, value in next, {"basic8"} do
	game_types[value] = require("ks_board." .. value)
end


return {
	new = function(protocol, game_type_with_score_target)
		local game_type, score_target = game_type_with_score_target:match("^(.+)%-([^%-]+)$")
		if not game_type then
			return
		end
		score_target = tonumber(score_target)
		if not score_target then
			return
		end
		
		local board_ctor = game_types[game_type]
		if not board_ctor then
			return
		end
		
		local new_game = setmetatable({
			endpoints = {},
			board = board_ctor.new(score_target),
			game_type = game_type,
			protocol = protocol,
			akmgr = protocol.akmgr,
			viewers = 0,
			cleanup_timer = false,
			status_cache = false,
			match_coroutine = false
		}, game_m)
		new_game.keys = new_game.akmgr:generate()
		
		new_game.endpoints[1] = {
			session = false,
			session_set = false,
			access_key = new_game.keys[1],
			endpoint_id = 1,
			game = new_game
		}
		new_game.endpoints[2] = {
			session = false,
			session_set = false,
			access_key = new_game.keys[2],
			endpoint_id = 2,
			game = new_game
		}
		new_game.endpoints[3] = {
			session = false,
			session_set = {},
			access_key = new_game.keys[3],
			endpoint_id = 3,
			game = new_game
		}
		
		new_game:update_status_cache()
		
		for endpoint_id, endpoint in next, new_game.endpoints do
			new_game.akmgr:set(endpoint.access_key, endpoint)
		end
		
		new_game:manage_cleanup_timer()
		
		printf("[GAME] create %s", tostring(new_game))
		return new_game
	end
}

