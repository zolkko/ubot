struct VOut {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f,
};

struct GaugeUniforms {
    value: f32,
    aspect: f32,
    time: f32,
    pad: f32,
};

@group(0) @binding(0) var<uniform> u: GaugeUniforms;

const PI: f32 = 3.14159265358979;

// Metal's smoothstep(e0, e1, x) with e0 > e1 is technically undefined;
// this helper gives the intended "falling edge" result explicitly.
fn falloff(outer: f32, inner: f32, x: f32) -> f32 {
    // equivalent to smoothstep(outer, inner, x) where outer > inner
    return 1.0 - smoothstep(inner, outer, x);
}

// Full-screen triangle, no vertex buffer needed
@vertex
fn gauge_vertex(@builtin(vertex_index) vid: u32) -> VOut {
    var positions = array<vec2f, 3>(
        vec2f(-1.0, -1.0),
        vec2f( 3.0, -1.0),
        vec2f(-1.0,  3.0)
    );
    var out: VOut;
    out.position = vec4f(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5; // 0..1
    return out;
}

@fragment
fn gauge_fragment(frag: VOut) -> @location(0) vec4f {
    // center + aspect-correct
    var p = frag.uv * 2.0 - 1.0;
    p.x *= u.aspect;

    let r = length(p);
    let angle = atan2(p.y, p.x); // -pi..pi

    // Map gauge to a 270° arc, starting at -225° (bottom-left) going clockwise
    let startAngle = radians(-225.0);
    let sweep = radians(270.0);
    var a = angle - startAngle;
    a = (a + 2.0 * PI) % (2.0 * PI);   // WGSL % on floats == fmod (truncated)
    let t = a / sweep; // 0..1 along the arc

    var color = vec3f(0.08); // background
    let onArc = (t >= 0.0 && t <= 1.0);

    // --- Ring track ---
    let ringOuter = 0.9;
    let ringInner = 0.78;
    let ringMask = falloff(ringOuter, ringOuter - 0.01, r) *
                   smoothstep(ringInner - 0.01, ringInner, r);
    if (onArc && ringMask > 0.0) {
        let track = vec3f(0.25);
        let fillColor = mix(vec3f(0.1, 0.8, 0.3), vec3f(0.9, 0.2, 0.2), t);
        let c = select(track, fillColor, t <= u.value);
        color = mix(color, c, ringMask);
    }

    // --- Tick marks every 10% ---
    for (var i: i32 = 0; i <= 10; i++) {
        let tt = f32(i) / 10.0;
        let tickAngle = startAngle + tt * sweep;
        let tickDir = vec2f(cos(tickAngle), sin(tickAngle));
        let tickLen = select(0.06, 0.12, i % 5 == 0);
        let d = abs(dot(p - tickDir * 0.78, vec2f(-tickDir.y, tickDir.x)));
        let band = falloff(0.012, 0.0, d) *
                   step(0.78 - tickLen, r) * step(r, 0.78);
        color = mix(color, vec3f(1.0), band);
    }

    // --- Needle ---
    let needleAngle = startAngle + u.value * sweep;
    let needleDir = vec2f(cos(needleAngle), sin(needleAngle));
    let side = dot(p, vec2f(-needleDir.y, needleDir.x));
    let along = dot(p, needleDir);
    let needleMask = falloff(0.015, 0.0, abs(side)) *
                     step(0.0, along) * step(along, 0.72);
    color = mix(color, vec3f(1.0, 0.85, 0.1), needleMask);

    // hub
    let hub = falloff(0.06, 0.05, r);
    color = mix(color, vec3f(0.9), hub);

    return vec4f(color, 1.0);
}
