package game

// A modifier attached to a thought or an item, aimed at one skill.
Skill_Modifier :: struct {
	skill: Skill,
	value: int,
}

Thought_State :: enum u8 {
	Unknown, // never encountered
	Researching, // in the cabinet, still turning over
	Internalized, // settled into you, for better or worse
}

// A thought is a position you are in the process of adopting. While you are
// working it out it costs you something; once you have adopted it, it pays.
// Some of them are bad ideas and pay badly. That is the point.
Thought :: struct {
	id:                   string,
	name:                 string,
	premise:              string, // shown while researching
	conclusion:           string, // shown once internalized
	state:                Thought_State,
	beats_required:       int,
	beats_done:           int,
	research_modifiers:   []Skill_Modifier,
	bonus_modifiers:      []Skill_Modifier,
}

Thought_Cabinet :: struct {
	thoughts: [dynamic]Thought,
	slots:    int,
}

STARTING_THOUGHT_SLOTS :: 3

cabinet_init :: proc(c: ^Thought_Cabinet) {
	c.thoughts = make([dynamic]Thought)
	c.slots = STARTING_THOUGHT_SLOTS
}

cabinet_find :: proc(c: ^Thought_Cabinet, id: string) -> ^Thought {
	for &t in c.thoughts {
		if t.id == id {
			return &t
		}
	}
	return nil
}

cabinet_used_slots :: proc(c: ^Thought_Cabinet) -> int {
	n := 0
	for &t in c.thoughts {
		if t.state != .Unknown {
			n += 1
		}
	}
	return n
}

// Moves a known thought into the cabinet. Returns false if every slot is full,
// which is a real refusal -- the player has to finish something first.
cabinet_start_research :: proc(c: ^Thought_Cabinet, id: string) -> bool {
	t := cabinet_find(c, id)
	if t == nil || t.state != .Unknown {
		return false
	}
	if cabinet_used_slots(c) >= c.slots {
		return false
	}
	t.state = .Researching
	t.beats_done = 0
	return true
}

// Research advances on dialogue beats rather than wall-clock time, so thinking
// progresses when you are out doing things, not when you idle.
cabinet_advance :: proc(c: ^Thought_Cabinet) -> (finished: []string) {
	done := make([dynamic]string, context.temp_allocator)
	for &t in c.thoughts {
		if t.state != .Researching {
			continue
		}
		t.beats_done += 1
		if t.beats_done >= t.beats_required {
			t.state = .Internalized
			append(&done, t.id)
		}
	}
	return done[:]
}

thought_is_internalized :: proc(c: ^Thought_Cabinet, id: string) -> bool {
	t := cabinet_find(c, id)
	return t != nil && t.state == .Internalized
}
