Shader "ProjectY/Fantasy Sky"
{
    Properties
    {
        _CloudCoverage ("Cloud Coverage", Range(0,1)) = .42
        _CloudSpeed ("Cloud Speed", Range(0,.05)) = .003
        _SunSize ("Sun Angular Radius", Range(.003,.04)) = .014
        [HideInInspector] _SunDirection ("Sun Direction", Vector) = (.3,.7,.4,0)
        [HideInInspector] _SunRadiance ("Sun Radiance", Vector) = (4,3.5,2.8,1)
        [HideInInspector] _Daylight ("Daylight", Float) = 1
        [HideInInspector] _WeatherRain ("Rain Intensity", Range(0,1)) = 0
        [HideInInspector] _WeatherTime ("Weather Visual Seconds", Float) = -1
        [HideInInspector] _WeatherWind ("Weather Wind XZ", Vector) = (1,.35,0,0)
        [HideInInspector] _StarVisibility ("Stars Through Clear Sky", Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            float _CloudCoverage, _CloudSpeed, _SunSize, _Daylight;
            float _WeatherRain, _WeatherTime, _StarVisibility;
            float4 _SunDirection, _SunRadiance, _WeatherWind;
            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 direction : TEXCOORD0; };
            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.direction = TransformObjectToWorldDir(input.positionOS.xyz);
                return output;
            }
            float Hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
            float Noise(float2 p)
            {
                float2 i = floor(p), f = frac(p); f = f*f*(3-2*f);
                return lerp(lerp(Hash(i),Hash(i+float2(1,0)),f.x),lerp(Hash(i+float2(0,1)),Hash(i+1),f.x),f.y);
            }
            float Clouds(float2 p) { return Noise(p)*.57 + Noise(p*2.03+7.4)*.29 + Noise(p*4.07-2.7)*.14; }
            float3 Stars(float3 direction)
            {
                // Stable hemisphere projection: no longitude seam and no per-frame random seed.
                float2 grid = direction.xz / max(1 + direction.y, .1) * 160;
                float2 cell = floor(grid);
                float seed = Hash(cell + 31.7);
                float2 center = .22 + .56 * float2(Hash(cell + 17.3), Hash(cell + 63.1));
                float2 offset = frac(grid) - center;
                float radius = lerp(.065, .12, Hash(cell + 94.6));
                float footprint = max(length(ddx(grid)), length(ddy(grid)));
                float filteredRadius = radius + max(.025, footprint * .65);
                float starMask = 1 - smoothstep(radius, filteredRadius, length(offset));
                starMask *= radius * radius / (filteredRadius * filteredRadius);
                float brightness = starMask * step(.983, seed) * lerp(1.1, 3.6, Hash(cell + 7.9));
                return lerp(float3(.65,.80,1), float3(1,.89,.69), Hash(cell + 42.8)) * brightness;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                float3 d = normalize(input.direction), sun = normalize(_SunDirection.xyz);
                float day = _Daylight;
                float3 zenith = lerp(float3(.006,.013,.035), float3(.10,.36,.82), day);
                float3 horizon = lerp(float3(.015,.025,.06), float3(.67,.81,1.02), day);
                float twilight = (1-smoothstep(.22,.65,sun.y))*day;
                horizon = lerp(horizon,float3(1.15,.64,.32),twilight*.85);
                zenith = lerp(zenith,float3(.17,.12,.32),twilight*.7);
                float horizonAmount = exp(-max(d.y,0)*4);
                float3 color = lerp(zenith, horizon, horizonAmount);
                float towardSun = saturate(dot(d,sun));
                float sunset = 1-smoothstep(.12,.65,sun.y);
                color += _SunRadiance.rgb * pow(towardSun,8) * horizonAmount * sunset * .20;
                float weatherTime = _WeatherTime >= 0 ? _WeatherTime : _Time.y;
                float2 cloudUV = d.xz / max(d.y+.18,.16) * 1.55
                    + weatherTime * _CloudSpeed * _WeatherWind.xy;
                float noise = Clouds(cloudUV);
                float coverage = saturate(_CloudCoverage);
                float cloud = smoothstep(1-coverage,1-coverage+.18,noise) * smoothstep(.01,.22,d.y);
                float stars = saturate(_StarVisibility) * (1-saturate(day)) * smoothstep(.02,.20,d.y) * (1-cloud);
                if (_StarVisibility * (1-saturate(day)) > .001) color += Stars(d) * stars;
                float detail = Clouds(cloudUV + sun.xz*.14);
                float silver = saturate((noise-detail)*7+.35);
                float3 cloudShade = lerp(float3(.025,.035,.07),float3(.50,.61,.78),day);
                float3 cloudLight = lerp(float3(.06,.075,.12),float3(.9,.95,1),day) + _SunRadiance.rgb*.22;
                cloudShade *= lerp(1,.52,saturate(_WeatherRain));
                cloudLight *= lerp(1,.64,saturate(_WeatherRain));
                color = lerp(color,lerp(cloudShade,cloudLight,silver),cloud*.94);
                float sunDisc = smoothstep(cos(_SunSize*1.15),cos(_SunSize*.8),dot(d,sun));
                float sunHalo = pow(towardSun,180)*.12;
                color += _SunRadiance.rgb * (sunDisc*lerp(2,14,day)+sunHalo) * (1-cloud*.95);
                color = lerp(color,lerp(float3(.008,.013,.02),float3(.18,.24,.30),day),1-smoothstep(-.3,-.02,d.y));
                return half4(color,1);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
