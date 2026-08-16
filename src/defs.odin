package game

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// ---------------------------------------------------------------------------
// content/*.defs -- thoughts, items and tasks.
//
//   :: thought cold_logic
//   NAME       Cold Logic
//   PREMISE    Feelings are noise on the wire...
//   CONCLUSION You stopped guessing and started measuring.
//   BEATS      6
//   RESEARCH   Empathy -1
//   BONUS      Logic +2
//
//   :: item badge
//   NAME   Cracked ID Badge
//   DESC   Somebody's access card, snapped across the chip.
//   EQUIP  yes
//   MOD    Authority +1
//
//   :: task find_intruder
//   TITLE  Find who submitted the final flag
//   DETAIL The account was never registered...
//
// Same line-oriented shape as .plot, so a writer only learns one syntax.
// ---------------------------------------------------------------------------

Defs :: struct {
	thoughts: [dynamic]Thought,
	items:    map[string]Item,
	tasks:    map[string]Task,
}

defs_init :: proc(d: ^Defs) {
	d.thoughts = make([dynamic]Thought)
	d.items = make(map[string]Item)
	d.tasks = make(map[string]Task)
}

load_defs :: proc(dir: string) -> (Defs, []Parse_Error) {
	defs: Defs
	defs_init(&defs)
	errors := make([dynamic]Parse_Error)

	files := list_files_with_suffix(dir, ".defs")
	defer delete(files)

	for path in files {
		data, err := os.read_entire_file_from_path(path, context.allocator)
		if err != nil {
			append(&errors, Parse_Error{path, 0, "could not read file"})
			continue
		}
		defer delete(data)
		parse_defs(&defs, &errors, path, string(data))
	}

	return defs, errors[:]
}

@(private = "file")
Def_Kind :: enum {
	None,
	Thought,
	Item,
	Task,
}

parse_defs :: proc(
	defs: ^Defs,
	errors: ^[dynamic]Parse_Error,
	path: string,
	src: string,
) {
	kind := Def_Kind.None
	id := ""

	thought: Thought
	research := make([dynamic]Skill_Modifier)
	bonus := make([dynamic]Skill_Modifier)

	item: Item
	item_mods := make([dynamic]Skill_Modifier)

	task: Task

	flush :: proc(
		defs: ^Defs,
		kind: Def_Kind,
		thought: ^Thought,
		research, bonus: ^[dynamic]Skill_Modifier,
		item: ^Item,
		item_mods: ^[dynamic]Skill_Modifier,
		task: ^Task,
	) {
		switch kind {
		case .Thought:
			thought.research_modifiers = research^[:]
			thought.bonus_modifiers = bonus^[:]
			if thought.beats_required <= 0 {
				thought.beats_required = 5
			}
			append(&defs.thoughts, thought^)
		case .Item:
			item.modifiers = item_mods^[:]
			defs.items[item.id] = item^
		case .Task:
			defs.tasks[task.id] = task^
		case .None:
		}
	}

	line_no := 0
	it := src
	for raw in strings.split_lines_iterator(&it) {
		line_no += 1
		line := strings.trim_space(raw)
		if len(line) == 0 || strings.has_prefix(line, "#") {
			continue
		}

		if strings.has_prefix(line, "::") {
			flush(defs, kind, &thought, &research, &bonus, &item, &item_mods, &task)

			header := strings.fields(strings.trim_space(line[2:]))
			if len(header) < 2 {
				append(errors, Parse_Error{path, line_no, "':: <kind> <id>' expected"})
				kind = .None
				continue
			}
			id = strings.clone(header[1])
			switch strings.to_lower(header[0], context.temp_allocator) {
			case "thought":
				kind = .Thought
				thought = Thought{id = id, name = id, state = .Unknown}
				research = make([dynamic]Skill_Modifier)
				bonus = make([dynamic]Skill_Modifier)
			case "item":
				kind = .Item
				item = Item{id = id, name = id}
				item_mods = make([dynamic]Skill_Modifier)
			case "task":
				kind = .Task
				task = Task{id = id, title = id, state = .Active}
			case:
				append(
					errors,
					Parse_Error{path, line_no, fmt.aprintf("unknown def kind '%s'", header[0])},
				)
				kind = .None
			}
			continue
		}

		if kind == .None {
			append(errors, Parse_Error{path, line_no, "field before any '::' header"})
			continue
		}

		key, rest := split_defs_keyword(line)

		switch kind {
		case .Thought:
			switch key {
			case "NAME":
				thought.name = strings.clone(rest)
			case "PREMISE":
				thought.premise = append_paragraph(thought.premise, rest)
			case "CONCLUSION":
				thought.conclusion = append_paragraph(thought.conclusion, rest)
			case "BEATS":
				if n, ok := strconv.parse_int(rest); ok {
					thought.beats_required = n
				} else {
					append(errors, Parse_Error{path, line_no, "BEATS needs a number"})
				}
			case "RESEARCH":
				if m, ok := parse_skill_modifier(rest); ok {
					append(&research, m)
				} else {
					append(errors, Parse_Error{path, line_no, "RESEARCH needs '<Skill> <±n>'"})
				}
			case "BONUS":
				if m, ok := parse_skill_modifier(rest); ok {
					append(&bonus, m)
				} else {
					append(errors, Parse_Error{path, line_no, "BONUS needs '<Skill> <±n>'"})
				}
			case:
				append(
					errors,
					Parse_Error{path, line_no, fmt.aprintf("thought has no field '%s'", key)},
				)
			}
		case .Item:
			switch key {
			case "NAME":
				item.name = strings.clone(rest)
			case "DESC":
				item.description = append_paragraph(item.description, rest)
			case "EQUIP":
				lowered := strings.to_lower(rest, context.temp_allocator)
				item.equippable = lowered == "yes" || lowered == "true"
			case "MOD":
				if m, ok := parse_skill_modifier(rest); ok {
					append(&item_mods, m)
				} else {
					append(errors, Parse_Error{path, line_no, "MOD needs '<Skill> <±n>'"})
				}
			case:
				append(
					errors,
					Parse_Error{path, line_no, fmt.aprintf("item has no field '%s'", key)},
				)
			}
		case .Task:
			switch key {
			case "TITLE":
				task.title = strings.clone(rest)
			case "DETAIL":
				task.detail = append_paragraph(task.detail, rest)
			case:
				append(
					errors,
					Parse_Error{path, line_no, fmt.aprintf("task has no field '%s'", key)},
				)
			}
		case .None:
		}
	}

	flush(defs, kind, &thought, &research, &bonus, &item, &item_mods, &task)
}

@(private = "file")
split_defs_keyword :: proc(line: string) -> (key, rest: string) {
	i := 0
	for i < len(line) && line[i] != ' ' && line[i] != '\t' {
		i += 1
	}
	return line[:i], strings.trim_space(line[i:])
}

// Repeated PREMISE/DESC/DETAIL lines accumulate into one paragraph, so long
// prose can be wrapped in the source file without escaping anything.
@(private = "file")
append_paragraph :: proc(existing, addition: string) -> string {
	if existing == "" {
		return strings.clone(addition)
	}
	return fmt.aprintf("%s %s", existing, addition)
}

// "Logic +2" / "Empathy -1" / "Visual Calculus +1"
parse_skill_modifier :: proc(s: string) -> (Skill_Modifier, bool) {
	toks := strings.fields(s)
	if len(toks) < 2 {
		return {}, false
	}
	value, ok := strconv.parse_int(toks[len(toks) - 1])
	if !ok {
		return {}, false
	}
	name := strings.join(toks[:len(toks) - 1], " ", context.temp_allocator)
	skill, sok := skill_from_name(name)
	if !sok {
		return {}, false
	}
	return Skill_Modifier{skill = skill, value = value}, true
}
