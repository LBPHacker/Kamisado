"use strict";

document.addEventListener("DOMContentLoaded", function() {
	const CLIENT_DIR = "/kamisado";
	const SERVER_URL = "wss://hikari.lbphacker.hu/kamisadoserver";
	const PING_TIMER_TIMEOUT = 60000;
	const KILL_TIMER_TIMEOUT = 90000;
	const RECONNECT_TIMER_TIMEOUT = 1000;
	const RECONNECT_TIMER_LOOPS = 10;
	
	const DEBUG = 1;
	var debug = function(stuff) {
		if (DEBUG)
			console.log(stuff);
	};
	
	var create_board, destroy_board, mirror_status, send_message, clear_choices, mirror_choices, mirror_keys;
	
	clear_choices = function() {
		document.querySelectorAll(".board .field").forEach(function(field) {
			field.classList.remove("choice_invalid", "choice_valid");
		});
		document.querySelectorAll(".board .tower").forEach(function(tower) {
			tower.classList.remove("choice_invalid", "choice_valid");
		});
	};
	
	mirror_choices = function(message_obj) {
		document.querySelectorAll(".board .field").forEach(function(field) {
			field.classList.add(message_obj.choices[field.dataset.fieldName] ? "choice_valid" : "choice_invalid");
		});
		document.querySelectorAll(".board .tower").forEach(function(tower) {
			tower.classList.add(message_obj.choices[tower.dataset.fieldName] ? "choice_valid" : "choice_invalid");
		});
	};
	
	mirror_keys = function(message_obj) {
		debug(message_obj);
		for (var ix = 0; ix != 3; ++ix) {
			var $key_p = document.querySelector("#msg_key_" + ix);
			var key_str = message_obj["key" + (ix + 1)];
			$key_p.children[0].href = CLIENT_DIR + ["/play/", "/play/", "/view/"][ix] + key_str;
			
			if (key_str == ".")
				$key_p.classList.add("hidden");
			else
				$key_p.classList.remove("hidden");
		}
	};
	
	create_board = function(message_obj) {
		var setup = message_obj.setup;
		
		var board_div = document.createElement("div");
		board_div.classList.add("board");
		
		Object.keys(setup.board_fields).map(function(field_name) {
			var field_obj = setup.board_fields[field_name];
			var field_div = document.createElement("div");
			
			field_div.classList.add("field", "colour_selector");
			field_div.dataset.colourId = field_obj.colour;
			field_div.dataset.fieldName = field_name;
			
			field_div.style.width  = (100.0 / setup.board_size                     ) + "%";
			field_div.style.height = (100.0 / setup.board_size                     ) + "%";
			field_div.style.left   = (100.0 / setup.board_size * (field_obj.px - 1)) + "%";
			field_div.style.top    = (100.0 / setup.board_size * (field_obj.py - 1)) + "%";
			
			var field_pattern = document.createElement("div");
			field_pattern.classList.add("field_pattern");
			field_div.appendChild(field_pattern);
			
			var field_middle = document.createElement("div");
			field_middle.classList.add("field_middle", "coloured");
			field_pattern.appendChild(field_middle);
			
			board_div.appendChild(field_div);
		});
		
		Object.keys(setup.board_towers).map(function(tower_name) {
			var tower_obj = setup.board_towers[tower_name];
			var tower_div = document.createElement("div");
			
			tower_div.classList.add("tower", "colour_selector", "hidden");
			tower_div.dataset.colourId = tower_obj.colour;
			tower_div.dataset.towerName = tower_name;
			tower_div.dataset.player = tower_obj.player;
			
			tower_div.style.width  = (100.0 / setup.board_size) + "%";
			tower_div.style.height = (100.0 / setup.board_size) + "%";
			
			var tower_middle = document.createElement("div");
			tower_middle.classList.add("tower_middle");
			tower_div.appendChild(tower_middle);
			
			for (var ix = 0; ix != 4; ++ix) {
				var tower_sumo = document.createElement("div");
				tower_sumo.classList.add("tower_sumo");
				tower_sumo.dataset.sumoLevel = ix + 1;
				tower_middle.appendChild(tower_sumo);
			}
			
			var tower_colour = document.createElement("div");
			tower_colour.classList.add("tower_colour", "coloured");
			tower_middle.appendChild(tower_colour);
			
			board_div.appendChild(tower_div);
		});
		
		board_div.addEventListener("click", function(event) {
			send_message({
				action: "choose",
				choice: event.target.dataset.fieldName
			});
		});
		
		var $board_border = document.querySelector("#board_border");
		$board_border.dataset.endpointId = setup.endpoint_id;
		$board_border.appendChild(board_div);
		
		document.querySelectorAll("#msg_content .msg_setup").forEach(function(span) {
			span.innerText = setup[span.dataset.setupKey];
		});
		
		document.querySelector("#msg_hax").classList.remove("hidden");
	};
	
	destroy_board = function() {
		document.querySelector(".board").remove();
		
		document.querySelector("#msg_hax").classList.add("hidden");
	};
	
	mirror_status = function(message_obj) {
		var status = message_obj.status;
		
		Object.keys(status.towers).map(function(tower_name) {
			var tower_obj = status.towers[tower_name];
			var $tower = document.querySelector(".board .tower[data-tower-name=" + tower_name + "]");
			var $field = document.querySelector(".board .field[data-field-name=" + tower_obj.field + "]");
			$tower.style.left = $field.style.left;
			$tower.style.top  = $field.style.top ;
			$tower.dataset.fieldName = tower_obj.field;
			$tower.dataset.sumoStatus = tower_obj.sumo_status;
			$tower.classList.remove("hidden");
		});
		
		document.querySelectorAll("#msg_content .msg_status").forEach(function(span) {
			span.innerText = status[span.dataset.statusKey];
		});
		
		document.querySelector("#msg_player_role").innerText = status.winner ? "Winner" : "Turn";
		document.querySelector("#msg_player_id").innerText = ["White", "Black"][(status.winner || status.player_turn) - 1];
	};
	
	(function() {
		var socket;
		
		var connection_open, stage_reconnect, handle_message, setup_socket, reconnect_callback, send_ping;
		var ping_interval, kill_timeout;
		
		var reconnect_loops;
		reconnect_callback = function() {
			reconnect_loops = reconnect_loops - 1;
			if (reconnect_loops > 0)
			{
				setTimeout(reconnect_callback, RECONNECT_TIMER_TIMEOUT);
				return;
			}
			
			setup_socket();
		};
		
		handle_message = function(event) {
			try {
				var message_obj = JSON.parse(event.data);
				
				switch (message_obj.action) {
				case "pong":
					clearTimeout(kill_timeout);
					kill_timeout = setTimeout(stage_reconnect, KILL_TIMER_TIMEOUT);
					break;
					
				case "ping":
					send_message({
						action: "pong"
					});
					break;
					
				case "newkeys":
					window.location.href = CLIENT_DIR + "/play/" + message_obj.key1;
					break;
					
				case "setup":
					create_board(message_obj);
					break;
					
				case "joined":
					break;
					
				case "left":
					destroy_board();
					break;
					
				case "clearchoices":
					clear_choices();
					break;
					
				case "choices":
					mirror_choices(message_obj);
					break;
					
				case "keys":
					mirror_keys(message_obj);
					break
					
				case "status":
					mirror_status(message_obj);
					break;
					
				default:
					debug("unknown action " + message_obj.action);
					debug(message_obj);
					break;
				}
			}
			catch (e) {}
		};
		
		send_message = function(message_obj) {
			socket.send(JSON.stringify(message_obj));
		};
		
		send_ping = function() {
			send_message({
				action: "ping"
			});
		};
		
		connection_open = function() {
			document.body.classList.add("connected");
			ping_interval = setInterval(send_ping, PING_TIMER_TIMEOUT);
			kill_timeout = setTimeout(stage_reconnect, KILL_TIMER_TIMEOUT);
			
			var page_params = ((window.location.href.match(new RegExp(CLIENT_DIR + "/(.*)")) || [])[1] || "").split("/").filter(str => str.length != 0);
		
			switch (page_params[0]) {
			case "play":
			case "view":
				send_message({
					action: "join",
					access_key: page_params[1]
				});
				break;
				
			case "new":
				send_message({
					action: "new",
					game_type: page_params[1]
				});
				break;
			}
		};
		
		stage_reconnect = function() {
			socket.removeEventListener("open", connection_open);
			socket.removeEventListener("message", handle_message);
			socket.removeEventListener("close", stage_reconnect);
			socket.removeEventListener("error", stage_reconnect);
			clearInterval(ping_interval);
			clearTimeout(kill_timeout);
			try {
				socket.close();
			}
			catch (e) {}
			
			document.body.classList.remove("connected");
			reconnect_loops = RECONNECT_TIMER_LOOPS;
			setTimeout(reconnect_callback, RECONNECT_TIMER_TIMEOUT);
		};
		
		setup_socket = function() {
			socket = new WebSocket(SERVER_URL, "kamisado");
			socket.addEventListener("open", connection_open);
			socket.addEventListener("message", handle_message);
			socket.addEventListener("close", stage_reconnect);
			socket.addEventListener("error", stage_reconnect);
		};
		
		setup_socket();
	})();
});

