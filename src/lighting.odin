package game

import "core:math"
import rl "vendor:raylib"

// Light in a top-down room.
//
// Every lamp in the building comes from something you can see -- a tube in the
// ceiling, the face of a rack, a screen nobody switched off -- and this file is
// the only place that decides how much of it lands anywhere. Two things use it:
// the floor, which gets light painted onto it as soft additive pools, and
// everything with a body, which gets shaded analytically from the same numbers
// so the pools and the people can never disagree about where the light is.
//
// The single rule that keeps it looking like paint rather than like a lightmap:
// nothing is ever lit to white and nothing ever falls to black. The darkest
// corner is a cold blue-green and the brightest tube is a warm off-white, and
// the whole image lives in the value range between them.

// Ambient is what is left when every lamp is too far away. It is deliberately
// coloured -- a dead neutral grey here would drain the room in one step.
AMBIENT :: rl.Color{34, 44, 50, 255}
AMBIENT_STRENGTH :: f32(0.42)

// How far past its nominal radius a light still reaches.
LIGHT_REACH :: f32(1.9)

// A tube on its way out does not blink on and off, it hunts: mostly there, with
// an irregular sag and the occasional hard stutter. Two incommensurate sines
// plus a cheap step give that without a random call.
light_flicker :: proc(l: Light, time: f32) -> f32 {
	if l.flicker <= 0.001 {
		return 1
	}
	t := time * 7.3 + l.phase
	wobble := math.sin(t) * 0.5 + math.sin(t * 2.37 + 1.1) * 0.3 + math.sin(t * 5.9) * 0.2

	// The stutter: brief, occasional, and never a full blackout.
	stutter := f32(0)
	s := math.sin(time * 2.1 + l.phase * 3.7)
	if s > 0.93 {
		stutter = -0.55
	}

	amount := l.flicker
	return clamp(1.0 + (wobble * 0.22 + stutter) * amount, 0.25, 1.12)
}

// Windowed inverse square. Physical near the source so the falloff reads right,
// then forced to zero at the edge of its reach so a lamp three rooms away cannot
// quietly lift the whole frame.
light_falloff :: proc(l: Light, dist: f32) -> f32 {
	if l.radius <= 0.0001 {
		return 0
	}
	x := dist / l.radius
	if x >= LIGHT_REACH {
		return 0
	}
	falloff := 1.0 / (1.0 + 3.0 * x * x)
	w := 1.0 - x / LIGHT_REACH
	return falloff * w * w * l.intensity
}

// Total light landing on a point, in linear space.
light_at :: proc(s: ^Scene, p: rl.Vector2, time: f32) -> Vec3 {
	total := srgb_to_linear(AMBIENT) * AMBIENT_STRENGTH

	for l in s.lights {
		dx := l.pos.x - p.x
		dy := l.pos.y - p.y
		d2 := dx * dx + dy * dy
		// Cheap reject before the square root; most lights fail this.
		reach := l.radius * LIGHT_REACH
		if d2 >= reach * reach {
			continue
		}
		att := light_falloff(l, math.sqrt(d2)) * light_flicker(l, time)
		if att <= 0.0001 {
			continue
		}
		total += srgb_to_linear(l.color) * att
	}
	return total
}

// The direction the dominant light arrives from, and how strong it is. This is
// what a body is shaded by and where its rim goes. Picking it per-position
// rather than assuming one global sun is what lets someone walk out of a tube's
// pool and have their lit side hand off to the rack glow behind them.
light_dominant :: proc(s: ^Scene, p: rl.Vector2, time: f32) -> (dir: rl.Vector2, strength: f32) {
	best := f32(0)
	dir = {0, -1}

	for l in s.lights {
		dx := l.pos.x - p.x
		dy := l.pos.y - p.y
		d2 := dx * dx + dy * dy
		reach := l.radius * LIGHT_REACH
		if d2 >= reach * reach {
			continue
		}
		d := math.sqrt(d2)
		att := light_falloff(l, d) * light_flicker(l, time)
		// Weight by how bright the lamp actually is, not just how close it is.
		score := att * luminance(srgb_to_linear(l.color))
		if score > best {
			best = score
			if d > 0.0001 {
				dir = {dx / d, dy / d}
			}
		}
	}
	return dir, best
}

// The colour of the dominant light, for rims and speculars.
light_dominant_color :: proc(s: ^Scene, p: rl.Vector2, time: f32) -> rl.Color {
	best := f32(0)
	col := AMBIENT

	for l in s.lights {
		dx := l.pos.x - p.x
		dy := l.pos.y - p.y
		d2 := dx * dx + dy * dy
		reach := l.radius * LIGHT_REACH
		if d2 >= reach * reach {
			continue
		}
		att := light_falloff(l, math.sqrt(d2)) * light_flicker(l, time)
		score := att * luminance(srgb_to_linear(l.color))
		if score > best {
			best = score
			col = l.color
		}
	}
	return col
}

// Apply accumulated light to a surface colour.
//
// The shadow push at the end is the part that matters: a painter's shadow is
// never just a darker version of the lit colour, it is the object colour turned
// down *and* pushed toward the colour of the ambient. Without this the dark half
// of every object is the same hue as the light half and the whole frame reads as
// a photograph with the exposure pulled down.
shade_albedo :: proc(albedo: rl.Color, light: Vec3) -> rl.Color {
	lit := srgb_to_linear(albedo) * light

	v := luminance(lit)
	push := 1.0 - math.min(v / 0.12, 1.0)
	if push > 0 {
		cold := srgb_to_linear(AMBIENT) * 0.14
		lit = lit + (cold - lit) * (push * 0.34)
	}
	return linear_to_srgb(lit, albedo.a)
}

// Convenience: shade a surface at a world position.
shade_at :: proc(s: ^Scene, p: rl.Vector2, albedo: rl.Color, time: f32) -> rl.Color {
	return shade_albedo(albedo, light_at(s, p, time))
}

// A lambert-ish term for a vertical face whose outward normal points `n` in the
// floor plane. Used for the extruded faces of walls and props, which are the
// only surfaces in a top-down room that have a direction at all.
//
// The wrap keeps unlit faces coloured instead of dead; real rooms have no hard
// terminator because light bounces.
FACE_WRAP :: f32(0.42)

face_shade :: proc(s: ^Scene, p: rl.Vector2, n: rl.Vector2, albedo: rl.Color, time: f32) -> rl.Color {
	amb := srgb_to_linear(AMBIENT) * AMBIENT_STRENGTH
	total := amb

	for l in s.lights {
		dx := l.pos.x - p.x
		dy := l.pos.y - p.y
		d2 := dx * dx + dy * dy
		reach := l.radius * LIGHT_REACH
		if d2 >= reach * reach {
			continue
		}
		d := math.sqrt(d2)
		att := light_falloff(l, d) * light_flicker(l, time)
		if att <= 0.0001 {
			continue
		}
		ndotl := f32(0)
		if d > 0.0001 {
			ndotl = (dx / d) * n.x + (dy / d) * n.y
		}
		wrapped := (ndotl + FACE_WRAP) / (1.0 + FACE_WRAP)
		if wrapped <= 0 {
			continue
		}
		total += srgb_to_linear(l.color) * (att * wrapped)
	}

	return shade_albedo(albedo, total)
}
