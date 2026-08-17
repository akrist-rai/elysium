package game

import "core:math"
import rl "vendor:raylib"

// The palette is deliberately small, the way a painter lays out a limited set of
// pigments and mixes everything on the palette rather than reaching for a tube.
// Two light sources own the whole room -- sodium-warm from the corridor and the
// exit sign, mercury-cold from the racks and the monitors -- and every colour in
// here is one of those, the dark between them, or a neutral earth to sit them on.
//
// Nothing is pure black and nothing is pure white. The darkest value in the room
// is a blue-green umber and the brightest is a warm off-white, which is what
// keeps the frame reading as paint on board instead of pixels on glass.

// --- earths: the neutral spine of the palette --------------------------------
PIG_UMBER_DEEP :: rl.Color{20, 24, 27, 255} // darkest usable value
PIG_UMBER :: rl.Color{38, 42, 44, 255}
PIG_UMBER_WARM :: rl.Color{56, 51, 44, 255}
PIG_GREY_PAYNE :: rl.Color{62, 70, 78, 255} // cool neutral, the shadow workhorse
PIG_GREY_WARM :: rl.Color{86, 80, 71, 255}
PIG_STONE :: rl.Color{112, 108, 99, 255}
PIG_BONE :: rl.Color{186, 178, 160, 255}

// --- the warm half: sodium, exit signs, corridor spill ------------------------
PIG_SODIUM :: rl.Color{255, 196, 118, 255}
PIG_NAPLES :: rl.Color{236, 205, 148, 255} // the tube overhead, softened by dust
PIG_AMBER_DEEP :: rl.Color{176, 108, 52, 255}
PIG_SIENNA :: rl.Color{128, 74, 46, 255}
PIG_EMBER :: rl.Color{226, 96, 66, 255} // exit sign, the only red light

// --- the cold half: monitors, rack LEDs, the dark between them ----------------
PIG_MERCURY :: rl.Color{158, 226, 214, 255} // monitor white, faintly green
PIG_VIRIDIAN :: rl.Color{74, 138, 130, 255}
PIG_TEAL_DEEP :: rl.Color{34, 62, 68, 255}
PIG_CYAN_LED :: rl.Color{120, 208, 232, 255}
PIG_BLUE_COLD :: rl.Color{78, 116, 156, 255}

// --- UI ink and paper ---------------------------------------------------------
COL_INK :: PIG_UMBER_DEEP
COL_PAPER :: rl.Color{226, 219, 200, 255}
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

// --- world lighting -----------------------------------------------------------
COL_KEY :: PIG_SODIUM
COL_FILL :: PIG_BLUE_COLD
COL_FLOOR :: rl.Color{74, 76, 74, 255}
COL_WALL :: rl.Color{92, 90, 84, 255}

COL_ORB :: rl.Color{248, 232, 178, 255}
COL_ORB_SEEN :: rl.Color{132, 138, 140, 255}

// ---------------------------------------------------------------------------
// Colour maths
//
// Mixing happens in linear light. Averaging two colours in sRGB darkens the
// result and turns every gradient muddy, which is exactly the failure mode that
// makes shaded polygons look like plastic instead of pigment.
// ---------------------------------------------------------------------------

Vec3 :: [3]f32

GAMMA :: 2.2

srgb_to_linear :: proc(c: rl.Color) -> Vec3 {
	return Vec3 {
		math.pow(f32(c.r) / 255.0, GAMMA),
		math.pow(f32(c.g) / 255.0, GAMMA),
		math.pow(f32(c.b) / 255.0, GAMMA),
	}
}

linear_to_srgb :: proc(v: Vec3, alpha: u8 = 255) -> rl.Color {
	inv := f32(1.0) / GAMMA
	return rl.Color {
		u8(clamp(math.pow(math.max(v.x, 0), inv) * 255.0, 0, 255)),
		u8(clamp(math.pow(math.max(v.y, 0), inv) * 255.0, 0, 255)),
		u8(clamp(math.pow(math.max(v.z, 0), inv) * 255.0, 0, 255)),
		alpha,
	}
}

luminance :: proc(v: Vec3) -> f32 {
	return v.x * 0.2126 + v.y * 0.7152 + v.z * 0.0722
}

fade :: proc(c: rl.Color, alpha: f32) -> rl.Color {
	out := c
	out.a = u8(clamp(f32(c.a) * alpha, 0, 255))
	return out
}

// sRGB-space lerp. Kept for UI work, where the inputs are already chosen by eye
// and a perceptual straight line between them is what is actually wanted.
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

// Pull a colour toward a hue without changing how bright it reads. Painters do
// this constantly -- a shadow is not the object colour turned down, it is the
// object colour turned down *and* pushed toward the colour of the ambient light.
tint_preserve_value :: proc(c: rl.Color, toward: rl.Color, amount: f32) -> rl.Color {
	base := srgb_to_linear(c)
	target := srgb_to_linear(toward)
	before := luminance(base)

	mixed := base + (target - base) * clamp(amount, 0, 1)
	after := luminance(mixed)
	if after > 0.0001 {
		mixed *= before / after
	}
	return linear_to_srgb(mixed, c.a)
}

// Desaturate toward the neutral of the same value. Distance haze and worn paint
// both want this rather than a straight fade to grey.
desaturate :: proc(c: rl.Color, amount: f32) -> rl.Color {
	v := srgb_to_linear(c)
	g := luminance(v)
	t := clamp(amount, 0, 1)
	return linear_to_srgb(v + (Vec3{g, g, g} - v) * t, c.a)
}
