package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Authored data model
// ---------------------------------------------------------------------------

Line_Kind :: enum u8 {
	Say, // somebody in the room said it
	Voice, // one of your skills said it, and only if it passed its passive
}

Line :: struct {
	kind:    Line_Kind,
	speaker: string, // Say only
	skill:   Skill, // Voice only
	target:  int, // Voice only: the passive difficulty
	text:    string,
}

Condition_Kind :: enum u8 {
	Skill_At_Least,
	Flag_Set,
	Flag_Not_Set,
	Has_Item,
	Thought_Internalized,
	Once, // hide once it has been taken
}

Condition :: struct {
	kind:  Condition_Kind,
	id:    string,
	skill: Skill,
	value: int,
}

Effect_Kind :: enum u8 {
	Set_Flag,
	Clear_Flag,
	Health,
	Morale,
	XP,
	Give_Item,
	Take_Item,
	Add_Thought,
	Task_Add,
	Task_Done,
	Task_Fail,
}

Effect :: struct {
	kind:  Effect_Kind,
	id:    string,
	value: int,
}

Option_Kind :: enum u8 {
	Plain,
	Check,
}

Option :: struct {
	kind:        Option_Kind,
	text:        string,
	conditions:  []Condition,
	effects:     []Effect,
	target_node: string, // Plain

	// Check only
	skill:         Skill,
	check_kind:    Check_Kind,
	check_target:  int,
	authored_mods: []Authored_Modifier,
	pass_node:     string,
	fail_node:     string,
	check_id:      string, // stable key into Game.check_records
}

Node :: struct {
	id:            string,
	lines:         []Line,
	options:       []Option,
	entry_effects: []Effect,
	goto_node:     string, // auto-advance when there are no options
	ends:          bool, // END: close the dialogue
	source:        string, // file it came from, for error messages
	line_no:       int,
}

Scene_Script :: struct {
	nodes: map[string]Node,
	order: [dynamic]string, // declaration order, for deterministic validation
}

// ---------------------------------------------------------------------------
// Runtime
// ---------------------------------------------------------------------------

Log_Kind :: enum u8 {
	Narration,
	Speech,
	Voice,
	Player,
	Check_Outcome,
	System,
}

Log_Entry :: struct {
	kind:    Log_Kind,
	speaker: string,
	color:   rl.Color,
	text:    string,
}

Check_Popup_State :: enum u8 {
	Presenting, // odds on screen, waiting for the player to commit
	Rolling, // dice tumbling
	Revealed, // outcome shown, waiting for acknowledgement
}

Pending_Check :: struct {
	active:      bool,
	option_idx:  int,
	skill:       Skill,
	kind:        Check_Kind,
	target:      int,
	modifiers:   []Modifier,
	odds:        f32,
	state:       Check_Popup_State,
	timer:       f32,
	result:      Check_Result,
	pass_node:   string,
	fail_node:   string,
	// Faces shown while the dice tumble, so the animation reads as dice.
	shown_a:     int,
	shown_b:     int,
}

// An option after gating has been applied, carrying what the UI needs to draw
// it without re-deriving anything.
Resolved_Option :: struct {
	index:     int, // index into the node's option list
	text:      string,
	prefix:    string, // "[Empathy 8]" or "[Interfacing - Medium 10]"
	color:     rl.Color,
	is_check:  bool,
	is_red:    bool,
	odds:      f32,
	locked:    bool, // shown greyed: you can see it, you cannot take it
	lock_note: string,
}

Dialogue :: struct {
	active:       bool,
	script:       ^Scene_Script,
	node_id:      string,
	log:          [dynamic]Log_Entry,
	options:      [dynamic]Resolved_Option,
	// Typewriter reveal covers only the newest batch of entries.
	batch_start:  int,
	revealed:     f32,
	batch_chars:  int,
	scroll:       f32,
	hovered:      int,
	pending:      Pending_Check,
	// Carried alongside `pending` so committing a check does not need to look
	// the option up again after the node may have changed.
	pending_check_id:     string,
	pending_option_text:  string,
	pending_effects:      []Effect,
	// An END node shows its text first and closes a beat later.
	pending_end:  bool,
	end_hold:     f32,
	auto_hold:    f32,
	// Set when the dialogue closes, so the world can react.
	just_closed:  bool,
}

TYPEWRITER_CPS :: 55.0

dialogue_init :: proc(d: ^Dialogue) {
	d.log = make([dynamic]Log_Entry)
	d.options = make([dynamic]Resolved_Option)
	d.hovered = -1
}

dialogue_log_reset :: proc(d: ^Dialogue) {
	clear(&d.log)
	d.batch_start = 0
	d.revealed = 0
	d.batch_chars = 0
	d.scroll = 0
}

// ---------------------------------------------------------------------------
// Conditions and effects
// ---------------------------------------------------------------------------

flag_is_set :: proc(g: ^Game, flag: string) -> bool {
	if flag == "" {
		return false
	}
	return g.flags[flag] or_else false
}

flag_set :: proc(g: ^Game, flag: string, value: bool) {
	g.flags[strings.clone(flag)] = value
}

condition_met :: proc(g: ^Game, c: Condition, option_key: string) -> bool {
	switch c.kind {
	case .Skill_At_Least:
		return skill_effective(g, c.skill) >= c.value
	case .Flag_Set:
		return flag_is_set(g, c.id)
	case .Flag_Not_Set:
		return !flag_is_set(g, c.id)
	case .Has_Item:
		return inventory_has(&g.inventory, c.id)
	case .Thought_Internalized:
		return thought_is_internalized(&g.cabinet, c.id)
	case .Once:
		return !(g.taken_options[option_key] or_else false)
	}
	return true
}

// The skill value with everything that currently applies folded in. Used for
// gating options; checks build the itemised list separately.
skill_effective :: proc(g: ^Game, s: Skill) -> int {
	total := skill_base(g.player, s)
	for &item in g.inventory.items {
		if !item.equipped {
			continue
		}
		for m in item.modifiers {
			if m.skill == s {
				total += m.value
			}
		}
	}
	for &t in g.cabinet.thoughts {
		mods: []Skill_Modifier
		switch t.state {
		case .Researching:
			mods = t.research_modifiers
		case .Internalized:
			mods = t.bonus_modifiers
		case .Unknown:
			continue
		}
		for m in mods {
			if m.skill == s {
				total += m.value
			}
		}
	}
	return total
}

apply_effect :: proc(g: ^Game, e: Effect) {
	switch e.kind {
	case .Set_Flag:
		flag_set(g, e.id, true)
	case .Clear_Flag:
		flag_set(g, e.id, false)
	case .Health:
		g.player.health = clamp(g.player.health + e.value, 0, health_max(g.player))
		// The bars are not on screen any more, so a change has to announce
		// itself rather than waiting to be noticed in a corner.
		vitals_reveal(g)
		toast_push(g, fmt.tprintf("HEALTH %+d", e.value), COL_HEALTH)
		if e.value < 0 {
			g.damage_flash = 0.6
		}
	case .Morale:
		g.player.morale = clamp(g.player.morale + e.value, 0, morale_max(g.player))
		vitals_reveal(g)
		toast_push(g, fmt.tprintf("MORALE %+d", e.value), COL_MORALE)
		if e.value < 0 {
			g.damage_flash = 0.6
		}
	case .XP:
		if award_xp(&g.player, e.value) {
			g.pending_level_ups += 1
			dialogue_push_system(
				g,
				fmt.aprintf("LEVEL %d - a skill point is waiting.", g.player.level),
			)
		}
	case .Give_Item:
		if def, ok := g.item_defs[e.id]; ok {
			inventory_add(&g.inventory, def)
			dialogue_push_system(g, fmt.aprintf("Acquired: %s", def.name))
		}
	case .Take_Item:
		inventory_remove(&g.inventory, e.id)
	case .Add_Thought:
		if cabinet_start_research(&g.cabinet, e.id) {
			t := cabinet_find(&g.cabinet, e.id)
			dialogue_push_system(g, fmt.aprintf("New thought: %s", t.name))
		}
	case .Task_Add:
		if def, ok := g.task_defs[e.id]; ok {
			journal_add(&g.journal, def)
			dialogue_push_system(g, fmt.aprintf("Task: %s", def.title))
		}
	case .Task_Done:
		journal_set_state(&g.journal, e.id, .Completed)
		if t := journal_find(&g.journal, e.id); t != nil {
			dialogue_push_system(g, fmt.aprintf("Task complete: %s", t.title))
		}
	case .Task_Fail:
		journal_set_state(&g.journal, e.id, .Failed)
	}
}

apply_effects :: proc(g: ^Game, effects: []Effect) {
	for e in effects {
		apply_effect(g, e)
	}
}

dialogue_push_system :: proc(g: ^Game, text: string) {
	append(
		&g.dialogue.log,
		Log_Entry{kind = .System, speaker = "", color = COL_SYSTEM, text = text},
	)
}

// ---------------------------------------------------------------------------
// Passive checks
// ---------------------------------------------------------------------------

// Passives are rolled once per (node, skill, difficulty) and remembered, so
// two consecutive lines from the same voice never disagree, and revisiting a
// node does not re-roll what you already heard.
passive_passes :: proc(g: ^Game, node_id: string, s: Skill, target: int) -> bool {
	key := fmt.aprintf("%s|%d|%d", node_id, int(s), target, allocator = context.temp_allocator)
	if cached, ok := g.passive_results[key]; ok {
		return cached
	}
	mods := build_modifiers(g, s, nil, context.temp_allocator)
	res := resolve_check(s, .White, target, mods)
	g.passive_results[strings.clone(key)] = res.passed
	return res.passed
}

// ---------------------------------------------------------------------------
// Node entry
// ---------------------------------------------------------------------------

dialogue_start :: proc(g: ^Game, script: ^Scene_Script, node_id: string) {
	d := &g.dialogue
	d.active = true
	d.script = script
	d.just_closed = false
	dialogue_log_reset(d)
	dialogue_enter_node(g, node_id)
}

dialogue_close :: proc(g: ^Game) {
	d := &g.dialogue
	d.active = false
	d.just_closed = true
	d.pending.active = false
	clear(&d.options)
}

dialogue_enter_node :: proc(g: ^Game, node_id: string) {
	d := &g.dialogue

	node, ok := d.script.nodes[node_id]
	if !ok {
		dialogue_push_system(g, fmt.aprintf("[missing node: %s]", node_id))
		dialogue_close(g)
		return
	}

	d.node_id = node_id
	d.batch_start = len(d.log)

	apply_effects(g, node.entry_effects)

	// Every node entered is a beat, and beats are what move thoughts along.
	finished := cabinet_advance(&g.cabinet)
	for id in finished {
		if t := cabinet_find(&g.cabinet, id); t != nil {
			dialogue_push_system(g, fmt.aprintf("Thought internalized: %s", t.name))
		}
	}

	for line in node.lines {
		switch line.kind {
		case .Say:
			kind := Log_Kind.Speech
			if line.speaker == "" || line.speaker == "Narrator" {
				kind = .Narration
			} else if line.speaker == "You" {
				kind = .Player
			}
			append(
				&d.log,
				Log_Entry {
					kind = kind,
					speaker = line.speaker,
					color = speaker_color(line.speaker),
					text = line.text,
				},
			)
		case .Voice:
			// Failure is silent. You never find out what you did not hear.
			if !passive_passes(g, node_id, line.skill, line.target) {
				continue
			}
			append(
				&d.log,
				Log_Entry {
					kind = .Voice,
					speaker = skill_info[line.skill].name,
					color = skill_info[line.skill].color,
					text = line.text,
				},
			)
		}
	}

	dialogue_begin_reveal(d)

	d.pending_end = node.ends
	d.end_hold = 0
	d.auto_hold = 0

	dialogue_rebuild_options(g)
}

dialogue_begin_reveal :: proc(d: ^Dialogue) {
	total := 0
	for i in d.batch_start ..< len(d.log) {
		total += len(d.log[i].text)
	}
	d.batch_chars = total
	d.revealed = 0
}

dialogue_fully_revealed :: proc(d: ^Dialogue) -> bool {
	return int(d.revealed) >= d.batch_chars
}

dialogue_skip_reveal :: proc(d: ^Dialogue) {
	d.revealed = f32(d.batch_chars)
}

speaker_color :: proc(name: string) -> rl.Color {
	switch name {
	case "", "Narrator":
		return COL_NARRATION
	case "You":
		return COL_PLAYER
	}
	if s, ok := skill_from_name(name); ok {
		return skill_info[s].color
	}
	return COL_SPEECH
}

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

option_key :: proc(node_id: string, idx: int) -> string {
	return fmt.aprintf("%s#%d", node_id, idx, allocator = context.temp_allocator)
}

dialogue_rebuild_options :: proc(g: ^Game) {
	d := &g.dialogue
	clear(&d.options)

	node, ok := d.script.nodes[d.node_id]
	if !ok {
		return
	}

	for opt, i in node.options {
		key := option_key(d.node_id, i)

		visible := true
		locked := false
		lock_note := ""

		for c in opt.conditions {
			if condition_met(g, c, key) {
				continue
			}
			switch c.kind {
			case .Skill_At_Least:
				// Skill gates stay visible but greyed -- seeing what you are
				// not yet capable of is half the point.
				locked = true
				lock_note = fmt.aprintf(
					"%s %d needed",
					skill_info[c.skill].name,
					c.value,
					allocator = context.temp_allocator,
				)
			case .Flag_Set, .Flag_Not_Set, .Has_Item, .Thought_Internalized, .Once:
				visible = false
			}
		}
		if !visible {
			continue
		}

		ro := Resolved_Option {
			index     = i,
			text      = opt.text,
			locked    = locked,
			lock_note = strings.clone(lock_note, context.temp_allocator),
			color     = COL_OPTION,
		}

		if opt.kind == .Check {
			mods := build_modifiers(g, opt.skill, opt.authored_mods, context.temp_allocator)
			bonus := sum_modifiers(mods)
			rec := g.check_records[opt.check_id] or_else Check_Record{kind = opt.check_kind}

			ro.is_check = true
			ro.is_red = opt.check_kind == .Red
			ro.odds = check_odds(opt.check_target, bonus)
			ro.color = skill_info[opt.skill].color
			ro.prefix = fmt.aprintf(
				"[%s]",
				format_check_label(opt.skill, opt.check_target, context.temp_allocator),
				allocator = context.temp_allocator,
			)

			if !check_available(rec, bonus) {
				locked = true
				ro.locked = true
				if rec.passed {
					ro.lock_note = "already succeeded"
				} else if rec.kind == .Red {
					ro.lock_note = "failed - permanently"
				} else {
					ro.lock_note = "nothing has changed yet"
				}
			}
		} else {
			for c in opt.conditions {
				if c.kind == .Skill_At_Least {
					ro.color = skill_info[c.skill].color
					ro.prefix = fmt.aprintf(
						"[%s %d]",
						skill_info[c.skill].name,
						c.value,
						allocator = context.temp_allocator,
					)
					break
				}
			}
		}

		append(&d.options, ro)
	}
}

// ---------------------------------------------------------------------------
// Selection
// ---------------------------------------------------------------------------

dialogue_select :: proc(g: ^Game, resolved_idx: int) {
	d := &g.dialogue
	if resolved_idx < 0 || resolved_idx >= len(d.options) {
		return
	}
	ro := d.options[resolved_idx]
	if ro.locked {
		return
	}

	node, ok := d.script.nodes[d.node_id]
	if !ok {
		return
	}
	opt := node.options[ro.index]

	g.taken_options[strings.clone(option_key(d.node_id, ro.index))] = true

	if opt.kind == .Check {
		dialogue_open_check(g, opt, ro.index)
		return
	}

	// Echo the choice back as the player's own line, the way DE does.
	append(
		&d.log,
		Log_Entry{kind = .Player, speaker = "You", color = COL_PLAYER, text = opt.text},
	)

	apply_effects(g, opt.effects)
	dialogue_advance_to(g, opt.target_node)
}

dialogue_advance_to :: proc(g: ^Game, target: string) {
	d := &g.dialogue
	if target == "" || target == "END" {
		dialogue_close(g)
		return
	}
	dialogue_enter_node(g, target)
}

dialogue_open_check :: proc(g: ^Game, opt: Option, opt_index: int) {
	d := &g.dialogue
	mods := build_modifiers(g, opt.skill, opt.authored_mods)
	bonus := sum_modifiers(mods)

	d.pending = Pending_Check {
		active     = true,
		option_idx = opt_index,
		skill      = opt.skill,
		kind       = opt.check_kind,
		target     = opt.check_target,
		modifiers  = mods,
		odds       = check_odds(opt.check_target, bonus),
		state      = .Presenting,
		timer      = 0,
		pass_node  = opt.pass_node,
		fail_node  = opt.fail_node,
		shown_a    = 1,
		shown_b    = 1,
	}
	d.pending_check_id = opt.check_id
	d.pending_option_text = opt.text
	d.pending_effects = opt.effects
}

ROLL_DURATION :: 1.1

dialogue_commit_check :: proc(g: ^Game) {
	d := &g.dialogue
	if !d.pending.active || d.pending.state != .Presenting {
		return
	}
	d.pending.state = .Rolling
	d.pending.timer = 0
	d.pending.result = resolve_check(
		d.pending.skill,
		d.pending.kind,
		d.pending.target,
		d.pending.modifiers,
	)
}

dialogue_finish_check :: proc(g: ^Game) {
	d := &g.dialogue
	if !d.pending.active || d.pending.state != .Revealed {
		return
	}
	res := d.pending.result

	g.check_records[strings.clone(d.pending_check_id)] = Check_Record {
		attempted            = true,
		passed               = res.passed,
		bonus_when_attempted = res.bonus,
		kind                 = d.pending.kind,
	}

	// The attempt itself is the player's line.
	append(
		&d.log,
		Log_Entry {
			kind = .Player,
			speaker = "You",
			color = COL_PLAYER,
			text = d.pending_option_text,
		},
	)

	verdict := "FAILURE"
	col := COL_FAIL
	if res.passed {
		verdict = "SUCCESS"
		col = COL_PASS
	}
	crit := ""
	if res.critical {
		crit = res.passed ? "  (double six)" : "  (snake eyes)"
	}
	append(
		&d.log,
		Log_Entry {
			kind = .Check_Outcome,
			speaker = skill_info[res.skill].name,
			color = col,
			text = fmt.aprintf(
				"%s - %d + %d = %d vs %d%s",
				verdict,
				res.die_a + res.die_b,
				res.bonus,
				roll_total(res),
				res.target,
				crit,
			),
		},
	)

	apply_effects(g, d.pending_effects)

	// Passing a check is how you learn. Failing a red one teaches you more.
	xp := res.passed ? 25 : (d.pending.kind == .Red ? 15 : 0)
	if xp > 0 {
		apply_effect(g, Effect{kind = .XP, value = xp})
	}

	next := res.passed ? d.pending.pass_node : d.pending.fail_node
	d.pending.active = false
	dialogue_advance_to(g, next)
}

// ---------------------------------------------------------------------------
// Per-frame update
// ---------------------------------------------------------------------------

dialogue_update :: proc(g: ^Game, dt: f32) {
	d := &g.dialogue
	if !d.active {
		return
	}

	if !dialogue_fully_revealed(d) {
		d.revealed += TYPEWRITER_CPS * dt
	} else if d.pending_end && !d.pending.active {
		// An END node still shows its text; it closes once you have read it.
		if len(d.options) == 0 {
			d.end_hold += dt
			if d.end_hold > 0.4 {
				d.pending_end = false
				d.end_hold = 0
				dialogue_close(g)
				return
			}
		}
	}

	if d.pending.active {
		d.pending.timer += dt
		switch d.pending.state {
		case .Presenting:
		// waiting on the player
		case .Rolling:
			// Tumble the faces, then settle onto the real result.
			d.pending.shown_a = 1 + (int(d.pending.timer * 22) % 6)
			d.pending.shown_b = 1 + (int(d.pending.timer * 17) % 6)
			if d.pending.timer >= ROLL_DURATION {
				d.pending.shown_a = d.pending.result.die_a
				d.pending.shown_b = d.pending.result.die_b
				d.pending.state = .Revealed
				d.pending.timer = 0
			}
		case .Revealed:
		// waiting on the player
		}
		return
	}

	// Auto-advance nodes that are pure narration.
	if dialogue_fully_revealed(d) && len(d.options) == 0 && !d.pending_end {
		node, ok := d.script.nodes[d.node_id]
		if ok && node.goto_node != "" {
			d.auto_hold += dt
			if d.auto_hold > 0.25 {
				d.auto_hold = 0
				dialogue_advance_to(g, node.goto_node)
			}
		}
	}
}
