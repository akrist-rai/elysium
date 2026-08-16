package game

import "core:math"
import "core:strings"
import rl "vendor:raylib"

// Everything solid in the room is a box: a footprint on the floor and a height.
// Boxes are enough to build a server room that reads correctly in isometric,
// and the painterly pass does the rest of the work.
Prop :: struct {
	pos:      rl.Vector2, // north-west corner, in tiles
	size:     rl.Vector2, // footprint
	height:   f32,
	top:      rl.Color,
	side:     rl.Color,
	emissive: f32, // 0 = inert, 1 = a lit monitor
	label:    string,
	blocks:   bool,
}

// A thing you can talk to or look at. In Disco Elysium these are the orbs
// floating over the world; clicking one is how almost everything starts.
Interactable :: struct {
	id:         string,
	label:      string,
	pos:        rl.Vector2, // where the orb sits, in tiles
	height:     f32, // how high the orb floats
	node:       string, // dialogue node this opens
	stand:      rl.Vector2, // where the player stands to use it
	require:    string, // flag that must be set for it to appear ("" = always)
	hide_when:  string, // flag that hides it once set
	seen:       bool,
	is_person:  bool,
	// Screen anchor in the 1600x900 top-down painting. Gameplay still uses the
	// grid position; this only puts the evidence halo over the painted object.
	topdown_pos: rl.Vector2,
}

Light :: struct {
	pos:       rl.Vector2,
	height:    f32,
	color:     rl.Color,
	radius:    f32,
	intensity: f32,
}

Scene :: struct {
	name:          string,
	nav:           Nav_Grid,
	props:         [dynamic]Prop,
	interactables: [dynamic]Interactable,
	lights:        [dynamic]Light,
	spawn:         rl.Vector2,
	// Entry dialogue fired the first time the scene is entered.
	opening_node:  string,
}

Player :: struct {
	pos:      rl.Vector2,
	path:     []rl.Vector2,
	path_idx: int,
	speed:    f32,
	facing:   rl.Vector2,
	bob:      f32, // walk cycle phase, drives the shoulder sway
	// Set when a walk was ordered in order to reach an interactable.
	pending_interactable: int,
}

// The playable painting uses the same authored grid as navigation, but renders
// it as an orthographic top-down room. Coordinates target the 1600x900 master.
topdown_world_to_screen :: proc(g: ^Game, p: rl.Vector2) -> rl.Vector2 {
	sx := f32(rl.GetScreenWidth()) / 1600.0
	sy := f32(rl.GetScreenHeight()) / 900.0
	return {
		(80.0 + p.x*78.0) * sx,
		(72.0 + p.y*55.0) * sy,
	}
}

topdown_screen_to_world :: proc(s: rl.Vector2) -> rl.Vector2 {
	sx := f32(rl.GetScreenWidth()) / 1600.0
	sy := f32(rl.GetScreenHeight()) / 900.0
	return {(s.x/sx - 80.0) / 78.0, (s.y/sy - 72.0) / 55.0}
}

interactable_screen_pos :: proc(g: ^Game, it: Interactable) -> rl.Vector2 {
	if g.world_art_loaded {
		if it.topdown_pos.x > 0 || it.topdown_pos.y > 0 {
			return {it.topdown_pos.x * f32(rl.GetScreenWidth()) / 1600.0, it.topdown_pos.y * f32(rl.GetScreenHeight()) / 900.0}
		}
		return topdown_world_to_screen(g, it.pos)
	}
	return world_to_screen(g.camera, it.pos.x, it.pos.y, it.height)
}

PLAYER_SPEED :: 3.4
INTERACT_RANGE :: 1.9

scene_init :: proc(s: ^Scene, name: string, w, h: int) {
	s.name = name
	nav_init(&s.nav, w, h)
	s.props = make([dynamic]Prop)
	s.interactables = make([dynamic]Interactable)
	s.lights = make([dynamic]Light)
}

// Adds a prop and, if it is solid, carves it out of the nav grid.
scene_add_prop :: proc(s: ^Scene, p: Prop) {
	append(&s.props, p)
	if p.blocks {
		nav_block_rect(
			&s.nav,
			int(p.pos.x),
			int(p.pos.y),
			int(math.ceil(p.size.x)),
			int(math.ceil(p.size.y)),
		)
	}
}

scene_add_interactable :: proc(s: ^Scene, i: Interactable) {
	append(&s.interactables, i)
}

interactable_visible :: proc(g: ^Game, it: Interactable) -> bool {
	if it.require != "" && !flag_is_set(g, it.require) {
		return false
	}
	if it.hide_when != "" && flag_is_set(g, it.hide_when) {
		return false
	}
	return true
}

// ---------------------------------------------------------------------------
// Player movement
// ---------------------------------------------------------------------------

player_order_move :: proc(g: ^Game, target: rl.Vector2, interactable_idx: int = -1) {
	p := &g.player_ent
	if p.path != nil {
		delete(p.path)
		p.path = nil
	}
	p.path = nav_find_path(&g.scene.nav, p.pos, target)
	p.path_idx = 0
	p.pending_interactable = interactable_idx
}

player_update :: proc(g: ^Game, dt: f32) {
	p := &g.player_ent

	if p.path == nil || p.path_idx >= len(p.path) {
		p.bob = math.lerp(p.bob, f32(0), math.min(f32(1), dt * 8))
		return
	}

	target := p.path[p.path_idx]
	delta := target - p.pos
	dist := math.sqrt(delta.x * delta.x + delta.y * delta.y)

	if dist < 0.06 {
		p.path_idx += 1
		if p.path_idx >= len(p.path) {
			delete(p.path)
			p.path = nil
			player_arrive(g)
		}
		return
	}

	dir := delta / dist
	p.facing = dir
	step := PLAYER_SPEED * dt
	if step > dist {
		step = dist
	}
	p.pos += dir * step
	p.bob += dt * 9.5
}

// Called the moment the player stops walking, so a move ordered by clicking an
// orb opens that orb's dialogue on arrival rather than immediately.
player_arrive :: proc(g: ^Game) {
	p := &g.player_ent
	idx := p.pending_interactable
	p.pending_interactable = -1
	if idx < 0 || idx >= len(g.scene.interactables) {
		return
	}
	it := &g.scene.interactables[idx]
	it.seen = true
	dialogue_start(g, &g.script, it.node)
}

// The orb nearest the cursor, within a generous pick radius. Returns -1 for
// none. Pick radius is in screen pixels because that is what the hand does.
world_pick_interactable :: proc(g: ^Game, mouse: rl.Vector2) -> int {
	best := -1
	best_dist := f32(46)

	for &it, i in g.scene.interactables {
		if !interactable_visible(g, it) {
			continue
		}
		sp := interactable_screen_pos(g, it)
		d := rl.Vector2Distance(sp, mouse)
		if d < best_dist {
			best_dist = d
			best = i
		}
	}
	return best
}

// Where to stand when using an interactable: its authored stand point if it has
// one, otherwise the nearest walkable tile to it.
interactable_stand_point :: proc(g: ^Game, it: Interactable) -> rl.Vector2 {
	if it.stand.x != 0 || it.stand.y != 0 {
		return it.stand
	}
	x, y, ok := nav_nearest_walkable(&g.scene.nav, int(it.pos.x), int(it.pos.y))
	if !ok {
		return it.pos
	}
	return {f32(x) + 0.5, f32(y) + 0.5}
}

world_update :: proc(g: ^Game, dt: f32) {
	player_update(g, dt)
	g.orb_phase += dt
	if g.click_marker_life > 0 {
		g.click_marker_life -= dt
	}
}

// ---------------------------------------------------------------------------
// World input, only live when no dialogue is open
// ---------------------------------------------------------------------------

world_handle_input :: proc(g: ^Game) {
	mouse := rl.GetMousePosition()
	g.hovered_interactable = world_pick_interactable(g, mouse)

	if !rl.IsMouseButtonPressed(.LEFT) {
		return
	}

	if g.hovered_interactable >= 0 {
		it := g.scene.interactables[g.hovered_interactable]
		stand := interactable_stand_point(g, it)
		// Already close enough? Then just talk, do not shuffle into position.
		if rl.Vector2Distance(g.player_ent.pos, it.pos) <= INTERACT_RANGE {
			g.scene.interactables[g.hovered_interactable].seen = true
			dialogue_start(g, &g.script, it.node)
		} else {
			player_order_move(g, stand, g.hovered_interactable)
		}
		return
	}

	target := g.world_art_loaded ? topdown_screen_to_world(mouse) : screen_to_world(g.camera, mouse)
	if nav_walkable_at(&g.scene.nav, target) {
		player_order_move(g, target)
		g.click_marker = target
		g.click_marker_life = 0.5
	} else {
		x, y, ok := nav_nearest_walkable(
			&g.scene.nav,
			int(math.floor(target.x)),
			int(math.floor(target.y)),
		)
		if ok {
			pt := rl.Vector2{f32(x) + 0.5, f32(y) + 0.5}
			player_order_move(g, pt)
			g.click_marker = pt
			g.click_marker_life = 0.5
		}
	}
}

label_or_id :: proc(it: Interactable) -> string {
	if it.label != "" {
		return it.label
	}
	return it.id
}
