package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Every sound in the game is synthesised at startup. There are no audio assets
// to ship, and a server room only really makes four noises anyway: the hum, the
// clatter of a key, dice on a desk, and the sound of being wrong.

SAMPLE_RATE :: 44100

Audio :: struct {
	ready:      bool,
	hum:        rl.Sound,
	key:        [4]rl.Sound, // slight variations so typing is not a metronome
	die:        rl.Sound,
	pass:       rl.Sound,
	fail:       rl.Sound,
	key_cursor: int,
	key_timer:  f32,
	enabled:    bool,
}

audio_init :: proc(a: ^Audio) {
	rl.InitAudioDevice()
	if !rl.IsAudioDeviceReady() {
		return
	}
	a.ready = true
	a.enabled = true
	rl.SetMasterVolume(0.75)

	a.hum = make_room_hum()
	rl.SetSoundVolume(a.hum, 0.34)

	for i in 0 ..< 4 {
		a.key[i] = make_key_click(0.9 + f32(i) * 0.07)
		rl.SetSoundVolume(a.key[i], 0.16)
	}

	a.die = make_die_clack()
	rl.SetSoundVolume(a.die, 0.4)

	a.pass = make_sting(true)
	rl.SetSoundVolume(a.pass, 0.32)

	a.fail = make_sting(false)
	rl.SetSoundVolume(a.fail, 0.36)
}

audio_shutdown :: proc(a: ^Audio) {
	if !a.ready {
		return
	}
	rl.UnloadSound(a.hum)
	for s in a.key {
		rl.UnloadSound(s)
	}
	rl.UnloadSound(a.die)
	rl.UnloadSound(a.pass)
	rl.UnloadSound(a.fail)
	rl.CloseAudioDevice()
}

// The hum is a loop we re-trigger when it runs out, which is cheaper and more
// robust than streaming and nobody can hear the seam under the noise floor.
audio_update :: proc(a: ^Audio, dt: f32) {
	if !a.ready || !a.enabled {
		return
	}
	if !rl.IsSoundPlaying(a.hum) {
		rl.PlaySound(a.hum)
	}
	if a.key_timer > 0 {
		a.key_timer -= dt
	}
}

// Called while dialogue text is revealing.
audio_typewriter :: proc(a: ^Audio) {
	if !a.ready || !a.enabled || a.key_timer > 0 {
		return
	}
	rl.SetSoundPitch(a.key[a.key_cursor], 0.92 + rand.float32() * 0.2)
	rl.PlaySound(a.key[a.key_cursor])
	a.key_cursor = (a.key_cursor + 1) % 4
	a.key_timer = 0.035 + rand.float32() * 0.03
}

audio_play :: proc(a: ^Audio, s: rl.Sound) {
	if a.ready && a.enabled {
		rl.PlaySound(s)
	}
}

// ---------------------------------------------------------------------------
// Synthesis
// ---------------------------------------------------------------------------

// Builds a mono 16-bit wave from a generator over normalised time.
@(private = "file")
synth :: proc(seconds: f32, gen: proc(t, phase: f32) -> f32) -> rl.Wave {
	frames := int(seconds * SAMPLE_RATE)
	samples := make([]i16, frames)

	for i in 0 ..< frames {
		t := f32(i) / SAMPLE_RATE
		phase := f32(i) / f32(frames)
		v := clamp(gen(t, phase), -1, 1)
		samples[i] = i16(v * 32000)
	}

	return rl.Wave {
		frameCount = u32(frames),
		sampleRate = SAMPLE_RATE,
		sampleSize = 16,
		channels = 1,
		data = raw_data(samples),
	}
}

@(private = "file")
sound_from :: proc(w: rl.Wave) -> rl.Sound {
	s := rl.LoadSoundFromWave(w)
	// The sample data was copied into the sound; the wave buffer is ours to
	// drop, and we allocated it ourselves so we free it ourselves.
	delete(([^]i16)(w.data)[:w.frameCount])
	return s
}

// Racks: mains hum at 50Hz with its harmonics, plus fan noise rolled off.
@(private = "file")
make_room_hum :: proc() -> rl.Sound {
	return sound_from(
		synth(4.0, proc(t, phase: f32) -> f32 {
			v := f32(0)
			v += math.sin(t * 50 * math.TAU) * 0.30
			v += math.sin(t * 100 * math.TAU) * 0.13
			v += math.sin(t * 150 * math.TAU) * 0.06
			// Fan wash: noise smoothed by a cheap one-pole, approximated with a
			// slow-moving random walk driven off the sample index.
			n := math.sin(t * 2371.3) * math.sin(t * 811.7) * math.sin(t * 137.1)
			v += n * 0.10
			// A slow beat between two nearly-tuned units.
			v *= 0.85 + 0.15 * math.sin(t * 0.37 * math.TAU)
			// Fade the loop seam.
			edge := math.min(phase, 1 - phase) / 0.04
			return v * clamp(edge, 0, 1)
		}),
	)
}

// A mechanical keyboard, one key, close-miked.
@(private = "file")
make_key_click :: proc(pitch: f32) -> rl.Sound {
	p := pitch
	// The generator has to be a plain proc, so the pitch rides in through a
	// file-scope cell rather than a closure.
	key_pitch = p
	return sound_from(
		synth(0.05, proc(t, phase: f32) -> f32 {
			env := math.exp(-t * 150)
			click := math.sin(t * 1800 * key_pitch * math.TAU) * 0.5
			noise := (math.sin(t * 9973.1) * math.sin(t * 4409.7)) * 0.5
			return (click + noise) * env
		}),
	)
}

@(private = "file")
key_pitch: f32 = 1.0

// Two dice landing on laminate.
@(private = "file")
make_die_clack :: proc() -> rl.Sound {
	return sound_from(
		synth(0.42, proc(t, phase: f32) -> f32 {
			hit :: proc(t, at, decay: f32) -> f32 {
				if t < at {
					return 0
				}
				d := t - at
				env := math.exp(-d * decay)
				body := math.sin(d * 320 * math.TAU) * 0.4
				snap := (math.sin(d * 7331.0) * math.sin(d * 3119.0)) * 0.6
				return (body + snap) * env
			}
			return hit(t, 0.0, 42) * 0.9 + hit(t, 0.09, 46) * 0.7 + hit(t, 0.17, 60) * 0.4
		}),
	)
}

// Success rises a fifth; failure falls a tritone and stays there.
@(private = "file")
make_sting :: proc(success: bool) -> rl.Sound {
	sting_up = success
	return sound_from(
		synth(0.9, proc(t, phase: f32) -> f32 {
			env := math.exp(-t * 3.0) * (1 - math.exp(-t * 60))
			base := f32(196.0) // G3
			f := sting_up ? base * math.pow(f32(2), t * 0.9) : base * math.pow(f32(2), -t * 0.55)
			v := math.sin(t * f * math.TAU) * 0.5
			v += math.sin(t * f * 2 * math.TAU) * 0.18
			v += math.sin(t * f * 1.5 * math.TAU) * (sting_up ? 0.16 : 0.0)
			return v * env
		}),
	)
}

@(private = "file")
sting_up: bool = true
