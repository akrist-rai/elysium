package game

import "core:math"
import "core:slice"
import rl "vendor:raylib"

// Top-down, drawn in three passes: the floor, then everything standing on it
// sorted by how far down the screen its base sits, then a light map multiplied
// over the whole thing. Nothing here is a photograph of a room — it is the room,
// and it keeps going past the edges of the screen.

// Winding for raylib's culled 2D triangles.
TRI_CCW_SIGN :: f32(-1)

draw_tri :: proc(a, b, c: rl.Vector2, col: rl.Color) {
	cross := (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
	if cross * TRI_CCW_SIGN > 0 {
		rl.DrawTriangle(a, b, c, col)
	} else {
		rl.DrawTriangle(a, c, b, col)
	}
}

draw_quad :: proc(a, b, c, d: rl.Vector2, col: rl.Color) {
	draw_tri(a, b, c, col)
	draw_tri(a, c, d, col)
}

// A filled ellipse at an arbitrary angle. Everything with a body in this game is
// built out of these, so people read as shoulders and coats from above rather
// than as circles.
draw_ellipse_rot :: proc(center: rl.Vector2, rx, ry, angle: f32, col: rl.Color, segments: int = 22) {
	ca := math.cos(angle)
	sa := math.sin(angle)
	prev: rl.Vector2
	for i in 0 ..= segments {
		t := f32(i) / f32(segments) * math.TAU
		lx := math.cos(t) * rx
		ly := math.sin(t) * ry
		p := rl.Vector2{center.x + lx * ca - ly * sa, center.y + lx * sa + ly * ca}
		if i > 0 {
			draw_tri(center, prev, p, col)
		}
		prev = p
	}
}

// Deterministic per-tile noise. The floor has to look worn without looking
// random every frame, and without an art asset to sample.
// Unsigned arithmetic wraps at runtime, which is exactly what a bit-mixer
// wants. (This Odin nightly no longer has the explicit `*%` / `+%` forms.)
@(private = "file")
hash2 :: proc(x, y: int) -> u32 {
	h := u32(x) * 374761393 + u32(y) * 668265263
	h = (h ~ (h >> 13)) * 1274126177
	return h ~ (h >> 16)
}

@(private = "file")
hashf :: proc(x, y: int) -> f32 {
	return f32(hash2(x, y) % 2048) / 2048.0
}

w2s :: proc(g: ^Game, p: rl.Vector2) -> rl.Vector2 {
	return world_to_screen(g.camera, p)
}

// World-space rectangle to a screen rectangle. The half-pixel of overdraw keeps
// neighbouring tiles from showing a seam when the camera lands on a fraction.
@(private = "file")
world_rect :: proc(g: ^Game, x, y, w, h: f32) -> rl.Rectangle {
	tl := w2s(g, {x, y})
	s := camera_scale(g.camera)
	return {tl.x, tl.y, w * s + 1, h * s + 1}
}

// ---------------------------------------------------------------------------
// Draw list
// ---------------------------------------------------------------------------

Draw_Kind :: enum u8 {
	Tile,
	Actor,
	Prop,
}

Draw_Item :: struct {
	depth: f32,
	kind:  Draw_Kind,
	index: int,
	x, y:  int,
}

// How far below its own tile a standing thing paints. This is the whole trick
// of a top-down room: the south face is what turns a coloured square into an
// object with a height.
@(private = "file")
tile_height :: proc(t: Tile) -> f32 {
	#partial switch t {
	case .Wall, .Wall_Board, .Wall_Screen, .Wall_Notice, .Wall_Exit:
		return 0.55
	case .Rack:
		return 0.52
	case .Shelf:
		return 0.46
	case .Crate:
		return 0.32
	case .Printer:
		return 0.26
	case .Desk:
		return 0.24
	case .Bench:
		return 0.21
	case .Spool:
		return 0.19
	case .Chair:
		return 0.15
	}
	return 0
}

// ---------------------------------------------------------------------------
// Floor
// ---------------------------------------------------------------------------

// The albedo of a surface, before any light lands on it. These are much
// brighter than the final pixel: the light map multiplies over the top.
@(private = "file")
floor_base :: proc(t: Tile) -> rl.Color {
	#partial switch t {
	case .Floor_Tech:
		return rl.Color{104, 108, 112, 255} // raised anti-static panels
	case .Floor_Corridor:
		return rl.Color{96, 91, 88, 255}
	case .Floor_Office:
		return rl.Color{100, 93, 85, 255}
	case .Door:
		return rl.Color{86, 82, 78, 255}
	}
	return rl.Color{30, 31, 33, 255}
}

// Wear is sampled at the tile's four corners and drawn as a gradient, so
// neighbouring tiles share their corner values exactly and the variation drifts
// across the floor instead of stepping at every boundary. A per-tile constant
// looks subtle on its own, but the painterly pass preserves edges by design --
// it would keep every one of those steps as a crisp line and turn the floor
// into graph paper.
@(private = "file")
floor_corner :: proc(base: rl.Color, x, y: int) -> rl.Color {
	return scale_rgb(base, 0.93 + hashf(x, y) * 0.14)
}

@(private = "file")
draw_floor :: proc(g: ^Game) {
	x0, y0, x1, y1 := camera_visible_tiles(g.camera)
	s := camera_scale(g.camera)
	// Barely-there seams. Strong ones turn the floor into graph paper, which is
	// the fastest way to make a room read as a grid instead of as a place.
	seam := fade(rl.Color{18, 19, 21, 255}, 0.22)

	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			t := tilemap_at(&g.scene.grid, x, y)
			if !tile_is_floor(t) {
				continue
			}
			r := world_rect(g, f32(x), f32(y), 1, 1)
			base := floor_base(t)
			rl.DrawRectangleGradientEx(
				r,
				floor_corner(base, x, y),
				floor_corner(base, x, y + 1),
				floor_corner(base, x + 1, y + 1),
				floor_corner(base, x + 1, y),
			)

			// Panel seams. Only the tech floor is panelled -- carpet gets
			// nothing, because anything laid out at one-tile spacing on carpet
			// reads as a checkerboard rather than as a weave.
			if t == .Floor_Tech {
				rl.DrawRectangleRec({r.x, r.y, r.width, math.max(1, s * 0.022)}, seam)
				rl.DrawRectangleRec({r.x, r.y, math.max(1, s * 0.022), r.height}, seam)
			}
		}
	}
}

@(private = "file")
draw_decals :: proc(g: ^Game) {
	s := camera_scale(g.camera)
	for d in g.scene.decals {
		switch d.kind {
		case .Cable:
			a := w2s(g, d.a)
			b := w2s(g, d.b)
			rl.DrawLineEx(a, b, math.max(1.5, d.size * s), d.tint)
			// A thin highlight along the top of the run so it reads as round.
			rl.DrawLineEx(
				{a.x, a.y - d.size * s * 0.28},
				{b.x, b.y - d.size * s * 0.28},
				math.max(1, d.size * s * 0.22),
				fade(rl.Color{120, 124, 130, 255}, 0.30),
			)
		case .Stain:
			c := w2s(g, d.a)
			for k := 3; k >= 1; k -= 1 {
				t := f32(k) / 3.0
				rl.DrawEllipse(i32(c.x), i32(c.y), d.size * s * t, d.size * s * 0.62 * t, fade(d.tint, 0.13))
			}
		case .Scuff:
			a := w2s(g, d.a)
			b := w2s(g, d.b)
			rl.DrawLineEx(a, b, math.max(1, d.size * s * 0.3), fade(d.tint, 0.16))
		case .Coat_Print:
			// The impression you left on the floor. Deliberately human-shaped.
			c := w2s(g, d.a)
			draw_ellipse_rot(c, s * 0.46, s * 0.30, 0.4, fade(d.tint, 0.40))
			draw_ellipse_rot({c.x + s * 0.30, c.y - s * 0.18}, s * 0.16, s * 0.15, 0, fade(d.tint, 0.34))
		}
	}
}

// ---------------------------------------------------------------------------
// Standing things
// ---------------------------------------------------------------------------

// The cap is the surface you would see looking straight down; the face is the
// side that catches light. Every solid tile is drawn as this pair.
@(private = "file")
draw_solid_tile :: proc(g: ^Game, x, y: int, t: Tile) {
	s := camera_scale(g.camera)
	h := tile_height(t)
	n := hashf(x, y)

	cap_col, face_col: rl.Color
	switch t {
	case .Wall:
		cap_col = scale_rgb(rl.Color{84, 84, 90, 255}, 0.92 + n * 0.16)
		face_col = rl.Color{126, 122, 118, 255}
	case .Wall_Board:
		cap_col = rl.Color{92, 92, 96, 255}
		face_col = rl.Color{224, 222, 212, 255}
	case .Wall_Screen:
		cap_col = rl.Color{72, 76, 82, 255}
		face_col = rl.Color{54, 72, 92, 255}
	case .Wall_Notice:
		cap_col = rl.Color{88, 84, 80, 255}
		face_col = rl.Color{168, 132, 92, 255}
	case .Wall_Exit:
		cap_col = rl.Color{86, 70, 66, 255}
		face_col = rl.Color{148, 66, 54, 255}
	case .Rack:
		cap_col = scale_rgb(rl.Color{68, 72, 80, 255}, 0.9 + n * 0.2)
		face_col = rl.Color{54, 60, 68, 255}
	case .Desk:
		cap_col = scale_rgb(rl.Color{138, 108, 78, 255}, 0.92 + n * 0.14)
		face_col = rl.Color{100, 76, 56, 255}
	case .Bench:
		cap_col = rl.Color{118, 120, 126, 255}
		face_col = rl.Color{88, 90, 96, 255}
	case .Crate:
		cap_col = scale_rgb(rl.Color{150, 122, 84, 255}, 0.9 + n * 0.2)
		face_col = rl.Color{112, 90, 60, 255}
	case .Shelf:
		cap_col = rl.Color{94, 96, 100, 255}
		face_col = rl.Color{70, 72, 76, 255}
	case .Spool:
		cap_col = rl.Color{90, 94, 86, 255}
		face_col = rl.Color{66, 70, 64, 255}
	case .Printer:
		cap_col = rl.Color{226, 222, 212, 255}
		face_col = rl.Color{176, 174, 168, 255}
	case .Chair:
		cap_col = rl.Color{82, 86, 96, 255}
		face_col = rl.Color{62, 66, 74, 255}
	case .Void, .Floor_Tech, .Floor_Corridor, .Floor_Office, .Door:
		return
	}

	south := tilemap_at(&g.scene.grid, x, y + 1)
	south_open := !tile_blocks(south) || tile_height(south) < h - 0.05

	// Contact shadow, but only where it would land on open floor. Casting one
	// from every tile of a stacked block painted dark bands across the racks.
	if !tile_blocks(south) {
		shadow := world_rect(g, f32(x) - 0.06, f32(y) + h * 0.55, 1.12, 1.0)
		rl.DrawRectangleRec(shadow, fade(rl.Color{8, 9, 11, 255}, 0.30))
	}

	if h > 0 && south_open {
		face := world_rect(g, f32(x), f32(y) + 1 - h * 0.35, 1, h)
		rl.DrawRectangleGradientEx(
			face,
			scale_rgb(face_col, 1.12),
			scale_rgb(face_col, 0.62),
			scale_rgb(face_col, 0.62),
			scale_rgb(face_col, 1.12),
		)
	}

	// The cap is shortened to make room for the face below it -- but only on the
	// tile that actually has a face. Shortening every tile of a stacked block
	// left a strip of bare floor showing between them, which read as black bars
	// painted across the rack row.
	cap_h := south_open ? 1 - h * 0.35 : f32(1.0)
	cap := world_rect(g, f32(x), f32(y), 1, cap_h)
	rl.DrawRectangleRec(cap, cap_col)

	// A lit lip along the top edge, which is what separates one object from the
	// one behind it without drawing an outline around everything.
	if !tile_blocks(tilemap_at(&g.scene.grid, x, y - 1)) {
		rl.DrawRectangleRec({cap.x, cap.y, cap.width, math.max(1, s * 0.03)}, fade(rl.Color{150, 148, 140, 255}, 0.30))
	}

	draw_tile_detail(g, x, y, t, cap, s)
}

// The difference between a grey box and a server rack is about six lines of
// detail, and this is where they go.
@(private = "file")
draw_tile_detail :: proc(g: ^Game, x, y: int, t: Tile, cap: rl.Rectangle, s: f32) {
	#partial switch t {
	case .Rack:
		// Vent slots across the cap.
		rows := 5
		for i in 0 ..< rows {
			ry := cap.y + cap.height * (0.16 + f32(i) * 0.17)
			rl.DrawRectangleRec({cap.x + cap.width * 0.12, ry, cap.width * 0.76, math.max(1, s * 0.018)}, fade(rl.Color{16, 17, 19, 255}, 0.34))
		}
		// Status LEDs on the front face, blinking on their own clocks.
		if tilemap_at(&g.scene.grid, x, y + 1) != .Rack {
			fy := cap.y + cap.height + s * 0.10
			for i in 0 ..< 4 {
				seed := hashf(x * 13 + i, y * 5)
				lit := math.sin(g.time * (1.4 + seed * 3.0) + seed * 30) > -0.35
				col := seed > 0.72 ? rl.Color{240, 176, 96, 255} : rl.Color{120, 226, 200, 255}
				rl.DrawRectangleRec(
					{cap.x + cap.width * (0.16 + f32(i) * 0.20), fy, math.max(1.5, s * 0.05), math.max(1.5, s * 0.035)},
					fade(col, lit ? 0.95 : 0.16),
				)
			}
		}
	case .Desk:
		// Wood grain, faint.
		for i in 0 ..< 3 {
			gy := cap.y + cap.height * (0.25 + f32(i) * 0.25)
			rl.DrawRectangleRec({cap.x + cap.width * 0.06, gy, cap.width * 0.88, math.max(1, s * 0.012)}, fade(rl.Color{40, 30, 22, 255}, 0.30))
		}
	case .Wall_Board:
		// Handwriting on the whiteboard, as marks rather than letters.
		for i in 0 ..< 4 {
			seed := hashf(x * 3 + i, y + i)
			ly := cap.y + cap.height * 0.30 + f32(i) * s * 0.10
			rl.DrawRectangleRec(
				{cap.x + cap.width * 0.10, ly, cap.width * (0.30 + seed * 0.55), math.max(1, s * 0.022)},
				fade(rl.Color{52, 62, 80, 255}, 0.55),
			)
		}
	case .Wall_Screen:
		// The frozen scoreboard: rows that do not move, because it stopped.
		for i in 0 ..< 6 {
			ly := cap.y + cap.height * 0.14 + f32(i) * s * 0.115
			w := cap.width * (0.26 + hashf(x + i, y * 2) * 0.5)
			rl.DrawRectangleRec({cap.x + cap.width * 0.12, ly, w, math.max(1, s * 0.05)}, fade(rl.Color{96, 180, 220, 255}, 0.62))
		}
	case .Wall_Notice:
		for i in 0 ..< 3 {
			seed := hashf(x + i * 5, y)
			rl.DrawRectangleRec(
				{cap.x + cap.width * (0.10 + seed * 0.4), cap.y + cap.height * (0.2 + f32(i) * 0.24), cap.width * 0.34, cap.height * 0.2},
				fade(rl.Color{226, 222, 210, 255}, 0.7),
			)
		}
	case .Wall_Exit:
		rl.DrawRectangleRec(
			{cap.x + cap.width * 0.18, cap.y + cap.height * 0.3, cap.width * 0.64, cap.height * 0.4},
			fade(rl.Color{250, 140, 110, 255}, 0.9),
		)
	case .Printer:
		rl.DrawRectangleRec({cap.x + cap.width * 0.16, cap.y + cap.height * 0.5, cap.width * 0.68, cap.height * 0.3}, fade(rl.Color{60, 60, 62, 255}, 0.8))
	case .Crate:
		rl.DrawRectangleLinesEx({cap.x + cap.width * 0.12, cap.y + cap.height * 0.16, cap.width * 0.76, cap.height * 0.66}, math.max(1, s * 0.02), fade(rl.Color{50, 40, 28, 255}, 0.7))
	case .Shelf:
		for i in 0 ..< 3 {
			rl.DrawRectangleRec(
				{cap.x + cap.width * 0.1, cap.y + cap.height * (0.2 + f32(i) * 0.26), cap.width * 0.8, math.max(1, s * 0.03)},
				fade(rl.Color{28, 29, 31, 255}, 0.8),
			)
		}
	case .Spool:
		c := rl.Vector2{cap.x + cap.width * 0.5, cap.y + cap.height * 0.5}
		rl.DrawCircleV(c, cap.width * 0.42, rl.Color{46, 48, 44, 255})
		rl.DrawCircleV(c, cap.width * 0.16, rl.Color{30, 31, 29, 255})
	case .Chair:
		c := rl.Vector2{cap.x + cap.width * 0.5, cap.y + cap.height * 0.55}
		rl.DrawCircleV(c, cap.width * 0.34, rl.Color{54, 56, 62, 255})
		rl.DrawCircleV(c, cap.width * 0.22, rl.Color{40, 42, 48, 255})
	}
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

@(private = "file")
draw_actor :: proc(g: ^Game, a: Actor, is_player: bool) {
	s := camera_scale(g.camera)
	base := w2s(g, a.pos)

	coat: rl.Color
	skin: rl.Color
	hair: rl.Color
	switch a.kind {
	case .Player:
		// The detective reads warmest of the three: you should always be able to
		// find yourself on a dark floor without a marker over your head.
		coat = rl.Color{104, 110, 132, 255}
		skin = rl.Color{212, 172, 136, 255}
		hair = rl.Color{86, 68, 54, 255}
	case .Sysadmin:
		coat = rl.Color{108, 132, 122, 255}
		skin = rl.Color{198, 156, 118, 255}
		hair = rl.Color{56, 48, 46, 255}
	case .Sleeper:
		coat = rl.Color{152, 116, 162, 255}
		skin = rl.Color{216, 178, 144, 255}
		hair = rl.Color{48, 40, 42, 255}
	}

	// Contact shadow, offset a little south of the body.
	rl.DrawEllipse(i32(base.x), i32(base.y + s * 0.16), s * 0.40, s * 0.22, fade(rl.Color{6, 7, 9, 255}, 0.42))

	if a.kind == .Sleeper {
		// Folded forward over the desk: shoulders square, head down and away,
		// one arm out across the surface.
		draw_ellipse_rot(base, s * 0.34, s * 0.26, 0, coat)
		draw_ellipse_rot({base.x - s * 0.30, base.y - s * 0.10}, s * 0.24, s * 0.09, -0.5, coat)
		head := rl.Vector2{base.x, base.y - s * 0.34}
		rl.DrawCircleV(head, s * 0.19, skin)
		draw_ellipse_rot({head.x, head.y - s * 0.05}, s * 0.20, s * 0.16, 0, hair)
		return
	}

	swing := math.sin(a.bob) * 0.34
	lift := math.abs(math.sin(a.bob)) * s * 0.035
	ang := a.facing
	perp := ang + math.PI * 0.5

	body := rl.Vector2{base.x, base.y - s * 0.12 - lift}

	// Order matters: arms go down before the coat, so the torso sits on top of
	// them and the silhouette stays one solid mass instead of three blobs.
	for side in 0 ..< 2 {
		sign := side == 0 ? f32(1) : f32(-1)
		phase := swing * sign
		ax := body.x + math.cos(perp) * s * 0.27 * sign + math.cos(ang) * s * phase * 0.55
		ay := body.y + math.sin(perp) * s * 0.27 * sign + math.sin(ang) * s * phase * 0.55
		draw_ellipse_rot({ax, ay}, s * 0.105, s * 0.15, ang, scale_rgb(coat, 0.74))
	}

	// The coat: broad across the shoulders, narrow front-to-back. That ratio is
	// the entire reason a top-down figure reads as facing somewhere.
	draw_ellipse_rot(body, s * 0.30, s * 0.235, perp, scale_rgb(coat, 0.80))
	// Shoulder line, forward of centre and slightly narrower, catching the light.
	draw_ellipse_rot(
		{body.x + math.cos(ang) * s * 0.055, body.y + math.sin(ang) * s * 0.055},
		s * 0.255,
		s * 0.175,
		perp,
		coat,
	)
	// The collar: a thin bright arc at the front of the shoulders.
	draw_ellipse_rot(
		{body.x + math.cos(ang) * s * 0.13, body.y + math.sin(ang) * s * 0.13},
		s * 0.145,
		s * 0.075,
		perp,
		scale_rgb(coat, 1.30),
	)

	// Head sits forward of the shoulders and is clearly smaller than them, with
	// the hair mass pushed to the back so front and back are never ambiguous.
	head := rl.Vector2{
		body.x + math.cos(ang) * s * 0.075,
		body.y + math.sin(ang) * s * 0.075 - s * 0.025,
	}
	rl.DrawCircleV(head, s * 0.145, skin)
	draw_ellipse_rot(
		{head.x - math.cos(ang) * s * 0.055, head.y - math.sin(ang) * s * 0.055},
		s * 0.135,
		s * 0.125,
		ang,
		hair,
	)
	// A sliver of brow catching the light, on the leading edge of the head.
	draw_ellipse_rot(
		{head.x + math.cos(ang) * s * 0.055, head.y + math.sin(ang) * s * 0.055},
		s * 0.075,
		s * 0.045,
		perp,
		scale_rgb(skin, 1.12),
	)

	if a.kind == .Sysadmin {
		// Still holding both coffees.
		for side in 0 ..< 2 {
			sign := side == 0 ? f32(1) : f32(-1)
			cx := body.x + math.cos(perp) * s * 0.30 * sign + math.cos(ang) * s * 0.19
			cy := body.y + math.sin(perp) * s * 0.30 * sign + math.sin(ang) * s * 0.19
			rl.DrawCircleV({cx, cy}, s * 0.062, rl.Color{226, 220, 206, 255})
			rl.DrawCircleV({cx, cy}, s * 0.040, rl.Color{78, 56, 40, 255})
		}
	}
}

// ---------------------------------------------------------------------------
// Detail props
// ---------------------------------------------------------------------------

@(private = "file")
draw_detail_prop :: proc(g: ^Game, p: Detail_Prop) {
	s := camera_scale(g.camera)
	c := w2s(g, p.pos)

	switch p.kind {
	case .Monitor:
		// Seen from above: a thin bright screen edge and the glow it throws
		// forward onto the desk.
		rl.DrawEllipse(i32(c.x), i32(c.y + s * 0.06), s * 0.30, s * 0.12, fade(rl.Color{8, 9, 11, 255}, 0.35))
		body := rl.Rectangle{c.x - s * 0.30, c.y - s * 0.10, s * 0.60, s * 0.20}
		rl.DrawRectangleRec(body, rl.Color{28, 30, 33, 255})
		screen := rl.Rectangle{c.x - s * 0.27, c.y - s * 0.07, s * 0.54, s * 0.10}
		rl.DrawRectangleRec(screen, fade(rl.Color{150, 232, 216, 255}, 0.85))
		// Text rows on the screen, frozen mid-submission.
		for i in 0 ..< 3 {
			rl.DrawRectangleRec(
				{screen.x + s * 0.03, screen.y + f32(i) * s * 0.03 + s * 0.01, s * (0.18 + hashf(i, int(p.pos.x)) * 0.28), math.max(1, s * 0.014)},
				fade(rl.Color{18, 40, 38, 255}, 0.7),
			)
		}
	case .Keyboard:
		rl.DrawRectangleRec({c.x - s * 0.24, c.y - s * 0.07, s * 0.48, s * 0.14}, rl.Color{42, 44, 48, 255})
		for i in 0 ..< 4 {
			rl.DrawRectangleRec({c.x - s * 0.21 + f32(i) * s * 0.11, c.y - s * 0.04, s * 0.09, s * 0.08}, fade(rl.Color{62, 64, 68, 255}, 0.9))
		}
	case .Papers:
		for i in 0 ..< 3 {
			seed := hashf(i * 7, int(p.pos.y * 10))
			draw_ellipse_rot(
				{c.x + (seed - 0.5) * s * 0.3, c.y + (hashf(i, 3) - 0.5) * s * 0.22},
				s * 0.16,
				s * 0.12,
				seed * 2,
				fade(rl.Color{206, 200, 184, 255}, 0.86),
			)
		}
	case .Cup:
		rl.DrawCircleV({c.x, c.y + s * 0.02}, s * 0.085, fade(rl.Color{8, 9, 11, 255}, 0.4))
		rl.DrawCircleV(c, s * 0.08, rl.Color{212, 206, 194, 255})
		rl.DrawCircleV(c, s * 0.055, rl.Color{52, 38, 28, 255})
	case .Toolbox:
		rl.DrawRectangleRec({c.x - s * 0.18, c.y - s * 0.12, s * 0.36, s * 0.24}, rl.Color{146, 72, 44, 255})
		rl.DrawRectangleRec({c.x - s * 0.06, c.y - s * 0.16, s * 0.12, s * 0.05}, rl.Color{60, 60, 62, 255})
	case .Cable_Coil:
		rl.DrawCircleV(c, s * 0.17, rl.Color{30, 32, 34, 255})
		rl.DrawCircleV(c, s * 0.11, rl.Color{44, 46, 48, 255})
		rl.DrawCircleV(c, s * 0.05, rl.Color{26, 28, 30, 255})
	}
}

// ---------------------------------------------------------------------------
// The world pass
// ---------------------------------------------------------------------------

render_world :: proc(g: ^Game) {
	rl.ClearBackground(rl.Color{12, 13, 15, 255})

	if !g.scene.built {
		return
	}

	draw_floor(g)
	draw_decals(g)

	x0, y0, x1, y1 := camera_visible_tiles(g.camera)
	items := make([dynamic]Draw_Item, context.temp_allocator)

	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			t := tilemap_at(&g.scene.grid, x, y)
			if tile_is_floor(t) || t == .Void {
				continue
			}
			// Sorted by the bottom edge of the tile, which is where it meets the
			// floor and therefore what decides who is in front of whom.
			append(&items, Draw_Item{depth = f32(y) + 1, kind = .Tile, index = 0, x = x, y = y})
		}
	}

	for a, i in g.scene.actors {
		if !actor_exists(g, a) {
			continue
		}
		append(&items, Draw_Item{depth = a.pos.y, kind = .Actor, index = i})
	}
	append(&items, Draw_Item{depth = g.player_ent.pos.y, kind = .Actor, index = -1})

	for p, i in g.scene.props {
		append(&items, Draw_Item{depth = p.pos.y + 0.05, kind = .Prop, index = i})
	}

	slice.sort_by(items[:], proc(a, b: Draw_Item) -> bool {
		return a.depth < b.depth
	})

	for item in items {
		switch item.kind {
		case .Tile:
			draw_solid_tile(g, item.x, item.y, tilemap_at(&g.scene.grid, item.x, item.y))
		case .Actor:
			if item.index < 0 {
				draw_actor(g, g.player_ent, true)
			} else {
				draw_actor(g, g.scene.actors[item.index], false)
			}
		case .Prop:
			draw_detail_prop(g, g.scene.props[item.index])
		}
	}
}

// ---------------------------------------------------------------------------
// Lighting
// ---------------------------------------------------------------------------

// What the light map clears to: the room with every lamp in it switched off.
// Deliberately just above the point where you would lose the floor, and named
// apart from lighting.odin's AMBIENT, which is a different quantity.
LIGHTMAP_AMBIENT :: rl.Color{64, 68, 82, 255}

light_intensity :: proc(l: Light, time: f32) -> f32 {
	if l.flicker <= 0 {
		return l.intensity
	}
	// A dying fluorescent does not fade, it stutters. Two detuned sines plus a
	// hard dropout reads as mains hum far better than noise does.
	t := time * 8.4 + l.phase
	wobble := (math.sin(t) * 0.5 + math.sin(t * 2.7) * 0.5)
	dip := math.sin(time * 1.3 + l.phase) > 0.94 ? f32(0.45) : f32(1.0)
	return l.intensity * (1.0 - l.flicker * 0.18 * (1.0 - wobble)) * dip
}

// Builds the light map: ambient everywhere, plus one additive falloff per
// source, then multiplied over the scene so unlit corners genuinely go dark.
render_lighting :: proc(g: ^Game) {
	rl.ClearBackground(LIGHTMAP_AMBIENT)
	if !g.scene.built {
		return
	}

	s := camera_scale(g.camera)
	rl.BeginBlendMode(.ADDITIVE)

	for l in g.scene.lights {
		c := w2s(g, l.pos)
		r := l.radius * s
		// Skip anything that cannot reach the screen.
		if c.x + r < 0 || c.y + r < 0 || c.x - r > f32(rl.GetScreenWidth()) || c.y - r > f32(rl.GetScreenHeight()) {
			continue
		}
		inten := light_intensity(l, g.time)
		// One falloff per source, no stacked core. Adding a second gradient on
		// top drove the centre of every tube straight to white and flattened
		// everything standing under it into a silhouette.
		rl.DrawCircleGradient(c, r, fade(l.color, inten), fade(l.color, 0))
	}

	// You carry a little light of your own, so you are never a silhouette in an
	// unlit corridor.
	pc := w2s(g, g.player_ent.pos)
	rl.DrawCircleGradient(pc, s * 3.0, fade(rl.Color{198, 186, 168, 255}, 0.22), fade(rl.Color{198, 186, 168, 255}, 0))

	rl.EndBlendMode()
}

// After the light map has been multiplied down, the sources themselves are put
// back additively -- otherwise the brightest things in the room get dimmed by
// their own lighting.
render_glow :: proc(g: ^Game) {
	if !g.scene.built {
		return
	}
	s := camera_scale(g.camera)
	rl.BeginBlendMode(.ADDITIVE)
	for l in g.scene.lights {
		c := w2s(g, l.pos)
		r := l.radius * s * 0.30
		if c.x + r < 0 || c.y + r < 0 || c.x - r > f32(rl.GetScreenWidth()) || c.y - r > f32(rl.GetScreenHeight()) {
			continue
		}
		inten := light_intensity(l, g.time)
		rl.DrawCircleGradient(c, r, fade(l.color, inten * 0.20), fade(l.color, 0))
	}
	rl.EndBlendMode()
}
