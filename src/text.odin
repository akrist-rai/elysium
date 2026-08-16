package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

// Fonts are loaded at a generous pixel size and scaled down when drawn, which
// keeps them crisp at every size the UI uses without a texture atlas per size.
FONT_ATLAS_SIZE :: 48

load_font_or_default :: proc(path: string) -> rl.Font {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	if !rl.FileExists(cpath) {
		return rl.GetFontDefault()
	}
	f := rl.LoadFontEx(cpath, FONT_ATLAS_SIZE, nil, 0)
	if f.texture.id == 0 {
		return rl.GetFontDefault()
	}
	rl.SetTextureFilter(f.texture, .BILINEAR)
	return f
}

measure :: proc(font: rl.Font, s: string, size: f32, spacing: f32 = 0) -> rl.Vector2 {
	c := strings.clone_to_cstring(s, context.temp_allocator)
	return rl.MeasureTextEx(font, c, size, spacing)
}

draw_text :: proc(
	font: rl.Font,
	s: string,
	pos: rl.Vector2,
	size: f32,
	color: rl.Color,
	spacing: f32 = 0,
) {
	c := strings.clone_to_cstring(s, context.temp_allocator)
	rl.DrawTextEx(font, c, pos, size, spacing, color)
}

// Greedy word wrap. Returns lines allocated in the temp allocator, so callers
// must use them within the frame.
wrap_text :: proc(font: rl.Font, s: string, size, max_width: f32, spacing: f32 = 0) -> []string {
	lines := make([dynamic]string, context.temp_allocator)

	if s == "" {
		append(&lines, "")
		return lines[:]
	}

	words := strings.fields(s, context.temp_allocator)
	if len(words) == 0 {
		append(&lines, "")
		return lines[:]
	}

	current := strings.builder_make(context.temp_allocator)
	strings.write_string(&current, words[0])

	for i in 1 ..< len(words) {
		candidate := fmt.tprintf("%s %s", strings.to_string(current), words[i])
		if measure(font, candidate, size, spacing).x <= max_width {
			strings.write_byte(&current, ' ')
			strings.write_string(&current, words[i])
		} else {
			append(&lines, strings.clone(strings.to_string(current), context.temp_allocator))
			current = strings.builder_make(context.temp_allocator)
			strings.write_string(&current, words[i])
		}
	}
	append(&lines, strings.clone(strings.to_string(current), context.temp_allocator))

	return lines[:]
}

// Draws wrapped text and returns the height consumed. `reveal` limits how many
// characters are painted, which is how the typewriter works -- the layout is
// computed for the whole string so nothing reflows as it types out.
draw_wrapped :: proc(
	font: rl.Font,
	s: string,
	pos: rl.Vector2,
	size, max_width, line_height: f32,
	color: rl.Color,
	reveal: int = -1,
	spacing: f32 = 0,
) -> f32 {
	lines := wrap_text(font, s, size, max_width, spacing)
	y := pos.y
	consumed := 0

	for line in lines {
		if reveal >= 0 && consumed >= reveal {
			break
		}
		text := line
		if reveal >= 0 {
			remaining := reveal - consumed
			if remaining < len(line) {
				text = line[:clamp_byte_boundary(line, remaining)]
			}
		}
		draw_text(font, text, {pos.x, y}, size, color, spacing)
		// +1 accounts for the space the wrap consumed between lines, so the
		// reveal advances at a steady rate rather than stalling at line ends.
		consumed += len(line) + 1
		y += line_height
	}

	return f32(len(lines)) * line_height
}

wrapped_height :: proc(
	font: rl.Font,
	s: string,
	size, max_width, line_height: f32,
	spacing: f32 = 0,
) -> f32 {
	return f32(len(wrap_text(font, s, size, max_width, spacing))) * line_height
}

// Never cut a UTF-8 sequence in half while typing text out.
clamp_byte_boundary :: proc(s: string, n: int) -> int {
	if n >= len(s) {
		return len(s)
	}
	i := n
	for i > 0 && (s[i] & 0xC0) == 0x80 {
		i -= 1
	}
	return i
}

// A thin bordered panel, the base of every UI surface in the game.
draw_panel :: proc(rect: rl.Rectangle, fill: rl.Color = COL_PANEL, edge: rl.Color = COL_PANEL_EDGE) {
	rl.DrawRectangleRec(rect, fill)
	rl.DrawRectangleLinesEx(rect, 1, edge)
}

draw_hline :: proc(x, y, w: f32, color: rl.Color) {
	rl.DrawRectangleRec({x, y, w, 1}, color)
}
