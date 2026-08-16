package game

import rl "vendor:raylib"

// The room is lit by two things: dying fluorescent tubes overhead and the cold
// glow of monitors nobody turned off. Everything in the palette is one of
// those two, or the dark between them.

COL_INK :: rl.Color{18, 20, 22, 255} // near-black backing for panels
COL_PAPER :: rl.Color{226, 219, 200, 255} // aged paper, the base text colour
COL_NARRATION :: rl.Color{176, 172, 158, 255}
COL_SPEECH :: rl.Color{228, 222, 206, 255}
COL_PLAYER :: rl.Color{236, 214, 148, 255}
COL_OPTION :: rl.Color{198, 194, 178, 255}
COL_SYSTEM :: rl.Color{132, 168, 140, 255}
COL_PASS :: rl.Color{126, 200, 132, 255}
COL_FAIL :: rl.Color{214, 88, 76, 255}
COL_RED_CHECK :: rl.Color{206, 66, 56, 255}
COL_WHITE_CHECK :: rl.Color{222, 220, 212, 255}
COL_LOCKED :: rl.Color{104, 102, 96, 255}

COL_HEALTH :: rl.Color{198, 72, 60, 255}
COL_MORALE :: rl.Color{92, 148, 206, 255}

COL_PANEL :: rl.Color{22, 24, 27, 238}
COL_PANEL_EDGE :: rl.Color{70, 68, 60, 255}

// World lighting: a warm sodium key from the corridor door, a cold fill from
// the racks. Every surface is graded between these two.
COL_KEY :: rl.Color{255, 214, 152, 255}
COL_FILL :: rl.Color{104, 138, 168, 255}
COL_FLOOR :: rl.Color{78, 77, 73, 255}
COL_WALL :: rl.Color{94, 91, 85, 255}

COL_ORB :: rl.Color{248, 232, 178, 255}
COL_ORB_SEEN :: rl.Color{146, 150, 152, 255}

fade :: proc(c: rl.Color, alpha: f32) -> rl.Color {
	out := c
	out.a = u8(clamp(f32(c.a) * alpha, 0, 255))
	return out
}

mix :: proc(a, b: rl.Color, t: f32) -> rl.Color {
	tt := clamp(t, 0, 1)
	return rl.Color {
		u8(f32(a.r) + (f32(b.r) - f32(a.r)) * tt),
		u8(f32(a.g) + (f32(b.g) - f32(a.g)) * tt),
		u8(f32(a.b) + (f32(b.b) - f32(a.b)) * tt),
		u8(f32(a.a) + (f32(b.a) - f32(a.a)) * tt),
	}
}

scale_rgb :: proc(c: rl.Color, f: f32) -> rl.Color {
	return rl.Color {
		u8(clamp(f32(c.r) * f, 0, 255)),
		u8(clamp(f32(c.g) * f, 0, 255)),
		u8(clamp(f32(c.b) * f, 0, 255)),
		c.a,
	}
}
