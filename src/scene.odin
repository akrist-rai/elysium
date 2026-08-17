package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// Server Room B and the two rooms you can reach from it, at three in the
// morning. The geometry comes out of content/map.txt; everything in here is
// what gets hung on that geometry — the lights, the marks on the floor, the two
// other people, and the things worth walking up to.

scene_build :: proc(s: ^Scene, content_dir: string) -> []Parse_Error {
	scene_destroy(s)

	grid, errors := tilemap_load(fmt.tprintf("%s/map.txt", content_dir))
	s.grid = grid
	if !grid.loaded {
		return errors
	}

	s.name = "Server Room B"
	s.spawn = grid.spawn
	s.opening_node = "wake"
	s.interactables = make([dynamic]Interactable)
	s.lights = make([dynamic]Light)
	s.actors = make([dynamic]Actor)
	s.decals = make([dynamic]Decal)
	s.props = make([dynamic]Detail_Prop)

	nav_build_from_map(&s.nav, &s.grid)

	scene_place_lights(s)
	scene_place_decals(s)
	scene_place_props(s)
	scene_place_actors(s)
	scene_place_interactables(s)

	s.built = true
	return errors
}

// ---------------------------------------------------------------------------
// Lighting
// ---------------------------------------------------------------------------

// Every light in the building is derived from something you can see: a tube in
// the ceiling, the front of a rack, a screen nobody switched off. Nothing is
// lit by a source that is not in the room.
@(private = "file")
scene_place_lights :: proc(s: ^Scene) {
	for pos, i in s.grid.tubes {
		// One tube in five is on its way out. That is the one the writing keeps
		// mentioning, so it had better be visible.
		dying := (i % 5) == 2
		append(
			&s.lights,
			Light {
				pos = pos,
				color = rl.Color{236, 226, 196, 255},
				// Tight enough that the pools stay separate: one big soft radius
				// per tube just lifts the whole floor to an even grey.
				radius = dying ? 3.6 : 4.4,
				intensity = dying ? 0.50 : 0.66,
				flicker = dying ? 1.0 : 0.06,
				phase = f32(i) * 1.9,
			},
		)
	}

	for y in 0 ..< s.grid.h {
		for x in 0 ..< s.grid.w {
			t := tilemap_at(&s.grid, x, y)
			c := rl.Vector2{f32(x) + 0.5, f32(y) + 0.5}

			#partial switch t {
			case .Rack:
				// Only the face of the row glows, not every tile inside it.
				if tilemap_at(&s.grid, x, y + 1) == .Rack {
					continue
				}
				append(
					&s.lights,
					Light {
						pos = {c.x, c.y + 0.55},
						color = rl.Color{120, 214, 198, 255},
						radius = 2.9,
						intensity = 0.50,
						flicker = 0.18,
						phase = f32(x * 7 + y * 3),
					},
				)
			case .Wall_Screen:
				append(
					&s.lights,
					Light {
						pos = {c.x + 0.7, c.y},
						color = rl.Color{116, 176, 226, 255},
						radius = 4.6,
						intensity = 0.62,
						flicker = 0.05,
						phase = f32(y),
					},
				)
			case .Wall_Exit:
				append(
					&s.lights,
					Light {
						pos = {c.x - 0.6, c.y},
						color = rl.Color{240, 108, 84, 255},
						radius = 4.2,
						intensity = 0.78,
						flicker = 0.0,
						phase = 0,
					},
				)
			case .Printer:
				append(
					&s.lights,
					Light {
						pos = c,
						color = rl.Color{130, 220, 140, 255},
						radius = 1.5,
						intensity = 0.34,
						flicker = 0.5,
						phase = f32(x),
					},
				)
			}
		}
	}

	// Priya's two monitors, still showing the submission that froze the board.
	// These are the brightest thing in the room and the reason her desk reads as
	// the centre of the scene from across the floor.
	append(
		&s.lights,
		Light{pos = {5.0, 9.3}, color = rl.Color{140, 226, 210, 255}, radius = 4.4, intensity = 0.85, flicker = 0.10, phase = 2.1},
	)
	append(
		&s.lights,
		Light{pos = {7.2, 9.3}, color = rl.Color{140, 226, 210, 255}, radius = 3.6, intensity = 0.66, flicker = 0.10, phase = 5.4},
	)
}

// ---------------------------------------------------------------------------
// Floor marks
// ---------------------------------------------------------------------------

@(private = "file")
scene_place_decals :: proc(s: ^Scene) {
	cable := rl.Color{26, 29, 32, 255}
	runs := [][4]f32 {
		{10.5, 5.4, 14.0, 8.5},
		{14.0, 8.5, 13.5, 14.0},
		{13.5, 14.0, 21.5, 15.5},
		{21.5, 15.5, 24.0, 11.0},
		{9.0, 5.4, 8.5, 8.0},
		{27.5, 5.4, 30.0, 10.5},
		{13.4, 21.5, 20.0, 22.5},
		{20.0, 22.5, 26.0, 20.5},
	}
	for r in runs {
		append(&s.decals, Decal{kind = .Cable, a = {r[0], r[1]}, b = {r[2], r[3]}, size = 0.11, tint = cable})
	}

	stains := [][3]f32{{9.4, 12.6, 1.5}, {24.5, 17.0, 1.1}, {18.0, 20.5, 1.8}, {44.0, 12.0, 1.3}, {26.0, 28.5, 1.6}}
	for st in stains {
		append(
			&s.decals,
			Decal{kind = .Stain, a = {st[0], st[1]}, size = st[2], tint = rl.Color{40, 40, 38, 255}},
		)
	}

	scuffs := [][4]f32{{6.0, 11.5, 8.5, 12.2}, {16.5, 19.5, 19.0, 19.2}, {8.5, 24.5, 9.5, 26.5}}
	for sc in scuffs {
		append(
			&s.decals,
			Decal{kind = .Scuff, a = {sc[0], sc[1]}, b = {sc[2], sc[3]}, size = 0.35, tint = rl.Color{96, 92, 84, 255}},
		)
	}

	// The shape of where you were lying, left on the carpet tile. It is the only
	// evidence of you in the building that you can actually stand over.
	append(
		&s.decals,
		Decal{kind = .Coat_Print, a = s.spawn, size = 1.0, tint = rl.Color{54, 54, 58, 255}},
	)
}

// ---------------------------------------------------------------------------
// What is sitting on the furniture
// ---------------------------------------------------------------------------

@(private = "file")
scene_place_props :: proc(s: ^Scene) {
	place :: proc(s: ^Scene, k: Detail_Prop_Kind, x, y: f32) {
		append(&s.props, Detail_Prop{kind = k, pos = {x, y}})
	}

	// Priya's desk: two monitors still lit, and nineteen hours of paperwork.
	place(s, .Monitor, 5.0, 9.15)
	place(s, .Monitor, 7.2, 9.15)
	place(s, .Keyboard, 6.1, 9.72)
	place(s, .Papers, 4.4, 9.6)
	place(s, .Cup, 7.9, 9.7)

	// The far desk, and the coffee cup that is a whole conversation.
	place(s, .Cup, 27.5, 19.3)
	place(s, .Papers, 28.6, 18.7)

	// The sysadmin's workbench.
	place(s, .Monitor, 16.4, 17.4)
	place(s, .Toolbox, 14.7, 18.4)
	place(s, .Cable_Coil, 17.8, 18.3)

	// The office nobody has been in since the competition started.
	place(s, .Monitor, 46.6, 2.7)
	place(s, .Keyboard, 47.2, 3.5)
	place(s, .Papers, 49.2, 2.8)
	place(s, .Monitor, 47.0, 20.7)
	place(s, .Cup, 49.4, 21.2)
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

ACTOR_SLEEPER :: 0
ACTOR_SYSADMIN :: 1

@(private = "file")
scene_place_actors :: proc(s: ^Scene) {
	// Priya, folded forward over her desk, exactly where the writing puts her.
	append(
		&s.actors,
		Actor{kind = .Sleeper, pos = {6.2, 10.35}, facing = -math.PI * 0.5, home = {6.2, 10.35}},
	)

	// The sysadmin, who is not going to hover, and is going to hover a little.
	append(
		&s.actors,
		Actor {
			kind = .Sysadmin,
			pos = {20.5, 6.6},
			facing = math.PI * 0.5,
			home = {20.5, 6.8},
			require = "sysadmin_present",
			wait = 1.2,
		},
	)
}

// ---------------------------------------------------------------------------
// Things worth walking up to
// ---------------------------------------------------------------------------

@(private = "file")
scene_place_interactables :: proc(s: ^Scene) {
	scene_add_interactable(s, Interactable{
		id = "body", label = "Priya", node = "the_body",
		pos = {6.2, 10.35}, is_person = true, follow_actor = ACTOR_SLEEPER,
	})
	scene_add_interactable(s, Interactable{
		id = "monitor", label = "Her monitor", node = "her_monitor",
		pos = {5.0, 9.4}, follow_actor = -1,
	})
	scene_add_interactable(s, Interactable{
		id = "scoreboard", label = "The frozen scoreboard", node = "scoreboard",
		pos = {1.0, 7.5}, follow_actor = -1,
	})
	scene_add_interactable(s, Interactable{
		id = "racks", label = "The rack row", node = "the_racks",
		pos = {20.5, 5.3}, follow_actor = -1,
	})
	scene_add_interactable(s, Interactable{
		id = "whiteboard", label = "The whiteboard", node = "whiteboard",
		pos = {6.0, 1.2}, follow_actor = -1,
	})
	scene_add_interactable(s, Interactable{
		id = "firedoor", label = "The fire door", node = "fire_door",
		pos = {36.4, 17.5}, follow_actor = -1,
	})
	scene_add_interactable(s, Interactable{
		id = "cup", label = "A coffee cup", node = "coffee_cup",
		pos = {27.5, 19.4}, follow_actor = -1,
	})
	scene_add_interactable(s, Interactable{
		id = "sysadmin", label = "The sysadmin", node = "sysadmin_hub",
		pos = {20.5, 6.6}, is_person = true, follow_actor = ACTOR_SYSADMIN,
		require = "sysadmin_present",
	})
	scene_add_interactable(s, Interactable{
		id = "self", label = "Yourself", node = "yourself",
		pos = s.spawn, follow_actor = -1,
	})
}
