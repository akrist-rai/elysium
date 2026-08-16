#version 330

// Painterly post-process.
//
// The scene arrives as flat isometric primitives. Everything that makes it read
// as a painting happens here: the sampling point is pushed around by layered
// noise so edges wobble like a loaded brush, bright areas bleed, the palette is
// pulled toward sodium light and cold shadow, and grain sits over all of it.

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float uTime;
uniform vec2  uResolution;
uniform float uWobble;
uniform float uGrain;
uniform float uVignette;
uniform float uBloom;
uniform float uGrade;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Three octaves is enough to get both the broad canvas warp and the fine
// bristle chatter without the cost of a full fbm.
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = fragTexCoord;
    vec2 px = 1.0 / uResolution;

    // --- brush wobble ------------------------------------------------------
    // Two scales of displacement: a slow wide warp that breaks the geometric
    // regularity of the isometric grid, and a tight one that roughens edges.
    float warpScale = 3.2;
    float bristleScale = 34.0;
    vec2 warp = vec2(fbm(uv * warpScale + 11.3), fbm(uv * warpScale + 41.7)) - 0.5;
    vec2 bristle = vec2(fbm(uv * bristleScale + 3.1), fbm(uv * bristleScale + 7.9)) - 0.5;
    vec2 offset = (warp * 2.6 + bristle * 0.9) * uWobble * px * 2.4;

    // --- sample, with chromatic aberration toward the frame edge -----------
    // The three channels are fetched at slightly different offsets here, at the
    // start, so that everything downstream grades a single coherent colour.
    // Splitting them after the grade would undo the grade on two channels.
    vec2 fromCenter = uv - 0.5;
    float edge = dot(fromCenter, fromCenter);
    float ca = edge * 0.010 * uWobble;
    vec2 base = uv + offset;

    vec3 col;
    col.r = texture(texture0, base + fromCenter * ca).r;
    col.g = texture(texture0, base).g;
    col.b = texture(texture0, base - fromCenter * ca).b;

    // A little exposure before grading: the room is lit by two dying tubes and
    // needs help before the shadow tint takes another bite out of it.
    col *= 1.18;

    // --- bloom -------------------------------------------------------------
    // A cheap wide tap: monitors and the exit sign are the only bright things
    // in the room, so anything above the knee is a light source by definition.
    vec3 glow = vec3(0.0);
    float total = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.7853981634; // 2pi/8
        for (int r = 1; r <= 2; r++) {
            vec2 d = vec2(cos(a), sin(a)) * px * float(r) * 5.0;
            vec3 s = texture(texture0, base + d).rgb;
            float lum = dot(s, vec3(0.299, 0.587, 0.114));
            float knee = smoothstep(0.62, 0.95, lum);
            glow += s * knee;
            total += 1.0;
        }
    }
    glow /= total;
    col += glow * 1.5 * uBloom;

    // --- grade -------------------------------------------------------------
    // Shadows go cold and slightly green, highlights go sodium-amber. This is
    // the single biggest contributor to the mood.
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 shadowTint = vec3(0.30, 0.42, 0.44);
    vec3 highTint   = vec3(1.16, 1.00, 0.72);
    vec3 graded = col * mix(shadowTint, highTint, smoothstep(0.05, 0.75, lum));

    // Lift the blacks so nothing is ever fully dead, the way paint on board
    // never reaches true black.
    graded = graded + vec3(0.045, 0.052, 0.050) * (1.0 - lum);

    // Slight desaturation, then a touch of contrast back in.
    float g = dot(graded, vec3(0.299, 0.587, 0.114));
    graded = mix(vec3(g), graded, 0.88);
    graded = (graded - 0.5) * 1.09 + 0.5;

    col = mix(col, graded, uGrade);

    // --- vignette ----------------------------------------------------------
    float vig = 1.0 - edge * 1.28 * uVignette;
    vig = clamp(vig, 0.0, 1.0);
    col *= mix(1.0, vig, 0.85);

    // --- grain -------------------------------------------------------------
    // Static-per-frame noise plus a fixed canvas tooth that does not crawl.
    float canvas = fbm(uv * 420.0) - 0.5;
    float film = hash(uv * uResolution + vec2(uTime * 91.0, uTime * 47.0)) - 0.5;
    col += (canvas * 0.055 + film * 0.035) * uGrain;

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0) * colDiffuse * fragColor;
}
