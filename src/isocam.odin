package game

import "core:math"
import rl "vendor:raylib"

// A 2:1 isometric projection. One world unit is one floor tile; z is height in
// the same units, so a rack two units tall is genuinely twice a desk.
TILE_HW :: 46.0 // half-width of a tile diamond
TILE_HH :: 23.0 // half-height
TILE_Z :: 40.0 // screen pixels per unit of height

Iso_Camera :: struct {
	offset: rl.Vector2, // screen-space pan
	zoom:   f32,
	// Pan is clamped to these world-space bounds so the room cannot be lost.
	bounds_min: rl.Vector2,
	bounds_max: rl.Vector2,
	drag_anchor: rl.Vector2,
	dragging:   bool,
}

camera_init :: proc(c: ^Iso_Camera, screen_w, screen_h: f32) {
	c.zoom = 1.0
	c.offset = {screen_w * 0.5, screen_h * 0.42}
}

world_to_screen :: proc(c: Iso_Camera, wx, wy, wz: f32) -> rl.Vector2 {
	sx := (wx - wy) * TILE_HW
	sy := (wx + wy) * TILE_HH - wz * TILE_Z
	return {sx * c.zoom + c.offset.x, sy * c.zoom + c.offset.y}
}

world_to_screen_v :: proc(c: Iso_Camera, p: rl.Vector2, wz: f32 = 0) -> rl.Vector2 {
	return world_to_screen(c, p.x, p.y, wz)
}

// Inverse projection onto the ground plane (z = 0).
screen_to_world :: proc(c: Iso_Camera, s: rl.Vector2) -> rl.Vector2 {
	sx := (s.x - c.offset.x) / c.zoom
	sy := (s.y - c.offset.y) / c.zoom
	return {(sx / TILE_HW + sy / TILE_HH) * 0.5, (sy / TILE_HH - sx / TILE_HW) * 0.5}
}

// Painter's-algorithm key. Objects further along both axes are nearer the
// viewer, so they draw later. Height breaks ties for things stacked in place.
depth_key :: proc(wx, wy, wz: f32) -> f32 {
	return wx + wy + wz * 0.001
}

camera_update :: proc(c: ^Iso_Camera, dt: f32, allow_input: bool) {
	if allow_input {
		// Middle-drag or right-drag pans; both feel natural and neither
		// collides with click-to-walk.
		if rl.IsMouseButtonPressed(.MIDDLE) || rl.IsMouseButtonPressed(.RIGHT) {
			c.dragging = true
			c.drag_anchor = rl.GetMousePosition()
		}
		if rl.IsMouseButtonReleased(.MIDDLE) || rl.IsMouseButtonReleased(.RIGHT) {
			c.dragging = false
		}
		if c.dragging {
			m := rl.GetMousePosition()
			c.offset += m - c.drag_anchor
			c.drag_anchor = m
		}

		speed: f32 = 520 * dt
		if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
			c.offset.x += speed
		}
		if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
			c.offset.x -= speed
		}
		if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
			c.offset.y += speed
		}
		if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
			c.offset.y -= speed
		}

		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			c.zoom = clamp(c.zoom + wheel*0.08, 0.6, 1.8)
		}
	}

	camera_clamp(c)
}

// Keeps the projected room bounding box overlapping the viewport.
camera_clamp :: proc(c: ^Iso_Camera) {
	if c.bounds_max.x <= c.bounds_min.x {
		return
	}
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	corners := [4]rl.Vector2 {
		{c.bounds_min.x, c.bounds_min.y},
		{c.bounds_max.x, c.bounds_min.y},
		{c.bounds_min.x, c.bounds_max.y},
		{c.bounds_max.x, c.bounds_max.y},
	}

	min_x, min_y := max(f32), max(f32)
	max_x, max_y := min(f32), min(f32)
	for p in corners {
		sx := (p.x - p.y) * TILE_HW * c.zoom
		sy := (p.x + p.y) * TILE_HH * c.zoom
		min_x = math.min(min_x, sx)
		max_x = math.max(max_x, sx)
		min_y = math.min(min_y, sy)
		max_y = math.max(max_y, sy)
	}

	// Leave at least a third of the room on screen in each direction.
	margin_x := sw * 0.34
	margin_y := sh * 0.34
	c.offset.x = clamp(c.offset.x, margin_x - max_x, sw - margin_x - min_x)
	c.offset.y = clamp(c.offset.y, margin_y - max_y, sh - margin_y - min_y)
}

camera_center_on :: proc(c: ^Iso_Camera, p: rl.Vector2, screen_w, screen_h: f32) {
	sx := (p.x - p.y) * TILE_HW * c.zoom
	sy := (p.x + p.y) * TILE_HH * c.zoom
	c.offset = {screen_w*0.5 - sx, screen_h*0.5 - sy}
	camera_clamp(c)
}
