package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// The world HUD reads like a field note pinned over the painting: enough
// information to play, but never enough chrome to compete with the room.

ORB_R :: 30.0

draw_hud :: proc(g: ^Game) {
	draw_case_header(g)
	draw_compact_vitals(g)
	draw_hints(g)

	if g.reload_notice > 0 {
		draw_reload_notice(g)
	}

	if g.damage_flash > 0 {
		draw_damage_flash(g)
	}
}

draw_case_header :: proc(g: ^Game) {
	panel := rl.Rectangle{20, 18, 330, 82}
	draw_panel(panel, fade(COL_INK, 0.86), fade(COL_KEY, 0.44))
	draw_text(g.font_small, "CASE 01  //  TECHHUNT NIGHT", {panel.x + 16, panel.y + 13}, 13, fade(COL_KEY, 0.90), 1.6)
	draw_text(g.font_title, "THE LOCKED SCOREBOARD", {panel.x + 16, panel.y + 32}, 20, COL_PAPER, 1.0)
	draw_text(g.font_small, "SERVER ROOM B", {panel.x + 16, panel.y + 60}, 13, fade(COL_NARRATION, 0.86), 1.2)
	clock := clock_text(g)
	cm := measure(g.font_title, clock, 20)
	draw_text(g.font_title, clock, {panel.x + panel.width - cm.x - 14, panel.y + 52}, 20, COL_KEY, 0.8)
}

draw_compact_vitals :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	panel := rl.Rectangle{sw - 236, 18, 216, 82}
	draw_panel(panel, fade(COL_INK, 0.86), fade(COL_PANEL_EDGE, 0.9))
	draw_vital_row(g, {panel.x + 14, panel.y + 13}, panel.width - 28, "HEALTH", g.player.health, health_max(g.player), COL_HEALTH)
	draw_vital_row(g, {panel.x + 14, panel.y + 45}, panel.width - 28, "MORALE", g.player.morale, morale_max(g.player), COL_MORALE)
}

draw_vital_row :: proc(g: ^Game, pos: rl.Vector2, w: f32, label: string, value, maximum: int, col: rl.Color) {
	draw_text(g.font_small, label, pos, 13, fade(col, 0.94), 1.1)
	num := fmt.tprintf("%d/%d", value, maximum)
	nm := measure(g.font_small, num, 13)
	draw_text(g.font_small, num, {pos.x + w - nm.x, pos.y}, 13, COL_PAPER, 0.4)
	bar_x := pos.x + 67
	bar_w := w - 112
	frac := maximum > 0 ? f32(value) / f32(maximum) : f32(0)
	rl.DrawRectangleRec({bar_x, pos.y + 5, bar_w, 5}, fade(COL_PANEL_EDGE, 0.7))
	rl.DrawRectangleRec({bar_x, pos.y + 5, bar_w * clamp(frac, 0, 1), 5}, col)
}

draw_stat_orb :: proc(
	g: ^Game,
	center: rl.Vector2,
	value, maximum: int,
	color: rl.Color,
	label: string,
) {
	// Well
	rl.DrawCircleV(center, ORB_R, rl.Color{20, 21, 24, 240})

	if maximum > 0 && value > 0 {
		fill := f32(value) / f32(maximum)
		// The orb fills from the bottom, like liquid.
		steps := 26
		for i in 0 ..< steps {
			t := f32(i) / f32(steps)
			if t > fill {
				break
			}
			y := center.y + ORB_R - t * ORB_R * 2
			half := math.sqrt(math.max(f32(0), ORB_R * ORB_R - (y - center.y) * (y - center.y)))
			rl.DrawRectangleRec(
				{center.x - half, y - (ORB_R * 2 / f32(steps)) - 1, half * 2, ORB_R * 2 / f32(steps) + 2},
				fade(color, 0.80),
			)
		}
	}

	rl.DrawCircleLinesV(center, ORB_R, fade(color, 0.75))
	rl.DrawCircleLinesV(center, ORB_R - 3, fade(color, 0.22))

	num := fmt.tprintf("%d", value)
	nm := measure(g.font_title, num, 26)
	draw_text(
		g.font_title,
		num,
		{center.x - nm.x * 0.5, center.y - nm.y * 0.5},
		26,
		value <= 1 ? color : COL_PAPER,
	)

	lm := measure(g.font_small, label, 12)
	draw_text(
		g.font_small,
		label,
		{center.x - lm.x * 0.5, center.y + ORB_R + 7},
		12,
		fade(color, 0.85),
		1.4,
	)
}

draw_level_readout :: proc(g: ^Game, center: rl.Vector2) {
	lvl := fmt.tprintf("%d", g.player.level)
	lm := measure(g.font_title, lvl, 26)
	draw_text(g.font_title, lvl, {center.x - lm.x * 0.5, center.y - lm.y * 0.5}, 26, COL_PAPER)

	label := "LEVEL"
	if g.pending_level_ups > 0 {
		label = "SPEND [C]"
	}
	col := g.pending_level_ups > 0 ? COL_SYSTEM : fade(COL_PAPER, 0.6)
	lbm := measure(g.font_small, label, 12)
	draw_text(g.font_small, label, {center.x - lbm.x * 0.5, center.y + ORB_R + 7}, 12, col, 1.4)

	// XP arc under the number.
	frac := f32(g.player.xp) / f32(XP_PER_LEVEL)
	rl.DrawRectangleRec({center.x - 26, center.y + 20, 52, 3}, rl.Color{40, 42, 46, 255})
	rl.DrawRectangleRec({center.x - 26, center.y + 20, 52 * frac, 3}, fade(COL_SYSTEM, 0.9))

	if g.pending_level_ups > 0 {
		pulse := 0.5 + 0.5 * math.sin(g.time * 4)
		rl.DrawCircleLinesV(center, ORB_R + 4, fade(COL_SYSTEM, 0.3 + pulse * 0.5))
	}
}

draw_top_bar :: proc(g: ^Game) {
	// Location and the clock. The clock does not move -- it has been 03:0X since
	// you woke up, and that is the first thing that should feel wrong.
	draw_text(g.font_small, "SERVER ROOM B - TECHHUNT NIGHT", {26, 24}, 15, fade(COL_PAPER, 0.72), 1.8)
	draw_text(g.font_small, clock_text(g), {26, 46}, 15, fade(COL_NARRATION, 0.7), 1.8)

	if journal_active_count(&g.journal) > 0 {
		text := fmt.tprintf("%d open lead(s)  [J]", journal_active_count(&g.journal))
		draw_text(g.font_small, text, {26, 68}, 14, fade(COL_SYSTEM, 0.8), 1.2)
	}
}

// The minute hand crawls with progress, not with real time. It has been just
// past three since you woke up, and that is meant to feel wrong.
clock_text :: proc(g: ^Game) -> string {
	return fmt.tprintf("03:0%d", clamp(len(g.flags) / 4, 0, 9))
}

draw_hints :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	if g.dialogue.active {
		return
	}

	hint := "[C] skill voices    [T] thoughts    [J] casebook    [I] pockets"
	m := measure(g.font_small, hint, 14)
	draw_panel({sw - m.x - 36, sh - 44, m.x + 20, 28}, fade(COL_INK, 0.78), fade(COL_PANEL_EDGE, 0.64))
	draw_text(g.font_small, hint, {sw - m.x - 26, sh - 36}, 14, fade(COL_PAPER, 0.74), 0.6)
}

draw_reload_notice :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	alpha := clamp(g.reload_notice, 0, 1)

	ok := len(g.load_errors) == 0
	text := ok ? "content reloaded" : fmt.tprintf("content reloaded with %d error(s)", len(g.load_errors))
	col := ok ? COL_SYSTEM : COL_FAIL

	m := measure(g.font_small, text, 15)
	x := sw * 0.5 - m.x * 0.5
	draw_panel({x - 14, 84, m.x + 28, 30}, fade(COL_INK, 0.9 * alpha), fade(col, 0.7 * alpha))
	draw_text(g.font_small, text, {x, 91}, 15, fade(col, alpha))

	// Show the first couple of failures inline; the rest go to stderr.
	y := f32(120)
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
