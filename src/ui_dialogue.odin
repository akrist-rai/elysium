package game

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

// The dialogue panel sits on the right and leaves the room visible on the left,
// because the room is still talking to you while people are.
DIALOGUE_PANEL_FRACTION :: f32(0.46)
DIALOGUE_PAD :: f32(26.0)
LOG_FONT :: f32(18.0)
LOG_LINE :: f32(25.0)
OPT_FONT :: f32(18.0)
OPT_LINE :: f32(24.0)

dialogue_panel_rect :: proc() -> rl.Rectangle {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	w := sw * DIALOGUE_PANEL_FRACTION
	return {sw - w, 0, w, sh}
}

// Height of one log entry, including its speaker line.
log_entry_height :: proc(g: ^Game, e: Log_Entry, width: f32) -> f32 {
	h := f32(0)
	if e.speaker != "" {
		h += 22
	}
	size := e.kind == .System ? LOG_FONT - 2 : LOG_FONT
	h += wrapped_height(g.font, e.text, size, width, LOG_LINE)
	return h + 12
}

draw_dialogue :: proc(g: ^Game) {
	d := &g.dialogue
	if !d.active {
		return
	}

	panel := dialogue_panel_rect()
	rl.DrawRectangleRec(panel, rl.Color{14, 15, 17, 244})
	rl.DrawRectangleRec({panel.x, 0, 1, panel.height}, COL_PANEL_EDGE)

	inner_x := panel.x + DIALOGUE_PAD
	inner_w := panel.width - DIALOGUE_PAD * 2

	// Options are measured first so the log knows how much room it has left.
	opt_h := dialogue_options_height(g, inner_w)
	log_bottom := panel.height - opt_h - DIALOGUE_PAD
	log_top := DIALOGUE_PAD

	rl.BeginScissorMode(
		i32(panel.x),
		i32(log_top),
		i32(panel.width),
		i32(log_bottom - log_top),
	)
	draw_dialogue_log(g, inner_x, inner_w, log_top, log_bottom)
	rl.EndScissorMode()

	if opt_h > 0 {
		draw_hline(inner_x, log_bottom + 8, inner_w, fade(COL_PANEL_EDGE, 0.7))
		draw_dialogue_options(g, inner_x, inner_w, log_bottom + DIALOGUE_PAD)
	}

	// The check popup covers everything when it is up.
	if d.pending.active {
		draw_check_popup(g)
	}
}

draw_dialogue_log :: proc(g: ^Game, x, w, top, bottom: f32) {
	d := &g.dialogue

	total := f32(0)
	for e in d.log {
		total += log_entry_height(g, e, w)
	}

	// Always bottom-anchored, so the newest line sits just above the options
	// and the eye never has to travel the height of the panel.
	view_h := bottom - top
	y := bottom - total
	if total > view_h {
		y += d.scroll
		// Do not let scrolling run past either end.
		y = math.min(y, top)
		y = math.max(y, bottom - total)
	} else {
		y = math.max(y, top)
	}

	revealed := int(d.revealed)
	consumed_before_batch := 0

	for e, i in d.log {
		h := log_entry_height(g, e, w)

		// Entries older than the current batch are always fully drawn.
		reveal_for_entry := -1
		if i >= d.batch_start {
			remaining := revealed - consumed_before_batch
			if remaining <= 0 {
				break
			}
			reveal_for_entry = remaining
			consumed_before_batch += len(e.text)
		}

		if y + h >= top - 40 && y <= bottom + 40 {
			draw_log_entry(g, e, {x, y}, w, reveal_for_entry)
		}
		y += h
	}
}

draw_log_entry :: proc(g: ^Game, e: Log_Entry, pos: rl.Vector2, w: f32, reveal: int) {
	y := pos.y

	if e.speaker != "" {
		label := e.speaker
		if e.kind == .Voice {
			label = strings.to_upper(e.speaker, context.temp_allocator)
		}
		draw_text(g.font_small, label, {pos.x, y}, 15, e.color, 1.2)
		y += 22
	}

	size := e.kind == .System ? LOG_FONT - 2 : LOG_FONT
	color := e.color
	switch e.kind {
	case .Voice:
		// The voice's own colour names it; the words themselves sit calmer.
		color = mix(e.color, COL_PAPER, 0.45)
	case .Speech:
		color = COL_SPEECH
	case .Narration:
		color = COL_NARRATION
	case .Player:
		color = COL_PLAYER
	case .Check_Outcome, .System:
	// keep the colour they were given
	}

	// A coloured rule down the left of a skill's line, so the chorus is
	// scannable at a glance.
	if e.kind == .Voice || e.kind == .Check_Outcome {
		h := wrapped_height(g.font, e.text, size, w - 14, LOG_LINE)
		rl.DrawRectangleRec({pos.x - 10, y + 3, 2, h - 6}, fade(e.color, 0.65))
		draw_wrapped(g.font, e.text, {pos.x + 4, y}, size, w - 14, LOG_LINE, color, reveal)
	} else {
		draw_wrapped(g.font, e.text, {pos.x, y}, size, w, LOG_LINE, color, reveal)
	}
}

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

option_height :: proc(g: ^Game, ro: Resolved_Option, w: f32) -> f32 {
	text_w := w - 34
	h := wrapped_height(g.font, ro.text, OPT_FONT, text_w, OPT_LINE)
	if ro.prefix != "" {
		h += 20
	}
	return h + 14
}

dialogue_options_height :: proc(g: ^Game, w: f32) -> f32 {
	d := &g.dialogue
	if !dialogue_fully_revealed(d) {
		// While text is still typing out, reserve room for the prompt only.
		return 46
	}
	if len(d.options) == 0 {
		return 46
	}
	total := f32(DIALOGUE_PAD)
	for ro in d.options {
		total += option_height(g, ro, w)
	}
	return total + 10
}

draw_dialogue_options :: proc(g: ^Game, x, w, top: f32) {
	d := &g.dialogue

	if !dialogue_fully_revealed(d) {
		draw_text(
			g.font_small,
			"[space] skip",
			{x, top},
			15,
			fade(COL_LOCKED, 0.9),
			1.0,
		)
		return
	}

	if len(d.options) == 0 {
		msg := d.pending_end ? "..." : "[space] continue"
		draw_text(g.font_small, msg, {x, top}, 15, fade(COL_LOCKED, 0.9), 1.0)
		return
	}

	mouse := rl.GetMousePosition()
	d.hovered = -1

	y := top
	for ro, i in d.options {
		h := option_height(g, ro, w)
		hit := rl.Rectangle{x - 10, y - 4, w + 20, h}
		hovered := rl.CheckCollisionPointRec(mouse, hit) && !ro.locked
		if hovered {
			d.hovered = i
		}

		draw_option(g, ro, i, {x, y}, w, hovered)
		y += h
	}
}

draw_option :: proc(g: ^Game, ro: Resolved_Option, idx: int, pos: rl.Vector2, w: f32, hovered: bool) {
	y := pos.y

	if hovered {
		h := option_height(g, ro, w)
		rl.DrawRectangleRec({pos.x - 12, y - 4, w + 22, h - 6}, fade(ro.color, 0.10))
		rl.DrawRectangleRec({pos.x - 12, y - 4, 2, h - 6}, fade(ro.color, 0.9))
	}

	num_col := ro.locked ? COL_LOCKED : fade(COL_PAPER, 0.55)
	draw_text(g.font_small, fmt.tprintf("%d", idx + 1), {pos.x, y + 2}, 15, num_col, 1.0)

	text_x := pos.x + 24
	text_w := w - 34

	if ro.prefix != "" {
		prefix_col := ro.locked ? COL_LOCKED : ro.color
		prefix := ro.prefix
		if ro.is_check {
			// The odds are the most important number on the screen.
			prefix = fmt.tprintf("%s  %.0f%%", ro.prefix, ro.odds * 100)
		}
		draw_text(g.font_small, prefix, {text_x, y}, 15, prefix_col, 0.6)

		// Red checks get a bar in front of them so you always know which of
		// the two kinds you are about to spend.
		if ro.is_check {
			mark_col := ro.is_red ? COL_RED_CHECK : COL_WHITE_CHECK
			rl.DrawRectangleRec({text_x - 12, y + 3, 4, 12}, fade(mark_col, ro.locked ? 0.35 : 1.0))
		}
		y += 20
	}

	body_col := COL_OPTION
	if ro.locked {
		body_col = COL_LOCKED
	} else if hovered {
		body_col = COL_PAPER
	}

	draw_wrapped(g.font, ro.text, {text_x, y}, OPT_FONT, text_w, OPT_LINE, body_col)

	if ro.locked && ro.lock_note != "" {
		note_y := y + wrapped_height(g.font, ro.text, OPT_FONT, text_w, OPT_LINE)
		draw_text(g.font_small, ro.lock_note, {text_x, note_y - 2}, 14, fade(COL_LOCKED, 0.85), 0.5)
	}
}

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------

dialogue_handle_input :: proc(g: ^Game) {
	d := &g.dialogue
	if !d.active {
		return
	}

	if d.pending.active {
		check_popup_input(g)
		return
	}

	// Typing out: any acknowledgement skips to the end of the reveal.
	if !dialogue_fully_revealed(d) {
		if rl.IsKeyPressed(.SPACE) ||
		   rl.IsKeyPressed(.ENTER) ||
		   rl.IsMouseButtonPressed(.LEFT) {
			dialogue_skip_reveal(d)
		}
		return
	}

	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		d.scroll += wheel * 42
	}

	if len(d.options) == 0 {
		if rl.IsKeyPressed(.SPACE) ||
		   rl.IsKeyPressed(.ENTER) ||
		   rl.IsMouseButtonPressed(.LEFT) {
			node, ok := d.script.nodes[d.node_id]
			if ok && node.goto_node != "" {
				dialogue_advance_to(g, node.goto_node)
			} else {
				dialogue_close(g)
			}
		}
		return
	}

	// Number keys pick options directly, which is how anyone plays these after
	// the first hour.
	for i in 0 ..< min(len(d.options), 9) {
		key := rl.KeyboardKey(int(rl.KeyboardKey.ONE) + i)
		if rl.IsKeyPressed(key) {
			dialogue_select(g, i)
			return
		}
	}

	if rl.IsMouseButtonPressed(.LEFT) && d.hovered >= 0 {
		dialogue_select(g, d.hovered)
	}
}
