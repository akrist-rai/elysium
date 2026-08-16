package game

import "base:runtime"
import "core:math"
import "core:slice"
import rl "vendor:raylib"

// Walkability lives on a coarse grid. The room is small and full of furniture,
// so a grid plus a smoothing pass reads better than a hand-built navmesh and
// is far easier to author against.
Nav_Grid :: struct {
	w, h:     int,
	walkable: []bool,
}

nav_init :: proc(n: ^Nav_Grid, w, h: int) {
	n.w = w
	n.h = h
	n.walkable = make([]bool, w * h)
	for i in 0 ..< len(n.walkable) {
		n.walkable[i] = true
	}
}

nav_in_bounds :: proc(n: ^Nav_Grid, x, y: int) -> bool {
	return x >= 0 && y >= 0 && x < n.w && y < n.h
}

nav_is_walkable :: proc(n: ^Nav_Grid, x, y: int) -> bool {
	if !nav_in_bounds(n, x, y) {
		return false
	}
	return n.walkable[y * n.w + x]
}

nav_block_rect :: proc(n: ^Nav_Grid, x, y, w, h: int) {
	for yy in y ..< y + h {
		for xx in x ..< x + w {
			if nav_in_bounds(n, xx, yy) {
				n.walkable[yy * n.w + xx] = false
			}
		}
	}
}

nav_walkable_at :: proc(n: ^Nav_Grid, p: rl.Vector2) -> bool {
	return nav_is_walkable(n, int(math.floor(p.x)), int(math.floor(p.y)))
}

@(private = "file")
Node_Rec :: struct {
	g, f:   f32,
	parent: int,
	closed: bool,
	opened: bool,
}

// A* over 8 neighbours. Diagonals are only allowed when both orthogonal
// neighbours are clear, so the player never clips a desk corner.
nav_find_path :: proc(
	n: ^Nav_Grid,
	from, to: rl.Vector2,
	allocator := context.allocator,
) -> []rl.Vector2 {
	sx := int(math.floor(from.x))
	sy := int(math.floor(from.y))
	gx := int(math.floor(to.x))
	gy := int(math.floor(to.y))

	if !nav_is_walkable(n, gx, gy) {
		found := false
		gx, gy, found = nav_nearest_walkable(n, gx, gy)
		if !found {
			return nil
		}
	}
	if !nav_is_walkable(n, sx, sy) {
		found := false
		sx, sy, found = nav_nearest_walkable(n, sx, sy)
		if !found {
			return nil
		}
	}
	if sx == gx && sy == gy {
		out := make([dynamic]rl.Vector2, allocator)
		append(&out, to)
		return out[:]
	}

	recs := make([]Node_Rec, n.w * n.h, context.temp_allocator)
	for i in 0 ..< len(recs) {
		recs[i] = Node_Rec {
			g      = max(f32),
			f      = max(f32),
			parent = -1,
		}
	}

	open := make([dynamic]int, context.temp_allocator)

	heuristic :: proc(ax, ay, bx, by: int) -> f32 {
		dx := abs(f32(ax - bx))
		dy := abs(f32(ay - by))
		// Octile distance: exact for 8-way movement with sqrt(2) diagonals.
		return (dx + dy) + (math.SQRT_TWO - 2) * math.min(dx, dy)
	}

	start := sy * n.w + sx
	goal := gy * n.w + gx
	recs[start].g = 0
	recs[start].f = heuristic(sx, sy, gx, gy)
	recs[start].opened = true
	append(&open, start)

	neighbours := [8][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

	for len(open) > 0 {
		// Small open set; a linear scan beats the bookkeeping of a heap here.
		best_i := 0
		for i in 1 ..< len(open) {
			if recs[open[i]].f < recs[open[best_i]].f {
				best_i = i
			}
		}
		current := open[best_i]
		unordered_remove(&open, best_i)

		if current == goal {
			return nav_reconstruct(n, recs, start, goal, to, allocator)
		}

		recs[current].closed = true
		cx := current % n.w
		cy := current / n.w

		for d in neighbours {
			nx := cx + d[0]
			ny := cy + d[1]
			if !nav_is_walkable(n, nx, ny) {
				continue
			}
			if d[0] != 0 && d[1] != 0 {
				// No cutting corners between two blocked cells.
				if !nav_is_walkable(n, cx + d[0], cy) || !nav_is_walkable(n, cx, cy + d[1]) {
					continue
				}
			}
			ni := ny * n.w + nx
			if recs[ni].closed {
				continue
			}
			step: f32 = (d[0] != 0 && d[1] != 0) ? math.SQRT_TWO : 1.0
			tentative := recs[current].g + step
			if tentative < recs[ni].g {
				recs[ni].g = tentative
				recs[ni].f = tentative + heuristic(nx, ny, gx, gy)
				recs[ni].parent = current
				if !recs[ni].opened {
					recs[ni].opened = true
					append(&open, ni)
				}
			}
		}
	}

	return nil
}

@(private = "file")
nav_reconstruct :: proc(
	n: ^Nav_Grid,
	recs: []Node_Rec,
	start, goal: int,
	exact_goal: rl.Vector2,
	allocator: runtime.Allocator,
) -> []rl.Vector2 {
	raw := make([dynamic]rl.Vector2, context.temp_allocator)
	cur := goal
	for cur != -1 {
		x := f32(cur % n.w) + 0.5
		y := f32(cur / n.w) + 0.5
		append(&raw, rl.Vector2{x, y})
		if cur == start {
			break
		}
		cur = recs[cur].parent
	}
	slice.reverse(raw[:])

	// The click landed somewhere inside the goal tile; walk to that point
	// rather than snapping to the tile centre.
	if len(raw) > 0 {
		raw[len(raw) - 1] = exact_goal
	}

	return nav_smooth(n, raw[:], allocator)
}

// String-pulling: drop any waypoint that can be skipped with a clear straight
// line. Turns the staircase A* produces into the diagonal a person would walk.
nav_smooth :: proc(
	n: ^Nav_Grid,
	path: []rl.Vector2,
	allocator := context.allocator,
) -> []rl.Vector2 {
	out := make([dynamic]rl.Vector2, allocator)
	if len(path) == 0 {
		return out[:]
	}

	anchor := 0
	append(&out, path[0])
	for anchor < len(path) - 1 {
		furthest := anchor + 1
		for probe in anchor + 2 ..< len(path) {
			if nav_line_clear(n, path[anchor], path[probe]) {
				furthest = probe
			}
		}
		append(&out, path[furthest])
		anchor = furthest
	}

	// The first point is where we already are.
	if len(out) > 1 {
		ordered_remove(&out, 0)
	}
	return out[:]
}

// Samples along the segment; step is well under a tile so nothing is missed.
nav_line_clear :: proc(n: ^Nav_Grid, a, b: rl.Vector2) -> bool {
	d := b - a
	dist := math.sqrt(d.x * d.x + d.y * d.y)
	steps := int(dist / 0.2) + 1
	for i in 0 ..= steps {
		t := f32(i) / f32(steps)
		p := a + d * t
		if !nav_walkable_at(n, p) {
			return false
		}
	}
	return true
}

// Spiral outward for the closest open tile, used when a click lands on a desk.
nav_nearest_walkable :: proc(n: ^Nav_Grid, x, y: int) -> (int, int, bool) {
	for radius in 0 ..< 12 {
		for dy in -radius ..= radius {
			for dx in -radius ..= radius {
				if abs(dx) != radius && abs(dy) != radius {
					continue // only the ring at this radius
				}
				if nav_is_walkable(n, x + dx, y + dy) {
					return x + dx, y + dy, true
				}
			}
		}
	}
	return x, y, false
}
