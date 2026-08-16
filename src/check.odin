package game

import "core:fmt"
import "core:math/rand"
import "core:strings"

// White checks can be retried once something about you changes. Red checks
// resolve exactly once and you live inside the result.
Check_Kind :: enum u8 {
	White,
	Red,
}

Difficulty :: enum u8 {
	Trivial,
	Easy,
	Medium,
	Challenging,
	Formidable,
	Legendary,
	Heroic,
	Godly,
	Impossible,
}

difficulty_target := [Difficulty]int {
	.Trivial    = 6,
	.Easy       = 8,
	.Medium     = 10,
	.Challenging = 12,
	.Formidable = 14,
	.Legendary  = 16,
	.Heroic     = 18,
	.Godly      = 20,
	.Impossible = 22,
}

difficulty_name := [Difficulty]string {
	.Trivial    = "Trivial",
	.Easy       = "Easy",
	.Medium     = "Medium",
	.Challenging = "Challenging",
	.Formidable = "Formidable",
	.Legendary  = "Legendary",
	.Heroic     = "Heroic",
	.Godly      = "Godly",
	.Impossible = "Impossible",
}

// The label shown next to a numeric target, e.g. 12 -> "Challenging". Targets
// that fall between rungs round down to the rung below.
difficulty_for_target :: proc(target: int) -> Difficulty {
	result := Difficulty.Trivial
	for t, d in difficulty_target {
		if target >= t {
			result = d
		}
	}
	return result
}

// A resolved roll, kept whole so the UI can replay it: both dice, the itemised
// modifiers that fed it, and what it came to.
Check_Result :: struct {
	skill:     Skill,
	kind:      Check_Kind,
	die_a:     int,
	die_b:     int,
	target:    int,
	bonus:     int, // sum of all modifier values
	modifiers: []Modifier,
	passed:    bool,
	critical:  bool, // snake eyes or boxcars: the dice overruled the arithmetic
}

roll_total :: proc(r: Check_Result) -> int {
	return r.die_a + r.die_b + r.bonus
}

// Exact probability of passing, enumerated over all 36 outcomes rather than
// approximated. Double 1 always fails and double 6 always succeeds, so the
// curve is not simply P(sum >= target - bonus).
check_odds :: proc(target, bonus: int) -> f32 {
	favourable := 0
	for a in 1 ..= 6 {
		for b in 1 ..= 6 {
			if outcome_passes(a, b, target, bonus) {
				favourable += 1
			}
		}
	}
	return f32(favourable) / 36.0
}

outcome_passes :: proc(a, b, target, bonus: int) -> bool {
	if a == 1 && b == 1 {
		return false // snake eyes: nothing saves you
	}
	if a == 6 && b == 6 {
		return true // boxcars: nothing stops you
	}
	return a + b + bonus >= target
}

// Rolls the check. `modifiers` is retained in the result and must outlive it;
// callers pass a slice owned by the game state.
resolve_check :: proc(
	skill: Skill,
	kind: Check_Kind,
	target: int,
	modifiers: []Modifier,
) -> Check_Result {
	bonus := 0
	for m in modifiers {
		bonus += m.value
	}

	a := int(rand.int31_max(6)) + 1
	b := int(rand.int31_max(6)) + 1

	return Check_Result {
		skill = skill,
		kind = kind,
		die_a = a,
		die_b = b,
		target = target,
		bonus = bonus,
		modifiers = modifiers,
		passed = outcome_passes(a, b, target, bonus),
		critical = (a == 1 && b == 1) || (a == 6 && b == 6),
	}
}

// What the game remembers about a check it has already seen.
Check_Record :: struct {
	attempted:   bool,
	passed:      bool,
	bonus_when_attempted: int,
	kind:        Check_Kind,
}

// A white check reopens the moment anything in your favour changes -- a level,
// a thought, an item, a fact you dug up. A red check never reopens.
check_available :: proc(rec: Check_Record, current_bonus: int) -> bool {
	if !rec.attempted {
		return true
	}
	if rec.passed {
		return false
	}
	if rec.kind == .Red {
		return false
	}
	return current_bonus > rec.bonus_when_attempted
}

// "Interfacing - Medium 10" for the option prefix.
format_check_label :: proc(
	skill: Skill,
	target: int,
	allocator := context.allocator,
) -> string {
	d := difficulty_for_target(target)
	return fmt.aprintf(
		"%s - %s %d",
		skill_info[skill].name,
		difficulty_name[d],
		target,
		allocator = allocator,
	)
}

// The itemised breakdown the popup renders, one line per reason.
format_modifier_line :: proc(m: Modifier, allocator := context.allocator) -> string {
	sign := "+"
	v := m.value
	if v < 0 {
		sign = "-"
		v = -v
	}
	return fmt.aprintf("%s%d  %s", sign, v, m.label, allocator = allocator)
}

sum_modifiers :: proc(mods: []Modifier) -> int {
	total := 0
	for m in mods {
		total += m.value
	}
	return total
}

// Builds the full modifier list for a check: the skill itself, then every
// situational reason that applies. The skill line comes first because that is
// how the player reads it -- "Interfacing 4, and then the world's opinion".
build_modifiers :: proc(
	g: ^Game,
	skill: Skill,
	authored: []Authored_Modifier,
	allocator := context.allocator,
) -> []Modifier {
	mods := make([dynamic]Modifier, allocator)

	append(&mods, Modifier{skill_info[skill].name, skill_base(g.player, skill)})

	// Equipment that speaks to this skill.
	for item in g.inventory.items {
		if !item.equipped {
			continue
		}
		for m in item.modifiers {
			if m.skill == skill {
				append(&mods, Modifier{item.name, m.value})
			}
		}
	}

	// Thoughts, both the ones still cooking and the ones that finished.
	for &t in g.cabinet.thoughts {
		switch t.state {
		case .Researching:
			for m in t.research_modifiers {
				if m.skill == skill {
					append(
						&mods,
						Modifier{
							fmt.aprintf(
								"%s (researching)",
								t.name,
								allocator = allocator,
							),
							m.value,
						},
					)
				}
			}
		case .Internalized:
			for m in t.bonus_modifiers {
				if m.skill == skill {
					append(&mods, Modifier{t.name, m.value})
				}
			}
		case .Unknown:
		// not in the cabinet yet, contributes nothing
		}
	}

	// Modifiers the writer attached to this specific check, each conditional on
	// a world flag being set.
	for a in authored {
		if flag_is_set(g, a.flag) {
			append(&mods, Modifier{a.label, a.value})
		}
	}

	return mods[:]
}

// A modifier written into a .plot check, gated on a flag: +1:found_badge
Authored_Modifier :: struct {
	value: int,
	flag:  string,
	label: string,
}

// Turns "found_badge" into "you found the badge" for display, so authored
// modifiers read as prose without the writer having to spell both out.
humanize_flag :: proc(flag: string, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	for c in flag {
		if c == '_' {
			strings.write_rune(&b, ' ')
		} else {
			strings.write_rune(&b, c)
		}
	}
	return strings.to_string(b)
}
