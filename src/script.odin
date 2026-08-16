package game

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// ---------------------------------------------------------------------------
// The .plot format
//
//   :: node_id
//   SAY   Narrator | The desk is a mess of cable and cold coffee.
//   VOICE Shivers 12 | The room is four degrees colder than the corridor.
//   SET   saw_the_desk
//   OPT   - | "Say nothing." | silence | SET:stayed_quiet
//   OPT   Empathy 8 | "He isn't asleep." | not_asleep
//   CHECK Interfacing WHITE 10 +1:found_badge | "Unlock it." | open | locked
//   GOTO  another_node
//   END
//
// Fields are separated by '|'. Everything is line-oriented and order-preserving
// so a writer can read a scene top to bottom and know what happens.
// ---------------------------------------------------------------------------

Parse_Error :: struct {
	file: string,
	line: int,
	msg:  string,
}

Parse_Result :: struct {
	script: Scene_Script,
	errors: [dynamic]Parse_Error,
}

script_init :: proc(s: ^Scene_Script) {
	s.nodes = make(map[string]Node)
	s.order = make([dynamic]string)
}

// Loads every .plot file under `dir` into one script. Scenes share a namespace
// so a node in one file can jump into another.
load_scripts :: proc(dir: string) -> (Scene_Script, []Parse_Error) {
	res: Parse_Result
	script_init(&res.script)
	res.errors = make([dynamic]Parse_Error)

	files := list_files_with_suffix(dir, ".plot")
	defer delete(files)

	for path in files {
		data, err := os.read_entire_file_from_path(path, context.allocator)
		if err != nil {
			append(&res.errors, Parse_Error{path, 0, "could not read file"})
			continue
		}
		defer delete(data)
		parse_plot(&res, path, string(data))
	}

	return res.script, res.errors[:]
}

// Flat listing of one directory. Scenes and defs both live in a single folder
// each, so there is nothing to recurse into.
list_files_with_suffix :: proc(dir, suffix: string) -> [dynamic]string {
	out := make([dynamic]string)

	infos, err := os.read_all_directory_by_path(dir, context.temp_allocator)
	if err != nil {
		return out
	}

	for info in infos {
		if info.type == .Directory {
			continue
		}
		if strings.has_suffix(info.name, suffix) {
			append(&out, strings.clone(info.fullpath))
		}
	}

	// Deterministic order keeps validation output stable across runs.
	slice_sort_strings(out[:])
	return out
}

slice_sort_strings :: proc(s: []string) {
	for i in 1 ..< len(s) {
		key := s[i]
		j := i - 1
		for j >= 0 && s[j] > key {
			s[j + 1] = s[j]
			j -= 1
		}
		s[j + 1] = key
	}
}

@(private = "file")
Node_Builder :: struct {
	node:    Node,
	lines:   [dynamic]Line,
	options: [dynamic]Option,
	entry:   [dynamic]Effect,
	open:    bool,
}

parse_plot :: proc(res: ^Parse_Result, path: string, src: string) {
	b: Node_Builder

	flush :: proc(res: ^Parse_Result, b: ^Node_Builder) {
		if !b.open {
			return
		}
		b.node.lines = b.lines[:]
		b.node.options = b.options[:]
		b.node.entry_effects = b.entry[:]

		if _, exists := res.script.nodes[b.node.id]; exists {
			append(
				&res.errors,
				Parse_Error {
					b.node.source,
					b.node.line_no,
					fmt.aprintf("duplicate node id '%s'", b.node.id),
				},
			)
		} else {
			append(&res.script.order, b.node.id)
		}
		res.script.nodes[b.node.id] = b.node
		b.open = false
	}

	line_no := 0
	it := src
	for raw_line in strings.split_lines_iterator(&it) {
		line_no += 1
		line := strings.trim_space(raw_line)

		if len(line) == 0 || strings.has_prefix(line, "#") {
			continue
		}

		if strings.has_prefix(line, "::") {
			flush(res, &b)
			id := strings.trim_space(line[2:])
			if id == "" {
				append(&res.errors, Parse_Error{path, line_no, "node has no id"})
				continue
			}
			b = Node_Builder {
				node = Node{id = strings.clone(id), source = path, line_no = line_no},
				lines = make([dynamic]Line),
				options = make([dynamic]Option),
				entry = make([dynamic]Effect),
				open = true,
			}
			continue
		}

		if !b.open {
			append(
				&res.errors,
				Parse_Error{path, line_no, "directive before any '::' node header"},
			)
			continue
		}

		keyword, rest := split_keyword(line)

		switch keyword {
		case "SAY":
			parse_say(res, &b, path, line_no, rest)
		case "VOICE":
			parse_voice(res, &b, path, line_no, rest)
		case "OPT":
			parse_opt(res, &b, path, line_no, rest)
		case "CHECK":
			parse_check(res, &b, path, line_no, rest)
		case "SET":
			append(&b.entry, Effect{kind = .Set_Flag, id = strings.clone(strings.trim_space(rest))})
		case "CLEAR":
			append(
				&b.entry,
				Effect{kind = .Clear_Flag, id = strings.clone(strings.trim_space(rest))},
			)
		case "DO":
			// Node-entry effects in the same token form options use.
			for tok in strings.fields(rest) {
				if e, ok := parse_effect_token(tok); ok {
					append(&b.entry, e)
				} else {
					append(
						&res.errors,
						Parse_Error{path, line_no, fmt.aprintf("unknown effect '%s'", tok)},
					)
				}
			}
		case "GOTO":
			b.node.goto_node = strings.clone(strings.trim_space(rest))
		case "END":
			b.node.ends = true
		case:
			append(
				&res.errors,
				Parse_Error{path, line_no, fmt.aprintf("unknown directive '%s'", keyword)},
			)
		}
	}

	flush(res, &b)
}

@(private = "file")
split_keyword :: proc(line: string) -> (keyword, rest: string) {
	i := 0
	for i < len(line) && line[i] != ' ' && line[i] != '\t' {
		i += 1
	}
	return line[:i], strings.trim_space(line[i:])
}

// Splits on '|' and trims each field.
@(private = "file")
split_fields :: proc(s: string) -> []string {
	parts := strings.split(s, "|")
	for &p in parts {
		p = strings.trim_space(p)
	}
	return parts
}

@(private = "file")
parse_say :: proc(res: ^Parse_Result, b: ^Node_Builder, path: string, ln: int, rest: string) {
	f := split_fields(rest)
	if len(f) < 2 {
		append(&res.errors, Parse_Error{path, ln, "SAY needs 'speaker | text'"})
		return
	}
	append(
		&b.lines,
		Line{kind = .Say, speaker = strings.clone(f[0]), text = strings.clone(f[1])},
	)
}

@(private = "file")
parse_voice :: proc(res: ^Parse_Result, b: ^Node_Builder, path: string, ln: int, rest: string) {
	f := split_fields(rest)
	if len(f) < 2 {
		append(&res.errors, Parse_Error{path, ln, "VOICE needs 'Skill difficulty | text'"})
		return
	}
	toks := strings.fields(f[0])
	if len(toks) < 2 {
		append(&res.errors, Parse_Error{path, ln, "VOICE needs a skill and a difficulty"})
		return
	}
	target, tok := strconv.parse_int(toks[len(toks) - 1])
	if !tok {
		append(
			&res.errors,
			Parse_Error{path, ln, fmt.aprintf("'%s' is not a difficulty", toks[len(toks) - 1])},
		)
		return
	}
	skill_name := strings.join(toks[:len(toks) - 1], " ", context.temp_allocator)
	skill, sok := skill_from_name(skill_name)
	if !sok {
		append(&res.errors, Parse_Error{path, ln, fmt.aprintf("unknown skill '%s'", skill_name)})
		return
	}
	append(
		&b.lines,
		Line{kind = .Voice, skill = skill, target = target, text = strings.clone(f[1])},
	)
}

// OPT <gate> | <text> | <target node> [| <effects>]
@(private = "file")
parse_opt :: proc(res: ^Parse_Result, b: ^Node_Builder, path: string, ln: int, rest: string) {
	f := split_fields(rest)
	if len(f) < 3 {
		append(&res.errors, Parse_Error{path, ln, "OPT needs 'gate | text | target'"})
		return
	}

	opt := Option {
		kind        = .Plain,
		text        = strings.clone(f[1]),
		target_node = strings.clone(f[2]),
	}

	conds, cerr := parse_gate(f[0])
	if cerr != "" {
		append(&res.errors, Parse_Error{path, ln, cerr})
		return
	}
	opt.conditions = conds

	if len(f) >= 4 && f[3] != "" {
		effs := make([dynamic]Effect)
		for tok in strings.fields(f[3]) {
			if e, ok := parse_effect_token(tok); ok {
				append(&effs, e)
			} else {
				append(&res.errors, Parse_Error{path, ln, fmt.aprintf("unknown effect '%s'", tok)})
			}
		}
		opt.effects = effs[:]
	}

	append(&b.options, opt)
}

// CHECK <Skill> <WHITE|RED> <target> [mods] | <text> | <pass> | <fail> [| <effects>]
@(private = "file")
parse_check :: proc(res: ^Parse_Result, b: ^Node_Builder, path: string, ln: int, rest: string) {
	f := split_fields(rest)
	if len(f) < 4 {
		append(
			&res.errors,
			Parse_Error{path, ln, "CHECK needs 'skill kind target | text | pass | fail'"},
		)
		return
	}

	toks := strings.fields(f[0])
	if len(toks) < 3 {
		append(&res.errors, Parse_Error{path, ln, "CHECK needs a skill, WHITE/RED and a target"})
		return
	}

	// Trailing +N:flag / -N:flag tokens are authored modifiers; peel them off
	// the right so the skill name can still contain spaces.
	mods := make([dynamic]Authored_Modifier)
	end := len(toks)
	for end > 0 {
		t := toks[end - 1]
		if len(t) > 0 && (t[0] == '+' || t[0] == '-') && strings.contains(t, ":") {
			if m, ok := parse_authored_modifier(t); ok {
				inject_at(&mods, 0, m)
				end -= 1
				continue
			}
		}
		break
	}
	toks = toks[:end]

	if len(toks) < 3 {
		append(&res.errors, Parse_Error{path, ln, "CHECK needs a skill, WHITE/RED and a target"})
		return
	}

	target, tok := strconv.parse_int(toks[len(toks) - 1])
	if !tok {
		append(
			&res.errors,
			Parse_Error{path, ln, fmt.aprintf("'%s' is not a difficulty", toks[len(toks) - 1])},
		)
		return
	}

	kind_str := strings.to_upper(toks[len(toks) - 2], context.temp_allocator)
	kind: Check_Kind
	switch kind_str {
	case "WHITE":
		kind = .White
	case "RED":
		kind = .Red
	case:
		append(&res.errors, Parse_Error{path, ln, "check kind must be WHITE or RED"})
		return
	}

	skill_name := strings.join(toks[:len(toks) - 2], " ", context.temp_allocator)
	skill, sok := skill_from_name(skill_name)
	if !sok {
		append(&res.errors, Parse_Error{path, ln, fmt.aprintf("unknown skill '%s'", skill_name)})
		return
	}

	opt := Option {
		kind          = .Check,
		text          = strings.clone(f[1]),
		skill         = skill,
		check_kind    = kind,
		check_target  = target,
		authored_mods = mods[:],
		pass_node     = strings.clone(f[2]),
		fail_node     = strings.clone(f[3]),
		// Stable across reloads as long as the writer does not renumber a node's
		// checks, which is what we want: edit the prose, keep the outcome.
		check_id      = fmt.aprintf("%s::%s@%d", b.node.id, skill_info[skill].name, target),
	}

	if len(f) >= 5 && f[4] != "" {
		effs := make([dynamic]Effect)
		for t in strings.fields(f[4]) {
			if e, ok := parse_effect_token(t); ok {
				append(&effs, e)
			} else {
				append(&res.errors, Parse_Error{path, ln, fmt.aprintf("unknown effect '%s'", t)})
			}
		}
		opt.effects = effs[:]
	}

	append(&b.options, opt)
}

inject_at :: proc(arr: ^[dynamic]Authored_Modifier, idx: int, v: Authored_Modifier) {
	append(arr, v)
	for i := len(arr) - 1; i > idx; i -= 1 {
		arr[i], arr[i - 1] = arr[i - 1], arr[i]
	}
}

// "+1:found_badge" / "-2:concussed"
parse_authored_modifier :: proc(tok: string) -> (Authored_Modifier, bool) {
	colon := strings.index_byte(tok, ':')
	if colon < 0 {
		return {}, false
	}
	value, ok := strconv.parse_int(tok[:colon])
	if !ok {
		return {}, false
	}
	flag := tok[colon + 1:]
	if flag == "" {
		return {}, false
	}
	return Authored_Modifier {
			value = value,
			flag = strings.clone(flag),
			label = humanize_flag(flag),
		},
		true
}

// Gate field: "-" for none, otherwise a mix of "<Skill> <n>" and IF:/NOT:/
// ITEM:/THOUGHT:/ONCE tokens.
parse_gate :: proc(field: string) -> ([]Condition, string) {
	conds := make([dynamic]Condition)
	if field == "" || field == "-" {
		return conds[:], ""
	}

	skill_words := make([dynamic]string, context.temp_allocator)

	for tok in strings.fields(field) {
		switch {
		case strings.has_prefix(tok, "IF:"):
			append(&conds, Condition{kind = .Flag_Set, id = strings.clone(tok[3:])})
		case strings.has_prefix(tok, "NOT:"):
			append(&conds, Condition{kind = .Flag_Not_Set, id = strings.clone(tok[4:])})
		case strings.has_prefix(tok, "ITEM:"):
			append(&conds, Condition{kind = .Has_Item, id = strings.clone(tok[5:])})
		case strings.has_prefix(tok, "THOUGHT:"):
			append(&conds, Condition{kind = .Thought_Internalized, id = strings.clone(tok[8:])})
		case tok == "ONCE":
			append(&conds, Condition{kind = .Once})
		case:
			append(&skill_words, tok)
		}
	}

	if len(skill_words) > 0 {
		if len(skill_words) < 2 {
			return conds[:], fmt.aprintf("gate '%s' needs a skill and a value", field)
		}
		value, ok := strconv.parse_int(skill_words[len(skill_words) - 1])
		if !ok {
			return conds[:], fmt.aprintf("'%s' is not a skill value", skill_words[len(skill_words) - 1])
		}
		name := strings.join(skill_words[:len(skill_words) - 1], " ", context.temp_allocator)
		skill, sok := skill_from_name(name)
		if !sok {
			return conds[:], fmt.aprintf("unknown skill '%s'", name)
		}
		append(&conds, Condition{kind = .Skill_At_Least, skill = skill, value = value})
	}

	return conds[:], ""
}

parse_effect_token :: proc(tok: string) -> (Effect, bool) {
	colon := strings.index_byte(tok, ':')
	if colon < 0 {
		return {}, false
	}
	key := strings.to_upper(tok[:colon], context.temp_allocator)
	val := tok[colon + 1:]

	num_effect :: proc(kind: Effect_Kind, val: string) -> (Effect, bool) {
		n, ok := strconv.parse_int(val)
		if !ok {
			return {}, false
		}
		return Effect{kind = kind, value = n}, true
	}

	switch key {
	case "SET":
		return Effect{kind = .Set_Flag, id = strings.clone(val)}, true
	case "CLEAR":
		return Effect{kind = .Clear_Flag, id = strings.clone(val)}, true
	case "HEALTH":
		return num_effect(.Health, val)
	case "MORALE":
		return num_effect(.Morale, val)
	case "XP":
		return num_effect(.XP, val)
	case "ITEM":
		return Effect{kind = .Give_Item, id = strings.clone(val)}, true
	case "TAKEITEM":
		return Effect{kind = .Take_Item, id = strings.clone(val)}, true
	case "THOUGHT":
		return Effect{kind = .Add_Thought, id = strings.clone(val)}, true
	case "TASK":
		return Effect{kind = .Task_Add, id = strings.clone(val)}, true
	case "TASKDONE":
		return Effect{kind = .Task_Done, id = strings.clone(val)}, true
	case "TASKFAIL":
		return Effect{kind = .Task_Fail, id = strings.clone(val)}, true
	}
	return {}, false
}

// ---------------------------------------------------------------------------
// Validation
//
// Every jump target has to exist. Broken writing should fail loudly in --test
// rather than dead-ending a player twenty minutes into a scene.
// ---------------------------------------------------------------------------

validate_script :: proc(s: ^Scene_Script) -> []Parse_Error {
	errors := make([dynamic]Parse_Error)

	check_target :: proc(
		s: ^Scene_Script,
		errors: ^[dynamic]Parse_Error,
		node: Node,
		target: string,
		what: string,
	) {
		if target == "" || target == "END" {
			return
		}
		if _, ok := s.nodes[target]; !ok {
			append(
				errors,
				Parse_Error {
					node.source,
					node.line_no,
					fmt.aprintf("%s of '%s' points at missing node '%s'", what, node.id, target),
				},
			)
		}
	}

	for id in s.order {
		node := s.nodes[id]

		check_target(s, &errors, node, node.goto_node, "GOTO")

		for opt in node.options {
			switch opt.kind {
			case .Plain:
				check_target(s, &errors, node, opt.target_node, "OPT")
			case .Check:
				check_target(s, &errors, node, opt.pass_node, "CHECK pass branch")
				check_target(s, &errors, node, opt.fail_node, "CHECK fail branch")
			}
		}

		// A node with nothing to do next is a dead end unless it says so.
		if len(node.options) == 0 && node.goto_node == "" && !node.ends {
			append(
				&errors,
				Parse_Error {
					node.source,
					node.line_no,
					fmt.aprintf("node '%s' has no options, no GOTO and no END", node.id),
				},
			)
		}
	}

	return errors[:]
}

// Nodes nothing ever jumps to. Reported separately because an unreferenced
// node is usually writing in progress, not a bug.
find_orphan_nodes :: proc(s: ^Scene_Script, roots: []string) -> []string {
	referenced := make(map[string]bool, context.temp_allocator)
	for r in roots {
		referenced[r] = true
	}
	for id in s.order {
		node := s.nodes[id]
		if node.goto_node != "" {
			referenced[node.goto_node] = true
		}
		for opt in node.options {
			switch opt.kind {
			case .Plain:
				referenced[opt.target_node] = true
			case .Check:
				referenced[opt.pass_node] = true
				referenced[opt.fail_node] = true
			}
		}
	}

	orphans := make([dynamic]string)
	for id in s.order {
		if !(referenced[id] or_else false) {
			append(&orphans, id)
		}
	}
	return orphans[:]
}
