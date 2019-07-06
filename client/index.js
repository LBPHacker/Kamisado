"use strict";

document.addEventListener("DOMContentLoaded", function() {
	var $start_match = document.querySelector("#start_match");
	var $bt = document.querySelector("#bt");
	var $mt = document.querySelector("#mt");

	var update_start_href = function() {
		start_match.href = "new/" + $bt[$bt.selectedIndex].value + "-" + $mt[$mt.selectedIndex].value;
	};

	document.querySelectorAll("select").forEach(function(select) {
		select.addEventListener("change", update_start_href);
	});

	document.querySelectorAll("option.default").forEach(function(option) {
		option.selected = true;
	});

	update_start_href();
});
