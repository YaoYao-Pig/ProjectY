Shader "ProjectY/Map Weather Particle"
{
    Properties
    {
        _Splash ("Splash Ring", Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Name "WeatherParticle"
            Tags { "LightMode"="UniversalForwardOnly" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off ZTest LEqual Cull Off
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            CBUFFER_START(UnityPerMaterial)
                half _Splash;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
                half fog : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                Light sun = GetMainLight();
                // Lighting is deliberately evaluated per vertex; rain never adds a white emissive layer at night.
                half3 light = max(half3(.008,.01,.015), sun.color * .58 + SampleSH(half3(0,1,0)) * .65);
                output.color = half4(input.color.rgb * min(light, half3(1.15,1.15,1.15)), input.color.a);
                output.fog = ComputeFogFactor(output.positionCS.z);
                return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 p = input.uv * 2 - 1;
                half mask;
                if (_Splash > .5)
                {
                    // Particle size expands the ring; lifetime alpha supplies its fade without an animated texture.
                    float radius = length(p);
                    float edge = max(.035, fwidth(radius));
                    mask = 1-smoothstep(.065, .065+edge, abs(radius-.64));
                    mask *= 1-smoothstep(.88, 1.0, radius);
                }
                else
                {
                    // Stretch billboards orient their long axis with velocity. A radial mask preserves
                    // that axis on both render backends instead of cropping the generated streak UVs.
                    mask = 1-smoothstep(.30, 1, dot(p,p));
                }
                return half4(MixFog(input.color.rgb, input.fog), input.color.a * mask);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
