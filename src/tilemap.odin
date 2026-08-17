package game

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

// The floor plan is a text file, one character per tile, living in content/
// alongside the writing. It reloads with F5 like everything else, so the room
// can be rearranged while the game is running.

Tile :: enum u8 {
	Void, // outside the building
	Floor_Tech, // raised server-room floor
	Floor_Corridor,
	Floor_Office,
	Wall,
	Wall_Board, // whiteboard
	Wall_Screen, // the frozen scoreboard
	Wall_Notice, // the duty roster
	Wall_Exit, // exit sign
	Door,
	Rack,
	Desk,
	Bench,
	Chair,
	Crate,
	Shelf,
	Spool,
	Printer,
}

Tile_Map :: struct {
	w, h:   int,
	tiles:  []Tile,
	spawn:  rl.Vector2,
	tubes:  [dynamic]rl.Vector2, // ceiling fluorescents, authored with '*'
	loaded: bool,
}

// Only floors and the things you can walk over are clear. Chairs are
// deliberately not solid -- shoving past a chair should never cost you a
// second of input.
tile_blocks :: proc(t: Tile) -> bool {
	switch t {
	case .Floor_Tech, .Floor_Corridor, .Floor_Office, .Door, .Chair:
		return false
	case .Void, .Wall, .Wall_Board, .Wall_Screen, .Wall_Notice, .Wall_Exit,
	     .Rack, .Desk, .Bench, .Crate, .Shelf, .Spool, .Printer:
		return true
	}
	return true
}

tile_is_floor :: proc(t: Tile) -> bool {
	return t == .Floor_Tech || t == .Floor_Corridor || t == .Floor_Office || t == .Door
}

tile_is_wall :: proc(t: Tile) -> bool {
	return t == .Wall || t == .Wall_Board || t == .Wall_Screen || t == .Wall_Notice || t == .Wall_Exit
}

@(private = "file")
tile_from_char :: proc(c: u8) -> (Tile, bool) {
	switch c {
	case '#':
		return .Wall, true
	case '.':
		return .Floor_Tech, true
	case ',':
		return .Floor_Corridor, true
	case ':':
		return .Floor_Office, true
	case 'X':
		return .Door, true
	case 'R':
		return .Rack, true
	case 'D':
		return .Desk, true
	case 'd':
		return .Bench, true
	case 'c':
		return .Chair, true
	case 'B':
		return .Crate, true
	case '=':
		return .Shelf, true
	case '~':
		return .Spool, true
	case 'P':
		return .Printer, true
	case 'W':
		return .Wall_Board, true
	case 'S':
		return .Wall_Screen, true
	case 'N':
		return .Wall_Notice, true
	case 'e':
		return .Wall_Exit, true
	}
	return .Void, false
}

tilemap_at :: proc(m: ^Tile_Map, x, y: int) -> Tile {
	if x < 0 || y < 0 || x >= m.w || y >= m.h {
		return .Void
	}
	return m.tiles[y * m.w + x]
}

tilemap_blocked_at :: proc(m: ^Tile_Map, wx, wy: f32) -> bool {
	return tile_blocks(tilemap_at(m, int(wx), int(wy)))
}

tilemap_destroy :: proc(m: ^Tile_Map) {
	if m.tiles != nil {
		delete(m.tiles)
		m.tiles = nil
	}
	if m.tubes != nil {
		delete(m.tubes)
		m.tubes = nil
	}
	m.loaded = false
}

// Parses content/map.txt. Errors carry the file and line so they land in the
// same reporting path as a broken .plot file.
tilemap_load :: proc(path: string) -> (m: Tile_Map, errors: []Parse_Error) {
	errs := make([dynamic]Parse_Error)

	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		append(&errs, Parse_Error{file = path, line = 0, msg = "map file not found"})
		return m, errs[:]
	}
	defer delete(data)

	name := path
	if idx := strings.last_index_byte(path, '/'); idx >= 0 {
		name = path[idx + 1:]
	}

	// Gather the grid rows first so the width can be validated against row one.
	rows := make([dynamic]string, context.temp_allocator)
	line_nos := make([dynamic]int, context.temp_allocator)

	src := string(data)
	line_no := 0
	for line in strings.split_lines_iterator(&src) {
		line_no += 1
		trimmed := strings.trim_right_space(line)
		if len(trimmed) == 0 || trimmed[0] == ';' {
			continue
		}
		append(&rows, trimmed)
		append(&line_nos, line_no)
	}

	if len(rows) == 0 {
		append(&errs, Parse_Error{file = name, line = 0, msg = "map is empty"})
		return m, errs[:]
	}

	width := len(rows[0])
	for row, i in rows {
		if len(row) != width {
			append(
				&errs,
				Parse_Error {
					file = name,
					line = line_nos[i],
					msg = fmt.aprintf("row is %d tiles wide, expected %d", len(row), width),
				},
			)
		}
	}
	if len(errs) > 0 {
		return m, errs[:]
	}

	m.w = width
	m.h = len(rows)
	m.tiles = make([]Tile, m.w * m.h)
	m.tubes = make([dynamic]rl.Vector2)
	m.spawn = {f32(m.w) * 0.5, f32(m.h) * 0.5}

	// '*' and '@' do not name a surface, they annotate one, so they are filled
	// in from a neighbour once the rest of the grid is known.
	deferred := make([dynamic][2]int, context.temp_allocator)
	spawn_found := false

	for row, y in rows {
		for x in 0 ..< width {
			c := row[x]
			switch c {
			case '*':
				append(&m.tubes, rl.Vector2{f32(x) + 0.5, f32(y) + 0.5})
				append(&deferred, [2]int{x, y})
				continue
			case '@':
				m.spawn = {f32(x) + 0.5, f32(y) + 0.5}
				spawn_found = true
				append(&deferred, [2]int{x, y})
				continue
			}

			tile, ok := tile_from_char(c)
			if !ok {
				append(
					&errs,
					Parse_Error {
						file = name,
						line = line_nos[y],
						msg = fmt.aprintf("unknown tile character '%c' at column %d", c, x + 1),
					},
				)
			}
			m.tiles[y * m.w + x] = tile
		}
	}

	for d in deferred {
		m.tiles[d[1] * m.w + d[0]] = neighbour_floor(&m, d[0], d[1])
	}

	if !spawn_found {
		append(&errs, Parse_Error{file = name, line = 0, msg = "no '@' spawn point in the map"})
	} else if tile_blocks(tilemap_at(&m, int(m.spawn.x), int(m.spawn.y))) {
		append(&errs, Parse_Error{file = name, line = 0, msg = "the '@' spawn point is inside something solid"})
	}

	m.loaded = len(errs) == 0
	return m, errs[:]
}

// A tube or a spawn marker takes the surface of whatever room it is standing
// in, so the same character works in the server room and the corridor.
@(private = "file")
neighbour_floor :: proc(m: ^Tile_Map, x, y: int) -> Tile {
	offsets := [8][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
	for o in offsets {
		t := tilemap_at(m, x + o[0], y + o[1])
		if t == .Floor_Tech || t == .Floor_Corridor || t == .Floor_Office {
			return t
		}
	}
	return .Floor_Tech
}
