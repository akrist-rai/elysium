package game

import "core:math"
import rl "vendor:raylib"

// A straight top-down camera. One world unit is one floor tile; TILE_PX is how
// many pixels that tile covers at zoom 1. The camera chases the player rather
// than snapping to them, and leads slightly in the direction they are walking,
// which is what stops a top-down game from feeling like a map viewer.

// How many tiles of room fill the height of the screen. Framing is defined in
// tiles rather than pixels so the game looks identical on a 900px laptop panel
// and a 1662px HiDPI one -- otherwise a sharper display just means a smaller
// character and more empty floor.
VIEW_TILES_V :: f32(11.5)

ZOOM_MIN :: f32(0.70)
ZOOM_MAX :: f32(1.70)
ZOOM_DEFAULT :: f32(1.0)

World_Camera :: struct {
	center:     rl.Vector2, // world tiles, the point under the middle of the screen
	zoom:       f32,
	bounds_min: rl.Vector2,
	bounds_max: rl.Vector2,
	shake:      f32,
	shake_seed: f32,
}

camera_init :: proc(c: ^World_Camera, at: rl.Vector2) {
	c.zoom = ZOOM_DEFAULT
	c.center = at
}

// Cut straight to a position with no chase, for spawning and teleports.
camera_snap :: proc(c: ^World_Camera, at: rl.Vector2) {
	c.center = at
	camera_clamp(c)
}

camera_set_bounds :: proc(c: ^World_Camera, w, h: int) {
	c.bounds_min = {0, 0}
	c.bounds_max = {f32(w), f32(h)}
}

camera_shake :: proc(c: ^World_Camera, amount: f32) {
	c.shake = math.max(c.shake, amount)
}

// Frame-rate independent smoothing: the 1-exp(-k*dt) form gives the same
// settling time whether the frame took 4ms or 40ms.
camera_follow :: proc(c: ^World_Camera, target: rl.Vector2, lead: rl.Vector2, dt: f32) {
	want := target + lead
	t := 1 - math.exp(-7.5 * dt)
	c.center += (want - c.center) * t

	if c.shake > 0 {
		c.shake = math.max(0, c.shake - dt * 2.2)
		c.shake_seed += dt * 47
	}

	camera_clamp(c)
}

// Keeps the view inside the building. When the map is smaller than the screen
// on an axis, the map is centred on that axis instead of clamped to an edge.
camera_clamp :: proc(c: ^World_Camera) {
	if c.bounds_max.x <= c.bounds_min.x {
		return
	}
	s := camera_scale(c^)
	half_w := f32(rl.GetScreenWidth()) * 0.5 / s
	half_h := f32(rl.GetScreenHeight()) * 0.5 / s

	span_x := c.bounds_max.x - c.bounds_min.x
	span_y := c.bounds_max.y - c.bounds_min.y

	if span_x <= half_w * 2 {
		c.center.x = (c.bounds_min.x + c.bounds_max.x) * 0.5
	} else {
		c.center.x = clamp(c.center.x, c.bounds_min.x + half_w, c.bounds_max.x - half_w)
	}
	if span_y <= half_h * 2 {
		c.center.y = (c.bounds_min.y + c.bounds_max.y) * 0.5
	} else {
		c.center.y = clamp(c.center.y, c.bounds_min.y + half_h, c.bounds_max.y - half_h)
	}
}

camera_offset :: proc(c: World_Camera) -> rl.Vector2 {
	if c.shake <= 0 {
		return {0, 0}
	}
	// Two out-of-phase sines read as a knock rather than as noise.
	amp := c.shake * 7
	return {math.sin(c.shake_seed) * amp, math.cos(c.shake_seed * 1.7) * amp}
}

world_to_screen :: proc(c: World_Camera, p: rl.Vector2) -> rl.Vector2 {
	s := camera_scale(c)
	off := camera_offset(c)
	return {
		(p.x - c.center.x) * s + f32(rl.GetScreenWidth()) * 0.5 + off.x,
		(p.y - c.center.y) * s + f32(rl.GetScreenHeight()) * 0.5 + off.y,
	}
}

screen_to_world :: proc(c: World_Camera, s: rl.Vector2) -> rl.Vector2 {
	px := camera_scale(c)
	return {
		(s.x - f32(rl.GetScreenWidth()) * 0.5) / px + c.center.x,
		(s.y - f32(rl.GetScreenHeight()) * 0.5) / px + c.center.y,
	}
}

// Pixels per tile on screen, which is the scale factor every world-space
// drawing routine multiplies its dimensions by. Derived from the window height
// so the framing is resolution independent; `zoom` is the player's own
// adjustment on top of that.
camera_scale :: proc(c: World_Camera) -> f32 {
	z := c.zoom <= 0 ? f32(1) : c.zoom
	return (f32(rl.GetScreenHeight()) / VIEW_TILES_V) * z
}

// The tile rectangle the screen currently covers, with a margin so props that
// straddle the edge are not popped in halfway.
camera_visible_tiles :: proc(c: World_Camera) -> (x0, y0, x1, y1: int) {
	half_w := f32(rl.GetScreenWidth()) * 0.5 / camera_scale(c)
	half_h := f32(rl.GetScreenHeight()) * 0.5 / camera_scale(c)
	margin := f32(3)
	x0 = int(math.floor(c.center.x - half_w - margin))
	y0 = int(math.floor(c.center.y - half_h - margin))
	x1 = int(math.ceil(c.center.x + half_w + margin))
	y1 = int(math.ceil(c.center.y + half_h + margin))
	return
}
