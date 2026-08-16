package game

import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

WINDOW_W :: 1600
WINDOW_H :: 900
TITLE :: "HACK THE PLOT"

g_audio: Audio

main :: proc() {
	content_dir, assets_dir := resolve_dirs()

	if has_flag_arg("--test") {
		os.exit(run_headless_tests(content_dir))
	}

	g := new(Game)
	g.content_dir = content_dir
	g.assets_dir = assets_dir
	game_init_state(g)

	if !game_load_content(g) {
		fmt.eprintln("content failed to load:")
		for e in g.load_errors {
			fmt.eprintln("  ", e)
		}
		fmt.eprintln("\nrun with --test for the full report")
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT, .VSYNC_HINT})
	rl.InitWindow(WINDOW_W, WINDOW_H, TITLE)
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL) // Escape closes menus, it does not quit the game

	load_presentation(g)
	defer unload_presentation(g)

	audio_init(&g_audio)
	defer audio_shutdown(&g_audio)

	build_server_room(&g.scene)
	g.player_ent.pos = g.scene.spawn
	g.player_ent.pending_interactable = -1
	camera_init(&g.camera, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
	g.camera.bounds_min = {0, 0}
	g.camera.bounds_max = {f32(g.scene.nav.w), f32(g.scene.nav.h)}
	camera_center_on(&g.camera, g.player_ent.pos, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

	g.mode = .Title

	shot_mode := has_flag_arg("--screenshot")
	frame := 0

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		g.time += dt

		update(g, dt)
		draw(g)

		if shot_mode {
			frame += 1
			if screenshot_script(g, frame) {
				break
			}
		}

		free_all(context.temp_allocator)
	}
}

// Drives the game through a fixed sequence and captures each screen, so the
// visuals can be checked without a human at the keyboard. Returns true when
// the sequence is finished.
screenshot_script :: proc(g: ^Game, frame: int) -> bool {
	switch frame {
	case 30:
		rl.TakeScreenshot("shot_1_title.png")
	case 40:
		game_set_mode(g, .World)
	case 70:
		rl.TakeScreenshot("shot_2_world.png")
	case 80:
		dialogue_start(g, &g.script, "the_body_desk")
		game_set_mode(g, .Dialogue)
	case 82:
		dialogue_skip_reveal(&g.dialogue)
	case 100:
		rl.TakeScreenshot("shot_3_dialogue.png")
	case 110:
		// Force a check popup so the modifier breakdown can be inspected.
		flag_set(g, "has_headphones", true)
		dialogue_start(g, &g.script, "whiteboard_hand")
	case 112:
		dialogue_skip_reveal(&g.dialogue)
		if len(g.dialogue.options) > 0 {
			dialogue_select(g, 0)
		}
	case 130:
		rl.TakeScreenshot("shot_4_check.png")
	case 135:
		dialogue_commit_check(g)
	case 215:
		rl.TakeScreenshot("shot_5_roll.png")
	case 225:
		dialogue_finish_check(g)
		dialogue_close(g)
		g.pending_level_ups = 2
		g.sheet_tab = .Skills
		game_set_mode(g, .Sheet)
	case 240:
		rl.TakeScreenshot("shot_6_skills.png")
	case 245:
		apply_effect(g, Effect{kind = .Add_Thought, id = "harmonic_greed"})
		apply_effect(g, Effect{kind = .Add_Thought, id = "the_invigilator"})
		g.sheet_tab = .Thoughts
	case 260:
		rl.TakeScreenshot("shot_7_thoughts.png")
	case 270:
		return true
	}
	return false
}

// Content and assets live next to the executable's project root, not the CWD,
// so the game can be launched from anywhere.
resolve_dirs :: proc() -> (content, assets: string) {
	// Prefer an explicit override, then the project layout relative to the
	// binary, then the current directory.
	for arg, i in os.args {
		if arg == "--content" && i + 1 < len(os.args) {
			return os.args[i + 1], fmt.aprintf("%s/../assets", os.args[i + 1])
		}
	}

	exe := os.args[0]
	dir := filepath.dir(exe)
	candidate := fmt.aprintf("%s/../content", dir)
	if os.exists(candidate) {
		return candidate, fmt.aprintf("%s/../assets", dir)
	}
	if os.exists("content") {
		return "content", "assets"
	}
	return candidate, fmt.aprintf("%s/../assets", dir)
}

load_presentation :: proc(g: ^Game) {
	g.font = load_font_or_default(fmt.tprintf("%s/fonts/body.ttf", g.assets_dir))
	g.font_small = load_font_or_default(fmt.tprintf("%s/fonts/body-condensed.ttf", g.assets_dir))
	g.font_title = load_font_or_default(fmt.tprintf("%s/fonts/title.ttf", g.assets_dir))

	// Key art gives the title screen an immediate sense of place before the
	// player sees the deliberately abstracted isometric room.
	art_path := fmt.tprintf("%s/art/server_room_key_art.png", g.assets_dir)
	if os.exists(art_path) {
		g.title_art = rl.LoadTexture(cstring(raw_data(fmt.tprintf("%s\x00", art_path))))
		g.title_art_loaded = g.title_art.id != 0
		if g.title_art_loaded {
			rl.SetTextureFilter(g.title_art, .BILINEAR)
		}
	}
	portrait_path := fmt.tprintf("%s/art/detective_portrait.png", g.assets_dir)
	if os.exists(portrait_path) {
		g.detective_portrait = rl.LoadTexture(cstring(raw_data(fmt.tprintf("%s\x00", portrait_path))))
		g.detective_portrait_loaded = g.detective_portrait.id != 0
		if g.detective_portrait_loaded {
			rl.SetTextureFilter(g.detective_portrait, .BILINEAR)
		}
	}
	sysadmin_path := fmt.tprintf("%s/art/sysadmin_portrait.png", g.assets_dir)
	if os.exists(sysadmin_path) {
		g.sysadmin_portrait = rl.LoadTexture(cstring(raw_data(fmt.tprintf("%s\x00", sysadmin_path))))
		g.sysadmin_portrait_loaded = g.sysadmin_portrait.id != 0
		if g.sysadmin_portrait_loaded {
			rl.SetTextureFilter(g.sysadmin_portrait, .BILINEAR)
		}
	}
	priya_path := fmt.tprintf("%s/art/priya_portrait.png", g.assets_dir)
	if os.exists(priya_path) {
		g.priya_portrait = rl.LoadTexture(cstring(raw_data(fmt.tprintf("%s\x00", priya_path))))
		g.priya_portrait_loaded = g.priya_portrait.id != 0
		if g.priya_portrait_loaded {
			rl.SetTextureFilter(g.priya_portrait, .BILINEAR)
		}
	}
	world_path := fmt.tprintf("%s/art/server_room_topdown.png", g.assets_dir)
	if os.exists(world_path) {
		g.world_art = rl.LoadTexture(cstring(raw_data(fmt.tprintf("%s\x00", world_path))))
		g.world_art_loaded = g.world_art.id != 0
		if g.world_art_loaded {
			rl.SetTextureFilter(g.world_art, .BILINEAR)
		}
	}

	g.scene_rt = rl.LoadRenderTexture(i32(rl.GetScreenWidth()), i32(rl.GetScreenHeight()))
	rl.SetTextureFilter(g.scene_rt.texture, .BILINEAR)

	painterly_load(&g.painterly, g.assets_dir)
}

unload_presentation :: proc(g: ^Game) {
	painterly_unload(&g.painterly)
	if g.title_art_loaded {
		rl.UnloadTexture(g.title_art)
	}
	if g.detective_portrait_loaded {
		rl.UnloadTexture(g.detective_portrait)
	}
	if g.sysadmin_portrait_loaded {
		rl.UnloadTexture(g.sysadmin_portrait)
	}
	if g.priya_portrait_loaded {
		rl.UnloadTexture(g.priya_portrait)
	}
	if g.world_art_loaded {
		rl.UnloadTexture(g.world_art)
	}
	rl.UnloadRenderTexture(g.scene_rt)
}

// The render target has to track the window, or the painterly pass stretches.
ensure_render_target :: proc(g: ^Game) {
	w := i32(rl.GetScreenWidth())
	h := i32(rl.GetScreenHeight())
	if g.scene_rt.texture.width != w || g.scene_rt.texture.height != h {
		rl.UnloadRenderTexture(g.scene_rt)
		g.scene_rt = rl.LoadRenderTexture(w, h)
		rl.SetTextureFilter(g.scene_rt.texture, .BILINEAR)
	}
}

// ---------------------------------------------------------------------------
// Update
// ---------------------------------------------------------------------------

update :: proc(g: ^Game, dt: f32) {
	audio_update(&g_audio, dt)

	if g.reload_notice > 0 {
		g.reload_notice -= dt
	}
	if g.damage_flash > 0 {
		g.damage_flash -= dt * 1.6
	}

	handle_global_keys(g)

	switch g.mode {
	case .Title:
		update_title(g)
	case .World:
		// The top-down room is a composed 2D scene, not a movable diorama. Keep
		// the old camera path available only for the procedural fallback.
		camera_update(&g.camera, dt, !g.world_art_loaded)
		world_update(g, dt)
		world_handle_input(g)
		// Walking into an interactable opens its dialogue from player_arrive.
		if g.dialogue.active {
			game_set_mode(g, .Dialogue)
		}
	case .Dialogue:
		camera_update(&g.camera, dt, false)
		world_update(g, dt)
		dialogue_update(g, dt)
		dialogue_handle_input(g)
		if !g.dialogue.active {
			game_set_mode(g, .World)
		}
		// Typewriter clatter, keyed off the reveal actually advancing.
		if !dialogue_fully_revealed(&g.dialogue) {
			audio_typewriter(&g_audio)
		}
	case .Sheet:
		sheet_handle_input(g)
	case .Game_Over:
		if rl.IsKeyPressed(.ENTER) {
			restart(g)
		}
	}

	game_check_death(g)
}

update_title :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ENTER) || rl.IsMouseButtonPressed(.LEFT) {
		game_set_mode(g, .World)
		if g.scene.opening_node != "" {
			if _, ok := g.script.nodes[g.scene.opening_node]; ok {
				dialogue_start(g, &g.script, g.scene.opening_node)
				game_set_mode(g, .Dialogue)
			}
		}
	}
	if rl.IsKeyPressed(.L) && save_exists(g) {
		if load_game(g) {
			g.player_ent.pos = g.player_ent.pos
			game_set_mode(g, .World)
		}
	}
}

handle_global_keys :: proc(g: ^Game) {
	if g.mode == .Title || g.mode == .Game_Over {
		return
	}

	// Hot reload. The whole point is to keep the run going while the writing
	// changes underneath it.
	if rl.IsKeyPressed(.F5) {
		game_reload_content(g)
		if g.dialogue.active {
			// The node we were standing in may have been rewritten or removed.
			if _, ok := g.script.nodes[g.dialogue.node_id]; ok {
				g.dialogue.script = &g.script
				dialogue_rebuild_options(g)
			} else {
				dialogue_close(g)
				game_set_mode(g, .World)
			}
		}
	}

	if rl.IsKeyPressed(.F6) {
		g.painterly.enabled = !g.painterly.enabled
	}
	if rl.IsKeyPressed(.F2) {
		save_game(g)
		g.reload_notice = 2.0
	}

	if g.dialogue.active {
		return
	}

	if rl.IsKeyPressed(.C) {
		g.sheet_tab = .Skills
		game_set_mode(g, g.mode == .Sheet ? .World : .Sheet)
	}
	if rl.IsKeyPressed(.T) {
		g.sheet_tab = .Thoughts
		game_set_mode(g, .Sheet)
	}
	if rl.IsKeyPressed(.J) {
		g.sheet_tab = .Journal
		game_set_mode(g, g.mode == .Sheet ? .World : .Sheet)
	}
	if rl.IsKeyPressed(.I) {
		g.sheet_tab = .Inventory
		game_set_mode(g, g.mode == .Sheet ? .World : .Sheet)
	}
}

restart :: proc(g: ^Game) {
	clear(&g.flags)
	clear(&g.taken_options)
	clear(&g.check_records)
	clear(&g.passive_results)
	clear(&g.journal.tasks)
	clear(&g.inventory.items)
	for &t in g.cabinet.thoughts {
		t.state = .Unknown
		t.beats_done = 0
	}
	for s in Skill {
		g.player.skill_points[s] = 0
	}
	character_init(&g.player, 3, 3, 3, 3)
	g.pending_level_ups = 0
	g.player_ent.pos = g.scene.spawn
	g.player_ent.path = nil
	for &it in g.scene.interactables {
		it.seen = false
	}
	dialogue_log_reset(&g.dialogue)
	g.mode = .Title
}

// ---------------------------------------------------------------------------
// Draw
// ---------------------------------------------------------------------------

draw :: proc(g: ^Game) {
	ensure_render_target(g)

	// The world goes through the painterly pass; the UI does not, because
	// wobbling text is unreadable.
	rl.BeginTextureMode(g.scene_rt)
	render_world(g)
	rl.EndTextureMode()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	painterly_present(&g.painterly, g.scene_rt, g.time)

	switch g.mode {
	case .Title:
		draw_title(g)
	case .World:
		draw_hud(g)
	case .Dialogue:
		draw_hud(g)
		draw_dialogue(g)
	case .Sheet:
		draw_hud(g)
		draw_sheet(g)
	case .Game_Over:
		draw_game_over(g)
	}

	rl.EndDrawing()
}

draw_title :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	if g.title_art_loaded {
		src := rl.Rectangle{0, 0, f32(g.title_art.width), f32(g.title_art.height)}
		rl.DrawTexturePro(g.title_art, src, {0, 0, sw, sh}, {0, 0}, 0, rl.WHITE)
	} else {
		rl.DrawRectangleRec({0, 0, sw, sh}, fade(rl.BLACK, 0.78))
	}

	// A dark, painted-feeling veil keeps the words readable while letting the
	// crime scene keep breathing at the edges of the screen.
	for i := 0; i < 9; i += 1 {
		t := f32(i) / 8.0
		inset := t * 38
		rl.DrawRectangleLinesEx({inset, inset, sw - inset*2, sh - inset*2}, 18, fade(COL_INK, 0.055))
	}
	rl.DrawRectangleRec({0, 0, sw, sh}, fade(COL_INK, 0.38))
	panel_w := math.min(sw * 0.56, 780)
	draw_panel({(sw - panel_w) * 0.5, sh * 0.15, panel_w, sh * 0.70}, fade(COL_INK, 0.72), fade(COL_PAPER, 0.20))

	y := sh * 0.22

	title := "HACK THE PLOT"
	tm := measure(g.font_title, title, 74, 6)
	draw_text(g.font_title, title, {(sw - tm.x) * 0.5, y}, 74, COL_PAPER, 6)
	y += 92

	sub := "a night at TechHunt"
	sm := measure(g.font, sub, 22)
	draw_text(g.font, sub, {(sw - sm.x) * 0.5, y}, 22, fade(COL_NARRATION, 0.9))
	y += 48
	draw_hline((sw - panel_w) * 0.5 + 38, y, panel_w - 76, fade(COL_KEY, 0.45))
	y += 30

	lines := []string {
		"The scoreboard has been frozen since 02:14.",
		"One contestant is not answering.",
		"The final flag was submitted eleven minutes ago",
		"by an account that was never registered.",
		"",
		"You have until dawn, and you have no idea who you are.",
	}
	for line in lines {
		m := measure(g.font, line, 19)
		draw_text(g.font, line, {(sw - m.x) * 0.5, y}, 19, fade(COL_OPTION, 0.85))
		y += 28
	}

	y += 24
	prompt := save_exists(g) ? "[enter] wake up      [L] resume" : "[enter] wake up"
	pm := measure(g.font_small, prompt, 18)
	draw_text(g.font_small, prompt, {(sw - pm.x) * 0.5, y}, 18, COL_SYSTEM, 1.4)

	if len(g.load_errors) > 0 {
		warn := fmt.tprintf("%d content error(s) - run with --test", len(g.load_errors))
		wm := measure(g.font_small, warn, 15)
		draw_text(g.font_small, warn, {(sw - wm.x) * 0.5, sh - 44}, 15, COL_FAIL)
	}
}

draw_game_over :: proc(g: ^Game) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	rl.DrawRectangleRec({0, 0, sw, sh}, fade(rl.BLACK, 0.88))

	y := sh * 0.34
	title := g.player.health <= 0 ? "YOUR BODY GAVE OUT" : "YOU GAVE UP"
	tm := measure(g.font_title, title, 52, 4)
	draw_text(g.font_title, title, {(sw - tm.x) * 0.5, y}, 52, COL_FAIL, 4)
	y += 84

	for line in strings.split_lines(g.game_over_reason, context.temp_allocator) {
		m := measure(g.font, line, 20)
		draw_text(g.font, line, {(sw - m.x) * 0.5, y}, 20, COL_NARRATION)
		y += 30
	}

	y += 40
	prompt := "[enter] wake up again"
	pm := measure(g.font_small, prompt, 18)
	draw_text(g.font_small, prompt, {(sw - pm.x) * 0.5, y}, 18, COL_SYSTEM, 1.4)
}
