local board_i = {}
local board_m = {__index = board_i}

function board_i:choose(choice)
	if not self.choices_assoc[choice] then
		return false
	end
	local ok, err = coroutine.resume(self.match_coroutine, choice)
	if not ok then
		error(err)
	end
	return true
end

function board_i:project_choices_in_line(tower, choices, xdir)
	local ydir = tower.facing
	for id = 1, 7 - tower.sumo_status * 2 do
		local row = self.field_map[tower.field.py + id * ydir]
		if not row then
			break
		end
		local next_field = row[tower.field.px + id * xdir]
		if not next_field or next_field.occupant then
			break
		end
		choices[next_field.name] = true
	end
end

function board_i:project_choices_by_sumo_push(tower, choices)
	local ydir = tower.facing
	local cy = tower.field.py
	local towers_to_push = 0
	local highest_sumo_status = 0
	while true do
		cy = cy + ydir
		if not self.field_map[cy] then
			-- * we don't leave the loop because the push is possibe but because
			--   we're out of the play zone, so the push is impossible
			towers_to_push = math.huge
			break
		end
		
		local current_field = self.field_map[cy][tower.field.px]
		if not current_field.occupant then
			break
		end
		towers_to_push = towers_to_push + 1
		if highest_sumo_status < current_field.occupant.sumo_status then
			highest_sumo_status = current_field.occupant.sumo_status
		end
		
		if current_field.occupant.player == tower.player then
			-- * we can't push our own pieces
			towers_to_push = math.huge
			break
		end
	end
	
	if towers_to_push <= tower.sumo_status and highest_sumo_status < tower.sumo_status then
		choices[self.field_map[tower.field.py + ydir][tower.field.px].name] = true
	end
end

function board_i:project_choices(tower)
	local choices = {}
	self:project_choices_in_line(tower, choices,  1)
	self:project_choices_in_line(tower, choices,  0)
	self:project_choices_in_line(tower, choices, -1)
	self:project_choices_by_sumo_push(tower, choices)
	return choices
end

function board_i:get_choice()
	return coroutine.yield()
end

function board_i:tower_to_field_get_callee(tower, field)
	local caller_tower = tower
	if field.occupant then
		-- * perform sumo push
		local ydir = tower.facing
		local cy = tower.field.py
		while true do
			cy = cy + ydir
			local current_field = self.field_map[cy][tower.field.px]
			if not current_field.occupant then
				break
			end
			caller_tower = current_field.occupant
		end
		for iy = cy - ydir, tower.field.py + ydir, -ydir do
			self:tower_to_field(self.field_map[iy][tower.field.px].occupant, self.field_map[iy + ydir][tower.field.px])
		end
	end
	self:tower_to_field(tower, field)
	
	-- * return new callee calculated from the effective caller tower
	return self.players[caller_tower.player.other].towers[caller_tower.field.colour]
end

function board_i:tower_to_field(tower, field)
	tower.field.occupant = false
	tower.field = field
	tower.field.occupant = tower
end

function board_i:match()
	-- * black starts
	self.player_turn = 2
	
	-- * round loop
	while true do
		-- * set up round
		self.choices_assoc = {}
		for ix = 1, self.size do
			self.choices_assoc[self.field_map[self.player_turn == 1 and 1 or self.size][ix].name] = true
		end
		
		-- * move loop
		local tower_to_sumoupdate
		while true do
			-- * at this point choices_assoc is filled with fields containing callee towers
			local moving_tower = self.fields[self:get_choice()].occupant
			self.choices_assoc = self:project_choices(moving_tower)
			
			-- * at this point choices_assoc is filled with possible target fields
			local target_field = self.fields[self:get_choice()]
			local original_callee_tower = self:tower_to_field_get_callee(moving_tower, target_field)
			
			if target_field.home_of == self.players[self.player_turn].other then
				-- * the player described by player_turn wins
				tower_to_sumoupdate = moving_tower
				break
			end
			
			-- * stuck loop
			local stuck_towers = {}
			local callee_tower = original_callee_tower
			local deadlock_detected
			self.player_turn = original_callee_tower.player.me
			while true do
				if stuck_towers[callee_tower] then
					deadlock_detected = true
					break
				end
				
				if next(self:project_choices(callee_tower)) then
					break
				end
				
				stuck_towers[callee_tower] = true
				target_field = callee_tower.field
				
				self.player_turn = self.players[self.player_turn].other
				callee_tower = self.players[self.player_turn].towers[target_field.colour]
			end
			if deadlock_detected then
				-- * deadlock, the player *not* described by the initial player_turn wins
				tower_to_sumoupdate = original_callee_tower
				self.player_turn = original_callee_tower.player.me
				break
			end
			
			self.choices_assoc = {[callee_tower.field.name] = true}
		end
		-- * at this point .player_turn is the player who won the round
		
		-- * update score and check winner
		tower_to_sumoupdate.player.score = tower_to_sumoupdate.player.score + 2 ^ tower_to_sumoupdate.sumo_status
		tower_to_sumoupdate.sumo_status = tower_to_sumoupdate.sumo_status + 1
		for ix = 1, 2 do
			if self.players[ix].score >= self.score_target then
				self.winner = ix
				break
			end
		end
		if self.winner then
			break
		end
		
		-- * initiate fills for next round
		self.choices_assoc = {}
		for field_name, field in next, self.fields do
			if field.home_of == self.player_turn and field.fill_role then
				self.choices_assoc[field.name] = true
			end
		end
		local reload_from_field = self.fields[self:get_choice()]
		-- * do refills on both sides
		for ip = 1, 2 do
			-- * find refill direction by checking whether the field has neighbours at a lower positions
			local xdir = self.field_map[reload_from_field.py][reload_from_field.px - 1] and -1 or 1
			local ydir = self.field_map[reload_from_field.py][reload_from_field.py - 1] and -1 or 1
			
			local next_home_row_field = reload_from_field.px
			for iy = reload_from_field.py, self.size + 1 - reload_from_field.py, ydir do
				for ix = reload_from_field.px, self.size + 1 - reload_from_field.px, xdir do
					local current_field = self.field_map[iy][ix]
					if current_field.occupant and current_field.occupant.player.me == self.player_turn then
						self:tower_to_field(current_field.occupant, self.field_map[reload_from_field.py][next_home_row_field])
						next_home_row_field = next_home_row_field + xdir
					end
				end
			end
			
			-- * find the other corner
			reload_from_field = self.field_map[self.size + 1 - reload_from_field.py][self.size + 1 - reload_from_field.px]
			-- * flip, other player should fill too
			self.player_turn = self.players[self.player_turn].other
		end
		
		-- * flip, loser starts
		self.player_turn = self.players[self.player_turn].other
	end
	self.player_turn = false
	
	self.choices_assoc = {}
end

function board_i:init()
	self.size = #self.colour_map
	
	self.score_target = 3
	
	self.players = {
		[1] = {
			name = "W",
			me = 1,
			other = 2,
			towers = {},
			score = 0
		},
		[2] = {
			name = "B",
			me = 2,
			other = 1,
			towers = {},
			score = 0
		}
	}
	self.winner = false
	
	self.fields = {}
	self.field_map = {}
	self.field_coll = {}
	local field_counter = 0
	for iy = 1, self.size do
		self.field_map[iy] = {}
		for ix = 1, self.size do
			field_counter = field_counter + 1
			local new_field = {
				colour = self.colour_map[iy][ix],
				name = "F" .. field_counter,
				px = ix,
				py = iy,
				fill_role = false,
				home_of = false,
				occupant = false
			}
			self.field_map[iy][ix] = new_field
			self.fields[new_field.name] = new_field
			self.field_coll[new_field.name] = {
				px = new_field.px,
				py = new_field.py,
				colour = new_field.colour
			}
		end
	end
	
	self.choices_assoc = {}
	
	self.towers = {}
	self.tower_coll = {}
	for iy, player in next, {[1] = self.players[1], [self.size] = self.players[2]} do
		for ix = 1, self.size do
			local new_tower = {
				name = player.name .. ix,
				field = self.field_map[iy][ix],
				colour = self.field_map[iy][ix].colour,
				player = player,
				facing = iy == 1 and 1 or -1,
				sumo_status = 0
			}
			
			self.field_map[iy][ix].occupant = new_tower
			self.field_map[iy][ix].home_of = player.me
			
			self.towers[new_tower.name] = new_tower
			self.tower_coll[new_tower.name] = {
				colour = new_tower.colour,
				facing = new_tower.facing,
				player = player.me
			}
			player.towers[new_tower.colour] = new_tower
		end
		
		local left, right = self.field_map[iy][1], self.field_map[iy][self.size]
		left.fill_role = "fill_left"
		right.fill_role = "fill_right"
		-- * NOTE: check if it's really player 1 who needs to be flipped
		if player.me == 1 then
			left.fill_role, right.fill_role = right.fill_role, left.fill_role
		end
	end
	
	self.match_coroutine = coroutine.create(self.match)
	-- * best self-call ever
	coroutine.resume(self.match_coroutine, self)
	
	return self
end

return {
	new = function()
		local new_board = setmetatable({
			colour_map = {
				{"C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"},
				{"C6", "C1", "C4", "C7", "C2", "C5", "C8", "C3"},
				{"C7", "C4", "C1", "C6", "C3", "C8", "C5", "C2"},
				{"C4", "C3", "C2", "C1", "C8", "C7", "C6", "C5"},
				{"C5", "C6", "C7", "C8", "C1", "C2", "C3", "C4"},
				{"C2", "C5", "C8", "C3", "C6", "C1", "C4", "C7"},
				{"C3", "C8", "C5", "C2", "C7", "C4", "C1", "C6"},
				{"C8", "C7", "C6", "C5", "C4", "C3", "C2", "C1"}
			}
		}, board_m)
		
		new_board:init()
		return new_board
	end
}

