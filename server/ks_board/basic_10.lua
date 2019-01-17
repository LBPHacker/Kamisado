local basic_stub = require("ks_board.basic_stub")

return {
	new = function(score_target)
		return basic_stub.new(score_target, {
			{ "C1",  "C6",  "C7",  "C9",  "C5",  "C4", "C10",  "C2",  "C3",  "C8"},
			{ "C2",  "C1",  "C4",  "C3",  "C9", "C10",  "C6",  "C5",  "C8",  "C7"},
			{ "C3",  "C9",  "C1",  "C4",  "C7",  "C2",  "C5",  "C8", "C10",  "C6"},
			{ "C4",  "C7",  "C9",  "C1",  "C6",  "C3",  "C8", "C10",  "C2",  "C5"},
			{"C10",  "C4",  "C3",  "C2",  "C1",  "C8",  "C7",  "C6",  "C5",  "C9"},
			{ "C9",  "C5",  "C6",  "C7",  "C8",  "C1",  "C2",  "C3",  "C4", "C10"},
			{ "C5",  "C2", "C10",  "C8",  "C3",  "C6",  "C1",  "C9",  "C7",  "C4"},
			{ "C6", "C10",  "C8",  "C5",  "C2",  "C7",  "C4",  "C1",  "C9",  "C3"},
			{ "C7",  "C8",  "C5",  "C6", "C10",  "C9",  "C3",  "C4",  "C1",  "C2"},
			{ "C8",  "C3",  "C2", "C10",  "C4",  "C5",  "C9",  "C7",  "C6",  "C1"}
		})
	end
}

