package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Mode :: enum u8 {
	World,
	Dialogue,
	Sheet, // character sheet / thought cabinet / journal / inventory
	Game_Over,
	Title,
}

Sheet_Tab :: enum u8 {
	Skills,
	Thoughts,
	Journal,
	Inventory,
}

Game :: struct {
	mode:      Mode,
	prev_mode: Mode,

	// --- character -------------------------------------------------------
	player:    Character,
	inventory: Inventory,
	cabinet:   Thought_Cabinet,
	journal:   Journal,

	// --- persistent world state ------------------------------------------
	flags:           map[string]bool,
	taken_options:   map[string]bool,
	check_records:   map[string]Check_Record,
	passive_results: map[string]bool,

	// --- content ----------------------------------------------------------
	script:    Scene_Script,
	defs:      Defs,
	item_defs: map[string]Item,
	task_defs: map[string]Task,

	// --- runtime ----------------------------------------------------------
	dialogue:   Dialogue,
	scene:      Scene,
	player_ent: Actor,
	camera:     World_Camera,

	hovered_interactable: int,
	orb_phase:            f32,
	damage_flash:         f32,
	pending_level_ups:    int,

	// --- transient, contextual UI ----------------------------------------
	// Nothing in this group is on screen unless it has just changed.
	toasts:        [dynamic]Toast,
	vitals_reveal: f32,
	controls_hint: f32,

	// --- presentation -----------------------------------------------------
	font:        rl.Font,
	font_small:  rl.Font,
	font_title:  rl.Font,
	title_art:    rl.Texture2D,
	title_art_loaded: bool,
	detective_portrait: rl.Texture2D,
	detective_portrait_loaded: bool,
	sysadmin_portrait: rl.Texture2D,
	sysadmin_portrait_loaded: bool,
	priya_portrait: rl.Texture2D,
	priya_portrait_loaded: bool,
	scene_rt:    rl.RenderTexture2D,
	light_rt:    rl.RenderTexture2D,
	painterly:   Painterly,
	sheet_tab:   Sheet_Tab,
	sheet_scroll: f32,
	time:        f32,

	// --- housekeeping -----------------------------------------------------
	content_dir:  string,
	assets_dir:   string,
	load_errors:  [dynamic]string,
	reload_notice: f32,
	game_over_reason: string,
	headless:     bool,
	// Set by --screenshot. The capture run drives itself, so live keyboard and
	// mouse input is ignored: a stray keystroke inherited from the launching
	// terminal must not decide what the captured frames contain.
	scripted:     bool,
}

game_init_state :: proc(g: ^Game) {
	g.flags = make(map[string]bool)
	g.taken_options = make(map[string]bool)
	g.check_records = make(map[string]Check_Record)
	g.passive_results = make(map[string]bool)
	g.load_errors = make([dynamic]string)
	g.toasts = make([dynamic]Toast)
	g.hovered_interactable = -1

	inventory_init(&g.inventory)
	cabinet_init(&g.cabinet)
	journal_init(&g.journal)
	dialogue_init(&g.dialogue)

	// The detective you wake up as. Not good at anything in particular, which
	// is the point -- the first hour is finding out which voice is loudest.
	character_init(&g.player, 3, 3, 3, 3)
}

// Loads (or reloads) every .plot and .defs file. Returns false if anything is
// broken, with the reasons in g.load_errors.
game_load_content :: proc(g: ^Game) -> bool {
	clear(&g.load_errors)

	scenes_dir := fmt.tprintf("%s/scenes", g.content_dir)
	script, script_errors := load_scripts(scenes_dir)
	g.script = script

	for e in script_errors {
		append(&g.load_errors, fmt.aprintf("%s:%d  %s", e.file, e.line, e.msg))
	}

	validation := validate_script(&g.script)
	for e in validation {
		append(&g.load_errors, fmt.aprintf("%s:%d  %s", e.file, e.line, e.msg))
	}

	defs, def_errors := load_defs(g.content_dir)
	g.defs = defs
	for e in def_errors {
		append(&g.load_errors, fmt.aprintf("%s:%d  %s", e.file, e.line, e.msg))
	}

	// The floor plan is content too, so F5 rebuilds the room along with the
	// writing. Anyone left standing inside a wall by an edit gets nudged out.
	map_errors := scene_build(&g.scene, g.content_dir)
	for e in map_errors {
		append(&g.load_errors, fmt.aprintf("%s:%d  %s", e.file, e.line, e.msg))
	}
	if g.scene.built {
		camera_set_bounds(&g.camera, g.scene.grid.w, g.scene.grid.h)
		if tilemap_blocked_at(&g.scene.grid, g.player_ent.pos.x, g.player_ent.pos.y) {
			g.player_ent.pos = g.scene.spawn
		}
	}

	g.item_defs = g.defs.items
	g.task_defs = g.defs.tasks

	// Thought definitions seed the cabinet in the Unknown state; dialogue moves
	// them to Researching. Reloading keeps whatever progress the player made.
	game_merge_thoughts(g)

	return len(g.load_errors) == 0
}

// Hot reload must not wipe the run. Thoughts already in flight keep their
// state and progress; only the authored text and modifiers are refreshed.
game_merge_thoughts :: proc(g: ^Game) {
	old := g.cabinet.thoughts
	g.cabinet.thoughts = make([dynamic]Thought)

	for def in g.defs.thoughts {
		t := def
		for &prev in old {
			if prev.id == def.id {
				t.state = prev.state
				t.beats_done = prev.beats_done
				break
			}
		}
		append(&g.cabinet.thoughts, t)
	}

	delete(old)
}

game_reload_content :: proc(g: ^Game) {
	ok := game_load_content(g)
	g.reload_notice = 2.5
	if !ok {
		for e in g.load_errors {
			fmt.eprintln("content error:", e)
		}
	}
}

// ---------------------------------------------------------------------------
// Death
// ---------------------------------------------------------------------------

// Neither of these is a hit point bar running out. One is your body quitting,
// the other is you deciding you are not the person who solves this.
game_check_death :: proc(g: ^Game) {
	if g.mode == .Game_Over {
		return
	}
	if g.player.health <= 0 {
		g.game_over_reason = "Your body filed its objection and it was sustained.\nYou go down between the racks, and the racks keep humming."
		g.mode = .Game_Over
	} else if g.player.morale <= 0 {
		g.game_over_reason = "You stop believing you are the kind of person who finds things out.\nThe belief does not come back before dawn."
		g.mode = .Game_Over
	}
}

game_set_mode :: proc(g: ^Game, m: Mode) {
	if g.mode != m {
		g.prev_mode = g.mode
		g.mode = m
	}
}

// ---------------------------------------------------------------------------
// Levelling
// ---------------------------------------------------------------------------

game_spend_point :: proc(g: ^Game, s: Skill) -> bool {
	if g.pending_level_ups <= 0 {
		return false
	}
	g.player.skill_points[s] += 1
	g.pending_level_ups -= 1
	// A new point can reopen a white check that was previously out of reach.
	if g.dialogue.active {
		dialogue_rebuild_options(g)
	}
	return true
}

clone_str :: proc(s: string) -> string {
	return strings.clone(s)
}
