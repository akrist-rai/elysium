package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// The world is a tile grid you walk around with WASD. Nothing here is on rails:
// the camera follows you, the room extends past the edges of the screen, and
// the only thing that interrupts you is standing next to something and pressing
// the interact key.

PLAYER_RADIUS :: f32(0.30)
PLAYER_ACCEL :: f32(46.0)
PLAYER_FRICTION :: f32(30.0)
PLAYER_MAX_SPEED :: f32(4.6)

NPC_SPEED :: f32(1.9)
NPC_RADIUS :: f32(0.28)

INTERACT_RANGE :: f32(1.75)

Actor_Kind :: enum u8 {
	Player,
	Sysadmin, // hovers by the racks, exactly as promised
	Sleeper, // Priya, face down on the desk
}

Actor :: struct {
	kind:    Actor_Kind,
	pos:     rl.Vector2,
	vel:     rl.Vector2,
	facing:  f32, // radians; 0 points east
	bob:     f32, // walk cycle phase
	// wander state, unused by the player
	home:     rl.Vector2,
	path:     []rl.Vector2,
	path_idx: int,
	wait:     f32,
	require:  string, // world flag that has to be set before they exist
}

Light :: struct {
	pos:       rl.Vector2,
	color:     rl.Color,
	radius:    f32, // in tiles
	intensity: f32,
	flicker:   f32, // 0 steady, 1 a tube on its way out
	phase:     f32,
}

// A mark on the floor: cable runs, scuffs, the shape of where you were lying.
Decal_Kind :: enum u8 {
	Cable,
	Stain,
	Scuff,
	Coat_Print,
}

Decal :: struct {
	kind: Decal_Kind,
	a, b: rl.Vector2,
	size: f32,
	tint: rl.Color,
}

// The small stuff on top of the furniture. None of it is solid — it exists so
// that a desk reads as somebody's desk rather than as a brown rectangle.
Detail_Prop_Kind :: enum u8 {
	Monitor,
	Keyboard,
	Papers,
	Cup,
	Toolbox,
	Cable_Coil,
}

Detail_Prop :: struct {
	kind: Detail_Prop_Kind,
	pos:  rl.Vector2,
}

// A thing you can walk up to and talk to or look at.
Interactable :: struct {
	id:           string,
	label:        string,
	pos:          rl.Vector2,
	node:         string, // dialogue node this opens
	require:      string, // flag that must be set for it to exist
	hide_when:    string, // flag that retires it
	seen:         bool,
	is_person:    bool,
	follow_actor: int, // -1, or an index into scene.actors that carries it
}

Scene :: struct {
	name:          string,
	grid:          Tile_Map,
	nav:           Nav_Grid,
	interactables: [dynamic]Interactable,
	lights:        [dynamic]Light,
	actors:        [dynamic]Actor,
	decals:        [dynamic]Decal,
	props:         [dynamic]Detail_Prop,
	spawn:         rl.Vector2,
	opening_node:  string,
	built:         bool,
}

// ---------------------------------------------------------------------------
// Scene lifecycle
// ---------------------------------------------------------------------------

scene_destroy :: proc(s: ^Scene) {
	tilemap_destroy(&s.grid)
	if s.nav.walkable != nil {
		delete(s.nav.walkable)
		s.nav.walkable = nil
	}
	for &a in s.actors {
		if a.path != nil {
			delete(a.path)
			a.path = nil
		}
	}
	delete(s.interactables)
	delete(s.lights)
	delete(s.actors)
	delete(s.decals)
	delete(s.props)
	s.interactables = nil
	s.lights = nil
	s.actors = nil
	s.decals = nil
	s.props = nil
	s.built = false
}

// Navigation reads straight off the tile grid, so the geometry you can see and
// the geometry the sysadmin walks around can never drift apart.
nav_build_from_map :: proc(n: ^Nav_Grid, m: ^Tile_Map) {
	nav_init(n, m.w, m.h)
	for y in 0 ..< m.h {
		for x in 0 ..< m.w {
			if tile_blocks(tilemap_at(m, x, y)) {
				n.walkable[y * n.w + x] = false
			}
		}
	}
}

scene_add_interactable :: proc(s: ^Scene, i: Interactable) {
	it := i
	if it.follow_actor == 0 && it.id != "" {
		// Zero is a real actor index, so callers that mean "none" must say -1.
		// Anything left at the zero value is treated as unattached.
	}
	append(&s.interactables, it)
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

// People carry their own marker around with them.
interactable_pos :: proc(g: ^Game, it: Interactable) -> rl.Vector2 {
	if it.follow_actor >= 0 && it.follow_actor < len(g.scene.actors) {
		return g.scene.actors[it.follow_actor].pos
	}
	return it.pos
}

label_or_id :: proc(it: Interactable) -> string {
	if it.label != "" {
		return it.label
	}
	return it.id
}

// ---------------------------------------------------------------------------
// Collision
// ---------------------------------------------------------------------------

// Move one axis at a time and push back out of anything solid. Resolving the
// axes separately is what lets you slide along a rack instead of sticking to it.
@(private = "file")
resolve_axis :: proc(m: ^Tile_Map, pos: rl.Vector2, radius: f32, horizontal: bool) -> rl.Vector2 {
	p := pos
	x0 := int(math.floor(p.x - radius))
	x1 := int(math.floor(p.x + radius))
	y0 := int(math.floor(p.y - radius))
	y1 := int(math.floor(p.y + radius))

	for ty in y0 ..= y1 {
		for tx in x0 ..= x1 {
			if !tile_blocks(tilemap_at(m, tx, ty)) {
				continue
			}
			minx, maxx := f32(tx), f32(tx + 1)
			miny, maxy := f32(ty), f32(ty + 1)

			// Closest point on the tile to the circle centre.
			cx := clamp(p.x, minx, maxx)
			cy := clamp(p.y, miny, maxy)
			dx := p.x - cx
			dy := p.y - cy
			if dx * dx + dy * dy >= radius * radius {
				continue
			}

			if horizontal {
				p.x = p.x < (minx + maxx) * 0.5 ? minx - radius : maxx + radius
			} else {
				p.y = p.y < (miny + maxy) * 0.5 ? miny - radius : maxy + radius
			}
		}
	}
	return p
}

move_with_collision :: proc(m: ^Tile_Map, pos, delta: rl.Vector2, radius: f32) -> rl.Vector2 {
	p := pos
	p.x += delta.x
	p = resolve_axis(m, p, radius, true)
	p.y += delta.y
	p = resolve_axis(m, p, radius, false)
	return p
}

// ---------------------------------------------------------------------------
// The player
// ---------------------------------------------------------------------------

player_input_dir :: proc() -> rl.Vector2 {
	dir := rl.Vector2{0, 0}
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
		dir.y -= 1
	}
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
		dir.y += 1
	}
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
		dir.x -= 1
	}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
		dir.x += 1
	}
	if dir.x != 0 && dir.y != 0 {
		// Diagonals must not be faster than the cardinals.
		dir = rl.Vector2Normalize(dir)
	}
	return dir
}

player_update :: proc(g: ^Game, dt: f32, accept_input: bool) {
	p := &g.player_ent
	dir := accept_input ? player_input_dir() : rl.Vector2{0, 0}

	if dir.x != 0 || dir.y != 0 {
		p.vel += dir * PLAYER_ACCEL * dt
		speed := rl.Vector2Length(p.vel)
		if speed > PLAYER_MAX_SPEED {
			p.vel = p.vel * (PLAYER_MAX_SPEED / speed)
		}
		// Turn toward travel rather than snapping, so corners read as turns.
		want := math.atan2(dir.y, dir.x)
		p.facing = angle_toward(p.facing, want, dt * 14)
	} else {
		speed := rl.Vector2Length(p.vel)
		drop := PLAYER_FRICTION * dt
		if speed <= drop {
			p.vel = {0, 0}
		} else {
			p.vel = p.vel * ((speed - drop) / speed)
		}
	}

	if p.vel.x != 0 || p.vel.y != 0 {
		p.pos = move_with_collision(&g.scene.grid, p.pos, p.vel * dt, PLAYER_RADIUS)
		p.bob += rl.Vector2Length(p.vel) * dt * 3.4
	} else {
		p.bob = math.lerp(p.bob, math.round(p.bob / math.PI) * math.PI, math.min(f32(1), dt * 9))
	}
}

// Shortest way round the circle, so turning from 179 to -179 is a nudge and not
// a full spin.
angle_toward :: proc(current, target, max_step: f32) -> f32 {
	diff := target - current
	for diff > math.PI {
		diff -= math.TAU
	}
	for diff < -math.PI {
		diff += math.TAU
	}
	if math.abs(diff) <= max_step {
		return target
	}
	return current + math.sign(diff) * max_step
}

// ---------------------------------------------------------------------------
// Non-player actors
// ---------------------------------------------------------------------------

actor_exists :: proc(g: ^Game, a: Actor) -> bool {
	return a.require == "" || flag_is_set(g, a.require)
}

// The sysadmin said they were not going to hover, and then said they were going
// to hover a little. This is the little.
npc_update :: proc(g: ^Game, idx: int, dt: f32) {
	a := &g.scene.actors[idx]
	if a.kind == .Sleeper || !actor_exists(g, a^) {
		return
	}

	// Stand still while you are being spoken to.
	if g.dialogue.active {
		a.vel = {0, 0}
		return
	}

	if a.path == nil || a.path_idx >= len(a.path) {
		a.wait -= dt
		a.bob = math.lerp(a.bob, 0, math.min(f32(1), dt * 6))
		if a.wait <= 0 {
			npc_pick_destination(g, idx)
		}
		return
	}

	target := a.path[a.path_idx]
	delta := target - a.pos
	dist := rl.Vector2Length(delta)
	if dist < 0.08 {
		a.path_idx += 1
		if a.path_idx >= len(a.path) {
			delete(a.path)
			a.path = nil
			a.wait = 1.6 + rand.float32() * 4.0
		}
		return
	}

	dir := delta / dist
	a.facing = angle_toward(a.facing, math.atan2(dir.y, dir.x), dt * 9)
	step := math.min(NPC_SPEED * dt, dist)
	a.pos = move_with_collision(&g.scene.grid, a.pos, dir * step, NPC_RADIUS)
	a.bob += step * 3.0
}

@(private = "file")
npc_pick_destination :: proc(g: ^Game, idx: int) {
	a := &g.scene.actors[idx]
	for _ in 0 ..< 12 {
		angle := rand.float32() * math.TAU
		dist := 1.5 + rand.float32() * 3.5
		want := a.home + rl.Vector2{math.cos(angle) * dist, math.sin(angle) * dist}
		if !nav_walkable_at(&g.scene.nav, want) {
			continue
		}
		path := nav_find_path(&g.scene.nav, a.pos, want)
		if path == nil || len(path) == 0 {
			if path != nil {
				delete(path)
			}
			continue
		}
		a.path = path
		a.path_idx = 0
		return
	}
	a.wait = 2.0
}

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------

// The nearest thing within arm's reach. Distance is measured in the world, not
// on the screen, because reaching for something is a thing your body does.
world_nearest_interactable :: proc(g: ^Game) -> int {
	best := -1
	best_dist := INTERACT_RANGE

	for it, i in g.scene.interactables {
		if !interactable_visible(g, it) {
			continue
		}
		d := rl.Vector2Distance(interactable_pos(g, it), g.player_ent.pos)
		if d < best_dist {
			best_dist = d
			best = i
		}
	}
	return best
}

world_update :: proc(g: ^Game, dt: f32) {
	accept := g.mode == .World
	player_update(g, dt, accept)

	for i in 0 ..< len(g.scene.actors) {
		npc_update(g, i, dt)
	}

	g.orb_phase += dt
	g.hovered_interactable = world_nearest_interactable(g)

	// A small lead in the direction of travel; the camera should feel like it
	// wants to show you where you are going.
	lead := g.player_ent.vel * 0.22
	camera_follow(&g.camera, g.player_ent.pos, lead, dt)

	toasts_update(g, dt)
}

world_handle_input :: proc(g: ^Game) {
	if wheel := rl.GetMouseWheelMove(); wheel != 0 {
		g.camera.zoom = clamp(g.camera.zoom + wheel * 0.09, ZOOM_MIN, ZOOM_MAX)
	}

	if rl.IsKeyPressed(.E) || rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) {
		world_try_interact(g)
	}
}

world_try_interact :: proc(g: ^Game) {
	idx := g.hovered_interactable
	if idx < 0 || idx >= len(g.scene.interactables) {
		return
	}
	it := &g.scene.interactables[idx]
	it.seen = true
	// Face what you are talking to; it reads as attention.
	delta := interactable_pos(g, it^) - g.player_ent.pos
	if delta.x != 0 || delta.y != 0 {
		g.player_ent.facing = math.atan2(delta.y, delta.x)
	}
	g.player_ent.vel = {0, 0}
	dialogue_start(g, &g.script, it.node)
}
