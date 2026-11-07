#ifndef PROJECT_Y_WORLD_FOG_SAMPLING
#define PROJECT_Y_WORLD_FOG_SAMPLING
TEXTURE2D(_WorldFogMask);
SAMPLER(sampler_WorldFogMask);
float4 _WorldFogBounds;
float _WorldFogEnabled;
half3 ApplyWorldFog(half3 color, float3 positionWS)
{
    if (_WorldFogEnabled < .5) return color;
    float2 uv = (positionWS.xz - _WorldFogBounds.xy) * _WorldFogBounds.zw;
    half2 sight = SAMPLE_TEXTURE2D(_WorldFogMask, sampler_WorldFogMask, uv).rg;
    clip(sight.g - .12);
    // Lift dark memories without clamping all shadowed slopes to one flat gray.
    // The monotonic curve preserves lighting/texture contrast even at night and compresses HDR highlights.
    half luminance = max(0, dot(color, half3(.2126,.7152,.0722)));
    half gray = .085 + .55 * sqrt(luminance / (1 + luminance));
    return lerp(gray.xxx, color, smoothstep(.2,.85,sight.r));
}
#endif
