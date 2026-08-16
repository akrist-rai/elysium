package game

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

// The scene is drawn from flat primitives into an offscreen target, then this
// pass does the work that makes it look painted rather than vector: the edges
// wobble, the palette is graded toward sodium and teal, the monitors bleed, and
// the whole frame sits under grain.
Painterly :: struct {
	shader:   rl.Shader,
	enabled:  bool,
	loaded:   bool,
	// uniform locations
	u_time:       i32,
	u_resolution: i32,
	u_wobble:     i32,
	u_grain:      i32,
	u_vignette:   i32,
	u_bloom:      i32,
	u_grade:      i32,
	// tunables, adjustable at runtime with F6-F9 while iterating
	wobble:   f32,
	grain:    f32,
	vignette: f32,
	bloom:    f32,
	grade:    f32,
}

painterly_load :: proc(p: ^Painterly, assets_dir: string) {
	p.wobble = 1.0
	p.grain = 1.0
	p.vignette = 1.0
	p.bloom = 1.0
	p.grade = 1.0
	p.enabled = true

	fs := fmt.tprintf("%s/shaders/painterly.fs", assets_dir)
	if !os.exists(fs) {
		fmt.eprintln("painterly: shader missing at", fs, "- running unfiltered")
		return
	}

	p.shader = rl.LoadShader(nil, cstring(raw_data(fmt.tprintf("%s\x00", fs))))
	if p.shader.id == 0 {
		fmt.eprintln("painterly: shader failed to compile - running unfiltered")
		return
	}

	p.loaded = true
	p.u_time = rl.GetShaderLocation(p.shader, "uTime")
	p.u_resolution = rl.GetShaderLocation(p.shader, "uResolution")
	p.u_wobble = rl.GetShaderLocation(p.shader, "uWobble")
	p.u_grain = rl.GetShaderLocation(p.shader, "uGrain")
	p.u_vignette = rl.GetShaderLocation(p.shader, "uVignette")
	p.u_bloom = rl.GetShaderLocation(p.shader, "uBloom")
	p.u_grade = rl.GetShaderLocation(p.shader, "uGrade")
}

painterly_unload :: proc(p: ^Painterly) {
	if p.loaded {
		rl.UnloadShader(p.shader)
		p.loaded = false
	}
}

// Draws the offscreen target to the backbuffer through the shader. The source
// rectangle is flipped in Y because render textures come out upside down.
painterly_present :: proc(p: ^Painterly, rt: rl.RenderTexture2D, time: f32) {
	w := f32(rt.texture.width)
	h := f32(rt.texture.height)
	src := rl.Rectangle{0, 0, w, -h}
	dst := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

	if p.loaded && p.enabled {
		t := time
		res := [2]f32{w, h}
		rl.SetShaderValue(p.shader, p.u_time, &t, .FLOAT)
		rl.SetShaderValue(p.shader, p.u_resolution, &res, .VEC2)
		rl.SetShaderValue(p.shader, p.u_wobble, &p.wobble, .FLOAT)
		rl.SetShaderValue(p.shader, p.u_grain, &p.grain, .FLOAT)
		rl.SetShaderValue(p.shader, p.u_vignette, &p.vignette, .FLOAT)
		rl.SetShaderValue(p.shader, p.u_bloom, &p.bloom, .FLOAT)
		rl.SetShaderValue(p.shader, p.u_grade, &p.grade, .FLOAT)

		rl.BeginShaderMode(p.shader)
		rl.DrawTexturePro(rt.texture, src, dst, {0, 0}, 0, rl.WHITE)
		rl.EndShaderMode()
	} else {
		rl.DrawTexturePro(rt.texture, src, dst, {0, 0}, 0, rl.WHITE)
	}
}
