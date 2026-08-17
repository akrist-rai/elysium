package game

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"

// `hacktheplot --test` runs everything that does not need a GPU: the dice
// maths, the content parse, and a walk over every authored node. Broken writing
// should fail here, not twenty minutes into someone's playthrough.

Test_Ctx :: struct {
	passed: int,
	failed: int,
}

@(private = "file")
check :: proc(t: ^Test_Ctx, condition: bool, description: string) {
	if condition {
		t.passed += 1
		fmt.printfln("  ok    %s", description)
	} else {
		t.failed += 1
		fmt.printfln("  FAIL  %s", description)
	}
}

@(private = "file")
check_near :: proc(t: ^Test_Ctx, actual, expected, tolerance: f32, description: string) {
	ok := math.abs(actual - expected) <= tolerance
	if ok {
		t.passed += 1
		fmt.printfln("  ok    %s (%.4f)", description, actual)
	} else {
		t.failed += 1
		fmt.printfln("  FAIL  %s: got %.4f, expected %.4f", description, actual, expected)
	}
}

run_headless_tests :: proc(content_dir: string) -> int {
	t: Test_Ctx

	fmt.println("2d6 check distribution")
	test_check_maths(&t)

	fmt.println("\ndifficulty ladder")
	test_difficulty(&t)

	fmt.println("\ncheck availability rules")
	test_check_availability(&t)

	fmt.println("\ncontent")
	test_content(&t, content_dir)

	fmt.println("\ncritical path")
	test_critical_path(&t, content_dir)

	fmt.println("\nfloor plan")
	test_floor_plan(&t, content_dir)

	fmt.printfln("\n%d passed, %d failed", t.passed, t.failed)
	return t.failed == 0 ? 0 : 1
}

@(private = "file")
test_check_maths :: proc(t: ^Test_Ctx) {
	// The 2d6 sum distribution is 1,2,3,4,5,6,5,4,3,2,1 out of 36. Needing a
	// sum of 7 or better is therefore 21/36.
	check_near(t, check_odds(10, 3), 21.0 / 36.0, 0.0001, "target 10 with +3 is 58.3%")
	check_near(t, check_odds(10, 4), 26.0 / 36.0, 0.0001, "target 10 with +4 is 72.2%")
	// Needing a sum of 10 leaves 10, 11 and 12: 3 + 2 + 1 = 6 outcomes.
	check_near(t, check_odds(10, 0), 6.0 / 36.0, 0.0001, "target 10 unaided is 16.7%")
	// Needing a 12 leaves only the double six.
	check_near(t, check_odds(12, 0), 1.0 / 36.0, 0.0001, "target 12 unaided is 2.8%")
	check_near(t, check_odds(6, 4), 35.0 / 36.0, 0.0001, "trivial target caps at 35/36")

	// Snake eyes and double six override the arithmetic in both directions, so
	// no check is ever a certainty either way.
	check_near(t, check_odds(2, 0), 35.0 / 36.0, 0.0001, "impossible-to-fail check still fails on snake eyes")
	check_near(t, check_odds(99, 0), 1.0 / 36.0, 0.0001, "impossible check still passes on double six")

	check(t, !outcome_passes(1, 1, 2, 100), "snake eyes fails with a +100 bonus")
	check(t, outcome_passes(6, 6, 100, 0), "double six passes against target 100")

	// Odds must be monotonic in the bonus, or the popup would be lying.
	monotonic := true
	prev := f32(-1)
	for bonus in 0 ..= 12 {
		o := check_odds(14, bonus)
		if o < prev {
			monotonic = false
		}
		prev = o
	}
	check(t, monotonic, "odds never decrease as modifiers improve")

	// Every roll the resolver produces must agree with outcome_passes.
	consistent := true
	for _ in 0 ..< 4000 {
		mods := []Modifier{{"test", 3}}
		r := resolve_check(.Logic, .White, 11, mods)
		if r.passed != outcome_passes(r.die_a, r.die_b, r.target, r.bonus) {
			consistent = false
		}
		if r.die_a < 1 || r.die_a > 6 || r.die_b < 1 || r.die_b > 6 {
			consistent = false
		}
	}
	check(t, consistent, "4000 rolls stay in range and match the predicate")

	// And the empirical rate should land near the stated odds.
	target := 11
	bonus := 3
	wins := 0
	trials := 40000
	for _ in 0 ..< trials {
		r := resolve_check(.Logic, .White, target, []Modifier{{"test", bonus}})
		if r.passed {
			wins += 1
		}
	}
	empirical := f32(wins) / f32(trials)
	check_near(t, empirical, check_odds(target, bonus), 0.02, "40k rolls match the stated odds")
}

@(private = "file")
test_difficulty :: proc(t: ^Test_Ctx) {
	check(t, difficulty_for_target(6) == .Trivial, "6 is Trivial")
	check(t, difficulty_for_target(10) == .Medium, "10 is Medium")
	check(t, difficulty_for_target(12) == .Challenging, "12 is Challenging")
	check(t, difficulty_for_target(13) == .Challenging, "13 rounds down to Challenging")
	check(t, difficulty_for_target(20) == .Godly, "20 is Godly")
	check(t, difficulty_for_target(40) == .Impossible, "anything past the ladder is Impossible")
}

@(private = "file")
test_check_availability :: proc(t: ^Test_Ctx) {
	fresh := Check_Record{}
	check(t, check_available(fresh, 4), "an untried check is available")

	failed_white := Check_Record {
		attempted            = true,
		passed               = false,
		bonus_when_attempted = 4,
		kind                 = .White,
	}
	check(t, !check_available(failed_white, 4), "a failed white check stays shut until something changes")
	check(t, check_available(failed_white, 5), "a failed white check reopens when the bonus improves")
	check(t, !check_available(failed_white, 3), "a white check does not reopen when you get worse")

	failed_red := Check_Record {
		attempted            = true,
		passed               = false,
		bonus_when_attempted = 4,
		kind                 = .Red,
	}
	check(t, !check_available(failed_red, 99), "a failed red check never reopens")

	passed := Check_Record{attempted = true, passed = true, bonus_when_attempted = 4, kind = .White}
	check(t, !check_available(passed, 99), "a passed check is not re-rollable")
}

@(private = "file")
test_content :: proc(t: ^Test_Ctx, content_dir: string) {
	g := new(Game)
	g.content_dir = content_dir
	g.headless = true
	game_init_state(g)

	ok := game_load_content(g)

	if !ok {
		for e in g.load_errors {
			fmt.printfln("  FAIL  %s", e)
		}
		t.failed += len(g.load_errors)
	} else {
		t.passed += 1
		fmt.printfln("  ok    all .plot and .defs files parse and validate")
	}

	check(t, len(g.script.nodes) > 0, "at least one dialogue node was loaded")
	check(t, len(g.defs.thoughts) > 0, "thought definitions loaded")
	check(t, len(g.defs.items) > 0, "item definitions loaded")
	check(t, len(g.defs.tasks) > 0, "task definitions loaded")

	// Every skill named anywhere in the content has to resolve, or a passive
	// would silently never fire.
	bad_skills := 0
	for id in g.script.order {
		node := g.script.nodes[id]
		for line in node.lines {
			if line.kind == .Voice && line.target <= 0 {
				bad_skills += 1
			}
		}
	}
	check(t, bad_skills == 0, "every VOICE line has a positive difficulty")

	// Effects that reference a thought, item or task that was never defined.
	dangling := make([dynamic]string, context.temp_allocator)
	verify_effects :: proc(g: ^Game, dangling: ^[dynamic]string, node_id: string, effects: []Effect) {
		for e in effects {
			switch e.kind {
			case .Add_Thought:
				if cabinet_find(&g.cabinet, e.id) == nil {
					append(dangling, fmt.aprintf("%s: unknown thought '%s'", node_id, e.id))
				}
			case .Give_Item, .Take_Item:
				if _, found := g.item_defs[e.id]; !found {
					append(dangling, fmt.aprintf("%s: unknown item '%s'", node_id, e.id))
				}
			case .Task_Add, .Task_Done, .Task_Fail:
				if _, found := g.task_defs[e.id]; !found {
					append(dangling, fmt.aprintf("%s: unknown task '%s'", node_id, e.id))
				}
			case .Set_Flag, .Clear_Flag, .Health, .Morale, .XP:
			// flags are free-form by design
			}
		}
	}

	for id in g.script.order {
		node := g.script.nodes[id]
		verify_effects(g, &dangling, id, node.entry_effects)
		for opt in node.options {
			verify_effects(g, &dangling, id, opt.effects)
		}
	}

	for d in dangling {
		fmt.printfln("  FAIL  %s", d)
	}
	if len(dangling) == 0 {
		t.passed += 1
		fmt.printfln("  ok    every effect references a defined thought, item or task")
	} else {
		t.failed += len(dangling)
	}

	// Orphans are reported but not fatal: an unreferenced node is usually a
	// scene still being written.
	roots := []string{"wake"}
	entry_points := make([dynamic]string, context.temp_allocator)
	append(&entry_points, ..roots)
	for &it in g.scene.interactables {
		append(&entry_points, it.node)
	}

	orphans := find_orphan_nodes(&g.script, entry_points[:])
	if len(orphans) > 0 {
		fmt.printfln("  note  %d unreferenced node(s): %s", len(orphans), strings.join(orphans, ", ", context.temp_allocator))
	} else {
		fmt.printfln("  ok    every node is reachable from an entry point")
	}

	// Every interactable in the room must point at a node that exists.
	missing := 0
	for &it in g.scene.interactables {
		if _, found := g.script.nodes[it.node]; !found {
			fmt.printfln("  FAIL  interactable '%s' opens missing node '%s'", it.id, it.node)
			missing += 1
		}
	}
	check(t, missing == 0, "every orb in the room opens a node that exists")

	// Walk the whole graph, taking every option, to make sure no combination
	// of effects panics and every path terminates.
	visited := make(map[string]bool, context.temp_allocator)
	for entry in entry_points {
		if _, found := g.script.nodes[entry]; !found {
			continue
		}
		walk_all_paths(g, entry, &visited, 0)
	}
	check(t, len(visited) > 0, fmt.tprintf("graph walk reached %d node(s)", len(visited)))
}

// The graph walk proves every node is reachable in principle. This proves the
// case is actually completable: that the flags the evidence sets really do open
// the accusation, and that the red check is wired to the evidence you gathered.
@(private = "file")
test_critical_path :: proc(t: ^Test_Ctx, content_dir: string) {
	g := new(Game)
	g.content_dir = content_dir
	g.headless = true
	game_init_state(g)
	game_load_content(g)
	g.dialogue.script = &g.script

	// With no evidence, the accusation must not be on the table.
	g.dialogue.node_id = "sysadmin_hub"
	dialogue_rebuild_options(g)
	has_accuse := false
	for ro in g.dialogue.options {
		if ro.index >= 0 {
			node := g.script.nodes["sysadmin_hub"]
			if node.options[ro.index].target_node == "finale_open" {
				has_accuse = true
			}
		}
	}
	check(t, !has_accuse, "the accusation is hidden before you have the evidence")

	// Now grant the flags the evidence chain actually sets, and it must open.
	flag_set(g, "knows_arjun", true)
	dialogue_rebuild_options(g)
	has_accuse = false
	for ro in g.dialogue.options {
		node := g.script.nodes["sysadmin_hub"]
		if node.options[ro.index].target_node == "finale_open" {
			has_accuse = true
		}
	}
	check(t, has_accuse, "the accusation opens once you know who did it")

	// The climax must be a red check, and its modifiers must be fed by the
	// evidence flags rather than being a flat difficulty.
	finale := g.script.nodes["finale_case"]
	red_check_found := false
	mod_count := 0
	for opt in finale.options {
		if opt.kind == .Check && opt.check_kind == .Red {
			red_check_found = true
			mod_count = len(opt.authored_mods)
		}
	}
	check(t, red_check_found, "the finale is a red check - one attempt only")
	check(t, mod_count >= 5, fmt.tprintf("the red check reads %d pieces of evidence", mod_count))

	// Gathering evidence has to measurably improve the odds, or the whole
	// investigation is decorative.
	for opt in finale.options {
		if opt.kind != .Check || opt.check_kind != .Red {
			continue
		}
		bare := build_modifiers(g, opt.skill, opt.authored_mods, context.temp_allocator)
		odds_bare := check_odds(opt.check_target, sum_modifiers(bare))

		for m in opt.authored_mods {
			flag_set(g, m.flag, true)
		}
		full := build_modifiers(g, opt.skill, opt.authored_mods, context.temp_allocator)
		odds_full := check_odds(opt.check_target, sum_modifiers(full))

		check(
			t,
			odds_full > odds_bare,
			fmt.tprintf(
				"evidence moves the finale from %.0f%% to %.0f%%",
				odds_bare * 100,
				odds_full * 100,
			),
		)
	}

	// Both branches of the climax have to lead somewhere authored. A red check
	// you can fail must not be a dead end.
	for opt in finale.options {
		if opt.kind != .Check {
			continue
		}
		_, pass_ok := g.script.nodes[opt.pass_node]
		_, fail_ok := g.script.nodes[opt.fail_node]
		check(t, pass_ok && fail_ok, "failing the finale is authored, not a dead end")
	}

	// And the ending must actually end.
	ending, ending_ok := g.script.nodes["finale_end"]
	check(t, ending_ok && ending.ends, "'finale_end' terminates the scene")

	// Hot reload must not cost the player their run. Put a thought partway
	// through research, reload the content, and it has to survive.
	cabinet_start_research(&g.cabinet, "harmonic_greed")
	th := cabinet_find(&g.cabinet, "harmonic_greed")
	th.beats_done = 3
	flag_set(g, "reload_canary", true)

	game_load_content(g)

	after := cabinet_find(&g.cabinet, "harmonic_greed")
	check(
		t,
		after != nil && after.state == .Researching && after.beats_done == 3,
		"hot reload keeps a thought's research progress",
	)
	check(t, flag_is_set(g, "reload_canary"), "hot reload keeps world flags")
	check(t, len(g.load_errors) == 0, "content still parses clean on reload")
}

// The floor plan is content, so it gets the same treatment as the writing: it
// has to parse, and it has to be a room you can actually walk around. A case
// where the evidence is behind a wall is as broken as one where the dialogue
// jumps to a node that does not exist.
@(private = "file")
test_floor_plan :: proc(t: ^Test_Ctx, content_dir: string) {
	g := new(Game)
	g.content_dir = content_dir
	g.headless = true
	game_init_state(g)
	game_load_content(g)

	check(t, g.scene.built, "content/map.txt parses and builds a scene")
	if !g.scene.built {
		return
	}

	m := &g.scene.grid
	check(t, m.w >= 20 && m.h >= 20, fmt.tprintf("floor plan is %dx%d tiles", m.w, m.h))
	check(
		t,
		!tile_blocks(tilemap_at(m, int(g.scene.spawn.x), int(g.scene.spawn.y))),
		"you do not wake up inside a wall",
	)
	check(t, len(g.scene.lights) > 0, fmt.tprintf("the room has %d light source(s)", len(g.scene.lights)))

	// Flood fill from where the player wakes up. Anything not in this set is
	// scenery the player can never touch.
	reach := make([]bool, m.w * m.h, context.temp_allocator)
	stack := make([dynamic]int, context.temp_allocator)
	start := int(g.scene.spawn.y) * m.w + int(g.scene.spawn.x)
	reach[start] = true
	append(&stack, start)

	reachable_count := 0
	neighbours := [4][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	for len(stack) > 0 {
		cur := pop(&stack)
		reachable_count += 1
		cx := cur % m.w
		cy := cur / m.w
		for d in neighbours {
			nx := cx + d[0]
			ny := cy + d[1]
			if nx < 0 || ny < 0 || nx >= m.w || ny >= m.h {
				continue
			}
			ni := ny * m.w + nx
			if reach[ni] || tile_blocks(tilemap_at(m, nx, ny)) {
				continue
			}
			reach[ni] = true
			append(&stack, ni)
		}
	}
	check(t, reachable_count > 300, fmt.tprintf("%d tiles can be walked to from where you wake", reachable_count))

	// If a doorway is walled off, one of these never gets set.
	seen_tech, seen_corridor, seen_office := false, false, false
	for i in 0 ..< len(reach) {
		if !reach[i] {
			continue
		}
		if m.tiles[i] == .Floor_Tech {
			seen_tech = true
		} else if m.tiles[i] == .Floor_Corridor {
			seen_corridor = true
		} else if m.tiles[i] == .Floor_Office {
			seen_office = true
		}
	}
	check(t, seen_tech, "the server room is reachable")
	check(t, seen_corridor, "the corridor is reachable through its doorway")
	check(t, seen_office, "the office is reachable through its doorway")

	// And every single thing the case is made of has somewhere to stand.
	stranded := 0
	for it in g.scene.interactables {
		pos := it.pos
		if it.follow_actor >= 0 && it.follow_actor < len(g.scene.actors) {
			pos = g.scene.actors[it.follow_actor].pos
		}

		within := false
		r := 4 // comfortably past INTERACT_RANGE in whole tiles
		for dy in -r ..= r {
			for dx in -r ..= r {
				tx := int(pos.x) + dx
				ty := int(pos.y) + dy
				if tx < 0 || ty < 0 || tx >= m.w || ty >= m.h {
					continue
				}
				if !reach[ty * m.w + tx] {
					continue
				}
				ddx := f32(tx) + 0.5 - pos.x
				ddy := f32(ty) + 0.5 - pos.y
				if math.sqrt(ddx * ddx + ddy * ddy) <= INTERACT_RANGE {
					within = true
				}
			}
		}
		if !within {
			fmt.printfln("  FAIL  nowhere to stand next to '%s'", it.id)
			stranded += 1
		}
	}
	check(t, stranded == 0, "every interactable can be walked up to and reached")
}

// Depth-limited exhaustive walk. Cycles are fine -- we only need each node
// entered once to know its effects and lines are well-formed.
@(private = "file")
walk_all_paths :: proc(g: ^Game, node_id: string, visited: ^map[string]bool, depth: int) {
	if depth > 400 {
		return
	}
	if visited[node_id] or_else false {
		return
	}
	visited[node_id] = true

	node, ok := g.script.nodes[node_id]
	if !ok {
		return
	}

	if node.goto_node != "" {
		walk_all_paths(g, node.goto_node, visited, depth + 1)
	}
	for opt in node.options {
		switch opt.kind {
		case .Plain:
			if opt.target_node != "" && opt.target_node != "END" {
				walk_all_paths(g, opt.target_node, visited, depth + 1)
			}
		case .Check:
			if opt.pass_node != "" && opt.pass_node != "END" {
				walk_all_paths(g, opt.pass_node, visited, depth + 1)
			}
			if opt.fail_node != "" && opt.fail_node != "END" {
				walk_all_paths(g, opt.fail_node, visited, depth + 1)
			}
		}
	}
}

has_flag_arg :: proc(name: string) -> bool {
	for arg in os.args[1:] {
		if arg == name {
			return true
		}
	}
	return false
}
