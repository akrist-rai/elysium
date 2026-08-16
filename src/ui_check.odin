package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// The moment the whole game is built around. Everything feeding the roll is on
// screen before you commit: the skill, every modifier with its reason, the
// target, and the exact odds. Nothing is hidden and nothing is rounded in the
// game's favour.

POPUP_W :: 470.0

check_popup_rect :: proc(g: ^Game) -> rl.Rectangle {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	d := &g.dialogue
	rows := f32(len(d.pending.modifiers))

	// Measured against the draw order below: header block, one row per
	// modifier, the target/odds block, and the prompt, plus padding.
	h := 268 + rows * 24
	if d.pending.state != .Presenting {
		h += 186 // dice, verdict, arithmetic and the prompt beneath them
		if d.pending.state == .Revealed && d.pending.result.critical {
			h += 24 // the extra line a double six or snake eyes earns
		}
	}

	return {(sw - POPUP_W) * 0.5, (sh - h) * 0.5, POPUP_W, h}
}

draw_check_popup :: proc(g: ^Game) {
	d := &g.dialogue
	p := &d.pending

	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	rl.DrawRectangleRec({0, 0, sw, sh}, fade(rl.BLACK, 0.62))

	rect := check_popup_rect(g)
	accent := p.kind == .Red ? COL_RED_CHECK : COL_WHITE_CHECK

	draw_panel(rect, rl.Color{18, 19, 22, 250}, fade(accent, 0.8))
	// A thick bar along the top edge: red or white, visible at a glance.
	rl.DrawRectangleRec({rect.x, rect.y, rect.width, 3}, accent)

	pad := f32(24)
	x := rect.x + pad
	w := rect.width - pad * 2
	y := rect.y + pad

	kind_label := p.kind == .Red ? "RED CHECK - ONE ATTEMPT" : "WHITE CHECK"
	draw_text(g.font_small, kind_label, {x, y}, 14, accent, 1.6)
	y += 24

	draw_text(g.font_title, skill_info[p.skill].name, {x, y}, 27, skill_info[p.skill].color)
	y += 36

	draw_text(
		g.font_small,
		skill_info[p.skill].blurb,
		{x, y},
		15,
		fade(COL_NARRATION, 0.9),
	)
	y += 26

	draw_hline(x, y, w, fade(COL_PANEL_EDGE, 0.9))
	y += 14

	// --- the itemised breakdown ---------------------------------------------
	for m in p.modifiers {
		sign_col := m.value >= 0 ? COL_PASS : COL_FAIL
		value_text := fmt.tprintf("%+d", m.value)
		draw_text(g.font, m.label, {x, y}, 16, COL_OPTION)
		vm := measure(g.font, value_text, 16)
		draw_text(g.font, value_text, {x + w - vm.x, y}, 16, sign_col)
		y += 24
	}

	draw_hline(x, y + 2, w, fade(COL_PANEL_EDGE, 0.9))
	y += 14

	// --- target and odds -----------------------------------------------------
	diff := difficulty_for_target(p.target)
	target_text := fmt.tprintf("%s %d", difficulty_name[diff], p.target)
	draw_text(g.font, "Target", {x, y}, 17, COL_PAPER)
	tm := measure(g.font, target_text, 17)
	draw_text(g.font, target_text, {x + w - tm.x, y}, 17, COL_PAPER)
	y += 26

	odds_text := fmt.tprintf("%.1f%%", p.odds * 100)
	odds_col := odds_color(p.odds)
	draw_text(g.font, "Chance", {x, y}, 17, COL_PAPER)
	om := measure(g.font_title, odds_text, 21)
	draw_text(g.font_title, odds_text, {x + w - om.x, y - 3}, 21, odds_col)
	y += 30

	// Odds bar
	rl.DrawRectangleRec({x, y, w, 5}, rl.Color{40, 42, 46, 255})
	rl.DrawRectangleRec({x, y, w * p.odds, 5}, odds_col)
	y += 22

	switch p.state {
	case .Presenting:
		hint := "[enter] roll     [esc] step back"
		hm := measure(g.font_small, hint, 15)
		draw_text(g.font_small, hint, {rect.x + (rect.width - hm.x) * 0.5, y + 4}, 15, COL_LOCKED)
	case .Rolling, .Revealed:
		draw_dice_tray(g, rect, y)
	}
}

odds_color :: proc(odds: f32) -> rl.Color {
	if odds >= 0.72 {
		return COL_PASS
	}
	if odds >= 0.42 {
		return rl.Color{214, 186, 92, 255}
	}
	return COL_FAIL
}

draw_dice_tray :: proc(g: ^Game, rect: rl.Rectangle, y: f32) {
	p := &g.dialogue.pending

	die_size := f32(56)
	gap := f32(18)
	total_w := die_size * 2 + gap
	dx := rect.x + (rect.width - total_w) * 0.5

	settled := p.state == .Revealed

	// While rolling the dice jitter; once settled they snap square.
	jitter_a := settled ? 0 : math.sin(p.timer * 41) * 3
	jitter_b := settled ? 0 : math.cos(p.timer * 37) * 3

	draw_die(g, {dx, y + jitter_a}, die_size, p.shown_a, settled)
	draw_die(g, {dx + die_size + gap, y + jitter_b}, die_size, p.shown_b, settled)

	if !settled {
		return
	}

	res := p.result
	oy := y + die_size + 18

	verdict := res.passed ? "SUCCESS" : "FAILURE"
	vcol := res.passed ? COL_PASS : COL_FAIL
	vm := measure(g.font_title, verdict, 26)
	draw_text(g.font_title, verdict, {rect.x + (rect.width - vm.x) * 0.5, oy}, 26, vcol)
	oy += 34

	sum := fmt.tprintf(
		"%d + %d  =  %d   vs   %d",
		res.die_a + res.die_b,
		res.bonus,
		roll_total(res),
		res.target,
	)
	sm := measure(g.font, sum, 17)
	draw_text(g.font, sum, {rect.x + (rect.width - sm.x) * 0.5, oy}, 17, COL_OPTION)
	oy += 26

	if res.critical {
		crit := res.passed ? "Double six. The dice decided for you." : "Snake eyes. Nothing could have saved that."
		cm := measure(g.font_small, crit, 15)
		draw_text(
			g.font_small,
			crit,
			{rect.x + (rect.width - cm.x) * 0.5, oy},
			15,
			fade(vcol, 0.85),
		)
		oy += 22
	}

	hint := "[enter] live with it"
	hm := measure(g.font_small, hint, 15)
	draw_text(g.font_small, hint, {rect.x + (rect.width - hm.x) * 0.5, oy + 2}, 15, COL_LOCKED)
}

// Pips, drawn properly, because a die that shows a number instead of pips does
// not feel like a die.
draw_die :: proc(g: ^Game, pos: rl.Vector2, size: f32, value: int, settled: bool) {
	face := settled ? rl.Color{226, 220, 204, 255} : rl.Color{176, 172, 160, 255}
	rl.DrawRectangleRounded({pos.x, pos.y, size, size}, 0.16, 6, face)
	rl.DrawRectangleRoundedLines(
		{pos.x, pos.y, size, size},
		0.16,
		6,
		rl.Color{60, 58, 52, 255},
	)

	pip_r := size * 0.082
	pip_col := rl.Color{28, 28, 30, 255}

	// Pip positions on a 3x3 lattice inside the face.
	lo := size * 0.26
	mid := size * 0.5
	hi := size * 0.74

	pip :: proc(pos: rl.Vector2, x, y, r: f32, col: rl.Color) {
		rl.DrawCircleV({pos.x + x, pos.y + y}, r, col)
	}

	v := clamp(value, 1, 6)
	if v % 2 == 1 {
		pip(pos, mid, mid, pip_r, pip_col)
	}
	if v >= 2 {
		pip(pos, lo, lo, pip_r, pip_col)
		pip(pos, hi, hi, pip_r, pip_col)
	}
	if v >= 4 {
		pip(pos, hi, lo, pip_r, pip_col)
		pip(pos, lo, hi, pip_r, pip_col)
	}
	if v == 6 {
		pip(pos, lo, mid, pip_r, pip_col)
		pip(pos, hi, mid, pip_r, pip_col)
	}
}

check_popup_input :: proc(g: ^Game) {
	d := &g.dialogue
	switch d.pending.state {
	case .Presenting:
		if rl.IsKeyPressed(.ENTER) || rl.IsMouseButtonPressed(.LEFT) {
			dialogue_commit_check(g)
		} else if rl.IsKeyPressed(.ESCAPE) {
			// Backing out is allowed right up until the dice leave your hand.
			d.pending.active = false
			dialogue_rebuild_options(g)
		}
	case .Rolling:
	// no input while the dice are in the air
	case .Revealed:
		if rl.IsKeyPressed(.ENTER) ||
		   rl.IsKeyPressed(.SPACE) ||
		   rl.IsMouseButtonPressed(.LEFT) {
			dialogue_finish_check(g)
		}
	}
}
