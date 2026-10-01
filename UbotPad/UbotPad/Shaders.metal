#include <metal_stdlib>
using namespace metal;

struct CircleVertexOut {
    float4 position [[position]];
    float2 uv;
};

// Full-screen triangle covering the entire viewport, no vertex buffer needed.
vertex CircleVertexOut circle_vertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    float2 pos = positions[vertexID];

    CircleVertexOut out;
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    return out;
}

struct CircleUniforms {
    float2 resolution;
};

fragment float4 circle_fragment(CircleVertexOut in [[stage_in]],
                                 constant CircleUniforms &uniforms [[buffer(0)]]) {
    float2 resolution = uniforms.resolution;
    float2 pixel = in.uv * resolution;
    float2 center = resolution * 0.5;
    float radius = min(resolution.x, resolution.y) * 0.35;

    float dist = distance(pixel, center);
    float edgeSoftness = 2.0;
    float alpha = 1.0 - smoothstep(radius - edgeSoftness, radius + edgeSoftness, dist);

    float3 color = float3(0.15, 0.55, 0.95);
    return float4(color, alpha * 0.35);
}
