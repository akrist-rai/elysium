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

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT, .VSYNC_HINT})
	rl.InitWindow(WINDOW_W, WINDOW_H, TITLE)
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL) // Escape closes menus, it does not quit the game

	// Content includes the floor plan, so this is what builds the room.
	if !game_load_content(g) {
		fmt.eprintln("content failed to load:")
		for e in g.load_errors {
			fmt.eprintln("  ", e)
		}
		fmt.eprintln("\nrun with --test for the full report")
	}

	load_presentation(g)
	defer unload_presentation(g)

	audio_init(&g_audio)
	defer audio_shutdown(&g_audio)

	g.player_ent.kind = .Player
	g.player_ent.pos = g.scene.spawn
	g.player_ent.facing = math.PI * 0.5 // looking down the room
	camera_init(&g.camera, g.player_ent.pos)
	camera_set_bounds(&g.camera, g.scene.grid.w, g.scene.grid.h)
	camera_snap(&g.camera, g.player_ent.pos)

	g.mode = .Title

	shot_mode := has_flag_arg("--screenshot")
	g.scripted = shot_mode
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

// Content and assets live next to the executable's project root, not the CWD,
// so the game can be launched from anywhere.
resolve_dirs :: proc() -> (content, assets: string) {
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

	// The only painted art left is the title card and the dossier portraits.
	// The room itself is no longer a picture of a room.
	g.title_art, g.title_art_loaded = load_texture_if_present(fmt.tprintf("%s/art/server_room_key_art.png", g.assets_dir))
	g.detective_portrait, g.detective_portrait_loaded = load_texture_if_present(fmt.tprintf("%s/art/detective_portrait.png", g.assets_dir))
	g.sysadmin_portrait, g.sysadmin_portrait_loaded = load_texture_if_present(fmt.tprintf("%s/art/sysadmin_portrait.png", g.assets_dir))
	g.priya_portrait, g.priya_portrait_loaded = load_texture_if_present(fmt.tprintf("%s/art/priya_portrait.png", g.assets_dir))

	w := i32(rl.GetScreenWidth())
	h := i32(rl.GetScreenHeight())
	g.scene_rt = rl.LoadRenderTexture(w, h)
	g.light_rt = rl.LoadRenderTexture(w, h)
	rl.SetTextureFilter(g.scene_rt.texture, .BILINEAR)
	rl.SetTextureFilter(g.light_rt.texture, .BILINEAR)

	painterly_load(&g.painterly, g.assets_dir)
}

load_texture_if_present :: proc(path: string) -> (rl.Texture2D, bool) {
	tex: rl.Texture2D
	if !os.exists(path) {
		return tex, false
	}
	tex = rl.LoadTexture(strings.clone_to_cstring(path, context.temp_allocator))
	if tex.id == 0 {
		return tex, false
	}
	rl.SetTextureFilter(tex, .BILINEAR)
	return tex, true
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
	rl.UnloadRenderTexture(g.scene_rt)
	rl.UnloadRenderTexture(g.light_rt)
}

// The render targets have to track the window, or the light map stops lining up
// with the scene it is lighting.
ensure_render_targets :: proc(g: ^Game) {
	w := i32(rl.GetScreenWidth())
	h := i32(rl.GetScreenHeight())
	if g.scene_rt.texture.width == w && g.scene_rt.texture.height == h {
		return
	}
	rl.UnloadRenderTexture(g.scene_rt)
	rl.UnloadRenderTexture(g.light_rt)
	g.scene_rt = rl.LoadRenderTexture(w, h)
	g.light_rt = rl.LoadRenderTexture(w, h)
	rl.SetTextureFilter(g.scene_rt.texture, .BILINEAR)
	rl.SetTextureFilter(g.light_rt.texture, .BILINEAR)
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

	if !g.scripted {
		handle_global_keys(g)
	}

	switch g.mode {
	case .Title:
		if !g.scripted {
			update_title(g)
		}
	case .World:
		world_update(g, dt)
		if !g.scripted {
			world_handle_input(g)
		}
		// Walking up to something and pressing E is the only way in.
		if g.dialogue.active {
			game_set_mode(g, .Dialogue)
		}
	case .Dialogue:
		// The world keeps running underneath: the camera settles, the racks
		// keep blinking, the sysadmin stays where they stopped.
		world_update(g, dt)
		dialogue_update(g, dt)
		if !g.scripted {
			dialogue_handle_input(g)
		}
		if !g.dialogue.active {
			game_set_mode(g, .World)
		}
		if !dialogue_fully_revealed(&g.dialogue) {
			audio_typewriter(&g_audio)
		}
	case .Sheet:
		toasts_update(g, dt)
		if !g.scripted {
			sheet_handle_input(g)
		}
	case .Game_Over:
		if rl.IsKeyPressed(.ENTER) {
			restart(g)
		}
	}

	game_check_death(g)
}

update_title :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ENTER) || rl.IsMouseButtonPressed(.LEFT) {
		enter_world(g)
		if g.scene.opening_node != "" {
			if _, ok := g.script.nodes[g.scene.opening_node]; ok {
				dialogue_start(g, &g.script, g.scene.opening_node)
				game_set_mode(g, .Dialogue)
			}
		}
	}
	if rl.IsKeyPressed(.L) && save_exists(g) {
		if load_game(g) {
			enter_world(g)
			camera_snap(&g.camera, g.player_ent.pos)
		}
	}
}

enter_world :: proc(g: ^Game) {
	game_set_mode(g, .World)
	g.controls_hint = 9.0
}

handle_global_keys :: proc(g: ^Game) {
	if g.mode == .Title || g.mode == .Game_Over {
		return
	}

	// Hot reload. The whole point is to keep the run going while the writing --
	// and now the floor plan -- changes underneath it.
	if rl.IsKeyPressed(.F5) {
		game_reload_content(g)
		if g.dialogue.active {
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

	// The sheets are the only chrome in the game, and they are all on demand.
	if rl.IsKeyPressed(.TAB) || rl.IsKeyPressed(.C) {
		g.sheet_tab = .Skills
		game_set_mode(g, g.mode == .Sheet ? .World : .Sheet)
	}
	if rl.IsKeyPressed(.T) {
		g.sheet_tab = .Thoughts
		game_set_mode(g, g.mode == .Sheet ? .World : .Sheet)
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
	g.player_ent.vel = {0, 0}
	camera_snap(&g.camera, g.player_ent.pos)
	for &it in g.scene.interactables {
		it.seen = false
	}
	dialogue_log_reset(&g.dialogue)
	g.mode = .Title
}

// ---------------------------------------------------------------------------
// Draw
// ---------------------------------------------------------------------------

// Draws a render texture over the whole screen. Render textures come out of GL
// bottom-up, so the source height is negative.
blit_rt :: proc(rt: rl.RenderTexture2D) {
	src := rl.Rectangle{0, 0, f32(rt.texture.width), -f32(rt.texture.height)}
	dst := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	rl.DrawTexturePro(rt.texture, src, dst, {0, 0}, 0, rl.WHITE)
}

draw :: proc(g: ^Game) {
	ensure_render_targets(g)

	// 1. The room, unlit.
	rl.BeginTextureMode(g.scene_rt)
	render_world(g)
	rl.EndTextureMode()

	// 2. The light map: ambient plus every source in the room.
	rl.BeginTextureMode(g.light_rt)
	render_lighting(g)
	rl.EndTextureMode()

	// 3. Multiply the light over the room, then put the sources themselves back
	//    on top so they are not dimmed by their own falloff.
	rl.BeginTextureMode(g.scene_rt)
	rl.BeginBlendMode(.MULTIPLIED)
	blit_rt(g.light_rt)
	rl.EndBlendMode()
	render_glow(g)
	rl.EndTextureMode()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// The world goes through the painterly pass; the UI does not, because
	// wobbling text is unreadable.
	painterly_present(&g.painterly, g.scene_rt, g.time)

	switch g.mode {
	case .Title:
		draw_title(g)
	case .World:
		draw_world_overlay(g)
	case .Dialogue:
		// Settle the room back a stop so the words carry the screen.
		rl.DrawRectangleRec(
			{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
			fade(COL_INK, 0.34),
		)
		draw_dialogue(g)
		draw_toasts(g)
	case .Sheet:
		draw_sheet(g)
		draw_toasts(g)
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

	for i := 0; i < 9; i += 1 {
		t := f32(i) / 8.0
		inset := t * 38
		rl.DrawRectangleLinesEx({inset, inset, sw - inset * 2, sh - inset * 2}, 18, fade(COL_INK, 0.055))
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

// ---------------------------------------------------------------------------
// Screenshot driver
// ---------------------------------------------------------------------------

// Drives the game through a fixed sequence and captures each screen, so the
// visuals can be checked without a human at the keyboard.
screenshot_script :: proc(g: ^Game, frame: int) -> bool {
	teleport :: proc(g: ^Game, x, y, facing: f32) {
		g.player_ent.pos = {x, y}
		g.player_ent.vel = {0, 0}
		g.player_ent.facing = facing
		camera_snap(&g.camera, g.player_ent.pos)
	}

	switch frame {
	case 30:
		rl.TakeScreenshot("shot_1_title.png")
	case 40:
		enter_world(g)
		flag_set(g, "sysadmin_present", true)
	case 44:
		// Where you wake up, on the floor, in the middle of the room.
		teleport(g, 12.5, 15.5, math.PI * 0.5)
	case 75:
		rl.TakeScreenshot("shot_2_wake_spot.png")
	case 80:
		// Walking: velocity set so the walk cycle and the camera lead are live.
		g.player_ent.pos = {10.0, 12.0}
		g.player_ent.vel = {2.6, 1.8}
		g.player_ent.facing = 0.6
	case 90:
		rl.TakeScreenshot("shot_3_walking.png")
	case 95:
		// Standing at Priya's desk: the interaction prompt should be up.
		teleport(g, 6.4, 11.6, -math.PI * 0.5)
	case 125:
		rl.TakeScreenshot("shot_4_prompt.png")
	case 130:
		// The rack row, to check the lighting and the LED detail.
		teleport(g, 20.5, 6.6, -math.PI * 0.5)
	case 160:
		rl.TakeScreenshot("shot_5_racks.png")
	case 165:
		// The corridor, to prove the map keeps going past the room.
		teleport(g, 20.0, 28.0, 0)
	case 195:
		rl.TakeScreenshot("shot_6_corridor.png")
	case 200:
		teleport(g, 6.4, 11.6, -math.PI * 0.5)
		dialogue_start(g, &g.script, "the_body")
		game_set_mode(g, .Dialogue)
	case 204:
		dialogue_skip_reveal(&g.dialogue)
	case 225:
		rl.TakeScreenshot("shot_7_dialogue.png")
	case 230:
		flag_set(g, "has_headphones", true)
		dialogue_start(g, &g.script, "whiteboard_hand")
	case 234:
		dialogue_skip_reveal(&g.dialogue)
		if len(g.dialogue.options) > 0 {
			dialogue_select(g, 0)
		}
	case 255:
		rl.TakeScreenshot("shot_8_check.png")
	case 260:
		dialogue_finish_check(g)
		dialogue_close(g)
		g.pending_level_ups = 2
		g.sheet_tab = .Skills
		game_set_mode(g, .Sheet)
	case 280:
		rl.TakeScreenshot("shot_9_skills.png")
	case 290:
		return true
	}
	return false
}
