package game

import "core:math"
import "core:slice"
import rl "vendor:raylib"

// Everything in the world is drawn back-to-front by depth key. Isometric has no
// depth buffer to lean on, so ordering is the whole trick.
Draw_Kind :: enum u8 {
	Prop,
	Player,
	Orb,
}

Draw_Item :: struct {
	depth: f32,
	kind:  Draw_Kind,
	index: int,
}

// Winding for raylib's culled 2D triangles. Flipping this one constant flips
// every polygon in the game, which is the only knob needed if culling ever
// disagrees with us.
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

// One box, three visible faces. The two side faces are shaded apart so the
// form reads without any outline.
draw_box :: proc(cam: Iso_Camera, pos, size: rl.Vector2, height: f32, top, side: rl.Color) {
	x0, y0 := pos.x, pos.y
	x1, y1 := pos.x + size.x, pos.y + size.y

	// Top face
	t_nw := world_to_screen(cam, x0, y0, height)
	t_ne := world_to_screen(cam, x1, y0, height)
	t_se := world_to_screen(cam, x1, y1, height)
	t_sw := world_to_screen(cam, x0, y1, height)

	// Ground corners of the two faces that point at the viewer
	g_ne := world_to_screen(cam, x1, y0, 0)
	g_se := world_to_screen(cam, x1, y1, 0)
	g_sw := world_to_screen(cam, x0, y1, 0)

	// The +x face catches the warm key from the corridor, the +y face is in
	// fill light only. That difference is what gives the room its volume.
	right_face := scale_rgb(side, 0.82)
	left_face := scale_rgb(side, 0.58)

	if height > 0.001 {
		draw_quad(t_ne, t_se, g_se, g_ne, right_face)
		draw_quad(t_sw, t_se, g_se, g_sw, left_face)
	}
	draw_quad(t_nw, t_ne, t_se, t_sw, top)
}

// The floor is drawn as one big diamond with a subtle tile grid scratched into
// it, rather than thousands of quads.
draw_floor :: proc(g: ^Game) {
	s := &g.scene
	w := f32(s.nav.w)
	h := f32(s.nav.h)
	cam := g.camera

	nw := world_to_screen(cam, 0, 0, 0)
	ne := world_to_screen(cam, w, 0, 0)
	se := world_to_screen(cam, w, h, 0)
	sw := world_to_screen(cam, 0, h, 0)
	draw_quad(nw, ne, se, sw, COL_FLOOR)

	// Grid lines, barely there -- enough to sell the space, not enough to look
	// like a strategy game.
	grid := fade(rl.Color{92, 90, 84, 255}, 0.30)
	for i := 0; i <= s.nav.w; i += 1 {
		a := world_to_screen(cam, f32(i), 0, 0)
		b := world_to_screen(cam, f32(i), h, 0)
		rl.DrawLineEx(a, b, 1, grid)
	}
	for j := 0; j <= s.nav.h; j += 1 {
		a := world_to_screen(cam, 0, f32(j), 0)
		b := world_to_screen(cam, w, f32(j), 0)
		rl.DrawLineEx(a, b, 1, grid)
	}

	// Pooled light on the floor under each source.
	for l in s.lights {
		center := world_to_screen(cam, l.pos.x, l.pos.y, 0)
		steps := 7
		for k := steps; k >= 1; k -= 1 {
			t := f32(k) / f32(steps)
			rx := l.radius * TILE_HW * cam.zoom * t
			ry := l.radius * TILE_HH * cam.zoom * t
			alpha := (1.0 - t) * 0.14 * l.intensity
			rl.DrawEllipse(
				i32(center.x),
				i32(center.y),
				rx,
				ry,
				fade(l.color, alpha),
			)
		}
	}
}

// A soft contact shadow so props and people sit on the floor instead of
// floating above it.
draw_ground_shadow :: proc(cam: Iso_Camera, at: rl.Vector2, radius: f32, strength: f32) {
	c := world_to_screen(cam, at.x, at.y, 0)
	steps := 4
	for k := steps; k >= 1; k -= 1 {
		t := f32(k) / f32(steps)
		rl.DrawEllipse(
			i32(c.x),
			i32(c.y),
			radius * TILE_HW * cam.zoom * t,
			radius * TILE_HH * cam.zoom * t,
			fade(rl.Color{8, 10, 12, 255}, (1.0 - t) * strength),
		)
	}
}

// The detective: a stack of simple forms. Deliberately unheroic -- a coat, a
// head, and a walk that sways slightly too much.
draw_player :: proc(g: ^Game) {
	p := g.player_ent
	cam := g.camera

	sway := math.sin(p.bob) * 0.06
	lift := math.abs(math.sin(p.bob * 2)) * 0.045

	draw_ground_shadow(cam, p.pos, 0.42, 0.55)

	base := world_to_screen(cam, p.pos.x, p.pos.y, 0)
	z := cam.zoom

	coat_w := 26.0 * z
	coat_h := 44.0 * z
	head_r := 9.5 * z

	body_top := base.y - coat_h - lift * TILE_Z * z
	cx := base.x + sway * TILE_HW * z

	// Coat: a tapered quad, wider at the shoulders.
	shoulder_l := rl.Vector2{cx - coat_w * 0.5, body_top}
	shoulder_r := rl.Vector2{cx + coat_w * 0.5, body_top}
	hem_l := rl.Vector2{cx - coat_w * 0.36, base.y}
	hem_r := rl.Vector2{cx + coat_w * 0.36, base.y}

	coat := rl.Color{58, 62, 74, 255}
	draw_quad(shoulder_l, shoulder_r, hem_r, hem_l, coat)

	// Lit edge on the side facing the corridor door.
	rl.DrawLineEx(shoulder_r, hem_r, 2 * z, rl.Color{132, 128, 118, 255})

	// Head
	head_c := rl.Vector2{cx, body_top - head_r * 0.85}
	rl.DrawCircleV(head_c, head_r, rl.Color{176, 148, 122, 255})
	rl.DrawCircleV(
		{head_c.x + head_r * 0.28, head_c.y - head_r * 0.2},
		head_r * 0.72,
		rl.Color{198, 170, 140, 255},
	)
}

// Orbs pulse. Ones you have already exhausted go grey, so a room you have
// worked through looks worked through.
draw_orb :: proc(g: ^Game, idx: int) {
	it := g.scene.interactables[idx]
	cam := g.camera
	sp := world_to_screen(cam, it.pos.x, it.pos.y, it.height)

	pulse := 1.0 + math.sin(g.orb_phase * 2.2 + f32(idx) * 1.7) * 0.14
	hovered := g.hovered_interactable == idx

	base_col := it.seen ? COL_ORB_SEEN : COL_ORB
	r := (it.is_person ? 8.0 : 6.0) * cam.zoom * pulse
	if hovered {
		r *= 1.35
	}

	// Halo
	for k in 1 ..= 4 {
		t := f32(k) / 4.0
		rl.DrawCircleV(sp, r * (1 + t * 2.4), fade(base_col, 0.10 * (1 - t)))
	}
	rl.DrawCircleV(sp, r, fade(base_col, hovered ? 1.0 : 0.85))
	rl.DrawCircleV(sp, r * 0.45, fade(rl.WHITE, hovered ? 0.9 : 0.5))

	// A thin tether down to the thing it belongs to, so it is never ambiguous
	// what the orb is pointing at.
	ground := world_to_screen(cam, it.pos.x, it.pos.y, 0)
	rl.DrawLineEx(sp, ground, 1, fade(base_col, 0.22))
}

draw_orb_label :: proc(g: ^Game, idx: int) {
	it := g.scene.interactables[idx]
	sp := world_to_screen(g.camera, it.pos.x, it.pos.y, it.height)
	label := label_or_id(it)

	size := f32(17)
	m := measure(g.font, label, size)
	pad := f32(8)
	box := rl.Rectangle{sp.x - m.x*0.5 - pad, sp.y - 36, m.x + pad*2, m.y + pad}

	draw_panel(box, fade(COL_INK, 0.92), fade(COL_ORB, 0.5))
	draw_text(g.font, label, {box.x + pad, box.y + pad*0.45}, size, COL_PAPER)
}

// The click ripple, so ordering a walk feels acknowledged.
draw_click_marker :: proc(g: ^Game) {
	if g.click_marker_life <= 0 {
		return
	}
	t := 1.0 - (g.click_marker_life / 0.5)
	c := world_to_screen(g.camera, g.click_marker.x, g.click_marker.y, 0)
	r := 6 + t * 22
	rl.DrawEllipseLines(
		i32(c.x),
		i32(c.y),
		r * g.camera.zoom,
		r * 0.5 * g.camera.zoom,
		fade(COL_PAPER, (1 - t) * 0.6),
	)
}

// The remaining path, drawn faintly, so long walks are legible.
draw_path :: proc(g: ^Game) {
	p := g.player_ent
	if p.path == nil || p.path_idx >= len(p.path) {
		return
	}
	prev := world_to_screen(g.camera, p.pos.x, p.pos.y, 0)
	for i in p.path_idx ..< len(p.path) {
		pt := world_to_screen(g.camera, p.path[i].x, p.path[i].y, 0)
		rl.DrawLineEx(prev, pt, 1.5, fade(COL_PAPER, 0.16))
		prev = pt
	}
	rl.DrawCircleV(prev, 3 * g.camera.zoom, fade(COL_PAPER, 0.3))
}

render_world :: proc(g: ^Game) {
	rl.ClearBackground(rl.Color{16, 17, 19, 255})

	draw_floor(g)
	draw_path(g)
	draw_click_marker(g)

	// Build the draw list, sort once, paint.
	items := make([dynamic]Draw_Item, context.temp_allocator)

	for prop, i in g.scene.props {
		// Depth is measured at the far corner so tall things behind short ones
		// still resolve correctly.
		append(
			&items,
			Draw_Item {
				depth = depth_key(prop.pos.x + prop.size.x, prop.pos.y + prop.size.y, 0),
				kind = .Prop,
				index = i,
			},
		)
	}

	append(
		&items,
		Draw_Item{depth = depth_key(g.player_ent.pos.x, g.player_ent.pos.y, 0.5), kind = .Player, index = 0},
	)

	for it, i in g.scene.interactables {
		if !interactable_visible(g, it) {
			continue
		}
		// Orbs float, so they sort above whatever they are attached to.
		append(
			&items,
			Draw_Item{depth = depth_key(it.pos.x, it.pos.y, it.height + 4), kind = .Orb, index = i},
		)
	}

	slice.sort_by(items[:], proc(a, b: Draw_Item) -> bool {
		return a.depth < b.depth
	})

	for item in items {
		switch item.kind {
		case .Prop:
			p := g.scene.props[item.index]
			draw_ground_shadow(g.camera, p.pos + p.size*0.5, math.max(p.size.x, p.size.y)*0.62, 0.35)
			draw_box(g.camera, p.pos, p.size, p.height, p.top, p.side)
			if p.emissive > 0 {
				draw_emissive_face(g.camera, p)
			}
		case .Player:
			draw_player(g)
		case .Orb:
			draw_orb(g, item.index)
		}
	}

	// Labels last, so nothing paints over them.
	if g.hovered_interactable >= 0 {
		draw_orb_label(g, g.hovered_interactable)
	}
}

// A glowing panel on the front face of a monitor or rack. This is what the
// bloom in the painterly pass latches onto.
draw_emissive_face :: proc(cam: Iso_Camera, p: Prop) {
	inset := f32(0.12)
	x0 := p.pos.x + inset
	x1 := p.pos.x + p.size.x - inset
	y := p.pos.y + p.size.y
	z0 := p.height * 0.25
	z1 := p.height * 0.92

	a := world_to_screen(cam, x0, y, z1)
	b := world_to_screen(cam, x1, y, z1)
	c := world_to_screen(cam, x1, y, z0)
	d := world_to_screen(cam, x0, y, z0)

	glow := rl.Color{150, 226, 206, 255}
	draw_quad(a, b, c, d, fade(glow, 0.55 * p.emissive))
	// A brighter core keeps it above the bloom knee.
	inner_a := rl.Vector2{a.x + (b.x-a.x)*0.12, a.y + (d.y-a.y)*0.16}
	inner_b := rl.Vector2{b.x - (b.x-a.x)*0.12, b.y + (c.y-b.y)*0.16}
	inner_c := rl.Vector2{c.x - (c.x-d.x)*0.12, c.y - (c.y-b.y)*0.16}
	inner_d := rl.Vector2{d.x + (c.x-d.x)*0.12, d.y - (d.y-a.y)*0.16}
	draw_quad(inner_a, inner_b, inner_c, inner_d, fade(rl.Color{210, 250, 236, 255}, 0.85 * p.emissive))
}
