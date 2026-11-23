#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Shockwave for a prank hit: a ring travels out from `center`, pushing pixels outwards
/// and splitting red/blue slightly where it passes. Fades out over about a second.
///
/// - center:    impact point in the view's coordinates (points)
/// - time:      seconds since the hit
/// - amplitude: how far the ring pushes pixels, in points
[[ stitchable ]] half4 impactWave(float2 position, SwiftUI::Layer layer,
                                  float2 center, float time, float amplitude) {
    const float speed = 650.0;    // ring speed, points per second
    const float width = 150.0;    // thickness of the ring

    float2 delta = position - center;
    float dist = length(delta);
    float2 dir = dist > 0.001 ? delta / dist : float2(0.0);

    // 1 on the ring, 0 away from it, smooth in between.
    float ring = 1.0 - smoothstep(0.0, width, abs(dist - time * speed));
    float fade = exp(-time * 2.4);
    float push = ring * amplitude * fade;

    float2 p = position - dir * push;
    half4 color = layer.sample(p);

    // Chromatic aberration along the ring.
    float split = push * 0.4;
    half red = layer.sample(p + dir * split).r;
    half blue = layer.sample(p - dir * split).b;
    return half4(red, color.g, blue, color.a);
}
