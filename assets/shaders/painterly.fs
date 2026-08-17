#version 330

// Painterly post-process.
//
// The scene arrives as flat shaded polygons. Everything that makes it read as a
// painting rather than as vector art happens here, and the order matters:
//
//   1. A structure tensor works out which way the image is "going" at every
//      pixel -- along an edge, across a gradient, or nowhere in particular.
//   2. An anisotropic Kuwahara filter then averages inside an ellipse aligned
//      to that direction, keeping the sector with the least variance. This is
//      the step that actually does it: instead of blurring, it collapses each
//      neighbourhood into a flat region with a hard edge, so the image breaks
//      into strokes that follow form the way a loaded brush does.
//   3. The gradient is reused to darken where forms meet, which is the drawn
//      accent a painter puts in last and the reason edges read as decisions
//      rather than as polygon boundaries.
//   4. Luminance is treated as a height field and lit from the upper left, so
//      thick passages catch a specular the way standing paint does.
//   5. Only then: bloom, grade, tonemap, canvas, grain.
//
// Steps 1-2 are the expensive part and the whole point. Everything after them is
// finishing.

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float uTime;
uniform vec2  uResolution;
uniform float uWobble;   // brush size / abstraction
uniform float uGrain;    // canvas tooth + film grain
uniform float uVignette;
uniform float uBloom;
uniform float uGrade;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float luma(vec3 c) { return dot(c, LUMA); }

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

// ---------------------------------------------------------------------------
// 1. Structure tensor
//
// Sobel in both axes, assembled into the tensor [[Jxx, Jxy], [Jxy, Jyy]]. Its
// eigenvectors give the direction of greatest and least change; the minor one
// runs along the edge, which is the direction a brush stroke wants to lie in.
// ---------------------------------------------------------------------------
void structure(vec2 uv, vec2 px, out vec2 dir, out float anisotropy) {
    vec3 tl = texture(texture0, uv + px * vec2(-1.0, -1.0)).rgb;
    vec3 tc = texture(texture0, uv + px * vec2( 0.0, -1.0)).rgb;
    vec3 tr = texture(texture0, uv + px * vec2( 1.0, -1.0)).rgb;
    vec3 ml = texture(texture0, uv + px * vec2(-1.0,  0.0)).rgb;
    vec3 mr = texture(texture0, uv + px * vec2( 1.0,  0.0)).rgb;
    vec3 bl = texture(texture0, uv + px * vec2(-1.0,  1.0)).rgb;
    vec3 bc = texture(texture0, uv + px * vec2( 0.0,  1.0)).rgb;
    vec3 br = texture(texture0, uv + px * vec2( 1.0,  1.0)).rgb;

    vec3 gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    vec3 gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);

    float Jxx = dot(gx, gx);
    float Jyy = dot(gy, gy);
    float Jxy = dot(gx, gy);

    // Eigenvalues of a symmetric 2x2.
    float trace = Jxx + Jyy;
    float delta = sqrt(max(trace * trace - 4.0 * (Jxx * Jyy - Jxy * Jxy), 0.0));
    float l1 = 0.5 * (trace + delta);
    float l2 = 0.5 * (trace - delta);

    // Minor eigenvector: along the edge.
    vec2 d = vec2(l1 - Jxx, -Jxy);
    dir = (length(d) < 1e-6) ? vec2(0.0, 1.0) : normalize(d);
    // Perpendicular, so the ellipse stretches along the edge.
    dir = vec2(-dir.y, dir.x);

    anisotropy = (l1 + l2 > 1e-6) ? (l1 - l2) / (l1 + l2) : 0.0;
}

// ---------------------------------------------------------------------------
// 2. Anisotropic Kuwahara
//
// Eight sectors around the point. Each accumulates a mean and a second moment;
// the sector whose variance is lowest wins, so the output always comes from the
// most uniform side of any edge. That is what keeps edges crisp while the
// interiors go flat, and it is why this looks like paint instead of like blur.
// ---------------------------------------------------------------------------
vec3 kuwahara(vec2 uv, vec2 px, vec2 dir, float anisotropy, float radius) {
    vec3  mean[8];
    vec3  moment[8];
    float count[8];

    for (int i = 0; i < 8; i++) {
        mean[i]   = vec3(0.0);
        moment[i] = vec3(0.0);
        count[i]  = 0.0;
    }

    // Stretch along the edge, squeeze across it. On flat areas anisotropy is ~0
    // and this degenerates to a circle, which is correct -- there is no stroke
    // direction in an untextured passage.
    float along  = radius * (1.0 + anisotropy * 1.7);
    float across = radius / (1.0 + anisotropy * 1.1);

    vec2 e0 = dir;
    vec2 e1 = vec2(-dir.y, dir.x);

    const int RINGS = 4;
    const int SPOKES = 8;

    for (int r = 1; r <= RINGS; r++) {
        float rt = float(r) / float(RINGS);
        for (int k = 0; k < SPOKES; k++) {
            float a = 6.2831853 * (float(k) + 0.5) / float(SPOKES);
            vec2 unit = vec2(cos(a), sin(a));
            // Map the unit circle onto the oriented ellipse.
            vec2 offs = (e0 * unit.x * along + e1 * unit.y * across) * rt;
            vec3 s = texture(texture0, uv + offs * px).rgb;

            mean[k]   += s;
            moment[k] += s * s;
            count[k]  += 1.0;
        }
    }

    vec3  best_col = vec3(0.0);
    float best_var = 1e20;

    for (int i = 0; i < 8; i++) {
        if (count[i] < 0.5) continue;
        vec3 m = mean[i] / count[i];
        vec3 v = abs(moment[i] / count[i] - m * m);
        float var = v.r + v.g + v.b;
        if (var < best_var) {
            best_var = var;
            best_col = m;
        }
    }
    return best_col;
}

void main() {
    vec2 uv = fragTexCoord;
    vec2 px = 1.0 / uResolution;

    vec2 fromCenter = uv - 0.5;
    float edgeDist = dot(fromCenter, fromCenter);

    // --- structure ---------------------------------------------------------
    vec2 dir;
    float anis;
    structure(uv, px, dir, anis);

    // --- brush -------------------------------------------------------------
    // The sampling point is nudged by low-frequency noise before filtering, so
    // stroke boundaries wander instead of sitting on a pixel grid. Small: this
    // is the wobble of a hand, not a distortion effect.
    vec2 warp = vec2(fbm(uv * 3.1 + 11.3), fbm(uv * 3.1 + 41.7)) - 0.5;
    vec2 base = uv + warp * px * 2.2 * uWobble;

    float radius = mix(1.5, 5.0, clamp(uWobble, 0.0, 1.0));
    vec3 col = kuwahara(base, px, dir, anis, radius);

    // Keep a little of the unfiltered image so fine detail -- rack LEDs, the
    // tube filament -- is not entirely eaten by the abstraction.
    vec3 sharp = texture(texture0, base).rgb;
    col = mix(col, sharp, 0.18);

    // --- 3. drawn edges ----------------------------------------------------
    // Gradient magnitude, reused from the tensor's inputs via a cheap re-sample.
    // Where forms meet, the value goes down and slightly warm, which is what a
    // dark accent laid in with a brush actually does to the colour underneath.
    float l0 = luma(texture(texture0, base + vec2( px.x, 0.0)).rgb);
    float l1 = luma(texture(texture0, base - vec2( px.x, 0.0)).rgb);
    float l2 = luma(texture(texture0, base + vec2(0.0,  px.y)).rgb);
    float l3 = luma(texture(texture0, base - vec2(0.0,  px.y)).rgb);
    float grad = length(vec2(l0 - l1, l2 - l3));
    // The low end of this threshold matters more than it looks: the floor is
    // drawn as flat per-tile fills, so tile-to-tile steps are real gradients.
    // Accenting them turns the grade into a visible grid, which is the exact
    // opposite of what the accent is for. Only genuine form boundaries qualify.
    float accent = smoothstep(0.10, 0.34, grad) * uWobble;
    col *= mix(1.0, 0.82, accent);
    col = mix(col, col * vec3(1.06, 0.98, 0.90), accent * 0.5);

    // --- bloom -------------------------------------------------------------
    // Monitors, the exit sign and the tubes are the only bright things in the
    // building, so anything above the knee is a light source by definition.
    vec3 glow = vec3(0.0);
    float total = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.7853981634;
        vec2 d = vec2(cos(a), sin(a));
        for (int r = 1; r <= 2; r++) {
            vec3 s = texture(texture0, base + d * px * float(r) * 5.0).rgb;
            // Tuned to the scene's actual range. Too high (0.6) and it never
            // fires, because nothing in a room lit by two tubes gets that
            // bright. Too low (0.3) and it catches the pools of light on the
            // floor, which are not sources -- they are floor -- and the whole
            // frame turns into a haze of white blobs.
            float knee = smoothstep(0.46, 0.86, luma(s));
            glow += s * knee;
            total += 1.0;
        }
    }
    glow /= max(total, 1.0);
    col += glow * 1.35 * uBloom;

    // --- 4. impasto --------------------------------------------------------
    // Luminance as a height field. Where the painting is bright it is thick, and
    // thick paint catches a raking light along its ridges. This is what stops
    // the flat Kuwahara regions from looking like posterisation.
    float hL = luma(texture(texture0, base - vec2(px.x, 0.0)).rgb);
    float hR = luma(texture(texture0, base + vec2(px.x, 0.0)).rgb);
    float hD = luma(texture(texture0, base - vec2(0.0, px.y)).rgb);
    float hU = luma(texture(texture0, base + vec2(0.0, px.y)).rgb);
    // Canvas tooth perturbs the surface normal too, so the specular breaks up.
    float tooth = fbm(uv * uResolution.x * 0.16) - 0.5;
    vec3 n = normalize(vec3((hL - hR) * 2.2 + tooth * 0.35,
                            (hD - hU) * 2.2 + tooth * 0.35,
                            1.0));
    vec3 lightDir = normalize(vec3(-0.55, -0.75, 0.65));
    float spec = pow(max(dot(n, lightDir), 0.0), 14.0);
    col += spec * 0.16 * uWobble * smoothstep(0.10, 0.55, luma(col));

    // --- 5. grade ----------------------------------------------------------
    // The room is lit by two dying tubes and a rack row. It needs exposure
    // before anything else touches it, or every step below is just dividing
    // darkness by more darkness.
    // NOTE: this is calibrated against the renderer's floor albedos. If those
    // change materially, the median lands somewhere else and this wants
    // re-measuring rather than re-eyeballing -- the frame is dark enough that
    // judging it by eye on a bright monitor is unreliable.
    col *= 1.30;

    // Shadows cold and slightly green, highlights sodium-amber. This is the
    // single biggest contributor to the mood.
    //
    // The tints are chosen to shift hue without cutting value. An earlier pass
    // used a shadow tint near 0.3, which is a 3x cut dressed up as a colour
    // grade: combined with a contrast pivot and a tonemap it put the median
    // pixel at 0.04 and buried half the room. A grade should decide what colour
    // the dark is, not how much of the image survives.
    float lum = luma(col);
    vec3 shadowTint = vec3(0.52, 0.72, 0.80);
    vec3 highTint   = vec3(1.15, 1.00, 0.76);
    vec3 graded = col * mix(shadowTint, highTint, smoothstep(0.02, 0.55, lum));

    // Lift the blacks, weighted to the darkest end only. Paint on board never
    // reaches true black, and the moment it does the frame stops reading as a
    // physical object and starts reading as a switched-off screen.
    graded += vec3(0.014, 0.018, 0.020) * (1.0 - smoothstep(0.0, 0.34, lum));

    // Pull very slightly toward the palette's warm neutral, the way a ground
    // colour shows through every layer laid over it.
    graded = mix(graded, graded * vec3(1.03, 1.00, 0.94), 0.6);

    float g = luma(graded);
    graded = mix(vec3(g), graded, 0.90);

    // Contrast pivots on this scene's actual midtone, not on 0.5. Pivoting at
    // 0.5 in a room whose median is a tenth of that pushes the entire image
    // down and is why the previous pass read as mud.
    // Contrast pivots on this scene's actual midtone, not on 0.5, and it has to
    // be strong: without it every value collapses into a single hazy band and
    // the frame reads as fog rather than as a dark room with lights in it.
    const float PIVOT = 0.14;
    graded = (graded - PIVOT) * 1.42 + PIVOT;

    col = mix(col, graded, uGrade);

    // Highlight rolloff. Gentle, and late: the tube and the exit sign are the
    // only things in the building allowed to reach white, and squashing them
    // costs the image its entire top end. An earlier pass asymptoted near 0.6,
    // which capped the brightest pixel in the room at half value.
    col = col / (1.0 + max(col - 0.70, 0.0) * 0.70);

    // --- vignette ----------------------------------------------------------
    // Keeps the eye in the middle of the frame without hiding the corners.
    float vig = clamp(1.0 - edgeDist * 1.05 * uVignette, 0.0, 1.0);
    col *= mix(1.0, vig, 0.78);

    // --- canvas and grain --------------------------------------------------
    // A fixed tooth that does not crawl, plus per-frame film grain that does.
    float canvas = fbm(uv * 420.0) - 0.5;
    float film = hash(uv * uResolution + vec2(uTime * 91.0, uTime * 47.0)) - 0.5;
    col += (canvas * 0.050 + film * 0.030) * uGrain;

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0) * colDiffuse * fragColor;
}
