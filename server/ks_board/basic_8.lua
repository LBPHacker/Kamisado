local basic_stub = require("ks_board.basic_stub")

return {
	new = function(score_target)
		return basic_stub.new(score_target, {
			{"Or", "Bl", "Pu", "Pi", "Ye", "Re", "Gr", "Br"},
			{"Re", "Or", "Pi", "Gr", "Bl", "Ye", "Br", "Pu"},
			{"Gr", "Pi", "Or", "Re", "Pu", "Br", "Ye", "Bl"},
			{"Pi", "Pu", "Bl", "Or", "Br", "Gr", "Re", "Ye"},
			{"Ye", "Re", "Gr", "Br", "Or", "Bl", "Pu", "Pi"},
			{"Bl", "Ye", "Br", "Pu", "Re", "Or", "Pi", "Gr"},
			{"Pu", "Br", "Ye", "Bl", "Gr", "Pi", "Or", "Re"},
			{"Br", "Gr", "Re", "Ye", "Pi", "Pu", "Bl", "Or"}
		})
	end
}

