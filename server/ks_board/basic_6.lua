local basic_stub = require("ks_board.basic_stub")

return {
	new = function(score_target)
		return basic_stub.new(score_target, {
			{"Or", "Bl", "Gr", "Pu", "Ye", "Re"},
			{"Pu", "Or", "Ye", "Bl", "Re", "Gr"},
			{"Ye", "Gr", "Or", "Re", "Pu", "Bl"},
			{"Bl", "Pu", "Re", "Or", "Gr", "Ye"},
			{"Gr", "Re", "Bl", "Ye", "Or", "Pu"},
			{"Re", "Ye", "Pu", "Gr", "Bl", "Or"}
		})
	end
}

