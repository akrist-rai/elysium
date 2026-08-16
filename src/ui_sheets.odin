package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// One overlay, four tabs: who you are, what you have decided to believe, what
// you are chasing, and what is in your pockets.

sheet_rect :: proc() -> rl.Rectangle {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	w := math.min(f32(1380), sw - 84)
	h := math.min(f32(810), sh - 72)
	return {(sw - w) * 0.5, (sh - h) * 0.5, w, h}
}

draw_sheet :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	rl.DrawRectangleRec({0, 0, sw, sh}, fade(COL_INK, 0.78))

	rect := sheet_rect()
	draw_panel(rect, rl.Color{17, 18, 21, 252}, fade(COL_KEY, 0.52))
	rl.DrawRectangleRec({rect.x, rect.y, 5, rect.height}, fade(COL_KEY, 0.86))

	pad := f32(32)
	x := rect.x + pad
	y := rect.y + pad
	w := rect.width - pad * 2

	draw_text(g.font_small, "PERSONAL CASE FILE", {x, y}, 13, fade(COL_KEY, 0.90), 1.7)
	draw_text(g.font_title, sheet_title(g.sheet_tab), {x, y + 20}, 28, COL_PAPER, 0.9)
	draw_sheet_tabs(g, x + 330, y + 17, w - 330)
	y += 62
	draw_hline(x, y, w, fade(COL_PANEL_EDGE, 0.9))
	y += 22

	body := rl.Rectangle{x, y, w, rect.y + rect.height - pad - y}
	rl.BeginScissorMode(i32(body.x), i32(body.y), i32(body.width), i32(body.height))
	switch g.sheet_tab {
	case .Skills:
		draw_skills_tab(g, body)
	case .Thoughts:
		draw_thoughts_tab(g, body)
	case .Journal:
		draw_journal_tab(g, body)
	case .Inventory:
		draw_inventory_tab(g, body)
	}
	rl.EndScissorMode()

	hint := "[tab] next dossier    [esc] return to room"
	m := measure(g.font_small, hint, 14)
	draw_text(
		g.font_small,
		hint,
		{rect.x + rect.width - pad - m.x, rect.y + rect.height - 26},
		14,
		COL_LOCKED,
	)
}

sheet_title :: proc(tab: Sheet_Tab) -> string {
	switch tab {
	case .Skills: return "THE INNER CHORUS"
	case .Thoughts: return "THOUGHT CABINET"
	case .Journal: return "ACTIVE CASEWORK"
	case .Inventory: return "POCKETS & EVIDENCE"
	}
	return "CASE FILE"
}

draw_sheet_tabs :: proc(g: ^Game, x, y, w: f32) {
	names := [Sheet_Tab]string {
		.Skills    = "SKILLS",
		.Thoughts  = "THOUGHT CABINET",
		.Journal   = "JOURNAL",
		.Inventory = "POCKETS",
	}

	tx := x
	for name, tab in names {
		active := g.sheet_tab == tab
		m := measure(g.font_small, name, 15)
		col := active ? COL_PAPER : COL_LOCKED

		mouse := rl.GetMousePosition()
		hit := rl.Rectangle{tx - 8, y - 6, m.x + 16, 30}
		if rl.CheckCollisionPointRec(mouse, hit) {
			col = COL_PAPER
			if rl.IsMouseButtonPressed(.LEFT) {
				g.sheet_tab = tab
				g.sheet_scroll = 0
			}
		}

		draw_text(g.font_small, name, {tx, y}, 15, col, 1.8)
		if active {
			rl.DrawRectangleRec({tx - 4, y + 22, m.x + 8, 2}, COL_KEY)
		}
		tx += m.x + 40
	}

	if g.pending_level_ups > 0 && g.sheet_tab == .Skills {
		text := fmt.tprintf("%d point(s) to spend - click a skill", g.pending_level_ups)
		m := measure(g.font_small, text, 15)
		draw_text(g.font_small, text, {x + w - m.x, y}, 15, COL_SYSTEM, 0.8)
	}
}

// ---------------------------------------------------------------------------

draw_skills_tab :: proc(g: ^Game, body: rl.Rectangle) {
	col_w := body.width / 4 - 18
	mouse := rl.GetMousePosition()

	for attr in Attribute {
		cx := body.x + f32(int(attr)) * (col_w + 24)
		y := body.y + g.sheet_scroll

		acol := attribute_color[attr]
		draw_text(g.font_title, attribute_name[attr], {cx, y}, 17, acol, 1.4)
		y += 24

		value := fmt.tprintf("%d", g.player.attributes[attr])
		draw_text(g.font_title, value, {cx, y}, 30, acol)
		y += 44

		rl.DrawRectangleRec({cx, y - 12, col_w, 1}, fade(acol, 0.35))

		for info, skill in skill_info {
			if info.attribute != attr {
				continue
			}
			row := rl.Rectangle{cx - 6, y - 4, col_w + 12, 30}
			hovered := rl.CheckCollisionPointRec(mouse, row)
			spendable := g.pending_level_ups > 0

			if hovered {
				rl.DrawRectangleRec(row, fade(info.color, spendable ? 0.16 : 0.08))
				if spendable && rl.IsMouseButtonPressed(.LEFT) {
					game_spend_point(g, skill)
				}
			}

			total := skill_effective(g, skill)
			base := skill_base(g.player, skill)

			draw_text(g.font, info.name, {cx, y}, 16, hovered ? COL_PAPER : COL_OPTION)

			num := fmt.tprintf("%d", total)
			nm := measure(g.font_title, num, 19)
			// Show modified values in the skill's own colour so buffs and
			// penalties are visible without opening anything.
			ncol := total == base ? COL_PAPER : (total > base ? COL_PASS : COL_FAIL)
			draw_text(g.font_title, num, {cx + col_w - nm.x, y - 2}, 19, ncol)

			y += 30
		}

		// Hovering a skill shows what that voice wants.
		y += 6
	}

	// Blurb for whichever skill the cursor is over, along the bottom.
	for info, skill in skill_info {
		attr := info.attribute
		cx := body.x + f32(int(attr)) * (col_w + 24)
		idx := skill_index_within_attribute(skill)
		y := body.y + g.sheet_scroll + 68 + 12 + f32(idx) * 30
		row := rl.Rectangle{cx - 6, y - 4, col_w + 12, 30}
		if rl.CheckCollisionPointRec(rl.GetMousePosition(), row) {
			draw_text(
				g.font,
				info.blurb,
				{body.x, body.y + body.height - 30},
				17,
				fade(info.color, 0.95),
			)
			break
		}
	}
}

skill_index_within_attribute :: proc(s: Skill) -> int {
	idx := 0
	for info, other in skill_info {
		if info.attribute != skill_info[s].attribute {
			continue
		}
		if other == s {
			return idx
		}
		idx += 1
	}
	return 0
}

// ---------------------------------------------------------------------------

draw_thoughts_tab :: proc(g: ^Game, body: rl.Rectangle) {
	y := body.y + g.sheet_scroll
	card_w := body.width * 0.5 - 16

	header := fmt.tprintf(
		"%d of %d slots in use",
		cabinet_used_slots(&g.cabinet),
		g.cabinet.slots,
	)
	draw_text(g.font_small, header, {body.x, y}, 15, fade(COL_PAPER, 0.65), 1.2)
	y += 30

	any := false
	col := 0
	row_y := y
	tallest := f32(0)

	for &t in g.cabinet.thoughts {
		if t.state == .Unknown {
			continue
		}
		any = true

		cx := body.x + f32(col) * (card_w + 32)
		h := draw_thought_card(g, &t, {cx, row_y}, card_w)
		tallest = math.max(tallest, h)

		col += 1
		if col >= 2 {
			col = 0
			row_y += tallest + 20
			tallest = 0
		}
	}

	if !any {
		draw_text(
			g.font,
			"Nothing yet. Thoughts arrive when something refuses to leave you alone.",
			{body.x, y + 10},
			17,
			COL_NARRATION,
		)
	}
}

draw_thought_card :: proc(g: ^Game, t: ^Thought, pos: rl.Vector2, w: f32) -> f32 {
	researching := t.state == .Researching
	accent := researching ? rl.Color{188, 158, 96, 255} : COL_SYSTEM

	body_text := researching ? t.premise : t.conclusion
	text_h := wrapped_height(g.font, body_text, 16, w - 28, 22)

	mods := researching ? t.research_modifiers : t.bonus_modifiers
	h := 44 + text_h + 16 + f32(len(mods)) * 20 + (researching ? 24 : 0)

	rect := rl.Rectangle{pos.x, pos.y, w, h}
	draw_panel(rect, rl.Color{22, 23, 26, 240}, fade(accent, 0.55))
	rl.DrawRectangleRec({rect.x, rect.y, 3, rect.height}, accent)

	x := pos.x + 16
	y := pos.y + 14
	draw_text(g.font_title, t.name, {x, y}, 19, accent)
	y += 26

	draw_wrapped(g.font, body_text, {x, y}, 16, w - 28, 22, COL_OPTION)
	y += text_h + 8

	for m in mods {
		text := fmt.tprintf("%+d %s", m.value, skill_info[m.skill].name)
		draw_text(g.font_small, text, {x, y}, 14, m.value >= 0 ? COL_PASS : COL_FAIL, 0.6)
		y += 20
	}

	if researching {
		frac := f32(t.beats_done) / f32(math.max(1, t.beats_required))
		rl.DrawRectangleRec({x, y + 4, w - 32, 4}, rl.Color{40, 42, 46, 255})
		rl.DrawRectangleRec({x, y + 4, (w - 32) * clamp(frac, 0, 1), 4}, accent)
	}

	return h
}

// ---------------------------------------------------------------------------

draw_journal_tab :: proc(g: ^Game, body: rl.Rectangle) {
	y := body.y + g.sheet_scroll

	if len(g.journal.tasks) == 0 {
		draw_text(
			g.font,
			"No leads. You do not yet know what you are supposed to be doing here.",
			{body.x, y + 10},
			17,
			COL_NARRATION,
		)
		return
	}

	for &t in g.journal.tasks {
		mark := "-"
		col := COL_PAPER
		switch t.state {
		case .Active:
			mark = "*"
		case .Completed:
			mark = "x"
			col = COL_SYSTEM
		case .Failed:
			mark = "!"
			col = COL_FAIL
		}

		draw_text(g.font_title, mark, {body.x, y}, 18, col)
		draw_text(g.font_title, t.title, {body.x + 26, y}, 18, col)
		y += 26

		if t.detail != "" {
			h := draw_wrapped(
				g.font,
				t.detail,
				{body.x + 26, y},
				16,
				body.width - 60,
				22,
				t.state == .Active ? COL_NARRATION : fade(COL_NARRATION, 0.6),
			)
			y += h
		}
		y += 18
	}
}

// ---------------------------------------------------------------------------

draw_inventory_tab :: proc(g: ^Game, body: rl.Rectangle) {
	y := body.y + g.sheet_scroll

	if len(g.inventory.items) == 0 {
		draw_text(
			g.font,
			"Your pockets contain lint and a receipt you cannot read.",
			{body.x, y + 10},
			17,
			COL_NARRATION,
		)
		return
	}

	mouse := rl.GetMousePosition()

	for &it in g.inventory.items {
		desc_h := wrapped_height(g.font, it.description, 16, body.width - 60, 22)
		h := 30 + desc_h + f32(len(it.modifiers)) * 20 + 14

		row := rl.Rectangle{body.x - 8, y - 6, body.width + 16, h}
		hovered := rl.CheckCollisionPointRec(mouse, row)
		if hovered && it.equippable {
			rl.DrawRectangleRec(row, fade(COL_PAPER, 0.05))
			if rl.IsMouseButtonPressed(.LEFT) {
				inventory_toggle_equip(&g.inventory, it.id)
			}
		}

		name_col := it.equipped ? COL_SYSTEM : COL_PAPER
		draw_text(g.font_title, it.name, {body.x, y}, 18, name_col)

		if it.equippable {
			tag := it.equipped ? "WORN" : (hovered ? "click to wear" : "")
			if tag != "" {
				m := measure(g.font_small, tag, 13)
				draw_text(
					g.font_small,
					tag,
					{body.x + body.width - m.x, y + 4},
					13,
					it.equipped ? COL_SYSTEM : COL_LOCKED,
					1.2,
				)
			}
		}
		y += 26

		draw_wrapped(g.font, it.description, {body.x, y}, 16, body.width - 60, 22, COL_NARRATION)
		y += desc_h + 4

		for m in it.modifiers {
			text := fmt.tprintf("%+d %s", m.value, skill_info[m.skill].name)
			col := m.value >= 0 ? COL_PASS : COL_FAIL
			if !it.equipped {
				col = fade(col, 0.45)
			}
			draw_text(g.font_small, text, {body.x, y}, 14, col, 0.6)
			y += 20
		}
		y += 16
	}
}

// ---------------------------------------------------------------------------

sheet_handle_input :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.C) || rl.IsKeyPressed(.J) || rl.IsKeyPressed(.I) {
		game_set_mode(g, .World)
		g.sheet_scroll = 0
		return
	}
	if rl.IsKeyPressed(.TAB) {
		next := int(g.sheet_tab) + 1
		if next > int(Sheet_Tab.Inventory) {
			next = 0
		}
		g.sheet_tab = Sheet_Tab(next)
		g.sheet_scroll = 0
	}

	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		g.sheet_scroll = math.min(0, g.sheet_scroll + wheel * 40)
	}
}
