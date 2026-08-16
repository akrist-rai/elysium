package game

import rl "vendor:raylib"

// Server Room B, 03:0-something. Built from boxes, lit by two dying tubes and
// whatever the racks are still willing to give off.
//
// The grid is 18x15 tiles. The room proper is the interior; the walls are props
// that also block navigation, so the geometry and the nav grid can never drift
// apart.

SERVER_ROOM_W :: 18
SERVER_ROOM_H :: 15

build_server_room :: proc(s: ^Scene) {
	scene_init(s, "Server Room B", SERVER_ROOM_W, SERVER_ROOM_H)
	s.spawn = {7.5, 9.5}
	s.opening_node = "wake"

	wall_top := rl.Color{102, 99, 92, 255}
	wall_side := rl.Color{88, 85, 80, 255}

	// --- shell --------------------------------------------------------------
	// The two far walls (north and west) are full height and act as the
	// backdrop. The two near walls are cut down to a lip, the way an isometric
	// room is always drawn -- at full height they would stand between the
	// camera and everything worth looking at.
	scene_add_prop(s, Prop{pos = {0, 0}, size = {SERVER_ROOM_W, 1}, height = 2.9, top = wall_top, side = wall_side, blocks = true})
	scene_add_prop(s, Prop{pos = {0, 1}, size = {1, SERVER_ROOM_H - 1}, height = 2.9, top = wall_top, side = wall_side, blocks = true})
	scene_add_prop(s, Prop{pos = {SERVER_ROOM_W - 1, 1}, size = {1, SERVER_ROOM_H - 1}, height = 0.55, top = wall_top, side = wall_side, blocks = true})
	scene_add_prop(s, Prop{pos = {1, SERVER_ROOM_H - 1}, size = {SERVER_ROOM_W - 2, 1}, height = 0.5, top = wall_top, side = wall_side, blocks = true})

	// --- the rack row -------------------------------------------------------
	// Six cabinets along the north wall. Their front panels are the brightest
	// thing in the room and the bloom pass keys off them.
	rack_top := rl.Color{44, 46, 50, 255}
	rack_side := rl.Color{52, 54, 60, 255}
	for i in 0 ..< 6 {
		x := 9.0 + f32(i) * 1.35
		scene_add_prop(
			s,
			Prop {
				pos = {x, 1.4},
				size = {1.1, 2.2},
				height = 2.35,
				top = rack_top,
				side = rack_side,
				emissive = i == 3 ? 0.35 : 0.85, // one cabinet is dark
				label = "rack",
				blocks = true,
			},
		)
	}

	// --- the desk and the contestant ----------------------------------------
	desk_top := rl.Color{92, 74, 56, 255}
	desk_side := rl.Color{74, 60, 46, 255}
	scene_add_prop(s, Prop{pos = {3.2, 6.4}, size = {3.4, 1.7}, height = 0.82, top = desk_top, side = desk_side, blocks = true})

	// His monitor, still on, still showing the submission that froze the board.
	scene_add_prop(
		s,
		Prop {
			pos = {4.1, 6.6},
			size = {1.4, 0.28},
			height = 0.72,
			top = rl.Color{30, 32, 34, 255},
			side = rl.Color{34, 36, 40, 255},
			emissive = 1.0,
			blocks = false,
		},
	)
	// The contestant himself, slumped forward across the desk.
	scene_add_prop(
		s,
		Prop {
			pos = {3.5, 7.4},
			size = {1.0, 0.85},
			height = 0.95,
			top = rl.Color{112, 96, 118, 255},
			side = rl.Color{88, 76, 96, 255},
			blocks = true,
		},
	)

	// --- the wall display ---------------------------------------------------
	// Mounted on the west wall, frozen on the scoreboard since 02:14.
	scene_add_prop(
		s,
		Prop {
			pos = {1.0, 4.2},
			size = {0.34, 2.8},
			height = 2.1,
			top = rl.Color{28, 30, 32, 255},
			side = rl.Color{26, 28, 30, 255},
			emissive = 0.9,
			blocks = false,
		},
	)

	// --- the whiteboard -----------------------------------------------------
	scene_add_prop(
		s,
		Prop {
			pos = {3.0, 1.0},
			size = {3.6, 0.3},
			height = 2.0,
			top = rl.Color{206, 204, 196, 255},
			side = rl.Color{188, 186, 178, 255},
			blocks = false,
		},
	)

	// --- the fire door, propped and then unpropped --------------------------
	scene_add_prop(
		s,
		Prop {
			pos = {SERVER_ROOM_W - 1.34, 10.0},
			size = {0.34, 2.2},
			height = 2.4,
			top = rl.Color{96, 88, 72, 255},
			side = rl.Color{84, 76, 62, 255},
			blocks = false,
		},
	)
	// Exit sign above it: the only genuinely warm light in the room.
	scene_add_prop(
		s,
		Prop {
			pos = {SERVER_ROOM_W - 1.4, 10.7},
			size = {0.2, 0.8},
			height = 2.75,
			top = rl.Color{60, 30, 26, 255},
			side = rl.Color{80, 34, 28, 255},
			emissive = 0.75,
			blocks = false,
		},
	)

	// --- clutter ------------------------------------------------------------
	// A second desk you can sit things on, and the coffee cup.
	scene_add_prop(s, Prop{pos = {11.4, 8.6}, size = {2.6, 1.3}, height = 0.78, top = desk_top, side = desk_side, blocks = true})
	scene_add_prop(
		s,
		Prop {
			pos = {12.1, 8.85},
			size = {0.32, 0.32},
			height = 0.24,
			top = rl.Color{214, 208, 196, 255},
			side = rl.Color{196, 190, 178, 255},
			blocks = false,
		},
	)
	// A chair, pushed back hard enough that it hit the rack behind it.
	scene_add_prop(
		s,
		Prop {
			pos = {5.0, 8.6},
			size = {0.85, 0.85},
			height = 0.5,
			top = rl.Color{58, 60, 66, 255},
			side = rl.Color{48, 50, 56, 255},
			blocks = true,
		},
	)
	// Cable spool and a floor tile somebody lifted and did not put back.
	scene_add_prop(
		s,
		Prop {
			pos = {8.2, 11.4},
			size = {1.0, 1.0},
			height = 0.34,
			top = rl.Color{50, 52, 48, 255},
			side = rl.Color{42, 44, 40, 255},
			blocks = true,
		},
	)

	// --- lights -------------------------------------------------------------
	append(&s.lights, Light{pos = {11.6, 2.6}, height = 2.4, color = rl.Color{150, 226, 206, 255}, radius = 5.0, intensity = 1.0})
	append(&s.lights, Light{pos = {4.8, 7.2}, height = 1.0, color = rl.Color{150, 226, 206, 255}, radius = 3.4, intensity = 0.9})
	append(&s.lights, Light{pos = {1.6, 5.6}, height = 1.6, color = rl.Color{140, 200, 220, 255}, radius = 3.8, intensity = 0.8})
	append(&s.lights, Light{pos = {16.6, 11.0}, height = 2.4, color = rl.Color{240, 120, 96, 255}, radius = 4.2, intensity = 0.9})
	// The one fluorescent tube that still works, dead centre.
	append(&s.lights, Light{pos = {9.0, 7.5}, height = 2.8, color = rl.Color{226, 220, 190, 255}, radius = 7.5, intensity = 0.55})

	// --- interactables ------------------------------------------------------
	scene_add_interactable(s, Interactable{
		id = "body", label = "The contestant", node = "the_body",
		pos = {4.0, 7.8}, height = 1.5, stand = {4.0, 9.2}, is_person = true, topdown_pos = {360, 625},
	})
	scene_add_interactable(s, Interactable{
		id = "monitor", label = "Her monitor", node = "her_monitor",
		pos = {4.8, 6.7}, height = 1.25, stand = {5.2, 8.6}, topdown_pos = {350, 555},
	})
	scene_add_interactable(s, Interactable{
		id = "scoreboard", label = "The frozen scoreboard", node = "scoreboard",
		pos = {1.4, 5.6}, height = 2.5, stand = {2.6, 5.6}, topdown_pos = {150, 250},
	})
	scene_add_interactable(s, Interactable{
		id = "racks", label = "The rack row", node = "the_racks",
		pos = {11.5, 3.4}, height = 2.9, stand = {11.5, 4.8}, topdown_pos = {890, 180},
	})
	scene_add_interactable(s, Interactable{
		id = "whiteboard", label = "The whiteboard", node = "whiteboard",
		pos = {4.8, 1.4}, height = 2.5, stand = {4.8, 3.0}, topdown_pos = {150, 520},
	})
	scene_add_interactable(s, Interactable{
		id = "firedoor", label = "The fire door", node = "fire_door",
		pos = {16.6, 11.1}, height = 2.9, stand = {15.4, 11.1}, topdown_pos = {1450, 460},
	})
	scene_add_interactable(s, Interactable{
		id = "cup", label = "A coffee cup", node = "coffee_cup",
		pos = {12.3, 9.0}, height = 1.15, stand = {12.3, 10.4}, topdown_pos = {1190, 740},
	})
	scene_add_interactable(s, Interactable{
		id = "sysadmin", label = "The sysadmin", node = "sysadmin_hub",
		pos = {13.4, 6.2}, height = 1.85, stand = {12.6, 6.6}, is_person = true, topdown_pos = {1110, 300},
		require = "sysadmin_present",
	})
	scene_add_interactable(s, Interactable{
		id = "self", label = "Yourself", node = "yourself",
		pos = {8.2, 11.6}, height = 1.2, stand = {7.4, 11.6}, topdown_pos = {760, 720},
	})
}
