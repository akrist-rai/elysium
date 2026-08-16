package game

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// Saves are plain text, one record per line. A run is small -- some flags, some
// dice already thrown -- and a readable save file is worth more during
// development than a compact one.

SAVE_VERSION :: 1

save_path :: proc(g: ^Game) -> string {
	return fmt.tprintf("%s/../save.hacktheplot", g.content_dir)
}

save_game :: proc(g: ^Game) -> bool {
	b := strings.builder_make(context.temp_allocator)

	fmt.sbprintfln(&b, "version %d", SAVE_VERSION)
	fmt.sbprintfln(
		&b,
		"attr %d %d %d %d",
		g.player.attributes[.Intellect],
		g.player.attributes[.Psyche],
		g.player.attributes[.Physique],
		g.player.attributes[.Motorics],
	)
	fmt.sbprintfln(
		&b,
		"vitals %d %d %d %d %d",
		g.player.health,
		g.player.morale,
		g.player.xp,
		g.player.level,
		g.pending_level_ups,
	)
	fmt.sbprintfln(&b, "pos %f %f", g.player_ent.pos.x, g.player_ent.pos.y)

	for info, s in skill_info {
		if g.player.skill_points[s] != 0 {
			fmt.sbprintfln(&b, "skill %d %d", int(s), g.player.skill_points[s])
		}
		_ = info
	}

	for flag, value in g.flags {
		if value {
			fmt.sbprintfln(&b, "flag %s", flag)
		}
	}
	for key, value in g.taken_options {
		if value {
			fmt.sbprintfln(&b, "taken %s", key)
		}
	}
	for key, value in g.passive_results {
		fmt.sbprintfln(&b, "passive %s %d", key, value ? 1 : 0)
	}
	for key, rec in g.check_records {
		fmt.sbprintfln(
			&b,
			"check %d %d %d %s",
			rec.passed ? 1 : 0,
			rec.bonus_when_attempted,
			int(rec.kind),
			key,
		)
	}
	for &t in g.cabinet.thoughts {
		if t.state != .Unknown {
			fmt.sbprintfln(&b, "thought %s %d %d", t.id, int(t.state), t.beats_done)
		}
	}
	for &t in g.journal.tasks {
		fmt.sbprintfln(&b, "task %s %d", t.id, int(t.state))
	}
	for &it in g.inventory.items {
		fmt.sbprintfln(&b, "item %s %d", it.id, it.equipped ? 1 : 0)
	}

	return os.write_entire_file(save_path(g), strings.to_string(b)) == nil
}

load_game :: proc(g: ^Game) -> bool {
	data, err := os.read_entire_file_from_path(save_path(g), context.allocator)
	if err != nil {
		return false
	}
	defer delete(data)

	// Start from a clean run so a load never inherits the current one.
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

	it_src := string(data)
	for line in strings.split_lines_iterator(&it_src) {
		fields := strings.fields(strings.trim_space(line), context.temp_allocator)
		if len(fields) == 0 {
			continue
		}

		switch fields[0] {
		case "attr":
			if len(fields) >= 5 {
				g.player.attributes[.Intellect] = atoi(fields[1])
				g.player.attributes[.Psyche] = atoi(fields[2])
				g.player.attributes[.Physique] = atoi(fields[3])
				g.player.attributes[.Motorics] = atoi(fields[4])
			}
		case "vitals":
			if len(fields) >= 6 {
				g.player.health = atoi(fields[1])
				g.player.morale = atoi(fields[2])
				g.player.xp = atoi(fields[3])
				g.player.level = atoi(fields[4])
				g.pending_level_ups = atoi(fields[5])
			}
		case "pos":
			if len(fields) >= 3 {
				g.player_ent.pos.x = f32(atof(fields[1]))
				g.player_ent.pos.y = f32(atof(fields[2]))
			}
		case "skill":
			if len(fields) >= 3 {
				idx := atoi(fields[1])
				if idx >= 0 && idx <= int(max(Skill)) {
					g.player.skill_points[Skill(idx)] = atoi(fields[2])
				}
			}
		case "flag":
			if len(fields) >= 2 {
				g.flags[strings.clone(fields[1])] = true
			}
		case "taken":
			if len(fields) >= 2 {
				g.taken_options[strings.clone(fields[1])] = true
			}
		case "passive":
			if len(fields) >= 3 {
				g.passive_results[strings.clone(fields[1])] = fields[2] == "1"
			}
		case "check":
			// The key is last because it can contain spaces.
			if len(fields) >= 5 {
				key := strings.join(fields[4:], " ")
				g.check_records[key] = Check_Record {
					attempted            = true,
					passed               = fields[1] == "1",
					bonus_when_attempted = atoi(fields[2]),
					kind                 = Check_Kind(atoi(fields[3])),
				}
			}
		case "thought":
			if len(fields) >= 4 {
				if t := cabinet_find(&g.cabinet, fields[1]); t != nil {
					t.state = Thought_State(atoi(fields[2]))
					t.beats_done = atoi(fields[3])
				}
			}
		case "task":
			if len(fields) >= 3 {
				if def, found := g.task_defs[fields[1]]; found {
					task := def
					task.state = Task_State(atoi(fields[2]))
					append(&g.journal.tasks, task)
				}
			}
		case "item":
			if len(fields) >= 3 {
				if def, found := g.item_defs[fields[1]]; found {
					item := def
					item.equipped = fields[2] == "1"
					append(&g.inventory.items, item)
				}
			}
		}
	}

	return true
}

save_exists :: proc(g: ^Game) -> bool {
	return os.exists(save_path(g))
}

@(private = "file")
atoi :: proc(s: string) -> int {
	n, _ := strconv.parse_int(s)
	return n
}

@(private = "file")
atof :: proc(s: string) -> f64 {
	n, _ := strconv.parse_f64(s)
	return n
}
