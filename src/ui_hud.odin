package game

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

// There is no HUD while you are walking around. The screen is the room. Numbers
// and panels only exist at the moment they have something to say, and then they
// get out of the way again.

TOAST_LIFE :: f32(3.4)
MARKER_FADE_RANGE :: f32(8.5)

Toast :: struct {
	text:  string,
	color: rl.Color,
	life:  f32,
}

toast_push :: proc(g: ^Game, text: string, color: rl.Color) {
	if g.headless {
		return
	}
	if g.toasts == nil {
		g.toasts = make([dynamic]Toast)
	}
	// Keep the stack short; the newest three are the only ones anyone reads.
	for len(g.toasts) >= 4 {
		delete(g.toasts[0].text)
		ordered_remove(&g.toasts, 0)
	}
	append(&g.toasts, Toast{text = strings.clone(text), color = color, life = TOAST_LIFE})
}

toasts_update :: proc(g: ^Game, dt: f32) {
	for i := len(g.toasts) - 1; i >= 0; i -= 1 {
		g.toasts[i].life -= dt
		if g.toasts[i].life <= 0 {
			delete(g.toasts[i].text)
			ordered_remove(&g.toasts, i)
		}
	}
	if g.vitals_reveal > 0 {
		g.vitals_reveal -= dt
	}
	if g.controls_hint > 0 {
		g.controls_hint -= dt
	}
}

// Health and morale are worth interrupting for, so a change to either puts the
// bars back on screen for a few seconds and then takes them away again.
vitals_reveal :: proc(g: ^Game) {
	g.vitals_reveal = 4.5
}

// ---------------------------------------------------------------------------
// The only thing drawn over the world
// ---------------------------------------------------------------------------

draw_world_overlay :: proc(g: ^Game) {
	if g.scene.built {
		draw_interaction_markers(g)
		draw_interaction_prompt(g)
	}
	draw_toasts(g)
	draw_transient_vitals(g)
	draw_controls_hint(g)

	if g.reload_notice > 0 {
		draw_reload_notice(g)
	}
	if g.damage_flash > 0 {
		draw_damage_flash(g)
	}
}

// A small mark over everything worth walking to. Far away it is barely a glint;
// up close it is unmistakable. It is never a wall of floating icons.
draw_interaction_markers :: proc(g: ^Game) {
	s := camera_scale(g.camera)

	for it, i in g.scene.interactables {
		if !interactable_visible(g, it) {
			continue
		}
		pos := interactable_pos(g, it)
		dist := rl.Vector2Distance(pos, g.player_ent.pos)
		if dist > MARKER_FADE_RANGE {
			continue
		}

		alpha := clamp(1.0 - (dist - INTERACT_RANGE) / (MARKER_FADE_RANGE - INTERACT_RANGE), 0.16, 1.0)
		nearest := g.hovered_interactable == i
		if nearest {
			alpha = 1.0
		}

		p := w2s(g, pos)
		float := math.sin(g.orb_phase * 2.0 + f32(i) * 1.3) * s * 0.04
		p.y -= s * (it.is_person ? 0.92 : 0.62) + float

		col := it.seen ? COL_ORB_SEEN : COL_ORB
		r := s * (nearest ? 0.115 : 0.085)
		if nearest {
			r *= 1.0 + 0.06 * math.sin(g.time * 4.0)
		}

		// A diamond, not a circle: it does not read as an object in the room.
		for k in 1 ..= 4 {
			t := f32(k) / 4.0
			rl.DrawPoly(p, 4, r * (1 + t * 1.9), 0, fade(col, 0.13 * (1 - t) * alpha))
		}
		// Rotation 0 is the diamond; 45 degrees turns a 4-gon back into an
		// axis-aligned square, which is indistinguishable from a UI element.
		rl.DrawPoly(p, 4, r, 0, fade(col, 0.92 * alpha))
		rl.DrawPoly(p, 4, r * 0.45, 0, fade(rl.WHITE, 0.80 * alpha))
	}
}

// The prompt only exists when you are actually standing next to something.
draw_interaction_prompt :: proc(g: ^Game) {
	idx := g.hovered_interactable
	if idx < 0 || idx >= len(g.scene.interactables) {
		return
	}
	it := g.scene.interactables[idx]
	s := camera_scale(g.camera)

	p := w2s(g, interactable_pos(g, it))
	p.y -= s * (it.is_person ? 1.30 : 1.00)

	label := label_or_id(it)
	key := "[E]"

	size := f32(18)
	km := measure(g.font_small, key, 15)
	lm := measure(g.font, label, size)
	pad := f32(11)
	gap := f32(9)

	w := km.x + gap + lm.x + pad * 2
	h := math.max(lm.y, km.y) + pad
	box := rl.Rectangle{p.x - w * 0.5, p.y - h, w, h}

	// A soft shadow behind the plate so it stays readable over a lit rack.
	rl.DrawRectangleRec({box.x + 2, box.y + 3, box.width, box.height}, fade(rl.BLACK, 0.35))
	draw_panel(box, fade(COL_INK, 0.93), fade(COL_ORB, 0.55))

	pulse := 0.75 + 0.25 * math.sin(g.time * 4.2)
	draw_text(g.font_small, key, {box.x + pad, box.y + pad * 0.42}, 15, fade(COL_ORB, pulse), 1.0)
	draw_text(g.font, label, {box.x + pad + km.x + gap, box.y + pad * 0.36}, size, COL_PAPER)

	// A stem down to the thing itself, so the plate is never ambiguous.
	rl.DrawLineEx({p.x, box.y + box.height}, {p.x, p.y + s * 0.10}, 1, fade(COL_ORB, 0.34))
}

draw_toasts :: proc(g: ^Game) {
	if len(g.toasts) == 0 {
		return
	}
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	y := sh - 96
	for i := len(g.toasts) - 1; i >= 0; i -= 1 {
		t := g.toasts[i]
		alpha := clamp(t.life / 0.6, 0, 1)
		// A short rise as it appears, so new lines are noticed without motion
		// anywhere near the middle of the screen.
		rise := (1.0 - clamp((TOAST_LIFE - t.life) / 0.25, 0, 1)) * 10

		m := measure(g.font_small, t.text, 16)
		x := sw * 0.5 - m.x * 0.5
		draw_panel(
			{x - 14, y + rise - 6, m.x + 28, m.y + 12},
			fade(COL_INK, 0.80 * alpha),
			fade(t.color, 0.55 * alpha),
		)
		draw_text(g.font_small, t.text, {x, y + rise}, 16, fade(t.color, alpha), 0.4)
		y -= m.y + 20
	}
}

// The bars are not on screen. They come back for a moment when they move.
draw_transient_vitals :: proc(g: ^Game) {
	if g.vitals_reveal <= 0 {
		return
	}
	alpha := clamp(g.vitals_reveal / 0.9, 0, 1)
	sw := f32(rl.GetScreenWidth())
	panel := rl.Rectangle{sw - 232, 22, 210, 74}

	draw_panel(panel, fade(COL_INK, 0.82 * alpha), fade(COL_PANEL_EDGE, 0.8 * alpha))
	draw_vital_row(g, {panel.x + 14, panel.y + 12}, panel.width - 28, "HEALTH", g.player.health, health_max(g.player), COL_HEALTH, alpha)
	draw_vital_row(g, {panel.x + 14, panel.y + 42}, panel.width - 28, "MORALE", g.player.morale, morale_max(g.player), COL_MORALE, alpha)
}

draw_vital_row :: proc(
	g: ^Game,
	pos: rl.Vector2,
	w: f32,
	label: string,
	value, maximum: int,
	col: rl.Color,
	alpha: f32,
) {
	draw_text(g.font_small, label, pos, 13, fade(col, 0.94 * alpha), 1.1)
	num := fmt.tprintf("%d/%d", value, maximum)
	nm := measure(g.font_small, num, 13)
	draw_text(g.font_small, num, {pos.x + w - nm.x, pos.y}, 13, fade(COL_PAPER, alpha), 0.4)

	bar_x := pos.x + 67
	bar_w := w - 112
	frac := maximum > 0 ? f32(value) / f32(maximum) : f32(0)
	rl.DrawRectangleRec({bar_x, pos.y + 5, bar_w, 5}, fade(COL_PANEL_EDGE, 0.7 * alpha))
	rl.DrawRectangleRec({bar_x, pos.y + 5, bar_w * clamp(frac, 0, 1), 5}, fade(col, alpha))
}

// Shown once when you stand up, then never again unless you ask for it.
draw_controls_hint :: proc(g: ^Game) {
	if g.controls_hint <= 0 {
		return
	}
	alpha := clamp(g.controls_hint / 1.6, 0, 1)
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	hint := "WASD  move        E  look at, or speak to        TAB  yourself"
	m := measure(g.font_small, hint, 15)
	draw_text(g.font_small, hint, {sw * 0.5 - m.x * 0.5, sh - 52}, 15, fade(COL_PAPER, 0.55 * alpha), 1.2)
}

// The minute hand crawls with progress, not with real time. It has been just
// past three since you woke up, and that is meant to feel wrong.
clock_text :: proc(g: ^Game) -> string {
	return fmt.tprintf("03:0%d", clamp(len(g.flags) / 4, 0, 9))
}

draw_reload_notice :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	alpha := clamp(g.reload_notice, 0, 1)

	ok := len(g.load_errors) == 0
	text := ok ? "content reloaded" : fmt.tprintf("content reloaded with %d error(s)", len(g.load_errors))
	col := ok ? COL_SYSTEM : COL_FAIL

	m := measure(g.font_small, text, 15)
	x := sw * 0.5 - m.x * 0.5
	draw_panel({x - 14, 34, m.x + 28, 30}, fade(COL_INK, 0.9 * alpha), fade(col, 0.7 * alpha))
	draw_text(g.font_small, text, {x, 41}, 15, fade(col, alpha))

	y := f32(70)
	for e, i in g.load_errors {
		if i >= 3 {
			break
		}
		em := measure(g.font_small, e, 13)
		draw_text(g.font_small, e, {sw * 0.5 - em.x * 0.5, y}, 13, fade(COL_FAIL, alpha * 0.9))
		y += 18
	}
}

// A red bloom around the frame edge when something took a piece out of you.
draw_damage_flash :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	a := clamp(g.damage_flash, 0, 1) * 0.5

	bands := 26
	for i in 0 ..< bands {
		t := f32(i) / f32(bands)
		rl.DrawRectangleLinesEx(
			{t * 22, t * 22, sw - t * 44, sh - t * 44},
			2,
			fade(COL_FAIL, a * (1 - t) * 0.5),
		)
	}
}
