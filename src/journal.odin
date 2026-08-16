package game

Task_State :: enum u8 {
	Active,
	Completed,
	Failed,
}

// Tasks are written the way the detective would phrase them to himself, not
// the way a quest system would.
Task :: struct {
	id:     string,
	title:  string,
	detail: string,
	state:  Task_State,
}

Journal :: struct {
	tasks:  [dynamic]Task,
	// Set whenever a task changes, so the HUD can flash the journal key.
	dirty:  bool,
}

journal_init :: proc(j: ^Journal) {
	j.tasks = make([dynamic]Task)
}

journal_find :: proc(j: ^Journal, id: string) -> ^Task {
	for &t in j.tasks {
		if t.id == id {
			return &t
		}
	}
	return nil
}

journal_add :: proc(j: ^Journal, task: Task) {
	if journal_find(j, task.id) != nil {
		return
	}
	append(&j.tasks, task)
	j.dirty = true
}

journal_set_state :: proc(j: ^Journal, id: string, state: Task_State) {
	t := journal_find(j, id)
	if t == nil || t.state == state {
		return
	}
	t.state = state
	j.dirty = true
}

journal_active_count :: proc(j: ^Journal) -> int {
	n := 0
	for &t in j.tasks {
		if t.state == .Active {
			n += 1
		}
	}
	return n
}
