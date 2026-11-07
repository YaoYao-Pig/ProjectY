#ifndef PROJECT_Y_MAP_WATER_SURFACE
#define PROJECT_Y_MAP_WATER_SURFACE
// Shared field: 1 inside / negative exterior distance, exact elevation, shore distance, optical depth (distances / radius).
TEXTURE2D(_WaterBoundaryField); SAMPLER(sampler_WaterBoundaryField);
float4 _WaterBoundaryBounds;
float _WaterBoundaryEnabled;
float4 WaterBoundary(float2 worldXZ)
{
    if (_WaterBoundaryEnabled < .5) return float4(0,0,16,.5);
    float2 uv=(worldXZ-_WaterBoundaryBounds.xy)*_WaterBoundaryBounds.zw;
    return SAMPLE_TEXTURE2D_LOD(_WaterBoundaryField,sampler_WaterBoundaryField,uv,0);
}
float2 OceanHash(float2 p)
{
    float3 q=frac(float3(p.xyx)*float3(.1031,.1030,.0973));
    q+=dot(q,q.yzx+33.33);return frac((q.xx+q.yz)*q.zy);
}
float OceanNoise(float2 p)
{
    float2 cell=floor(p),f=frac(p);f=f*f*(3-2*f);
    return lerp(lerp(OceanHash(cell).x,OceanHash(cell+float2(1,0)).x,f.x),
        lerp(OceanHash(cell+float2(0,1)).x,OceanHash(cell+1).x,f.x),f.y);
}
float WaterWave(float2 p,float time,float2 direction,float frequency,float amplitude,float speed,
    float footprint,inout float3 waves)
{
    // Analytic height/slope; waves smaller than a pixel fade before they can sparkle or alias.
    float weight=1-smoothstep(.4,2.0,footprint*frequency);
    float sine,cosine;sincos(dot(p,direction)*frequency-time*speed,sine,cosine);
    waves+=float3(sine,direction*frequency*cosine)*(amplitude*weight);
    return smoothstep(.84,.99,sine)*weight;
}
half3 StylizedWater(float3 world,float radius,float time,float shore,float depth)
{
    float2 p=world.xz/max(radius,.001);
    float footprint=max(length(ddx(p)),length(ddy(p)));
    float detail=1-smoothstep(.2,.9,footprint);
    float rippleDetail=1-smoothstep(.08,.24,footprint);
    float coastNoise=OceanNoise(p*.43+float2(time*.012,-time*.009));
    float driftNoise=OceanNoise(p*.11+float2(time*.007,time*.004)+19.3);
    float2 wavePosition=p+float2(driftNoise-.5,coastNoise-.5)*1.8;
    float3 waves=0;
    WaterWave(wavePosition,time,float2(.8,.6),.62,.22,.68,footprint,waves);
    float crest=WaterWave(wavePosition,time,float2(-.6,.8),1.47,.075,1.36,footprint,waves)*.8;
    crest+=WaterWave(wavePosition,time,float2(.96,-.28),4.1,.014,2.15,footprint,waves)*.25;
    depth=max(0,depth);
    float amplitude=(.65+.35*saturate(depth*.35))*smoothstep(0,.6,shore)*lerp(.12,1,rippleDetail);
    half3 normal=normalize(half3(-waves.y*amplitude,1,-waves.z*amplitude));
    half3 view=GetWorldSpaceNormalizeViewDir(world);
    half nv=saturate(dot(normal,view));

    // Cheap absorption and a restrained riverbed hint, rather than a screen-color/refraction pass.
    half bedVariation=(coastNoise-.5)*.035*detail;
    half3 bed=half3(.22,.43,.34)+bedVariation;
    half3 body=lerp(half3(.035,.19,.20),half3(.018,.11,.17),saturate(depth/8));
    float path=depth/max(nv,.35);
    half3 transmission=exp2(-path*half3(.72,.32,.20));
    half3 color=lerp(body,bed,transmission);

    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
        float4 shadow=ComputeScreenPos(TransformWorldToHClip(world));
    #else
        float4 shadow=TransformWorldToShadowCoord(world);
    #endif
    Light sun=GetMainLight(shadow);
    half3 illumination=clamp(sun.color*.7+SampleSH(half3(0,1,0))*.45,
        half3(.12,.14,.16),half3(1.1,1.1,1.1));
    half diffuse=.94+.06*saturate(dot(normal,sun.direction));
    color*=illumination*diffuse*lerp(.75,1,sun.shadowAttenuation);

    // Fresnel + a broad stylized sky lobe; no reflection cameras, cubemap lookup or SSR.
    half grazing=1-nv;half grazing2=grazing*grazing;
    half fresnel=.0204+.9796*grazing2*grazing2*grazing;
    half3 reflection=reflect(-view,normal);
    half3 sky=lerp(half3(.10,.19,.23),half3(.52,.66,.67),smoothstep(.25,.85,reflection.y));
    color=lerp(color,sky*illumination,saturate(.09+fresnel*.7));
    half3 halfVector=SafeNormalize(sun.direction+view);
    half specular=pow(saturate(dot(normal,halfVector)),24);
    color+=sun.color*specular*(.025+.09*detail)*sun.shadowAttenuation;

    // Explicit stylized wave faces remain legible from above, even away from the sun reflection.
    // Reuse the three waves' sin/cos and the existing two noise values; no extra texture fetch or wave loop.
    color*=1+(smoothstep(-.16,.16,waves.x)-.5)*.11*rippleDetail;
    float breakup=smoothstep(.26,.66,coastNoise)*smoothstep(.12,.62,driftNoise+.2);
    float ripple=saturate(crest)*breakup*rippleDetail*smoothstep(0,.55,shore);
    color=lerp(color,half3(.42,.67,.65)*illumination,ripple*.55);

    // Sparse shore pulses move inland, break up and fade; the boundary is not a permanent white outline.
    float pulse=sin(shore*6+time*1.55+coastNoise*2.4)*.5+.5;
    float foam=smoothstep(.78,.98,pulse)*smoothstep(.25,.62,coastNoise)
        *(1-smoothstep(.18,1.05,shore))*smoothstep(0,.16,shore);
    foam*=lerp(.30,.65,saturate(depth*.25))*(.35+.65*detail);
    color=lerp(color,half3(.66,.78,.74)*illumination,foam);
    return color;
}
#endif
