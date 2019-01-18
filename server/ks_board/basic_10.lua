local basic_stub = require("ks_board.basic_stub")

return {
	new = function(score_target)
		return basic_stub.new(score_target, {
			{"Or", "Re", "Gr", "Go", "Ye", "Pi", "Si", "Bl", "Pu", "Br"},
			{"Bl", "Or", "Pi", "Pu", "Go", "Si", "Re", "Ye", "Br", "Gr"},
			{"Pu", "Go", "Or", "Pi", "Gr", "Bl", "Ye", "Br", "Si", "Re"},
			{"Pi", "Gr", "Go", "Or", "Re", "Pu", "Br", "Si", "Bl", "Ye"},
			{"Si", "Pi", "Pu", "Bl", "Or", "Br", "Gr", "Re", "Ye", "Go"},
			{"Go", "Ye", "Re", "Gr", "Br", "Or", "Bl", "Pu", "Pi", "Si"},
			{"Ye", "Bl", "Si", "Br", "Pu", "Re", "Or", "Go", "Gr", "Pi"},
			{"Re", "Si", "Br", "Ye", "Bl", "Gr", "Pi", "Or", "Go", "Pu"},
			{"Gr", "Br", "Ye", "Re", "Si", "Go", "Pu", "Pi", "Or", "Bl"},
			{"Br", "Pu", "Bl", "Si", "Pi", "Ye", "Go", "Gr", "Re", "Or"}
		})
	end
}

