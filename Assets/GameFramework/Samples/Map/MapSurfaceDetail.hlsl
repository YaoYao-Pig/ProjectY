#ifndef PROJECT_Y_MAP_SURFACE_DETAIL
#define PROJECT_Y_MAP_SURFACE_DETAIL
float MapHash(float2 p) { return frac(sin(dot(p, float2(127.1,311.7))) * 43758.5453); }
float MapNoise(float2 p)
{
    float2 i = floor(p), f = frac(p); f = f*f*(3-2*f);
    return lerp(lerp(MapHash(i),MapHash(i+float2(1,0)),f.x),lerp(MapHash(i+float2(0,1)),MapHash(i+1),f.x),f.y);
}
float2 MapProject(float3 p, float3 n)
{
    n = abs(n);
    return n.y > .6 ? p.xz : (n.x > n.z ? p.zy : p.xy);
}
float4 MapOrientedPattern(float4 data, float3 normal)
{
    // Masonry faces use courses; horizontal stone surfaces use larger square slabs.
    if (data.x > 8.5 && abs(normal.y) > .6) data.x = 1;
    return data;
}
// RGB: albedo multiplier, height in metres, cavity occlusion. W: smoothness variation.
float4 MapSurface(float2 meters, float4 data, float relief)
{
    float kind = data.x;
    if (kind < .5) return float4(1, 0, 1, 0);
    float2 p = meters / max(.1, data.y);
    float fade = 1-saturate(max(fwidth(p.x),fwidth(p.y))*1.5);
    float coarse = MapNoise(p*.43);
    float fine = MapNoise(p*2.7);
    float value = 1, height = 0, cavity = 1, finish = 0;
    bool wood = kind > 4.5 && kind < 5.5;
    if (wood) relief *= .35;
    bool paving = kind < 2.5 || kind > 8.5 || wood;
    if (paving)
    {
        float2 q = p;
        if (wood) q.y *= .16;
        else if (kind > 8.5) q.y *= 2;
        q.x += fmod(floor(q.y),2)*.5;
        float2 f = frac(q), edge = min(f,1-f), aa = max(fwidth(q), .001);
        float gap = data.w * .55;
        float2 bevel = smoothstep(gap, gap + .065 + aa, edge);
        float face = min(bevel.x, bevel.y);
        if (kind > 1.5 && kind < 2.5)
            face *= 1-smoothstep(.53,.66+max(aa.x,aa.y),length(f-.5));
        float variation = MapHash(floor(q));
        value += ((variation-.5)*.65 - (1-face)*.8) * data.z * fade;
        height = (face + (coarse-.5)*.14) * relief * fade;
        cavity = 1-(1-face)*.28*fade;
        finish = (variation-.5)*.05*fade;
        if (wood)
        {
            float warp = MapNoise(float2(p.x*.7,p.y*.14))*.65;
            float grain = sin((p.x + warp)*46 + MapNoise(p*.6)*4);
            float grainFade = 1-saturate(max(fwidth(p.x)*18,fwidth(p.y)));
            value += grain * .055 * grainFade;
            height += grain * relief * .09 * grainFade;
            finish += grain * .025 * grainFade;
        }
    }
    else
    {
        value += ((coarse-.5)*1.1+(fine-.5)*.25*fade)*data.z;
        float rock = kind > 5.5 ? 1 : .22;
        height = ((coarse-.5)*.75+(fine-.5)*.25)*relief*rock*fade;
        finish = (coarse-.5)*.07*fade;
    }
    return float4(value,height,cavity,finish);
}
// Surface-gradient bump mapping works on world-projected hexes and rotated/scaled model-space props.
float3 MapReliefNormal(float3 positionWS, float3 normalWS, float height)
{
    float3 dx = ddx(positionWS), dy = ddy(positionWS);
    float3 r1 = cross(dy, normalWS), r2 = cross(normalWS, dx);
    float determinant = dot(dx,r1);
    float3 gradient = sign(determinant)*(ddx(height)*r1+ddy(height)*r2);
    return normalize(max(abs(determinant),1e-10)*normalWS-gradient);
}
#endif
